const std = @import("std");
const raw = @import("vulkan_raw");
const commands = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const image = @import("image.zig");
const debug_utils = @import("debug_utils.zig");
const sync = @import("synchronization.zig");
const rendering = @import("rendering.zig");
const transfer = @import("transfer.zig");
const buffers = @import("buffer.zig");
const sampler = @import("sampler.zig");
const pipeline = @import("pipeline.zig");
const descriptor = @import("descriptor.zig");

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
    image: image.Reference,
    layout: types.ImageLayout,
    color: types.ClearColor,
    subresource_range: types.ImageSubresourceRange,
};

pub const ClearDepthStencilImageOptions = struct {
    image: image.Reference,
    layout: types.ImageLayout,
    value: types.ClearDepthStencil,
    subresource_range: types.ImageSubresourceRange,
};

pub const VertexBufferBinding = struct { buffer: *const buffers.Buffer, offset: core.DeviceOffset = .zero };

pub const IndexType = enum {
    uint16,
    uint32,
    uint8,

    fn toRaw(value: IndexType) raw.VkIndexType {
        return switch (value) {
            .uint16 => raw.VK_INDEX_TYPE_UINT16,
            .uint32 => raw.VK_INDEX_TYPE_UINT32,
            .uint8 => raw.VK_INDEX_TYPE_UINT8,
        };
    }
};

pub const DrawOptions = struct { vertex_count: u32, instance_count: u32 = 1, first_vertex: u32 = 0, first_instance: u32 = 0 };
pub const DrawIndexedOptions = struct { index_count: u32, instance_count: u32 = 1, first_index: u32 = 0, vertex_offset: i32 = 0, first_instance: u32 = 0 };
pub const DispatchOptions = struct { x: u32, y: u32 = 1, z: u32 = 1 };

pub const State = enum {
    initial,
    recording,
    executable,
    pending,
};

