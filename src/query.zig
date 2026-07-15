const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const commands = @import("command_buffer.zig");
const buffers = @import("buffer.zig");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const QueryPoolHandle = core.NonNullHandle(raw.VkQueryPool);

pub const PipelineStatisticBit = enum(u32) {
    input_assembly_vertices = raw.VK_QUERY_PIPELINE_STATISTIC_INPUT_ASSEMBLY_VERTICES_BIT,
    input_assembly_primitives = raw.VK_QUERY_PIPELINE_STATISTIC_INPUT_ASSEMBLY_PRIMITIVES_BIT,
    vertex_shader_invocations = raw.VK_QUERY_PIPELINE_STATISTIC_VERTEX_SHADER_INVOCATIONS_BIT,
    geometry_shader_invocations = raw.VK_QUERY_PIPELINE_STATISTIC_GEOMETRY_SHADER_INVOCATIONS_BIT,
    geometry_shader_primitives = raw.VK_QUERY_PIPELINE_STATISTIC_GEOMETRY_SHADER_PRIMITIVES_BIT,
    clipping_invocations = raw.VK_QUERY_PIPELINE_STATISTIC_CLIPPING_INVOCATIONS_BIT,
    clipping_primitives = raw.VK_QUERY_PIPELINE_STATISTIC_CLIPPING_PRIMITIVES_BIT,
    fragment_shader_invocations = raw.VK_QUERY_PIPELINE_STATISTIC_FRAGMENT_SHADER_INVOCATIONS_BIT,
    tessellation_control_shader_patches = raw.VK_QUERY_PIPELINE_STATISTIC_TESSELLATION_CONTROL_SHADER_PATCHES_BIT,
    tessellation_evaluation_shader_invocations = raw.VK_QUERY_PIPELINE_STATISTIC_TESSELLATION_EVALUATION_SHADER_INVOCATIONS_BIT,
    compute_shader_invocations = raw.VK_QUERY_PIPELINE_STATISTIC_COMPUTE_SHADER_INVOCATIONS_BIT,
    task_shader_invocations = raw.VK_QUERY_PIPELINE_STATISTIC_TASK_SHADER_INVOCATIONS_BIT_EXT,
    mesh_shader_invocations = raw.VK_QUERY_PIPELINE_STATISTIC_MESH_SHADER_INVOCATIONS_BIT_EXT,
    cluster_culling_shader_invocations = raw.VK_QUERY_PIPELINE_STATISTIC_CLUSTER_CULLING_SHADER_INVOCATIONS_BIT_HUAWEI,
};

pub const PipelineStatisticFlags = struct {
    bits: u32 = 0,

    pub const empty: PipelineStatisticFlags = .{};

    pub fn init(comptime values: []const PipelineStatisticBit) PipelineStatisticFlags {
        var bits: u32 = 0;
        inline for (values) |value| bits |= @intFromEnum(value);
        return .{ .bits = bits };
    }

    pub fn contains(flags: PipelineStatisticFlags, bit: PipelineStatisticBit) bool {
        return flags.bits & @intFromEnum(bit) != 0;
    }
};

pub const Performance = struct {
    queue_family: core.QueueFamilyIndex,
    counter_indices: []const u32,
};

pub const PerformanceCounterUnit = enum(raw.VkPerformanceCounterUnitKHR) {
    generic = raw.VK_PERFORMANCE_COUNTER_UNIT_GENERIC_KHR,
    percentage = raw.VK_PERFORMANCE_COUNTER_UNIT_PERCENTAGE_KHR,
    nanoseconds = raw.VK_PERFORMANCE_COUNTER_UNIT_NANOSECONDS_KHR,
    bytes = raw.VK_PERFORMANCE_COUNTER_UNIT_BYTES_KHR,
    bytes_per_second = raw.VK_PERFORMANCE_COUNTER_UNIT_BYTES_PER_SECOND_KHR,
    kelvin = raw.VK_PERFORMANCE_COUNTER_UNIT_KELVIN_KHR,
    watts = raw.VK_PERFORMANCE_COUNTER_UNIT_WATTS_KHR,
    volts = raw.VK_PERFORMANCE_COUNTER_UNIT_VOLTS_KHR,
    amps = raw.VK_PERFORMANCE_COUNTER_UNIT_AMPS_KHR,
    hertz = raw.VK_PERFORMANCE_COUNTER_UNIT_HERTZ_KHR,
    cycles = raw.VK_PERFORMANCE_COUNTER_UNIT_CYCLES_KHR,
    _,
};

