//! Optional, allocation-free workflow helpers.
//!
//! These helpers never wait for device idle and never hide queue-family ownership, image
//! layouts, capacity, or completion. Callers remain responsible for externally synchronizing
//! the queue, command pool, and resources referenced by recorded work.

const std = @import("std");
const core = @import("core.zig");
const types = @import("vulkan_types");
const buffer = @import("buffer.zig");
const image = @import("image.zig");
const memory = @import("memory.zig");
const commands = @import("command_buffer.zig");
const queues = @import("queue.zig");
const synchronization = @import("synchronization.zig");

/// The caller-visible completion condition for submitted work.
pub const Completion = union(enum) {
    fence: *const synchronization.Fence,
    timeline: struct {
        semaphore: *const synchronization.Semaphore,
        value: u64,
    },
};

pub const UploadTransition = struct {
    old_layout: types.ImageLayout,
    transfer_layout: types.ImageLayout,
    final_layout: types.ImageLayout,
    source_stage: types.PipelineStage2Flags,
    destination_stage: types.PipelineStage2Flags,
    source_access: types.AccessFlags = .empty,
    destination_access: types.AccessFlags = .empty,
};

pub const UploadOperation = union(enum) {
    buffer: struct {
        destination: *const buffer.Buffer,
        destination_offset: core.DeviceOffset,
        staging_offset: u64,
        size: core.DeviceSize,
        ownership: core.QueueFamilyOwnership,
    },
    image: struct {
        destination: image.SwapchainImage,
        staging_offset: u64,
        size: core.DeviceSize,
        ownership: core.QueueFamilyOwnership,
        transition: UploadTransition,
    },
};

/// A caller-bounded upload description backed by caller-owned staging bytes.
pub fn UploadBatch(comptime capacity: u32) type {
    if (capacity == 0) @compileError("UploadBatch capacity must be greater than zero");
    return struct {
        staging: []u8,
        queue_family: core.QueueFamilyIndex,
        operations_storage: [capacity]UploadOperation = undefined,
        operation_count: u32 = 0,
        staging_used: u64 = 0,
        completion: ?Completion = null,

        const Batch = @This();

        pub fn init(staging: []u8, queue_family: core.QueueFamilyIndex) Batch {
            return .{ .staging = staging, .queue_family = queue_family };
        }

        pub fn operations(batch: *const Batch) []const UploadOperation {
            return batch.operations_storage[0..batch.operation_count];
        }

        pub fn stagedBytes(batch: *const Batch) []const u8 {
            return batch.staging[0..batch.staging_used];
        }

        pub fn appendBuffer(
            batch: *Batch,
            destination: *const buffer.Buffer,
            destination_offset: core.DeviceOffset,
            bytes: []const u8,
            alignment: u32,
            ownership: core.QueueFamilyOwnership,
        ) core.Error!void {
            if (bytes.len == 0) return error.InvalidOptions;
            const staging_offset = try batch.reserve(bytes.len, alignment);
            @memcpy(batch.staging[staging_offset..][0..bytes.len], bytes);
            batch.operations_storage[batch.operation_count] = .{ .buffer = .{
                .destination = destination,
                .destination_offset = destination_offset,
                .staging_offset = staging_offset,
                .size = .fromBytes(bytes.len),
                .ownership = ownership,
            } };
            batch.commit(staging_offset + bytes.len);
        }

        pub fn appendImage(
            batch: *Batch,
            destination: image.SwapchainImage,
            bytes: []const u8,
            alignment: u32,
            ownership: core.QueueFamilyOwnership,
            transition: UploadTransition,
        ) core.Error!void {
            if (bytes.len == 0) return error.InvalidOptions;
            if (transition.transfer_layout != .transfer_dst_optimal) {
                return error.InvalidOptions;
            }
            const staging_offset = try batch.reserve(bytes.len, alignment);
            @memcpy(batch.staging[staging_offset..][0..bytes.len], bytes);
            batch.operations_storage[batch.operation_count] = .{ .image = .{
                .destination = destination,
                .staging_offset = staging_offset,
                .size = .fromBytes(bytes.len),
                .ownership = ownership,
                .transition = transition,
            } };
            batch.commit(staging_offset + bytes.len);
        }

        pub fn seal(batch: *Batch, completion: Completion) core.Error!void {
            if (batch.operation_count == 0) return error.InvalidOptions;
            if (batch.completion != null) return error.InvalidOptions;
            batch.completion = completion;
        }

        pub fn reset(batch: *Batch) void {
            batch.operation_count = 0;
            batch.staging_used = 0;
            batch.completion = null;
        }

        fn reserve(batch: *const Batch, byte_count: usize, alignment: u32) core.Error!usize {
            if (batch.completion != null) return error.InvalidOptions;
            if (batch.operation_count == capacity) return error.CapacityExceeded;
            if (alignment == 0 or !std.math.isPowerOfTwo(alignment)) {
                return error.InvalidOptions;
            }
            const start = std.mem.alignForward(u64, batch.staging_used, alignment);
            const end = std.math.add(u64, start, byte_count) catch return error.SizeOverflow;
            if (end > batch.staging.len) return error.BufferTooSmall;
            return @intCast(start);
        }

        fn commit(batch: *Batch, staging_used: usize) void {
            std.debug.assert(batch.operation_count < capacity);
            std.debug.assert(staging_used <= batch.staging.len);
            batch.operation_count += 1;
            batch.staging_used = staging_used;
        }
    };
}

