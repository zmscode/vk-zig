const std = @import("std");
const vk = @import("vulkan");
const support = @import("support.zig");

pub fn main(init: std.process.Init) !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();
    const entry = try loader.entry();

    var instance = try support.createInstance(&entry);
    defer instance.deinit();
    const physical_devices = try instance.physicalDevices(init.gpa);
    defer init.gpa.free(physical_devices);
    if (physical_devices.len == 0) return error.NoPhysicalDevice;

    const physical_device = &physical_devices[0];
    const queue_families = try physical_device.queueFamilyProperties(init.gpa);
    defer init.gpa.free(queue_families);
    const family_index = support.findGraphicsQueue(queue_families) orelse {
        return error.NoGraphicsQueue;
    };

    const priorities = [_]f32{1.0};
    const queues = [_]vk.DeviceQueueOptions{.{
        .family_index = family_index,
        .priorities = &priorities,
    }};
    var device = try physical_device.createDevice(.{
        .queues = &queues,
        .enable_portability_subset = vk.platform == .metal,
    });
    defer device.deinit();

    const queue = try device.queue(family_index, 0);
    try queue.waitIdle();
    try device.waitIdle();

    const properties = physical_device.properties();
    std.log.info(
        "created a logical device and graphics queue for {s}",
        .{vk.physicalDeviceName(&properties)},
    );
}
