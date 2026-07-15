//! Focused `VK_ARM_data_graph` pipeline/session lifecycle and dispatch support.

const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const shader = @import("shader.zig");
const pipelines = @import("pipeline.zig");
const memory = @import("memory.zig");
const commands = @import("command_buffer.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const PipelineHandle = core.NonNullHandle(raw.VkPipeline);
const SessionHandle = core.NonNullHandle(raw.VkDataGraphPipelineSessionARM);
pub const resource_count_max = 64;
pub const constant_count_max = 64;
pub const bind_point_count_max = 32;

pub const Resource = struct { descriptor_set: u32, binding: u32, array_element: u32 = 0 };
pub const Constant = struct { id: u32, bytes: []const u8 };

pub const PipelineOptions = struct {
    layout: *const pipelines.Layout,
    shader: *const shader.Module,
    entry_point: [:0]const u8 = "main",
    resources: []const Resource = &.{},
    constants: []const Constant = &.{},
};

pub const Pipeline = struct {
    _handle: ?PipelineHandle,
    _owner: core.Owner,
    _device: DeviceHandle,
    _state: core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _destroy: CommandFunction(raw.PFN_vkDestroyPipeline),

    pub fn deinit(pipeline: *Pipeline) void {
        if (!(pipeline._owner.release(pipeline) catch return)) return;
        const handle = pipeline._handle orelse return;
        pipeline._destroy(pipeline._device, handle, pipeline._allocation_callbacks);
        pipeline._handle = null;
    }

    pub fn rawHandle(pipeline: *const Pipeline) core.Error!raw.VkPipeline {
        try pipeline._owner.validate(pipeline);
        try pipeline._state.ensureDispatchAllowed();
        return pipeline._handle orelse error.InactiveObject;
    }
};

pub const PipelineCreateResult = union(enum) { success: Pipeline, compile_required };

pub const BindPoint = enum(raw.VkDataGraphPipelineSessionBindPointARM) {
    transient = raw.VK_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_TRANSIENT_ARM,
    optical_flow_cache = raw.VK_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_OPTICAL_FLOW_CACHE_ARM,
    neural_accelerator_statistics = raw.VK_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_NEURAL_ACCELERATOR_STATISTICS_ARM,
    _,
};

pub const BindPointRequirement = struct { point: BindPoint, object_count: u32 };

pub const Session = struct {
    _handle: ?SessionHandle,
    _owner: core.Owner,
    _pipeline_owner: core.Owner.Borrow,
    _device: DeviceHandle,
    _state: core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _destroy: CommandFunction(raw.PFN_vkDestroyDataGraphPipelineSessionARM),
    _requirements: CommandFunction(raw.PFN_vkGetDataGraphPipelineSessionBindPointRequirementsARM),
    _memory_requirements: CommandFunction(raw.PFN_vkGetDataGraphPipelineSessionMemoryRequirementsARM),
    _bind: CommandFunction(raw.PFN_vkBindDataGraphPipelineSessionMemoryARM),

    pub fn deinit(session: *Session) void {
        if (!(session._owner.release(session) catch return)) return;
        const handle = session._handle orelse return;
        session._destroy(session._device, handle, session._allocation_callbacks);
        session._handle = null;
    }

    pub fn rawHandle(session: *const Session) core.Error!raw.VkDataGraphPipelineSessionARM {
        try session._owner.validate(session);
        try session._pipeline_owner.validate();
        try session._state.ensureDispatchAllowed();
        return session._handle orelse error.InactiveObject;
    }

    pub fn bindPointRequirementCount(session: *const Session) core.Error!u32 {
        const info: raw.VkDataGraphPipelineSessionBindPointRequirementsInfoARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_REQUIREMENTS_INFO_ARM,
            .session = try session.rawHandle(),
        };
        var count: u32 = 0;
        const result = session._requirements(session._device, &info, &count, null);
        if (result != raw.VK_SUCCESS and result != raw.VK_INCOMPLETE) try core.checkSuccessOptional(@constCast(&session._state), result);
        if (count > bind_point_count_max) return error.CountOverflow;
        return count;
    }

    pub fn bindPointRequirementsInto(session: *const Session, output: []BindPointRequirement) core.Error![]BindPointRequirement {
        if (output.len > bind_point_count_max) return error.CountOverflow;
        const info: raw.VkDataGraphPipelineSessionBindPointRequirementsInfoARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_REQUIREMENTS_INFO_ARM,
            .session = try session.rawHandle(),
        };
        var values: [bind_point_count_max]raw.VkDataGraphPipelineSessionBindPointRequirementARM = undefined;
        for (values[0..output.len]) |*value| value.* = .{ .sType = raw.VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_REQUIREMENT_ARM };
        var count: u32 = @intCast(output.len);
        const result = session._requirements(session._device, &info, &count, if (output.len == 0) null else &values);
        if (result == raw.VK_INCOMPLETE or count > output.len) return error.BufferTooSmall;
        try core.checkSuccessOptional(@constCast(&session._state), result);
        for (output[0..count], values[0..count]) |*item, value| {
            if (value.bindPointType != raw.VK_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_TYPE_MEMORY_ARM) return error.UnsupportedOperation;
            item.* = .{ .point = @enumFromInt(value.bindPoint), .object_count = value.numObjects };
        }
        return output[0..count];
    }

    pub fn bindPointRequirements(session: *const Session, gpa: std.mem.Allocator) (core.Error || std.mem.Allocator.Error)![]BindPointRequirement {
        const output = try gpa.alloc(BindPointRequirement, try session.bindPointRequirementCount());
        errdefer gpa.free(output);
        const written = try session.bindPointRequirementsInto(output);
        return gpa.realloc(output, written.len);
    }

    pub fn memoryRequirements(session: *const Session, point: BindPoint, object_index: u32) core.Error!memory.Requirements {
        const info: raw.VkDataGraphPipelineSessionMemoryRequirementsInfoARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_MEMORY_REQUIREMENTS_INFO_ARM,
            .session = try session.rawHandle(),
            .bindPoint = @intFromEnum(point),
            .objectIndex = object_index,
        };
        var value: raw.VkMemoryRequirements2 = .{ .sType = raw.VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2 };
        session._memory_requirements(session._device, &info, &value);
        return .fromRaw(value.memoryRequirements);
    }

    pub fn bindMemory(session: *const Session, point: BindPoint, object_index: u32, allocation: *const memory.Allocation, offset: core.DeviceOffset) core.Error!void {
        if (allocation._device_handle != session._device) return error.InvalidHandle;
        const requirements = try session.memoryRequirements(point, object_index);
        if (offset.bytes() % requirements.alignment.bytes() != 0 or offset.bytes() > allocation.size.bytes() or requirements.size.bytes() > allocation.size.bytes() - offset.bytes()) return error.InvalidOptions;
        const info: raw.VkBindDataGraphPipelineSessionMemoryInfoARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_BIND_DATA_GRAPH_PIPELINE_SESSION_MEMORY_INFO_ARM,
            .session = try session.rawHandle(),
            .bindPoint = @intFromEnum(point),
            .objectIndex = object_index,
            .memory = try allocation.rawHandle(),
            .memoryOffset = offset.bytes(),
        };
        try core.checkSuccessOptional(@constCast(&session._state), session._bind(session._device, 1, &info));
    }
};

