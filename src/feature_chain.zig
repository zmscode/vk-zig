const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const core = @import("core.zig");
const physical_device = @import("physical_device.zig");

pub const Feature = types.Feature;
pub const FeatureSet = types.FeatureSet;

/// Common profiles are explicit requirement sets. Selecting one requests only
/// the listed features; vk-zig still validates every bit against device support.
pub const Profile = enum {
    baseline_compute,
    modern_rendering,
    descriptor_indexing,
};

pub fn profileRequirements(profile: Profile) FeatureSet {
    return switch (profile) {
        .baseline_compute => .init(&.{.shader_int64}),
        .modern_rendering => .init(&.{ .dynamic_rendering, .synchronization2 }),
        .descriptor_indexing => .init(&.{
            .descriptor_indexing,
            .runtime_descriptor_array,
            .descriptor_binding_partially_bound,
        }),
    };
}

/// Caller-owned storage for the complete promoted feature chain. Its internal
/// pointers are linked only after the value reaches final storage, preventing
/// pointers into returned temporaries.
pub const FeatureStorage = struct {
    root: raw.VkPhysicalDeviceFeatures2 = .{
        .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
    },
    vulkan_11: raw.VkPhysicalDeviceVulkan11Features = .{
        .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
    },
    vulkan_12: raw.VkPhysicalDeviceVulkan12Features = .{
        .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
    },
    vulkan_13: raw.VkPhysicalDeviceVulkan13Features = .{
        .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
    },
    vulkan_14: raw.VkPhysicalDeviceVulkan14Features = .{
        .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_4_FEATURES,
    },

    pub fn init(requested: FeatureSet) FeatureStorage {
        return .{
            .root = .{
                .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
                .features = requested.core10Raw(),
            },
            .vulkan_11 = requested.vulkan11Raw(),
            .vulkan_12 = requested.vulkan12Raw(),
            .vulkan_13 = requested.vulkan13Raw(),
            .vulkan_14 = requested.vulkan14Raw(),
        };
    }

    pub fn link(storage: *FeatureStorage, api_version: core.Version) *raw.VkPhysicalDeviceFeatures2 {
        storage.root.pNext = null;
        storage.vulkan_11.pNext = null;
        storage.vulkan_12.pNext = null;
        storage.vulkan_13.pNext = null;
        storage.vulkan_14.pNext = null;
        if (api_version.atLeast(.v1_1)) storage.root.pNext = &storage.vulkan_11;
        if (api_version.atLeast(.v1_2)) storage.vulkan_11.pNext = &storage.vulkan_12;
        if (api_version.atLeast(.v1_3)) storage.vulkan_12.pNext = &storage.vulkan_13;
        if (api_version.atLeast(.v1_4)) storage.vulkan_13.pNext = &storage.vulkan_14;
        return &storage.root;
    }

    pub fn featureSet(storage: *const FeatureStorage) FeatureSet {
        return .fromRaw(
            &storage.root.features,
            &storage.vulkan_11,
            &storage.vulkan_12,
            &storage.vulkan_13,
            &storage.vulkan_14,
        );
    }
};

/// Caller-owned storage for the common physical-device property chain.
pub const PropertyStorage = struct {
    root: raw.VkPhysicalDeviceProperties2 = .{
        .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,
    },
    identity: raw.VkPhysicalDeviceIDProperties = .{
        .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ID_PROPERTIES,
    },
    driver: raw.VkPhysicalDeviceDriverProperties = .{
        .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRIVER_PROPERTIES,
    },

    pub fn link(storage: *PropertyStorage, api_version: core.Version) *raw.VkPhysicalDeviceProperties2 {
        storage.root.pNext = null;
        storage.identity.pNext = null;
        storage.driver.pNext = null;
        if (api_version.atLeast(.v1_1)) {
            storage.root.pNext = &storage.identity;
            if (api_version.atLeast(.v1_2)) storage.identity.pNext = &storage.driver;
        }
        return &storage.root;
    }

    pub fn properties(storage: *const PropertyStorage, api_version: core.Version) physical_device.Properties {
        return .fromRaw2(
            &storage.root.properties,
            if (api_version.atLeast(.v1_1)) &storage.identity else null,
            if (api_version.atLeast(.v1_2)) &storage.driver else null,
        );
    }
};

test "generated feature storage owns stable query and enable chains" {
    const std = @import("std");
    const requested = FeatureSet.init(&.{ .shader_int64, .dynamic_rendering, .maintenance5 });
    var storage = FeatureStorage.init(requested);
    const root = storage.link(.v1_4);
    try std.testing.expect(root.pNext == &storage.vulkan_11);
    try std.testing.expect(storage.vulkan_11.pNext == &storage.vulkan_12);
    try std.testing.expect(storage.vulkan_12.pNext == &storage.vulkan_13);
    try std.testing.expect(storage.vulkan_13.pNext == &storage.vulkan_14);
    try std.testing.expect(storage.featureSet().containsAll(requested));

    _ = storage.link(.v1_2);
    try std.testing.expect(storage.vulkan_12.pNext == null);
}

test "profiles remain explicit feature requirement sets" {
    const std = @import("std");
    const rendering = profileRequirements(.modern_rendering);
    try std.testing.expect(rendering.contains(.dynamic_rendering));
    try std.testing.expect(rendering.contains(.synchronization2));
    try std.testing.expect(!rendering.contains(.maintenance4));
}