pub const PerformanceCounterScope = enum(raw.VkPerformanceCounterScopeKHR) {
    command_buffer = raw.VK_PERFORMANCE_COUNTER_SCOPE_COMMAND_BUFFER_KHR,
    render_pass = raw.VK_PERFORMANCE_COUNTER_SCOPE_RENDER_PASS_KHR,
    command = raw.VK_PERFORMANCE_COUNTER_SCOPE_COMMAND_KHR,
    _,
};

pub const PerformanceCounterStorage = enum(raw.VkPerformanceCounterStorageKHR) {
    int32 = raw.VK_PERFORMANCE_COUNTER_STORAGE_INT32_KHR,
    int64 = raw.VK_PERFORMANCE_COUNTER_STORAGE_INT64_KHR,
    uint32 = raw.VK_PERFORMANCE_COUNTER_STORAGE_UINT32_KHR,
    uint64 = raw.VK_PERFORMANCE_COUNTER_STORAGE_UINT64_KHR,
    float32 = raw.VK_PERFORMANCE_COUNTER_STORAGE_FLOAT32_KHR,
    float64 = raw.VK_PERFORMANCE_COUNTER_STORAGE_FLOAT64_KHR,
    _,
};

pub const PerformanceCounter = struct {
    unit: PerformanceCounterUnit,
    scope: PerformanceCounterScope,
    storage: PerformanceCounterStorage,
    uuid: [16]u8,
    performance_impacting: bool,
    concurrently_impacted: bool,
    _name: [256]u8,
    _name_len: u16,
    _category: [256]u8,
    _category_len: u16,
    _description: [256]u8,
    _description_len: u16,

    pub fn name(counter: *const PerformanceCounter) []const u8 {
        return counter._name[0..counter._name_len];
    }

    pub fn category(counter: *const PerformanceCounter) []const u8 {
        return counter._category[0..counter._category_len];
    }

    pub fn description(counter: *const PerformanceCounter) []const u8 {
        return counter._description[0..counter._description_len];
    }

    pub fn fromRaw(
        counter: raw.VkPerformanceCounterKHR,
        description_value: raw.VkPerformanceCounterDescriptionKHR,
    ) PerformanceCounter {
        return .{
            .unit = @enumFromInt(counter.unit),
            .scope = @enumFromInt(counter.scope),
            .storage = @enumFromInt(counter.storage),
            .uuid = counter.uuid,
            .performance_impacting = description_value.flags & raw.VK_PERFORMANCE_COUNTER_DESCRIPTION_PERFORMANCE_IMPACTING_BIT_KHR != 0,
            .concurrently_impacted = description_value.flags & raw.VK_PERFORMANCE_COUNTER_DESCRIPTION_CONCURRENTLY_IMPACTED_BIT_KHR != 0,
            ._name = description_value.name,
            ._name_len = boundedLength(&description_value.name),
            ._category = description_value.category,
            ._category_len = boundedLength(&description_value.category),
            ._description = description_value.description,
            ._description_len = boundedLength(&description_value.description),
        };
    }
};

pub const Kind = union(enum) {
    occlusion,
    timestamp,
    pipeline_statistics: PipelineStatisticFlags,
    performance: Performance,
};

pub const Options = struct {
    kind: Kind,
    count: u32,
    next: ?*const anyopaque = null,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks = null,
};

pub const ResultOptions = struct {
    first: u32 = 0,
    count: u32,
    wait: bool = false,
    partial: bool = false,
    include_availability: bool = true,
};

