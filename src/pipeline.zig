const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const descriptor = @import("descriptor.zig");
const shader = @import("shader.zig");
const debug_utils = @import("debug_utils.zig");
const types = @import("vulkan_types");
const sampler = @import("sampler.zig");
const render_passes = @import("render_pass.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const LayoutHandle = core.NonNullHandle(raw.VkPipelineLayout);
const PipelineHandle = core.NonNullHandle(raw.VkPipeline);
const set_layout_count_max = 32;
const push_constant_range_count_max = 32;

pub const PushConstantRange = struct {
    stages: shader.StageSet,
    offset: u32 = 0,
    size: u32,

    pub fn end(range: PushConstantRange) core.Error!u32 {
        return std.math.add(u32, range.offset, range.size) catch error.SizeOverflow;
    }
};

const std = @import("std");

pub const LayoutOptions = struct {
    set_layouts: []const *const descriptor.SetLayout = &.{},
    push_constants: []const PushConstantRange = &.{},
};

pub const LayoutDispatch = struct {
    create: CommandFunction(raw.PFN_vkCreatePipelineLayout),
    destroy: CommandFunction(raw.PFN_vkDestroyPipelineLayout),
};

pub const Layout = struct {
    _handle: ?LayoutHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    _push_constants: [push_constant_range_count_max]PushConstantRange = undefined,
    _push_constant_count: usize = 0,
    _set_layouts: [set_layout_count_max]raw.VkDescriptorSetLayout = undefined,
    _set_layout_count: usize = 0,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_layout: CommandFunction(raw.PFN_vkDestroyPipelineLayout),

    pub fn deinit(layout: *Layout) void {
        if (!(layout._owner.release(layout) catch return)) return;
        const handle = layout._handle orelse return;
        layout.destroy_layout(layout._device_handle, handle, layout.allocation_callbacks);
        layout._handle = null;
    }

    pub fn rawHandle(layout: *const Layout) core.Error!raw.VkPipelineLayout {
        try layout._owner.validate(layout);
        if (layout._device_state) |*state| try state.ensureDispatchAllowed();
        return layout._handle orelse error.InactiveObject;
    }

    pub fn supportsPushConstants(
        layout: *const Layout,
        stages: shader.StageSet,
        offset: u32,
        size: u32,
    ) bool {
        const end = std.math.add(u32, offset, size) catch return false;
        for (layout._push_constants[0..layout._push_constant_count]) |range| {
            if (!range.stages.intersects(stages)) continue;
            const range_end = range.end() catch continue;
            if (offset >= range.offset and end <= range_end) return true;
        }
        return false;
    }

    pub fn supportsDescriptorSet(layout: *const Layout, set_index: u32, set_layout: raw.VkDescriptorSetLayout) bool {
        const index: usize = set_index;
        return index < layout._set_layout_count and layout._set_layouts[index] == set_layout;
    }

    pub fn debugObject(layout: *const Layout) core.Error!debug_utils.Object {
        return .forDevice(.pipeline_layout, try layout.rawHandle(), layout._device_handle);
    }
};

pub fn createLayout(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: LayoutDispatch,
    max_push_constant_size: u32,
    options: LayoutOptions,
) core.Error!Layout {
    if (options.set_layouts.len > set_layout_count_max or
        options.push_constants.len > push_constant_range_count_max)
    {
        return error.CountOverflow;
    }
    var raw_set_layouts: [set_layout_count_max]raw.VkDescriptorSetLayout = undefined;
    for (options.set_layouts, 0..) |set_layout, index| {
        if (set_layout._device_handle != device_handle) return error.InvalidHandle;
        raw_set_layouts[index] = try set_layout.rawHandle();
    }
    var raw_ranges: [push_constant_range_count_max]raw.VkPushConstantRange = undefined;
    for (options.push_constants, 0..) |range, index| {
        if (range.size == 0 or range.size % 4 != 0 or range.offset % 4 != 0 or
            range.stages.toRaw() == 0 or try range.end() > max_push_constant_size)
        {
            return error.InvalidOptions;
        }
        for (options.push_constants[0..index]) |previous| {
            if (!range.stages.intersects(previous.stages)) continue;
            if (range.offset < try previous.end() and previous.offset < try range.end()) {
                return error.InvalidOptions;
            }
        }
        raw_ranges[index] = .{
            .stageFlags = range.stages.toRaw(),
            .offset = range.offset,
            .size = range.size,
        };
    }
    const info: raw.VkPipelineLayoutCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = @intCast(options.set_layouts.len),
        .pSetLayouts = if (options.set_layouts.len == 0) null else raw_set_layouts[0..options.set_layouts.len].ptr,
        .pushConstantRangeCount = @intCast(options.push_constants.len),
        .pPushConstantRanges = if (options.push_constants.len == 0) null else raw_ranges[0..options.push_constants.len].ptr,
    };
    var handle: raw.VkPipelineLayout = null;
    const result = dispatch.create(device_handle, &info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccess(result);
        unreachable;
    }
    var layout: Layout = .{
        ._handle = handle orelse return error.InvalidHandle,
        ._owner = try .init(&handle),
        ._device_handle = device_handle,
        .allocation_callbacks = allocation_callbacks,
        .destroy_layout = dispatch.destroy,
    };
    for (options.push_constants, 0..) |range, index| layout._push_constants[index] = range;
    layout._push_constant_count = options.push_constants.len;
    for (raw_set_layouts[0..options.set_layouts.len], 0..) |set_layout, index| layout._set_layouts[index] = set_layout;
    layout._set_layout_count = options.set_layouts.len;
    return layout;
}

