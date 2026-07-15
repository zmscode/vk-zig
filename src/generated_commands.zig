//! Typed `VK_EXT_device_generated_commands` layouts, execution sets, and recording.
//!
//! The older NV model remains discoverable as `nv.extension`; its handle and
//! token domains are intentionally not mixed with the EXT model below.

const std = @import("std");
const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const buffers = @import("buffer.zig");
const commands = @import("command_buffer.zig");
const debug_utils = @import("debug_utils.zig");
const descriptors = @import("descriptor.zig");
const memory = @import("memory.zig");
const pipelines = @import("pipeline.zig");
const shader_objects = @import("shader_object.zig");
const shaders = @import("shader.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const LayoutHandle = core.NonNullHandle(raw.VkIndirectCommandsLayoutEXT);
const ExecutionSetHandle = core.NonNullHandle(raw.VkIndirectExecutionSetEXT);
const token_count_max = 64;
const update_count_max = 64;
const shader_count_max = 32;
const set_layout_count_max = 256;
const push_constant_count_max = 32;

pub const extension = command.DeviceExtension.ext_device_generated_commands;
pub const Features = types.extension_features.DeviceGeneratedCommandsFeaturesEXT;
pub const nv = struct {
    pub const extension = command.DeviceExtension.nv_device_generated_commands;
};

pub const Properties = struct {
    max_pipeline_count: u32,
    max_shader_object_count: u32,
    max_sequence_count: u32,
    max_token_count: u32,
    max_token_offset: u32,
    max_stride: u32,
    supported_stages: shaders.StageSet,

    pub fn fromRaw(value: raw.VkPhysicalDeviceDeviceGeneratedCommandsPropertiesEXT) Properties {
        return .{ .max_pipeline_count = value.maxIndirectPipelineCount, .max_shader_object_count = value.maxIndirectShaderObjectCount, .max_sequence_count = value.maxIndirectSequenceCount, .max_token_count = value.maxIndirectCommandsTokenCount, .max_token_offset = value.maxIndirectCommandsTokenOffset, .max_stride = value.maxIndirectCommandsIndirectStride, .supported_stages = stageSetFromRaw(value.supportedIndirectCommandsShaderStages) };
    }
};

fn stageSetFromRaw(value: raw.VkShaderStageFlags) shaders.StageSet {
    var result: shaders.StageSet = .{};
    inline for (std.meta.tags(shaders.Stage)) |stage| if ((value & @as(raw.VkShaderStageFlags, @intCast(stage.toRaw()))) != 0) result.bits.insert(stage);
    return result;
}

fn containsStages(superset: shaders.StageSet, subset: shaders.StageSet) bool {
    inline for (std.meta.tags(shaders.Stage)) |stage| {
        if (subset.contains(stage) and !superset.contains(stage)) return false;
    }
    return true;
}

pub const ExecutionSetKind = enum { pipelines, shader_objects };
pub const InputMode = enum { vulkan, dxgi };

pub const TokenData = union(enum) {
    execution_set: struct { kind: ExecutionSetKind, stages: shaders.StageSet },
    push_constant: pipelines.PushConstantRange,
    sequence_index,
    index_buffer: InputMode,
    vertex_buffer: u32,
    draw_indexed,
    draw,
    draw_indexed_count,
    draw_count,
    dispatch,
    draw_mesh_tasks,
    draw_mesh_tasks_count,
    trace_rays,
};

pub const Token = struct { offset: u32, data: TokenData };
pub const LayoutFlags = struct { explicit_preprocess: bool = false, unordered_sequences: bool = false };

pub const LayoutOptions = struct {
    stages: shaders.StageSet,
    stride: u32,
    tokens: []const Token,
    pipeline_layout: ?*const pipelines.Layout = null,
    flags: LayoutFlags = .{},
};

pub const Layout = struct {
    _handle: ?LayoutHandle,
    _owner: core.Owner,
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    stages: shaders.StageSet,
    execution_set_kind: ?ExecutionSetKind,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _destroy: CommandFunction(raw.PFN_vkDestroyIndirectCommandsLayoutEXT),

    pub fn deinit(layout: *Layout) void {
        if (!(layout._owner.release(layout) catch return)) return;
        const handle = layout._handle orelse return;
        layout._destroy(layout._device, handle, layout.allocation_callbacks);
        layout._handle = null;
    }
    pub fn rawHandle(layout: *const Layout) core.Error!raw.VkIndirectCommandsLayoutEXT {
        try layout._owner.validate(layout);
        try layout._state.ensureDispatchAllowed();
        return layout._handle orelse error.InactiveObject;
    }
    pub fn debugObject(layout: *const Layout) core.Error!debug_utils.Object {
        return .forDevice(.indirect_commands_layout, try layout.rawHandle(), layout._device);
    }
};

pub const ExecutionSet = struct {
    _handle: ?ExecutionSetHandle,
    _owner: core.Owner,
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    kind: ExecutionSetKind,
    capacity: u32,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _destroy: CommandFunction(raw.PFN_vkDestroyIndirectExecutionSetEXT),

    pub fn deinit(set: *ExecutionSet) void {
        if (!(set._owner.release(set) catch return)) return;
        const handle = set._handle orelse return;
        set._destroy(set._device, handle, set.allocation_callbacks);
        set._handle = null;
    }
    pub fn rawHandle(set: *const ExecutionSet) core.Error!raw.VkIndirectExecutionSetEXT {
        try set._owner.validate(set);
        try set._state.ensureDispatchAllowed();
        return set._handle orelse error.InactiveObject;
    }
    pub fn debugObject(set: *const ExecutionSet) core.Error!debug_utils.Object {
        return .forDevice(.indirect_execution_set, try set.rawHandle(), set._device);
    }
};

pub const ShaderSlot = struct { shader: *const shader_objects.Shader, set_layouts: []const *const descriptors.SetLayout = &.{} };
pub const PipelineSetOptions = struct { initial: *const pipelines.Pipeline, capacity: u32 };
pub const ShaderSetOptions = struct { initial: []const ShaderSlot, capacity: u32, push_constants: []const pipelines.PushConstantRange = &.{} };
pub const PipelineUpdate = struct { index: u32, pipeline: *const pipelines.Pipeline };
pub const ShaderUpdate = struct { index: u32, shader: *const shader_objects.Shader };

pub const RequirementsOptions = struct { execution_set: ?*const ExecutionSet = null, layout: *const Layout, max_sequences: u32, max_draws: u32 = 1 };
pub const Info = struct {
    stages: shaders.StageSet,
    execution_set: ?*const ExecutionSet = null,
    layout: *const Layout,
    indirect_address: buffers.DeviceAddress,
    indirect_size: core.DeviceSize,
    preprocess_address: buffers.DeviceAddress,
    preprocess_size: core.DeviceSize,
    max_sequences: u32,
    sequence_count_address: ?buffers.DeviceAddress = null,
    max_draws: u32 = 1,
};

pub const Context = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    properties: Properties,
    _requirements: ?CommandFunction(raw.PFN_vkGetGeneratedCommandsMemoryRequirementsEXT),
    _preprocess: ?CommandFunction(raw.PFN_vkCmdPreprocessGeneratedCommandsEXT),
    _execute: ?CommandFunction(raw.PFN_vkCmdExecuteGeneratedCommandsEXT),
    _create_layout: ?CommandFunction(raw.PFN_vkCreateIndirectCommandsLayoutEXT),
    _destroy_layout: ?CommandFunction(raw.PFN_vkDestroyIndirectCommandsLayoutEXT),
    _create_set: ?CommandFunction(raw.PFN_vkCreateIndirectExecutionSetEXT),
    _destroy_set: ?CommandFunction(raw.PFN_vkDestroyIndirectExecutionSetEXT),
    _update_pipelines: ?CommandFunction(raw.PFN_vkUpdateIndirectExecutionSetPipelineEXT),
    _update_shaders: ?CommandFunction(raw.PFN_vkUpdateIndirectExecutionSetShaderEXT),

    pub fn createLayout(context: Context, options: LayoutOptions) core.Error!Layout {
        const create = context._create_layout orelse return error.MissingCommand;
        const destroy = context._destroy_layout orelse return error.MissingCommand;
        if (options.tokens.len == 0 or options.tokens.len > token_count_max or options.tokens.len > context.properties.max_token_count or options.stride == 0 or options.stride > context.properties.max_stride) return error.InvalidOptions;
        if (!containsStages(context.properties.supported_stages, options.stages)) return error.InvalidOptions;
        var push: [token_count_max]raw.VkIndirectCommandsPushConstantTokenEXT = undefined;
        var vertex: [token_count_max]raw.VkIndirectCommandsVertexBufferTokenEXT = undefined;
        var index_buffer: [token_count_max]raw.VkIndirectCommandsIndexBufferTokenEXT = undefined;
        var execution: [token_count_max]raw.VkIndirectCommandsExecutionSetTokenEXT = undefined;
        var tokens: [token_count_max]raw.VkIndirectCommandsLayoutTokenEXT = undefined;
        var execution_set_kind: ?ExecutionSetKind = null;
        for (options.tokens, 0..) |token, index| {
            if (token.offset > context.properties.max_token_offset or token.offset >= options.stride) return error.InvalidOptions;
            var type_: raw.VkIndirectCommandsTokenTypeEXT = undefined;
            var data: raw.VkIndirectCommandsTokenDataEXT = std.mem.zeroes(raw.VkIndirectCommandsTokenDataEXT);
            switch (token.data) {
                .execution_set => |value| {
                    if (execution_set_kind) |kind| {
                        if (kind != value.kind) return error.InvalidOptions;
                    } else {
                        execution_set_kind = value.kind;
                    }
                    execution[index] = .{ .type = switch (value.kind) {
                        .pipelines => raw.VK_INDIRECT_EXECUTION_SET_INFO_TYPE_PIPELINES_EXT,
                        .shader_objects => raw.VK_INDIRECT_EXECUTION_SET_INFO_TYPE_SHADER_OBJECTS_EXT,
                    }, .shaderStages = value.stages.toRaw() };
                    data = .{ .pExecutionSet = &execution[index] };
                    type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_EXECUTION_SET_EXT;
                },
                .push_constant => |value| {
                    push[index] = .{ .updateRange = .{ .stageFlags = value.stages.toRaw(), .offset = value.offset, .size = value.size } };
                    data = .{ .pPushConstant = &push[index] };
                    type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_PUSH_CONSTANT_EXT;
                },
                .sequence_index => type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_SEQUENCE_INDEX_EXT,
                .index_buffer => |value| {
                    index_buffer[index] = .{ .mode = switch (value) {
                        .vulkan => raw.VK_INDIRECT_COMMANDS_INPUT_MODE_VULKAN_INDEX_BUFFER_EXT,
                        .dxgi => raw.VK_INDIRECT_COMMANDS_INPUT_MODE_DXGI_INDEX_BUFFER_EXT,
                    } };
                    data = .{ .pIndexBuffer = &index_buffer[index] };
                    type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_INDEX_BUFFER_EXT;
                },
                .vertex_buffer => |binding| {
                    vertex[index] = .{ .vertexBindingUnit = binding };
                    data = .{ .pVertexBuffer = &vertex[index] };
                    type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_VERTEX_BUFFER_EXT;
                },
                .draw_indexed => type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_DRAW_INDEXED_EXT,
                .draw => type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_DRAW_EXT,
                .draw_indexed_count => type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_DRAW_INDEXED_COUNT_EXT,
                .draw_count => type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_DRAW_COUNT_EXT,
                .dispatch => type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_DISPATCH_EXT,
                .draw_mesh_tasks => type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_DRAW_MESH_TASKS_EXT,
                .draw_mesh_tasks_count => type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_DRAW_MESH_TASKS_COUNT_EXT,
                .trace_rays => type_ = raw.VK_INDIRECT_COMMANDS_TOKEN_TYPE_TRACE_RAYS2_EXT,
            }
            tokens[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_INDIRECT_COMMANDS_LAYOUT_TOKEN_EXT, .type = type_, .data = data, .offset = token.offset };
        }
        const info: raw.VkIndirectCommandsLayoutCreateInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_INDIRECT_COMMANDS_LAYOUT_CREATE_INFO_EXT, .flags = (if (options.flags.explicit_preprocess) raw.VK_INDIRECT_COMMANDS_LAYOUT_USAGE_EXPLICIT_PREPROCESS_BIT_EXT else 0) | (if (options.flags.unordered_sequences) raw.VK_INDIRECT_COMMANDS_LAYOUT_USAGE_UNORDERED_SEQUENCES_BIT_EXT else 0), .shaderStages = options.stages.toRaw(), .indirectStride = options.stride, .pipelineLayout = if (options.pipeline_layout) |layout| blk: {
            if (layout._device_handle != context._device) return error.InvalidOptions;
            break :blk try layout.rawHandle();
        } else null, .tokenCount = @intCast(options.tokens.len), .pTokens = tokens[0..options.tokens.len].ptr };
        var handle: raw.VkIndirectCommandsLayoutEXT = null;
        const result = create(context._device, &info, context._allocation_callbacks, &handle);
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional| destroy(context._device, provisional, context._allocation_callbacks);
            try core.checkSuccess(result);
        }
        return .{ ._handle = handle orelse return error.InvalidHandle, ._owner = try .init(&handle), ._device = context._device, ._state = context._state, .stages = options.stages, .execution_set_kind = execution_set_kind, .allocation_callbacks = context._allocation_callbacks, ._destroy = destroy };
    }

    pub fn createPipelineSet(context: Context, options: PipelineSetOptions) core.Error!ExecutionSet {
        const create = context._create_set orelse return error.MissingCommand;
        const destroy = context._destroy_set orelse return error.MissingCommand;
        if (options.initial._device_handle != context._device or options.capacity == 0 or options.capacity > context.properties.max_pipeline_count) return error.InvalidOptions;
        const pipeline_info: raw.VkIndirectExecutionSetPipelineInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_INDIRECT_EXECUTION_SET_PIPELINE_INFO_EXT, .initialPipeline = try options.initial.rawHandle(), .maxPipelineCount = options.capacity };
        const info: raw.VkIndirectExecutionSetCreateInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_INDIRECT_EXECUTION_SET_CREATE_INFO_EXT, .type = raw.VK_INDIRECT_EXECUTION_SET_INFO_TYPE_PIPELINES_EXT, .info = .{ .pPipelineInfo = &pipeline_info } };
        return context.finishCreateSet(create, destroy, info, .pipelines, options.capacity);
    }

    pub fn createShaderSet(context: Context, options: ShaderSetOptions) core.Error!ExecutionSet {
        const create = context._create_set orelse return error.MissingCommand;
        const destroy = context._destroy_set orelse return error.MissingCommand;
        if (options.initial.len == 0 or options.initial.len > shader_count_max or options.capacity < options.initial.len or options.capacity > context.properties.max_shader_object_count or options.push_constants.len > push_constant_count_max) return error.InvalidOptions;
        var handles: [shader_count_max]raw.VkShaderEXT = undefined;
        var layout_infos: [shader_count_max]raw.VkIndirectExecutionSetShaderLayoutInfoEXT = undefined;
        var layouts: [set_layout_count_max]raw.VkDescriptorSetLayout = undefined;
        var layout_count: usize = 0;
        for (options.initial, 0..) |slot, index| {
            if (slot.shader._device != context._device or layout_count + slot.set_layouts.len > layouts.len) return error.InvalidOptions;
            handles[index] = try slot.shader.rawHandle();
            const start = layout_count;
            for (slot.set_layouts) |layout| {
                if (layout._device_handle != context._device) return error.InvalidOptions;
                layouts[layout_count] = try layout.rawHandle();
                layout_count += 1;
            }
            layout_infos[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_INDIRECT_EXECUTION_SET_SHADER_LAYOUT_INFO_EXT, .setLayoutCount = @intCast(slot.set_layouts.len), .pSetLayouts = layouts[start..layout_count].ptr };
        }
        var ranges: [push_constant_count_max]raw.VkPushConstantRange = undefined;
        for (options.push_constants, 0..) |range, index| ranges[index] = .{ .stageFlags = range.stages.toRaw(), .offset = range.offset, .size = range.size };
        const shader_info: raw.VkIndirectExecutionSetShaderInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_INDIRECT_EXECUTION_SET_SHADER_INFO_EXT, .shaderCount = @intCast(options.initial.len), .pInitialShaders = handles[0..options.initial.len].ptr, .pSetLayoutInfos = layout_infos[0..options.initial.len].ptr, .maxShaderCount = options.capacity, .pushConstantRangeCount = @intCast(options.push_constants.len), .pPushConstantRanges = ranges[0..options.push_constants.len].ptr };
        const info: raw.VkIndirectExecutionSetCreateInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_INDIRECT_EXECUTION_SET_CREATE_INFO_EXT, .type = raw.VK_INDIRECT_EXECUTION_SET_INFO_TYPE_SHADER_OBJECTS_EXT, .info = .{ .pShaderInfo = &shader_info } };
        return context.finishCreateSet(create, destroy, info, .shader_objects, options.capacity);
    }

    fn finishCreateSet(context: Context, create: CommandFunction(raw.PFN_vkCreateIndirectExecutionSetEXT), destroy: CommandFunction(raw.PFN_vkDestroyIndirectExecutionSetEXT), info: raw.VkIndirectExecutionSetCreateInfoEXT, kind: ExecutionSetKind, capacity: u32) core.Error!ExecutionSet {
        var handle: raw.VkIndirectExecutionSetEXT = null;
        const result = create(context._device, &info, context._allocation_callbacks, &handle);
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional| destroy(context._device, provisional, context._allocation_callbacks);
            try core.checkSuccess(result);
        }
        return .{ ._handle = handle orelse return error.InvalidHandle, ._owner = try .init(&handle), ._device = context._device, ._state = context._state, .kind = kind, .capacity = capacity, .allocation_callbacks = context._allocation_callbacks, ._destroy = destroy };
    }

    pub fn updatePipelines(context: Context, set: *const ExecutionSet, updates: []const PipelineUpdate) core.Error!void {
        const update = context._update_pipelines orelse return error.MissingCommand;
        if (set._device != context._device or set.kind != .pipelines or updates.len == 0 or updates.len > update_count_max) return error.InvalidOptions;
        var writes: [update_count_max]raw.VkWriteIndirectExecutionSetPipelineEXT = undefined;
        for (updates, 0..) |item, index| {
            if (item.index >= set.capacity or item.pipeline._device_handle != context._device) return error.InvalidOptions;
            writes[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_WRITE_INDIRECT_EXECUTION_SET_PIPELINE_EXT, .index = item.index, .pipeline = try item.pipeline.rawHandle() };
        }
        update(context._device, try set.rawHandle(), @intCast(updates.len), writes[0..updates.len].ptr);
    }

    pub fn updateShaders(context: Context, set: *const ExecutionSet, updates: []const ShaderUpdate) core.Error!void {
        const update = context._update_shaders orelse return error.MissingCommand;
        if (set._device != context._device or set.kind != .shader_objects or updates.len == 0 or updates.len > update_count_max) return error.InvalidOptions;
        var writes: [update_count_max]raw.VkWriteIndirectExecutionSetShaderEXT = undefined;
        for (updates, 0..) |item, index| {
            if (item.index >= set.capacity or item.shader._device != context._device) return error.InvalidOptions;
            writes[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_WRITE_INDIRECT_EXECUTION_SET_SHADER_EXT, .index = item.index, .shader = try item.shader.rawHandle() };
        }
        update(context._device, try set.rawHandle(), @intCast(updates.len), writes[0..updates.len].ptr);
    }

    pub fn memoryRequirements(context: Context, options: RequirementsOptions) core.Error!memory.Requirements {
        const get = context._requirements orelse return error.MissingCommand;
        if (options.layout._device != context._device or options.max_sequences == 0 or options.max_sequences > context.properties.max_sequence_count or options.max_draws == 0) return error.InvalidOptions;
        if (options.execution_set) |set| {
            if (options.layout.execution_set_kind != set.kind) return error.InvalidOptions;
        }
        const info: raw.VkGeneratedCommandsMemoryRequirementsInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_GENERATED_COMMANDS_MEMORY_REQUIREMENTS_INFO_EXT, .indirectExecutionSet = if (options.execution_set) |set| blk: {
            if (set._device != context._device) return error.InvalidOptions;
            break :blk try set.rawHandle();
        } else null, .indirectCommandsLayout = try options.layout.rawHandle(), .maxSequenceCount = options.max_sequences, .maxDrawCount = options.max_draws };
        var output: raw.VkMemoryRequirements2 = .{ .sType = raw.VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2 };
        get(context._device, &info, &output);
        return .fromRaw(output.memoryRequirements);
    }

    fn rawInfo(context: Context, info: Info) core.Error!raw.VkGeneratedCommandsInfoEXT {
        if (info.layout._device != context._device or info.max_sequences == 0 or info.max_sequences > context.properties.max_sequence_count or info.indirect_size.bytes() == 0 or info.preprocess_size.bytes() == 0 or !containsStages(info.layout.stages, info.stages)) return error.InvalidOptions;
        if (info.execution_set) |set| {
            if (info.layout.execution_set_kind != set.kind) return error.InvalidOptions;
        }
        return .{ .sType = raw.VK_STRUCTURE_TYPE_GENERATED_COMMANDS_INFO_EXT, .shaderStages = info.stages.toRaw(), .indirectExecutionSet = if (info.execution_set) |set| blk: {
            if (set._device != context._device) return error.InvalidOptions;
            break :blk try set.rawHandle();
        } else null, .indirectCommandsLayout = try info.layout.rawHandle(), .indirectAddress = info.indirect_address.toRaw(), .indirectAddressSize = info.indirect_size.bytes(), .preprocessAddress = info.preprocess_address.toRaw(), .preprocessSize = info.preprocess_size.bytes(), .maxSequenceCount = info.max_sequences, .sequenceCountAddress = if (info.sequence_count_address) |address| address.toRaw() else 0, .maxDrawCount = info.max_draws };
    }

    pub fn preprocess(context: Context, command_buffer: *commands.Buffer, state_command_buffer: *commands.Buffer, info: Info) core.Error!void {
        const command_fn = context._preprocess orelse return error.MissingCommand;
        if (command_buffer._device_handle != context._device or state_command_buffer._device_handle != context._device or command_buffer.state != .recording or state_command_buffer.state != .recording) return error.InvalidOptions;
        const raw_info = try context.rawInfo(info);
        command_fn(try command_buffer.rawHandle(), &raw_info, try state_command_buffer.rawHandle());
    }
    pub fn execute(context: Context, command_buffer: *commands.Buffer, preprocessed: bool, info: Info) core.Error!void {
        const command_fn = context._execute orelse return error.MissingCommand;
        if (command_buffer._device_handle != context._device or command_buffer.state != .recording) return error.InvalidOptions;
        const raw_info = try context.rawInfo(info);
        command_fn(try command_buffer.rawHandle(), if (preprocessed) raw.VK_TRUE else raw.VK_FALSE, &raw_info);
    }
};