pub const Results = struct {
    _owner: core.Owner,
    values: []u64,
    availability: ?[]bool,
    query_count: u32,
    values_per_query: u32,

    pub fn deinit(results: *Results, gpa: std.mem.Allocator) void {
        if (!(results._owner.release(results) catch return)) return;
        gpa.free(results.values);
        if (results.availability) |availability| gpa.free(availability);
        results.* = undefined;
    }

    pub fn query(results: Results, index: u32) core.Error![]const u64 {
        try results._owner.validate(&results);
        if (index >= results.query_count) return error.InvalidOptions;
        const start = @as(usize, index) * results.values_per_query;
        return results.values[start..][0..results.values_per_query];
    }
};

pub const ReadResult = union(enum) {
    ready: Results,
    partial: Results,
    not_ready,

    pub fn deinit(result: *ReadResult, gpa: std.mem.Allocator) void {
        switch (result.*) {
            .ready, .partial => |*values| values.deinit(gpa),
            .not_ready => {},
        }
        result.* = .not_ready;
    }
};

pub const CopyOptions = struct {
    first: u32 = 0,
    count: u32,
    destination: *const buffers.Buffer,
    offset: core.DeviceOffset = .zero,
    stride: core.DeviceSize,
    wait: bool = false,
    partial: bool = false,
    include_availability: bool = false,
};

pub const Dispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateQueryPool),
    destroy: CommandFunction(raw.PFN_vkDestroyQueryPool),
    get_results: CommandFunction(raw.PFN_vkGetQueryPoolResults),
    reset_host: ?CommandFunction(raw.PFN_vkResetQueryPool),
    begin: CommandFunction(raw.PFN_vkCmdBeginQuery),
    end: CommandFunction(raw.PFN_vkCmdEndQuery),
    reset: CommandFunction(raw.PFN_vkCmdResetQueryPool),
    write_timestamp: CommandFunction(raw.PFN_vkCmdWriteTimestamp),
    write_timestamp2: ?CommandFunction(raw.PFN_vkCmdWriteTimestamp2),
    copy_results: CommandFunction(raw.PFN_vkCmdCopyQueryPoolResults),
};