pub const BindPoint = enum(raw.VkPipelineBindPoint) {
    graphics = raw.VK_PIPELINE_BIND_POINT_GRAPHICS,
    compute = raw.VK_PIPELINE_BIND_POINT_COMPUTE,
    _,

    pub fn fromRaw(value: raw.VkPipelineBindPoint) BindPoint {
        return @enumFromInt(value);
    }
    pub fn toRaw(value: BindPoint) raw.VkPipelineBindPoint {
        return @intFromEnum(value);
    }
};

pub const VertexInputRate = enum(raw.VkVertexInputRate) {
    vertex = raw.VK_VERTEX_INPUT_RATE_VERTEX,
    instance = raw.VK_VERTEX_INPUT_RATE_INSTANCE,
    _,

    pub fn fromRaw(value: raw.VkVertexInputRate) VertexInputRate {
        return @enumFromInt(value);
    }
    pub fn toRaw(value: VertexInputRate) raw.VkVertexInputRate {
        return @intFromEnum(value);
    }
};

pub const VertexBinding = struct { binding: u32, stride: u32, rate: VertexInputRate = .vertex };
pub const VertexAttribute = struct { location: u32, binding: u32, format: types.Format, offset: u32 };

pub const Topology = enum(raw.VkPrimitiveTopology) {
    point_list = raw.VK_PRIMITIVE_TOPOLOGY_POINT_LIST,
    line_list = raw.VK_PRIMITIVE_TOPOLOGY_LINE_LIST,
    line_strip = raw.VK_PRIMITIVE_TOPOLOGY_LINE_STRIP,
    triangle_list = raw.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
    triangle_strip = raw.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP,
    triangle_fan = raw.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN,
    patch_list = raw.VK_PRIMITIVE_TOPOLOGY_PATCH_LIST,
    _,

    pub fn fromRaw(value: raw.VkPrimitiveTopology) Topology {
        return @enumFromInt(value);
    }
    pub fn toRaw(value: Topology) raw.VkPrimitiveTopology {
        return @intFromEnum(value);
    }
};

pub const PolygonMode = enum(raw.VkPolygonMode) {
    fill = raw.VK_POLYGON_MODE_FILL,
    line = raw.VK_POLYGON_MODE_LINE,
    point = raw.VK_POLYGON_MODE_POINT,
    _,

    pub fn fromRaw(value: raw.VkPolygonMode) PolygonMode {
        return @enumFromInt(value);
    }
    pub fn toRaw(value: PolygonMode) raw.VkPolygonMode {
        return @intFromEnum(value);
    }
};

pub const CullMode = enum(raw.VkCullModeFlags) {
    none = raw.VK_CULL_MODE_NONE,
    front = raw.VK_CULL_MODE_FRONT_BIT,
    back = raw.VK_CULL_MODE_BACK_BIT,
    front_and_back = raw.VK_CULL_MODE_FRONT_AND_BACK,
    _,

    pub fn fromRaw(value: raw.VkCullModeFlags) CullMode {
        return @enumFromInt(value);
    }
    pub fn toRaw(value: CullMode) raw.VkCullModeFlags {
        return @intFromEnum(value);
    }
};

pub const FrontFace = enum(raw.VkFrontFace) {
    counter_clockwise = raw.VK_FRONT_FACE_COUNTER_CLOCKWISE,
    clockwise = raw.VK_FRONT_FACE_CLOCKWISE,
    _,

    pub fn fromRaw(value: raw.VkFrontFace) FrontFace {
        return @enumFromInt(value);
    }
    pub fn toRaw(value: FrontFace) raw.VkFrontFace {
        return @intFromEnum(value);
    }
};

pub const DepthBias = struct {
    constant: f32 = 0,
    clamp: f32 = 0,
    slope: f32 = 0,
};

pub const Rasterization = struct {
    depth_clamp: bool = false,
    discard: bool = false,
    polygon_mode: PolygonMode = .fill,
    cull_mode: CullMode = .back,
    front_face: FrontFace = .counter_clockwise,
    depth_bias: ?DepthBias = null,
    line_width: f32 = 1,
};

pub const Multisample = struct {
    samples: types.SampleCountBit = ._1,
    minimum_sample_shading: ?f32 = null,
    alpha_to_coverage: bool = false,
    alpha_to_one: bool = false,
};

pub const DepthBounds = struct {
    minimum: f32 = 0,
    maximum: f32 = 1,
};

pub const DepthStencil = struct {
    depth_test: bool = false,
    depth_write: bool = false,
    depth_compare: sampler.CompareOperation = .less,
    depth_bounds: ?DepthBounds = null,
};

