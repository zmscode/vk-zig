const std = @import("std");
const types = @import("vulkan_types");
const core = @import("core.zig");

/// A selected capability and whether the caller's preferred value was available.
pub fn Choice(comptime T: type) type {
    return struct {
        value: T,
        preferred: bool,
    };
}

pub fn clampSurfaceExtent(
    capabilities: types.SurfaceCapabilities,
    desired: types.Extent2D,
) types.Extent2D {
    return capabilities.extent_current orelse .{
        .width = @min(
            @max(desired.width, capabilities.extent_min.width),
            capabilities.extent_max.width,
        ),
        .height = @min(
            @max(desired.height, capabilities.extent_min.height),
            capabilities.extent_max.height,
        ),
    };
}

pub fn chooseSwapchainImageCount(
    capabilities: types.SurfaceCapabilities,
    preferred: ?u32,
) Choice(u32) {
    const default_count = if (capabilities.image_count_min == std.math.maxInt(u32))
        capabilities.image_count_min
    else
        capabilities.image_count_min + 1;
    const requested = preferred orelse default_count;
    const maximum = capabilities.image_count_max orelse std.math.maxInt(u32);
    const selected = @min(@max(requested, capabilities.image_count_min), maximum);
    return .{ .value = selected, .preferred = preferred == null or selected == requested };
}

pub fn chooseSurfaceFormat(
    available: []const types.SurfaceFormat,
    preferred: []const types.SurfaceFormat,
) core.Error!Choice(types.SurfaceFormat) {
    if (available.len == 0) return error.UnsupportedSurfaceConfiguration;
    if (available.len == 1 and available[0].format == .undefined_) {
        return .{
            .value = if (preferred.len == 0) available[0] else preferred[0],
            .preferred = preferred.len != 0,
        };
    }
    for (preferred) |wanted| {
        for (available) |candidate| {
            if (candidate.format == wanted.format and
                candidate.color_space == wanted.color_space)
            {
                return .{ .value = candidate, .preferred = true };
            }
        }
    }
    return .{ .value = available[0], .preferred = false };
}

pub fn choosePresentMode(
    available: []const types.PresentMode,
    preferred: []const types.PresentMode,
) core.Error!Choice(types.PresentMode) {
    if (available.len == 0) return error.UnsupportedSurfaceConfiguration;
    for (preferred) |wanted| {
        for (available) |candidate| {
            if (candidate == wanted) return .{ .value = candidate, .preferred = true };
        }
    }
    for (available) |candidate| {
        if (candidate == .fifo) return .{ .value = candidate, .preferred = false };
    }
    return .{ .value = available[0], .preferred = false };
}

pub fn chooseSurfaceTransform(
    capabilities: types.SurfaceCapabilities,
    preferred: []const types.SurfaceTransformBit,
) Choice(types.SurfaceTransformBit) {
    for (preferred) |wanted| {
        if (capabilities.transforms_supported.contains(wanted)) {
            return .{ .value = wanted, .preferred = true };
        }
    }
    return .{ .value = capabilities.transform_current, .preferred = false };
}

pub fn chooseCompositeAlpha(
    supported: types.CompositeAlphaFlags,
    preferred: []const types.CompositeAlphaBit,
) core.Error!Choice(types.CompositeAlphaBit) {
    for (preferred) |wanted| {
        if (supported.contains(wanted)) return .{ .value = wanted, .preferred = true };
    }
    const fallback_order = [_]types.CompositeAlphaBit{
        .opaque_,
        .pre_multiplied,
        .post_multiplied,
        .inherit,
    };
    for (fallback_order) |candidate| {
        if (supported.contains(candidate)) return .{ .value = candidate, .preferred = false };
    }
    return error.UnsupportedSurfaceConfiguration;
}

pub fn chooseImageUsage(
    supported: types.ImageUsageFlags,
    required: types.ImageUsageFlags,
    preferred: types.ImageUsageFlags,
) core.Error!Choice(types.ImageUsageFlags) {
    if (!supported.containsAll(required)) return error.UnsupportedSurfaceConfiguration;
    const optional_bits = supported.toRaw() & preferred.toRaw();
    const selected = types.ImageUsageFlags.fromRaw(required.toRaw() | optional_bits);
    return .{
        .value = selected,
        .preferred = supported.containsAll(preferred),
    };
}
