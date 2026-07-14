const std = @import("std");
const vk = @import("vulkan");

pub fn main(init: std.process.Init) !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();
    const entry = try loader.entry();

    const extensions = try entry.instanceExtensions(init.gpa, null);
    defer init.gpa.free(extensions);
    const layers = try entry.instanceLayers(init.gpa);
    defer init.gpa.free(layers);

    std.log.info("VK_EXT_debug_utils available: {}", .{
        vk.supportsExtension(extensions, vk.extension.ext_debug_utils.name),
    });
    std.log.info("Khronos validation layer available: {}", .{
        vk.supportsLayer(layers, vk.layer.khronos_validation.name),
    });
    for (vk.Portability.instanceExtensions()) |name| {
        std.log.info("platform requires instance extension: {s}", .{name});
    }
    for (vk.Portability.deviceExtensions()) |name| {
        std.log.info("platform may require device extension: {s}", .{name});
    }
}