pub const BlendFactor = enum(raw.VkBlendFactor) {
    zero = raw.VK_BLEND_FACTOR_ZERO,
    one = raw.VK_BLEND_FACTOR_ONE,
    source_alpha = raw.VK_BLEND_FACTOR_SRC_ALPHA,
    one_minus_source_alpha = raw.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
    destination_alpha = raw.VK_BLEND_FACTOR_DST_ALPHA,
    one_minus_destination_alpha = raw.VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA,
    _,

    pub fn fromRaw(value: raw.VkBlendFactor) BlendFactor {
        return @enumFromInt(value);
    }
    pub fn toRaw(value: BlendFactor) raw.VkBlendFactor {
        return @intFromEnum(value);
    }
};

pub const BlendOperation = enum(raw.VkBlendOp) {
    add = raw.VK_BLEND_OP_ADD,
    subtract = raw.VK_BLEND_OP_SUBTRACT,
    reverse_subtract = raw.VK_BLEND_OP_REVERSE_SUBTRACT,
    minimum = raw.VK_BLEND_OP_MIN,
    maximum = raw.VK_BLEND_OP_MAX,
    _,

    pub fn fromRaw(value: raw.VkBlendOp) BlendOperation {
        return @enumFromInt(value);
    }
    pub fn toRaw(value: BlendOperation) raw.VkBlendOp {
        return @intFromEnum(value);
    }
};

pub const ColorWriteMask = packed struct(u4) {
    red: bool = true,
    green: bool = true,
    blue: bool = true,
    alpha: bool = true,

    fn toRaw(value: ColorWriteMask) raw.VkColorComponentFlags {
        var result: raw.VkColorComponentFlags = 0;
        if (value.red) result |= raw.VK_COLOR_COMPONENT_R_BIT;
        if (value.green) result |= raw.VK_COLOR_COMPONENT_G_BIT;
        if (value.blue) result |= raw.VK_COLOR_COMPONENT_B_BIT;
        if (value.alpha) result |= raw.VK_COLOR_COMPONENT_A_BIT;
        return result;
    }
};

pub const ColorBlendAttachment = struct {
    enabled: bool = false,
    source_color: BlendFactor = .one,
    destination_color: BlendFactor = .zero,
    color_operation: BlendOperation = .add,
    source_alpha: BlendFactor = .one,
    destination_alpha: BlendFactor = .zero,
    alpha_operation: BlendOperation = .add,
    write_mask: ColorWriteMask = .{},
};

pub const DynamicState = enum(raw.VkDynamicState) {
    viewport = raw.VK_DYNAMIC_STATE_VIEWPORT,
    scissor = raw.VK_DYNAMIC_STATE_SCISSOR,
    line_width = raw.VK_DYNAMIC_STATE_LINE_WIDTH,
    depth_bias = raw.VK_DYNAMIC_STATE_DEPTH_BIAS,
    blend_constants = raw.VK_DYNAMIC_STATE_BLEND_CONSTANTS,
    depth_bounds = raw.VK_DYNAMIC_STATE_DEPTH_BOUNDS,
    stencil_compare_mask = raw.VK_DYNAMIC_STATE_STENCIL_COMPARE_MASK,
    stencil_write_mask = raw.VK_DYNAMIC_STATE_STENCIL_WRITE_MASK,
    stencil_reference = raw.VK_DYNAMIC_STATE_STENCIL_REFERENCE,
    _,

    pub fn fromRaw(value: raw.VkDynamicState) DynamicState {
        return @enumFromInt(value);
    }
    pub fn toRaw(value: DynamicState) raw.VkDynamicState {
        return @intFromEnum(value);
    }
};

pub const RenderingFormats = struct {
    color: []const types.Format = &.{},
    depth: ?types.Format = null,
    stencil: ?types.Format = null,
    view_mask: u32 = 0,
};

pub const LegacyRenderPassCompatibility = struct {
    render_pass: *const render_passes.RenderPass,
    subpass: u32 = 0,
};

pub const GraphicsCompatibility = union(enum) {
    dynamic_rendering: RenderingFormats,
    render_pass: LegacyRenderPassCompatibility,
};

pub const GraphicsOptions = struct {
    stages: []const shader.StageOptions,
    layout: *const Layout,
    vertex_bindings: []const VertexBinding = &.{},
    vertex_attributes: []const VertexAttribute = &.{},
    topology: Topology = .triangle_list,
    primitive_restart: bool = false,
    patch_control_points: ?u32 = null,
    viewports: []const types.Viewport = &.{},
    scissors: []const types.Rect2D = &.{},
    rasterization: Rasterization = .{},
    multisample: Multisample = .{},
    depth_stencil: DepthStencil = .{},
    color_blend_attachments: []const ColorBlendAttachment = &.{},
    blend_constants: [4]f32 = .{ 0, 0, 0, 0 },
    dynamic_states: []const DynamicState = &.{ .viewport, .scissor },
    compatibility: GraphicsCompatibility = .{ .dynamic_rendering = .{} },
    fail_on_compile_required: bool = false,
};

pub const ComputeOptions = struct {
    stage: shader.StageOptions,
    layout: *const Layout,
    fail_on_compile_required: bool = false,
};

