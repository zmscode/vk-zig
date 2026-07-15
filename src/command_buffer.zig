const std = @import("std");
const raw = @import("vulkan_raw");
const commands = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const image = @import("image.zig");
const debug_utils = @import("debug_utils.zig");
const sync = @import("synchronization.zig");
const rendering = @import("rendering.zig");
const render_passes = @import("render_pass.zig");
const transfer = @import("transfer.zig");
const buffers = @import("buffer.zig");
const sampler = @import("sampler.zig");
const pipeline = @import("pipeline.zig");
const descriptor = @import("descriptor.zig");
const video = @import("video.zig");
const device_group = @import("device_group.zig");

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
    render_pass: ?render_passes.Inheritance = null,
};

pub const BeginOptions = struct {
    flags: types.CommandBufferUsageFlags = .empty,
    inheritance: ?SecondaryInheritance = null,
    device_mask: ?device_group.Mask = null,
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
pub const ConditionalRenderingOptions = struct {
    buffer: *const buffers.Buffer,
    offset: core.DeviceOffset = .zero,
    inverted: bool = false,
};
pub const TransformFeedbackCounter = struct {
    buffer: *const buffers.Buffer,
    offset: core.DeviceOffset = .zero,
};
pub const transform_feedback_counter_max = 8;
pub const DrawIndirectCommand = extern struct { vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32 };
pub const DrawIndexedIndirectCommand = extern struct { index_count: u32, instance_count: u32, first_index: u32, vertex_offset: i32, first_instance: u32 };
pub const DispatchIndirectCommand = extern struct { x: u32, y: u32, z: u32 };
comptime {
    std.debug.assert(@sizeOf(DrawIndirectCommand) == @sizeOf(raw.VkDrawIndirectCommand));
    std.debug.assert(@sizeOf(DrawIndexedIndirectCommand) == @sizeOf(raw.VkDrawIndexedIndirectCommand));
    std.debug.assert(@sizeOf(DispatchIndirectCommand) == @sizeOf(raw.VkDispatchIndirectCommand));
}
pub const MultiDraw = struct { first_vertex: u32 = 0, vertex_count: u32 };
pub const MultiDrawIndexed = struct { first_index: u32 = 0, index_count: u32, vertex_offset: i32 = 0 };
pub const StencilFaces = packed struct(u2) {
    front: bool = false,
    back: bool = false,

    fn toRaw(value: StencilFaces) raw.VkStencilFaceFlags {
        var flags: raw.VkStencilFaceFlags = 0;
        if (value.front) flags |= raw.VK_STENCIL_FACE_FRONT_BIT;
        if (value.back) flags |= raw.VK_STENCIL_FACE_BACK_BIT;
        return flags;
    }
};

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

const LegacyDependencyStorage = struct {
    memory: [64]raw.VkMemoryBarrier = undefined,
    buffers: [64]raw.VkBufferMemoryBarrier = undefined,
    images: [64]raw.VkImageMemoryBarrier = undefined,
    source_stages: raw.VkPipelineStageFlags = 0,
    destination_stages: raw.VkPipelineStageFlags = 0,

    fn init(storage: *LegacyDependencyStorage, dependency: sync.DependencyInfo) core.Error!void {
        if (dependency.memory_barriers.len > storage.memory.len or dependency.buffer_barriers.len > storage.buffers.len or dependency.image_barriers.len > storage.images.len) return error.CountOverflow;
        for (dependency.memory_barriers, 0..) |barrier, index| {
            storage.addStages(barrier.source_stage, barrier.destination_stage) catch return error.UnsupportedOperation;
            storage.memory[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_MEMORY_BARRIER, .srcAccessMask = try legacyAccess(barrier.source_access), .dstAccessMask = try legacyAccess(barrier.destination_access) };
        }
        for (dependency.buffer_barriers, 0..) |barrier, index| {
            storage.addStages(barrier.source_stage, barrier.destination_stage) catch return error.UnsupportedOperation;
            const converted = try barrier.toRaw();
            storage.buffers[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER, .srcAccessMask = try legacyAccess(barrier.source_access), .dstAccessMask = try legacyAccess(barrier.destination_access), .srcQueueFamilyIndex = converted.srcQueueFamilyIndex, .dstQueueFamilyIndex = converted.dstQueueFamilyIndex, .buffer = converted.buffer, .offset = converted.offset, .size = converted.size };
        }
        for (dependency.image_barriers, 0..) |barrier, index| {
            storage.addStages(barrier.source_stage, barrier.destination_stage) catch return error.UnsupportedOperation;
            const converted = try barrier.toRaw();
            storage.images[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, .srcAccessMask = try legacyAccess(barrier.source_access), .dstAccessMask = try legacyAccess(barrier.destination_access), .oldLayout = converted.oldLayout, .newLayout = converted.newLayout, .srcQueueFamilyIndex = converted.srcQueueFamilyIndex, .dstQueueFamilyIndex = converted.dstQueueFamilyIndex, .image = converted.image, .subresourceRange = converted.subresourceRange };
        }
        if (storage.source_stages == 0) storage.source_stages = raw.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        if (storage.destination_stages == 0) storage.destination_stages = raw.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;
    }

    fn addStages(storage: *LegacyDependencyStorage, source: types.PipelineStage2Flags, destination: types.PipelineStage2Flags) core.Error!void {
        storage.source_stages |= try legacyStages(source);
        storage.destination_stages |= try legacyStages(destination);
    }
};

fn legacyStages(value: types.PipelineStage2Flags) core.Error!raw.VkPipelineStageFlags {
    const bits = value.toRaw();
    if (bits > std.math.maxInt(raw.VkPipelineStageFlags)) return error.UnsupportedOperation;
    return @intCast(bits);
}

fn legacyAccess(value: types.Access2Flags) core.Error!raw.VkAccessFlags {
    const bits = value.toRaw();
    if (bits > std.math.maxInt(raw.VkAccessFlags)) return error.UnsupportedOperation;
    return @intCast(bits);
}

fn validateImageRegion(reference: image.Reference, layers: transfer.SubresourceLayers, offset: types.Offset3D, extent: types.Extent3D) core.Error!void {
    if (layers.layer_count == 0 or offset.x < 0 or offset.y < 0 or offset.z < 0 or extent.width == 0 or extent.height == 0 or extent.depth == 0) return error.InvalidOptions;
    if (reference.knownExtentAtMip(layers.mip_level)) |known| {
        const x: u32 = @intCast(offset.x);
        const y: u32 = @intCast(offset.y);
        const z: u32 = @intCast(offset.z);
        if (x > known.width or extent.width > known.width - x or y > known.height or extent.height > known.height - y or z > known.depth or extent.depth > known.depth - z) return error.InvalidOptions;
    } else if (reference == .owned) return error.InvalidOptions;
    if (reference.knownArrayLayers()) |layer_count| {
        if (layers.base_array_layer > layer_count or layers.layer_count > layer_count - layers.base_array_layer) return error.InvalidOptions;
    }
}

pub const Buffer = struct {
    _handle: ?CommandBufferHandle,
    _device_handle: DeviceHandle,
    _pool: *Pool,
    _pool_owner: core.Owner.Borrow,
    _pool_generation: u64,
    level: types.CommandBufferLevel,
    can_reset: bool,
    state: State = .initial,
    simultaneous_use: bool = false,
    pending_submissions: usize = 0,
    rendering_active: bool = false,
    render_pass_active: bool = false,
    active_render_pass: raw.VkRenderPass = null,
    active_framebuffer: raw.VkFramebuffer = null,
    active_subpass: u32 = 0,
    active_subpass_count: u32 = 0,
    graphics_pipeline_bound: bool = false,
    compute_pipeline_bound: bool = false,
    ray_tracing_pipeline_bound: bool = false,
    execution_graph_pipeline_bound: bool = false,
    conditional_rendering_active: bool = false,
    transform_feedback_active: bool = false,
    video_coding_active: bool = false,
    active_video_profile: ?video.Profile = null,
    _device_group_size: u32 = 1,
    begin_command_buffer: CommandFunction(raw.PFN_vkBeginCommandBuffer),
    end_command_buffer: CommandFunction(raw.PFN_vkEndCommandBuffer),
    reset_command_buffer: CommandFunction(raw.PFN_vkResetCommandBuffer),
    cmd_pipeline_barrier: CommandFunction(raw.PFN_vkCmdPipelineBarrier),
    cmd_pipeline_barrier2: ?CommandFunction(raw.PFN_vkCmdPipelineBarrier2),
    cmd_set_event: CommandFunction(raw.PFN_vkCmdSetEvent),
    cmd_reset_event: CommandFunction(raw.PFN_vkCmdResetEvent),
    cmd_wait_events: CommandFunction(raw.PFN_vkCmdWaitEvents),
    cmd_set_event2: ?CommandFunction(raw.PFN_vkCmdSetEvent2),
    cmd_reset_event2: ?CommandFunction(raw.PFN_vkCmdResetEvent2),
    cmd_wait_events2: ?CommandFunction(raw.PFN_vkCmdWaitEvents2),
    cmd_begin_rendering: ?CommandFunction(raw.PFN_vkCmdBeginRendering),
    cmd_end_rendering: ?CommandFunction(raw.PFN_vkCmdEndRendering),
    cmd_begin_render_pass: CommandFunction(raw.PFN_vkCmdBeginRenderPass),
    cmd_next_subpass: CommandFunction(raw.PFN_vkCmdNextSubpass),
    cmd_end_render_pass: CommandFunction(raw.PFN_vkCmdEndRenderPass),
    cmd_begin_render_pass2: ?CommandFunction(raw.PFN_vkCmdBeginRenderPass2),
    cmd_next_subpass2: ?CommandFunction(raw.PFN_vkCmdNextSubpass2),
    cmd_end_render_pass2: ?CommandFunction(raw.PFN_vkCmdEndRenderPass2),
    cmd_clear_color_image: CommandFunction(raw.PFN_vkCmdClearColorImage),
    cmd_clear_depth_stencil_image: CommandFunction(raw.PFN_vkCmdClearDepthStencilImage),
    cmd_fill_buffer: CommandFunction(raw.PFN_vkCmdFillBuffer),
    cmd_update_buffer: CommandFunction(raw.PFN_vkCmdUpdateBuffer),
    cmd_copy_buffer: CommandFunction(raw.PFN_vkCmdCopyBuffer),
    cmd_copy_buffer2: ?CommandFunction(raw.PFN_vkCmdCopyBuffer2),
    cmd_copy_buffer_to_image: CommandFunction(raw.PFN_vkCmdCopyBufferToImage),
    cmd_copy_buffer_to_image2: ?CommandFunction(raw.PFN_vkCmdCopyBufferToImage2),
    cmd_copy_image_to_buffer: CommandFunction(raw.PFN_vkCmdCopyImageToBuffer),
    cmd_copy_image_to_buffer2: ?CommandFunction(raw.PFN_vkCmdCopyImageToBuffer2),
    cmd_copy_image: CommandFunction(raw.PFN_vkCmdCopyImage),
    cmd_copy_image2: ?CommandFunction(raw.PFN_vkCmdCopyImage2),
    cmd_blit_image: CommandFunction(raw.PFN_vkCmdBlitImage),
    cmd_blit_image2: ?CommandFunction(raw.PFN_vkCmdBlitImage2),
    cmd_resolve_image: CommandFunction(raw.PFN_vkCmdResolveImage),
    cmd_resolve_image2: ?CommandFunction(raw.PFN_vkCmdResolveImage2),
    cmd_bind_pipeline: CommandFunction(raw.PFN_vkCmdBindPipeline),
    cmd_bind_descriptor_sets: CommandFunction(raw.PFN_vkCmdBindDescriptorSets),
    cmd_push_descriptor_set: ?CommandFunction(raw.PFN_vkCmdPushDescriptorSet),
    cmd_bind_vertex_buffers: CommandFunction(raw.PFN_vkCmdBindVertexBuffers),
    cmd_bind_index_buffer: CommandFunction(raw.PFN_vkCmdBindIndexBuffer),
    cmd_set_viewport: CommandFunction(raw.PFN_vkCmdSetViewport),
    cmd_set_scissor: CommandFunction(raw.PFN_vkCmdSetScissor),
    cmd_set_line_width: CommandFunction(raw.PFN_vkCmdSetLineWidth),
    cmd_set_depth_bias: CommandFunction(raw.PFN_vkCmdSetDepthBias),
    cmd_set_blend_constants: CommandFunction(raw.PFN_vkCmdSetBlendConstants),
    cmd_set_depth_bounds: CommandFunction(raw.PFN_vkCmdSetDepthBounds),
    cmd_set_stencil_compare_mask: CommandFunction(raw.PFN_vkCmdSetStencilCompareMask),
    cmd_set_stencil_write_mask: CommandFunction(raw.PFN_vkCmdSetStencilWriteMask),
    cmd_set_stencil_reference: CommandFunction(raw.PFN_vkCmdSetStencilReference),
    cmd_push_constants: CommandFunction(raw.PFN_vkCmdPushConstants),
    cmd_draw: CommandFunction(raw.PFN_vkCmdDraw),
    cmd_draw_indexed: CommandFunction(raw.PFN_vkCmdDrawIndexed),
    cmd_draw_indirect: CommandFunction(raw.PFN_vkCmdDrawIndirect),
    cmd_draw_indexed_indirect: CommandFunction(raw.PFN_vkCmdDrawIndexedIndirect),
    cmd_draw_indirect_count: ?CommandFunction(raw.PFN_vkCmdDrawIndirectCount),
    cmd_draw_indexed_indirect_count: ?CommandFunction(raw.PFN_vkCmdDrawIndexedIndirectCount),
    cmd_draw_multi: ?CommandFunction(raw.PFN_vkCmdDrawMultiEXT),
    cmd_draw_multi_indexed: ?CommandFunction(raw.PFN_vkCmdDrawMultiIndexedEXT),
    cmd_dispatch: CommandFunction(raw.PFN_vkCmdDispatch),
    cmd_dispatch_indirect: CommandFunction(raw.PFN_vkCmdDispatchIndirect),
    cmd_dispatch_base: ?CommandFunction(raw.PFN_vkCmdDispatchBase),
    cmd_execute_commands: CommandFunction(raw.PFN_vkCmdExecuteCommands),
    cmd_begin_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdBeginDebugUtilsLabelEXT),
    cmd_end_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdEndDebugUtilsLabelEXT),
    cmd_insert_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdInsertDebugUtilsLabelEXT),
    cmd_begin_conditional_rendering_ext: ?CommandFunction(raw.PFN_vkCmdBeginConditionalRenderingEXT),
    cmd_end_conditional_rendering_ext: ?CommandFunction(raw.PFN_vkCmdEndConditionalRenderingEXT),
    cmd_begin_transform_feedback_ext: ?CommandFunction(raw.PFN_vkCmdBeginTransformFeedbackEXT),
    cmd_end_transform_feedback_ext: ?CommandFunction(raw.PFN_vkCmdEndTransformFeedbackEXT),
    cmd_begin_video_coding_khr: ?CommandFunction(raw.PFN_vkCmdBeginVideoCodingKHR),
    cmd_end_video_coding_khr: ?CommandFunction(raw.PFN_vkCmdEndVideoCodingKHR),
    cmd_control_video_coding_khr: ?CommandFunction(raw.PFN_vkCmdControlVideoCodingKHR),
    cmd_decode_video_khr: ?CommandFunction(raw.PFN_vkCmdDecodeVideoKHR),
    cmd_encode_video_khr: ?CommandFunction(raw.PFN_vkCmdEncodeVideoKHR),
    cmd_set_device_mask: ?CommandFunction(raw.PFN_vkCmdSetDeviceMask),

    fn liveHandle(buffer: *Buffer) core.Error!CommandBufferHandle {
        try buffer._pool_owner.validate();
        const handle = buffer._handle orelse return error.InactiveObject;
        _ = buffer._pool._handle orelse return error.InactiveObject;
        if (buffer._pool_generation != buffer._pool.generation) {
            buffer._pool_generation = buffer._pool.generation;
            buffer.state = .initial;
            buffer.simultaneous_use = false;
            buffer.pending_submissions = 0;
            buffer.rendering_active = false;
            buffer.render_pass_active = false;
            buffer.active_render_pass = null;
            buffer.active_framebuffer = null;
            buffer.active_subpass = 0;
            buffer.active_subpass_count = 0;
            buffer.graphics_pipeline_bound = false;
            buffer.compute_pipeline_bound = false;
            buffer.ray_tracing_pipeline_bound = false;
            buffer.execution_graph_pipeline_bound = false;
            buffer.conditional_rendering_active = false;
            buffer.transform_feedback_active = false;
            buffer.video_coding_active = false;
            buffer.active_video_profile = null;
        }
        return handle;
    }

    pub fn deinit(buffer: *Buffer) void {
        const handle = buffer._handle orelse return;
        buffer._pool_owner.validate() catch {
            buffer._handle = null;
            return;
        };
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
            buffer.render_pass_active = false;
            buffer.active_render_pass = null;
            buffer.active_framebuffer = null;
            buffer.active_subpass = 0;
            buffer.active_subpass_count = 0;
            buffer.graphics_pipeline_bound = false;
            buffer.compute_pipeline_bound = false;
            buffer.ray_tracing_pipeline_bound = false;
            buffer.execution_graph_pipeline_bound = false;
            buffer.conditional_rendering_active = false;
            buffer.transform_feedback_active = false;
            buffer.video_coding_active = false;
            buffer.active_video_profile = null;
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
        if (options.inheritance) |inheritance| {
            if (inheritance.render_pass) |legacy| {
                if (!options.flags.contains(.render_pass_continue) or legacy.render_pass._device_handle != buffer._device_handle) return error.InvalidOptions;
                if (legacy.render_pass.subpassColorAttachmentCount(legacy.subpass) == null) return error.InvalidOptions;
                inheritance_info.renderPass = try legacy.render_pass.rawHandle();
                inheritance_info.subpass = legacy.subpass;
                if (legacy.framebuffer) |framebuffer| {
                    if (framebuffer._device_handle != buffer._device_handle or framebuffer._render_pass_handle != inheritance_info.renderPass) return error.InvalidHandle;
                    inheritance_info.framebuffer = try framebuffer.rawHandle();
                }
            } else if (options.flags.contains(.render_pass_continue)) return error.InvalidOptions;
        }
        var device_group_info: raw.VkDeviceGroupCommandBufferBeginInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_DEVICE_GROUP_COMMAND_BUFFER_BEGIN_INFO,
        };
        if (options.device_mask) |mask| {
            try mask.validate(buffer._device_group_size);
            device_group_info.deviceMask = mask.bits;
        }
        const begin_info: raw.VkCommandBufferBeginInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pNext = if (options.device_mask != null) &device_group_info else null,
            .flags = options.flags.toRaw(),
            .pInheritanceInfo = if (options.inheritance != null) &inheritance_info else null,
        };
        try core.checkSuccessOptional(if (buffer._pool._device_state) |*state| state else null, buffer.begin_command_buffer(handle, &begin_info));
        buffer.state = .recording;
        buffer.simultaneous_use = options.flags.contains(.simultaneous_use);
        buffer.rendering_active = false;
        buffer.render_pass_active = false;
        buffer.active_render_pass = null;
        buffer.active_framebuffer = null;
        buffer.active_subpass = 0;
        buffer.active_subpass_count = 0;
        buffer.graphics_pipeline_bound = false;
        buffer.compute_pipeline_bound = false;
        buffer.ray_tracing_pipeline_bound = false;
        buffer.execution_graph_pipeline_bound = false;
        buffer.conditional_rendering_active = false;
        buffer.transform_feedback_active = false;
        buffer.video_coding_active = false;
        buffer.active_video_profile = null;
    }

    pub fn setDeviceMask(buffer: *Buffer, mask: device_group.Mask) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording) return error.InvalidOptions;
        try mask.validate(buffer._device_group_size);
        const set_mask = buffer.cmd_set_device_mask orelse return error.MissingCommand;
        set_mask(handle, mask.bits);
    }

    pub fn end(buffer: *Buffer) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or buffer.rendering_active or buffer.render_pass_active or buffer.video_coding_active) return error.InvalidOptions;
        try core.checkSuccessOptional(if (buffer._pool._device_state) |*state| state else null, buffer.end_command_buffer(handle));
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
        try core.checkSuccessOptional(if (buffer._pool._device_state) |*state| state else null, buffer.reset_command_buffer(handle, flags));
        buffer.state = .initial;
        buffer.simultaneous_use = false;
        buffer.pending_submissions = 0;
        buffer.rendering_active = false;
        buffer.render_pass_active = false;
        buffer.active_render_pass = null;
        buffer.active_framebuffer = null;
        buffer.active_subpass = 0;
        buffer.active_subpass_count = 0;
        buffer.graphics_pipeline_bound = false;
        buffer.compute_pipeline_bound = false;
        buffer.ray_tracing_pipeline_bound = false;
        buffer.execution_graph_pipeline_bound = false;
        buffer.conditional_rendering_active = false;
        buffer.transform_feedback_active = false;
        buffer.video_coding_active = false;
        buffer.active_video_profile = null;
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
            .image = try options.image.rawHandle(),
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
        if (dependency.memory_barriers.len > 64 or dependency.buffer_barriers.len > 64 or
            dependency.image_barriers.len > 64)
        {
            return error.CountOverflow;
        }
        if (buffer.cmd_pipeline_barrier2 == null) {
            var legacy: LegacyDependencyStorage = .{};
            try legacy.init(dependency);
            buffer.cmd_pipeline_barrier(handle, legacy.source_stages, legacy.destination_stages, dependency.flags.toRaw(), @intCast(dependency.memory_barriers.len), if (dependency.memory_barriers.len == 0) null else legacy.memory[0..dependency.memory_barriers.len].ptr, @intCast(dependency.buffer_barriers.len), if (dependency.buffer_barriers.len == 0) null else legacy.buffers[0..dependency.buffer_barriers.len].ptr, @intCast(dependency.image_barriers.len), if (dependency.image_barriers.len == 0) null else legacy.images[0..dependency.image_barriers.len].ptr);
            return;
        }
        const barrier2 = buffer.cmd_pipeline_barrier2.?;
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
        if (buffer.cmd_set_event2) |command| {
            var storage: DependencyStorage = .{};
            try storage.init(dependency);
            command(try buffer.liveHandle(), try event.rawHandle(), &storage.info);
        } else {
            var storage: LegacyDependencyStorage = .{};
            try storage.init(dependency);
            buffer.cmd_set_event(try buffer.liveHandle(), try event.rawHandle(), storage.source_stages);
        }
    }

    pub fn resetEvent(
        buffer: *Buffer,
        event: *const sync.Event,
        stages: types.PipelineStage2Flags,
    ) core.Error!void {
        if (event._device_handle != buffer._device_handle or stages.isEmpty() or buffer.state != .recording) return error.InvalidOptions;
        if (buffer.cmd_reset_event2) |command| {
            command(try buffer.liveHandle(), try event.rawHandle(), stages.toRaw());
        } else {
            buffer.cmd_reset_event(try buffer.liveHandle(), try event.rawHandle(), try legacyStages(stages));
        }
    }

    pub fn waitEvent(
        buffer: *Buffer,
        event: *const sync.Event,
        dependency: sync.DependencyInfo,
    ) core.Error!void {
        if (event._device_handle != buffer._device_handle) return error.InvalidHandle;
        if (buffer.state != .recording) return error.InvalidOptions;
        const event_handle = try event.rawHandle();
        if (buffer.cmd_wait_events2) |command| {
            var storage: DependencyStorage = .{};
            try storage.init(dependency);
            command(try buffer.liveHandle(), 1, @ptrCast(&event_handle), &storage.info);
        } else {
            var storage: LegacyDependencyStorage = .{};
            try storage.init(dependency);
            buffer.cmd_wait_events(try buffer.liveHandle(), 1, @ptrCast(&event_handle), storage.source_stages, storage.destination_stages, @intCast(dependency.memory_barriers.len), if (dependency.memory_barriers.len == 0) null else storage.memory[0..dependency.memory_barriers.len].ptr, @intCast(dependency.buffer_barriers.len), if (dependency.buffer_barriers.len == 0) null else storage.buffers[0..dependency.buffer_barriers.len].ptr, @intCast(dependency.image_barriers.len), if (dependency.image_barriers.len == 0) null else storage.images[0..dependency.image_barriers.len].ptr);
        }
    }

    pub fn beginRendering(
        buffer: *Buffer,
        options: rendering.Options,
    ) core.Error!RenderingScope {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or buffer.rendering_active or buffer.render_pass_active) return error.InvalidOptions;
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
        var shading_rate_info: raw.VkRenderingFragmentShadingRateAttachmentInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_RENDERING_FRAGMENT_SHADING_RATE_ATTACHMENT_INFO_KHR };
        var density_map_info: raw.VkRenderingFragmentDensityMapAttachmentInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_RENDERING_FRAGMENT_DENSITY_MAP_ATTACHMENT_INFO_EXT };
        var next: ?*const anyopaque = null;
        if (options.fragment_density_map_attachment) |attachment| {
            density_map_info.imageView = try attachment.view.rawHandle();
            density_map_info.imageLayout = attachment.layout.toRaw();
            density_map_info.pNext = next;
            next = &density_map_info;
        }
        if (options.fragment_shading_rate_attachment) |attachment| {
            shading_rate_info.imageView = try attachment.view.rawHandle();
            shading_rate_info.imageLayout = attachment.layout.toRaw();
            shading_rate_info.shadingRateAttachmentTexelSize = attachment.texel_size.toRaw();
            shading_rate_info.pNext = next;
            next = &shading_rate_info;
        }
        const info: raw.VkRenderingInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_RENDERING_INFO,
            .pNext = next,
            .flags = options.flags.toRaw(),
            .renderArea = options.render_area.toRaw(),
            .layerCount = options.layer_count,
            .viewMask = options.view_mask,
            .colorAttachmentCount = @intCast(options.color_attachments.len),
            .pColorAttachments = if (options.color_attachments.len == 0) null else color_attachments[0..options.color_attachments.len].ptr,
            .pDepthAttachment = if (options.depth_attachment != null) &depth_attachment else null,
            .pStencilAttachment = if (options.stencil_attachment != null) &stencil_attachment else null,
        };
        var owner = try core.Owner.init({});
        errdefer _ = owner.release({}) catch {};
        begin_rendering(handle, &info);
        buffer.rendering_active = true;
        return .{ ._owner = owner, .buffer = buffer };
    }

    pub fn endRendering(buffer: *Buffer) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or !buffer.rendering_active) return error.InvalidOptions;
        const end_rendering = buffer.cmd_end_rendering orelse return error.MissingCommand;
        end_rendering(handle);
        buffer.rendering_active = false;
    }

    pub fn beginRenderPass(buffer: *Buffer, options: render_passes.BeginOptions) core.Error!RenderPassScope {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or buffer.rendering_active or buffer.render_pass_active) return error.InvalidOptions;
        if (options.render_pass._device_handle != buffer._device_handle or options.framebuffer._device_handle != buffer._device_handle) return error.InvalidHandle;
        const render_pass_handle = try options.render_pass.rawHandle();
        const framebuffer_handle = try options.framebuffer.rawHandle();
        if (options.framebuffer._render_pass_handle != render_pass_handle or
            options.render_area.offset.x < 0 or options.render_area.offset.y < 0 or
            options.render_area.extent.width == 0 or options.render_area.extent.height == 0)
        {
            return error.InvalidOptions;
        }
        const right = std.math.add(u32, @intCast(options.render_area.offset.x), options.render_area.extent.width) catch return error.SizeOverflow;
        const bottom = std.math.add(u32, @intCast(options.render_area.offset.y), options.render_area.extent.height) catch return error.SizeOverflow;
        if (right > options.framebuffer.width or bottom > options.framebuffer.height or
            options.clear_values.len > options.render_pass.attachmentCount() or
            options.clear_values.len > render_passes.attachment_count_max)
        {
            return error.InvalidOptions;
        }
        var clear_values: [render_passes.attachment_count_max]raw.VkClearValue = undefined;
        for (options.clear_values, 0..) |value, index| clear_values[index] = value.toRaw();
        var attachment_views: [render_passes.framebuffer_attachment_count_max]raw.VkImageView = undefined;
        var attachment_info: raw.VkRenderPassAttachmentBeginInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_RENDER_PASS_ATTACHMENT_BEGIN_INFO,
        };
        if (options.framebuffer.imageless) {
            if (options.imageless_attachments.len != options.framebuffer.attachment_count) return error.InvalidOptions;
            for (options.imageless_attachments, 0..) |view, index| {
                if (view._device_handle != buffer._device_handle or view.format != options.render_pass.attachmentFormat(index).?) return error.InvalidHandle;
                if (view.samples) |samples| if (samples != options.render_pass.attachmentSamples(index).?) return error.InvalidOptions;
                if (view.extent) |extent| if (right > extent.width or bottom > extent.height) return error.InvalidOptions;
                if (view.layer_count) |layers| if (options.framebuffer.layers > layers) return error.InvalidOptions;
                attachment_views[index] = try view.rawHandle();
            }
            attachment_info.attachmentCount = @intCast(options.imageless_attachments.len);
            attachment_info.pAttachments = if (options.imageless_attachments.len == 0) null else attachment_views[0..options.imageless_attachments.len].ptr;
        } else if (options.imageless_attachments.len != 0) return error.InvalidOptions;
        const begin_info: raw.VkRenderPassBeginInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .pNext = if (options.framebuffer.imageless) &attachment_info else null,
            .renderPass = render_pass_handle,
            .framebuffer = framebuffer_handle,
            .renderArea = options.render_area.toRaw(),
            .clearValueCount = @intCast(options.clear_values.len),
            .pClearValues = if (options.clear_values.len == 0) null else clear_values[0..options.clear_values.len].ptr,
        };
        var owner = try core.Owner.init({});
        errdefer _ = owner.release({}) catch {};
        if (buffer.cmd_begin_render_pass2) |begin2| {
            const subpass_begin: raw.VkSubpassBeginInfo = .{
                .sType = raw.VK_STRUCTURE_TYPE_SUBPASS_BEGIN_INFO,
                .contents = options.contents.toRaw(),
            };
            begin2(handle, &begin_info, &subpass_begin);
        } else buffer.cmd_begin_render_pass(handle, &begin_info, options.contents.toRaw());
        buffer.render_pass_active = true;
        buffer.active_render_pass = render_pass_handle;
        buffer.active_framebuffer = framebuffer_handle;
        buffer.active_subpass = 0;
        buffer.active_subpass_count = @intCast(options.render_pass.subpassCount());
        buffer.graphics_pipeline_bound = false;
        return .{ ._owner = owner, .buffer = buffer };
    }

    pub fn nextSubpass(buffer: *Buffer, contents: render_passes.Contents) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or !buffer.render_pass_active or buffer.active_subpass + 1 >= buffer.active_subpass_count) return error.InvalidOptions;
        if (buffer.cmd_next_subpass2) |next2| {
            const end_info: raw.VkSubpassEndInfo = .{ .sType = raw.VK_STRUCTURE_TYPE_SUBPASS_END_INFO };
            const begin_info: raw.VkSubpassBeginInfo = .{ .sType = raw.VK_STRUCTURE_TYPE_SUBPASS_BEGIN_INFO, .contents = contents.toRaw() };
            next2(handle, &begin_info, &end_info);
        } else buffer.cmd_next_subpass(handle, contents.toRaw());
        buffer.active_subpass += 1;
        buffer.graphics_pipeline_bound = false;
    }

    pub fn endRenderPass(buffer: *Buffer) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or !buffer.render_pass_active) return error.InvalidOptions;
        if (buffer.cmd_end_render_pass2) |end2| {
            const end_info: raw.VkSubpassEndInfo = .{ .sType = raw.VK_STRUCTURE_TYPE_SUBPASS_END_INFO };
            end2(handle, &end_info);
        } else buffer.cmd_end_render_pass(handle);
        buffer.render_pass_active = false;
        buffer.active_render_pass = null;
        buffer.active_framebuffer = null;
        buffer.active_subpass = 0;
        buffer.active_subpass_count = 0;
        buffer.graphics_pipeline_bound = false;
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
        if (source._handle == destination._handle) try validateSameBufferCopyRegions(regions);
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
        var regions2: [64]raw.VkBufferImageCopy2 = undefined;
        for (options.regions, 0..) |region, index| {
            if (region.buffer_offset.bytes() >= options.source.size.bytes()) return error.InvalidOptions;
            try validateImageRegion(options.destination, region.image_subresource, region.image_offset, region.image_extent);
            regions[index] = try region.toRaw();
            regions2[index] = try region.toRaw2();
        }
        if (command_buffer.cmd_copy_buffer_to_image2) |copy2| {
            const info: raw.VkCopyBufferToImageInfo2 = .{ .sType = raw.VK_STRUCTURE_TYPE_COPY_BUFFER_TO_IMAGE_INFO_2, .srcBuffer = try options.source.rawHandle(), .dstImage = try options.destination.handle(), .dstImageLayout = options.destination_layout.toRaw(), .regionCount = @intCast(options.regions.len), .pRegions = regions2[0..options.regions.len].ptr };
            copy2(handle, &info);
        } else command_buffer.cmd_copy_buffer_to_image(handle, try options.source.rawHandle(), try options.destination.handle(), options.destination_layout.toRaw(), @intCast(options.regions.len), regions[0..options.regions.len].ptr);
    }

    pub fn copyImageToBuffer(command_buffer: *Buffer, options: transfer.ImageToBuffer) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or options.regions.len == 0 or options.regions.len > 64) return error.InvalidOptions;
        if (options.destination._device_handle != command_buffer._device_handle or options.source.deviceHandle() != command_buffer._device_handle) return error.InvalidHandle;
        var regions: [64]raw.VkBufferImageCopy = undefined;
        var regions2: [64]raw.VkBufferImageCopy2 = undefined;
        for (options.regions, 0..) |region, index| {
            if (region.buffer_offset.bytes() >= options.destination.size.bytes()) return error.InvalidOptions;
            try validateImageRegion(options.source, region.image_subresource, region.image_offset, region.image_extent);
            regions[index] = try region.toRaw();
            regions2[index] = try region.toRaw2();
        }
        if (command_buffer.cmd_copy_image_to_buffer2) |copy2| {
            const info: raw.VkCopyImageToBufferInfo2 = .{ .sType = raw.VK_STRUCTURE_TYPE_COPY_IMAGE_TO_BUFFER_INFO_2, .srcImage = try options.source.handle(), .srcImageLayout = options.source_layout.toRaw(), .dstBuffer = try options.destination.rawHandle(), .regionCount = @intCast(options.regions.len), .pRegions = regions2[0..options.regions.len].ptr };
            copy2(handle, &info);
        } else command_buffer.cmd_copy_image_to_buffer(handle, try options.source.handle(), options.source_layout.toRaw(), try options.destination.rawHandle(), @intCast(options.regions.len), regions[0..options.regions.len].ptr);
    }

    pub fn copyImage(command_buffer: *Buffer, options: transfer.ImageToImage) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or options.regions.len == 0 or options.regions.len > 64) return error.InvalidOptions;
        if (options.source.deviceHandle() != command_buffer._device_handle or options.destination.deviceHandle() != command_buffer._device_handle) return error.InvalidHandle;
        var regions: [64]raw.VkImageCopy = undefined;
        var regions2: [64]raw.VkImageCopy2 = undefined;
        for (options.regions, 0..) |region, index| {
            try validateImageRegion(options.source, region.source_subresource, region.source_offset, region.extent);
            try validateImageRegion(options.destination, region.destination_subresource, region.destination_offset, region.extent);
            regions[index] = try region.toRaw();
            regions2[index] = try region.toRaw2();
        }
        if (command_buffer.cmd_copy_image2) |copy2| {
            const info: raw.VkCopyImageInfo2 = .{ .sType = raw.VK_STRUCTURE_TYPE_COPY_IMAGE_INFO_2, .srcImage = try options.source.handle(), .srcImageLayout = options.source_layout.toRaw(), .dstImage = try options.destination.handle(), .dstImageLayout = options.destination_layout.toRaw(), .regionCount = @intCast(options.regions.len), .pRegions = regions2[0..options.regions.len].ptr };
            copy2(handle, &info);
        } else command_buffer.cmd_copy_image(handle, try options.source.handle(), options.source_layout.toRaw(), try options.destination.handle(), options.destination_layout.toRaw(), @intCast(options.regions.len), regions[0..options.regions.len].ptr);
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
        var raw_regions2: [64]raw.VkImageBlit2 = undefined;
        for (regions, 0..) |region, index| {
            const source_extent = types.Extent3D{ .width = @intCast(@abs(region.source_offsets[1].x - region.source_offsets[0].x)), .height = @intCast(@abs(region.source_offsets[1].y - region.source_offsets[0].y)), .depth = @intCast(@abs(region.source_offsets[1].z - region.source_offsets[0].z)) };
            const destination_extent = types.Extent3D{ .width = @intCast(@abs(region.destination_offsets[1].x - region.destination_offsets[0].x)), .height = @intCast(@abs(region.destination_offsets[1].y - region.destination_offsets[0].y)), .depth = @intCast(@abs(region.destination_offsets[1].z - region.destination_offsets[0].z)) };
            const source_offset = types.Offset3D{ .x = @min(region.source_offsets[0].x, region.source_offsets[1].x), .y = @min(region.source_offsets[0].y, region.source_offsets[1].y), .z = @min(region.source_offsets[0].z, region.source_offsets[1].z) };
            const destination_offset = types.Offset3D{ .x = @min(region.destination_offsets[0].x, region.destination_offsets[1].x), .y = @min(region.destination_offsets[0].y, region.destination_offsets[1].y), .z = @min(region.destination_offsets[0].z, region.destination_offsets[1].z) };
            try validateImageRegion(source, region.source_subresource, source_offset, source_extent);
            try validateImageRegion(destination, region.destination_subresource, destination_offset, destination_extent);
            raw_regions[index] = try region.toRaw();
            raw_regions2[index] = try region.toRaw2();
        }
        if (command_buffer.cmd_blit_image2) |blit2| {
            const info: raw.VkBlitImageInfo2 = .{ .sType = raw.VK_STRUCTURE_TYPE_BLIT_IMAGE_INFO_2, .srcImage = try source.handle(), .srcImageLayout = source_layout.toRaw(), .dstImage = try destination.handle(), .dstImageLayout = destination_layout.toRaw(), .regionCount = @intCast(regions.len), .pRegions = raw_regions2[0..regions.len].ptr, .filter = filter.toRaw() };
            blit2(handle, &info);
        } else command_buffer.cmd_blit_image(handle, try source.handle(), source_layout.toRaw(), try destination.handle(), destination_layout.toRaw(), @intCast(regions.len), raw_regions[0..regions.len].ptr, filter.toRaw());
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
        var raw_regions2: [64]raw.VkImageResolve2 = undefined;
        for (regions, 0..) |region, index| {
            try validateImageRegion(source, region.source_subresource, region.source_offset, region.extent);
            try validateImageRegion(destination, region.destination_subresource, region.destination_offset, region.extent);
            raw_regions[index] = try region.toRaw();
            raw_regions2[index] = try region.toRaw2();
        }
        if (command_buffer.cmd_resolve_image2) |resolve2| {
            const info: raw.VkResolveImageInfo2 = .{ .sType = raw.VK_STRUCTURE_TYPE_RESOLVE_IMAGE_INFO_2, .srcImage = try source.handle(), .srcImageLayout = source_layout.toRaw(), .dstImage = try destination.handle(), .dstImageLayout = destination_layout.toRaw(), .regionCount = @intCast(regions.len), .pRegions = raw_regions2[0..regions.len].ptr };
            resolve2(handle, &info);
        } else command_buffer.cmd_resolve_image(handle, try source.handle(), source_layout.toRaw(), try destination.handle(), destination_layout.toRaw(), @intCast(regions.len), raw_regions[0..regions.len].ptr);
    }

    pub fn bindPipeline(command_buffer: *Buffer, value: *const pipeline.Pipeline) core.Error!void {
        const handle = try command_buffer.liveHandle();
        if (command_buffer.state != .recording or value._device_handle != command_buffer._device_handle) return error.InvalidOptions;
        switch (value.bind_point) {
            .graphics => {
                if (command_buffer.rendering_active and !value._dynamic_rendering) return error.InvalidOptions;
                if (command_buffer.render_pass_active and
                    (value._render_pass_handle != command_buffer.active_render_pass or value._subpass != command_buffer.active_subpass))
                {
                    return error.InvalidOptions;
                }
                command_buffer.graphics_pipeline_bound = true;
            },
            .compute => command_buffer.compute_pipeline_bound = true,
            .ray_tracing => {
                if (command_buffer.rendering_active or command_buffer.render_pass_active or command_buffer.video_coding_active) return error.InvalidOptions;
                command_buffer.ray_tracing_pipeline_bound = true;
            },
            .execution_graph => {
                if (command_buffer.rendering_active or command_buffer.render_pass_active or command_buffer.video_coding_active) return error.InvalidOptions;
                command_buffer.execution_graph_pipeline_bound = true;
            },
            else => return error.InvalidOptions,
        }
        command_buffer.cmd_bind_pipeline(handle, value.bind_point.toRaw(), try value.rawHandle());
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

    pub fn pushDescriptorSet(
        command_buffer: *Buffer,
        bind_point: pipeline.BindPoint,
        layout: *const pipeline.Layout,
        set_index: u32,
        set_layout: *const descriptor.SetLayout,
        writes: []const descriptor.PushWrite,
    ) core.Error!void {
        const push_descriptors = command_buffer.cmd_push_descriptor_set orelse return error.MissingCommand;
        if (command_buffer.state != .recording or layout._device_handle != command_buffer._device_handle or
            set_layout._device_handle != command_buffer._device_handle)
        {
            return error.InvalidHandle;
        }
        const set_layout_handle = try set_layout.rawHandle();
        if (!layout.supportsDescriptorSet(set_index, set_layout_handle)) return error.InvalidOptions;
        return descriptor.push(
            command_buffer._device_handle,
            push_descriptors,
            try command_buffer.liveHandle(),
            bind_point.toRaw(),
            try layout.rawHandle(),
            set_index,
            set_layout,
            writes,
        );
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

    pub fn setStencilCompareMask(command_buffer: *Buffer, faces: StencilFaces, mask: u32) core.Error!void {
        if (command_buffer.state != .recording or faces.toRaw() == 0) return error.InvalidOptions;
        command_buffer.cmd_set_stencil_compare_mask(try command_buffer.liveHandle(), faces.toRaw(), mask);
    }

    pub fn setStencilWriteMask(command_buffer: *Buffer, faces: StencilFaces, mask: u32) core.Error!void {
        if (command_buffer.state != .recording or faces.toRaw() == 0) return error.InvalidOptions;
        command_buffer.cmd_set_stencil_write_mask(try command_buffer.liveHandle(), faces.toRaw(), mask);
    }

    pub fn setStencilReference(command_buffer: *Buffer, faces: StencilFaces, reference: u32) core.Error!void {
        if (command_buffer.state != .recording or faces.toRaw() == 0) return error.InvalidOptions;
        command_buffer.cmd_set_stencil_reference(try command_buffer.liveHandle(), faces.toRaw(), reference);
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
        if (command_buffer.state != .recording or !(command_buffer.rendering_active or command_buffer.render_pass_active) or !command_buffer.graphics_pipeline_bound or options.vertex_count == 0 or options.instance_count == 0) return error.InvalidOptions;
        command_buffer.cmd_draw(try command_buffer.liveHandle(), options.vertex_count, options.instance_count, options.first_vertex, options.first_instance);
    }

    pub fn drawIndexed(command_buffer: *Buffer, options: DrawIndexedOptions) core.Error!void {
        if (command_buffer.state != .recording or !(command_buffer.rendering_active or command_buffer.render_pass_active) or !command_buffer.graphics_pipeline_bound or options.index_count == 0 or options.instance_count == 0) return error.InvalidOptions;
        command_buffer.cmd_draw_indexed(try command_buffer.liveHandle(), options.index_count, options.instance_count, options.first_index, options.vertex_offset, options.first_instance);
    }

    pub fn drawMulti(command_buffer: *Buffer, draws: []const MultiDraw, instance_count: u32, first_instance: u32) core.Error!void {
        const command = command_buffer.cmd_draw_multi orelse return error.MissingCommand;
        if (command_buffer.state != .recording or !(command_buffer.rendering_active or command_buffer.render_pass_active) or !command_buffer.graphics_pipeline_bound or draws.len == 0 or draws.len > 256 or instance_count == 0) return error.InvalidOptions;
        var values: [256]raw.VkMultiDrawInfoEXT = undefined;
        for (draws, 0..) |draw_info, index| {
            if (draw_info.vertex_count == 0) return error.InvalidOptions;
            values[index] = .{ .firstVertex = draw_info.first_vertex, .vertexCount = draw_info.vertex_count };
        }
        command(try command_buffer.liveHandle(), @intCast(draws.len), values[0..draws.len].ptr, instance_count, first_instance, @sizeOf(raw.VkMultiDrawInfoEXT));
    }

    pub fn drawMultiIndexed(command_buffer: *Buffer, draws: []const MultiDrawIndexed, instance_count: u32, first_instance: u32, common_vertex_offset: ?i32) core.Error!void {
        const command = command_buffer.cmd_draw_multi_indexed orelse return error.MissingCommand;
        if (command_buffer.state != .recording or !(command_buffer.rendering_active or command_buffer.render_pass_active) or !command_buffer.graphics_pipeline_bound or draws.len == 0 or draws.len > 256 or instance_count == 0) return error.InvalidOptions;
        var values: [256]raw.VkMultiDrawIndexedInfoEXT = undefined;
        for (draws, 0..) |draw_info, index| {
            if (draw_info.index_count == 0) return error.InvalidOptions;
            values[index] = .{ .firstIndex = draw_info.first_index, .indexCount = draw_info.index_count, .vertexOffset = draw_info.vertex_offset };
        }
        var vertex_offset = common_vertex_offset orelse 0;
        command(try command_buffer.liveHandle(), @intCast(draws.len), values[0..draws.len].ptr, instance_count, first_instance, @sizeOf(raw.VkMultiDrawIndexedInfoEXT), if (common_vertex_offset != null) &vertex_offset else null);
    }

    pub fn drawIndirect(command_buffer: *Buffer, indirect: *const buffers.Buffer, offset: core.DeviceOffset, draw_count: u32, stride: u32) core.Error!void {
        if (command_buffer.state != .recording or !(command_buffer.rendering_active or command_buffer.render_pass_active) or !command_buffer.graphics_pipeline_bound or indirect._device_handle != command_buffer._device_handle or draw_count == 0 or stride < @sizeOf(DrawIndirectCommand) or stride % 4 != 0) return error.InvalidOptions;
        try validateIndirectRange(indirect, offset, draw_count, stride, @sizeOf(DrawIndirectCommand));
        command_buffer.cmd_draw_indirect(try command_buffer.liveHandle(), try indirect.rawHandle(), offset.bytes(), draw_count, stride);
    }

    pub fn drawIndexedIndirect(command_buffer: *Buffer, indirect: *const buffers.Buffer, offset: core.DeviceOffset, draw_count: u32, stride: u32) core.Error!void {
        if (command_buffer.state != .recording or !(command_buffer.rendering_active or command_buffer.render_pass_active) or !command_buffer.graphics_pipeline_bound or indirect._device_handle != command_buffer._device_handle or draw_count == 0 or stride < @sizeOf(DrawIndexedIndirectCommand) or stride % 4 != 0) return error.InvalidOptions;
        try validateIndirectRange(indirect, offset, draw_count, stride, @sizeOf(DrawIndexedIndirectCommand));
        command_buffer.cmd_draw_indexed_indirect(try command_buffer.liveHandle(), try indirect.rawHandle(), offset.bytes(), draw_count, stride);
    }

    pub fn drawIndirectCount(command_buffer: *Buffer, indirect: *const buffers.Buffer, offset: core.DeviceOffset, count_buffer: *const buffers.Buffer, count_offset: core.DeviceOffset, max_draw_count: u32, stride: u32) core.Error!void {
        const command = command_buffer.cmd_draw_indirect_count orelse return error.MissingCommand;
        if (command_buffer.state != .recording or !(command_buffer.rendering_active or command_buffer.render_pass_active) or !command_buffer.graphics_pipeline_bound or indirect._device_handle != command_buffer._device_handle or count_buffer._device_handle != command_buffer._device_handle or max_draw_count == 0 or stride < @sizeOf(DrawIndirectCommand) or stride % 4 != 0 or count_offset.bytes() % 4 != 0) return error.InvalidOptions;
        try validateIndirectRange(indirect, offset, max_draw_count, stride, @sizeOf(DrawIndirectCommand));
        try validateFixedRange(count_buffer, count_offset, @sizeOf(u32));
        command(try command_buffer.liveHandle(), try indirect.rawHandle(), offset.bytes(), try count_buffer.rawHandle(), count_offset.bytes(), max_draw_count, stride);
    }

    pub fn drawIndexedIndirectCount(command_buffer: *Buffer, indirect: *const buffers.Buffer, offset: core.DeviceOffset, count_buffer: *const buffers.Buffer, count_offset: core.DeviceOffset, max_draw_count: u32, stride: u32) core.Error!void {
        const command = command_buffer.cmd_draw_indexed_indirect_count orelse return error.MissingCommand;
        if (command_buffer.state != .recording or !(command_buffer.rendering_active or command_buffer.render_pass_active) or !command_buffer.graphics_pipeline_bound or indirect._device_handle != command_buffer._device_handle or count_buffer._device_handle != command_buffer._device_handle or max_draw_count == 0 or stride < @sizeOf(DrawIndexedIndirectCommand) or stride % 4 != 0 or count_offset.bytes() % 4 != 0) return error.InvalidOptions;
        try validateIndirectRange(indirect, offset, max_draw_count, stride, @sizeOf(DrawIndexedIndirectCommand));
        try validateFixedRange(count_buffer, count_offset, @sizeOf(u32));
        command(try command_buffer.liveHandle(), try indirect.rawHandle(), offset.bytes(), try count_buffer.rawHandle(), count_offset.bytes(), max_draw_count, stride);
    }

    pub fn dispatch(command_buffer: *Buffer, options: DispatchOptions) core.Error!void {
        if (command_buffer.state != .recording or command_buffer.rendering_active or command_buffer.render_pass_active or !command_buffer.compute_pipeline_bound or options.x == 0 or options.y == 0 or options.z == 0) return error.InvalidOptions;
        command_buffer.cmd_dispatch(try command_buffer.liveHandle(), options.x, options.y, options.z);
    }

    pub fn dispatchIndirect(command_buffer: *Buffer, indirect: *const buffers.Buffer, offset: core.DeviceOffset) core.Error!void {
        if (command_buffer.state != .recording or command_buffer.rendering_active or command_buffer.render_pass_active or !command_buffer.compute_pipeline_bound or indirect._device_handle != command_buffer._device_handle or offset.bytes() % 4 != 0) return error.InvalidOptions;
        try validateFixedRange(indirect, offset, @sizeOf(DispatchIndirectCommand));
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
        if (command_buffer.state != .recording or command_buffer.rendering_active or command_buffer.render_pass_active or !command_buffer.compute_pipeline_bound or groups.x == 0 or groups.y == 0 or groups.z == 0) return error.InvalidOptions;
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
        var owner = try core.Owner.init({});
        errdefer _ = owner.release({}) catch {};
        try buffer.beginLabel(options);
        return .{ ._owner = owner, .command_buffer = try buffer.liveHandle(), .end_label = end_label };
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

    pub fn beginConditionalRendering(
        buffer: *Buffer,
        options: ConditionalRenderingOptions,
    ) core.Error!ConditionalRenderingScope {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or buffer.conditional_rendering_active) return error.InvalidOptions;
        if (options.buffer._device_handle != buffer._device_handle or options.offset.bytes() >= options.buffer.size.bytes() or options.offset.bytes() % 4 != 0) return error.InvalidOptions;
        const begin_command = buffer.cmd_begin_conditional_rendering_ext orelse return error.MissingCommand;
        _ = buffer.cmd_end_conditional_rendering_ext orelse return error.MissingCommand;
        var owner = try core.Owner.init({});
        errdefer _ = owner.release({}) catch {};
        const info: raw.VkConditionalRenderingBeginInfoEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_CONDITIONAL_RENDERING_BEGIN_INFO_EXT,
            .buffer = try options.buffer.rawHandle(),
            .offset = options.offset.bytes(),
            .flags = if (options.inverted) raw.VK_CONDITIONAL_RENDERING_INVERTED_BIT_EXT else 0,
        };
        begin_command(handle, &info);
        buffer.conditional_rendering_active = true;
        return .{ ._owner = owner, .buffer = buffer };
    }

    pub fn endConditionalRendering(buffer: *Buffer) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or !buffer.conditional_rendering_active) return error.InvalidOptions;
        const end_command = buffer.cmd_end_conditional_rendering_ext orelse return error.MissingCommand;
        end_command(handle);
        buffer.conditional_rendering_active = false;
    }

    pub fn beginTransformFeedback(
        buffer: *Buffer,
        first_counter_buffer: u32,
        counters: []const TransformFeedbackCounter,
    ) core.Error!TransformFeedbackScope {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or buffer.transform_feedback_active) return error.InvalidOptions;
        if (counters.len > transform_feedback_counter_max) return error.CountOverflow;
        const begin_command = buffer.cmd_begin_transform_feedback_ext orelse return error.MissingCommand;
        _ = buffer.cmd_end_transform_feedback_ext orelse return error.MissingCommand;
        var handles: [transform_feedback_counter_max]raw.VkBuffer = undefined;
        var offsets: [transform_feedback_counter_max]raw.VkDeviceSize = undefined;
        for (counters, 0..) |counter, index| {
            if (counter.buffer._device_handle != buffer._device_handle or counter.offset.bytes() >= counter.buffer.size.bytes() or counter.offset.bytes() % 4 != 0) return error.InvalidOptions;
            handles[index] = try counter.buffer.rawHandle();
            offsets[index] = counter.offset.bytes();
        }
        var owner = try core.Owner.init({});
        errdefer _ = owner.release({}) catch {};
        begin_command(handle, first_counter_buffer, @intCast(counters.len), if (counters.len == 0) null else handles[0..counters.len].ptr, if (counters.len == 0) null else offsets[0..counters.len].ptr);
        buffer.transform_feedback_active = true;
        var scope: TransformFeedbackScope = .{
            ._owner = owner,
            .buffer = buffer,
            .first_counter_buffer = first_counter_buffer,
            .counter_count = counters.len,
        };
        for (handles[0..counters.len], 0..) |item, index| scope.handles[index] = item;
        for (offsets[0..counters.len], 0..) |item, index| scope.offsets[index] = item;
        return scope;
    }

    fn endTransformFeedback(buffer: *Buffer, scope: *const TransformFeedbackScope) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or !buffer.transform_feedback_active) return error.InvalidOptions;
        const end_command = buffer.cmd_end_transform_feedback_ext orelse return error.MissingCommand;
        end_command(handle, scope.first_counter_buffer, @intCast(scope.counter_count), if (scope.counter_count == 0) null else scope.handles[0..scope.counter_count].ptr, if (scope.counter_count == 0) null else scope.offsets[0..scope.counter_count].ptr);
        buffer.transform_feedback_active = false;
    }

    pub fn beginVideoCoding(buffer: *Buffer, options: video.CodingOptions) core.Error!VideoCodingScope {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or buffer.video_coding_active or buffer.rendering_active or buffer.render_pass_active) return error.InvalidOptions;
        if (options.session._device_handle != buffer._device_handle) return error.InvalidHandle;
        if (!video.referencesMatch(options.session.profile, options.references)) return error.UnsupportedCodec;
        const begin_command = buffer.cmd_begin_video_coding_khr orelse return error.MissingCommand;
        _ = buffer.cmd_end_video_coding_khr orelse return error.MissingCommand;
        const parameters_handle = if (options.parameters) |parameters| blk: {
            if (parameters._device_handle != buffer._device_handle) return error.InvalidHandle;
            break :blk try parameters.rawHandle();
        } else null;
        var owner = try core.Owner.init({});
        errdefer _ = owner.release({}) catch {};
        var reference_storage: video.ReferenceStorage = .{};
        const references = try reference_storage.build(buffer._device_handle, options.references);
        const info: raw.VkVideoBeginCodingInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_VIDEO_BEGIN_CODING_INFO_KHR,
            .videoSession = try options.session.rawHandle(),
            .videoSessionParameters = parameters_handle,
            .referenceSlotCount = @intCast(references.len),
            .pReferenceSlots = if (references.len == 0) null else references.ptr,
        };
        begin_command(handle, &info);
        buffer.video_coding_active = true;
        buffer.active_video_profile = options.session.profile;
        return .{ ._owner = owner, .buffer = buffer };
    }

    fn endVideoCoding(buffer: *Buffer) core.Error!void {
        const handle = try buffer.liveHandle();
        if (buffer.state != .recording or !buffer.video_coding_active) return error.InvalidOptions;
        const end_command = buffer.cmd_end_video_coding_khr orelse return error.MissingCommand;
        const info: raw.VkVideoEndCodingInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_VIDEO_END_CODING_INFO_KHR,
        };
        end_command(handle, &info);
        buffer.video_coding_active = false;
        buffer.active_video_profile = null;
    }

    pub fn controlVideoCoding(buffer: *Buffer, options: video.Control) core.Error!void {
        if (buffer.state != .recording or !buffer.video_coding_active) return error.InvalidOptions;
        const control = buffer.cmd_control_video_coding_khr orelse return error.MissingCommand;
        const info: raw.VkVideoCodingControlInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_VIDEO_CODING_CONTROL_INFO_KHR,
            .flags = options.flags(),
        };
        control(try buffer.liveHandle(), &info);
    }

    pub fn decodeVideo(buffer: *Buffer, options: video.DecodeOptions) core.Error!void {
        if (buffer.state != .recording or !buffer.video_coding_active or options.bitstream._device_handle != buffer._device_handle) return error.InvalidHandle;
        const decode = buffer.cmd_decode_video_khr orelse return error.MissingCommand;
        const profile = buffer.active_video_profile orelse return error.InvalidOptions;
        if (!video.decodeMatches(profile, options.codec) or !video.referencesMatch(profile, options.references)) return error.UnsupportedCodec;
        if (options.setup_reference) |setup| if (!video.referencesMatch(profile, &.{setup})) return error.UnsupportedCodec;
        if (options.range.bytes() == 0 or options.offset.bytes() > options.bitstream.size.bytes() or options.range.bytes() > options.bitstream.size.bytes() - options.offset.bytes()) return error.InvalidOptions;
        var references_storage: video.ReferenceStorage = .{};
        const references = try references_storage.build(buffer._device_handle, options.references);
        var setup_storage: video.ReferenceStorage = .{};
        const setup_slots = if (options.setup_reference) |setup| try setup_storage.build(buffer._device_handle, &.{setup}) else &.{};
        const setup_pointer: ?*const raw.VkVideoReferenceSlotInfoKHR = if (setup_slots.len == 0) null else &setup_slots[0];
        var h264: raw.VkVideoDecodeH264PictureInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_H264_PICTURE_INFO_KHR };
        var h265: raw.VkVideoDecodeH265PictureInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_H265_PICTURE_INFO_KHR };
        const codec_pointer: *const anyopaque = switch (options.codec) {
            .h264 => |value| blk: {
                if (value.slice_offsets.len == 0 or value.slice_offsets.len > 4096) return error.InvalidOptions;
                h264.pStdPictureInfo = value.picture;
                h264.sliceCount = @intCast(value.slice_offsets.len);
                h264.pSliceOffsets = value.slice_offsets.ptr;
                break :blk &h264;
            },
            .h265 => |value| blk: {
                if (value.slice_segment_offsets.len == 0 or value.slice_segment_offsets.len > 4096) return error.InvalidOptions;
                h265.pStdPictureInfo = value.picture;
                h265.sliceSegmentCount = @intCast(value.slice_segment_offsets.len);
                h265.pSliceSegmentOffsets = value.slice_segment_offsets.ptr;
                break :blk &h265;
            },
        };
        const info: raw.VkVideoDecodeInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_INFO_KHR,
            .pNext = codec_pointer,
            .srcBuffer = try options.bitstream.rawHandle(),
            .srcBufferOffset = options.offset.bytes(),
            .srcBufferRange = options.range.bytes(),
            .dstPictureResource = try options.destination.toRaw(buffer._device_handle),
            .pSetupReferenceSlot = setup_pointer,
            .referenceSlotCount = @intCast(references.len),
            .pReferenceSlots = if (references.len == 0) null else references.ptr,
        };
        decode(try buffer.liveHandle(), &info);
    }

    pub fn encodeVideo(buffer: *Buffer, options: video.EncodeOptions) core.Error!void {
        if (buffer.state != .recording or !buffer.video_coding_active or options.bitstream._device_handle != buffer._device_handle) return error.InvalidHandle;
        const encode = buffer.cmd_encode_video_khr orelse return error.MissingCommand;
        const profile = buffer.active_video_profile orelse return error.InvalidOptions;
        if (!video.encodeMatches(profile, options.codec) or !video.referencesMatch(profile, options.references)) return error.UnsupportedCodec;
        if (options.setup_reference) |setup| if (!video.referencesMatch(profile, &.{setup})) return error.UnsupportedCodec;
        if (options.range.bytes() == 0 or options.offset.bytes() > options.bitstream.size.bytes() or options.range.bytes() > options.bitstream.size.bytes() - options.offset.bytes()) return error.InvalidOptions;
        var references_storage: video.ReferenceStorage = .{};
        const references = try references_storage.build(buffer._device_handle, options.references);
        var setup_storage: video.ReferenceStorage = .{};
        const setup_slots = if (options.setup_reference) |setup| try setup_storage.build(buffer._device_handle, &.{setup}) else &.{};
        const setup_pointer: ?*const raw.VkVideoReferenceSlotInfoKHR = if (setup_slots.len == 0) null else &setup_slots[0];
        var h264: raw.VkVideoEncodeH264PictureInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_PICTURE_INFO_KHR };
        var h265: raw.VkVideoEncodeH265PictureInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_PICTURE_INFO_KHR };
        const codec_pointer: *const anyopaque = switch (options.codec) {
            .h264 => |value| blk: {
                if (value.slices.len == 0 or value.slices.len > 4096) return error.InvalidOptions;
                h264.pStdPictureInfo = value.picture;
                h264.naluSliceEntryCount = @intCast(value.slices.len);
                h264.pNaluSliceEntries = value.slices.ptr;
                h264.generatePrefixNalu = if (value.generate_prefix_nalu) raw.VK_TRUE else raw.VK_FALSE;
                break :blk &h264;
            },
            .h265 => |value| blk: {
                if (value.slices.len == 0 or value.slices.len > 4096) return error.InvalidOptions;
                h265.pStdPictureInfo = value.picture;
                h265.naluSliceSegmentEntryCount = @intCast(value.slices.len);
                h265.pNaluSliceSegmentEntries = value.slices.ptr;
                break :blk &h265;
            },
        };
        const info: raw.VkVideoEncodeInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_INFO_KHR,
            .pNext = codec_pointer,
            .dstBuffer = try options.bitstream.rawHandle(),
            .dstBufferOffset = options.offset.bytes(),
            .dstBufferRange = options.range.bytes(),
            .srcPictureResource = try options.source.toRaw(buffer._device_handle),
            .pSetupReferenceSlot = setup_pointer,
            .referenceSlotCount = @intCast(references.len),
            .pReferenceSlots = if (references.len == 0) null else references.ptr,
            .precedingExternallyEncodedBytes = options.preceding_externally_encoded_bytes,
        };
        encode(try buffer.liveHandle(), &info);
    }

    pub fn rawHandle(buffer: *Buffer) core.Error!raw.VkCommandBuffer {
        return try buffer.liveHandle();
    }

    pub fn debugObject(buffer: *Buffer) core.Error!debug_utils.Object {
        return .forDevice(.command_buffer, try buffer.rawHandle(), buffer._device_handle);
    }
};

