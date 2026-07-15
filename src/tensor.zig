//! Typed `VK_ARM_tensors` ownership, memory, views, and copy commands.

const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const memory = @import("memory.zig");
const commands = @import("command_buffer.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const TensorHandle = core.NonNullHandle(raw.VkTensorARM);
const ViewHandle = core.NonNullHandle(raw.VkTensorViewARM);
pub const dimension_count_max = 16;
pub const queue_family_count_max = 64;
pub const copy_region_count_max = 64;

pub const Tiling = enum(raw.VkTensorTilingARM) {
    optimal = raw.VK_TENSOR_TILING_OPTIMAL_ARM,
    linear = raw.VK_TENSOR_TILING_LINEAR_ARM,
    brick_16_wide = raw.VK_TENSOR_TILING_BRICK_16_WIDE_ARM,
    brick_8_wide = raw.VK_TENSOR_TILING_BRICK_8_WIDE_ARM,
    brick_4_wide = raw.VK_TENSOR_TILING_BRICK_4_WIDE_ARM,
    block_u_interleaved = raw.VK_TENSOR_TILING_BLOCK_U_INTERLEAVED_ARM,
    block_u_interleaved_64k = raw.VK_TENSOR_TILING_BLOCK_U_INTERLEAVED_64K_ARM,
    _,
};

pub const Usage = enum(raw.VkTensorUsageFlagsARM) {
    shader = raw.VK_TENSOR_USAGE_SHADER_BIT_ARM,
    transfer_source = raw.VK_TENSOR_USAGE_TRANSFER_SRC_BIT_ARM,
    transfer_destination = raw.VK_TENSOR_USAGE_TRANSFER_DST_BIT_ARM,
    image_aliasing = raw.VK_TENSOR_USAGE_IMAGE_ALIASING_BIT_ARM,
    data_graph = raw.VK_TENSOR_USAGE_DATA_GRAPH_BIT_ARM,
    _,
};

pub const UsageFlags = types.Flags(raw.VkTensorUsageFlagsARM, Usage);

pub const Description = struct {
    tiling: Tiling = .optimal,
    format: types.Format,
    dimensions: []const i64,
    strides: ?[]const i64 = null,
    usage: UsageFlags,

    fn validate(description: Description) core.Error!void {
        if (description.dimensions.len == 0 or description.dimensions.len > dimension_count_max) return error.InvalidOptions;
        if (description.strides) |strides| if (strides.len != description.dimensions.len) return error.InvalidOptions;
        for (description.dimensions) |dimension| if (dimension <= 0) return error.InvalidOptions;
    }
};

pub const Options = struct {
    description: Description,
    queue_family_indices: []const core.QueueFamilyIndex = &.{},
};

pub const Context = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _create: ?CommandFunction(raw.PFN_vkCreateTensorARM),
    _destroy: ?CommandFunction(raw.PFN_vkDestroyTensorARM),
    _create_view: ?CommandFunction(raw.PFN_vkCreateTensorViewARM),
    _destroy_view: ?CommandFunction(raw.PFN_vkDestroyTensorViewARM),
    _requirements: ?CommandFunction(raw.PFN_vkGetTensorMemoryRequirementsARM),
    _bind: ?CommandFunction(raw.PFN_vkBindTensorMemoryARM),
    _copy: ?CommandFunction(raw.PFN_vkCmdCopyTensorARM),

    pub fn create(context: Context, options: Options) core.Error!Tensor {
        try options.description.validate();
        if (options.queue_family_indices.len > queue_family_count_max or options.queue_family_indices.len == 1) return error.InvalidOptions;
        var queue_indices: [queue_family_count_max]u32 = undefined;
        for (options.queue_family_indices, 0..) |family, index| {
            for (options.queue_family_indices[0..index]) |previous| if (family == previous) return error.InvalidOptions;
            queue_indices[index] = family.toRaw();
        }
        const description: raw.VkTensorDescriptionARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_TENSOR_DESCRIPTION_ARM,
            .tiling = @intFromEnum(options.description.tiling),
            .format = options.description.format.toRaw(),
            .dimensionCount = @intCast(options.description.dimensions.len),
            .pDimensions = options.description.dimensions.ptr,
            .pStrides = if (options.description.strides) |strides| strides.ptr else null,
            .usage = options.description.usage.toRaw(),
        };
        const info: raw.VkTensorCreateInfoARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_TENSOR_CREATE_INFO_ARM,
            .pDescription = &description,
            .sharingMode = if (options.queue_family_indices.len == 0) raw.VK_SHARING_MODE_EXCLUSIVE else raw.VK_SHARING_MODE_CONCURRENT,
            .queueFamilyIndexCount = @intCast(options.queue_family_indices.len),
            .pQueueFamilyIndices = if (options.queue_family_indices.len == 0) null else queue_indices[0..options.queue_family_indices.len].ptr,
        };
        const create_fn = context._create orelse return error.MissingCommand;
        const destroy_fn = context._destroy orelse return error.MissingCommand;
        const requirements_fn = context._requirements orelse return error.MissingCommand;
        const bind_fn = context._bind orelse return error.MissingCommand;
        var handle: raw.VkTensorARM = null;
        const result = create_fn(context._device, &info, context._allocation_callbacks, &handle);
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional| destroy_fn(context._device, provisional, context._allocation_callbacks);
            try core.checkSuccessTracked(@constCast(context._state), result);
            unreachable;
        }
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._owner = try .init(&handle),
            ._device = context._device,
            ._state = context._state.*,
            ._allocation_callbacks = context._allocation_callbacks,
            ._destroy = destroy_fn,
            ._requirements = requirements_fn,
            ._bind = bind_fn,
            ._create_view = context._create_view,
            ._destroy_view = context._destroy_view,
        };
    }

    pub fn recorder(context: Context) Recorder {
        return .{ ._device = context._device, ._state = context._state, ._copy = context._copy };
    }
};

