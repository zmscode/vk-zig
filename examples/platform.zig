const std = @import("std");
const vk = @import("vulkan");

pub fn main() !void {
    std.log.info("generated Vulkan platform: {s}", .{@tagName(vk.platform)});
    std.log.info("Khronos registry commit: {s}", .{vk.registry_commit});

    std.log.info("surface extensions: {any}", .{vk.SurfaceConfiguration.instanceExtensions()});
}
