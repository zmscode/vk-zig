const std = @import("std");

const file_size_max = 64 * 1024 * 1024;
const generated_name_size_max = 256;

const EnumSpec = struct {
    registry_name: []const u8,
    zig_name: []const u8,
    raw_name: []const u8,
    constant_prefix: []const u8,
    terminal_token: ?[]const u8 = null,
};

const FlagSpec = struct {
    registry_name: []const u8,
    bit_name: []const u8,
    flags_name: []const u8,
    raw_flags_name: []const u8,
    constant_prefix: []const u8,
    terminal_token: ?[]const u8 = null,
};

const enum_specs = [_]EnumSpec{
    .{
        .registry_name = "VkPhysicalDeviceType",
        .zig_name = "PhysicalDeviceType",
        .raw_name = "VkPhysicalDeviceType",
        .constant_prefix = "VK_PHYSICAL_DEVICE_TYPE_",
    },
    .{
        .registry_name = "VkFormat",
        .zig_name = "Format",
        .raw_name = "VkFormat",
        .constant_prefix = "VK_FORMAT_",
    },
    .{
        .registry_name = "VkColorSpaceKHR",
        .zig_name = "ColorSpace",
        .raw_name = "VkColorSpaceKHR",
        .constant_prefix = "VK_COLOR_SPACE_",
        .terminal_token = "KHR",
    },
    .{
        .registry_name = "VkPresentModeKHR",
        .zig_name = "PresentMode",
        .raw_name = "VkPresentModeKHR",
        .constant_prefix = "VK_PRESENT_MODE_",
        .terminal_token = "KHR",
    },
    .{
        .registry_name = "VkImageLayout",
        .zig_name = "ImageLayout",
        .raw_name = "VkImageLayout",
        .constant_prefix = "VK_IMAGE_LAYOUT_",
    },
    .{
        .registry_name = "VkSharingMode",
        .zig_name = "SharingMode",
        .raw_name = "VkSharingMode",
        .constant_prefix = "VK_SHARING_MODE_",
    },
    .{
        .registry_name = "VkImageViewType",
        .zig_name = "ImageViewType",
        .raw_name = "VkImageViewType",
        .constant_prefix = "VK_IMAGE_VIEW_TYPE_",
    },
    .{
        .registry_name = "VkImageType",
        .zig_name = "ImageType",
        .raw_name = "VkImageType",
        .constant_prefix = "VK_IMAGE_TYPE_",
    },
    .{
        .registry_name = "VkImageTiling",
        .zig_name = "ImageTiling",
        .raw_name = "VkImageTiling",
        .constant_prefix = "VK_IMAGE_TILING_",
    },
    .{
        .registry_name = "VkComponentSwizzle",
        .zig_name = "ComponentSwizzle",
        .raw_name = "VkComponentSwizzle",
        .constant_prefix = "VK_COMPONENT_SWIZZLE_",
    },
    .{
        .registry_name = "VkCommandBufferLevel",
        .zig_name = "CommandBufferLevel",
        .raw_name = "VkCommandBufferLevel",
        .constant_prefix = "VK_COMMAND_BUFFER_LEVEL_",
    },
};