pub const Tensor = struct {
    _handle: ?TensorHandle,
    _owner: core.Owner,
    _device: DeviceHandle,
    _state: core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _destroy: CommandFunction(raw.PFN_vkDestroyTensorARM),
    _requirements: CommandFunction(raw.PFN_vkGetTensorMemoryRequirementsARM),
    _bind: CommandFunction(raw.PFN_vkBindTensorMemoryARM),
    _create_view: ?CommandFunction(raw.PFN_vkCreateTensorViewARM),
    _destroy_view: ?CommandFunction(raw.PFN_vkDestroyTensorViewARM),

    pub fn deinit(tensor: *Tensor) void {
        if (!(tensor._owner.release(tensor) catch return)) return;
        const handle = tensor._handle orelse return;
        tensor._destroy(tensor._device, handle, tensor._allocation_callbacks);
        tensor._handle = null;
    }

    pub fn rawHandle(tensor: *const Tensor) core.Error!raw.VkTensorARM {
        try tensor._owner.validate(tensor);
        try tensor._state.ensureDispatchAllowed();
        return tensor._handle orelse error.InactiveObject;
    }

    pub fn memoryRequirements(tensor: *const Tensor) core.Error!memory.Requirements {
        const info: raw.VkTensorMemoryRequirementsInfoARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_TENSOR_MEMORY_REQUIREMENTS_INFO_ARM,
            .tensor = try tensor.rawHandle(),
        };
        var value: raw.VkMemoryRequirements2 = .{ .sType = raw.VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2 };
        tensor._requirements(tensor._device, &info, &value);
        return .fromRaw(value.memoryRequirements);
    }

    pub fn bindMemory(tensor: *const Tensor, allocation: *const memory.Allocation, offset: core.DeviceOffset) core.Error!void {
        if (allocation._device_handle != tensor._device) return error.InvalidHandle;
        const requirements = try tensor.memoryRequirements();
        if (offset.bytes() % requirements.alignment.bytes() != 0 or offset.bytes() > allocation.size.bytes() or requirements.size.bytes() > allocation.size.bytes() - offset.bytes()) return error.InvalidOptions;
        const info: raw.VkBindTensorMemoryInfoARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_BIND_TENSOR_MEMORY_INFO_ARM,
            .tensor = try tensor.rawHandle(),
            .memory = try allocation.rawHandle(),
            .memoryOffset = offset.bytes(),
        };
        try core.checkSuccessOptional(@constCast(&tensor._state), tensor._bind(tensor._device, 1, &info));
    }

    pub fn createView(tensor: *const Tensor, format: types.Format) core.Error!View {
        const create_fn = tensor._create_view orelse return error.MissingCommand;
        const destroy_fn = tensor._destroy_view orelse return error.MissingCommand;
        const info: raw.VkTensorViewCreateInfoARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_TENSOR_VIEW_CREATE_INFO_ARM,
            .tensor = try tensor.rawHandle(),
            .format = format.toRaw(),
        };
        var handle: raw.VkTensorViewARM = null;
        const result = create_fn(tensor._device, &info, tensor._allocation_callbacks, &handle);
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional| destroy_fn(tensor._device, provisional, tensor._allocation_callbacks);
            try core.checkSuccessOptional(@constCast(&tensor._state), result);
            unreachable;
        }
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._owner = try .init(&handle),
            ._tensor_owner = tensor._owner.borrow(),
            ._device = tensor._device,
            ._state = tensor._state,
            ._allocation_callbacks = tensor._allocation_callbacks,
            ._destroy = destroy_fn,
        };
    }
};

