const std = @import("std");

const file_size_max = 64 * 1024 * 1024;

const Scope = enum {
    global,
    instance,
    device,
};

const Command = struct {
    pfn_name: []const u8,
    command_name: []const u8,
    alias_name: ?[]const u8,
    scope: ?Scope,
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 4) return error.InvalidArguments;

    const bindings = try std.Io.Dir.cwd().readFileAlloc(
        io,
        args[1],
        gpa,
        .limited(file_size_max),
    );
    defer gpa.free(bindings);
    const registry = try std.Io.Dir.cwd().readFileAlloc(
        io,
        args[2],
        gpa,
        .limited(file_size_max),
    );
    defer gpa.free(registry);

    var registry_commands: std.StringHashMapUnmanaged(void) = .empty;
    defer registry_commands.deinit(gpa);
    try collectRegistryCommands(gpa, registry, &registry_commands);

    var commands: std.ArrayList(Command) = .empty;
    defer commands.deinit(gpa);
    try collectBindingCommands(gpa, bindings, &registry_commands, &commands);
    defer for (commands.items) |command| {
        gpa.free(command.pfn_name);
        gpa.free(command.command_name);
        if (command.alias_name) |alias_name| gpa.free(alias_name);
    };
    try resolveAliasScopes(commands.items);

    var output: std.Io.Writer.Allocating = .init(gpa);
    defer output.deinit();
    try writeHeader(&output.writer);

    var generated_names: std.StringHashMapUnmanaged(void) = .empty;
    defer generated_names.deinit(gpa);
    for (commands.items) |command| {
        var name_buffer: [256]u8 = undefined;
        const generated_name = try snakeName(command.command_name, &name_buffer);
        const result = try generated_names.getOrPut(gpa, generated_name);
        if (result.found_existing) return error.DuplicateGeneratedName;
        result.key_ptr.* = try gpa.dupe(u8, generated_name);

        try output.writer.print(
            "pub const {s} = Descriptor(raw.PFN_{s}, \"{s}\", .{s}){{}};\n",
            .{ generated_name, command.pfn_name, command.command_name, @tagName(command.scope.?) },
        );
    }

    var key_iterator = generated_names.keyIterator();
    while (key_iterator.next()) |key| gpa.free(key.*);

    if (commands.items.len < 100) return error.IncompleteCommandGeneration;
    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = args[3],
        .data = output.written(),
    });
}

fn collectRegistryCommands(
    gpa: std.mem.Allocator,
    registry: []const u8,
    commands: *std.StringHashMapUnmanaged(void),
) !void {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, registry, cursor, "<command")) |command_start| {
        const tag_end = std.mem.indexOfPos(u8, registry, command_start, ">") orelse {
            return error.InvalidRegistry;
        };
        const opening_tag = registry[command_start .. tag_end + 1];
        if (attribute(opening_tag, "name")) |name| {
            if (std.mem.startsWith(u8, name, "vk")) try commands.put(gpa, name, {});
            cursor = tag_end + 1;
            continue;
        }

        const block_end = std.mem.indexOfPos(u8, registry, tag_end, "</command>") orelse {
            return error.InvalidRegistry;
        };
        const block = registry[tag_end + 1 .. block_end];
        const proto_start = std.mem.indexOf(u8, block, "<proto>") orelse {
            cursor = block_end + "</command>".len;
            continue;
        };
        const proto_end = std.mem.indexOfPos(u8, block, proto_start, "</proto>") orelse {
            return error.InvalidRegistry;
        };
        const proto = block[proto_start..proto_end];
        const name_start = std.mem.indexOf(u8, proto, "<name>") orelse {
            return error.InvalidRegistry;
        };
        const value_start = name_start + "<name>".len;
        const value_end = std.mem.indexOfPos(u8, proto, value_start, "</name>") orelse {
            return error.InvalidRegistry;
        };
        const name = proto[value_start..value_end];
        if (std.mem.startsWith(u8, name, "vk")) try commands.put(gpa, name, {});
        cursor = block_end + "</command>".len;
    }
}

fn attribute(tag: []const u8, name: []const u8) ?[]const u8 {
    var pattern_buffer: [64]u8 = undefined;
    const pattern = std.fmt.bufPrint(&pattern_buffer, "{s}=\"", .{name}) catch return null;
    const start = std.mem.indexOf(u8, tag, pattern) orelse return null;
    const value_start = start + pattern.len;
    const value_end = std.mem.indexOfScalarPos(u8, tag, value_start, '"') orelse return null;
    return tag[value_start..value_end];
}

