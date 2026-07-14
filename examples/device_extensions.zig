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
        const properties = device.properties();
        const extensions = try device.deviceExtensions(init.gpa, null);
        defer init.gpa.free(extensions);
        std.log.info("{s}: {d} device extensions", .{
            properties.name(),
            extensions.len,
        });
        std.log.info("  VK_KHR_swapchain: {}", .{
            vk.supportsExtension(extensions, vk.extension.khr_swapchain.name),
        });
    }
}
