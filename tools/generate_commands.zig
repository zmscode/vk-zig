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

const ApiVersion = struct {
    major: u8,
    minor: u8,
};

const CommandResults = struct {
    success_codes: ?[]const u8,
    error_codes: ?[]const u8,
};

const RegistryExtension = struct {
    name: []const u8,
    scope: Scope,
    promoted_to: ?[]const u8,
    deprecated_by: ?[]const u8,
    obsoleted_by: ?[]const u8,
    depends: ?[]const u8,
    platform: ?[]const u8,
    block: []const u8,
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 5) return error.InvalidArguments;

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
    const wrapper_source = try std.Io.Dir.cwd().readFileAlloc(
        io,
        args[3],
        gpa,
        .limited(file_size_max),
    );
    defer gpa.free(wrapper_source);

    var registry_commands: std.StringHashMapUnmanaged(void) = .empty;
    defer registry_commands.deinit(gpa);
    try collectRegistryCommands(gpa, registry, &registry_commands);
    var command_external_sync: std.StringHashMapUnmanaged(bool) = .empty;
    defer command_external_sync.deinit(gpa);
    try collectCommandExternalSync(gpa, registry, &command_external_sync);
    var command_results: std.StringHashMapUnmanaged(CommandResults) = .empty;
    defer command_results.deinit(gpa);
    try collectCommandResults(gpa, registry, &command_results);
    var registry_aliases: std.StringHashMapUnmanaged([]const u8) = .empty;
    defer registry_aliases.deinit(gpa);
    try collectRegistryCommandAliases(gpa, registry, &registry_aliases);

    var core_versions: std.StringHashMapUnmanaged(ApiVersion) = .empty;
    defer core_versions.deinit(gpa);
    try collectCoreCommandVersions(gpa, registry, &core_versions);

    var command_extensions: std.StringHashMapUnmanaged([]const u8) = .empty;
    defer command_extensions.deinit(gpa);
    try collectCommandExtensions(gpa, registry, &command_extensions);

    var registry_extensions: std.ArrayList(RegistryExtension) = .empty;
    defer {
        for (registry_extensions.items) |item| {
            gpa.free(item.name);
            if (item.promoted_to) |value| gpa.free(value);
            if (item.deprecated_by) |value| gpa.free(value);
            if (item.obsoleted_by) |value| gpa.free(value);
            if (item.depends) |value| gpa.free(value);
            if (item.platform) |value| gpa.free(value);
        }
        registry_extensions.deinit(gpa);
    }
    try collectRegistryExtensions(gpa, registry, &registry_extensions);

    var commands: std.ArrayList(Command) = .empty;
    defer commands.deinit(gpa);
    try collectBindingCommands(
        gpa,
        bindings,
        &registry_commands,
        &registry_aliases,
        &commands,
    );
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
            "pub const {s} = Descriptor(raw.PFN_{s}, \"{s}\", .{s}, &.{{",
            .{ generated_name, command.pfn_name, command.command_name, @tagName(command.scope.?) },
        );
        const root_name = try canonicalCommandName(commands.items, command.command_name);
        for (commands.items) |candidate| {
            if (std.mem.eql(u8, candidate.command_name, command.command_name)) continue;
            const candidate_root = try canonicalCommandName(commands.items, candidate.command_name);
            if (!std.mem.eql(u8, root_name, candidate_root)) continue;
            try output.writer.print("\"{s}\",", .{candidate.command_name});
        }
        try output.writer.writeAll("}, ");
        if (groupCoreVersion(commands.items, &core_versions, root_name)) |version| {
            try output.writer.print(".{{ .major = {d}, .minor = {d} }}, ", .{
                version.major,
                version.minor,
            });
        } else {
            try output.writer.writeAll("null, ");
        }
        try output.writer.writeAll("&.{");
        for (commands.items) |candidate| {
            const candidate_root = try canonicalCommandName(commands.items, candidate.command_name);
            if (!std.mem.eql(u8, root_name, candidate_root)) continue;
            const extension_name = command_extensions.get(candidate.command_name) orelse continue;
            var duplicate = false;
            for (commands.items) |previous| {
                if (std.mem.eql(u8, previous.command_name, candidate.command_name)) break;
                const previous_root = try canonicalCommandName(commands.items, previous.command_name);
                if (!std.mem.eql(u8, root_name, previous_root)) continue;
                if (command_extensions.get(previous.command_name)) |previous_extension| {
                    if (std.mem.eql(u8, extension_name, previous_extension)) duplicate = true;
                }
            }
            if (!duplicate) try output.writer.print("\"{s}\",", .{extension_name});
        }
        const results: CommandResults = command_results.get(root_name) orelse .{
            .success_codes = null,
            .error_codes = null,
        };
        try output.writer.print("}}, {}, ", .{command_external_sync.get(root_name) orelse false});
        try writeCodeList(&output.writer, results.success_codes);
        try output.writer.writeAll(", ");
        try writeCodeList(&output.writer, results.error_codes);
        try output.writer.writeAll("){};\n");
    }

    var key_iterator = generated_names.keyIterator();
    while (key_iterator.next()) |key| gpa.free(key.*);

    try writeCoreCoverage(
        &output.writer,
        commands.items,
        &core_versions,
        &command_results,
        wrapper_source,
    );

    try writeExtensions(&output.writer, registry_extensions.items);

    if (commands.items.len < 100) return error.IncompleteCommandGeneration;
    if (registry_extensions.items.len < 100) return error.IncompleteExtensionGeneration;
    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = args[4],
        .data = output.written(),
    });
}

