const std = @import("std");
const raw = @import("vulkan_raw");
const commands = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const image = @import("image.zig");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = commands.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const CommandPoolHandle = core.NonNullHandle(raw.VkCommandPool);
const CommandBufferHandle = core.NonNullHandle(raw.VkCommandBuffer);

pub const PoolOptions = struct {
    family_index: core.QueueFamilyIndex,
    flags: types.CommandPoolCreateFlags = .empty,
};

pub const Options = struct {
    level: types.CommandBufferLevel = .primary,
};

pub const SecondaryInheritance = struct {
    occlusion_query_enable: bool = false,
};

pub const BeginOptions = struct {
    flags: types.CommandBufferUsageFlags = .empty,
    inheritance: ?SecondaryInheritance = null,
};

pub const ImageBarrierOptions = struct {
    source_stage: types.PipelineStageFlags,
    destination_stage: types.PipelineStageFlags,
    source_access: types.AccessFlags = .empty,
    destination_access: types.AccessFlags = .empty,
    old_layout: types.ImageLayout,
    new_layout: types.ImageLayout,
    ownership: core.QueueFamilyOwnership = .ignored,
    image: *const image.SwapchainImage,
    subresource_range: types.ImageSubresourceRange,
};

pub const ClearColorImageOptions = struct {
    image: *const image.SwapchainImage,
    layout: types.ImageLayout,
    color: types.ClearColor,
    subresource_range: types.ImageSubresourceRange,
};

pub const State = enum {
    initial,
    recording,
    executable,
    pending,
};