pub const Context = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _create_pipeline: ?CommandFunction(raw.PFN_vkCreateDataGraphPipelinesARM),
    _destroy_pipeline: CommandFunction(raw.PFN_vkDestroyPipeline),
    _create_session: ?CommandFunction(raw.PFN_vkCreateDataGraphPipelineSessionARM),
    _destroy_session: ?CommandFunction(raw.PFN_vkDestroyDataGraphPipelineSessionARM),
    _requirements: ?CommandFunction(raw.PFN_vkGetDataGraphPipelineSessionBindPointRequirementsARM),
    _memory_requirements: ?CommandFunction(raw.PFN_vkGetDataGraphPipelineSessionMemoryRequirementsARM),
    _bind: ?CommandFunction(raw.PFN_vkBindDataGraphPipelineSessionMemoryARM),
    _dispatch: ?CommandFunction(raw.PFN_vkCmdDispatchDataGraphARM),

    pub fn createPipeline(context: Context, options: PipelineOptions) core.Error!PipelineCreateResult {
        if (options.layout._device_handle != context._device or options.shader._device_handle != context._device) return error.InvalidHandle;
        if (options.resources.len > resource_count_max or options.constants.len > constant_count_max) return error.CountOverflow;
        var resources: [resource_count_max]raw.VkDataGraphPipelineResourceInfoARM = undefined;
        for (options.resources, resources[0..options.resources.len]) |item, *value| value.* = .{
            .sType = raw.VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_RESOURCE_INFO_ARM,
            .descriptorSet = item.descriptor_set,
            .binding = item.binding,
            .arrayElement = item.array_element,
        };
        var constants: [constant_count_max]raw.VkDataGraphPipelineConstantARM = undefined;
        for (options.constants, constants[0..options.constants.len]) |item, *value| {
            if (item.bytes.len == 0) return error.InvalidOptions;
            value.* = .{ .sType = raw.VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_CONSTANT_ARM, .id = item.id, .pConstantData = item.bytes.ptr };
        }
        const shader_info: raw.VkDataGraphPipelineShaderModuleCreateInfoARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SHADER_MODULE_CREATE_INFO_ARM,
            .module = try options.shader.rawHandle(),
            .pName = options.entry_point.ptr,
            .constantCount = @intCast(options.constants.len),
            .pConstants = if (options.constants.len == 0) null else constants[0..options.constants.len].ptr,
        };
        const info: raw.VkDataGraphPipelineCreateInfoARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_CREATE_INFO_ARM,
            .pNext = &shader_info,
            .layout = try options.layout.rawHandle(),
            .resourceInfoCount = @intCast(options.resources.len),
            .pResourceInfos = if (options.resources.len == 0) null else resources[0..options.resources.len].ptr,
        };
        const create_fn = context._create_pipeline orelse return error.MissingCommand;
        var handle: raw.VkPipeline = null;
        const result = create_fn(context._device, null, null, 1, &info, context._allocation_callbacks, &handle);
        if (result == raw.VK_PIPELINE_COMPILE_REQUIRED_EXT) return .compile_required;
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional| context._destroy_pipeline(context._device, provisional, context._allocation_callbacks);
            try core.checkSuccessTracked(@constCast(context._state), result);
            unreachable;
        }
        return .{ .success = .{
            ._handle = handle orelse return error.InvalidHandle,
            ._owner = try .init(&handle),
            ._device = context._device,
            ._state = context._state.*,
            ._allocation_callbacks = context._allocation_callbacks,
            ._destroy = context._destroy_pipeline,
        } };
    }

    pub fn createSession(context: Context, pipeline: *const Pipeline) core.Error!Session {
        if (pipeline._device != context._device) return error.InvalidHandle;
        const create_fn = context._create_session orelse return error.MissingCommand;
        const destroy_fn = context._destroy_session orelse return error.MissingCommand;
        const requirements_fn = context._requirements orelse return error.MissingCommand;
        const memory_requirements_fn = context._memory_requirements orelse return error.MissingCommand;
        const bind_fn = context._bind orelse return error.MissingCommand;
        const info: raw.VkDataGraphPipelineSessionCreateInfoARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_SESSION_CREATE_INFO_ARM,
            .dataGraphPipeline = try pipeline.rawHandle(),
        };
        var handle: raw.VkDataGraphPipelineSessionARM = null;
        const result = create_fn(context._device, &info, context._allocation_callbacks, &handle);
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional| destroy_fn(context._device, provisional, context._allocation_callbacks);
            try core.checkSuccessTracked(@constCast(context._state), result);
            unreachable;
        }
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._owner = try .init(&handle),
            ._pipeline_owner = pipeline._owner.borrow(),
            ._device = context._device,
            ._state = context._state.*,
            ._allocation_callbacks = context._allocation_callbacks,
            ._destroy = destroy_fn,
            ._requirements = requirements_fn,
            ._memory_requirements = memory_requirements_fn,
            ._bind = bind_fn,
        };
    }

    pub fn dispatch(context: Context, command_buffer: *commands.Buffer, session: *const Session) core.Error!void {
        if (command_buffer._device_handle != context._device or session._device != context._device) return error.InvalidHandle;
        const dispatch_fn = context._dispatch orelse return error.MissingCommand;
        var info: raw.VkDataGraphPipelineDispatchInfoARM = .{ .sType = raw.VK_STRUCTURE_TYPE_DATA_GRAPH_PIPELINE_DISPATCH_INFO_ARM };
        dispatch_fn(try command_buffer.rawHandle(), try session.rawHandle(), &info);
    }
};

