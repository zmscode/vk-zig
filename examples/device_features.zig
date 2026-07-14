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

    for (devices) |*device| {
        const features = try device.features();
        const properties = device.properties();
        std.log.info("{s} selected features:", .{properties.name()});
        std.log.info(
            "  geometry shader: {s}",
            .{support.boolName(features.contains(.geometry_shader))},
        );
        std.log.info(
            "  tessellation shader: {s}",
            .{support.boolName(features.contains(.tessellation_shader))},
        );
        std.log.info("  sampler anisotropy: {s}", .{
            support.boolName(features.contains(.sampler_anisotropy)),
        });
    }
}