pub const Pool = struct {
    _handle: ?QueryPoolHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: *core.DeviceState,
    kind: Kind,
    count: u32,
    values_per_query: u32,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,

    pub fn deinit(pool: *Pool) void {
        if (!(pool._owner.release(pool) catch return)) return;
        const handle = pool._handle orelse return;
        pool.dispatch.destroy(pool._device_handle, handle, pool.allocation_callbacks);
        pool._handle = null;
    }

    pub fn rawHandle(pool: *const Pool) core.Error!raw.VkQueryPool {
        try pool._owner.validate(pool);
        try pool._device_state.ensureDispatchAllowed();
        return pool._handle orelse error.InactiveObject;
    }

    pub fn debugObject(pool: *const Pool) core.Error!debug_utils.Object {
        return .forDevice(.query_pool, try pool.rawHandle(), pool._device_handle);
    }

    pub fn reset(pool: *const Pool, first: u32, count: u32) core.Error!void {
        try pool._device_state.ensureDispatchAllowed();
        try pool.validateRange(first, count);
        const reset_host = pool.dispatch.reset_host orelse return error.MissingCommand;
        reset_host(pool._device_handle, try pool.rawHandle(), first, count);
    }

    pub fn begin(
        pool: *const Pool,
        command_buffer: *commands.Buffer,
        index: u32,
        precise: bool,
    ) core.Error!Scope {
        try pool.validateCommand(command_buffer, index);
        if (pool.isTimestamp()) return error.InvalidOptions;
        var owner = try core.Owner.init({});
        errdefer _ = owner.release({}) catch {};
        pool.dispatch.begin(
            try command_buffer.rawHandle(),
            try pool.rawHandle(),
            index,
            if (precise) raw.VK_QUERY_CONTROL_PRECISE_BIT else 0,
        );
        return .{ ._owner = owner, .pool = pool, .command_buffer = command_buffer, .index = index };
    }

    pub fn resetRecorded(
        pool: *const Pool,
        command_buffer: *commands.Buffer,
        first: u32,
        count: u32,
    ) core.Error!void {
        try pool.validateCommand(command_buffer, first);
        try pool.validateRange(first, count);
        pool.dispatch.reset(try command_buffer.rawHandle(), try pool.rawHandle(), first, count);
    }

    pub fn writeTimestamp(
        pool: *const Pool,
        command_buffer: *commands.Buffer,
        index: u32,
        stage: types.PipelineStageBit,
    ) core.Error!void {
        try pool.validateTimestamp(command_buffer, index);
        pool.dispatch.write_timestamp(
            try command_buffer.rawHandle(),
            stage.toRaw(),
            try pool.rawHandle(),
            index,
        );
    }

    pub fn writeTimestamp2(
        pool: *const Pool,
        command_buffer: *commands.Buffer,
        index: u32,
        stage: types.PipelineStage2Flags,
    ) core.Error!void {
        try pool.validateTimestamp(command_buffer, index);
        const write = pool.dispatch.write_timestamp2 orelse return error.MissingCommand;
        write(try command_buffer.rawHandle(), stage.toRaw(), try pool.rawHandle(), index);
    }

    pub fn copyResults(
        pool: *const Pool,
        command_buffer: *commands.Buffer,
        options: CopyOptions,
    ) core.Error!void {
        try pool.validateCommand(command_buffer, options.first);
        try pool.validateRange(options.first, options.count);
        if (options.destination._device_handle != pool._device_handle) return error.InvalidHandle;
        const minimum_stride = pool.resultStride(options.include_availability);
        if (options.stride.bytes() < minimum_stride) return error.InvalidOptions;
        const required = if (options.count == 0)
            0
        else blk: {
            const preceding = std.math.mul(u64, options.stride.bytes(), options.count - 1) catch return error.SizeOverflow;
            break :blk std.math.add(u64, preceding, minimum_stride) catch return error.SizeOverflow;
        };
        const available = options.destination.size.bytes() -| options.offset.bytes();
        if (required > available) return error.BufferTooSmall;
        pool.dispatch.copy_results(
            try command_buffer.rawHandle(),
            try pool.rawHandle(),
            options.first,
            options.count,
            try options.destination.rawHandle(),
            options.offset.bytes(),
            options.stride.bytes(),
            resultFlags(options.wait, options.partial, options.include_availability),
        );
    }

    pub fn getResults(
        pool: *const Pool,
        gpa: std.mem.Allocator,
        options: ResultOptions,
    ) (core.Error || std.mem.Allocator.Error)!ReadResult {
        try pool._device_state.ensureDispatchAllowed();
        try pool.validateRange(options.first, options.count);
        if (options.count == 0) {
            const values = try gpa.alloc(u64, 0);
            errdefer gpa.free(values);
            const availability = if (options.include_availability) try gpa.alloc(bool, 0) else null;
            errdefer if (availability) |items| gpa.free(items);
            return .{ .ready = .{
                ._owner = try .init(&values),
                .values = values,
                .availability = availability,
                .query_count = 0,
                .values_per_query = pool.values_per_query,
            } };
        }
        const include_availability = options.include_availability or options.partial;
        const words_per_query = pool.values_per_query + @intFromBool(include_availability);
        const word_count = std.math.mul(usize, options.count, words_per_query) catch return error.SizeOverflow;
        var words = try gpa.alloc(u64, word_count);
        defer gpa.free(words);
        @memset(words, 0);
        const result = pool.dispatch.get_results(
            pool._device_handle,
            try pool.rawHandle(),
            options.first,
            options.count,
            words.len * @sizeOf(u64),
            words.ptr,
            @as(u64, words_per_query) * @sizeOf(u64),
            resultFlags(options.wait, options.partial, include_availability),
        );
        const status = try core.classifyResultTracked(pool._device_state, result);
        if (status == .not_ready and !options.partial) return .not_ready;
        if (status != .success and status != .not_ready) return error.UnexpectedVulkanResult;

        const values = try gpa.alloc(u64, @as(usize, options.count) * pool.values_per_query);
        errdefer gpa.free(values);
        const availability = if (options.include_availability)
            try gpa.alloc(bool, options.count)
        else
            null;
        errdefer if (availability) |items| gpa.free(items);
        var all_available = true;
        for (0..options.count) |query_index| {
            const source = words[query_index * words_per_query ..][0..pool.values_per_query];
            const destination = values[query_index * pool.values_per_query ..][0..pool.values_per_query];
            @memcpy(destination, source);
            if (include_availability) {
                const item_available = words[query_index * words_per_query + pool.values_per_query] != 0;
                all_available = all_available and item_available;
                if (availability) |items| items[query_index] = item_available;
            }
        }
        const output: Results = .{
            ._owner = try .init(&values),
            .values = values,
            .availability = availability,
            .query_count = options.count,
            .values_per_query = pool.values_per_query,
        };
        return if (all_available and status == .success)
            .{ .ready = output }
        else
            .{ .partial = output };
    }

    fn validateRange(pool: *const Pool, first: u32, count: u32) core.Error!void {
        if (first > pool.count or count > pool.count - first) return error.InvalidOptions;
    }

    fn validateCommand(pool: *const Pool, command_buffer: *commands.Buffer, index: u32) core.Error!void {
        try pool._device_state.ensureDispatchAllowed();
        try pool.validateRange(index, 1);
        if (command_buffer._device_handle != pool._device_handle) return error.InvalidHandle;
    }

    fn validateTimestamp(pool: *const Pool, command_buffer: *commands.Buffer, index: u32) core.Error!void {
        try pool.validateCommand(command_buffer, index);
        if (!pool.isTimestamp()) return error.InvalidOptions;
    }

    fn resultStride(pool: *const Pool, include_availability: bool) u64 {
        return (@as(u64, pool.values_per_query) + @intFromBool(include_availability)) * @sizeOf(u64);
    }

    fn isTimestamp(pool: *const Pool) bool {
        return switch (pool.kind) {
            .timestamp => true,
            else => false,
        };
    }
};

