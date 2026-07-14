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

    std.log.info("{d} physical devices:", .{devices.len});
    for (devices) |*device| {
        const properties = device.properties();
        const version = vk.Version.decode(properties.apiVersion);
        std.log.info(
            "  {s}: {s}, Vulkan {d}.{d}.{d}, vendor=0x{x}, device=0x{x}",
            .{
                support.cString(&properties.deviceName),
                support.deviceTypeName(properties.deviceType),
                version.major,
                version.minor,
                version.patch,
                properties.vendorID,
                properties.deviceID,
            },
        );
    }
}
