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
        const device_properties = device.properties();
        const families = try device.queueFamilyProperties(init.gpa);
        defer init.gpa.free(families);

        std.log.info("{s} queue families:", .{vk.physicalDeviceName(&device_properties)});
        for (families, 0..) |family, index| {
            std.log.info(
                "  {d}: queues={d}, flags=0x{x}, timestamp bits={d}",
                .{ index, family.queueCount, family.queueFlags, family.timestampValidBits },
            );
        }
    }
}