const flag_specs = [_]FlagSpec{
    .{
        .registry_name = "VkInstanceCreateFlagBits",
        .bit_name = "InstanceCreateBit",
        .flags_name = "InstanceCreateFlags",
        .raw_flags_name = "VkInstanceCreateFlags",
        .constant_prefix = "VK_INSTANCE_CREATE_",
    },
    .{
        .registry_name = "VkQueueFlagBits",
        .bit_name = "QueueBit",
        .flags_name = "QueueFlags",
        .raw_flags_name = "VkQueueFlags",
        .constant_prefix = "VK_QUEUE_",
    },
    .{
        .registry_name = "VkMemoryPropertyFlagBits",
        .bit_name = "MemoryPropertyBit",
        .flags_name = "MemoryPropertyFlags",
        .raw_flags_name = "VkMemoryPropertyFlags",
        .constant_prefix = "VK_MEMORY_PROPERTY_",
    },
    .{
        .registry_name = "VkMemoryHeapFlagBits",
        .bit_name = "MemoryHeapBit",
        .flags_name = "MemoryHeapFlags",
        .raw_flags_name = "VkMemoryHeapFlags",
        .constant_prefix = "VK_MEMORY_HEAP_",
    },
    .{
        .registry_name = "VkAccessFlagBits",
        .bit_name = "AccessBit",
        .flags_name = "AccessFlags",
        .raw_flags_name = "VkAccessFlags",
        .constant_prefix = "VK_ACCESS_",
    },
    .{
        .registry_name = "VkImageUsageFlagBits",
        .bit_name = "ImageUsageBit",
        .flags_name = "ImageUsageFlags",
        .raw_flags_name = "VkImageUsageFlags",
        .constant_prefix = "VK_IMAGE_USAGE_",
    },
    .{
        .registry_name = "VkImageCreateFlagBits",
        .bit_name = "ImageCreateBit",
        .flags_name = "ImageCreateFlags",
        .raw_flags_name = "VkImageCreateFlags",
        .constant_prefix = "VK_IMAGE_CREATE_",
    },
    .{
        .registry_name = "VkSampleCountFlagBits",
        .bit_name = "SampleCountBit",
        .flags_name = "SampleCountFlags",
        .raw_flags_name = "VkSampleCountFlags",
        .constant_prefix = "VK_SAMPLE_COUNT_",
    },
    .{
        .registry_name = "VkFenceCreateFlagBits",
        .bit_name = "FenceCreateBit",
        .flags_name = "FenceCreateFlags",
        .raw_flags_name = "VkFenceCreateFlags",
        .constant_prefix = "VK_FENCE_CREATE_",
    },
    .{
        .registry_name = "VkFormatFeatureFlagBits",
        .bit_name = "FormatFeatureBit",
        .flags_name = "FormatFeatureFlags",
        .raw_flags_name = "VkFormatFeatureFlags",
        .constant_prefix = "VK_FORMAT_FEATURE_",
    },
    .{
        .registry_name = "VkFormatFeatureFlagBits2",
        .bit_name = "FormatFeature2Bit",
        .flags_name = "FormatFeature2Flags",
        .raw_flags_name = "VkFormatFeatureFlags2",
        .constant_prefix = "VK_FORMAT_FEATURE_2_",
    },
    .{
        .registry_name = "VkExternalMemoryHandleTypeFlagBits",
        .bit_name = "ExternalMemoryHandleTypeBit",
        .flags_name = "ExternalMemoryHandleTypeFlags",
        .raw_flags_name = "VkExternalMemoryHandleTypeFlags",
        .constant_prefix = "VK_EXTERNAL_MEMORY_HANDLE_TYPE_",
    },
    .{
        .registry_name = "VkExternalMemoryFeatureFlagBits",
        .bit_name = "ExternalMemoryFeatureBit",
        .flags_name = "ExternalMemoryFeatureFlags",
        .raw_flags_name = "VkExternalMemoryFeatureFlags",
        .constant_prefix = "VK_EXTERNAL_MEMORY_FEATURE_",
    },
    .{
        .registry_name = "VkCommandBufferUsageFlagBits",
        .bit_name = "CommandBufferUsageBit",
        .flags_name = "CommandBufferUsageFlags",
        .raw_flags_name = "VkCommandBufferUsageFlags",
        .constant_prefix = "VK_COMMAND_BUFFER_USAGE_",
    },
    .{
        .registry_name = "VkImageAspectFlagBits",
        .bit_name = "ImageAspectBit",
        .flags_name = "ImageAspectFlags",
        .raw_flags_name = "VkImageAspectFlags",
        .constant_prefix = "VK_IMAGE_ASPECT_",
    },
    .{
        .registry_name = "VkPipelineStageFlagBits",
        .bit_name = "PipelineStageBit",
        .flags_name = "PipelineStageFlags",
        .raw_flags_name = "VkPipelineStageFlags",
        .constant_prefix = "VK_PIPELINE_STAGE_",
    },
    .{
        .registry_name = "VkPipelineStageFlagBits2",
        .bit_name = "PipelineStage2Bit",
        .flags_name = "PipelineStage2Flags",
        .raw_flags_name = "VkPipelineStageFlags2",
        .constant_prefix = "VK_PIPELINE_STAGE_2_",
    },
    .{
        .registry_name = "VkSubmitFlagBits",
        .bit_name = "SubmitBit",
        .flags_name = "SubmitFlags",
        .raw_flags_name = "VkSubmitFlags",
        .constant_prefix = "VK_SUBMIT_",
    },
    .{
        .registry_name = "VkCommandPoolCreateFlagBits",
        .bit_name = "CommandPoolCreateBit",
        .flags_name = "CommandPoolCreateFlags",
        .raw_flags_name = "VkCommandPoolCreateFlags",
        .constant_prefix = "VK_COMMAND_POOL_CREATE_",
    },
    .{
        .registry_name = "VkCompositeAlphaFlagBitsKHR",
        .bit_name = "CompositeAlphaBit",
        .flags_name = "CompositeAlphaFlags",
        .raw_flags_name = "VkCompositeAlphaFlagsKHR",
        .constant_prefix = "VK_COMPOSITE_ALPHA_",
        .terminal_token = "KHR",
    },
    .{
        .registry_name = "VkSurfaceTransformFlagBitsKHR",
        .bit_name = "SurfaceTransformBit",
        .flags_name = "SurfaceTransformFlags",
        .raw_flags_name = "VkSurfaceTransformFlagsKHR",
        .constant_prefix = "VK_SURFACE_TRANSFORM_",
        .terminal_token = "KHR",
    },
    .{
        .registry_name = "VkSwapchainCreateFlagBitsKHR",
        .bit_name = "SwapchainCreateBit",
        .flags_name = "SwapchainCreateFlags",
        .raw_flags_name = "VkSwapchainCreateFlagsKHR",
        .constant_prefix = "VK_SWAPCHAIN_CREATE_",
        .terminal_token = "KHR",
    },
    .{
        .registry_name = "VkSparseImageFormatFlagBits",
        .bit_name = "SparseImageFormatBit",
        .flags_name = "SparseImageFormatFlags",
        .raw_flags_name = "VkSparseImageFormatFlags",
        .constant_prefix = "VK_SPARSE_IMAGE_FORMAT_",
    },
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

    var binding_constants: std.StringHashMapUnmanaged(void) = .empty;
    defer binding_constants.deinit(gpa);
    try collectBindingConstants(gpa, bindings, &binding_constants);

    var output: std.Io.Writer.Allocating = .init(gpa);
    defer output.deinit();
    try writeHeader(&output.writer);
    for (enum_specs) |spec| {
        try writeEnum(gpa, &output.writer, registry, &binding_constants, spec);
    }
    for (flag_specs) |spec| {
        try writeFlags(gpa, &output.writer, registry, &binding_constants, spec);
    }
    try writeValueTypes(&output.writer);

    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = args[3],
        .data = output.written(),
    });
}