fn testCreateCompileRequired(
    _: raw.VkDevice,
    _: raw.VkDeferredOperationKHR,
    _: raw.VkPipelineCache,
    _: u32,
    _: [*c]const raw.VkDataGraphPipelineCreateInfoARM,
    _: [*c]const raw.VkAllocationCallbacks,
    _: [*c]raw.VkPipeline,
) callconv(.c) raw.VkResult {
    return raw.VK_PIPELINE_COMPILE_REQUIRED_EXT;
}

fn testDestroyPipeline(_: raw.VkDevice, _: raw.VkPipeline, _: [*c]const raw.VkAllocationCallbacks) callconv(.c) void {}

test "data graph vocabulary remains typed" {
    std.testing.refAllDecls(@This());
    try std.testing.expectEqual(@as(raw.VkDataGraphPipelineSessionBindPointARM, raw.VK_DATA_GRAPH_PIPELINE_SESSION_BIND_POINT_TRANSIENT_ARM), @intFromEnum(BindPoint.transient));
    var context: Context = undefined;
    context._device = @ptrFromInt(0x1000);
    var layout: pipelines.Layout = undefined;
    layout._device_handle = @ptrFromInt(0x2000);
    var module: shader.Module = undefined;
    module._device_handle = @ptrFromInt(0x2000);
    try std.testing.expectError(error.InvalidHandle, context.createPipeline(.{
        .layout = &layout,
        .shader = &module,
    }));
}

test "data graph preserves compile-required status" {
    const device: DeviceHandle = @ptrFromInt(0x1000);
    var layout_handle: raw.VkPipelineLayout = @ptrFromInt(0x2000);
    var layout: pipelines.Layout = undefined;
    layout._handle = layout_handle.?;
    layout._owner = try .init(&layout_handle);
    layout._device_handle = device;
    layout._device_state = null;
    var shader_handle: raw.VkShaderModule = @ptrFromInt(0x3000);
    var module: shader.Module = undefined;
    module._handle = shader_handle.?;
    module._owner = try .init(&shader_handle);
    module._device_handle = device;
    module._device_state = null;
    var state = try core.DeviceState.init();
    var context: Context = undefined;
    context._device = device;
    context._state = &state;
    context._allocation_callbacks = null;
    context._create_pipeline = testCreateCompileRequired;
    context._destroy_pipeline = testDestroyPipeline;
    const result = try context.createPipeline(.{ .layout = &layout, .shader = &module });
    try std.testing.expect(result == .compile_required);
}
