const std = @import("std");
const raw = @import("vulkan_raw");
const core = @import("core.zig");
const device_configuration = @import("device.zig");
const types = @import("vulkan_types");

pub const device_count_max = raw.VK_MAX_DEVICE_GROUP_SIZE;

pub const Mask = struct {
    bits: u32,

    pub const primary: Mask = .{ .bits = 1 };

    pub fn all(device_count: u32) core.Error!Mask {
        if (device_count == 0 or device_count > device_count_max) return error.InvalidOptions;
        return .{ .bits = if (device_count == 32) std.math.maxInt(u32) else (@as(u32, 1) << @intCast(device_count)) - 1 };
    }

    pub fn init(indices: []const u32) core.Error!Mask {
        if (indices.len == 0 or indices.len > device_count_max) return error.InvalidOptions;
        var bits: u32 = 0;
        for (indices) |index| {
            if (index >= device_count_max) return error.InvalidOptions;
            const bit = @as(u32, 1) << @intCast(index);
            if (bits & bit != 0) return error.InvalidOptions;
            bits |= bit;
        }
        return .{ .bits = bits };
    }

    pub fn validate(mask: Mask, device_count: u32) core.Error!void {
        if (mask.bits == 0) return error.InvalidOptions;
        const allowed = (try all(device_count)).bits;
        if (mask.bits & ~allowed != 0) return error.InvalidOptions;
    }

    pub fn contains(mask: Mask, index: u32) bool {
        return index < 32 and mask.bits & (@as(u32, 1) << @intCast(index)) != 0;
    }
};

pub const PhysicalGroup = struct {
    _members: [device_count_max]device_configuration.GroupMember = undefined,
    count: u32,
    subset_allocation: bool,

    pub fn members(group: *const PhysicalGroup) []const device_configuration.GroupMember {
        return group._members[0..group.count];
    }

    pub fn member(group: *const PhysicalGroup, index: u32) core.Error!device_configuration.GroupMember {
        if (index >= group.count) return error.InvalidOptions;
        return group._members[index];
    }

    pub fn mask(group: *const PhysicalGroup) core.Error!Mask {
        return Mask.all(group.count);
    }
};

pub const PeerMemoryFeatures = packed struct(u4) {
    copy_source: bool = false,
    copy_destination: bool = false,
    generic_source: bool = false,
    generic_destination: bool = false,

    pub fn fromRaw(bits: raw.VkPeerMemoryFeatureFlags) PeerMemoryFeatures {
        return .{
            .copy_source = bits & raw.VK_PEER_MEMORY_FEATURE_COPY_SRC_BIT != 0,
            .copy_destination = bits & raw.VK_PEER_MEMORY_FEATURE_COPY_DST_BIT != 0,
            .generic_source = bits & raw.VK_PEER_MEMORY_FEATURE_GENERIC_SRC_BIT != 0,
            .generic_destination = bits & raw.VK_PEER_MEMORY_FEATURE_GENERIC_DST_BIT != 0,
        };
    }
};

pub const PresentModes = packed struct(u4) {
    local: bool = false,
    remote: bool = false,
    sum: bool = false,
    local_multi_device: bool = false,

    pub fn fromRaw(bits: raw.VkDeviceGroupPresentModeFlagsKHR) PresentModes {
        return .{
            .local = bits & raw.VK_DEVICE_GROUP_PRESENT_MODE_LOCAL_BIT_KHR != 0,
            .remote = bits & raw.VK_DEVICE_GROUP_PRESENT_MODE_REMOTE_BIT_KHR != 0,
            .sum = bits & raw.VK_DEVICE_GROUP_PRESENT_MODE_SUM_BIT_KHR != 0,
            .local_multi_device = bits & raw.VK_DEVICE_GROUP_PRESENT_MODE_LOCAL_MULTI_DEVICE_BIT_KHR != 0,
        };
    }

    pub fn toRaw(modes: PresentModes) raw.VkDeviceGroupPresentModeFlagsKHR {
        var bits: raw.VkDeviceGroupPresentModeFlagsKHR = 0;
        if (modes.local) bits |= raw.VK_DEVICE_GROUP_PRESENT_MODE_LOCAL_BIT_KHR;
        if (modes.remote) bits |= raw.VK_DEVICE_GROUP_PRESENT_MODE_REMOTE_BIT_KHR;
        if (modes.sum) bits |= raw.VK_DEVICE_GROUP_PRESENT_MODE_SUM_BIT_KHR;
        if (modes.local_multi_device) bits |= raw.VK_DEVICE_GROUP_PRESENT_MODE_LOCAL_MULTI_DEVICE_BIT_KHR;
        return bits;
    }
};