fn collectBindingConstants(
    gpa: std.mem.Allocator,
    bindings: []const u8,
    constants: *std.StringHashMapUnmanaged(void),
) !void {
    var lines = std.mem.splitScalar(u8, bindings, '\n');
    while (lines.next()) |line| {
        const prefix = "pub const VK_";
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        const name_end = std.mem.indexOfScalarPos(u8, line, "pub const ".len, ':') orelse {
            continue;
        };
        try constants.put(gpa, line["pub const ".len..name_end], {});
    }
}

fn writeEnum(
    gpa: std.mem.Allocator,
    writer: *std.Io.Writer,
    registry: []const u8,
    binding_constants: *const std.StringHashMapUnmanaged(void),
    spec: EnumSpec,
) !void {
    try writer.print("\npub const {s} = enum(raw.{s}) {{\n", .{ spec.zig_name, spec.raw_name });
    var generated_names: std.StringHashMapUnmanaged([]const u8) = .empty;
    defer freeKeys(gpa, &generated_names);
    try writeGroupEntries(
        gpa,
        writer,
        registry,
        binding_constants,
        spec.registry_name,
        spec.constant_prefix,
        spec.terminal_token,
        &generated_names,
    );
    try writeEnumFooter(writer, spec.raw_name);
}

fn writeFlags(
    gpa: std.mem.Allocator,
    writer: *std.Io.Writer,
    registry: []const u8,
    binding_constants: *const std.StringHashMapUnmanaged(void),
    spec: FlagSpec,
) !void {
    try writer.print(
        "\npub const {s} = enum(raw.{s}) {{\n",
        .{ spec.bit_name, spec.raw_flags_name },
    );
    var generated_names: std.StringHashMapUnmanaged([]const u8) = .empty;
    defer freeKeys(gpa, &generated_names);
    try writeGroupEntries(
        gpa,
        writer,
        registry,
        binding_constants,
        spec.registry_name,
        spec.constant_prefix,
        spec.terminal_token,
        &generated_names,
    );
    try writeEnumFooter(writer, spec.raw_flags_name);
    try writer.print(
        "pub const {s} = Flags(raw.{s}, {s});\n",
        .{ spec.flags_name, spec.raw_flags_name, spec.bit_name },
    );
}