fn collectCommandResults(
    gpa: std.mem.Allocator,
    registry: []const u8,
    metadata: *std.StringHashMapUnmanaged(CommandResults),
) !void {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, registry, cursor, "<command")) |command_start| {
        const tag_end = std.mem.indexOfScalarPos(u8, registry, command_start, '>') orelse {
            return error.InvalidRegistry;
        };
        const opening = registry[command_start .. tag_end + 1];
        if (attribute(opening, "name") != null) {
            cursor = tag_end + 1;
            continue;
        }
        const block_end = std.mem.indexOfPos(u8, registry, tag_end, "</command>") orelse {
            return error.InvalidRegistry;
        };
        const block = registry[tag_end + 1 .. block_end];
        cursor = block_end + "</command>".len;
        const proto_start = std.mem.indexOf(u8, block, "<proto>") orelse continue;
        const proto_end = std.mem.indexOfPos(u8, block, proto_start, "</proto>") orelse {
            return error.InvalidRegistry;
        };
        const proto = block[proto_start..proto_end];
        const name_start = std.mem.indexOf(u8, proto, "<name>") orelse continue;
        const value_start = name_start + "<name>".len;
        const value_end = std.mem.indexOfPos(u8, proto, value_start, "</name>") orelse {
            return error.InvalidRegistry;
        };
        try metadata.put(gpa, proto[value_start..value_end], .{
            .success_codes = attribute(opening, "successcodes"),
            .error_codes = attribute(opening, "errorcodes"),
        });
    }
}

fn writeCodeList(writer: *std.Io.Writer, maybe_codes: ?[]const u8) !void {
    try writer.writeAll("&.{");
    const codes = maybe_codes orelse {
        try writer.writeAll("}");
        return;
    };
    var iterator = std.mem.splitScalar(u8, codes, ',');
    while (iterator.next()) |code| try writer.print("\"{s}\",", .{code});
    try writer.writeAll("}");
}

fn collectCommandExternalSync(
    gpa: std.mem.Allocator,
    registry: []const u8,
    metadata: *std.StringHashMapUnmanaged(bool),
) !void {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, registry, cursor, "<command")) |command_start| {
        const tag_end = std.mem.indexOfScalarPos(u8, registry, command_start, '>') orelse {
            return error.InvalidRegistry;
        };
        const opening = registry[command_start .. tag_end + 1];
        if (attribute(opening, "name") != null) {
            cursor = tag_end + 1;
            continue;
        }
        const block_end = std.mem.indexOfPos(u8, registry, tag_end, "</command>") orelse {
            return error.InvalidRegistry;
        };
        const block = registry[tag_end + 1 .. block_end];
        cursor = block_end + "</command>".len;
        const proto_start = std.mem.indexOf(u8, block, "<proto>") orelse continue;
        const proto_end = std.mem.indexOfPos(u8, block, proto_start, "</proto>") orelse {
            return error.InvalidRegistry;
        };
        const proto = block[proto_start..proto_end];
        const name_start = std.mem.indexOf(u8, proto, "<name>") orelse continue;
        const value_start = name_start + "<name>".len;
        const value_end = std.mem.indexOfPos(u8, proto, value_start, "</name>") orelse {
            return error.InvalidRegistry;
        };
        const name = proto[value_start..value_end];
        const externally_synchronized = std.mem.indexOf(u8, block, "externsync=\"true\"") != null or
            std.mem.indexOf(u8, block, "externsync=\"maybe\"") != null or
            std.mem.indexOf(u8, block, "<implicitexternsyncparams>") != null;
        try metadata.put(gpa, name, externally_synchronized);
    }
}

