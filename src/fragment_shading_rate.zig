const std = @import("std");
const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const pipelines = @import("pipeline.zig");
const images = @import("image.zig");
const command_buffers = @import("command_buffer.zig");

const CommandFunction = command.FunctionType;

pub const Features = types.extension_features.FragmentShadingRateFeaturesKHR;
pub const EnumFeaturesNv = types.extension_features.FragmentShadingRateEnumsFeaturesNV;
pub const ImageFeaturesNv = types.extension_features.ShadingRateImageFeaturesNV;
pub const PipelineState = pipelines.FragmentShadingRateState;

pub const Combiner = enum(raw.VkFragmentShadingRateCombinerOpKHR) {
    keep = raw.VK_FRAGMENT_SHADING_RATE_COMBINER_OP_KEEP_KHR,
    replace = raw.VK_FRAGMENT_SHADING_RATE_COMBINER_OP_REPLACE_KHR,
    minimum = raw.VK_FRAGMENT_SHADING_RATE_COMBINER_OP_MIN_KHR,
    maximum = raw.VK_FRAGMENT_SHADING_RATE_COMBINER_OP_MAX_KHR,
    multiply = raw.VK_FRAGMENT_SHADING_RATE_COMBINER_OP_MUL_KHR,
    _,

    pub fn toRaw(value: Combiner) raw.VkFragmentShadingRateCombinerOpKHR {
        return @intFromEnum(value);
    }
};

pub const Combiners = struct {
    pipeline_with_primitive: Combiner = .keep,
    result_with_attachment: Combiner = .keep,

    pub fn toRaw(value: Combiners) [2]raw.VkFragmentShadingRateCombinerOpKHR {
        return .{ value.pipeline_with_primitive.toRaw(), value.result_with_attachment.toRaw() };
    }
};

pub const Rate = struct {
    fragment_size: types.Extent2D,
    sample_counts: types.SampleCountFlags,

    pub fn fromRaw(value: raw.VkPhysicalDeviceFragmentShadingRateKHR) Rate {
        return .{
            .fragment_size = .fromRaw(value.fragmentSize),
            .sample_counts = .fromRaw(value.sampleCounts),
        };
    }
};

pub const Properties = struct {
    attachment_texel_size_min: types.Extent2D,
    attachment_texel_size_max: types.Extent2D,
    attachment_texel_size_aspect_ratio_max: u32,
    primitive_with_multiple_viewports: bool,
    layered_attachments: bool,
    non_trivial_combiner_operations: bool,
    fragment_size_max: types.Extent2D,
    fragment_size_aspect_ratio_max: u32,
    coverage_samples_max: u32,
    rasterization_samples_max: types.SampleCountBit,
    with_shader_depth_stencil_writes: bool,
    with_sample_mask: bool,
    with_shader_sample_mask: bool,
    with_conservative_rasterization: bool,
    with_fragment_shader_interlock: bool,
    with_custom_sample_locations: bool,
    strict_multiply_combiner: bool,

    pub fn fromRaw(value: raw.VkPhysicalDeviceFragmentShadingRatePropertiesKHR) Properties {
        return .{
            .attachment_texel_size_min = .fromRaw(value.minFragmentShadingRateAttachmentTexelSize),
            .attachment_texel_size_max = .fromRaw(value.maxFragmentShadingRateAttachmentTexelSize),
            .attachment_texel_size_aspect_ratio_max = value.maxFragmentShadingRateAttachmentTexelSizeAspectRatio,
            .primitive_with_multiple_viewports = value.primitiveFragmentShadingRateWithMultipleViewports != raw.VK_FALSE,
            .layered_attachments = value.layeredShadingRateAttachments != raw.VK_FALSE,
            .non_trivial_combiner_operations = value.fragmentShadingRateNonTrivialCombinerOps != raw.VK_FALSE,
            .fragment_size_max = .fromRaw(value.maxFragmentSize),
            .fragment_size_aspect_ratio_max = value.maxFragmentSizeAspectRatio,
            .coverage_samples_max = value.maxFragmentShadingRateCoverageSamples,
            .rasterization_samples_max = .fromRaw(value.maxFragmentShadingRateRasterizationSamples),
            .with_shader_depth_stencil_writes = value.fragmentShadingRateWithShaderDepthStencilWrites != raw.VK_FALSE,
            .with_sample_mask = value.fragmentShadingRateWithSampleMask != raw.VK_FALSE,
            .with_shader_sample_mask = value.fragmentShadingRateWithShaderSampleMask != raw.VK_FALSE,
            .with_conservative_rasterization = value.fragmentShadingRateWithConservativeRasterization != raw.VK_FALSE,
            .with_fragment_shader_interlock = value.fragmentShadingRateWithFragmentShaderInterlock != raw.VK_FALSE,
            .with_custom_sample_locations = value.fragmentShadingRateWithCustomSampleLocations != raw.VK_FALSE,
            .strict_multiply_combiner = value.fragmentShadingRateStrictMultiplyCombiner != raw.VK_FALSE,
        };
    }
};

