const std = @import("std");
const vk = @import("vulkan");

pub fn main() !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();

    const entry = try loader.entry();
    const version = try entry.apiVersion();
    std.log.info(
        "Vulkan loader supports {d}.{d}.{d} (registry {s})",
        .{ version.major, version.minor, version.patch, vk.registry_commit },
    );
}
