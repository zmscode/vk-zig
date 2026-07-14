const std = @import("std");

const file_size_max = 64 * 1024 * 1024;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.InvalidArguments;

    const input = try std.Io.Dir.cwd().readFileAlloc(
        io,
        args[1],
        gpa,
        .limited(file_size_max),
    );
    defer gpa.free(input);

    var output: std.Io.Writer.Allocating = .init(gpa);
    defer output.deinit();

    try output.writer.writeAll(
        "// Generated from the Khronos Vulkan headers by Zig translate-c.\n",
    );

    var declaration_count: u32 = 0;
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "pub const VkInstance =")) {
            declaration_count += 1;
        }
        if (std.mem.startsWith(u8, line, "pub const PFN_vkCreateInstance =")) {
            declaration_count += 1;
        }
        if (std.mem.startsWith(u8, line, "pub const VK_API_VERSION_1_0 =")) {
            declaration_count += 1;
        }

        try output.writer.writeAll(line);
        try output.writer.writeByte('\n');
    }

    if (declaration_count != 3) return error.IncompleteVulkanBindings;

    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = args[2],
        .data = output.written(),
    });
}