pub const Pipeline = struct {
    _handle: ?PipelineHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    bind_point: BindPoint,
    _dynamic_rendering: bool = false,
    _render_pass_handle: raw.VkRenderPass = null,
    _subpass: u32 = 0,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_pipeline: CommandFunction(raw.PFN_vkDestroyPipeline),

    pub fn deinit(pipeline: *Pipeline) void {
        if (!(pipeline._owner.release(pipeline) catch return)) return;
        const handle = pipeline._handle orelse return;
        pipeline.destroy_pipeline(pipeline._device_handle, handle, pipeline.allocation_callbacks);
        pipeline._handle = null;
    }

    pub fn rawHandle(pipeline: *const Pipeline) core.Error!raw.VkPipeline {
        try pipeline._owner.validate(pipeline);
        if (pipeline._device_state) |*state| try state.ensureDispatchAllowed();
        return pipeline._handle orelse error.InactiveObject;
    }

    pub fn debugObject(pipeline: *const Pipeline) core.Error!debug_utils.Object {
        return .forDevice(.pipeline, try pipeline.rawHandle(), pipeline._device_handle);
    }
};

pub const CreateResult = union(enum) {
    success: Pipeline,
    compile_required,
};

pub const PipelineDispatch = struct {
    create_graphics: CommandFunction(raw.PFN_vkCreateGraphicsPipelines),
    create_compute: CommandFunction(raw.PFN_vkCreateComputePipelines),
    destroy: CommandFunction(raw.PFN_vkDestroyPipeline),
};

const StageGraph = struct {
    stages: [8]raw.VkPipelineShaderStageCreateInfo = undefined,
    specializations: [8]raw.VkSpecializationInfo = undefined,
    entries: [128]raw.VkSpecializationMapEntry = undefined,
    entry_count: usize = 0,

    fn build(graph: *StageGraph, options: []const shader.StageOptions, device_handle: DeviceHandle) core.Error![]const raw.VkPipelineShaderStageCreateInfo {
        if (options.len == 0 or options.len > graph.stages.len) return error.InvalidOptions;
        for (options, 0..) |stage, index| {
            if (stage.module._device_handle != device_handle or stage.entry_point.len == 0) return error.InvalidHandle;
            var specialization_pointer: [*c]const raw.VkSpecializationInfo = null;
            if (stage.specialization) |specialization| {
                try specialization.validate();
                if (specialization.entries.len > graph.entries.len - graph.entry_count) return error.CountOverflow;
                const start = graph.entry_count;
                for (specialization.entries) |entry| {
                    graph.entries[graph.entry_count] = .{
                        .constantID = entry.constant_id,
                        .offset = @intCast(entry.offset),
                        .size = entry.size,
                    };
                    graph.entry_count += 1;
                }
                graph.specializations[index] = .{
                    .mapEntryCount = @intCast(specialization.entries.len),
                    .pMapEntries = graph.entries[start..graph.entry_count].ptr,
                    .dataSize = specialization.data.len,
                    .pData = specialization.data.ptr,
                };
                specialization_pointer = &graph.specializations[index];
            }
            graph.stages[index] = .{
                .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = stage.stage.toRaw(),
                .module = try stage.module.rawHandle(),
                .pName = stage.entry_point.ptr,
                .pSpecializationInfo = specialization_pointer,
            };
        }
        return graph.stages[0..options.len];
    }
};

fn creationFlags(fail_on_compile_required: bool) raw.VkPipelineCreateFlags {
    return if (fail_on_compile_required)
        @intCast(raw.VK_PIPELINE_CREATE_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT)
    else
        0;
}

fn finishCreate(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy: CommandFunction(raw.PFN_vkDestroyPipeline),
    bind_point: BindPoint,
    result: raw.VkResult,
    handle: raw.VkPipeline,
    dynamic_rendering: bool,
    render_pass_handle: raw.VkRenderPass,
    subpass: u32,
) core.Error!CreateResult {
    if (result == raw.VK_PIPELINE_COMPILE_REQUIRED) {
        if (handle) |provisional| destroy(device_handle, provisional, allocation_callbacks);
        return .compile_required;
    }
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccess(result);
        unreachable;
    }
    return .{ .success = .{
        ._handle = handle orelse return error.InvalidHandle,
        ._owner = try .init(&handle),
        ._device_handle = device_handle,
        .bind_point = bind_point,
        ._dynamic_rendering = dynamic_rendering,
        ._render_pass_handle = render_pass_handle,
        ._subpass = subpass,
        .allocation_callbacks = allocation_callbacks,
        .destroy_pipeline = destroy,
    } };
}

pub fn createCompute(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: PipelineDispatch,
    options: ComputeOptions,
) core.Error!CreateResult {
    if (options.layout._device_handle != device_handle or options.stage.stage != .compute) return error.InvalidOptions;
    var graph: StageGraph = .{};
    const stages = try graph.build(&.{options.stage}, device_handle);
    const info: raw.VkComputePipelineCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .flags = creationFlags(options.fail_on_compile_required),
        .stage = stages[0],
        .layout = try options.layout.rawHandle(),
    };
    var handle: raw.VkPipeline = null;
    const result = dispatch.create_compute(device_handle, null, 1, &info, allocation_callbacks, &handle);
    return finishCreate(device_handle, allocation_callbacks, dispatch.destroy, .compute, result, handle, false, null, 0);
}

