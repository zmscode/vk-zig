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
        const families = try device.queueFamilies(init.gpa);
        defer init.gpa.free(families);

        std.log.info("{s} queue families:", .{device_properties.name()});
        for (families) |family| {
            std.log.info(
                "  {d}: queues={d}, flags=0x{x}, timestamp bits={d}, transfer granularity={d}x{d}x{d}",
                .{
                    family.index.toRaw(),
                    family.queueCount(),
                    family.flags.toRaw(),
                    family.timestamp_valid_bits,
                    family.minimum_image_transfer_granularity.width,
                    family.minimum_image_transfer_granularity.height,
                    family.minimum_image_transfer_granularity.depth,
                },
            );
        }
    }
}