fn writeGroupEntries(
    gpa: std.mem.Allocator,
    writer: *std.Io.Writer,
    registry: []const u8,
    binding_constants: *const std.StringHashMapUnmanaged(void),
    registry_name: []const u8,
    constant_prefix: []const u8,
    terminal_token: ?[]const u8,
    generated_names: *std.StringHashMapUnmanaged([]const u8),
) !void {
    var marker_buffer: [generated_name_size_max]u8 = undefined;
    const marker = try std.fmt.bufPrint(
        &marker_buffer,
        "<enums name=\"{s}\"",
        .{registry_name},
    );
    const group_start = std.mem.indexOf(u8, registry, marker) orelse {
        return error.MissingRegistryGroup;
    };
    const group_end = std.mem.indexOfPos(u8, registry, group_start, "</enums>") orelse {
        return error.InvalidRegistry;
    };
    try writeEntryTags(
        gpa,
        writer,
        registry[group_start..group_end],
        binding_constants,
        null,
        constant_prefix,
        terminal_token,
        generated_names,
    );
    try writeEntryTags(
        gpa,
        writer,
        registry,
        binding_constants,
        registry_name,
        constant_prefix,
        terminal_token,
        generated_names,
    );
}

fn writeEntryTags(
    gpa: std.mem.Allocator,
    writer: *std.Io.Writer,
    xml: []const u8,
    binding_constants: *const std.StringHashMapUnmanaged(void),
    required_extends: ?[]const u8,
    constant_prefix: []const u8,
    terminal_token: ?[]const u8,
    generated_names: *std.StringHashMapUnmanaged([]const u8),
) !void {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, xml, cursor, "<enum ")) |tag_start| {
        const tag_end = std.mem.indexOfScalarPos(u8, xml, tag_start, '>') orelse {
            return error.InvalidRegistry;
        };
        const tag = xml[tag_start .. tag_end + 1];
        cursor = tag_end + 1;
        if (attribute(tag, "alias") != null) continue;
        if (required_extends) |expected| {
            const actual = attribute(tag, "extends") orelse continue;
            if (!std.mem.eql(u8, actual, expected)) continue;
        } else if (attribute(tag, "extends") != null) {
            continue;
        }
        const constant_name = attribute(tag, "name") orelse return error.InvalidRegistry;
        if (!binding_constants.contains(constant_name)) continue;
        if (!std.mem.startsWith(u8, constant_name, constant_prefix)) continue;

        var name_buffer: [generated_name_size_max]u8 = undefined;
        const generated_name = try generatedTagName(
            constant_name,
            constant_prefix,
            terminal_token,
            &name_buffer,
        );
        const result = try generated_names.getOrPut(gpa, generated_name);
        if (result.found_existing) {
            if (std.mem.eql(u8, result.value_ptr.*, constant_name)) continue;
            std.log.err(
                "duplicate Vulkan tag '{s}' from {s} and {s}",
                .{ generated_name, result.value_ptr.*, constant_name },
            );
            return error.DuplicateGeneratedName;
        }
        result.key_ptr.* = try gpa.dupe(u8, generated_name);
        result.value_ptr.* = constant_name;
        try writer.print(
            "    @\"{s}\" = @intCast(raw.{s}),\n",
            .{ generated_name, constant_name },
        );
    }
}

