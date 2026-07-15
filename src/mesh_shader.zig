const std = @import("std");
const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const buffers = @import("buffer.zig");
const command_buffers = @import("command_buffer.zig");

const CommandFunction = command.FunctionType;

pub const FeaturesExt = types.extension_features.MeshShaderFeaturesEXT;
pub const FeaturesNv = types.extension_features.MeshShaderFeaturesNV;

pub const Variant = enum { ext, nv };

pub const ExtProperties = struct {
    max_task_work_group_total_count: u32,
    max_task_work_group_count: [3]u32,
    max_task_work_group_invocations: u32,
    max_task_work_group_size: [3]u32,
    max_task_payload_size: u32,
    max_task_shared_memory_size: u32,
    max_task_payload_and_shared_memory_size: u32,
    max_mesh_work_group_total_count: u32,
    max_mesh_work_group_count: [3]u32,
    max_mesh_work_group_invocations: u32,
    max_mesh_work_group_size: [3]u32,
    max_mesh_shared_memory_size: u32,
    max_mesh_payload_and_shared_memory_size: u32,
    max_mesh_output_memory_size: u32,
    max_mesh_payload_and_output_memory_size: u32,
    max_mesh_output_components: u32,
    max_mesh_output_vertices: u32,
    max_mesh_output_primitives: u32,
    max_mesh_output_layers: u32,
    max_mesh_multiview_view_count: u32,
    mesh_output_per_vertex_granularity: u32,
    mesh_output_per_primitive_granularity: u32,
    max_preferred_task_work_group_invocations: u32,
    max_preferred_mesh_work_group_invocations: u32,
    prefers_local_invocation_vertex_output: bool,
    prefers_local_invocation_primitive_output: bool,
    prefers_compact_vertex_output: bool,
    prefers_compact_primitive_output: bool,

    pub fn fromRaw(value: raw.VkPhysicalDeviceMeshShaderPropertiesEXT) ExtProperties {
        return .{
            .max_task_work_group_total_count = value.maxTaskWorkGroupTotalCount,
            .max_task_work_group_count = value.maxTaskWorkGroupCount,
            .max_task_work_group_invocations = value.maxTaskWorkGroupInvocations,
            .max_task_work_group_size = value.maxTaskWorkGroupSize,
            .max_task_payload_size = value.maxTaskPayloadSize,
            .max_task_shared_memory_size = value.maxTaskSharedMemorySize,
            .max_task_payload_and_shared_memory_size = value.maxTaskPayloadAndSharedMemorySize,
            .max_mesh_work_group_total_count = value.maxMeshWorkGroupTotalCount,
            .max_mesh_work_group_count = value.maxMeshWorkGroupCount,
            .max_mesh_work_group_invocations = value.maxMeshWorkGroupInvocations,
            .max_mesh_work_group_size = value.maxMeshWorkGroupSize,
            .max_mesh_shared_memory_size = value.maxMeshSharedMemorySize,
            .max_mesh_payload_and_shared_memory_size = value.maxMeshPayloadAndSharedMemorySize,
            .max_mesh_output_memory_size = value.maxMeshOutputMemorySize,
            .max_mesh_payload_and_output_memory_size = value.maxMeshPayloadAndOutputMemorySize,
            .max_mesh_output_components = value.maxMeshOutputComponents,
            .max_mesh_output_vertices = value.maxMeshOutputVertices,
            .max_mesh_output_primitives = value.maxMeshOutputPrimitives,
            .max_mesh_output_layers = value.maxMeshOutputLayers,
            .max_mesh_multiview_view_count = value.maxMeshMultiviewViewCount,
            .mesh_output_per_vertex_granularity = value.meshOutputPerVertexGranularity,
            .mesh_output_per_primitive_granularity = value.meshOutputPerPrimitiveGranularity,
            .max_preferred_task_work_group_invocations = value.maxPreferredTaskWorkGroupInvocations,
            .max_preferred_mesh_work_group_invocations = value.maxPreferredMeshWorkGroupInvocations,
            .prefers_local_invocation_vertex_output = value.prefersLocalInvocationVertexOutput != raw.VK_FALSE,
            .prefers_local_invocation_primitive_output = value.prefersLocalInvocationPrimitiveOutput != raw.VK_FALSE,
            .prefers_compact_vertex_output = value.prefersCompactVertexOutput != raw.VK_FALSE,
            .prefers_compact_primitive_output = value.prefersCompactPrimitiveOutput != raw.VK_FALSE,
        };
    }
};