pub const PresentMode = enum {
    local,
    remote,
    sum,
    local_multi_device,

    pub fn toRaw(mode: PresentMode) raw.VkDeviceGroupPresentModeFlagBitsKHR {
        return switch (mode) {
            .local => raw.VK_DEVICE_GROUP_PRESENT_MODE_LOCAL_BIT_KHR,
            .remote => raw.VK_DEVICE_GROUP_PRESENT_MODE_REMOTE_BIT_KHR,
            .sum => raw.VK_DEVICE_GROUP_PRESENT_MODE_SUM_BIT_KHR,
            .local_multi_device => raw.VK_DEVICE_GROUP_PRESENT_MODE_LOCAL_MULTI_DEVICE_BIT_KHR,
        };
    }
};

pub const PresentCapabilities = struct {
    masks: [device_count_max]Mask,
    device_count: u32,
    modes: PresentModes,

    pub fn deviceMasks(capabilities: *const PresentCapabilities) []const Mask {
        return capabilities.masks[0..capabilities.device_count];
    }
};

pub const PresentRectangle = types.Rect2D;

pub const BufferBindingOptions = struct {
    device_indices: []const u32 = &.{},
};

pub const ImageBindingOptions = struct {
    device_indices: []const u32 = &.{},
    split_regions: []const types.Rect2D = &.{},
};

pub fn validateDeviceIndices(indices: []const u32, device_count: u32) core.Error!void {
    if (indices.len > device_count_max) return error.CountOverflow;
    for (indices, 0..) |index, position| {
        if (index >= device_count) return error.InvalidOptions;
        for (indices[0..position]) |previous| {
            if (index == previous) return error.InvalidOptions;
        }
    }
}

pub fn validateSplitRegions(regions: []const types.Rect2D, device_count: u32) core.Error!void {
    if (regions.len == 0) return;
    if (regions.len != device_count or regions.len > device_count_max) return error.InvalidOptions;
    for (regions) |region| {
        if (region.extent.width == 0 or region.extent.height == 0) return error.InvalidOptions;
    }
}

test "device masks reject out-of-group bits" {
    const mask = try Mask.init(&.{ 0, 2 });
    try mask.validate(3);
    try std.testing.expect(mask.contains(2));
    try std.testing.expectError(error.InvalidOptions, mask.validate(2));
}

test "device indices and split regions are validated against the group" {
    try validateDeviceIndices(&.{ 0, 2 }, 3);
    try std.testing.expectError(error.InvalidOptions, validateDeviceIndices(&.{ 0, 0 }, 3));
    try std.testing.expectError(error.InvalidOptions, validateDeviceIndices(&.{2}, 2));
    const regions = [_]types.Rect2D{
        .{ .offset = .{ .x = 0, .y = 0 }, .extent = .{ .width = 32, .height = 64 } },
        .{ .offset = .{ .x = 32, .y = 0 }, .extent = .{ .width = 32, .height = 64 } },
    };
    try validateSplitRegions(&regions, 2);
    try std.testing.expectError(error.InvalidOptions, validateSplitRegions(regions[0..1], 2));
}