fn collectRegistryExtensions(
    gpa: std.mem.Allocator,
    registry: []const u8,
    extensions: *std.ArrayList(RegistryExtension),
) !void {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, registry, cursor, "<extension ")) |extension_start| {
        const tag_end = std.mem.indexOfPos(u8, registry, extension_start, ">") orelse {
            return error.InvalidCoreRegistry;
        };
        const opening_tag = registry[extension_start .. tag_end + 1];
        const extension_end = std.mem.indexOfPos(u8, registry, tag_end, "</extension>") orelse {
            return error.InvalidCoreRegistry;
        };
        const name = attribute(opening_tag, "name") orelse return error.InvalidRegistry;
        const extension_type = attribute(opening_tag, "type") orelse {
            cursor = tag_end + 1;
            continue;
        };
        const scope: Scope = if (std.mem.eql(u8, extension_type, "instance"))
            .instance
        else if (std.mem.eql(u8, extension_type, "device"))
            .device
        else {
            cursor = tag_end + 1;
            continue;
        };
        if (std.mem.startsWith(u8, name, "VK_")) try extensions.append(gpa, .{
            .name = try gpa.dupe(u8, name),
            .scope = scope,
            .promoted_to = if (attribute(opening_tag, "promotedto")) |value|
                try gpa.dupe(u8, value)
            else
                null,
            .deprecated_by = if (attribute(opening_tag, "deprecatedby")) |value|
                try gpa.dupe(u8, value)
            else
                null,
            .obsoleted_by = if (attribute(opening_tag, "obsoletedby")) |value|
                try gpa.dupe(u8, value)
            else
                null,
            .depends = if (attribute(opening_tag, "depends")) |value|
                try gpa.dupe(u8, value)
            else
                null,
            .platform = if (attribute(opening_tag, "platform")) |value|
                try gpa.dupe(u8, value)
            else
                null,
            .block = registry[tag_end + 1 .. extension_end],
        });
        cursor = extension_end + "</extension>".len;
    }
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

fn collectRegistryCommandAliases(
    gpa: std.mem.Allocator,
    registry: []const u8,
    aliases: *std.StringHashMapUnmanaged([]const u8),
) !void {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, registry, cursor, "<command")) |command_start| {
        const tag_end = std.mem.indexOfPos(u8, registry, command_start, ">") orelse {
            return error.InvalidRegistry;
        };
        const opening_tag = registry[command_start .. tag_end + 1];
        if (attribute(opening_tag, "name")) |name| {
            if (attribute(opening_tag, "alias")) |alias_name| {
                try aliases.put(gpa, name, alias_name);
            }
        }
        cursor = tag_end + 1;
    }
}

fn collectCoreCommandVersions(
    gpa: std.mem.Allocator,
    registry: []const u8,
    versions: *std.StringHashMapUnmanaged(ApiVersion),
) !void {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, registry, cursor, "<feature ")) |feature_start| {
        const tag_end = std.mem.indexOfPos(u8, registry, feature_start, ">") orelse {
            return error.InvalidRegistry;
        };
        const opening_tag = registry[feature_start .. tag_end + 1];
        const api = attribute(opening_tag, "api") orelse "vulkan";
        const number = attribute(opening_tag, "number") orelse {
            cursor = tag_end + 1;
            continue;
        };
        const feature_end = std.mem.indexOfPos(u8, registry, tag_end, "</feature>") orelse {
            return error.InvalidCoreRegistry;
        };
        cursor = feature_end + "</feature>".len;
        if (!apiListContains(api, "vulkan")) continue;
        const separator = std.mem.indexOfScalar(u8, number, '.') orelse return error.InvalidCoreRegistry;
        const version: ApiVersion = .{
            .major = try std.fmt.parseInt(u8, number[0..separator], 10),
            .minor = try std.fmt.parseInt(u8, number[separator + 1 ..], 10),
        };
        const block = registry[tag_end + 1 .. feature_end];
        var command_cursor: usize = 0;
        while (std.mem.indexOfPos(u8, block, command_cursor, "<command ")) |command_start| {
            const command_end = std.mem.indexOfPos(u8, block, command_start, ">") orelse {
                return error.InvalidCoreRegistry;
            };
            const command_tag = block[command_start .. command_end + 1];
            if (attribute(command_tag, "name")) |name| try versions.put(gpa, name, version);
            command_cursor = command_end + 1;
        }
    }
}