pub fn createGraphics(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: PipelineDispatch,
    options: GraphicsOptions,
) core.Error!CreateResult {
    if (options.layout._device_handle != device_handle) return error.InvalidHandle;
    if (options.vertex_bindings.len > 32 or options.vertex_attributes.len > 64 or
        options.viewports.len > 16 or options.scissors.len > 16 or
        options.color_blend_attachments.len > 16 or options.dynamic_states.len > 32 or
        (switch (options.compatibility) {
            .dynamic_rendering => |value| value.color.len,
            .render_pass => 0,
        }) > 16)
    {
        return error.CountOverflow;
    }
    if (options.viewports.len != options.scissors.len) return error.InvalidOptions;
    const dynamic_formats: RenderingFormats = switch (options.compatibility) {
        .dynamic_rendering => |value| value,
        .render_pass => .{},
    };
    var legacy_render_pass: raw.VkRenderPass = null;
    var legacy_subpass: u32 = 0;
    switch (options.compatibility) {
        .dynamic_rendering => {
            if (options.color_blend_attachments.len != dynamic_formats.color.len) return error.InvalidOptions;
        },
        .render_pass => |value| {
            if (value.render_pass._device_handle != device_handle) return error.InvalidHandle;
            legacy_render_pass = try value.render_pass.rawHandle();
            legacy_subpass = value.subpass;
            const color_count = value.render_pass.subpassColorAttachmentCount(value.subpass) orelse return error.InvalidOptions;
            const samples = value.render_pass.subpassSamples(value.subpass) orelse return error.InvalidOptions;
            if (options.color_blend_attachments.len != color_count or options.multisample.samples != samples) return error.InvalidOptions;
        },
    }
    if (!std.math.isFinite(options.rasterization.line_width) or options.rasterization.line_width <= 0) return error.InvalidOptions;
    if (options.multisample.minimum_sample_shading) |value| {
        if (!std.math.isFinite(value) or value < 0 or value > 1) return error.InvalidOptions;
    }
    var graph: StageGraph = .{};
    const stages = try graph.build(options.stages, device_handle);
    var bindings: [32]raw.VkVertexInputBindingDescription = undefined;
    for (options.vertex_bindings, 0..) |binding, index| bindings[index] = .{
        .binding = binding.binding,
        .stride = binding.stride,
        .inputRate = binding.rate.toRaw(),
    };
    var attributes: [64]raw.VkVertexInputAttributeDescription = undefined;
    for (options.vertex_attributes, 0..) |attribute, index| attributes[index] = .{
        .location = attribute.location,
        .binding = attribute.binding,
        .format = attribute.format.toRaw(),
        .offset = attribute.offset,
    };
    const vertex_input: raw.VkPipelineVertexInputStateCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = @intCast(options.vertex_bindings.len),
        .pVertexBindingDescriptions = if (options.vertex_bindings.len == 0) null else bindings[0..options.vertex_bindings.len].ptr,
        .vertexAttributeDescriptionCount = @intCast(options.vertex_attributes.len),
        .pVertexAttributeDescriptions = if (options.vertex_attributes.len == 0) null else attributes[0..options.vertex_attributes.len].ptr,
    };
    const input_assembly: raw.VkPipelineInputAssemblyStateCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = options.topology.toRaw(),
        .primitiveRestartEnable = if (options.primitive_restart) raw.VK_TRUE else raw.VK_FALSE,
    };
    const tessellation: raw.VkPipelineTessellationStateCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_TESSELLATION_STATE_CREATE_INFO,
        .patchControlPoints = options.patch_control_points orelse 0,
    };
    var viewports: [16]raw.VkViewport = undefined;
    for (options.viewports, 0..) |viewport, index| viewports[index] = viewport.toRaw();
    var scissors: [16]raw.VkRect2D = undefined;
    for (options.scissors, 0..) |scissor, index| scissors[index] = scissor.toRaw();
    const viewport_state: raw.VkPipelineViewportStateCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = @intCast(@max(1, options.viewports.len)),
        .pViewports = if (options.viewports.len == 0) null else viewports[0..options.viewports.len].ptr,
        .scissorCount = @intCast(@max(1, options.scissors.len)),
        .pScissors = if (options.scissors.len == 0) null else scissors[0..options.scissors.len].ptr,
    };
    const bias = options.rasterization.depth_bias orelse DepthBias{};
    const rasterization: raw.VkPipelineRasterizationStateCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = if (options.rasterization.depth_clamp) raw.VK_TRUE else raw.VK_FALSE,
        .rasterizerDiscardEnable = if (options.rasterization.discard) raw.VK_TRUE else raw.VK_FALSE,
        .polygonMode = options.rasterization.polygon_mode.toRaw(),
        .cullMode = options.rasterization.cull_mode.toRaw(),
        .frontFace = options.rasterization.front_face.toRaw(),
        .depthBiasEnable = if (options.rasterization.depth_bias != null) raw.VK_TRUE else raw.VK_FALSE,
        .depthBiasConstantFactor = bias.constant,
        .depthBiasClamp = bias.clamp,
        .depthBiasSlopeFactor = bias.slope,
        .lineWidth = options.rasterization.line_width,
    };
    const multisample: raw.VkPipelineMultisampleStateCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .rasterizationSamples = options.multisample.samples.toRaw(),
        .sampleShadingEnable = if (options.multisample.minimum_sample_shading != null) raw.VK_TRUE else raw.VK_FALSE,
        .minSampleShading = options.multisample.minimum_sample_shading orelse 0,
        .alphaToCoverageEnable = if (options.multisample.alpha_to_coverage) raw.VK_TRUE else raw.VK_FALSE,
        .alphaToOneEnable = if (options.multisample.alpha_to_one) raw.VK_TRUE else raw.VK_FALSE,
    };
    const bounds = options.depth_stencil.depth_bounds orelse DepthBounds{};
    const depth_stencil: raw.VkPipelineDepthStencilStateCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .depthTestEnable = if (options.depth_stencil.depth_test) raw.VK_TRUE else raw.VK_FALSE,
        .depthWriteEnable = if (options.depth_stencil.depth_write) raw.VK_TRUE else raw.VK_FALSE,
        .depthCompareOp = options.depth_stencil.depth_compare.toRaw(),
        .depthBoundsTestEnable = if (options.depth_stencil.depth_bounds != null) raw.VK_TRUE else raw.VK_FALSE,
        .minDepthBounds = bounds.minimum,
        .maxDepthBounds = bounds.maximum,
    };
    var blend_attachments: [16]raw.VkPipelineColorBlendAttachmentState = undefined;
    for (options.color_blend_attachments, 0..) |attachment, index| blend_attachments[index] = .{
        .blendEnable = if (attachment.enabled) raw.VK_TRUE else raw.VK_FALSE,
        .srcColorBlendFactor = attachment.source_color.toRaw(),
        .dstColorBlendFactor = attachment.destination_color.toRaw(),
        .colorBlendOp = attachment.color_operation.toRaw(),
        .srcAlphaBlendFactor = attachment.source_alpha.toRaw(),
        .dstAlphaBlendFactor = attachment.destination_alpha.toRaw(),
        .alphaBlendOp = attachment.alpha_operation.toRaw(),
        .colorWriteMask = attachment.write_mask.toRaw(),
    };
    const blend: raw.VkPipelineColorBlendStateCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .attachmentCount = @intCast(options.color_blend_attachments.len),
        .pAttachments = if (options.color_blend_attachments.len == 0) null else blend_attachments[0..options.color_blend_attachments.len].ptr,
        .blendConstants = options.blend_constants,
    };
    var dynamic_states: [32]raw.VkDynamicState = undefined;
    for (options.dynamic_states, 0..) |state, index| dynamic_states[index] = state.toRaw();
    const dynamic: raw.VkPipelineDynamicStateCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = @intCast(options.dynamic_states.len),
        .pDynamicStates = if (options.dynamic_states.len == 0) null else dynamic_states[0..options.dynamic_states.len].ptr,
    };
    var color_formats: [16]raw.VkFormat = undefined;
    for (dynamic_formats.color, 0..) |format, index| color_formats[index] = format.toRaw();
    const dynamic_rendering: raw.VkPipelineRenderingCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
        .viewMask = dynamic_formats.view_mask,
        .colorAttachmentCount = @intCast(dynamic_formats.color.len),
        .pColorAttachmentFormats = if (dynamic_formats.color.len == 0) null else color_formats[0..dynamic_formats.color.len].ptr,
        .depthAttachmentFormat = if (dynamic_formats.depth) |format| format.toRaw() else raw.VK_FORMAT_UNDEFINED,
        .stencilAttachmentFormat = if (dynamic_formats.stencil) |format| format.toRaw() else raw.VK_FORMAT_UNDEFINED,
    };
    const info: raw.VkGraphicsPipelineCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .pNext = if (options.compatibility == .dynamic_rendering) &dynamic_rendering else null,
        .flags = creationFlags(options.fail_on_compile_required),
        .stageCount = @intCast(stages.len),
        .pStages = stages.ptr,
        .pVertexInputState = &vertex_input,
        .pInputAssemblyState = &input_assembly,
        .pTessellationState = if (options.patch_control_points != null) &tessellation else null,
        .pViewportState = &viewport_state,
        .pRasterizationState = &rasterization,
        .pMultisampleState = &multisample,
        .pDepthStencilState = &depth_stencil,
        .pColorBlendState = &blend,
        .pDynamicState = &dynamic,
        .layout = try options.layout.rawHandle(),
        .renderPass = legacy_render_pass,
        .subpass = legacy_subpass,
    };
    var handle: raw.VkPipeline = null;
    const result = dispatch.create_graphics(device_handle, null, 1, &info, allocation_callbacks, &handle);
    return finishCreate(
        device_handle,
        allocation_callbacks,
        dispatch.destroy,
        .graphics,
        result,
        handle,
        options.compatibility == .dynamic_rendering,
        legacy_render_pass,
        legacy_subpass,
    );
}