pub const RenderingScope = struct {
    _owner: core.Owner,
    buffer: *Buffer,
    active: bool = true,

    pub fn end(scope: *RenderingScope) core.Error!void {
        if (!(try scope._owner.release(scope))) return;
        if (!scope.active) return;
        try scope.buffer.endRendering();
        scope.active = false;
    }

    pub fn deinit(scope: *RenderingScope) void {
        scope.end() catch {};
    }
};

pub const RenderPassScope = struct {
    _owner: core.Owner,
    buffer: *Buffer,
    active: bool = true,

    pub fn next(scope: *RenderPassScope, contents: render_passes.Contents) core.Error!void {
        try scope._owner.validate(scope);
        if (!scope.active) return error.InvalidOptions;
        try scope.buffer.nextSubpass(contents);
    }

    pub fn end(scope: *RenderPassScope) core.Error!void {
        if (!(try scope._owner.release(scope))) return;
        if (!scope.active) return;
        try scope.buffer.endRenderPass();
        scope.active = false;
    }

    pub fn deinit(scope: *RenderPassScope) void {
        scope.end() catch {};
    }
};

pub const LabelScope = struct {
    _owner: core.Owner,
    command_buffer: CommandBufferHandle,
    end_label: CommandFunction(raw.PFN_vkCmdEndDebugUtilsLabelEXT),
    active: bool = true,

    pub fn end(scope: *LabelScope) void {
        if (!(scope._owner.release(scope) catch return)) return;
        if (!scope.active) return;
        scope.end_label(scope.command_buffer);
        scope.active = false;
    }

    pub fn deinit(scope: *LabelScope) void {
        scope.end();
    }
};

