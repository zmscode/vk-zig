const std = @import("std");
const vk = @import("vulkan");
const support = @import("support.zig");

pub fn main(init: std.process.Init) !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();
    const entry = try loader.entry();

    var instance = try support.createInstance(&entry);
    defer instance.deinit();
    const devices = try instance.physicalDevices(init.gpa);
    defer init.gpa.free(devices);

    const get_features = instance.load(
        vk.raw.PFN_vkGetPhysicalDeviceFeatures2,
        "vkGetPhysicalDeviceFeatures2",
    ) orelse return error.Features2Unavailable;

    for (devices) |*device| {
        var features: vk.raw.VkPhysicalDeviceFeatures2 = .{
            .sType = vk.raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
        };
        get_features(device.handle, &features);
        const properties = device.properties();
        std.log.info("{s} selected features:", .{support.cString(&properties.deviceName)});
        std.log.info(
            "  geometry shader: {s}",
            .{support.boolName(features.features.geometryShader)},
        );
        std.log.info(
            "  tessellation shader: {s}",
            .{support.boolName(features.features.tessellationShader)},
        );
        std.log.info("  sampler anisotropy: {s}", .{
            support.boolName(features.features.samplerAnisotropy),
        });
    }
}