pub fn createComputeBatch(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: PipelineDispatch,
    options: []const ComputeOptions,
    output: []CreateResult,
) core.Error![]CreateResult {
    if (options.len == 0) return error.InvalidOptions;
    if (output.len < options.len) return error.BufferTooSmall;
    var initialized: usize = 0;
    errdefer rollbackBatch(output[0..initialized]);
    for (options, 0..) |item, index| {
        output[index] = try createCompute(device_handle, allocation_callbacks, dispatch, item);
        initialized += 1;
    }
    return output[0..options.len];
}

pub fn createGraphicsBatch(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: PipelineDispatch,
    options: []const GraphicsOptions,
    output: []CreateResult,
) core.Error![]CreateResult {
    if (options.len == 0) return error.InvalidOptions;
    if (output.len < options.len) return error.BufferTooSmall;
    var initialized: usize = 0;
    errdefer rollbackBatch(output[0..initialized]);
    for (options, 0..) |item, index| {
        output[index] = try createGraphics(device_handle, allocation_callbacks, dispatch, item);
        initialized += 1;
    }
    return output[0..options.len];
}

fn rollbackBatch(results: []CreateResult) void {
    for (results) |*result| switch (result.*) {
        .success => |*value| value.deinit(),
        .compile_required => {},
    };
}

