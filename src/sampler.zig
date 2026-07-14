const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const SamplerHandle = core.NonNullHandle(raw.VkSampler);
const ConversionHandle = core.NonNullHandle(raw.VkSamplerYcbcrConversion);

pub const Filter = enum {
    nearest,
    linear,
    cubic,

    pub fn toRaw(value: Filter) raw.VkFilter {
        return switch (value) {
            .nearest => raw.VK_FILTER_NEAREST,
            .linear => raw.VK_FILTER_LINEAR,
            .cubic => raw.VK_FILTER_CUBIC_EXT,
        };
    }
};

pub const MipmapMode = enum {
    nearest,
    linear,

    fn toRaw(value: MipmapMode) raw.VkSamplerMipmapMode {
        return switch (value) {
            .nearest => raw.VK_SAMPLER_MIPMAP_MODE_NEAREST,
            .linear => raw.VK_SAMPLER_MIPMAP_MODE_LINEAR,
        };
    }
};

pub const AddressMode = enum {
    repeat,
    mirrored_repeat,
    clamp_to_edge,
    clamp_to_border,
    mirror_clamp_to_edge,

    fn toRaw(value: AddressMode) raw.VkSamplerAddressMode {
        return switch (value) {
            .repeat => raw.VK_SAMPLER_ADDRESS_MODE_REPEAT,
            .mirrored_repeat => raw.VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT,
            .clamp_to_edge => raw.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            .clamp_to_border => raw.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
            .mirror_clamp_to_edge => raw.VK_SAMPLER_ADDRESS_MODE_MIRROR_CLAMP_TO_EDGE,
        };
    }
};

pub const CompareOperation = enum {
    never,
    less,
    equal,
    less_or_equal,
    greater,
    not_equal,
    greater_or_equal,
    always,

    pub fn toRaw(value: CompareOperation) raw.VkCompareOp {
        return switch (value) {
            .never => raw.VK_COMPARE_OP_NEVER,
            .less => raw.VK_COMPARE_OP_LESS,
            .equal => raw.VK_COMPARE_OP_EQUAL,
            .less_or_equal => raw.VK_COMPARE_OP_LESS_OR_EQUAL,
            .greater => raw.VK_COMPARE_OP_GREATER,
            .not_equal => raw.VK_COMPARE_OP_NOT_EQUAL,
            .greater_or_equal => raw.VK_COMPARE_OP_GREATER_OR_EQUAL,
            .always => raw.VK_COMPARE_OP_ALWAYS,
        };
    }
};

pub const ReductionMode = enum {
    weighted_average,
    minimum,
    maximum,

    fn toRaw(value: ReductionMode) raw.VkSamplerReductionMode {
        return switch (value) {
            .weighted_average => raw.VK_SAMPLER_REDUCTION_MODE_WEIGHTED_AVERAGE,
            .minimum => raw.VK_SAMPLER_REDUCTION_MODE_MIN,
            .maximum => raw.VK_SAMPLER_REDUCTION_MODE_MAX,
        };
    }
};

pub const BorderColor = union(enum) {
    transparent_black_float,
    transparent_black_int,
    opaque_black_float,
    opaque_black_int,
    opaque_white_float,
    opaque_white_int,
    custom_float: struct { value: [4]f32, format: types.Format },
    custom_int: struct { value: [4]i32, format: types.Format },

    fn rawKind(value: BorderColor) raw.VkBorderColor {
        return switch (value) {
            .transparent_black_float => raw.VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK,
            .transparent_black_int => raw.VK_BORDER_COLOR_INT_TRANSPARENT_BLACK,
            .opaque_black_float => raw.VK_BORDER_COLOR_FLOAT_OPAQUE_BLACK,
            .opaque_black_int => raw.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
            .opaque_white_float => raw.VK_BORDER_COLOR_FLOAT_OPAQUE_WHITE,
            .opaque_white_int => raw.VK_BORDER_COLOR_INT_OPAQUE_WHITE,
            .custom_float => raw.VK_BORDER_COLOR_FLOAT_CUSTOM_EXT,
            .custom_int => raw.VK_BORDER_COLOR_INT_CUSTOM_EXT,
        };
    }
};