pub const ConditionalRenderingScope = struct {
    _owner: core.Owner,
    buffer: *Buffer,
    active: bool = true,

    pub fn end(scope: *ConditionalRenderingScope) core.Error!void {
        if (!(try scope._owner.release(scope))) return;
        if (!scope.active) return;
        try scope.buffer.endConditionalRendering();
        scope.active = false;
    }

    pub fn deinit(scope: *ConditionalRenderingScope) void {
        scope.end() catch {};
    }
};

pub const TransformFeedbackScope = struct {
    _owner: core.Owner,
    buffer: *Buffer,
    first_counter_buffer: u32,
    counter_count: usize,
    handles: [transform_feedback_counter_max]raw.VkBuffer = undefined,
    offsets: [transform_feedback_counter_max]raw.VkDeviceSize = undefined,
    active: bool = true,

    pub fn end(scope: *TransformFeedbackScope) core.Error!void {
        if (!(try scope._owner.release(scope))) return;
        if (!scope.active) return;
        try scope.buffer.endTransformFeedback(scope);
        scope.active = false;
    }

    pub fn deinit(scope: *TransformFeedbackScope) void {
        scope.end() catch {};
    }
};

pub const VideoCodingScope = struct {
    _owner: core.Owner,
    buffer: *Buffer,
    active: bool = true,

    pub fn end(scope: *VideoCodingScope) core.Error!void {
        if (!(try scope._owner.release(scope))) return;
        if (!scope.active) return;
        try scope.buffer.endVideoCoding();
        scope.active = false;
    }

    pub fn deinit(scope: *VideoCodingScope) void {
        scope.end() catch {};
    }
};