/// An explicit one-time command-buffer lifecycle. Submission never waits implicitly.
pub const OneTimeCommands = struct {
    command_buffer: ?commands.Buffer = null,
    state: State = .empty,

    pub const State = enum {
        empty,
        recording,
        submitted,
        complete,
    };

    pub fn begin(helper: *OneTimeCommands, pool: *commands.Pool) core.Error!void {
        if (helper.state != .empty) return error.InvalidOptions;
        helper.command_buffer = try pool.allocateCommandBuffer(.{});
        errdefer {
            pool.freeCommandBuffer(&helper.command_buffer.?) catch |err| {
                std.debug.panic("failed to roll back one-time command buffer: {t}", .{err});
            };
            helper.command_buffer = null;
        }
        try helper.command_buffer.?.begin(.{
            .flags = .init(&.{.one_time_submit}),
        });
        helper.state = .recording;
    }

    pub fn commandsForRecording(helper: *OneTimeCommands) core.Error!*commands.Buffer {
        if (helper.state != .recording) return error.InvalidOptions;
        return &helper.command_buffer.?;
    }

    pub fn submit(
        helper: *OneTimeCommands,
        queue: *const queues.Queue,
        completion_fence: ?*const synchronization.Fence,
    ) core.Error!void {
        if (helper.state != .recording) return error.InvalidOptions;
        const command_buffer = &helper.command_buffer.?;
        try command_buffer.end();
        const submitted = [_]*commands.Buffer{command_buffer};
        try queue.submit(.{ .command_buffers = &submitted, .fence = completion_fence });
        helper.state = .submitted;
    }

    pub fn markComplete(helper: *OneTimeCommands) core.Error!void {
        if (helper.state != .submitted) return error.InvalidOptions;
        try helper.command_buffer.?.markComplete();
        helper.state = .complete;
    }

    pub fn release(helper: *OneTimeCommands, pool: *commands.Pool) core.Error!void {
        if (helper.state == .submitted) return error.InvalidOptions;
        if (helper.command_buffer) |*command_buffer| {
            try pool.freeCommandBuffer(command_buffer);
        }
        helper.command_buffer = null;
        helper.state = .empty;
    }
};

/// A fixed-capacity FIFO retirement queue. Readiness is supplied by the caller so fences and
/// timeline semaphores can share the same ordered implementation.
pub fn RetirementQueue(comptime T: type, comptime capacity: u32) type {
    if (capacity == 0) @compileError("RetirementQueue capacity must be greater than zero");
    return struct {
        entries: [capacity]Entry = undefined,
        head: u32 = 0,
        count: u32 = 0,

        pub const Entry = struct {
            value: T,
            completion: Completion,
        };

        const Queue = @This();

        pub fn enqueue(queue: *Queue, value: T, completion: Completion) core.Error!void {
            if (queue.count == capacity) return error.CapacityExceeded;
            const tail = (queue.head + queue.count) % capacity;
            queue.entries[tail] = .{ .value = value, .completion = completion };
            queue.count += 1;
        }

        pub fn peek(queue: *const Queue) ?*const Entry {
            if (queue.count == 0) return null;
            return &queue.entries[queue.head];
        }

        pub fn retireReady(
            queue: *Queue,
            context: anytype,
            comptime is_ready: fn (@TypeOf(context), Completion) core.Error!bool,
            comptime retire: fn (@TypeOf(context), T) void,
        ) core.Error!u32 {
            var retired: u32 = 0;
            while (retired < capacity and queue.count > 0) : (retired += 1) {
                const entry = queue.entries[queue.head];
                if (!try is_ready(context, entry.completion)) break;
                retire(context, entry.value);
                queue.head = (queue.head + 1) % capacity;
                queue.count -= 1;
            }
            return retired;
        }
    };
}