pub const Scope = struct {
    _owner: core.Owner,
    pool: *const Pool,
    command_buffer: *commands.Buffer,
    index: u32,
    active: bool = true,

    pub fn end(scope: *Scope) core.Error!void {
        if (!(try scope._owner.release(scope))) return;
        if (!scope.active) return;
        try scope.pool.validateCommand(scope.command_buffer, scope.index);
        scope.pool.dispatch.end(
            try scope.command_buffer.rawHandle(),
            try scope.pool.rawHandle(),
            scope.index,
        );
        scope.active = false;
    }

    pub fn deinit(scope: *Scope) void {
        scope.end() catch {};
    }
};

pub const TimeDomain = enum(raw.VkTimeDomainKHR) {
    device = raw.VK_TIME_DOMAIN_DEVICE_KHR,
    clock_monotonic = raw.VK_TIME_DOMAIN_CLOCK_MONOTONIC_KHR,
    clock_monotonic_raw = raw.VK_TIME_DOMAIN_CLOCK_MONOTONIC_RAW_KHR,
    query_performance_counter = raw.VK_TIME_DOMAIN_QUERY_PERFORMANCE_COUNTER_KHR,
    _,
};

pub const CalibratedTimestamp = struct {
    domain: TimeDomain,
    value: u64,
};

pub const Calibration = struct {
    timestamps: []CalibratedTimestamp,
    max_deviation_nanoseconds: u64,
};

pub const ProfilingLock = struct {
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: *core.DeviceState,
    release: CommandFunction(raw.PFN_vkReleaseProfilingLockKHR),
    active: bool = true,

    pub fn deinit(lock: *ProfilingLock) void {
        if (!(lock._owner.release(lock) catch return)) return;
        if (!lock.active) return;
        lock.release(lock._device_handle);
        lock.active = false;
    }
};