pub const Pool = struct {
    _handle: ?CommandPoolHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    _device_group_size: u32 = 1,
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
    cmd_set_event: CommandFunction(raw.PFN_vkCmdSetEvent),
    cmd_reset_event: CommandFunction(raw.PFN_vkCmdResetEvent),
    cmd_wait_events: CommandFunction(raw.PFN_vkCmdWaitEvents),
    cmd_set_event2: ?CommandFunction(raw.PFN_vkCmdSetEvent2),
    cmd_reset_event2: ?CommandFunction(raw.PFN_vkCmdResetEvent2),
    cmd_wait_events2: ?CommandFunction(raw.PFN_vkCmdWaitEvents2),
    cmd_begin_rendering: ?CommandFunction(raw.PFN_vkCmdBeginRendering),
    cmd_end_rendering: ?CommandFunction(raw.PFN_vkCmdEndRendering),
    cmd_begin_render_pass: CommandFunction(raw.PFN_vkCmdBeginRenderPass),
    cmd_next_subpass: CommandFunction(raw.PFN_vkCmdNextSubpass),
    cmd_end_render_pass: CommandFunction(raw.PFN_vkCmdEndRenderPass),
    cmd_begin_render_pass2: ?CommandFunction(raw.PFN_vkCmdBeginRenderPass2),
    cmd_next_subpass2: ?CommandFunction(raw.PFN_vkCmdNextSubpass2),
    cmd_end_render_pass2: ?CommandFunction(raw.PFN_vkCmdEndRenderPass2),
    cmd_clear_color_image: CommandFunction(raw.PFN_vkCmdClearColorImage),
    cmd_clear_depth_stencil_image: CommandFunction(raw.PFN_vkCmdClearDepthStencilImage),
    cmd_fill_buffer: CommandFunction(raw.PFN_vkCmdFillBuffer),
    cmd_update_buffer: CommandFunction(raw.PFN_vkCmdUpdateBuffer),
    cmd_copy_buffer: CommandFunction(raw.PFN_vkCmdCopyBuffer),
    cmd_copy_buffer2: ?CommandFunction(raw.PFN_vkCmdCopyBuffer2),
    cmd_copy_buffer_to_image: CommandFunction(raw.PFN_vkCmdCopyBufferToImage),
    cmd_copy_buffer_to_image2: ?CommandFunction(raw.PFN_vkCmdCopyBufferToImage2),
    cmd_copy_image_to_buffer: CommandFunction(raw.PFN_vkCmdCopyImageToBuffer),
    cmd_copy_image_to_buffer2: ?CommandFunction(raw.PFN_vkCmdCopyImageToBuffer2),
    cmd_copy_image: CommandFunction(raw.PFN_vkCmdCopyImage),
    cmd_copy_image2: ?CommandFunction(raw.PFN_vkCmdCopyImage2),
    cmd_blit_image: CommandFunction(raw.PFN_vkCmdBlitImage),
    cmd_blit_image2: ?CommandFunction(raw.PFN_vkCmdBlitImage2),
    cmd_resolve_image: CommandFunction(raw.PFN_vkCmdResolveImage),
    cmd_resolve_image2: ?CommandFunction(raw.PFN_vkCmdResolveImage2),
    cmd_bind_pipeline: CommandFunction(raw.PFN_vkCmdBindPipeline),
    cmd_bind_descriptor_sets: CommandFunction(raw.PFN_vkCmdBindDescriptorSets),
    cmd_push_descriptor_set: ?CommandFunction(raw.PFN_vkCmdPushDescriptorSet),
    cmd_bind_vertex_buffers: CommandFunction(raw.PFN_vkCmdBindVertexBuffers),
    cmd_bind_index_buffer: CommandFunction(raw.PFN_vkCmdBindIndexBuffer),
    cmd_set_viewport: CommandFunction(raw.PFN_vkCmdSetViewport),
    cmd_set_scissor: CommandFunction(raw.PFN_vkCmdSetScissor),
    cmd_set_line_width: CommandFunction(raw.PFN_vkCmdSetLineWidth),
    cmd_set_depth_bias: CommandFunction(raw.PFN_vkCmdSetDepthBias),
    cmd_set_blend_constants: CommandFunction(raw.PFN_vkCmdSetBlendConstants),
    cmd_set_depth_bounds: CommandFunction(raw.PFN_vkCmdSetDepthBounds),
    cmd_set_stencil_compare_mask: CommandFunction(raw.PFN_vkCmdSetStencilCompareMask),
    cmd_set_stencil_write_mask: CommandFunction(raw.PFN_vkCmdSetStencilWriteMask),
    cmd_set_stencil_reference: CommandFunction(raw.PFN_vkCmdSetStencilReference),
    cmd_push_constants: CommandFunction(raw.PFN_vkCmdPushConstants),
    cmd_draw: CommandFunction(raw.PFN_vkCmdDraw),
    cmd_draw_indexed: CommandFunction(raw.PFN_vkCmdDrawIndexed),
    cmd_draw_indirect: CommandFunction(raw.PFN_vkCmdDrawIndirect),
    cmd_draw_indexed_indirect: CommandFunction(raw.PFN_vkCmdDrawIndexedIndirect),
    cmd_draw_indirect_count: ?CommandFunction(raw.PFN_vkCmdDrawIndirectCount),
    cmd_draw_indexed_indirect_count: ?CommandFunction(raw.PFN_vkCmdDrawIndexedIndirectCount),
    cmd_draw_multi: ?CommandFunction(raw.PFN_vkCmdDrawMultiEXT),
    cmd_draw_multi_indexed: ?CommandFunction(raw.PFN_vkCmdDrawMultiIndexedEXT),
    cmd_dispatch: CommandFunction(raw.PFN_vkCmdDispatch),
    cmd_dispatch_indirect: CommandFunction(raw.PFN_vkCmdDispatchIndirect),
    cmd_dispatch_base: ?CommandFunction(raw.PFN_vkCmdDispatchBase),
    cmd_execute_commands: CommandFunction(raw.PFN_vkCmdExecuteCommands),
    cmd_begin_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdBeginDebugUtilsLabelEXT),
    cmd_end_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdEndDebugUtilsLabelEXT),
    cmd_insert_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdInsertDebugUtilsLabelEXT),
    cmd_begin_conditional_rendering_ext: ?CommandFunction(raw.PFN_vkCmdBeginConditionalRenderingEXT),
    cmd_end_conditional_rendering_ext: ?CommandFunction(raw.PFN_vkCmdEndConditionalRenderingEXT),
    cmd_begin_transform_feedback_ext: ?CommandFunction(raw.PFN_vkCmdBeginTransformFeedbackEXT),
    cmd_end_transform_feedback_ext: ?CommandFunction(raw.PFN_vkCmdEndTransformFeedbackEXT),
    cmd_begin_video_coding_khr: ?CommandFunction(raw.PFN_vkCmdBeginVideoCodingKHR),
    cmd_end_video_coding_khr: ?CommandFunction(raw.PFN_vkCmdEndVideoCodingKHR),
    cmd_control_video_coding_khr: ?CommandFunction(raw.PFN_vkCmdControlVideoCodingKHR),
    cmd_decode_video_khr: ?CommandFunction(raw.PFN_vkCmdDecodeVideoKHR),
    cmd_encode_video_khr: ?CommandFunction(raw.PFN_vkCmdEncodeVideoKHR),
    cmd_set_device_mask: ?CommandFunction(raw.PFN_vkCmdSetDeviceMask),

    pub fn deinit(pool: *Pool) void {
        if (!(pool._owner.release(pool) catch return)) return;
        const handle = pool._handle orelse return;
        pool.destroy_command_pool(pool._device_handle, handle, pool.allocation_callbacks);
        pool._handle = null;
        pool.generation +%= 1;
    }

    pub fn allocateCommandBuffer(pool: *Pool, options: Options) core.Error!Buffer {
        const pool_handle = (try pool.rawHandle()) orelse return error.InactiveObject;
        const allocate_info: raw.VkCommandBufferAllocateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = pool_handle,
            .level = options.level.toRaw(),
            .commandBufferCount = 1,
        };
        var handle: raw.VkCommandBuffer = null;
        try core.checkSuccessOptional(if (pool._device_state) |*state| state else null, pool.allocate_command_buffers(
            pool._device_handle,
            &allocate_info,
            &handle,
        ));
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._device_handle = pool._device_handle,
            ._pool = pool,
            ._pool_owner = pool._owner.borrow(),
            ._pool_generation = pool.generation,
            .level = options.level,
            .can_reset = pool.buffers_can_reset,
            .begin_command_buffer = pool.begin_command_buffer,
            .end_command_buffer = pool.end_command_buffer,
            .reset_command_buffer = pool.reset_command_buffer,
            .cmd_pipeline_barrier = pool.cmd_pipeline_barrier,
            .cmd_pipeline_barrier2 = pool.cmd_pipeline_barrier2,
            .cmd_set_event = pool.cmd_set_event,
            .cmd_reset_event = pool.cmd_reset_event,
            .cmd_wait_events = pool.cmd_wait_events,
            .cmd_set_event2 = pool.cmd_set_event2,
            .cmd_reset_event2 = pool.cmd_reset_event2,
            .cmd_wait_events2 = pool.cmd_wait_events2,
            .cmd_begin_rendering = pool.cmd_begin_rendering,
            .cmd_end_rendering = pool.cmd_end_rendering,
            .cmd_begin_render_pass = pool.cmd_begin_render_pass,
            .cmd_next_subpass = pool.cmd_next_subpass,
            .cmd_end_render_pass = pool.cmd_end_render_pass,
            .cmd_begin_render_pass2 = pool.cmd_begin_render_pass2,
            .cmd_next_subpass2 = pool.cmd_next_subpass2,
            .cmd_end_render_pass2 = pool.cmd_end_render_pass2,
            .cmd_clear_color_image = pool.cmd_clear_color_image,
            .cmd_clear_depth_stencil_image = pool.cmd_clear_depth_stencil_image,
            .cmd_fill_buffer = pool.cmd_fill_buffer,
            .cmd_update_buffer = pool.cmd_update_buffer,
            .cmd_copy_buffer = pool.cmd_copy_buffer,
            .cmd_copy_buffer2 = pool.cmd_copy_buffer2,
            .cmd_copy_buffer_to_image = pool.cmd_copy_buffer_to_image,
            .cmd_copy_buffer_to_image2 = pool.cmd_copy_buffer_to_image2,
            .cmd_copy_image_to_buffer = pool.cmd_copy_image_to_buffer,
            .cmd_copy_image_to_buffer2 = pool.cmd_copy_image_to_buffer2,
            .cmd_copy_image = pool.cmd_copy_image,
            .cmd_copy_image2 = pool.cmd_copy_image2,
            .cmd_blit_image = pool.cmd_blit_image,
            .cmd_blit_image2 = pool.cmd_blit_image2,
            .cmd_resolve_image = pool.cmd_resolve_image,
            .cmd_resolve_image2 = pool.cmd_resolve_image2,
            .cmd_bind_pipeline = pool.cmd_bind_pipeline,
            .cmd_bind_descriptor_sets = pool.cmd_bind_descriptor_sets,
            .cmd_push_descriptor_set = pool.cmd_push_descriptor_set,
            .cmd_bind_vertex_buffers = pool.cmd_bind_vertex_buffers,
            .cmd_bind_index_buffer = pool.cmd_bind_index_buffer,
            .cmd_set_viewport = pool.cmd_set_viewport,
            .cmd_set_scissor = pool.cmd_set_scissor,
            .cmd_set_line_width = pool.cmd_set_line_width,
            .cmd_set_depth_bias = pool.cmd_set_depth_bias,
            .cmd_set_blend_constants = pool.cmd_set_blend_constants,
            .cmd_set_depth_bounds = pool.cmd_set_depth_bounds,
            .cmd_set_stencil_compare_mask = pool.cmd_set_stencil_compare_mask,
            .cmd_set_stencil_write_mask = pool.cmd_set_stencil_write_mask,
            .cmd_set_stencil_reference = pool.cmd_set_stencil_reference,
            .cmd_push_constants = pool.cmd_push_constants,
            .cmd_draw = pool.cmd_draw,
            .cmd_draw_indexed = pool.cmd_draw_indexed,
            .cmd_draw_indirect = pool.cmd_draw_indirect,
            .cmd_draw_indexed_indirect = pool.cmd_draw_indexed_indirect,
            .cmd_draw_indirect_count = pool.cmd_draw_indirect_count,
            .cmd_draw_indexed_indirect_count = pool.cmd_draw_indexed_indirect_count,
            .cmd_draw_multi = pool.cmd_draw_multi,
            .cmd_draw_multi_indexed = pool.cmd_draw_multi_indexed,
            .cmd_dispatch = pool.cmd_dispatch,
            .cmd_dispatch_indirect = pool.cmd_dispatch_indirect,
            .cmd_dispatch_base = pool.cmd_dispatch_base,
            .cmd_execute_commands = pool.cmd_execute_commands,
            .cmd_begin_debug_utils_label_ext = pool.cmd_begin_debug_utils_label_ext,
            .cmd_end_debug_utils_label_ext = pool.cmd_end_debug_utils_label_ext,
            .cmd_insert_debug_utils_label_ext = pool.cmd_insert_debug_utils_label_ext,
            .cmd_begin_conditional_rendering_ext = pool.cmd_begin_conditional_rendering_ext,
            .cmd_end_conditional_rendering_ext = pool.cmd_end_conditional_rendering_ext,
            .cmd_begin_transform_feedback_ext = pool.cmd_begin_transform_feedback_ext,
            .cmd_end_transform_feedback_ext = pool.cmd_end_transform_feedback_ext,
            .cmd_begin_video_coding_khr = pool.cmd_begin_video_coding_khr,
            .cmd_end_video_coding_khr = pool.cmd_end_video_coding_khr,
            .cmd_control_video_coding_khr = pool.cmd_control_video_coding_khr,
            .cmd_decode_video_khr = pool.cmd_decode_video_khr,
            .cmd_encode_video_khr = pool.cmd_encode_video_khr,
            .cmd_set_device_mask = pool.cmd_set_device_mask,
            ._device_group_size = pool._device_group_size,
        };
    }

    pub fn freeCommandBuffer(pool: *Pool, buffer: *Buffer) core.Error!void {
        const pool_handle = (try pool.rawHandle()) orelse return error.InactiveObject;
        try buffer._pool_owner.validate();
        if (buffer._pool != pool or buffer._device_handle != pool._device_handle) {
            return error.InvalidHandle;
        }
        const handle = buffer._handle orelse return;
        if (buffer.state == .pending) return error.InvalidOptions;
        pool.free_command_buffers(pool._device_handle, pool_handle, 1, @ptrCast(&handle));
        buffer._handle = null;
    }

    pub fn reset(pool: *Pool, release_resources: bool) core.Error!void {
        const handle = (try pool.rawHandle()) orelse return error.InactiveObject;
        const flags: raw.VkCommandPoolResetFlags = if (release_resources)
            @intCast(raw.VK_COMMAND_POOL_RESET_RELEASE_RESOURCES_BIT)
        else
            0;
        try core.checkSuccessOptional(if (pool._device_state) |*state| state else null, pool.reset_command_pool(pool._device_handle, handle, flags));
        pool.generation +%= 1;
    }

    pub fn rawHandle(pool: *const Pool) core.Error!raw.VkCommandPool {
        try pool._owner.validate(pool);
        if (pool._device_state) |*state| try state.ensureDispatchAllowed();
        return pool._handle orelse error.InactiveObject;
    }

    pub fn debugObject(pool: *const Pool) core.Error!debug_utils.Object {
        return .forDevice(.command_pool, try pool.rawHandle(), pool._device_handle);
    }
};