const DependencyStorage = struct {
    memory: [64]raw.VkMemoryBarrier2 = undefined,
    buffers: [64]raw.VkBufferMemoryBarrier2 = undefined,
    images: [64]raw.VkImageMemoryBarrier2 = undefined,
    info: raw.VkDependencyInfo = .{ .sType = raw.VK_STRUCTURE_TYPE_DEPENDENCY_INFO },

    fn init(storage: *DependencyStorage, dependency: sync.DependencyInfo) core.Error!void {
        if (dependency.memory_barriers.len > storage.memory.len or
            dependency.buffer_barriers.len > storage.buffers.len or
            dependency.image_barriers.len > storage.images.len)
        {
            return error.CountOverflow;
        }
        for (dependency.memory_barriers, 0..) |barrier, index| storage.memory[index] = barrier.toRaw();
        for (dependency.buffer_barriers, 0..) |barrier, index| storage.buffers[index] = try barrier.toRaw();
        for (dependency.image_barriers, 0..) |barrier, index| storage.images[index] = try barrier.toRaw();
        storage.info = .{
            .sType = raw.VK_STRUCTURE_TYPE_DEPENDENCY_INFO,
            .dependencyFlags = dependency.flags.toRaw(),
            .memoryBarrierCount = @intCast(dependency.memory_barriers.len),
            .pMemoryBarriers = if (dependency.memory_barriers.len == 0) null else storage.memory[0..dependency.memory_barriers.len].ptr,
            .bufferMemoryBarrierCount = @intCast(dependency.buffer_barriers.len),
            .pBufferMemoryBarriers = if (dependency.buffer_barriers.len == 0) null else storage.buffers[0..dependency.buffer_barriers.len].ptr,
            .imageMemoryBarrierCount = @intCast(dependency.image_barriers.len),
            .pImageMemoryBarriers = if (dependency.image_barriers.len == 0) null else storage.images[0..dependency.image_barriers.len].ptr,
        };
    }
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
    rendering_active: bool = false,
    graphics_pipeline_bound: bool = false,
    compute_pipeline_bound: bool = false,
    begin_command_buffer: CommandFunction(raw.PFN_vkBeginCommandBuffer),
    end_command_buffer: CommandFunction(raw.PFN_vkEndCommandBuffer),
    reset_command_buffer: CommandFunction(raw.PFN_vkResetCommandBuffer),
    cmd_pipeline_barrier: CommandFunction(raw.PFN_vkCmdPipelineBarrier),
    cmd_pipeline_barrier2: ?CommandFunction(raw.PFN_vkCmdPipelineBarrier2),
    cmd_set_event2: ?CommandFunction(raw.PFN_vkCmdSetEvent2),
    cmd_reset_event2: ?CommandFunction(raw.PFN_vkCmdResetEvent2),
    cmd_wait_events2: ?CommandFunction(raw.PFN_vkCmdWaitEvents2),
    cmd_begin_rendering: ?CommandFunction(raw.PFN_vkCmdBeginRendering),
    cmd_end_rendering: ?CommandFunction(raw.PFN_vkCmdEndRendering),
    cmd_clear_color_image: CommandFunction(raw.PFN_vkCmdClearColorImage),
    cmd_clear_depth_stencil_image: CommandFunction(raw.PFN_vkCmdClearDepthStencilImage),
    cmd_fill_buffer: CommandFunction(raw.PFN_vkCmdFillBuffer),
    cmd_update_buffer: CommandFunction(raw.PFN_vkCmdUpdateBuffer),
    cmd_copy_buffer: CommandFunction(raw.PFN_vkCmdCopyBuffer),
    cmd_copy_buffer2: ?CommandFunction(raw.PFN_vkCmdCopyBuffer2),
    cmd_copy_buffer_to_image: CommandFunction(raw.PFN_vkCmdCopyBufferToImage),
    cmd_copy_image_to_buffer: CommandFunction(raw.PFN_vkCmdCopyImageToBuffer),
    cmd_copy_image: CommandFunction(raw.PFN_vkCmdCopyImage),
    cmd_blit_image: CommandFunction(raw.PFN_vkCmdBlitImage),
    cmd_resolve_image: CommandFunction(raw.PFN_vkCmdResolveImage),
    cmd_bind_pipeline: CommandFunction(raw.PFN_vkCmdBindPipeline),
    cmd_bind_descriptor_sets: CommandFunction(raw.PFN_vkCmdBindDescriptorSets),
    cmd_bind_vertex_buffers: CommandFunction(raw.PFN_vkCmdBindVertexBuffers),
    cmd_bind_index_buffer: CommandFunction(raw.PFN_vkCmdBindIndexBuffer),
    cmd_set_viewport: CommandFunction(raw.PFN_vkCmdSetViewport),
    cmd_set_scissor: CommandFunction(raw.PFN_vkCmdSetScissor),
    cmd_set_line_width: CommandFunction(raw.PFN_vkCmdSetLineWidth),
    cmd_set_depth_bias: CommandFunction(raw.PFN_vkCmdSetDepthBias),
    cmd_set_blend_constants: CommandFunction(raw.PFN_vkCmdSetBlendConstants),
    cmd_set_depth_bounds: CommandFunction(raw.PFN_vkCmdSetDepthBounds),
    cmd_push_constants: CommandFunction(raw.PFN_vkCmdPushConstants),
    cmd_draw: CommandFunction(raw.PFN_vkCmdDraw),
    cmd_draw_indexed: CommandFunction(raw.PFN_vkCmdDrawIndexed),
    cmd_draw_indirect: CommandFunction(raw.PFN_vkCmdDrawIndirect),
    cmd_draw_indexed_indirect: CommandFunction(raw.PFN_vkCmdDrawIndexedIndirect),
    cmd_draw_indirect_count: ?CommandFunction(raw.PFN_vkCmdDrawIndirectCount),
    cmd_draw_indexed_indirect_count: ?CommandFunction(raw.PFN_vkCmdDrawIndexedIndirectCount),
    cmd_dispatch: CommandFunction(raw.PFN_vkCmdDispatch),
    cmd_dispatch_indirect: CommandFunction(raw.PFN_vkCmdDispatchIndirect),
    cmd_dispatch_base: ?CommandFunction(raw.PFN_vkCmdDispatchBase),
    cmd_execute_commands: CommandFunction(raw.PFN_vkCmdExecuteCommands),
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
            buffer.rendering_active = false;
            buffer.graphics_pipeline_bound = false;
            buffer.compute_pipeline_bound = false;
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
            buffer.simultaneous_use = false;
            buffer.pending_submissions = 0;
            buffer.rendering_active = false;
            buffer.graphics_pipeline_bound = false;
            buffer.compute_pipeline_bound = false;
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
        buffer.rendering_active = false;
        buffer.graphics_pipeline_bound = false;
        buffer.compute_pipeline_bound = false;
    }

    pub fn end(buffer: *Buffer) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or buffer.rendering_active) return error.InvalidOptions;
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
        buffer.rendering_active = false;
        buffer.graphics_pipeline_bound = false;
        buffer.compute_pipeline_bound = false;
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

    pub fn pipelineBarrier(buffer: *Buffer, dependency: sync.DependencyInfo) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording) return error.InvalidOptions;
        const barrier2 = buffer.cmd_pipeline_barrier2 orelse return error.MissingCommand;
        if (dependency.memory_barriers.len > 64 or dependency.buffer_barriers.len > 64 or
            dependency.image_barriers.len > 64)
        {
            return error.CountOverflow;
        }
        var memory_barriers: [64]raw.VkMemoryBarrier2 = undefined;
        for (dependency.memory_barriers, 0..) |barrier, index| memory_barriers[index] = barrier.toRaw();
        var buffer_barriers: [64]raw.VkBufferMemoryBarrier2 = undefined;
        for (dependency.buffer_barriers, 0..) |barrier, index| {
            if (barrier.buffer._device_handle != buffer._device_handle) return error.InvalidHandle;
            buffer_barriers[index] = try barrier.toRaw();
        }
        var image_barriers: [64]raw.VkImageMemoryBarrier2 = undefined;
        for (dependency.image_barriers, 0..) |barrier, index| {
            if (barrier.image.deviceHandle() != buffer._device_handle) return error.InvalidHandle;
            image_barriers[index] = try barrier.toRaw();
        }
        const info: raw.VkDependencyInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_DEPENDENCY_INFO,
            .dependencyFlags = dependency.flags.toRaw(),
            .memoryBarrierCount = @intCast(dependency.memory_barriers.len),
            .pMemoryBarriers = if (dependency.memory_barriers.len == 0) null else memory_barriers[0..dependency.memory_barriers.len].ptr,
            .bufferMemoryBarrierCount = @intCast(dependency.buffer_barriers.len),
            .pBufferMemoryBarriers = if (dependency.buffer_barriers.len == 0) null else buffer_barriers[0..dependency.buffer_barriers.len].ptr,
            .imageMemoryBarrierCount = @intCast(dependency.image_barriers.len),
            .pImageMemoryBarriers = if (dependency.image_barriers.len == 0) null else image_barriers[0..dependency.image_barriers.len].ptr,
        };
        barrier2(handle, &info);
    }

    pub fn setEvent(
        buffer: *Buffer,
        event: *const sync.Event,
        dependency: sync.DependencyInfo,
    ) core.Error!void {
        if (event._device_handle != buffer._device_handle) return error.InvalidHandle;
        if (buffer.state != .recording) return error.InvalidOptions;
        const command = buffer.cmd_set_event2 orelse return error.MissingCommand;
        var storage: DependencyStorage = .{};
        try storage.init(dependency);
        command(try buffer.liveHandle(), try event.rawHandle(), &storage.info);
    }

    pub fn resetEvent(
        buffer: *Buffer,
        event: *const sync.Event,
        stages: types.PipelineStage2Flags,
    ) core.Error!void {
        if (event._device_handle != buffer._device_handle or stages.isEmpty() or buffer.state != .recording) return error.InvalidOptions;
        const command = buffer.cmd_reset_event2 orelse return error.MissingCommand;
        command(try buffer.liveHandle(), try event.rawHandle(), stages.toRaw());
    }

    pub fn waitEvent(
        buffer: *Buffer,
        event: *const sync.Event,
        dependency: sync.DependencyInfo,
    ) core.Error!void {
        if (event._device_handle != buffer._device_handle) return error.InvalidHandle;
        if (buffer.state != .recording) return error.InvalidOptions;
        const command = buffer.cmd_wait_events2 orelse return error.MissingCommand;
        const event_handle = try event.rawHandle();
        var storage: DependencyStorage = .{};
        try storage.init(dependency);
        command(try buffer.liveHandle(), 1, @ptrCast(&event_handle), &storage.info);
    }

    pub fn beginRendering(
        buffer: *Buffer,
        options: rendering.Options,
    ) core.Error!RenderingScope {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or buffer.rendering_active) return error.InvalidOptions;
        const begin_rendering = buffer.cmd_begin_rendering orelse return error.MissingCommand;
        try options.validate(buffer._device_handle);
        var color_attachments: [16]raw.VkRenderingAttachmentInfo = undefined;
        for (options.color_attachments, 0..) |attachment, index| {
            color_attachments[index] = try attachment.toRaw();
        }
        var depth_attachment: raw.VkRenderingAttachmentInfo = undefined;
        if (options.depth_attachment) |attachment| depth_attachment = try attachment.toRaw();
        var stencil_attachment: raw.VkRenderingAttachmentInfo = undefined;
        if (options.stencil_attachment) |attachment| stencil_attachment = try attachment.toRaw();
        const info: raw.VkRenderingInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_RENDERING_INFO,
            .flags = options.flags.toRaw(),
            .renderArea = options.render_area.toRaw(),
            .layerCount = options.layer_count,
            .viewMask = options.view_mask,
            .colorAttachmentCount = @intCast(options.color_attachments.len),
            .pColorAttachments = if (options.color_attachments.len == 0) null else color_attachments[0..options.color_attachments.len].ptr,
            .pDepthAttachment = if (options.depth_attachment != null) &depth_attachment else null,
            .pStencilAttachment = if (options.stencil_attachment != null) &stencil_attachment else null,
        };
        begin_rendering(handle, &info);
        buffer.rendering_active = true;
        return .{ .buffer = buffer };
    }

    pub fn endRendering(buffer: *Buffer) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or !buffer.rendering_active) return error.InvalidOptions;
        const end_rendering = buffer.cmd_end_rendering orelse return error.MissingCommand;
        end_rendering(handle);
        buffer.rendering_active = false;
    }

    pub fn clearColorImage(buffer: *Buffer, options: ClearColorImageOptions) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording) return error.InvalidOptions;
        if (options.image.deviceHandle() != buffer._device_handle) return error.InvalidHandle;
        const color = options.color.toRaw();
        const range = options.subresource_range.toRaw();
        buffer.cmd_clear_color_image(
            handle,
            try options.image.handle(),
            options.layout.toRaw(),
            &color,
            1,
            &range,
        );
    }

    pub fn clearDepthStencilImage(buffer: *Buffer, options: ClearDepthStencilImageOptions) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or options.image.deviceHandle() != buffer._device_handle) return error.InvalidOptions;
        const value = options.value.toRaw();
        const range = options.subresource_range.toRaw();
        buffer.cmd_clear_depth_stencil_image(
            handle,
            try options.image.handle(),
            options.layout.toRaw(),
            &value,
            1,
            &range,
        );
    }

    pub fn fillBuffer(
        command_buffer: *Buffer,
        destination: *const buffers.Buffer,
        offset: core.DeviceOffset,
        range: core.DeviceRange,
        value: u32,
    ) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or destination._device_handle != command_buffer._device_handle) return error.InvalidOptions;
        if (offset.bytes() % 4 != 0) return error.InvalidOptions;
        const size = switch (range) {
            .whole => destination.size.bytes() -| offset.bytes(),
            .bytes => |item| item.bytes(),
        };
        if (size == 0 or size % 4 != 0 or offset.bytes() > destination.size.bytes() or size > destination.size.bytes() - offset.bytes()) return error.InvalidOptions;
        command_buffer.cmd_fill_buffer(handle, try destination.rawHandle(), offset.bytes(), range.toRaw(), value);
    }

    pub fn updateBuffer(
        command_buffer: *Buffer,
        destination: *const buffers.Buffer,
        offset: core.DeviceOffset,
        data: []align(4) const u8,
    ) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or destination._device_handle != command_buffer._device_handle) return error.InvalidOptions;
        if (data.len == 0 or data.len > 65_536 or data.len % 4 != 0 or offset.bytes() % 4 != 0 or
            offset.bytes() > destination.size.bytes() or data.len > destination.size.bytes() - offset.bytes()) return error.InvalidOptions;
        command_buffer.cmd_update_buffer(handle, try destination.rawHandle(), offset.bytes(), data.len, data.ptr);
    }

    pub fn copyBuffer(
        command_buffer: *Buffer,
        source: *const buffers.Buffer,
        destination: *const buffers.Buffer,
        regions: []const transfer.BufferCopy,
    ) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or regions.len == 0 or regions.len > 64) return error.InvalidOptions;
        if (source._device_handle != command_buffer._device_handle or destination._device_handle != command_buffer._device_handle) return error.InvalidHandle;
        var raw_regions: [64]raw.VkBufferCopy = undefined;
        var raw_regions2: [64]raw.VkBufferCopy2 = undefined;
        for (regions, 0..) |region, index| {
            const size = region.size.bytes();
            if (size == 0 or region.source_offset.bytes() > source.size.bytes() or size > source.size.bytes() - region.source_offset.bytes() or
                region.destination_offset.bytes() > destination.size.bytes() or size > destination.size.bytes() - region.destination_offset.bytes()) return error.InvalidOptions;
            raw_regions[index] = .{ .srcOffset = region.source_offset.bytes(), .dstOffset = region.destination_offset.bytes(), .size = size };
            raw_regions2[index] = .{
                .sType = raw.VK_STRUCTURE_TYPE_BUFFER_COPY_2,
                .srcOffset = region.source_offset.bytes(),
                .dstOffset = region.destination_offset.bytes(),
                .size = size,
            };
        }
        const source_handle = try source.rawHandle();
        const destination_handle = try destination.rawHandle();
        if (command_buffer.cmd_copy_buffer2) |copy2| {
            const info: raw.VkCopyBufferInfo2 = .{
                .sType = raw.VK_STRUCTURE_TYPE_COPY_BUFFER_INFO_2,
                .srcBuffer = source_handle,
                .dstBuffer = destination_handle,
                .regionCount = @intCast(regions.len),
                .pRegions = raw_regions2[0..regions.len].ptr,
            };
            copy2(handle, &info);
        } else command_buffer.cmd_copy_buffer(handle, source_handle, destination_handle, @intCast(regions.len), raw_regions[0..regions.len].ptr);
    }

    pub fn copyBufferToImage(command_buffer: *Buffer, options: transfer.BufferToImage) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or options.regions.len == 0 or options.regions.len > 64) return error.InvalidOptions;
        if (options.source._device_handle != command_buffer._device_handle or options.destination.deviceHandle() != command_buffer._device_handle) return error.InvalidHandle;
        var regions: [64]raw.VkBufferImageCopy = undefined;
        for (options.regions, 0..) |region, index| regions[index] = try region.toRaw();
        command_buffer.cmd_copy_buffer_to_image(handle, try options.source.rawHandle(), try options.destination.handle(), options.destination_layout.toRaw(), @intCast(options.regions.len), regions[0..options.regions.len].ptr);
    }

    pub fn copyImageToBuffer(command_buffer: *Buffer, options: transfer.ImageToBuffer) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or options.regions.len == 0 or options.regions.len > 64) return error.InvalidOptions;
        if (options.destination._device_handle != command_buffer._device_handle or options.source.deviceHandle() != command_buffer._device_handle) return error.InvalidHandle;
        var regions: [64]raw.VkBufferImageCopy = undefined;
        for (options.regions, 0..) |region, index| regions[index] = try region.toRaw();
        command_buffer.cmd_copy_image_to_buffer(handle, try options.source.handle(), options.source_layout.toRaw(), try options.destination.rawHandle(), @intCast(options.regions.len), regions[0..options.regions.len].ptr);
    }

    pub fn copyImage(command_buffer: *Buffer, options: transfer.ImageToImage) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or options.regions.len == 0 or options.regions.len > 64) return error.InvalidOptions;
        if (options.source.deviceHandle() != command_buffer._device_handle or options.destination.deviceHandle() != command_buffer._device_handle) return error.InvalidHandle;
        var regions: [64]raw.VkImageCopy = undefined;
        for (options.regions, 0..) |region, index| regions[index] = try region.toRaw();
        command_buffer.cmd_copy_image(handle, try options.source.handle(), options.source_layout.toRaw(), try options.destination.handle(), options.destination_layout.toRaw(), @intCast(options.regions.len), regions[0..options.regions.len].ptr);
    }

    pub fn blitImage(
        command_buffer: *Buffer,
        source: image.Reference,
        source_layout: types.ImageLayout,
        destination: image.Reference,
        destination_layout: types.ImageLayout,
        regions: []const transfer.ImageBlit,
        filter: sampler.Filter,
    ) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or regions.len == 0 or regions.len > 64) return error.InvalidOptions;
        if (source.deviceHandle() != command_buffer._device_handle or destination.deviceHandle() != command_buffer._device_handle) return error.InvalidHandle;
        var raw_regions: [64]raw.VkImageBlit = undefined;
        for (regions, 0..) |region, index| raw_regions[index] = try region.toRaw();
        command_buffer.cmd_blit_image(handle, try source.handle(), source_layout.toRaw(), try destination.handle(), destination_layout.toRaw(), @intCast(regions.len), raw_regions[0..regions.len].ptr, filter.toRaw());
    }

    pub fn resolveImage(
        command_buffer: *Buffer,
        source: image.Reference,
        source_layout: types.ImageLayout,
        destination: image.Reference,
        destination_layout: types.ImageLayout,
        regions: []const transfer.ImageResolve,
    ) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or regions.len == 0 or regions.len > 64) return error.InvalidOptions;
        if (source.deviceHandle() != command_buffer._device_handle or destination.deviceHandle() != command_buffer._device_handle) return error.InvalidHandle;
        var raw_regions: [64]raw.VkImageResolve = undefined;
        for (regions, 0..) |region, index| raw_regions[index] = try region.toRaw();
        command_buffer.cmd_resolve_image(handle, try source.handle(), source_layout.toRaw(), try destination.handle(), destination_layout.toRaw(), @intCast(regions.len), raw_regions[0..regions.len].ptr);
    }

    pub fn bindPipeline(command_buffer: *Buffer, value: *const pipeline.Pipeline) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or value._device_handle != command_buffer._device_handle) return error.InvalidOptions;
        command_buffer.cmd_bind_pipeline(handle, value.bind_point.toRaw(), try value.rawHandle());
        switch (value.bind_point) {
            .graphics => command_buffer.graphics_pipeline_bound = true,
            .compute => command_buffer.compute_pipeline_bound = true,
        }
    }

    pub fn bindDescriptorSets(
        command_buffer: *Buffer,
        bind_point: pipeline.BindPoint,
        layout: *const pipeline.Layout,
        first_set: u32,
        sets: []const *const descriptor.Set,
        dynamic_offsets: []const u32,
    ) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or sets.len == 0 or sets.len > 32 or dynamic_offsets.len > 64 or layout._device_handle != command_buffer._device_handle) return error.InvalidOptions;
        var set_handles: [32]raw.VkDescriptorSet = undefined;
        for (sets, 0..) |set, index| {
            if (set._device_handle != command_buffer._device_handle or !layout.supportsDescriptorSet(first_set + @as(u32, @intCast(index)), set.layout_handle)) return error.InvalidHandle;
            set_handles[index] = try set.rawHandle();
        }
        command_buffer.cmd_bind_descriptor_sets(handle, bind_point.toRaw(), try layout.rawHandle(), first_set, @intCast(sets.len), set_handles[0..sets.len].ptr, @intCast(dynamic_offsets.len), if (dynamic_offsets.len == 0) null else dynamic_offsets.ptr);
    }

    pub fn bindVertexBuffers(command_buffer: *Buffer, first_binding: u32, bindings: []const VertexBufferBinding) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or bindings.len == 0 or bindings.len > 32) return error.InvalidOptions;
        var handles: [32]raw.VkBuffer = undefined;
        var offsets: [32]raw.VkDeviceSize = undefined;
        for (bindings, 0..) |binding, index| {
            if (binding.buffer._device_handle != command_buffer._device_handle or binding.offset.bytes() >= binding.buffer.size.bytes()) return error.InvalidHandle;
            handles[index] = try binding.buffer.rawHandle();
            offsets[index] = binding.offset.bytes();
        }
        command_buffer.cmd_bind_vertex_buffers(handle, first_binding, @intCast(bindings.len), handles[0..bindings.len].ptr, offsets[0..bindings.len].ptr);
    }

    pub fn bindIndexBuffer(command_buffer: *Buffer, value: *const buffers.Buffer, offset: core.DeviceOffset, index_type: IndexType) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or value._device_handle != command_buffer._device_handle or offset.bytes() >= value.size.bytes()) return error.InvalidOptions;
        const alignment: u64 = switch (index_type) {
            .uint8 => 1,
            .uint16 => 2,
            .uint32 => 4,
        };
        if (offset.bytes() % alignment != 0) return error.InvalidOptions;
        command_buffer.cmd_bind_index_buffer(handle, try value.rawHandle(), offset.bytes(), index_type.toRaw());
    }

    pub fn setViewports(command_buffer: *Buffer, first: u32, values: []const types.Viewport) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or values.len == 0 or values.len > 16) return error.InvalidOptions;
        var raw_values: [16]raw.VkViewport = undefined;
        for (values, 0..) |value, index| raw_values[index] = value.toRaw();
        command_buffer.cmd_set_viewport(handle, first, @intCast(values.len), raw_values[0..values.len].ptr);
    }

    pub fn setScissors(command_buffer: *Buffer, first: u32, values: []const types.Rect2D) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or values.len == 0 or values.len > 16) return error.InvalidOptions;
        var raw_values: [16]raw.VkRect2D = undefined;
        for (values, 0..) |value, index| raw_values[index] = value.toRaw();
        command_buffer.cmd_set_scissor(handle, first, @intCast(values.len), raw_values[0..values.len].ptr);
    }

    pub fn setLineWidth(command_buffer: *Buffer, width: f32) core.Error!void {
        if (!std.math.isFinite(width) or width <= 0 or command_buffer.state != .recording) return error.InvalidOptions;
        command_buffer.cmd_set_line_width(try command_buffer.liveHandle(), width);
    }

    pub fn setDepthBias(command_buffer: *Buffer, constant: f32, clamp: f32, slope: f32) core.Error!void {
        if (!std.math.isFinite(constant) or !std.math.isFinite(clamp) or !std.math.isFinite(slope) or command_buffer.state != .recording) return error.InvalidOptions;
        command_buffer.cmd_set_depth_bias(try command_buffer.liveHandle(), constant, clamp, slope);
    }

    pub fn setBlendConstants(command_buffer: *Buffer, values: [4]f32) core.Error!void {
        if (command_buffer.state != .recording) return error.InvalidOptions;
        for (values) |value| if (!std.math.isFinite(value)) return error.InvalidOptions;
        command_buffer.cmd_set_blend_constants(try command_buffer.liveHandle(), &values);
    }

    pub fn setDepthBounds(command_buffer: *Buffer, minimum: f32, maximum: f32) core.Error!void {
        if (command_buffer.state != .recording or !std.math.isFinite(minimum) or !std.math.isFinite(maximum) or minimum < 0 or maximum > 1 or minimum > maximum) return error.InvalidOptions;
        command_buffer.cmd_set_depth_bounds(try command_buffer.liveHandle(), minimum, maximum);
    }

    pub fn pushConstants(command_buffer: *Buffer, layout: *const pipeline.Layout, stages: @import("shader.zig").StageSet, offset: u32, bytes: []const u8) core.Error!void {
        if (command_buffer.state != .recording or layout._device_handle != command_buffer._device_handle or bytes.len == 0 or bytes.len % 4 != 0 or offset % 4 != 0 or bytes.len > std.math.maxInt(u32)) return error.InvalidOptions;
        if (!layout.supportsPushConstants(stages, offset, @intCast(bytes.len))) return error.InvalidOptions;
        command_buffer.cmd_push_constants(try command_buffer.liveHandle(), try layout.rawHandle(), stages.toRaw(), offset, @intCast(bytes.len), bytes.ptr);
    }

    pub fn pushConstantsValue(command_buffer: *Buffer, layout: *const pipeline.Layout, stages: @import("shader.zig").StageSet, offset: u32, value: anytype) core.Error!void {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .@"struct" => |info| if (info.layout != .@"extern" and info.layout != .@"packed") @compileError("push-constant values must be extern or packed structs"),
            else => @compileError("push-constant values must be extern or packed structs"),
        }
        const bytes = std.mem.asBytes(&value);
        return command_buffer.pushConstants(layout, stages, offset, bytes);
    }

    pub fn draw(command_buffer: *Buffer, options: DrawOptions) core.Error!void {
        if (command_buffer.state != .recording or !command_buffer.rendering_active or !command_buffer.graphics_pipeline_bound or options.vertex_count == 0 or options.instance_count == 0) return error.InvalidOptions;
        command_buffer.cmd_draw(try command_buffer.liveHandle(), options.vertex_count, options.instance_count, options.first_vertex, options.first_instance);
    }

    pub fn drawIndexed(command_buffer: *Buffer, options: DrawIndexedOptions) core.Error!void {
        if (command_buffer.state != .recording or !command_buffer.rendering_active or !command_buffer.graphics_pipeline_bound or options.index_count == 0 or options.instance_count == 0) return error.InvalidOptions;
        command_buffer.cmd_draw_indexed(try command_buffer.liveHandle(), options.index_count, options.instance_count, options.first_index, options.vertex_offset, options.first_instance);
    }

    pub fn drawIndirect(command_buffer: *Buffer, indirect: *const buffers.Buffer, offset: core.DeviceOffset, draw_count: u32, stride: u32) core.Error!void {
        if (command_buffer.state != .recording or !command_buffer.rendering_active or !command_buffer.graphics_pipeline_bound or indirect._device_handle != command_buffer._device_handle or draw_count == 0 or stride < @sizeOf(raw.VkDrawIndirectCommand) or stride % 4 != 0) return error.InvalidOptions;
        try validateIndirectRange(indirect, offset, draw_count, stride, @sizeOf(raw.VkDrawIndirectCommand));
        command_buffer.cmd_draw_indirect(try command_buffer.liveHandle(), try indirect.rawHandle(), offset.bytes(), draw_count, stride);
    }

    pub fn drawIndexedIndirect(command_buffer: *Buffer, indirect: *const buffers.Buffer, offset: core.DeviceOffset, draw_count: u32, stride: u32) core.Error!void {
        if (command_buffer.state != .recording or !command_buffer.rendering_active or !command_buffer.graphics_pipeline_bound or indirect._device_handle != command_buffer._device_handle or draw_count == 0 or stride < @sizeOf(raw.VkDrawIndexedIndirectCommand) or stride % 4 != 0) return error.InvalidOptions;
        try validateIndirectRange(indirect, offset, draw_count, stride, @sizeOf(raw.VkDrawIndexedIndirectCommand));
        command_buffer.cmd_draw_indexed_indirect(try command_buffer.liveHandle(), try indirect.rawHandle(), offset.bytes(), draw_count, stride);
    }

    pub fn drawIndirectCount(command_buffer: *Buffer, indirect: *const buffers.Buffer, offset: core.DeviceOffset, count_buffer: *const buffers.Buffer, count_offset: core.DeviceOffset, max_draw_count: u32, stride: u32) core.Error!void {
        const command = command_buffer.cmd_draw_indirect_count orelse return error.MissingCommand;
        if (command_buffer.state != .recording or !command_buffer.rendering_active or !command_buffer.graphics_pipeline_bound or indirect._device_handle != command_buffer._device_handle or count_buffer._device_handle != command_buffer._device_handle or max_draw_count == 0 or stride < @sizeOf(raw.VkDrawIndirectCommand) or stride % 4 != 0 or count_offset.bytes() % 4 != 0) return error.InvalidOptions;
        try validateIndirectRange(indirect, offset, max_draw_count, stride, @sizeOf(raw.VkDrawIndirectCommand));
        try validateFixedRange(count_buffer, count_offset, @sizeOf(u32));
        command(try command_buffer.liveHandle(), try indirect.rawHandle(), offset.bytes(), try count_buffer.rawHandle(), count_offset.bytes(), max_draw_count, stride);
    }

    pub fn drawIndexedIndirectCount(command_buffer: *Buffer, indirect: *const buffers.Buffer, offset: core.DeviceOffset, count_buffer: *const buffers.Buffer, count_offset: core.DeviceOffset, max_draw_count: u32, stride: u32) core.Error!void {
        const command = command_buffer.cmd_draw_indexed_indirect_count orelse return error.MissingCommand;
        if (command_buffer.state != .recording or !command_buffer.rendering_active or !command_buffer.graphics_pipeline_bound or indirect._device_handle != command_buffer._device_handle or count_buffer._device_handle != command_buffer._device_handle or max_draw_count == 0 or stride < @sizeOf(raw.VkDrawIndexedIndirectCommand) or stride % 4 != 0 or count_offset.bytes() % 4 != 0) return error.InvalidOptions;
        try validateIndirectRange(indirect, offset, max_draw_count, stride, @sizeOf(raw.VkDrawIndexedIndirectCommand));
        try validateFixedRange(count_buffer, count_offset, @sizeOf(u32));
        command(try command_buffer.liveHandle(), try indirect.rawHandle(), offset.bytes(), try count_buffer.rawHandle(), count_offset.bytes(), max_draw_count, stride);
    }

    pub fn dispatch(command_buffer: *Buffer, options: DispatchOptions) core.Error!void {
        if (command_buffer.state != .recording or command_buffer.rendering_active or !command_buffer.compute_pipeline_bound or options.x == 0 or options.y == 0 or options.z == 0) return error.InvalidOptions;
        command_buffer.cmd_dispatch(try command_buffer.liveHandle(), options.x, options.y, options.z);
    }

    pub fn dispatchIndirect(command_buffer: *Buffer, indirect: *const buffers.Buffer, offset: core.DeviceOffset) core.Error!void {
        if (command_buffer.state != .recording or command_buffer.rendering_active or !command_buffer.compute_pipeline_bound or indirect._device_handle != command_buffer._device_handle or offset.bytes() % 4 != 0) return error.InvalidOptions;
        try validateFixedRange(indirect, offset, @sizeOf(raw.VkDispatchIndirectCommand));
        command_buffer.cmd_dispatch_indirect(try command_buffer.liveHandle(), try indirect.rawHandle(), offset.bytes());
    }

    fn validateFixedRange(value: *const buffers.Buffer, offset: core.DeviceOffset, size: u64) core.Error!void {
        if (offset.bytes() > value.size.bytes() or size > value.size.bytes() - offset.bytes()) return error.InvalidOptions;
    }

    fn validateIndirectRange(value: *const buffers.Buffer, offset: core.DeviceOffset, count: u32, stride: u32, command_size: u64) core.Error!void {
        const prefix = std.math.mul(u64, count - 1, stride) catch return error.SizeOverflow;
        const bytes = std.math.add(u64, prefix, command_size) catch return error.SizeOverflow;
        try validateFixedRange(value, offset, bytes);
    }

    pub fn dispatchBase(command_buffer: *Buffer, base: DispatchOptions, groups: DispatchOptions) core.Error!void {
        const command = command_buffer.cmd_dispatch_base orelse return error.MissingCommand;
        if (command_buffer.state != .recording or command_buffer.rendering_active or !command_buffer.compute_pipeline_bound or groups.x == 0 or groups.y == 0 or groups.z == 0) return error.InvalidOptions;
        command(try command_buffer.liveHandle(), base.x, base.y, base.z, groups.x, groups.y, groups.z);
    }

    pub fn executeSecondary(command_buffer: *Buffer, secondary: []const *Buffer) core.Error!void {
        if (command_buffer.level != .primary or command_buffer.state != .recording or secondary.len == 0 or secondary.len > 64) return error.InvalidOptions;
        var handles: [64]raw.VkCommandBuffer = undefined;
        for (secondary, 0..) |child, index| {
            if (child._device_handle != command_buffer._device_handle or child.level != .secondary or child.state != .executable) return error.InvalidHandle;
            handles[index] = try child.liveHandle();
        }
        command_buffer.cmd_execute_commands(try command_buffer.liveHandle(), @intCast(secondary.len), handles[0..secondary.len].ptr);
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

pub const RenderingScope = struct {
    buffer: *Buffer,
    active: bool = true,

    pub fn end(scope: *RenderingScope) core.Error!void {
        if (!scope.active) return;
        try scope.buffer.endRendering();
        scope.active = false;
    }

    pub fn deinit(scope: *RenderingScope) void {
        scope.end() catch {};
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
    cmd_pipeline_barrier2: ?CommandFunction(raw.PFN_vkCmdPipelineBarrier2),
    cmd_set_event2: ?CommandFunction(raw.PFN_vkCmdSetEvent2),
    cmd_reset_event2: ?CommandFunction(raw.PFN_vkCmdResetEvent2),
    cmd_wait_events2: ?CommandFunction(raw.PFN_vkCmdWaitEvents2),
    cmd_begin_rendering: ?CommandFunction(raw.PFN_vkCmdBeginRendering),
    cmd_end_rendering: ?CommandFunction(raw.PFN_vkCmdEndRendering),
    cmd_clear_color_image: CommandFunction(raw.PFN_vkCmdClearColorImage),
    cmd_clear_depth_stencil_image: CommandFunction(raw.PFN_vkCmdClearDepthStencilImage),
    cmd_fill_buffer: CommandFunction(raw.PFN_vkCmdFillBuffer),
    cmd_update_buffer: CommandFunction(raw.PFN_vkCmdUpdateBuffer),
    cmd_copy_buffer: CommandFunction(raw.PFN_vkCmdCopyBuffer),
    cmd_copy_buffer2: ?CommandFunction(raw.PFN_vkCmdCopyBuffer2),
    cmd_copy_buffer_to_image: CommandFunction(raw.PFN_vkCmdCopyBufferToImage),
    cmd_copy_image_to_buffer: CommandFunction(raw.PFN_vkCmdCopyImageToBuffer),
    cmd_copy_image: CommandFunction(raw.PFN_vkCmdCopyImage),
    cmd_blit_image: CommandFunction(raw.PFN_vkCmdBlitImage),
    cmd_resolve_image: CommandFunction(raw.PFN_vkCmdResolveImage),
    cmd_bind_pipeline: CommandFunction(raw.PFN_vkCmdBindPipeline),
    cmd_bind_descriptor_sets: CommandFunction(raw.PFN_vkCmdBindDescriptorSets),
    cmd_bind_vertex_buffers: CommandFunction(raw.PFN_vkCmdBindVertexBuffers),
    cmd_bind_index_buffer: CommandFunction(raw.PFN_vkCmdBindIndexBuffer),
    cmd_set_viewport: CommandFunction(raw.PFN_vkCmdSetViewport),
    cmd_set_scissor: CommandFunction(raw.PFN_vkCmdSetScissor),
    cmd_set_line_width: CommandFunction(raw.PFN_vkCmdSetLineWidth),
    cmd_set_depth_bias: CommandFunction(raw.PFN_vkCmdSetDepthBias),
    cmd_set_blend_constants: CommandFunction(raw.PFN_vkCmdSetBlendConstants),
    cmd_set_depth_bounds: CommandFunction(raw.PFN_vkCmdSetDepthBounds),
    cmd_push_constants: CommandFunction(raw.PFN_vkCmdPushConstants),
    cmd_draw: CommandFunction(raw.PFN_vkCmdDraw),
    cmd_draw_indexed: CommandFunction(raw.PFN_vkCmdDrawIndexed),
    cmd_draw_indirect: CommandFunction(raw.PFN_vkCmdDrawIndirect),
    cmd_draw_indexed_indirect: CommandFunction(raw.PFN_vkCmdDrawIndexedIndirect),
    cmd_draw_indirect_count: ?CommandFunction(raw.PFN_vkCmdDrawIndirectCount),
    cmd_draw_indexed_indirect_count: ?CommandFunction(raw.PFN_vkCmdDrawIndexedIndirectCount),
    cmd_dispatch: CommandFunction(raw.PFN_vkCmdDispatch),
    cmd_dispatch_indirect: CommandFunction(raw.PFN_vkCmdDispatchIndirect),
    cmd_dispatch_base: ?CommandFunction(raw.PFN_vkCmdDispatchBase),
    cmd_execute_commands: CommandFunction(raw.PFN_vkCmdExecuteCommands),
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
            .cmd_pipeline_barrier2 = pool.cmd_pipeline_barrier2,
            .cmd_set_event2 = pool.cmd_set_event2,
            .cmd_reset_event2 = pool.cmd_reset_event2,
            .cmd_wait_events2 = pool.cmd_wait_events2,
            .cmd_begin_rendering = pool.cmd_begin_rendering,
            .cmd_end_rendering = pool.cmd_end_rendering,
            .cmd_clear_color_image = pool.cmd_clear_color_image,
            .cmd_clear_depth_stencil_image = pool.cmd_clear_depth_stencil_image,
            .cmd_fill_buffer = pool.cmd_fill_buffer,
            .cmd_update_buffer = pool.cmd_update_buffer,
            .cmd_copy_buffer = pool.cmd_copy_buffer,
            .cmd_copy_buffer2 = pool.cmd_copy_buffer2,
            .cmd_copy_buffer_to_image = pool.cmd_copy_buffer_to_image,
            .cmd_copy_image_to_buffer = pool.cmd_copy_image_to_buffer,
            .cmd_copy_image = pool.cmd_copy_image,
            .cmd_blit_image = pool.cmd_blit_image,
            .cmd_resolve_image = pool.cmd_resolve_image,
            .cmd_bind_pipeline = pool.cmd_bind_pipeline,
            .cmd_bind_descriptor_sets = pool.cmd_bind_descriptor_sets,
            .cmd_bind_vertex_buffers = pool.cmd_bind_vertex_buffers,
            .cmd_bind_index_buffer = pool.cmd_bind_index_buffer,
            .cmd_set_viewport = pool.cmd_set_viewport,
            .cmd_set_scissor = pool.cmd_set_scissor,
            .cmd_set_line_width = pool.cmd_set_line_width,
            .cmd_set_depth_bias = pool.cmd_set_depth_bias,
            .cmd_set_blend_constants = pool.cmd_set_blend_constants,
            .cmd_set_depth_bounds = pool.cmd_set_depth_bounds,
            .cmd_push_constants = pool.cmd_push_constants,
            .cmd_draw = pool.cmd_draw,
            .cmd_draw_indexed = pool.cmd_draw_indexed,
            .cmd_draw_indirect = pool.cmd_draw_indirect,
            .cmd_draw_indexed_indirect = pool.cmd_draw_indexed_indirect,
            .cmd_draw_indirect_count = pool.cmd_draw_indirect_count,
            .cmd_draw_indexed_indirect_count = pool.cmd_draw_indexed_indirect_count,
            .cmd_dispatch = pool.cmd_dispatch,
            .cmd_dispatch_indirect = pool.cmd_dispatch_indirect,
            .cmd_dispatch_base = pool.cmd_dispatch_base,
            .cmd_execute_commands = pool.cmd_execute_commands,
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

test "all command-buffer declarations compile" {
    std.testing.refAllDecls(@This());
}
