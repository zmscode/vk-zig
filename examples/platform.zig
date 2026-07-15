const std = @import("std");
const vk = @import("vulkan");

pub fn main() !void {
    std.log.info("legacy primary platform: {s}", .{@tagName(vk.platform)});
    std.log.info("platform declarations: metal={} win32={} xlib={} xcb={} wayland={} android={}", .{
        vk.platform_support.metal,
        vk.platform_support.win32,
        vk.platform_support.xlib,
        vk.platform_support.xcb,
        vk.platform_support.wayland,
        vk.platform_support.android,
    });
    std.log.info("Khronos registry commit: {s}", .{vk.registry_commit});

    for (vk.SurfaceConfiguration.instanceExtensions()) |item| {
        std.log.info("surface extension: {s}", .{item.name});
    }
}
