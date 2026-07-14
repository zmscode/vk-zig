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
    var pending_extern_local: ?[]const u8 = null;
    var pending_indent: []const u8 = "";
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

        const trimmed = std.mem.trimStart(u8, line, " \t");
        if (std.mem.startsWith(u8, trimmed, "const extern_local_") and
            std.mem.indexOf(u8, trimmed, " = struct {") != null)
        {
            const name_start = "const ".len;
            const name_end = std.mem.indexOfPos(u8, trimmed, name_start, " =") orelse {
                return error.InvalidTranslatedBindings;
            };
            pending_extern_local = trimmed[name_start..name_end];
            pending_indent = line[0 .. line.len - trimmed.len];
        }

        try output.writer.writeAll(line);
        try output.writer.writeByte('\n');
        if (pending_extern_local) |name| {
            if (std.mem.eql(u8, trimmed, "};")) {
                try output.writer.print("{s}_ = &{s};\n", .{ pending_indent, name });
                pending_extern_local = null;
            }
        }
    }

    if (declaration_count != 3) return error.IncompleteVulkanBindings;
    if (pending_extern_local != null) return error.InvalidTranslatedBindings;

    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = args[2],
        .data = output.written(),
    });
}