fn collectCommandExtensions(
    gpa: std.mem.Allocator,
    registry: []const u8,
    extensions: *std.StringHashMapUnmanaged([]const u8),
) !void {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, registry, cursor, "<extension ")) |extension_start| {
        const tag_end = std.mem.indexOfPos(u8, registry, extension_start, ">") orelse {
            return error.InvalidExtensionRegistry;
        };
        const opening_tag = registry[extension_start .. tag_end + 1];
        const extension_name = attribute(opening_tag, "name") orelse return error.InvalidExtensionRegistry;
        if (std.mem.endsWith(u8, opening_tag, "/>")) {
            cursor = tag_end + 1;
            continue;
        }
        const extension_end = std.mem.indexOfPos(u8, registry, tag_end, "</extension>") orelse {
            return error.InvalidExtensionRegistry;
        };
        cursor = extension_end + "</extension>".len;
        if (!std.mem.startsWith(u8, extension_name, "VK_")) continue;
        const supported = attribute(opening_tag, "supported") orelse "vulkan";
        if (!apiListContains(supported, "vulkan")) continue;
        const block = registry[tag_end + 1 .. extension_end];
        var command_cursor: usize = 0;
        while (std.mem.indexOfPos(u8, block, command_cursor, "<command ")) |command_start| {
            const command_end = std.mem.indexOfPos(u8, block, command_start, ">") orelse {
                return error.InvalidExtensionRegistry;
            };
            const command_tag = block[command_start .. command_end + 1];
            if (attribute(command_tag, "name")) |name| {
                const result = try extensions.getOrPut(gpa, name);
                if (!result.found_existing) result.value_ptr.* = extension_name;
            }
            command_cursor = command_end + 1;
        }
    }
}

