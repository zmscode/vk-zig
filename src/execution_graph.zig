//! Typed provisional `VK_AMDX_shader_enqueue` execution-graph support.

const std = @import("std");
const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const buffers = @import("buffer.zig");
const commands = @import("command_buffer.zig");
const pipelines = @import("pipeline.zig");
const pipeline_tools = @import("pipeline_tools.zig");
const shaders = @import("shader.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const stage_count_max = 32;
const specialization_count_max = 256;
const dispatch_count_max = 64;

pub const extension = command.DeviceExtension.amdx_shader_enqueue;
pub const Features = types.extension_features.ShaderEnqueueFeaturesAMDX;

pub const Properties = struct {
    max_depth: u32,
    max_output_nodes: u32,
    max_payload_size: u32,
    max_payload_count: u32,
    dispatch_address_alignment: u32,
    max_workgroup_count: [3]u32,
    max_workgroups: u32,

    pub fn fromRaw(value: raw.VkPhysicalDeviceShaderEnqueuePropertiesAMDX) Properties {
        return .{ .max_depth = value.maxExecutionGraphDepth, .max_output_nodes = value.maxExecutionGraphShaderOutputNodes, .max_payload_size = value.maxExecutionGraphShaderPayloadSize, .max_payload_count = value.maxExecutionGraphShaderPayloadCount, .dispatch_address_alignment = value.executionGraphDispatchAddressAlignment, .max_workgroup_count = value.maxExecutionGraphWorkgroupCount, .max_workgroups = value.maxExecutionGraphWorkgroups };
    }
};

pub const Node = struct { name: ?[:0]const u8 = null, index: u32 = 0 };
pub const Stage = struct { shader: shaders.StageOptions, node: Node = .{} };
pub const Options = struct {
    stages: []const Stage,
    layout: *const pipelines.Layout,
    cache: ?*const pipeline_tools.Cache = null,
    fail_on_compile_required: bool = false,
};
pub const CreateResult = union(enum) { success: pipelines.Pipeline, compile_required };

pub const Scratch = struct {
    minimum: core.DeviceSize,
    maximum: core.DeviceSize,
    granularity: core.DeviceSize,

    pub fn supports(scratch: Scratch, size: core.DeviceSize) bool {
        const bytes = size.bytes();
        return bytes >= scratch.minimum.bytes() and bytes <= scratch.maximum.bytes() and
            scratch.granularity.bytes() != 0 and bytes % scratch.granularity.bytes() == 0;
    }
};

pub const NodeIndex = enum(u32) { _ };
pub const Address = union(enum) {
    device: buffers.DeviceAddress,
    host: *const anyopaque,
    fn toRaw(value: Address) raw.VkDeviceOrHostAddressConstAMDX {
        return switch (value) {
            .device => |address| .{ .deviceAddress = address.toRaw() },
            .host => |pointer| .{ .hostAddress = pointer },
        };
    }
};
pub const Dispatch = struct { node: NodeIndex, payload_count: u32, payloads: Address, payload_stride: u64 };

pub const Context = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    properties: Properties,
    _create: ?CommandFunction(raw.PFN_vkCreateExecutionGraphPipelinesAMDX),
    _destroy: CommandFunction(raw.PFN_vkDestroyPipeline),
    _scratch: ?CommandFunction(raw.PFN_vkGetExecutionGraphPipelineScratchSizeAMDX),
    _node: ?CommandFunction(raw.PFN_vkGetExecutionGraphPipelineNodeIndexAMDX),
    _initialize: ?CommandFunction(raw.PFN_vkCmdInitializeGraphScratchMemoryAMDX),
    _dispatch: ?CommandFunction(raw.PFN_vkCmdDispatchGraphAMDX),
    _dispatch_indirect: ?CommandFunction(raw.PFN_vkCmdDispatchGraphIndirectAMDX),
    _dispatch_indirect_count: ?CommandFunction(raw.PFN_vkCmdDispatchGraphIndirectCountAMDX),

    pub fn create(context: Context, options: Options) core.Error!CreateResult {
        const create_command = context._create orelse return error.MissingCommand;
        if (options.stages.len == 0 or options.stages.len > stage_count_max or options.layout._device_handle != context._device) return error.InvalidOptions;
        var raw_stages: [stage_count_max]raw.VkPipelineShaderStageCreateInfo = undefined;
        var nodes: [stage_count_max]raw.VkPipelineShaderStageNodeCreateInfoAMDX = undefined;
        var specializations: [stage_count_max]raw.VkSpecializationInfo = undefined;
        var entries: [specialization_count_max]raw.VkSpecializationMapEntry = undefined;
        var entry_count: usize = 0;
        for (options.stages, 0..) |stage, index| {
            if (stage.shader.module._device_handle != context._device) return error.InvalidOptions;
            nodes[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_NODE_CREATE_INFO_AMDX, .pName = if (stage.node.name) |name| name.ptr else null, .index = stage.node.index };
            var specialization_pointer: [*c]const raw.VkSpecializationInfo = null;
            if (stage.shader.specialization) |value| {
                try value.validate();
                if (entry_count + value.entries.len > entries.len) return error.InvalidOptions;
                const first = entry_count;
                for (value.entries) |entry| {
                    entries[entry_count] = .{ .constantID = entry.constant_id, .offset = @intCast(entry.offset), .size = entry.size };
                    entry_count += 1;
                }
                specializations[index] = .{ .mapEntryCount = @intCast(value.entries.len), .pMapEntries = entries[first..entry_count].ptr, .dataSize = value.data.len, .pData = value.data.ptr };
                specialization_pointer = &specializations[index];
            }
            raw_stages[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, .pNext = &nodes[index], .stage = stage.shader.stage.toRaw(), .module = try stage.shader.module.rawHandle(), .pName = stage.shader.entry_point.ptr, .pSpecializationInfo = specialization_pointer };
        }
        const info: raw.VkExecutionGraphPipelineCreateInfoAMDX = .{ .sType = raw.VK_STRUCTURE_TYPE_EXECUTION_GRAPH_PIPELINE_CREATE_INFO_AMDX, .flags = if (options.fail_on_compile_required) raw.VK_PIPELINE_CREATE_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT_EXT else 0, .stageCount = @intCast(options.stages.len), .pStages = raw_stages[0..options.stages.len].ptr, .layout = try options.layout.rawHandle() };
        var handle: raw.VkPipeline = null;
        const result = create_command(context._device, if (options.cache) |cache| blk: {
            if (cache._device_handle != context._device) return error.InvalidOptions;
            break :blk try cache.rawHandle();
        } else null, 1, &info, context._allocation_callbacks, &handle);
        if (result == raw.VK_PIPELINE_COMPILE_REQUIRED_EXT) {
            if (handle) |provisional| context._destroy(context._device, provisional, context._allocation_callbacks);
            return .compile_required;
        }
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional| context._destroy(context._device, provisional, context._allocation_callbacks);
            try core.checkSuccess(result);
        }
        return .{ .success = .{ ._handle = handle orelse return error.InvalidHandle, ._owner = try .init(&handle), ._device_handle = context._device, ._device_state = context._state.*, .bind_point = .execution_graph, .allocation_callbacks = context._allocation_callbacks, .destroy_pipeline = context._destroy } };
    }

    pub fn scratchRequirements(context: Context, pipeline: *const pipelines.Pipeline) core.Error!Scratch {
        const get = context._scratch orelse return error.MissingCommand;
        if (pipeline._device_handle != context._device or pipeline.bind_point != .execution_graph) return error.InvalidOptions;
        var output: raw.VkExecutionGraphPipelineScratchSizeAMDX = .{ .sType = raw.VK_STRUCTURE_TYPE_EXECUTION_GRAPH_PIPELINE_SCRATCH_SIZE_AMDX };
        try core.checkSuccess(get(context._device, try pipeline.rawHandle(), &output));
        if (output.sizeGranularity == 0 or output.minSize > output.maxSize) return error.InvalidProperties;
        return .{ .minimum = .fromBytes(output.minSize), .maximum = .fromBytes(output.maxSize), .granularity = .fromBytes(output.sizeGranularity) };
    }

    pub fn nodeIndex(context: Context, pipeline: *const pipelines.Pipeline, node: Node) core.Error!NodeIndex {
        const get = context._node orelse return error.MissingCommand;
        if (pipeline._device_handle != context._device or pipeline.bind_point != .execution_graph) return error.InvalidOptions;
        const info: raw.VkPipelineShaderStageNodeCreateInfoAMDX = .{ .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_NODE_CREATE_INFO_AMDX, .pName = if (node.name) |name| name.ptr else null, .index = node.index };
        var index: u32 = 0;
        try core.checkSuccess(get(context._device, try pipeline.rawHandle(), &info, &index));
        return @enumFromInt(index);
    }

    fn validateRecording(context: Context, command_buffer: *commands.Buffer, scratch: buffers.DeviceAddress, size: core.DeviceSize) core.Error!void {
        if (context.properties.dispatch_address_alignment == 0 or command_buffer._device_handle != context._device or command_buffer.state != .recording or command_buffer.rendering_active or command_buffer.render_pass_active or command_buffer.video_coding_active or size.bytes() == 0 or scratch.toRaw() % context.properties.dispatch_address_alignment != 0) return error.InvalidOptions;
    }

    pub fn initializeScratch(context: Context, command_buffer: *commands.Buffer, pipeline: *const pipelines.Pipeline, scratch: buffers.DeviceAddress, size: core.DeviceSize) core.Error!void {
        const initialize = context._initialize orelse return error.MissingCommand;
        try context.validateRecording(command_buffer, scratch, size);
        if (pipeline._device_handle != context._device or pipeline.bind_point != .execution_graph) return error.InvalidOptions;
        initialize(try command_buffer.rawHandle(), try pipeline.rawHandle(), scratch.toRaw(), size.bytes());
    }

    pub fn dispatch(context: Context, command_buffer: *commands.Buffer, scratch: buffers.DeviceAddress, size: core.DeviceSize, infos: []const Dispatch) core.Error!void {
        const dispatch_command = context._dispatch orelse return error.MissingCommand;
        try context.validateRecording(command_buffer, scratch, size);
        if (!command_buffer.execution_graph_pipeline_bound) return error.InvalidOptions;
        if (infos.len == 0 or infos.len > dispatch_count_max) return error.InvalidOptions;
        var raw_infos: [dispatch_count_max]raw.VkDispatchGraphInfoAMDX = undefined;
        for (infos, 0..) |info, index| {
            if (info.payload_count == 0 or info.payload_count > context.properties.max_payload_count or info.payload_stride == 0) return error.InvalidOptions;
            raw_infos[index] = .{ .nodeIndex = @intFromEnum(info.node), .payloadCount = info.payload_count, .payloads = info.payloads.toRaw(), .payloadStride = info.payload_stride };
        }
        const count: raw.VkDispatchGraphCountInfoAMDX = .{ .count = @intCast(infos.len), .infos = .{ .hostAddress = raw_infos[0..infos.len].ptr }, .stride = @sizeOf(raw.VkDispatchGraphInfoAMDX) };
        dispatch_command(try command_buffer.rawHandle(), scratch.toRaw(), size.bytes(), &count);
    }

    pub fn dispatchIndirect(context: Context, command_buffer: *commands.Buffer, scratch: buffers.DeviceAddress, size: core.DeviceSize, count: u32, infos: buffers.DeviceAddress, stride: u64) core.Error!void {
        const dispatch_command = context._dispatch_indirect orelse return error.MissingCommand;
        try context.validateRecording(command_buffer, scratch, size);
        if (!command_buffer.execution_graph_pipeline_bound) return error.InvalidOptions;
        if (count == 0 or stride < @sizeOf(raw.VkDispatchGraphInfoAMDX) or infos.toRaw() % context.properties.dispatch_address_alignment != 0) return error.InvalidOptions;
        const count_info: raw.VkDispatchGraphCountInfoAMDX = .{ .count = count, .infos = .{ .deviceAddress = infos.toRaw() }, .stride = stride };
        dispatch_command(try command_buffer.rawHandle(), scratch.toRaw(), size.bytes(), &count_info);
    }

    pub fn dispatchIndirectCount(context: Context, command_buffer: *commands.Buffer, scratch: buffers.DeviceAddress, size: core.DeviceSize, count_info: buffers.DeviceAddress) core.Error!void {
        const dispatch_command = context._dispatch_indirect_count orelse return error.MissingCommand;
        try context.validateRecording(command_buffer, scratch, size);
        if (!command_buffer.execution_graph_pipeline_bound) return error.InvalidOptions;
        if (count_info.toRaw() % context.properties.dispatch_address_alignment != 0) return error.InvalidOptions;
        dispatch_command(try command_buffer.rawHandle(), scratch.toRaw(), size.bytes(), count_info.toRaw());
    }
};