test "all pipeline declarations compile" {
    std.testing.refAllDecls(@This());
}

test "pipeline enum domains preserve unknown extension values" {
    const unknown_topology: raw.VkPrimitiveTopology = 0x7fff;
    const unknown_dynamic_state: raw.VkDynamicState = 0x7ffe;
    try std.testing.expectEqual(unknown_topology, Topology.fromRaw(unknown_topology).toRaw());
    try std.testing.expectEqual(unknown_dynamic_state, DynamicState.fromRaw(unknown_dynamic_state).toRaw());
}

var test_layout_result: raw.VkResult = raw.VK_SUCCESS;
var test_layout_destroy_count: usize = 0;
var test_pipeline_result: raw.VkResult = raw.VK_SUCCESS;
var test_pipeline_destroy_count: usize = 0;
var test_graphics_has_rendering = false;
var test_graphics_render_pass: raw.VkRenderPass = null;
var test_graphics_subpass: u32 = 0;

fn testCreateLayout(
    _: raw.VkDevice,
    _: [*c]const raw.VkPipelineLayoutCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkPipelineLayout,
) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x3000);
    return test_layout_result;
}

fn testDestroyLayout(
    _: raw.VkDevice,
    _: raw.VkPipelineLayout,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_layout_destroy_count += 1;
}

fn testDestroySetLayout(
    _: raw.VkDevice,
    _: raw.VkDescriptorSetLayout,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {}

fn testCreateComputePipeline(
    _: raw.VkDevice,
    _: raw.VkPipelineCache,
    count: u32,
    infos: [*c]const raw.VkComputePipelineCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkPipeline,
) callconv(.c) raw.VkResult {
    for (0..count) |index| {
        std.debug.assert(infos[index].stage.stage == raw.VK_SHADER_STAGE_COMPUTE_BIT);
        output[index] = @ptrFromInt(0x5000 + index);
    }
    return test_pipeline_result;
}

fn testCreateGraphicsPipeline(
    _: raw.VkDevice,
    _: raw.VkPipelineCache,
    count: u32,
    infos: [*c]const raw.VkGraphicsPipelineCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkPipeline,
) callconv(.c) raw.VkResult {
    for (0..count) |index| output[index] = @ptrFromInt(0x6000 + index);
    test_graphics_has_rendering = infos[0].pNext != null;
    test_graphics_render_pass = infos[0].renderPass;
    test_graphics_subpass = infos[0].subpass;
    return test_pipeline_result;
}

fn testCreateRenderPass(
    _: raw.VkDevice,
    _: [*c]const raw.VkRenderPassCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkRenderPass,
) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x7000);
    return raw.VK_SUCCESS;
}