fn generatedTagName(
    constant_name: []const u8,
    constant_prefix: []const u8,
    terminal_token: ?[]const u8,
    buffer: []u8,
) ![]const u8 {
    var source = constant_name[constant_prefix.len..];
    if (terminal_token) |token| {
        var suffix_buffer: [32]u8 = undefined;
        const suffix = try std.fmt.bufPrint(&suffix_buffer, "_{s}", .{token});
        if (std.mem.endsWith(u8, source, suffix)) {
            source = source[0 .. source.len - suffix.len];
        }
    }

    var length: usize = 0;
    if (source.len > 0 and std.ascii.isDigit(source[0])) {
        buffer[length] = '_';
        length += 1;
    }
    var tokens = std.mem.splitScalar(u8, source, '_');
    while (tokens.next()) |token| {
        if (std.mem.eql(u8, token, "BIT")) continue;
        if (length > 0 and buffer[length - 1] != '_') {
            if (length == buffer.len) return error.NameTooLong;
            buffer[length] = '_';
            length += 1;
        }
        if (length + token.len > buffer.len) return error.NameTooLong;
        for (token, buffer[length .. length + token.len]) |character, *output| {
            output.* = std.ascii.toLower(character);
        }
        length += token.len;
    }
    if (length == 0) return error.InvalidGeneratedName;
    if (isZigKeyword(buffer[0..length])) {
        if (length == buffer.len) return error.NameTooLong;
        buffer[length] = '_';
        length += 1;
    }
    return buffer[0..length];
}

fn isZigKeyword(name: []const u8) bool {
    const keywords = [_][]const u8{
        "addrspace", "align",     "allowzero",   "and",         "anyframe",
        "anytype",   "asm",       "async",       "await",       "break",
        "callconv",  "catch",     "comptime",    "const",       "continue",
        "defer",     "else",      "enum",        "errdefer",    "error",
        "export",    "extern",    "false",       "fn",          "for",
        "if",        "inline",    "linksection", "noalias",     "noinline",
        "nosuspend", "null",      "opaque",      "or",          "orelse",
        "packed",    "pub",       "resume",      "return",      "struct",
        "suspend",   "switch",    "test",        "threadlocal", "true",
        "try",       "undefined", "union",       "unreachable", "usingnamespace",
        "var",       "volatile",  "while",
    };
    for (keywords) |keyword| {
        if (std.mem.eql(u8, name, keyword)) return true;
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

fn freeKeys(
    gpa: std.mem.Allocator,
    names: *std.StringHashMapUnmanaged([]const u8),
) void {
    var iterator = names.keyIterator();
    while (iterator.next()) |name| gpa.free(name.*);
    names.deinit(gpa);
}

fn writeEnumFooter(writer: *std.Io.Writer, raw_name: []const u8) !void {
    try writer.print(
        \\    _,
        \\
        \\    pub fn fromRaw(value: raw.{s}) @This() {{
        \\        return @enumFromInt(value);
        \\    }}
        \\
        \\    pub fn toRaw(value: @This()) raw.{s} {{
        \\        return @intFromEnum(value);
        \\    }}
        \\}};
        \\
    , .{ raw_name, raw_name });
}