pub const ImagePropertiesNv = struct {
    texel_size: types.Extent2D,
    palette_size: u32,
    max_coarse_samples: u32,

    pub fn fromRaw(value: raw.VkPhysicalDeviceShadingRateImagePropertiesNV) ImagePropertiesNv {
        return .{
            .texel_size = .fromRaw(value.shadingRateTexelSize),
            .palette_size = value.shadingRatePaletteSize,
            .max_coarse_samples = value.shadingRateMaxCoarseSamples,
        };
    }
};

pub const PaletteEntryNv = enum(raw.VkShadingRatePaletteEntryNV) {
    no_invocations = raw.VK_SHADING_RATE_PALETTE_ENTRY_NO_INVOCATIONS_NV,
    invocations_16_per_pixel = raw.VK_SHADING_RATE_PALETTE_ENTRY_16_INVOCATIONS_PER_PIXEL_NV,
    invocations_8_per_pixel = raw.VK_SHADING_RATE_PALETTE_ENTRY_8_INVOCATIONS_PER_PIXEL_NV,
    invocations_4_per_pixel = raw.VK_SHADING_RATE_PALETTE_ENTRY_4_INVOCATIONS_PER_PIXEL_NV,
    invocations_2_per_pixel = raw.VK_SHADING_RATE_PALETTE_ENTRY_2_INVOCATIONS_PER_PIXEL_NV,
    invocation_1_per_pixel = raw.VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_PIXEL_NV,
    invocation_1_per_2x1 = raw.VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_2X1_PIXELS_NV,
    invocation_1_per_1x2 = raw.VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_1X2_PIXELS_NV,
    invocation_1_per_2x2 = raw.VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_2X2_PIXELS_NV,
    invocation_1_per_4x2 = raw.VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_4X2_PIXELS_NV,
    invocation_1_per_2x4 = raw.VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_2X4_PIXELS_NV,
    invocation_1_per_4x4 = raw.VK_SHADING_RATE_PALETTE_ENTRY_1_INVOCATION_PER_4X4_PIXELS_NV,
    _,
};

pub const EnumRateNv = enum(raw.VkFragmentShadingRateNV) {
    invocation_1_per_pixel = raw.VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_PIXEL_NV,
    invocation_1_per_1x2 = raw.VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_1X2_PIXELS_NV,
    invocation_1_per_2x1 = raw.VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_2X1_PIXELS_NV,
    invocation_1_per_2x2 = raw.VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_2X2_PIXELS_NV,
    invocation_1_per_2x4 = raw.VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_2X4_PIXELS_NV,
    invocation_1_per_4x2 = raw.VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_4X2_PIXELS_NV,
    invocation_1_per_4x4 = raw.VK_FRAGMENT_SHADING_RATE_1_INVOCATION_PER_4X4_PIXELS_NV,
    invocations_2_per_pixel = raw.VK_FRAGMENT_SHADING_RATE_2_INVOCATIONS_PER_PIXEL_NV,
    invocations_4_per_pixel = raw.VK_FRAGMENT_SHADING_RATE_4_INVOCATIONS_PER_PIXEL_NV,
    invocations_8_per_pixel = raw.VK_FRAGMENT_SHADING_RATE_8_INVOCATIONS_PER_PIXEL_NV,
    invocations_16_per_pixel = raw.VK_FRAGMENT_SHADING_RATE_16_INVOCATIONS_PER_PIXEL_NV,
    no_invocations = raw.VK_FRAGMENT_SHADING_RATE_NO_INVOCATIONS_NV,
    _,
};