test "indirect token variants cannot be interchanged" {
    const token: Token = .{ .offset = 0, .data = .dispatch };
    try std.testing.expect(token.data == .dispatch);
    try std.testing.expect(extension == command.DeviceExtension.ext_device_generated_commands);
}

var test_execute_count: usize = 0;

fn testRequirements(_: raw.VkDevice, _: [*c]const raw.VkGeneratedCommandsMemoryRequirementsInfoEXT, output: [*c]raw.VkMemoryRequirements2) callconv(.c) void {
    output.*.memoryRequirements = .{ .size = 4096, .alignment = 256, .memoryTypeBits = 3 };
}

fn testExecute(_: raw.VkCommandBuffer, _: raw.VkBool32, info: [*c]const raw.VkGeneratedCommandsInfoEXT) callconv(.c) void {
    std.debug.assert(info.*.maxSequenceCount == 4);
    test_execute_count += 1;
}

test "requirements and generated recording use typed layouts and addresses" {
    var state = try core.DeviceState.init();
    defer state.markDestroyed();
    const device: DeviceHandle = @ptrFromInt(0x1000);
    var layout_handle: raw.VkIndirectCommandsLayoutEXT = @ptrFromInt(0x2000);
    var layout: Layout = .{ ._handle = layout_handle, ._owner = try .init(&layout_handle), ._device = device, ._state = &state, .stages = .init(&.{.compute}), .execution_set_kind = null, .allocation_callbacks = null, ._destroy = undefined };
    defer _ = layout._owner.release(&layout) catch false;

    var context: Context = undefined;
    context._device = device;
    context._state = &state;
    context.properties = .{ .max_pipeline_count = 8, .max_shader_object_count = 8, .max_sequence_count = 32, .max_token_count = 16, .max_token_offset = 256, .max_stride = 256, .supported_stages = .init(&.{.compute}) };
    context._requirements = testRequirements;
    context._execute = testExecute;
    const requirements = try context.memoryRequirements(.{ .layout = &layout, .max_sequences = 4 });
    try std.testing.expectEqual(@as(u64, 4096), requirements.size.bytes());

    var pool_handle: raw.VkCommandPool = @ptrFromInt(0x3000);
    var pool: commands.Pool = undefined;
    pool._handle = pool_handle;
    pool._owner = try .init(&pool_handle);
    pool._device_handle = device;
    pool._device_state = state;
    pool.generation = 0;
    defer _ = pool._owner.release(&pool) catch false;
    var command_buffer: commands.Buffer = undefined;
    command_buffer._handle = @ptrFromInt(0x4000);
    command_buffer._device_handle = device;
    command_buffer._pool = &pool;
    command_buffer._pool_owner = pool._owner.borrow();
    command_buffer._pool_generation = 0;
    command_buffer.state = .recording;
    test_execute_count = 0;
    try context.execute(&command_buffer, false, .{ .stages = .init(&.{.compute}), .layout = &layout, .indirect_address = @enumFromInt(0x5000), .indirect_size = .fromBytes(256), .preprocess_address = @enumFromInt(0x6000), .preprocess_size = .fromBytes(4096), .max_sequences = 4 });
    try std.testing.expectEqual(@as(usize, 1), test_execute_count);
}

test "unavailable generated command reports MissingCommand" {
    var context: Context = undefined;
    context._create_layout = null;
    try std.testing.expectError(error.MissingCommand, context.createLayout(undefined));
    context._create_set = null;
    try std.testing.expectError(error.MissingCommand, context.createPipelineSet(undefined));
    try std.testing.expectError(error.MissingCommand, context.createShaderSet(undefined));
    context._update_pipelines = null;
    try std.testing.expectError(error.MissingCommand, context.updatePipelines(undefined, &.{}));
    context._update_shaders = null;
    try std.testing.expectError(error.MissingCommand, context.updateShaders(undefined, &.{}));
    context._preprocess = null;
    try std.testing.expectError(error.MissingCommand, context.preprocess(undefined, undefined, undefined));
}