fn writeHeader(writer: *std.Io.Writer) !void {
    try writer.writeAll(
        \\// Generated from the Vulkan registry. Do not edit.
        \\const std = @import("std");
        \\const raw = @import("vulkan_raw");
        \\
        \\pub fn Flags(comptime Raw: type, comptime Bit: type) type {
        \\    const raw_info = @typeInfo(Raw);
        \\    if (raw_info != .int) @compileError("Vulkan flag storage must be an integer");
        \\    const bit_info = @typeInfo(Bit);
        \\    if (bit_info != .@"enum") @compileError("Vulkan flag bit must be an enum");
        \\    if (bit_info.@"enum".tag_type != Raw) {
        \\        @compileError("Vulkan flag bit and storage representations differ");
        \\    }
        \\    return struct {
        \\        bits: Raw = 0,
        \\
        \\        const Set = @This();
        \\
        \\        pub const empty: Set = .{};
        \\
        \\        pub fn init(values: []const Bit) Set {
        \\            var set: Set = .empty;
        \\            for (values) |value| set.bits |= @intFromEnum(value);
        \\            return set;
        \\        }
        \\
        \\        pub fn fromRaw(bits: Raw) Set {
        \\            return .{ .bits = bits };
        \\        }
        \\
        \\        pub fn toRaw(set: Set) Raw {
        \\            return set.bits;
        \\        }
        \\
        \\        pub fn with(set: Set, value: Bit) Set {
        \\            return .fromRaw(set.bits | @intFromEnum(value));
        \\        }
        \\
        \\        pub fn without(set: Set, value: Bit) Set {
        \\            return .fromRaw(set.bits & ~@intFromEnum(value));
        \\        }
        \\
        \\        pub fn merge(set: Set, other: Set) Set {
        \\            return .fromRaw(set.bits | other.bits);
        \\        }
        \\
        \\        pub fn contains(set: Set, value: Bit) bool {
        \\            const mask = @intFromEnum(value);
        \\            return (set.bits & mask) == mask;
        \\        }
        \\
        \\        pub fn containsAll(set: Set, other: Set) bool {
        \\            return (set.bits & other.bits) == other.bits;
        \\        }
        \\
        \\        pub fn isEmpty(set: Set) bool {
        \\            return set.bits == 0;
        \\        }
        \\    };
        \\}
    );
}