pub const Controller = struct {
    _set_rate: ?CommandFunction(raw.PFN_vkCmdSetFragmentShadingRateKHR),
    _set_enum_nv: ?CommandFunction(raw.PFN_vkCmdSetFragmentShadingRateEnumNV),
    _bind_image_nv: ?CommandFunction(raw.PFN_vkCmdBindShadingRateImageNV),
    _set_palettes_nv: ?CommandFunction(raw.PFN_vkCmdSetViewportShadingRatePaletteNV),

    pub fn setRate(
        controller: Controller,
        command_buffer: *command_buffers.Buffer,
        fragment_size: types.Extent2D,
        combiners: Combiners,
    ) core.Error!void {
        const set = controller._set_rate orelse return error.MissingCommand;
        try validateGraphicsRecording(command_buffer);
        if (fragment_size.width == 0 or fragment_size.height == 0) return error.InvalidOptions;
        const raw_size = fragment_size.toRaw();
        const raw_combiners = combiners.toRaw();
        set(try command_buffer.rawHandle(), &raw_size, &raw_combiners);
    }

    pub fn setEnumNv(
        controller: Controller,
        command_buffer: *command_buffers.Buffer,
        rate: EnumRateNv,
        combiners: Combiners,
    ) core.Error!void {
        const set = controller._set_enum_nv orelse return error.MissingCommand;
        try validateGraphicsRecording(command_buffer);
        const raw_combiners = combiners.toRaw();
        set(try command_buffer.rawHandle(), @intFromEnum(rate), &raw_combiners);
    }

    pub fn bindImageNv(
        controller: Controller,
        command_buffer: *command_buffers.Buffer,
        view: ?*const images.View,
        layout: types.ImageLayout,
    ) core.Error!void {
        const bind = controller._bind_image_nv orelse return error.MissingCommand;
        if (command_buffer.state != .recording) return error.InvalidOptions;
        const handle = if (view) |value| blk: {
            if (value._device_handle != command_buffer._device_handle) return error.InvalidHandle;
            break :blk try value.rawHandle();
        } else null;
        bind(try command_buffer.rawHandle(), handle, layout.toRaw());
    }

    pub fn setPalettesNv(
        controller: Controller,
        command_buffer: *command_buffers.Buffer,
        first_viewport: u32,
        palettes: []const []const PaletteEntryNv,
    ) core.Error!void {
        const set = controller._set_palettes_nv orelse return error.MissingCommand;
        if (command_buffer.state != .recording or palettes.len == 0 or palettes.len > 16) return error.InvalidOptions;
        var raw_entries: [16][256]raw.VkShadingRatePaletteEntryNV = undefined;
        var raw_palettes: [16]raw.VkShadingRatePaletteNV = undefined;
        for (palettes, 0..) |palette, index| {
            if (palette.len == 0 or palette.len > raw_entries[index].len) return error.CountOverflow;
            for (palette, 0..) |entry, entry_index| raw_entries[index][entry_index] = @intFromEnum(entry);
            raw_palettes[index] = .{
                .shadingRatePaletteEntryCount = @intCast(palette.len),
                .pShadingRatePaletteEntries = raw_entries[index][0..palette.len].ptr,
            };
        }
        set(try command_buffer.rawHandle(), first_viewport, @intCast(palettes.len), raw_palettes[0..palettes.len].ptr);
    }
};

fn validateGraphicsRecording(buffer: *const command_buffers.Buffer) core.Error!void {
    if (buffer.state != .recording or !(buffer.rendering_active or buffer.render_pass_active) or
        !buffer.graphics_pipeline_bound) return error.InvalidOptions;
}

test "fragment-rate combiners remain ordered" {
    const combined = (Combiners{
        .pipeline_with_primitive = .replace,
        .result_with_attachment = .multiply,
    }).toRaw();
    try std.testing.expectEqual(@as(raw.VkFragmentShadingRateCombinerOpKHR, @intCast(raw.VK_FRAGMENT_SHADING_RATE_COMBINER_OP_REPLACE_KHR)), combined[0]);
    try std.testing.expectEqual(@as(raw.VkFragmentShadingRateCombinerOpKHR, @intCast(raw.VK_FRAGMENT_SHADING_RATE_COMBINER_OP_MUL_KHR)), combined[1]);
}