pub fn create(
    device_handle: DeviceHandle,
    device_state: *core.DeviceState,
    dispatch: Dispatch,
    options: Options,
) core.Error!Pool {
    try device_state.ensureDispatchAllowed();
    if (options.count == 0) return error.InvalidOptions;
    var performance_info: raw.VkQueryPoolPerformanceCreateInfoKHR = .{
        .sType = raw.VK_STRUCTURE_TYPE_QUERY_POOL_PERFORMANCE_CREATE_INFO_KHR,
    };
    const query_type: raw.VkQueryType = switch (options.kind) {
        .occlusion => raw.VK_QUERY_TYPE_OCCLUSION,
        .timestamp => raw.VK_QUERY_TYPE_TIMESTAMP,
        .pipeline_statistics => raw.VK_QUERY_TYPE_PIPELINE_STATISTICS,
        .performance => |performance| blk: {
            if (performance.counter_indices.len == 0) return error.InvalidOptions;
            performance_info.queueFamilyIndex = performance.queue_family.toRaw();
            performance_info.counterIndexCount = try core.count32(performance.counter_indices.len);
            performance_info.pCounterIndices = performance.counter_indices.ptr;
            performance_info.pNext = options.next;
            break :blk raw.VK_QUERY_TYPE_PERFORMANCE_QUERY_KHR;
        },
    };
    const statistics: raw.VkQueryPipelineStatisticFlags = switch (options.kind) {
        .pipeline_statistics => |flags| if (flags.bits == 0) return error.InvalidOptions else @intCast(flags.bits),
        else => 0,
    };
    const create_info: raw.VkQueryPoolCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO,
        .pNext = switch (options.kind) {
            .performance => &performance_info,
            else => options.next,
        },
        .queryType = query_type,
        .queryCount = options.count,
        .pipelineStatistics = statistics,
    };
    var handle: raw.VkQueryPool = null;
    const result = dispatch.create(device_handle, &create_info, options.allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, options.allocation_callbacks);
        try core.checkSuccessTracked(device_state, result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._owner = try .init(&handle),
        ._device_handle = device_handle,
        ._device_state = device_state,
        .kind = options.kind,
        .count = options.count,
        .values_per_query = switch (options.kind) {
            .pipeline_statistics => |flags| @popCount(flags.bits),
            .performance => |performance| @intCast(performance.counter_indices.len),
            else => 1,
        },
        .allocation_callbacks = options.allocation_callbacks,
        .dispatch = dispatch,
    };
}

fn resultFlags(wait: bool, partial: bool, availability: bool) raw.VkQueryResultFlags {
    var flags: raw.VkQueryResultFlags = raw.VK_QUERY_RESULT_64_BIT;
    if (wait) flags |= raw.VK_QUERY_RESULT_WAIT_BIT;
    if (partial) flags |= raw.VK_QUERY_RESULT_PARTIAL_BIT;
    if (availability) flags |= raw.VK_QUERY_RESULT_WITH_AVAILABILITY_BIT;
    return flags;
}

fn boundedLength(bytes: []const u8) u16 {
    return @intCast(std.mem.indexOfScalar(u8, bytes, 0) orelse bytes.len);
}

test "all query declarations compile" {
    std.testing.refAllDecls(@This());
}

var test_result: raw.VkResult = raw.VK_SUCCESS;
var test_destroy_count: usize = 0;

fn testHandle(comptime OptionalHandle: type, address: usize) core.NonNullHandle(OptionalHandle) {
    return @ptrFromInt(address);
}

fn testFunction(comptime OptionalFunction: type) CommandFunction(OptionalFunction) {
    return @ptrFromInt(0x1000);
}

fn testCreate(
    _: raw.VkDevice,
    _: [*c]const raw.VkQueryPoolCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkQueryPool,
) callconv(.c) raw.VkResult {
    output.* = testHandle(raw.VkQueryPool, 0x7000);
    return test_result;
}