pub const View = struct {
    _handle: ?ViewHandle,
    _owner: core.Owner,
    _tensor_owner: core.Owner.Borrow,
    _device: DeviceHandle,
    _state: core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _destroy: CommandFunction(raw.PFN_vkDestroyTensorViewARM),

    pub fn deinit(view: *View) void {
        if (!(view._owner.release(view) catch return)) return;
        const handle = view._handle orelse return;
        view._destroy(view._device, handle, view._allocation_callbacks);
        view._handle = null;
    }

    pub fn rawHandle(view: *const View) core.Error!raw.VkTensorViewARM {
        try view._owner.validate(view);
        try view._tensor_owner.validate();
        try view._state.ensureDispatchAllowed();
        return view._handle orelse error.InactiveObject;
    }
};

pub const CopyRegion = struct {
    source_offset: []const u64,
    destination_offset: []const u64,
    extent: []const u64,
};

pub const Recorder = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _copy: ?CommandFunction(raw.PFN_vkCmdCopyTensorARM),

    pub fn copy(recorder: Recorder, command_buffer: *commands.Buffer, source: *const Tensor, destination: *const Tensor, regions: []const CopyRegion) core.Error!void {
        if (command_buffer._device_handle != recorder._device or source._device != recorder._device or destination._device != recorder._device) return error.InvalidHandle;
        if (regions.len == 0 or regions.len > copy_region_count_max) return error.InvalidOptions;
        var values: [copy_region_count_max]raw.VkTensorCopyARM = undefined;
        for (regions, values[0..regions.len]) |region, *value| {
            if (region.extent.len == 0 or region.extent.len > dimension_count_max or region.source_offset.len != region.extent.len or region.destination_offset.len != region.extent.len) return error.InvalidOptions;
            value.* = .{
                .sType = raw.VK_STRUCTURE_TYPE_TENSOR_COPY_ARM,
                .dimensionCount = @intCast(region.extent.len),
                .pSrcOffset = region.source_offset.ptr,
                .pDstOffset = region.destination_offset.ptr,
                .pExtent = region.extent.ptr,
            };
        }
        const copy_fn = recorder._copy orelse return error.MissingCommand;
        const info: raw.VkCopyTensorInfoARM = .{
            .sType = raw.VK_STRUCTURE_TYPE_COPY_TENSOR_INFO_ARM,
            .srcTensor = try source.rawHandle(),
            .dstTensor = try destination.rawHandle(),
            .regionCount = @intCast(regions.len),
            .pRegions = values[0..regions.len].ptr,
        };
        try recorder._state.ensureDispatchAllowed();
        copy_fn(try command_buffer.rawHandle(), &info);
    }
};

var test_destroy_count: u32 = 0;

fn testCreateFailure(
    _: raw.VkDevice,
    _: [*c]const raw.VkTensorCreateInfoARM,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkTensorARM,
) callconv(.c) raw.VkResult {
    output[0] = @ptrFromInt(0x2000);
    return raw.VK_ERROR_OUT_OF_DEVICE_MEMORY;
}

fn testDestroy(_: raw.VkDevice, _: raw.VkTensorARM, _: [*c]const raw.VkAllocationCallbacks) callconv(.c) void {
    test_destroy_count += 1;
}

fn testRequirements(_: raw.VkDevice, _: [*c]const raw.VkTensorMemoryRequirementsInfoARM, _: [*c]raw.VkMemoryRequirements2) callconv(.c) void {}

fn testBind(_: raw.VkDevice, _: u32, _: [*c]const raw.VkBindTensorMemoryInfoARM) callconv(.c) raw.VkResult {
    return raw.VK_SUCCESS;
}

test "tensor descriptions reject mismatched strides" {
    std.testing.refAllDecls(@This());
    const description: Description = .{
        .format = .r32_sfloat,
        .dimensions = &.{ 4, 4 },
        .strides = &.{4},
        .usage = .init(&.{.shader}),
    };
    try std.testing.expectError(error.InvalidOptions, description.validate());
    var context: Context = undefined;
    try std.testing.expectError(error.InvalidOptions, context.create(.{ .description = .{
        .format = .r32_sfloat,
        .dimensions = &.{},
        .usage = .init(&.{.shader}),
    } }));
}

test "tensor creation rolls back provisional handles" {
    var state = try core.DeviceState.init();
    const context: Context = .{
        ._device = @ptrFromInt(0x1000),
        ._state = &state,
        ._allocation_callbacks = null,
        ._create = testCreateFailure,
        ._destroy = testDestroy,
        ._create_view = null,
        ._destroy_view = null,
        ._requirements = testRequirements,
        ._bind = testBind,
        ._copy = null,
    };
    test_destroy_count = 0;
    try std.testing.expectError(error.OutOfDeviceMemory, context.create(.{ .description = .{
        .format = .r32_sfloat,
        .dimensions = &.{4},
        .usage = .init(&.{.shader}),
    } }));
    try std.testing.expectEqual(@as(u32, 1), test_destroy_count);
}