fn testDestroyRenderPass(
    _: raw.VkDevice,
    _: raw.VkRenderPass,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {}

fn testRenderAreaGranularity(_: raw.VkDevice, _: raw.VkRenderPass, _: [*c]raw.VkExtent2D) callconv(.c) void {}

fn testDestroyPipeline(
    _: raw.VkDevice,
    _: raw.VkPipeline,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_pipeline_destroy_count += 1;
}

fn testDestroyShaderModule(
    _: raw.VkDevice,
    _: raw.VkShaderModule,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {}

test "pipeline layouts reject invalid ranges and roll back provisional handles" {
    const device_handle: DeviceHandle = @ptrFromInt(0x1000);
    const dispatch: LayoutDispatch = .{ .create = testCreateLayout, .destroy = testDestroyLayout };
    const vertex = shader.StageSet.init(&.{.vertex});
    const fragment = shader.StageSet.init(&.{.fragment});

    try std.testing.expectError(error.InvalidOptions, createLayout(device_handle, null, dispatch, 128, .{
        .push_constants = &.{.{ .stages = vertex, .offset = 2, .size = 4 }},
    }));
    const foreign_set_layout: descriptor.SetLayout = .{
        ._handle = @ptrFromInt(0x4000),
        ._owner = core.Owner.init({}) catch unreachable,
        ._device_handle = @ptrFromInt(0x2000),
        .allocation_callbacks = null,
        .destroy_layout = testDestroySetLayout,
    };
    try std.testing.expectError(error.InvalidHandle, createLayout(device_handle, null, dispatch, 128, .{
        .set_layouts = &.{&foreign_set_layout},
    }));
    try std.testing.expectError(error.InvalidOptions, createLayout(device_handle, null, dispatch, 128, .{
        .push_constants = &.{.{ .stages = vertex, .size = 132 }},
    }));
    try std.testing.expectError(error.InvalidOptions, createLayout(device_handle, null, dispatch, 128, .{
        .push_constants = &.{
            .{ .stages = vertex, .offset = 0, .size = 16 },
            .{ .stages = vertex, .offset = 8, .size = 16 },
        },
    }));

    var layout = try createLayout(device_handle, null, dispatch, 128, .{
        .push_constants = &.{
            .{ .stages = vertex, .offset = 0, .size = 16 },
            .{ .stages = fragment, .offset = 8, .size = 16 },
        },
    });
    try std.testing.expect(layout.supportsPushConstants(vertex, 4, 8));
    try std.testing.expect(!layout.supportsPushConstants(fragment, 0, 4));
    test_layout_destroy_count = 0;
    layout.deinit();
    layout.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_layout_destroy_count);

    test_layout_result = raw.VK_ERROR_OUT_OF_HOST_MEMORY;
    defer test_layout_result = raw.VK_SUCCESS;
    test_layout_destroy_count = 0;
    try std.testing.expectError(error.OutOfHostMemory, createLayout(device_handle, null, dispatch, 128, .{}));
    try std.testing.expectEqual(@as(usize, 1), test_layout_destroy_count);
}

test "compute pipeline batches preserve compile status and roll back earlier successes" {
    const device_handle: DeviceHandle = @ptrFromInt(0x1000);
    const dispatch: PipelineDispatch = .{
        .create_graphics = testCreateGraphicsPipeline,
        .create_compute = testCreateComputePipeline,
        .destroy = testDestroyPipeline,
    };
    const module: shader.Module = .{
        ._handle = @ptrFromInt(0x2000),
        ._owner = core.Owner.init({}) catch unreachable,
        ._device_handle = device_handle,
        .allocation_callbacks = null,
        .dispatch = .{
            .create = undefined,
            .destroy = testDestroyShaderModule,
            .get_identifier = null,
            .get_create_info_identifier = null,
        },
    };
    const layout: Layout = .{
        ._handle = @ptrFromInt(0x3000),
        ._owner = core.Owner.init({}) catch unreachable,
        ._device_handle = device_handle,
        .allocation_callbacks = null,
        .destroy_layout = testDestroyLayout,
    };
    const valid: ComputeOptions = .{ .stage = .{ .stage = .compute, .module = &module }, .layout = &layout };

    test_pipeline_result = raw.VK_SUCCESS;
    test_graphics_has_rendering = false;
    var graphics_result = try createGraphics(device_handle, null, dispatch, .{
        .stages = &.{.{ .stage = .vertex, .module = &module }},
        .layout = &layout,
        .color_blend_attachments = &.{.{}},
        .compatibility = .{ .dynamic_rendering = .{ .color = &.{.b8g8r8a8_srgb} } },
    });
    try std.testing.expect(graphics_result == .success);
    try std.testing.expect(test_graphics_has_rendering);
    switch (graphics_result) {
        .success => |*value| value.deinit(),
        .compile_required => unreachable,
    }

    var render_pass = try render_passes.create(device_handle, null, .{
        .create = testCreateRenderPass,
        .create2 = null,
        .destroy = testDestroyRenderPass,
        .get_granularity = testRenderAreaGranularity,
    }, .{
        .attachments = &.{.{ .format = .b8g8r8a8_srgb, .final_layout = .color_attachment_optimal }},
        .subpasses = &.{.{ .color_attachments = &.{.{ .attachment = .{ .index = 0, .layout = .color_attachment_optimal } }} }},
    });
    defer render_pass.deinit();
    test_graphics_has_rendering = true;
    test_graphics_render_pass = null;
    test_graphics_subpass = 99;
    var legacy_result = try createGraphics(device_handle, null, dispatch, .{
        .stages = &.{.{ .stage = .vertex, .module = &module }},
        .layout = &layout,
        .color_blend_attachments = &.{.{}},
        .compatibility = .{ .render_pass = .{ .render_pass = &render_pass } },
    });
    try std.testing.expect(legacy_result == .success);
    try std.testing.expect(!test_graphics_has_rendering);
    try std.testing.expectEqual(try render_pass.rawHandle(), test_graphics_render_pass);
    try std.testing.expectEqual(@as(u32, 0), test_graphics_subpass);
    switch (legacy_result) {
        .success => |*value| value.deinit(),
        .compile_required => unreachable,
    }

    test_pipeline_result = raw.VK_PIPELINE_COMPILE_REQUIRED;
    test_pipeline_destroy_count = 0;
    const compile_result = try createCompute(device_handle, null, dispatch, valid);
    try std.testing.expect(compile_result == .compile_required);
    try std.testing.expectEqual(@as(usize, 1), test_pipeline_destroy_count);

    test_pipeline_result = raw.VK_SUCCESS;
    test_pipeline_destroy_count = 0;
    var output: [2]CreateResult = undefined;
    const invalid: ComputeOptions = .{ .stage = .{ .stage = .vertex, .module = &module }, .layout = &layout };
    try std.testing.expectError(error.InvalidOptions, createComputeBatch(
        device_handle,
        null,
        dispatch,
        &.{ valid, invalid },
        &output,
    ));
    try std.testing.expectEqual(@as(usize, 1), test_pipeline_destroy_count);
}
