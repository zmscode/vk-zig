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
        std.log.info(
            "  {s} (Vulkan {d}.{d}.{d}): {s}",
            .{
                layer.name(),
                layer.spec_version.major,
                layer.spec_version.minor,
                layer.spec_version.patch,
                layer.description(),
            },
        );
    }
}
