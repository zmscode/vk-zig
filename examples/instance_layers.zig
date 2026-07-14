const std = @import("std");
const vk = @import("vulkan");

pub fn main(init: std.process.Init) !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();

    const entry = try loader.entry();
    const layers = try entry.instanceLayers(init.gpa);
    defer init.gpa.free(layers);

    std.log.info("{d} instance layers:", .{layers.len});
    for (layers) |layer| {
        const version = vk.Version.decode(layer.specVersion);
        std.log.info(
            "  {s} (Vulkan {d}.{d}.{d}): {s}",
            .{
                vk.layerName(&layer),
                version.major,
                version.minor,
                version.patch,
                vk.layerDescription(&layer),
            },
        );
    }
}