pub const Options = struct {
    mag_filter: Filter = .linear,
    min_filter: Filter = .linear,
    mipmap_mode: MipmapMode = .linear,
    address_u: AddressMode = .repeat,
    address_v: AddressMode = .repeat,
    address_w: AddressMode = .repeat,
    mip_lod_bias: f32 = 0,
    anisotropy: ?f32 = null,
    compare: ?CompareOperation = null,
    min_lod: f32 = 0,
    max_lod: f32 = 0,
    border_color: BorderColor = .transparent_black_float,
    unnormalized_coordinates: bool = false,
    reduction: ?ReductionMode = null,
    ycbcr_conversion: ?*const YcbcrConversion = null,

    pub fn validate(options: Options) core.Error!void {
        if (!std.math.isFinite(options.mip_lod_bias) or
            !std.math.isFinite(options.min_lod) or
            !std.math.isFinite(options.max_lod) or
            options.min_lod > options.max_lod)
        {
            return error.InvalidOptions;
        }
        if (options.anisotropy) |value| {
            if (!std.math.isFinite(value) or value < 1) return error.InvalidOptions;
        }
        if (options.unnormalized_coordinates) {
            if (options.mag_filter != options.min_filter or options.mipmap_mode != .nearest or options.min_lod != 0 or options.max_lod != 0 or
                options.anisotropy != null or options.compare != null)
            {
                return error.InvalidOptions;
            }
            if (options.address_u != .clamp_to_edge and options.address_u != .clamp_to_border) return error.InvalidOptions;
            if (options.address_v != .clamp_to_edge and options.address_v != .clamp_to_border) return error.InvalidOptions;
        }
    }
};

pub const Dispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateSampler),
    destroy: CommandFunction(raw.PFN_vkDestroySampler),
};

pub const Sampler = struct {
    _handle: ?SamplerHandle,
    _device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_sampler: CommandFunction(raw.PFN_vkDestroySampler),

    pub fn deinit(sampler: *Sampler) void {
        const handle = sampler._handle orelse return;
        sampler.destroy_sampler(sampler._device_handle, handle, sampler.allocation_callbacks);
        sampler._handle = null;
    }

    pub fn rawHandle(sampler: *const Sampler) core.Error!raw.VkSampler {
        return sampler._handle orelse error.InactiveObject;
    }

    pub fn debugObject(sampler: *const Sampler) core.Error!debug_utils.Object {
        return .forDevice(.sampler, try sampler.rawHandle(), sampler._device_handle);
    }
};

pub fn create(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,
    options: Options,
) core.Error!Sampler {
    try options.validate();
    var custom: raw.VkSamplerCustomBorderColorCreateInfoEXT = .{
        .sType = raw.VK_STRUCTURE_TYPE_SAMPLER_CUSTOM_BORDER_COLOR_CREATE_INFO_EXT,
    };
    const has_custom = switch (options.border_color) {
        .custom_float => |value| blk: {
            custom.customBorderColor.float32 = value.value;
            custom.format = value.format.toRaw();
            break :blk true;
        },
        .custom_int => |value| blk: {
            custom.customBorderColor.int32 = value.value;
            custom.format = value.format.toRaw();
            break :blk true;
        },
        else => false,
    };
    var reduction: raw.VkSamplerReductionModeCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_SAMPLER_REDUCTION_MODE_CREATE_INFO,
        .reductionMode = if (options.reduction) |value| value.toRaw() else raw.VK_SAMPLER_REDUCTION_MODE_WEIGHTED_AVERAGE,
    };
    var conversion_info: raw.VkSamplerYcbcrConversionInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_SAMPLER_YCBCR_CONVERSION_INFO,
    };
    if (options.ycbcr_conversion) |conversion| {
        if (conversion._device_handle != device_handle) return error.InvalidHandle;
        conversion_info.conversion = try conversion.rawHandle();
    }
    var next: ?*const anyopaque = null;
    if (options.ycbcr_conversion != null) {
        conversion_info.pNext = next;
        next = &conversion_info;
    }
    if (has_custom) {
        custom.pNext = next;
        next = &custom;
    }
    if (options.reduction != null) {
        reduction.pNext = next;
        next = &reduction;
    }
    const info: raw.VkSamplerCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .pNext = next,
        .magFilter = options.mag_filter.toRaw(),
        .minFilter = options.min_filter.toRaw(),
        .mipmapMode = options.mipmap_mode.toRaw(),
        .addressModeU = options.address_u.toRaw(),
        .addressModeV = options.address_v.toRaw(),
        .addressModeW = options.address_w.toRaw(),
        .mipLodBias = options.mip_lod_bias,
        .anisotropyEnable = if (options.anisotropy != null) raw.VK_TRUE else raw.VK_FALSE,
        .maxAnisotropy = options.anisotropy orelse 1,
        .compareEnable = if (options.compare != null) raw.VK_TRUE else raw.VK_FALSE,
        .compareOp = if (options.compare) |value| value.toRaw() else raw.VK_COMPARE_OP_ALWAYS,
        .minLod = options.min_lod,
        .maxLod = options.max_lod,
        .borderColor = options.border_color.rawKind(),
        .unnormalizedCoordinates = if (options.unnormalized_coordinates) raw.VK_TRUE else raw.VK_FALSE,
    };
    var handle: raw.VkSampler = null;
    const result = dispatch.create(device_handle, &info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccess(result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._device_handle = device_handle,
        .allocation_callbacks = allocation_callbacks,
        .destroy_sampler = dispatch.destroy,
    };
}