fn collectBindingCommands(
    gpa: std.mem.Allocator,
    bindings: []const u8,
    registry_commands: *const std.StringHashMapUnmanaged(void),
    commands: *std.ArrayList(Command),
) !void {
    var lines = std.mem.splitScalar(u8, bindings, '\n');
    while (lines.next()) |line| {
        const prefix = "pub const PFN_";
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        const pfn_end = std.mem.indexOfScalarPos(u8, line, prefix.len, ' ') orelse continue;
        const pfn_name = line[prefix.len..pfn_end];
        if (!std.mem.startsWith(u8, pfn_name, "vk")) continue;
        if (!registry_commands.contains(pfn_name)) continue;

        const alias_marker = "= PFN_";
        const alias_name = if (std.mem.indexOf(u8, line, alias_marker)) |alias_start| blk: {
            const value_start = alias_start + alias_marker.len;
            const value_end = std.mem.indexOfScalarPos(u8, line, value_start, ';') orelse {
                return error.InvalidBindingAlias;
            };
            break :blk line[value_start..value_end];
        } else null;

        try commands.append(gpa, .{
            .pfn_name = try gpa.dupe(u8, pfn_name),
            .command_name = try gpa.dupe(u8, pfn_name),
            .alias_name = if (alias_name) |value| try gpa.dupe(u8, value) else null,
            .scope = if (alias_name == null) classifyScope(line) else null,
        });
    }
}

fn classifyScope(line: []const u8) Scope {
    const signature_marker = "?*const fn (";
    const signature_start = std.mem.indexOf(u8, line, signature_marker) orelse return .global;
    const parameters = line[signature_start + signature_marker.len ..];
    if (std.mem.startsWith(u8, parameters, "instance: VkInstance")) return .instance;
    if (std.mem.startsWith(u8, parameters, "physicalDevice: VkPhysicalDevice")) return .instance;
    if (std.mem.startsWith(u8, parameters, "device: VkDevice")) return .device;
    if (std.mem.startsWith(u8, parameters, "queue: VkQueue")) return .device;
    if (std.mem.startsWith(u8, parameters, "commandBuffer: VkCommandBuffer")) return .device;
    return .global;
}

fn resolveAliasScopes(commands: []Command) !void {
    for (0..commands.len) |_| {
        var changed = false;
        for (commands) |*command| {
            if (command.scope != null) continue;
            const alias_name = command.alias_name orelse return error.InvalidBindingAlias;
            for (commands) |target| {
                if (!std.mem.eql(u8, target.command_name, alias_name)) continue;
                if (target.scope) |scope| {
                    command.scope = scope;
                    changed = true;
                }
                break;
            }
        }
        if (!changed) break;
    }
    for (commands) |command| {
        if (command.scope == null) return error.UnresolvedCommandAlias;
    }
}

fn snakeName(command_name: []const u8, buffer: []u8) ![]const u8 {
    if (!std.mem.startsWith(u8, command_name, "vk")) return error.InvalidCommandName;
    const source = command_name[2..];
    var length: usize = 0;
    for (source, 0..) |character, index| {
        const uppercase = std.ascii.isUpper(character);
        if (uppercase and index > 0) {
            const previous = source[index - 1];
            const next_lowercase = index + 1 < source.len and std.ascii.isLower(source[index + 1]);
            if (std.ascii.isLower(previous) or std.ascii.isDigit(previous) or
                (std.ascii.isUpper(previous) and next_lowercase))
            {
                if (length == buffer.len) return error.NameTooLong;
                buffer[length] = '_';
                length += 1;
            }
        }
        if (length == buffer.len) return error.NameTooLong;
        buffer[length] = std.ascii.toLower(character);
        length += 1;
    }
    return buffer[0..length];
}

fn writeHeader(writer: *std.Io.Writer) !void {
    try writer.writeAll(
        \\// Generated from Vulkan PFN declarations. Do not edit.
        \\const raw = @import("vulkan_raw");
        \\
        \\pub const Scope = enum { global, instance, device };
        \\
        \\pub fn FunctionType(comptime Pfn: type) type {
        \\    const optional = switch (@typeInfo(Pfn)) {
        \\        .optional => |value| value,
        \\        else => @compileError("expected an optional Vulkan PFN function-pointer type"),
        \\    };
        \\    const pointer = switch (@typeInfo(optional.child)) {
        \\        .pointer => |value| value,
        \\        else => @compileError("expected an optional Vulkan PFN function-pointer type"),
        \\    };
        \\    if (pointer.size != .one or !pointer.is_const) {
        \\        @compileError("expected an optional Vulkan PFN function-pointer type");
        \\    }
        \\    switch (@typeInfo(pointer.child)) {
        \\        .@"fn" => {},
        \\        else => @compileError("expected an optional Vulkan PFN function-pointer type"),
        \\    }
        \\    return optional.child;
        \\}
        \\
        \\pub fn Descriptor(
        \\    comptime PfnType: type,
        \\    comptime command_name: [:0]const u8,
        \\    comptime command_scope: Scope,
        \\) type {
        \\    return struct {
        \\        pub const Pfn = PfnType;
        \\        pub const Function = FunctionType(PfnType);
        \\        pub const name = command_name;
        \\        pub const scope = command_scope;
        \\    };
        \\}
        \\
    );
}