test "scratch range includes aligned endpoints" {
    const scratch: Scratch = .{ .minimum = .fromBytes(64), .maximum = .fromBytes(256), .granularity = .fromBytes(64) };
    try std.testing.expect(scratch.supports(.fromBytes(64)));
    try std.testing.expect(scratch.supports(.fromBytes(256)));
    try std.testing.expect(!scratch.supports(.fromBytes(96)));
    try std.testing.expect(extension == command.DeviceExtension.amdx_shader_enqueue);
}

test "unavailable execution graph command reports MissingCommand" {
    var context: Context = undefined;
    context._create = null;
    try std.testing.expectError(error.MissingCommand, context.create(undefined));
    context._scratch = null;
    try std.testing.expectError(error.MissingCommand, context.scratchRequirements(undefined));
    context._node = null;
    try std.testing.expectError(error.MissingCommand, context.nodeIndex(undefined, .{}));
    context._initialize = null;
    try std.testing.expectError(error.MissingCommand, context.initializeScratch(undefined, undefined, @enumFromInt(1), .fromBytes(1)));
    context._dispatch = null;
    try std.testing.expectError(error.MissingCommand, context.dispatch(undefined, @enumFromInt(1), .fromBytes(1), &.{}));
    context._dispatch_indirect = null;
    try std.testing.expectError(error.MissingCommand, context.dispatchIndirect(undefined, @enumFromInt(1), .fromBytes(1), 1, @enumFromInt(1), 1));
    context._dispatch_indirect_count = null;
    try std.testing.expectError(error.MissingCommand, context.dispatchIndirectCount(undefined, @enumFromInt(1), .fromBytes(1), @enumFromInt(1)));
}