pub const YcbcrModel = enum {
    rgb_identity,
    ycbcr_identity,
    ycbcr_709,
    ycbcr_601,
    ycbcr_2020,

    fn toRaw(value: YcbcrModel) raw.VkSamplerYcbcrModelConversion {
        return switch (value) {
            .rgb_identity => raw.VK_SAMPLER_YCBCR_MODEL_CONVERSION_RGB_IDENTITY,
            .ycbcr_identity => raw.VK_SAMPLER_YCBCR_MODEL_CONVERSION_YCBCR_IDENTITY,
            .ycbcr_709 => raw.VK_SAMPLER_YCBCR_MODEL_CONVERSION_YCBCR_709,
            .ycbcr_601 => raw.VK_SAMPLER_YCBCR_MODEL_CONVERSION_YCBCR_601,
            .ycbcr_2020 => raw.VK_SAMPLER_YCBCR_MODEL_CONVERSION_YCBCR_2020,
        };
    }
};

pub const YcbcrRange = enum {
    full,
    narrow,

    fn toRaw(value: YcbcrRange) raw.VkSamplerYcbcrRange {
        return switch (value) {
            .full => raw.VK_SAMPLER_YCBCR_RANGE_ITU_FULL,
            .narrow => raw.VK_SAMPLER_YCBCR_RANGE_ITU_NARROW,
        };
    }
};

pub const ChromaLocation = enum {
    cosited_even,
    midpoint,

    fn toRaw(value: ChromaLocation) raw.VkChromaLocation {
        return switch (value) {
            .cosited_even => raw.VK_CHROMA_LOCATION_COSITED_EVEN,
            .midpoint => raw.VK_CHROMA_LOCATION_MIDPOINT,
        };
    }
};

pub const YcbcrOptions = struct {
    format: types.Format,
    model: YcbcrModel = .ycbcr_709,
    range: YcbcrRange = .narrow,
    components: types.ComponentMapping = .{},
    x_chroma_offset: ChromaLocation = .cosited_even,
    y_chroma_offset: ChromaLocation = .cosited_even,
    chroma_filter: Filter = .linear,
    force_explicit_reconstruction: bool = false,
};

pub const YcbcrDispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateSamplerYcbcrConversion),
    destroy: CommandFunction(raw.PFN_vkDestroySamplerYcbcrConversion),
};

pub const YcbcrConversion = struct {
    _handle: ?ConversionHandle,
    _device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_conversion: CommandFunction(raw.PFN_vkDestroySamplerYcbcrConversion),

    pub fn deinit(conversion: *YcbcrConversion) void {
        const handle = conversion._handle orelse return;
        conversion.destroy_conversion(conversion._device_handle, handle, conversion.allocation_callbacks);
        conversion._handle = null;
    }

    pub fn rawHandle(conversion: *const YcbcrConversion) core.Error!raw.VkSamplerYcbcrConversion {
        return conversion._handle orelse error.InactiveObject;
    }

    pub fn debugObject(conversion: *const YcbcrConversion) core.Error!debug_utils.Object {
        return .forDevice(.sampler_ycbcr_conversion, try conversion.rawHandle(), conversion._device_handle);
    }
};

