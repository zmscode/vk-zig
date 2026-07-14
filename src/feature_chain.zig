const std = @import("std");
const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const core = @import("core.zig");
const physical_device = @import("physical_device.zig");

pub const Feature = types.Feature;
pub const FeatureSet = types.FeatureSet;
pub const ExtensionFeature = types.extension_features;

/// A heterogeneous, caller-owned chain of registry-generated extension feature nodes.
/// The node list is compile-time fixed, while requested/supported booleans remain ordinary values.
pub fn ExtensionChain(comptime NodeTypes: []const type) type {
    if (NodeTypes.len == 0) @compileError("an extension feature chain needs at least one node");
    comptime {
        for (NodeTypes, 0..) |Node, index| {
            if (!@hasDecl(Node, "Raw") or !@hasDecl(Node, "structure_type") or
                !@hasDecl(Node, "toRaw") or !@hasDecl(Node, "fromRaw"))
            {
                @compileError("extension feature chain nodes must come from vk.ExtensionFeature");
            }
            for (NodeTypes[0..index]) |Previous| {
                if (Node.structure_type == Previous.structure_type) {
                    @compileError("duplicate or aliased extension feature chain node");
                }
            }
        }
    }
    const Values = std.meta.Tuple(NodeTypes);
    comptime var raw_node_types: [NodeTypes.len]type = undefined;
    inline for (NodeTypes, 0..) |Node, index| raw_node_types[index] = Node.Raw;
    const RawValues = std.meta.Tuple(&raw_node_types);

    return struct {
        values: Values,
        raw_values: RawValues = undefined,

        const Chain = @This();

        pub fn init(values: Values) Chain {
            return .{ .values = values };
        }

        pub fn empty() Chain {
            return .{ .values = std.mem.zeroes(Values) };
        }

        /// Links mutable output nodes immediately before `vkGetPhysicalDeviceFeatures2`.
        pub fn prepareQuery(chain: *Chain) ?*anyopaque {
            return chain.linkRaw();
        }

        pub fn finishQuery(chain: *Chain) void {
            inline for (NodeTypes, 0..) |Node, index| {
                chain.values[index] = Node.fromRaw(&chain.raw_values[index]);
            }
        }

        /// Links requested input nodes immediately before `vkCreateDevice`.
        pub fn prepareEnable(chain: *Chain) ?*anyopaque {
            return chain.linkRaw();
        }

        pub fn supportedBy(requested: *const Chain, supported: *const Chain) bool {
            inline for (NodeTypes, 0..) |Node, index| {
                inline for (std.meta.fields(Node)) |field| {
                    if (@field(requested.values[index], field.name) and
                        !@field(supported.values[index], field.name)) return false;
                }
            }
            return true;
        }

        fn linkRaw(chain: *Chain) ?*anyopaque {
            var next: ?*anyopaque = null;
            inline for (0..NodeTypes.len) |offset| {
                const index = NodeTypes.len - 1 - offset;
                chain.raw_values[index] = chain.values[index].toRaw(next);
                next = @ptrCast(&chain.raw_values[index]);
            }
            return next;
        }
    };
}

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
        return storage.linkWithTail(api_version, null);
    }

    pub fn linkWithTail(
        storage: *FeatureStorage,
        api_version: core.Version,
        tail: ?*anyopaque,
    ) *raw.VkPhysicalDeviceFeatures2 {
        storage.root.pNext = null;
        storage.vulkan_11.pNext = null;
        storage.vulkan_12.pNext = null;
        storage.vulkan_13.pNext = null;
        storage.vulkan_14.pNext = null;
        if (api_version.atLeast(.v1_1)) storage.root.pNext = &storage.vulkan_11;
        if (api_version.atLeast(.v1_2)) storage.vulkan_11.pNext = &storage.vulkan_12;
        if (api_version.atLeast(.v1_3)) storage.vulkan_12.pNext = &storage.vulkan_13;
        if (api_version.atLeast(.v1_4)) storage.vulkan_13.pNext = &storage.vulkan_14;
        if (api_version.atLeast(.v1_4)) {
            storage.vulkan_14.pNext = tail;
        } else if (api_version.atLeast(.v1_3)) {
            storage.vulkan_13.pNext = tail;
        } else if (api_version.atLeast(.v1_2)) {
            storage.vulkan_12.pNext = tail;
        } else if (api_version.atLeast(.v1_1)) {
            storage.vulkan_11.pNext = tail;
        } else {
            storage.root.pNext = tail;
        }
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
    const rendering = profileRequirements(.modern_rendering);
    try std.testing.expect(rendering.contains(.dynamic_rendering));
    try std.testing.expect(rendering.contains(.synchronization2));
    try std.testing.expect(!rendering.contains(.maintenance4));
}

test "generated extension chains preserve addresses and validate requests" {
    const Mesh = ExtensionFeature.MeshShaderFeaturesEXT;
    const RayQuery = ExtensionFeature.RayQueryFeaturesKHR;
    const Chain = ExtensionChain(&.{ Mesh, RayQuery });
    var supported = Chain.init(.{
        Mesh{ .mesh_shader = true, .task_shader = true },
        RayQuery{ .ray_query = true },
    });
    _ = supported.prepareEnable();
    try std.testing.expect(supported.raw_values[0].pNext == @as(?*anyopaque, @ptrCast(&supported.raw_values[1])));
    try std.testing.expect(supported.raw_values[1].pNext == null);

    var requested = Chain.init(.{
        Mesh{ .mesh_shader = true },
        RayQuery{},
    });
    try std.testing.expect(requested.supportedBy(&supported));
    requested.values[1].ray_query = true;
    try std.testing.expect(requested.supportedBy(&supported));
    supported.values[1].ray_query = false;
    try std.testing.expect(!requested.supportedBy(&supported));
}