fn apiListContains(list: []const u8, expected: []const u8) bool {
    var values = std.mem.splitScalar(u8, list, ',');
    while (values.next()) |value| {
        if (std.mem.eql(u8, std.mem.trim(u8, value, " \t\r\n"), expected)) return true;
    }
    return false;
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
    registry_aliases: *const std.StringHashMapUnmanaged([]const u8),
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
        const binding_alias_name = if (std.mem.indexOf(u8, line, alias_marker)) |alias_start| blk: {
            const value_start = alias_start + alias_marker.len;
            const value_end = std.mem.indexOfScalarPos(u8, line, value_start, ';') orelse {
                return error.InvalidBindingAlias;
            };
            break :blk line[value_start..value_end];
        } else null;
        const alias_name = binding_alias_name orelse registry_aliases.get(pfn_name);

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

fn canonicalCommandName(commands: []const Command, name: []const u8) ![]const u8 {
    var current = name;
    for (0..commands.len) |_| {
        for (commands) |command| {
            if (!std.mem.eql(u8, command.command_name, current)) continue;
            current = command.alias_name orelse return command.command_name;
            break;
        } else return error.UnresolvedCommandAlias;
    }
    return error.CommandAliasCycle;
}

fn groupCoreVersion(
    commands: []const Command,
    versions: *const std.StringHashMapUnmanaged(ApiVersion),
    root_name: []const u8,
) ?ApiVersion {
    var selected: ?ApiVersion = null;
    for (commands) |command| {
        const candidate_root = canonicalCommandName(commands, command.command_name) catch continue;
        if (!std.mem.eql(u8, root_name, candidate_root)) continue;
        const version = versions.get(command.command_name) orelse continue;
        if (selected == null or version.major < selected.?.major or
            (version.major == selected.?.major and version.minor < selected.?.minor))
        {
            selected = version;
        }
    }
    return selected;
}

fn writeCoreCoverage(
    writer: *std.Io.Writer,
    commands: []const Command,
    versions: *const std.StringHashMapUnmanaged(ApiVersion),
    results: *const std.StringHashMapUnmanaged(CommandResults),
    wrapper_source: []const u8,
) !void {
    try writer.writeAll(
        \\
        \\pub const WrapperStatus = enum { wrapped, raw_only };
        \\
        \\pub const CoreCommandCoverage = struct {
        \\    name: [:0]const u8,
        \\    scope: Scope,
        \\    version: ApiVersion,
        \\    status: WrapperStatus,
        \\    success_codes: []const [:0]const u8,
        \\    error_codes: []const [:0]const u8,
        \\};
        \\
        \\pub const core_command_coverage = [_]CoreCommandCoverage{
        \\
    );
    var covered: usize = 0;
    var iterator = versions.iterator();
    while (iterator.next()) |entry| {
        const name = entry.key_ptr.*;
        const version = entry.value_ptr.*;
        var pfn_buffer: [256]u8 = undefined;
        const pfn_name = try std.fmt.bufPrint(&pfn_buffer, "PFN_{s}", .{name});
        const status: []const u8 = if (std.mem.indexOf(u8, wrapper_source, pfn_name) != null)
            "wrapped"
        else
            "raw_only";
        for (commands) |command| {
            if (!std.mem.eql(u8, command.command_name, name)) continue;
            try writer.print(
                "    .{{ .name = \"{s}\", .scope = .{s}, .version = .{{ .major = {d}, .minor = {d} }}, .status = .{s}, .success_codes = ",
                .{ name, @tagName(command.scope.?), version.major, version.minor, status },
            );
            const root_name = try canonicalCommandName(commands, name);
            const metadata: CommandResults = results.get(root_name) orelse .{
                .success_codes = null,
                .error_codes = null,
            };
            try writeCodeList(writer, metadata.success_codes);
            try writer.writeAll(", .error_codes = ");
            try writeCodeList(writer, metadata.error_codes);
            try writer.writeAll(" },\n");
            covered += 1;
            break;
        } else return error.MissingCoreCommandBinding;
    }
    if (covered != versions.count()) return error.IncompleteCoreCommandCoverage;
    try writer.writeAll("};\n");
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

fn extensionSnakeName(extension_name: []const u8, buffer: []u8) ![]const u8 {
    if (!std.mem.startsWith(u8, extension_name, "VK_")) return error.InvalidExtensionName;
    const source = extension_name["VK_".len..];
    if (source.len > buffer.len) return error.NameTooLong;
    for (source, buffer[0..source.len]) |character, *output| {
        output.* = std.ascii.toLower(character);
    }
    return buffer[0..source.len];
}

fn writeExtensions(writer: *std.Io.Writer, extensions: []const RegistryExtension) !void {
    try writer.writeAll(
        \\
        \\pub fn ExtensionMetadata(comptime extension_scope: Scope) type {
        \\    return struct {
        \\    name: [:0]const u8,
        \\    promoted_to: ?[:0]const u8 = null,
        \\    deprecated_by: ?[:0]const u8 = null,
        \\    obsoleted_by: ?[:0]const u8 = null,
        \\    depends: ?[:0]const u8 = null,
        \\    platform: ?[:0]const u8 = null,
        \\    commands: []const [:0]const u8 = &.{},
        \\    feature_structures: []const [:0]const u8 = &.{},
        \\    property_structures: []const [:0]const u8 = &.{},
        \\
        \\        pub const scope = extension_scope;
        \\    };
        \\}
        \\pub const InstanceExtension = ExtensionMetadata(.instance);
        \\pub const DeviceExtension = ExtensionMetadata(.device);
        \\
        \\pub const extension = struct {
        \\
    );
    for (extensions) |item| {
        var name_buffer: [256]u8 = undefined;
        const generated_name = try extensionSnakeName(item.name, &name_buffer);
        const extension_type = switch (item.scope) {
            .instance => "InstanceExtension",
            .device => "DeviceExtension",
            .global => unreachable,
        };
        try writer.print(
            "    pub const {s}: {s} = .{{ .name = \"{s}\", .promoted_to = ",
            .{ generated_name, extension_type, item.name },
        );
        if (item.promoted_to) |value| try writer.print("\"{s}\"", .{value}) else try writer.writeAll("null");
        try writer.writeAll(", .deprecated_by = ");
        if (item.deprecated_by) |value| try writer.print("\"{s}\"", .{value}) else try writer.writeAll("null");
        try writer.writeAll(", .obsoleted_by = ");
        if (item.obsoleted_by) |value| try writer.print("\"{s}\"", .{value}) else try writer.writeAll("null");
        try writer.writeAll(", .depends = ");
        if (item.depends) |value| try writer.print("\"{s}\"", .{value}) else try writer.writeAll("null");
        try writer.writeAll(", .platform = ");
        if (item.platform) |value| try writer.print("\"{s}\"", .{value}) else try writer.writeAll("null");
        try writer.writeAll(", .commands = ");
        try writeRequiredNames(writer, item.block, "command", null);
        try writer.writeAll(", .feature_structures = ");
        try writeRequiredNames(writer, item.block, "type", "Features");
        try writer.writeAll(", .property_structures = ");
        try writeRequiredNames(writer, item.block, "type", "Properties");
        try writer.writeAll(" };\n");
    }
    try writer.writeAll("};\n\npub const instance_extensions = [_]InstanceExtension{\n");
    for (extensions) |item| {
        if (item.scope != .instance) continue;
        var name_buffer: [256]u8 = undefined;
        const generated_name = try extensionSnakeName(item.name, &name_buffer);
        try writer.print("    extension.{s},\n", .{generated_name});
    }
    try writer.writeAll("};\n\npub const device_extensions = [_]DeviceExtension{\n");
    for (extensions) |item| {
        if (item.scope != .device) continue;
        var name_buffer: [256]u8 = undefined;
        const generated_name = try extensionSnakeName(item.name, &name_buffer);
        try writer.print("    extension.{s},\n", .{generated_name});
    }
    try writer.writeAll(
        \\};
        \\
        \\pub fn findInstanceExtension(name: []const u8) ?InstanceExtension {
        \\    for (instance_extensions) |item| if (std.mem.eql(u8, item.name, name)) return item;
        \\    return null;
        \\}
        \\
        \\pub fn findDeviceExtension(name: []const u8) ?DeviceExtension {
        \\    for (device_extensions) |item| if (std.mem.eql(u8, item.name, name)) return item;
        \\    return null;
        \\}
        \\
    );
}

fn writeRequiredNames(
    writer: *std.Io.Writer,
    block: []const u8,
    element: []const u8,
    required_name_fragment: ?[]const u8,
) !void {
    try writer.writeAll("&.{");
    var cursor: usize = 0;
    var marker_buffer: [32]u8 = undefined;
    const marker = try std.fmt.bufPrint(&marker_buffer, "<{s} ", .{element});
    while (std.mem.indexOfPos(u8, block, cursor, marker)) |start| {
        const end = std.mem.indexOfScalarPos(u8, block, start, '>') orelse {
            return error.InvalidRegistry;
        };
        const tag = block[start .. end + 1];
        cursor = end + 1;
        const name = attribute(tag, "name") orelse continue;
        if (required_name_fragment) |fragment| {
            if (!std.mem.startsWith(u8, name, "VkPhysicalDevice")) continue;
            if (std.mem.indexOf(u8, name, fragment) == null) continue;
        }
        try writer.print("\"{s}\",", .{name});
    }
    try writer.writeAll("}");
}

fn writeHeader(writer: *std.Io.Writer) !void {
    try writer.writeAll(
        \\// Generated from Vulkan PFN declarations. Do not edit.
        \\const std = @import("std");
        \\const raw = @import("vulkan_raw");
        \\
        \\pub const Scope = enum { global, instance, device };
        \\pub const ApiVersion = struct { major: u8, minor: u8 };
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
        \\    comptime command_aliases: []const [:0]const u8,
        \\    comptime command_core_version: ?ApiVersion,
        \\    comptime command_extensions: []const [:0]const u8,
        \\    comptime command_externally_synchronized: bool,
        \\    comptime command_success_codes: []const [:0]const u8,
        \\    comptime command_error_codes: []const [:0]const u8,
        \\) type {
        \\    return struct {
        \\        pub const Pfn = PfnType;
        \\        pub const Function = FunctionType(PfnType);
        \\        pub const name = command_name;
        \\        pub const scope = command_scope;
        \\        pub const aliases = command_aliases;
        \\        pub const core_version = command_core_version;
        \\        pub const extensions = command_extensions;
        \\        pub const externally_synchronized = command_externally_synchronized;
        \\        pub const success_codes = command_success_codes;
        \\        pub const error_codes = command_error_codes;
        \\    };
        \\}
        \\
    );
}
