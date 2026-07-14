const std = @import("std");

const file_size_max = 1024 * 1024;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const args = try init.minimal.args.toSlice(gpa);
    defer gpa.free(args);
    if (args.len < 2) return error.InvalidArguments;

    for (args[1..]) |path| {
        const source = try std.Io.Dir.cwd().readFileAlloc(
            init.io,
            path,
            gpa,
            .limited(file_size_max),
        );
        defer gpa.free(source);
        if (std.mem.indexOf(u8, source, "vk.raw") != null) {
            std.log.err("idiomatic example references vk.raw: {s}", .{path});
            return error.RawVulkanReference;
        }
    }
}