fn testDestroy(
    _: raw.VkDevice,
    _: raw.VkQueryPool,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_count += 1;
}

fn testGetResults(
    _: raw.VkDevice,
    _: raw.VkQueryPool,
    _: u32,
    query_count: u32,
    _: usize,
    data: ?*anyopaque,
    stride: u64,
    flags: raw.VkQueryResultFlags,
) callconv(.c) raw.VkResult {
    if (test_result == raw.VK_NOT_READY and flags & raw.VK_QUERY_RESULT_PARTIAL_BIT == 0) {
        return test_result;
    }
    const bytes: [*]u8 = @ptrCast(data.?);
    for (0..query_count) |index| {
        const words: [*]u64 = @ptrCast(@alignCast(bytes + index * stride));
        words[0] = 100 + index;
        if (flags & raw.VK_QUERY_RESULT_WITH_AVAILABILITY_BIT != 0) {
            words[1] = if (test_result == raw.VK_SUCCESS or index == 0) 1 else 0;
        }
    }
    return test_result;
}

fn testDispatch() Dispatch {
    return .{
        .create = testCreate,
        .destroy = testDestroy,
        .get_results = testGetResults,
        .reset_host = testFunction(raw.PFN_vkResetQueryPool),
        .begin = testFunction(raw.PFN_vkCmdBeginQuery),
        .end = testFunction(raw.PFN_vkCmdEndQuery),
        .reset = testFunction(raw.PFN_vkCmdResetQueryPool),
        .write_timestamp = testFunction(raw.PFN_vkCmdWriteTimestamp),
        .write_timestamp2 = testFunction(raw.PFN_vkCmdWriteTimestamp2),
        .copy_results = testFunction(raw.PFN_vkCmdCopyQueryPoolResults),
    };
}

test "query results keep ready not-ready and partial distinct" {
    var state = try core.DeviceState.init();
    defer state.markDestroyed();
    test_result = raw.VK_SUCCESS;
    test_destroy_count = 0;
    var pool = try create(
        testHandle(raw.VkDevice, 0x2000),
        &state,
        testDispatch(),
        .{ .kind = .timestamp, .count = 2 },
    );
    defer pool.deinit();

    var ready = try pool.getResults(std.testing.allocator, .{ .count = 2 });
    defer ready.deinit(std.testing.allocator);
    switch (ready) {
        .ready => |results| {
            try std.testing.expectEqualSlices(u64, &.{ 100, 101 }, results.values);
            try std.testing.expectEqualSlices(bool, &.{ true, true }, results.availability.?);
        },
        else => return error.UnexpectedVulkanResult,
    }

    test_result = raw.VK_NOT_READY;
    try std.testing.expectEqual(ReadResult.not_ready, try pool.getResults(
        std.testing.allocator,
        .{ .count = 2, .include_availability = false },
    ));

    var partial = try pool.getResults(std.testing.allocator, .{ .count = 2, .partial = true });
    defer partial.deinit(std.testing.allocator);
    switch (partial) {
        .partial => |results| try std.testing.expectEqualSlices(bool, &.{ true, false }, results.availability.?),
        else => return error.UnexpectedVulkanResult,
    }
    test_result = raw.VK_SUCCESS;
}

test "query creation validates kind and cleanup is idempotent" {
    var state = try core.DeviceState.init();
    defer state.markDestroyed();
    try std.testing.expectError(error.InvalidOptions, create(
        testHandle(raw.VkDevice, 0x2000),
        &state,
        testDispatch(),
        .{ .kind = .{ .pipeline_statistics = .empty }, .count = 1 },
    ));
    var pool = try create(
        testHandle(raw.VkDevice, 0x2000),
        &state,
        testDispatch(),
        .{ .kind = .occlusion, .count = 1 },
    );
    test_destroy_count = 0;
    pool.deinit();
    pool.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_count);
}