pub const MemoryPreset = enum {
    device_local,
    upload,
    readback,
};

pub const MemorySelection = struct {
    index: core.MemoryTypeIndex,
    preferred: bool,
    preset: MemoryPreset,
};

/// Selects a memory type while reporting whether the preset's preferred flags were satisfied.
pub fn selectMemory(
    properties: *const memory.Properties,
    type_bits: u32,
    preset: MemoryPreset,
) core.Error!MemorySelection {
    const required: types.MemoryPropertyFlags = switch (preset) {
        .device_local => .empty,
        .upload, .readback => .init(&.{.host_visible}),
    };
    const preferred: types.MemoryPropertyFlags = switch (preset) {
        .device_local => .init(&.{.device_local}),
        .upload => .init(&.{ .host_coherent, .host_cached }),
        .readback => .init(&.{ .host_cached, .host_coherent }),
    };
    const index = try properties.findType(.{
        .type_bits = type_bits,
        .required_flags = required,
        .preferred_flags = preferred,
    });
    const selected = properties.types()[@intCast(index.toRaw())];
    return .{
        .index = index,
        .preferred = selected.flags.containsAll(preferred),
        .preset = preset,
    };
}

pub const cache = struct {
    pub fn load(destination: []u8, source: []const u8) core.Error![]u8 {
        if (source.len > destination.len) return error.BufferTooSmall;
        @memcpy(destination[0..source.len], source);
        return destination[0..source.len];
    }

    /// Writes to a caller-owned stream. The caller controls and must perform the final flush.
    pub fn store(writer: *std.Io.Writer, bytes: []const u8) std.Io.Writer.Error!void {
        try writer.writeAll(bytes);
    }
};

test "bounded upload rollback and capacity" {
    var staging: [8]u8 = undefined;
    var batch = UploadBatch(1).init(&staging, .fromRaw(0));
    const fake_buffer: *const buffer.Buffer = @ptrFromInt(@alignOf(buffer.Buffer));
    try batch.appendBuffer(fake_buffer, .zero, "abcd", 4, .ignored);
    try std.testing.expectEqualStrings("abcd", batch.stagedBytes());
    try std.testing.expectError(
        error.CapacityExceeded,
        batch.appendBuffer(fake_buffer, .zero, "e", 1, .ignored),
    );
    try std.testing.expectEqual(@as(u32, 1), batch.operation_count);
}

test "retirement is ordered" {
    const Context = struct {
        completed: u64,
        output: *std.ArrayList(u32),

        fn ready(context: *@This(), completion: Completion) core.Error!bool {
            return switch (completion) {
                .timeline => |timeline| timeline.value <= context.completed,
                .fence => error.UnsupportedOperation,
            };
        }

        fn retire(context: *@This(), value: u32) void {
            context.output.append(std.testing.allocator, value) catch unreachable;
        }
    };

    var output: std.ArrayList(u32) = .empty;
    defer output.deinit(std.testing.allocator);
    var queue: RetirementQueue(u32, 3) = .{};
    const fake_semaphore: *const synchronization.Semaphore =
        @ptrFromInt(@alignOf(synchronization.Semaphore));
    try queue.enqueue(1, .{ .timeline = .{ .semaphore = fake_semaphore, .value = 2 } });
    try queue.enqueue(2, .{ .timeline = .{ .semaphore = fake_semaphore, .value = 4 } });
    var context: Context = .{ .completed = 3, .output = &output };
    try std.testing.expectEqual(@as(u32, 1), try queue.retireReady(&context, Context.ready, Context.retire));
    try std.testing.expectEqualSlices(u32, &.{1}, output.items);
}