test "all command-buffer declarations compile" {
    std.testing.refAllDecls(@This());
}

fn validateSameBufferCopyRegions(regions: []const transfer.BufferCopy) core.Error!void {
    for (regions, 0..) |region, index| {
        const size = region.size.bytes();
        if (size == 0) return error.InvalidOptions;
        const source_end = std.math.add(u64, region.source_offset.bytes(), size) catch return error.SizeOverflow;
        const destination_end = std.math.add(u64, region.destination_offset.bytes(), size) catch return error.SizeOverflow;
        if (region.source_offset.bytes() < destination_end and region.destination_offset.bytes() < source_end) return error.InvalidOptions;
        for (regions[0..index]) |previous| {
            const previous_size = previous.size.bytes();
            const previous_source_end = std.math.add(u64, previous.source_offset.bytes(), previous_size) catch return error.SizeOverflow;
            const previous_destination_end = std.math.add(u64, previous.destination_offset.bytes(), previous_size) catch return error.SizeOverflow;
            if ((region.source_offset.bytes() < previous_destination_end and previous.destination_offset.bytes() < source_end) or
                (region.destination_offset.bytes() < previous_source_end and previous.source_offset.bytes() < destination_end)) return error.InvalidOptions;
        }
    }
}

test "known image bounds validate compressed transfer regions" {
    const owned: image.Image = .{
        ._handle = @ptrFromInt(0x1000),
        ._owner = core.Owner.init({}) catch unreachable,
        ._device_handle = @ptrFromInt(0x2000),
        .format = .bc1_rgba_unorm_block,
        .extent = .{ .width = 64, .height = 64, .depth = 1 },
        .samples = ._1,
        .mip_levels = 4,
        .array_layers = 2,
        .allocation_callbacks = null,
        .dispatch = undefined,
    };
    const layers: transfer.SubresourceLayers = .{ .aspects = .init(&.{.color}), .mip_level = 1, .layer_count = 2 };
    try validateImageRegion(.{ .owned = &owned }, layers, .{ .x = 0, .y = 0, .z = 0 }, .{ .width = 32, .height = 32, .depth = 1 });
    try std.testing.expectError(error.InvalidOptions, validateImageRegion(.{ .owned = &owned }, layers, .{ .x = 16, .y = 0, .z = 0 }, .{ .width = 32, .height = 32, .depth = 1 }));
}

test "same-buffer copy regions reject direct and cross-region overlap" {
    try validateSameBufferCopyRegions(&.{.{
        .source_offset = .fromBytes(0),
        .destination_offset = .fromBytes(64),
        .size = .fromBytes(32),
    }});
    try std.testing.expectError(error.InvalidOptions, validateSameBufferCopyRegions(&.{.{
        .source_offset = .fromBytes(0),
        .destination_offset = .fromBytes(16),
        .size = .fromBytes(32),
    }}));
    try std.testing.expectError(error.InvalidOptions, validateSameBufferCopyRegions(&.{
        .{ .source_offset = .fromBytes(0), .destination_offset = .fromBytes(128), .size = .fromBytes(32) },
        .{ .source_offset = .fromBytes(112), .destination_offset = .fromBytes(256), .size = .fromBytes(32) },
    }));
}
