const std = @import("std");
const vk = @import("vulkan");

pub fn main(init: std.process.Init) !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();

    const entry = try loader.entry();
    const extensions = try entry.instanceExtensions(init.gpa, null);
    defer init.gpa.free(extensions);

    std.log.info("{d} instance extensions:", .{extensions.len});
    for (extensions) |extension| {
        std.log.info(
            "  {s} (revision {d})",
            .{ extension.name(), extension.revision },
        );
    }
}