pub const Buffer = struct {
    _handle: ?CommandBufferHandle,
    _device_handle: DeviceHandle,
    _pool: *Pool,
    _pool_generation: u64,
    level: types.CommandBufferLevel,
    can_reset: bool,
    state: State = .initial,
    simultaneous_use: bool = false,
    pending_submissions: usize = 0,
    begin_command_buffer: CommandFunction(raw.PFN_vkBeginCommandBuffer),
    end_command_buffer: CommandFunction(raw.PFN_vkEndCommandBuffer),
    reset_command_buffer: CommandFunction(raw.PFN_vkResetCommandBuffer),
    cmd_pipeline_barrier: CommandFunction(raw.PFN_vkCmdPipelineBarrier),
    cmd_clear_color_image: CommandFunction(raw.PFN_vkCmdClearColorImage),
    cmd_begin_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdBeginDebugUtilsLabelEXT),
    cmd_end_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdEndDebugUtilsLabelEXT),
    cmd_insert_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdInsertDebugUtilsLabelEXT),

    fn liveHandle(buffer: *Buffer) core.Error!CommandBufferHandle {
        const handle = buffer._handle orelse return error.InactiveObject;
        _ = buffer._pool._handle orelse return error.InactiveObject;
        if (buffer._pool_generation != buffer._pool.generation) {
            buffer._pool_generation = buffer._pool.generation;
            buffer.state = .initial;
            buffer.simultaneous_use = false;
            buffer.pending_submissions = 0;
        }
        return handle;
    }

    pub fn deinit(buffer: *Buffer) void {
        const handle = buffer._handle orelse return;
        const pool_handle = buffer._pool._handle orelse {
            buffer._handle = null;
            return;
        };
        if (buffer._pool_generation != buffer._pool.generation) {
            buffer._pool_generation = buffer._pool.generation;
            buffer.state = .initial;
            buffer.pending_submissions = 0;
        }
        if (buffer.state == .pending) return;
        buffer._pool.free_command_buffers(
            buffer._device_handle,
            pool_handle,
            1,
            @ptrCast(&handle),
        );
        buffer._handle = null;
    }

    pub fn begin(buffer: *Buffer, options: BeginOptions) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .initial) return error.InvalidOptions;
        if ((buffer.level == .secondary) != (options.inheritance != null)) {
            return error.InvalidOptions;
        }
        var inheritance_info: raw.VkCommandBufferInheritanceInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_COMMAND_BUFFER_INHERITANCE_INFO,
            .occlusionQueryEnable = if (options.inheritance) |inheritance|
                if (inheritance.occlusion_query_enable) raw.VK_TRUE else raw.VK_FALSE
            else
                raw.VK_FALSE,
        };
        const begin_info: raw.VkCommandBufferBeginInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = options.flags.toRaw(),
            .pInheritanceInfo = if (options.inheritance != null) &inheritance_info else null,
        };
        try core.checkSuccess(buffer.begin_command_buffer(handle, &begin_info));
        buffer.state = .recording;
        buffer.simultaneous_use = options.flags.contains(.simultaneous_use);
    }

    pub fn end(buffer: *Buffer) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording) return error.InvalidOptions;
        try core.checkSuccess(buffer.end_command_buffer(handle));
        buffer.state = .executable;
    }

    pub fn reset(buffer: *Buffer, release_resources: bool) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state == .recording or buffer.state == .pending) return error.InvalidOptions;
        if (!buffer.can_reset) return error.InvalidOptions;
        const flags: raw.VkCommandBufferResetFlags = if (release_resources)
            @intCast(raw.VK_COMMAND_BUFFER_RESET_RELEASE_RESOURCES_BIT)
        else
            0;
        try core.checkSuccess(buffer.reset_command_buffer(handle, flags));
        buffer.state = .initial;
        buffer.simultaneous_use = false;
        buffer.pending_submissions = 0;
    }

    pub fn markComplete(buffer: *Buffer) core.Error!void {
        _ = try buffer.liveHandle();
        if (buffer.state != .pending) return error.InvalidOptions;
        std.debug.assert(buffer.pending_submissions > 0);
        buffer.pending_submissions -= 1;
        if (buffer.pending_submissions == 0) buffer.state = .executable;
    }

    pub fn canSubmit(buffer: *Buffer) core.Error!bool {
        _ = try buffer.liveHandle();
        return buffer.state == .executable or
            (buffer.state == .pending and buffer.simultaneous_use);
    }

    pub fn markSubmitted(buffer: *Buffer) core.Error!void {
        _ = try buffer.liveHandle();
        if (!try buffer.canSubmit()) return error.InvalidOptions;
        if (buffer.pending_submissions == std.math.maxInt(usize)) return error.CountOverflow;
        buffer.state = .pending;
        buffer.pending_submissions += 1;
    }

    pub fn imageBarrier(buffer: *Buffer, options: ImageBarrierOptions) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording) return error.InvalidOptions;
        if (options.image._device_handle != buffer._device_handle) return error.InvalidHandle;
        const barrier: raw.VkImageMemoryBarrier = .{
            .sType = raw.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            .srcAccessMask = options.source_access.toRaw(),
            .dstAccessMask = options.destination_access.toRaw(),
            .oldLayout = options.old_layout.toRaw(),
            .newLayout = options.new_layout.toRaw(),
            .srcQueueFamilyIndex = options.ownership.sourceRaw(),
            .dstQueueFamilyIndex = options.ownership.destinationRaw(),
            .image = options.image._handle,
            .subresourceRange = options.subresource_range.toRaw(),
        };
        buffer.cmd_pipeline_barrier(
            handle,
            options.source_stage.toRaw(),
            options.destination_stage.toRaw(),
            0,
            0,
            null,
            0,
            null,
            1,
            &barrier,
        );
    }

    pub fn clearColorImage(buffer: *Buffer, options: ClearColorImageOptions) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording) return error.InvalidOptions;
        if (options.image._device_handle != buffer._device_handle) return error.InvalidHandle;
        const color = options.color.toRaw();
        const range = options.subresource_range.toRaw();
        buffer.cmd_clear_color_image(
            handle,
            options.image._handle,
            options.layout.toRaw(),
            &color,
            1,
            &range,
        );
    }

    pub fn beginLabel(buffer: *Buffer, options: debug_utils.LabelOptions) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording) return error.InvalidOptions;
        const begin_label = buffer.cmd_begin_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        const label = options.toRaw();
        begin_label(handle, &label);
    }

    pub fn beginLabelScope(
        buffer: *Buffer,
        options: debug_utils.LabelOptions,
    ) core.Error!LabelScope {
        const end_label = buffer.cmd_end_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        try buffer.beginLabel(options);
        return .{ .command_buffer = try buffer.liveHandle(), .end_label = end_label };
    }

    pub fn endLabel(buffer: *Buffer) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording) return error.InvalidOptions;
        const end_label = buffer.cmd_end_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        end_label(handle);
    }

    pub fn insertLabel(buffer: *Buffer, options: debug_utils.LabelOptions) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording) return error.InvalidOptions;
        const insert_label = buffer.cmd_insert_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        const label = options.toRaw();
        insert_label(handle, &label);
    }

    pub fn rawHandle(buffer: *Buffer) core.Error!raw.VkCommandBuffer {
        return try buffer.liveHandle();
    }

    pub fn debugObject(buffer: *Buffer) core.Error!debug_utils.Object {
        return .forDevice(.command_buffer, try buffer.rawHandle(), buffer._device_handle);
    }
};