fn writeValueTypes(writer: *std.Io.Writer) !void {
    try writer.writeAll(
        \\pub const Extent2D = struct {
        \\    width: u32,
        \\    height: u32,
        \\
        \\    pub fn fromRaw(value: raw.VkExtent2D) Extent2D {
        \\        return .{ .width = value.width, .height = value.height };
        \\    }
        \\
        \\    pub fn toRaw(value: Extent2D) raw.VkExtent2D {
        \\        return .{ .width = value.width, .height = value.height };
        \\    }
        \\};
        \\
        \\pub const Extent3D = struct {
        \\    width: u32,
        \\    height: u32,
        \\    depth: u32,
        \\
        \\    pub fn fromRaw(value: raw.VkExtent3D) Extent3D {
        \\        return .{ .width = value.width, .height = value.height, .depth = value.depth };
        \\    }
        \\
        \\    pub fn toRaw(value: Extent3D) raw.VkExtent3D {
        \\        return .{ .width = value.width, .height = value.height, .depth = value.depth };
        \\    }
        \\};
        \\
        \\pub const SurfaceFormat = extern struct {
        \\    format: Format,
        \\    color_space: ColorSpace,
        \\
        \\    pub fn fromRaw(value: raw.VkSurfaceFormatKHR) SurfaceFormat {
        \\        return .{ .format = .fromRaw(value.format),
        \\            .color_space = .fromRaw(value.colorSpace) };
        \\    }
        \\
        \\    pub fn toRaw(value: SurfaceFormat) raw.VkSurfaceFormatKHR {
        \\        return .{ .format = value.format.toRaw(),
        \\            .colorSpace = value.color_space.toRaw() };
        \\    }
        \\};
        \\
        \\comptime {
        \\    if (@sizeOf(SurfaceFormat) != @sizeOf(raw.VkSurfaceFormatKHR)) {
        \\        @compileError("typed and raw Vulkan surface formats differ in size");
        \\    }
        \\    if (@alignOf(SurfaceFormat) != @alignOf(raw.VkSurfaceFormatKHR)) {
        \\        @compileError("typed and raw Vulkan surface formats differ in alignment");
        \\    }
        \\}
        \\
        \\pub const SurfaceCapabilities = struct {
        \\    image_count_min: u32,
        \\    /// `null` means the surface does not advertise a maximum image count.
        \\    image_count_max: ?u32,
        \\    /// `null` means the application chooses an extent within `extent_min` and `extent_max`.
        \\    extent_current: ?Extent2D,
        \\    extent_min: Extent2D,
        \\    extent_max: Extent2D,
        \\    image_array_layer_count_max: u32,
        \\    transforms_supported: SurfaceTransformFlags,
        \\    transform_current: SurfaceTransformBit,
        \\    composite_alpha_supported: CompositeAlphaFlags,
        \\    image_usage_supported: ImageUsageFlags,
        \\
        \\    pub fn fromRaw(value: raw.VkSurfaceCapabilitiesKHR) SurfaceCapabilities {
        \\        const variable_width = value.currentExtent.width == std.math.maxInt(u32);
        \\        const variable_height = value.currentExtent.height == std.math.maxInt(u32);
        \\        std.debug.assert(variable_width == variable_height);
        \\        return .{
        \\            .image_count_min = value.minImageCount,
        \\            .image_count_max = if (value.maxImageCount == 0)
        \\                null
        \\            else
        \\                value.maxImageCount,
        \\            .extent_current = if (variable_width) null else .fromRaw(value.currentExtent),
        \\            .extent_min = .fromRaw(value.minImageExtent),
        \\            .extent_max = .fromRaw(value.maxImageExtent),
        \\            .image_array_layer_count_max = value.maxImageArrayLayers,
        \\            .transforms_supported = .fromRaw(value.supportedTransforms),
        \\            .transform_current = .fromRaw(value.currentTransform),
        \\            .composite_alpha_supported = .fromRaw(value.supportedCompositeAlpha),
        \\            .image_usage_supported = .fromRaw(value.supportedUsageFlags),
        \\        };
        \\    }
        \\};
        \\
        \\pub const Offset2D = struct {
        \\    x: i32,
        \\    y: i32,
        \\
        \\    pub fn fromRaw(value: raw.VkOffset2D) Offset2D {
        \\        return .{ .x = value.x, .y = value.y };
        \\    }
        \\
        \\    pub fn toRaw(value: Offset2D) raw.VkOffset2D {
        \\        return .{ .x = value.x, .y = value.y };
        \\    }
        \\};
        \\
        \\pub const Offset3D = struct {
        \\    x: i32,
        \\    y: i32,
        \\    z: i32,
        \\
        \\    pub fn fromRaw(value: raw.VkOffset3D) Offset3D {
        \\        return .{ .x = value.x, .y = value.y, .z = value.z };
        \\    }
        \\    pub fn toRaw(value: Offset3D) raw.VkOffset3D {
        \\        return .{ .x = value.x, .y = value.y, .z = value.z };
        \\    }
        \\};
        \\
        \\pub const Rect2D = struct {
        \\    offset: Offset2D,
        \\    extent: Extent2D,
        \\
        \\    pub fn fromRaw(value: raw.VkRect2D) Rect2D {
        \\        return .{ .offset = .fromRaw(value.offset), .extent = .fromRaw(value.extent) };
        \\    }
        \\
        \\    pub fn toRaw(value: Rect2D) raw.VkRect2D {
        \\        return .{ .offset = value.offset.toRaw(), .extent = value.extent.toRaw() };
        \\    }
        \\};
        \\
        \\pub const Viewport = struct {
        \\    x: f32,
        \\    y: f32,
        \\    width: f32,
        \\    height: f32,
        \\    min_depth: f32 = 0.0,
        \\    max_depth: f32 = 1.0,
        \\
        \\    pub fn fromRaw(value: raw.VkViewport) Viewport {
        \\        return .{ .x = value.x, .y = value.y, .width = value.width,
        \\            .height = value.height, .min_depth = value.minDepth,
        \\            .max_depth = value.maxDepth };
        \\    }
        \\
        \\    pub fn toRaw(value: Viewport) raw.VkViewport {
        \\        return .{ .x = value.x, .y = value.y, .width = value.width,
        \\            .height = value.height, .minDepth = value.min_depth,
        \\            .maxDepth = value.max_depth };
        \\    }
        \\};
        \\
        \\pub const ComponentMapping = struct {
        \\    red: ComponentSwizzle = .identity,
        \\    green: ComponentSwizzle = .identity,
        \\    blue: ComponentSwizzle = .identity,
        \\    alpha: ComponentSwizzle = .identity,
        \\
        \\    pub fn toRaw(value: ComponentMapping) raw.VkComponentMapping {
        \\        return .{ .r = value.red.toRaw(), .g = value.green.toRaw(),
        \\            .b = value.blue.toRaw(), .a = value.alpha.toRaw() };
        \\    }
        \\};
        \\
        \\pub const ImageSubresourceRange = struct {
        \\    aspect_mask: ImageAspectFlags,
        \\    base_mip_level: u32 = 0,
        \\    level_count: u32 = 1,
        \\    base_array_layer: u32 = 0,
        \\    layer_count: u32 = 1,
        \\
        \\    pub fn toRaw(value: ImageSubresourceRange) raw.VkImageSubresourceRange {
        \\        return .{ .aspectMask = value.aspect_mask.toRaw(),
        \\            .baseMipLevel = value.base_mip_level, .levelCount = value.level_count,
        \\            .baseArrayLayer = value.base_array_layer, .layerCount = value.layer_count };
        \\    }
        \\};
        \\
        \\pub const ClearColor = union(enum) {
        \\    float: [4]f32,
        \\    signed: [4]i32,
        \\    unsigned: [4]u32,
        \\
        \\    pub fn toRaw(value: ClearColor) raw.VkClearColorValue {
        \\        return switch (value) {
        \\            .float => |channels| .{ .float32 = channels },
        \\            .signed => |channels| .{ .int32 = channels },
        \\            .unsigned => |channels| .{ .uint32 = channels },
        \\        };
        \\    }
        \\};
        \\
        \\pub const ClearDepthStencil = struct {
        \\    depth: f32,
        \\    stencil: u32,
        \\
        \\    pub fn toRaw(value: ClearDepthStencil) raw.VkClearDepthStencilValue {
        \\        return .{ .depth = value.depth, .stencil = value.stencil };
        \\    }
        \\};
        \\
        \\pub const ClearValue = union(enum) {
        \\    color: ClearColor,
        \\    depth_stencil: ClearDepthStencil,
        \\
        \\    pub fn toRaw(value: ClearValue) raw.VkClearValue {
        \\        return switch (value) {
        \\            .color => |color| .{ .color = color.toRaw() },
        \\            .depth_stencil => |depth_stencil| .{
        \\                .depthStencil = depth_stencil.toRaw(),
        \\            },
        \\        };
        \\    }
        \\};
    );
}