pub const NvProperties = struct {
    max_draw_mesh_tasks_count: u32,
    max_task_work_group_invocations: u32,
    max_task_work_group_size: [3]u32,
    max_task_total_memory_size: u32,
    max_task_output_count: u32,
    max_mesh_work_group_invocations: u32,
    max_mesh_work_group_size: [3]u32,
    max_mesh_total_memory_size: u32,
    max_mesh_output_vertices: u32,
    max_mesh_output_primitives: u32,
    max_mesh_multiview_view_count: u32,
    mesh_output_per_vertex_granularity: u32,
    mesh_output_per_primitive_granularity: u32,

    pub fn fromRaw(value: raw.VkPhysicalDeviceMeshShaderPropertiesNV) NvProperties {
        return .{
            .max_draw_mesh_tasks_count = value.maxDrawMeshTasksCount,
            .max_task_work_group_invocations = value.maxTaskWorkGroupInvocations,
            .max_task_work_group_size = value.maxTaskWorkGroupSize,
            .max_task_total_memory_size = value.maxTaskTotalMemorySize,
            .max_task_output_count = value.maxTaskOutputCount,
            .max_mesh_work_group_invocations = value.maxMeshWorkGroupInvocations,
            .max_mesh_work_group_size = value.maxMeshWorkGroupSize,
            .max_mesh_total_memory_size = value.maxMeshTotalMemorySize,
            .max_mesh_output_vertices = value.maxMeshOutputVertices,
            .max_mesh_output_primitives = value.maxMeshOutputPrimitives,
            .max_mesh_multiview_view_count = value.maxMeshMultiviewViewCount,
            .mesh_output_per_vertex_granularity = value.meshOutputPerVertexGranularity,
            .mesh_output_per_primitive_granularity = value.meshOutputPerPrimitiveGranularity,
        };
    }
};

pub const ExtGroups = struct { x: u32, y: u32 = 1, z: u32 = 1 };
pub const NvTasks = struct { count: u32, first: u32 = 0 };