pub const LabelScope = struct {
    command_buffer: CommandBufferHandle,
    end_label: CommandFunction(raw.PFN_vkCmdEndDebugUtilsLabelEXT),
    active: bool = true,

    pub fn end(scope: *LabelScope) void {
        if (!scope.active) return;
        scope.end_label(scope.command_buffer);
        scope.active = false;
    }

    pub fn deinit(scope: *LabelScope) void {
        scope.end();
    }
};

pub const Pool = struct {
    _handle: ?CommandPoolHandle,
    _device_handle: DeviceHandle,
    buffers_can_reset: bool,
    generation: u64 = 0,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_command_pool: CommandFunction(raw.PFN_vkDestroyCommandPool),
    allocate_command_buffers: CommandFunction(raw.PFN_vkAllocateCommandBuffers),
    free_command_buffers: CommandFunction(raw.PFN_vkFreeCommandBuffers),
    reset_command_pool: CommandFunction(raw.PFN_vkResetCommandPool),
    begin_command_buffer: CommandFunction(raw.PFN_vkBeginCommandBuffer),
    end_command_buffer: CommandFunction(raw.PFN_vkEndCommandBuffer),
    reset_command_buffer: CommandFunction(raw.PFN_vkResetCommandBuffer),
    cmd_pipeline_barrier: CommandFunction(raw.PFN_vkCmdPipelineBarrier),
    cmd_clear_color_image: CommandFunction(raw.PFN_vkCmdClearColorImage),
    cmd_begin_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdBeginDebugUtilsLabelEXT),
    cmd_end_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdEndDebugUtilsLabelEXT),
    cmd_insert_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdInsertDebugUtilsLabelEXT),

    pub fn deinit(pool: *Pool) void {
        const handle = pool._handle orelse return;
        pool.destroy_command_pool(pool._device_handle, handle, pool.allocation_callbacks);
        pool._handle = null;
        pool.generation +%= 1;
    }

    pub fn allocateCommandBuffer(pool: *Pool, options: Options) core.Error!Buffer {
        const pool_handle = pool._handle orelse return error.InactiveObject;
        const allocate_info: raw.VkCommandBufferAllocateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = pool_handle,
            .level = options.level.toRaw(),
            .commandBufferCount = 1,
        };
        var handle: raw.VkCommandBuffer = null;
        try core.checkSuccess(pool.allocate_command_buffers(
            pool._device_handle,
            &allocate_info,
            &handle,
        ));
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._device_handle = pool._device_handle,
            ._pool = pool,
            ._pool_generation = pool.generation,
            .level = options.level,
            .can_reset = pool.buffers_can_reset,
            .begin_command_buffer = pool.begin_command_buffer,
            .end_command_buffer = pool.end_command_buffer,
            .reset_command_buffer = pool.reset_command_buffer,
            .cmd_pipeline_barrier = pool.cmd_pipeline_barrier,
            .cmd_clear_color_image = pool.cmd_clear_color_image,
            .cmd_begin_debug_utils_label_ext = pool.cmd_begin_debug_utils_label_ext,
            .cmd_end_debug_utils_label_ext = pool.cmd_end_debug_utils_label_ext,
            .cmd_insert_debug_utils_label_ext = pool.cmd_insert_debug_utils_label_ext,
        };
    }

    pub fn freeCommandBuffer(pool: *Pool, buffer: *Buffer) core.Error!void {
        const pool_handle = pool._handle orelse return error.InactiveObject;
        if (buffer._pool != pool or buffer._device_handle != pool._device_handle) {
            return error.InvalidHandle;
        }
        const handle = buffer._handle orelse return;
        if (buffer.state == .pending) return error.InvalidOptions;
        pool.free_command_buffers(pool._device_handle, pool_handle, 1, @ptrCast(&handle));
        buffer._handle = null;
    }

    pub fn reset(pool: *Pool, release_resources: bool) core.Error!void {
        const handle = pool._handle orelse return error.InactiveObject;
        const flags: raw.VkCommandPoolResetFlags = if (release_resources)
            @intCast(raw.VK_COMMAND_POOL_RESET_RELEASE_RESOURCES_BIT)
        else
            0;
        try core.checkSuccess(pool.reset_command_pool(pool._device_handle, handle, flags));
        pool.generation +%= 1;
    }

    pub fn rawHandle(pool: *const Pool) core.Error!raw.VkCommandPool {
        return pool._handle orelse error.InactiveObject;
    }

    pub fn debugObject(pool: *const Pool) core.Error!debug_utils.Object {
        return .forDevice(.command_pool, try pool.rawHandle(), pool._device_handle);
    }
};
