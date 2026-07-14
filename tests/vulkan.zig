const std = @import("std");
const vk = @import("vulkan");

test "raw bindings contain core Vulkan declarations" {
    try std.testing.expect(@hasDecl(vk.raw, "VkInstance"));
    try std.testing.expect(@hasDecl(vk.raw, "VkDevice"));
    try std.testing.expect(@hasDecl(vk.raw, "PFN_vkGetInstanceProcAddr"));
    try std.testing.expect(@hasDecl(vk.raw, "PFN_vkCreateInstance"));
    try std.testing.expect(@hasDecl(vk.raw, "VK_API_VERSION_1_4"));
}

test "default Apple builds include Metal surface declarations" {
    if (vk.platform != .metal) return;
    try std.testing.expect(@hasDecl(vk.raw, "VkMetalSurfaceCreateInfoEXT"));
    try std.testing.expect(@hasDecl(vk.raw, "PFN_vkCreateMetalSurfaceEXT"));
}

test "API versions round trip" {
    const expected: vk.Version = .{
        .variant = 0,
        .major = 1,
        .minor = 4,
        .patch = 356,
    };
    const actual = vk.Version.decode(expected.encode());
    try std.testing.expectEqual(expected, actual);
}

test "wrapper exposes typed Vulkan lifecycle objects" {
    try std.testing.expect(@hasDecl(vk, "Loader"));
    try std.testing.expect(@hasDecl(vk.Loader, "initFromPath"));
    try std.testing.expect(@hasDecl(vk, "Entry"));
    try std.testing.expect(@hasDecl(vk, "Instance"));
    try std.testing.expect(@hasDecl(vk, "PhysicalDevice"));
    try std.testing.expect(@hasDecl(vk, "Device"));
    try std.testing.expect(@hasDecl(vk, "Queue"));
}

test "all public wrapper declarations compile" {
    std.testing.refAllDecls(vk);
    _ = &vk.Entry.apiVersion;
    _ = &vk.Entry.instanceExtensions;
    _ = &vk.Entry.instanceLayers;
    _ = &vk.Entry.createInstance;
    _ = &vk.Entry.createInstanceRaw;
    _ = &vk.Instance.deinit;
    _ = &vk.Instance.physicalDevices;
    _ = &vk.PhysicalDevice.properties;
    _ = &vk.PhysicalDevice.memoryProperties;
    _ = &vk.PhysicalDevice.queueFamilyProperties;
    _ = &vk.PhysicalDevice.createDevice;
    _ = &vk.Device.deinit;
    _ = &vk.Device.waitIdle;
    _ = &vk.Device.queue;
    _ = &vk.Queue.submit;
    _ = &vk.Queue.waitIdle;
}

test "vendored registry revision is recorded" {
    try std.testing.expectEqual(@as(usize, 40), vk.registry_commit.len);
}