pub const Recorder = struct {
    _draw_ext: ?CommandFunction(raw.PFN_vkCmdDrawMeshTasksEXT),
    _draw_indirect_ext: ?CommandFunction(raw.PFN_vkCmdDrawMeshTasksIndirectEXT),
    _draw_indirect_count_ext: ?CommandFunction(raw.PFN_vkCmdDrawMeshTasksIndirectCountEXT),
    _draw_nv: ?CommandFunction(raw.PFN_vkCmdDrawMeshTasksNV),
    _draw_indirect_nv: ?CommandFunction(raw.PFN_vkCmdDrawMeshTasksIndirectNV),
    _draw_indirect_count_nv: ?CommandFunction(raw.PFN_vkCmdDrawMeshTasksIndirectCountNV),

    pub fn drawExt(recorder: Recorder, buffer: *command_buffers.Buffer, groups: ExtGroups) core.Error!void {
        const draw = recorder._draw_ext orelse return error.MissingCommand;
        try validateRecording(buffer);
        if (groups.x == 0 or groups.y == 0 or groups.z == 0) return error.InvalidOptions;
        draw(try buffer.rawHandle(), groups.x, groups.y, groups.z);
    }

    pub fn drawNv(recorder: Recorder, buffer: *command_buffers.Buffer, tasks: NvTasks) core.Error!void {
        const draw = recorder._draw_nv orelse return error.MissingCommand;
        try validateRecording(buffer);
        if (tasks.count == 0) return error.InvalidOptions;
        draw(try buffer.rawHandle(), tasks.count, tasks.first);
    }

    pub fn drawIndirect(
        recorder: Recorder,
        variant: Variant,
        buffer: *command_buffers.Buffer,
        indirect: *const buffers.Buffer,
        offset: core.DeviceOffset,
        draw_count: u32,
        stride: u32,
    ) core.Error!void {
        try validateRecording(buffer);
        const command_size: u64 = switch (variant) {
            .ext => @sizeOf(raw.VkDrawMeshTasksIndirectCommandEXT),
            .nv => @sizeOf(raw.VkDrawMeshTasksIndirectCommandNV),
        };
        try validateIndirect(buffer, indirect, offset, draw_count, stride, command_size);
        const handle = try buffer.rawHandle();
        switch (variant) {
            .ext => (recorder._draw_indirect_ext orelse return error.MissingCommand)(handle, try indirect.rawHandle(), offset.bytes(), draw_count, stride),
            .nv => (recorder._draw_indirect_nv orelse return error.MissingCommand)(handle, try indirect.rawHandle(), offset.bytes(), draw_count, stride),
        }
    }

    pub fn drawIndirectCount(
        recorder: Recorder,
        variant: Variant,
        buffer: *command_buffers.Buffer,
        indirect: *const buffers.Buffer,
        offset: core.DeviceOffset,
        count_buffer: *const buffers.Buffer,
        count_offset: core.DeviceOffset,
        max_draw_count: u32,
        stride: u32,
    ) core.Error!void {
        try validateRecording(buffer);
        if (count_buffer._device_handle != buffer._device_handle or count_offset.bytes() % 4 != 0 or
            count_offset.bytes() > count_buffer.size.bytes() or @sizeOf(u32) > count_buffer.size.bytes() - count_offset.bytes())
        {
            return error.InvalidOptions;
        }
        const command_size: u64 = switch (variant) {
            .ext => @sizeOf(raw.VkDrawMeshTasksIndirectCommandEXT),
            .nv => @sizeOf(raw.VkDrawMeshTasksIndirectCommandNV),
        };
        try validateIndirect(buffer, indirect, offset, max_draw_count, stride, command_size);
        const handle = try buffer.rawHandle();
        switch (variant) {
            .ext => (recorder._draw_indirect_count_ext orelse return error.MissingCommand)(handle, try indirect.rawHandle(), offset.bytes(), try count_buffer.rawHandle(), count_offset.bytes(), max_draw_count, stride),
            .nv => (recorder._draw_indirect_count_nv orelse return error.MissingCommand)(handle, try indirect.rawHandle(), offset.bytes(), try count_buffer.rawHandle(), count_offset.bytes(), max_draw_count, stride),
        }
    }
};

fn validateRecording(buffer: *const command_buffers.Buffer) core.Error!void {
    if (buffer.state != .recording or !(buffer.rendering_active or buffer.render_pass_active) or
        !buffer.graphics_pipeline_bound) return error.InvalidOptions;
}

fn validateIndirect(
    command_buffer: *const command_buffers.Buffer,
    indirect: *const buffers.Buffer,
    offset: core.DeviceOffset,
    count: u32,
    stride: u32,
    command_size: u64,
) core.Error!void {
    if (indirect._device_handle != command_buffer._device_handle or count == 0 or
        stride < command_size or stride % 4 != 0 or offset.bytes() % 4 != 0) return error.InvalidOptions;
    const prefix = std.math.mul(u64, count - 1, stride) catch return error.SizeOverflow;
    const bytes = std.math.add(u64, prefix, command_size) catch return error.SizeOverflow;
    if (offset.bytes() > indirect.size.bytes() or bytes > indirect.size.bytes() - offset.bytes()) {
        return error.InvalidOptions;
    }
}

test "mesh shader feature aliases and variants remain explicit" {
    const features = FeaturesExt{ .mesh_shader = true, .task_shader = true };
    try std.testing.expect(features.mesh_shader);
    try std.testing.expectEqual(@as(u64, 12), @sizeOf(raw.VkDrawMeshTasksIndirectCommandEXT));
    try std.testing.expectEqual(@as(u64, 8), @sizeOf(raw.VkDrawMeshTasksIndirectCommandNV));
}