pub fn createYcbcrConversion(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: YcbcrDispatch,
    options: YcbcrOptions,
) core.Error!YcbcrConversion {
    if (options.format == .undefined_) return error.InvalidOptions;
    const info: raw.VkSamplerYcbcrConversionCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_SAMPLER_YCBCR_CONVERSION_CREATE_INFO,
        .format = options.format.toRaw(),
        .ycbcrModel = options.model.toRaw(),
        .ycbcrRange = options.range.toRaw(),
        .components = options.components.toRaw(),
        .xChromaOffset = options.x_chroma_offset.toRaw(),
        .yChromaOffset = options.y_chroma_offset.toRaw(),
        .chromaFilter = options.chroma_filter.toRaw(),
        .forceExplicitReconstruction = if (options.force_explicit_reconstruction) raw.VK_TRUE else raw.VK_FALSE,
    };
    var handle: raw.VkSamplerYcbcrConversion = null;
    const result = dispatch.create(device_handle, &info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccess(result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._device_handle = device_handle,
        .allocation_callbacks = allocation_callbacks,
        .destroy_conversion = dispatch.destroy,
    };
}

test "all sampler declarations compile" {
    std.testing.refAllDecls(@This());
}

var test_result: raw.VkResult = raw.VK_SUCCESS;
var test_destroy_count: usize = 0;
var test_chain_count: usize = 0;

fn testCreateSampler(
    _: raw.VkDevice,
    info: [*c]const raw.VkSamplerCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkSampler,
) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x2000);
    test_chain_count = 0;
    var next = info.*.pNext;
    while (next) |pointer| {
        test_chain_count += 1;
        const base: *const raw.VkBaseInStructure = @ptrCast(@alignCast(pointer));
        next = base.pNext;
    }
    return test_result;
}

fn testDestroySampler(
    _: raw.VkDevice,
    _: raw.VkSampler,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_count += 1;
}

fn testDestroyConversion(
    _: raw.VkDevice,
    _: raw.VkSamplerYcbcrConversion,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {}

test "sampler validation, extension chains, and rollback are deterministic" {
    try (Options{}).validate();
    try std.testing.expectError(error.InvalidOptions, (Options{ .anisotropy = 0.5 }).validate());
    try std.testing.expectError(error.InvalidOptions, (Options{
        .mag_filter = .linear,
        .min_filter = .nearest,
        .mipmap_mode = .nearest,
        .address_u = .clamp_to_edge,
        .address_v = .clamp_to_edge,
        .unnormalized_coordinates = true,
    }).validate());

    const device_handle: DeviceHandle = @ptrFromInt(0x1000);
    const conversion: YcbcrConversion = .{
        ._handle = @ptrFromInt(0x3000),
        ._device_handle = device_handle,
        .allocation_callbacks = null,
        .destroy_conversion = testDestroyConversion,
    };
    var value = try create(device_handle, null, .{
        .create = testCreateSampler,
        .destroy = testDestroySampler,
    }, .{
        .compare = .less,
        .border_color = .{ .custom_float = .{ .value = .{ 0, 0, 0, 1 }, .format = .r8g8b8a8_unorm } },
        .reduction = .maximum,
        .ycbcr_conversion = &conversion,
    });
    try std.testing.expectEqual(@as(usize, 3), test_chain_count);
    test_destroy_count = 0;
    value.deinit();
    value.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_count);

    test_result = raw.VK_ERROR_OUT_OF_DEVICE_MEMORY;
    defer test_result = raw.VK_SUCCESS;
    test_destroy_count = 0;
    try std.testing.expectError(error.OutOfDeviceMemory, create(device_handle, null, .{
        .create = testCreateSampler,
        .destroy = testDestroySampler,
    }, .{}));
    try std.testing.expectEqual(@as(usize, 1), test_destroy_count);
}
