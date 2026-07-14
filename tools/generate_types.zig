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
    .{
        .registry_name = "VkValidationFeatureEnableEXT",
        .zig_name = "ValidationFeature",
        .raw_name = "VkValidationFeatureEnableEXT",
        .constant_prefix = "VK_VALIDATION_FEATURE_ENABLE_",
        .terminal_token = "EXT",
    },
    .{
        .registry_name = "VkValidationFeatureDisableEXT",
        .zig_name = "DisabledValidationFeature",
        .raw_name = "VkValidationFeatureDisableEXT",
        .constant_prefix = "VK_VALIDATION_FEATURE_DISABLE_",
        .terminal_token = "EXT",
    },
    .{
        .registry_name = "VkValidationCheckEXT",
        .zig_name = "DisabledValidationCheck",
        .raw_name = "VkValidationCheckEXT",
        .constant_prefix = "VK_VALIDATION_CHECK_",
        .terminal_token = "EXT",
    },
    .{
        .registry_name = "VkLayerSettingTypeEXT",
        .zig_name = "LayerSettingType",
        .raw_name = "VkLayerSettingTypeEXT",
        .constant_prefix = "VK_LAYER_SETTING_TYPE_",
        .terminal_token = "EXT",
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
        .registry_name = "VkBufferUsageFlagBits",
        .bit_name = "BufferUsageBit",
        .flags_name = "BufferUsageFlags",
        .raw_flags_name = "VkBufferUsageFlags",
        .constant_prefix = "VK_BUFFER_USAGE_",
    },
    .{
        .registry_name = "VkBufferCreateFlagBits",
        .bit_name = "BufferCreateBit",
        .flags_name = "BufferCreateFlags",
        .raw_flags_name = "VkBufferCreateFlags",
        .constant_prefix = "VK_BUFFER_CREATE_",
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
        .registry_name = "VkAccessFlagBits2",
        .bit_name = "Access2Bit",
        .flags_name = "Access2Flags",
        .raw_flags_name = "VkAccessFlags2",
        .constant_prefix = "VK_ACCESS_2_",
    },
    .{
        .registry_name = "VkDependencyFlagBits",
        .bit_name = "DependencyBit",
        .flags_name = "DependencyFlags",
        .raw_flags_name = "VkDependencyFlags",
        .constant_prefix = "VK_DEPENDENCY_",
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
    .{
        .registry_name = "VkDescriptorBindingFlagBits",
        .bit_name = "DescriptorBindingBit",
        .flags_name = "DescriptorBindingFlags",
        .raw_flags_name = "VkDescriptorBindingFlags",
        .constant_prefix = "VK_DESCRIPTOR_BINDING_",
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
    try writeRegistryEnums(gpa, &output.writer, registry, bindings, &binding_constants);
    for (flag_specs) |spec| {
        try writeFlags(gpa, &output.writer, registry, &binding_constants, spec);
    }
    try writeRegistryFlags(gpa, &output.writer, registry, bindings, &binding_constants);
    try writeFeatures(gpa, &output.writer, bindings);
    try writeExtensionFeatures(gpa, &output.writer, registry, bindings);
    try writeValueTypes(&output.writer);

    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = args[3],
        .data = output.written(),
    });
}

const FeatureStruct = struct {
    raw_name: []const u8,
    method_name: []const u8,
};

const feature_structs = [_]FeatureStruct{
    .{ .raw_name = "VkPhysicalDeviceFeatures", .method_name = "core10" },
    .{ .raw_name = "VkPhysicalDeviceVulkan11Features", .method_name = "vulkan11" },
    .{ .raw_name = "VkPhysicalDeviceVulkan12Features", .method_name = "vulkan12" },
    .{ .raw_name = "VkPhysicalDeviceVulkan13Features", .method_name = "vulkan13" },
    .{ .raw_name = "VkPhysicalDeviceVulkan14Features", .method_name = "vulkan14" },
};

const FeatureField = struct {
    raw_name: []const u8,
    zig_name: []const u8,
    owner: usize,
};

fn writeFeatures(gpa: std.mem.Allocator, writer: *std.Io.Writer, bindings: []const u8) !void {
    var fields: std.ArrayList(FeatureField) = .empty;
    defer {
        for (fields.items) |field| gpa.free(field.zig_name);
        fields.deinit(gpa);
    }
    var names: std.StringHashMapUnmanaged(void) = .empty;
    defer names.deinit(gpa);

    for (feature_structs, 0..) |feature_struct, owner| {
        var marker_buffer: [128]u8 = undefined;
        const marker = try std.fmt.bufPrint(&marker_buffer, "pub const struct_{s} = extern struct {{", .{feature_struct.raw_name});
        const start = std.mem.indexOf(u8, bindings, marker) orelse return error.MissingFeatureStruct;
        const body_start = start + marker.len;
        const end = std.mem.indexOfPos(u8, bindings, body_start, "\n};") orelse return error.InvalidBindings;
        var lines = std.mem.splitScalar(u8, bindings[body_start..end], '\n');
        while (lines.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, " \t\r");
            const separator = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            const raw_name = line[0..separator];
            if (std.mem.eql(u8, raw_name, "sType") or std.mem.eql(u8, raw_name, "pNext")) continue;
            if (std.mem.indexOf(u8, line[separator + 1 ..], "VkBool32") == null) continue;
            var name_buffer: [generated_name_size_max]u8 = undefined;
            const zig_name = try camelToSnake(raw_name, &name_buffer);
            if (names.contains(zig_name)) return error.DuplicateFeatureName;
            try names.put(gpa, try gpa.dupe(u8, zig_name), {});
            try fields.append(gpa, .{
                .raw_name = raw_name,
                .zig_name = try gpa.dupe(u8, zig_name),
                .owner = owner,
            });
        }
    }
    defer {
        var iterator = names.keyIterator();
        while (iterator.next()) |name| gpa.free(name.*);
    }

    try writer.writeAll("\npub const Feature = enum {\n");
    for (fields.items) |field| try writer.print("    {s},\n", .{field.zig_name});
    try writer.writeAll(
        \\};
        \\
        \\pub const FeatureSet = struct {
        \\    bits: std.EnumSet(Feature) = .initEmpty(),
        \\
        \\    pub const empty: FeatureSet = .{};
        \\
        \\    pub fn init(features: []const Feature) FeatureSet {
        \\        var set: FeatureSet = .empty;
        \\        for (features) |feature| set.bits.insert(feature);
        \\        return set;
        \\    }
        \\
        \\    pub fn contains(set: FeatureSet, feature: Feature) bool {
        \\        return set.bits.contains(feature);
        \\    }
        \\
        \\    pub fn enable(set: *FeatureSet, feature: Feature) void {
        \\        set.bits.insert(feature);
        \\    }
        \\
        \\    pub fn containsAll(set: FeatureSet, required: FeatureSet) bool {
        \\        return set.bits.supersetOf(required.bits);
        \\    }
        \\
        \\    pub fn firstMissing(set: FeatureSet, required: FeatureSet) ?Feature {
        \\        inline for (std.meta.tags(Feature)) |feature| {
        \\            if (required.contains(feature) and !set.contains(feature)) return feature;
        \\        }
        \\        return null;
        \\    }
        \\
    );
    for (feature_structs, 0..) |feature_struct, owner| {
        try writer.print("    pub fn {s}Raw(set: FeatureSet) raw.{s} {{\n", .{ feature_struct.method_name, feature_struct.raw_name });
        if (owner == 0) {
            try writer.writeAll("        var value: raw.VkPhysicalDeviceFeatures = .{};\n");
        } else {
            try writer.print("        var value: raw.{s} = .{{ .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_{d}_{d}_FEATURES }};\n", .{
                feature_struct.raw_name,
                1,
                owner,
            });
        }
        for (fields.items) |field| if (field.owner == owner) {
            try writer.print("        if (set.contains(.{s})) value.{s} = raw.VK_TRUE;\n", .{ field.zig_name, field.raw_name });
        };
        try writer.writeAll("        return value;\n    }\n\n");
    }
    try writer.writeAll("    pub fn fromRaw(\n");
    for (feature_structs) |feature_struct| {
        try writer.print("        {s}: *const raw.{s},\n", .{ feature_struct.method_name, feature_struct.raw_name });
    }
    try writer.writeAll("    ) FeatureSet {\n        var set: FeatureSet = .empty;\n");
    for (fields.items) |field| {
        try writer.print("        if ({s}.{s} != raw.VK_FALSE) set.enable(.{s});\n", .{
            feature_structs[field.owner].method_name,
            field.raw_name,
            field.zig_name,
        });
    }
    try writer.writeAll(
        \\        return set;
        \\    }
        \\
        \\    pub fn coreRaw(set: FeatureSet) raw.VkPhysicalDeviceFeatures {
        \\        return set.core10Raw();
        \\    }
        \\
        \\    pub fn fromCoreRaw(value: *const raw.VkPhysicalDeviceFeatures) FeatureSet {
        \\        var empty11: raw.VkPhysicalDeviceVulkan11Features = .{};
        \\        var empty12: raw.VkPhysicalDeviceVulkan12Features = .{};
        \\        var empty13: raw.VkPhysicalDeviceVulkan13Features = .{};
        \\        var empty14: raw.VkPhysicalDeviceVulkan14Features = .{};
        \\        return fromRaw(value, &empty11, &empty12, &empty13, &empty14);
        \\    }
        \\
        \\    pub fn hasPromoted(set: FeatureSet) bool {
        \\        inline for (std.meta.tags(Feature)) |feature| switch (feature) {
        \\
    );
    for (fields.items) |field| if (field.owner != 0) {
        try writer.print("            .{s},\n", .{field.zig_name});
    };
    try writer.writeAll(
        \\            => if (set.contains(feature)) return true,
        \\            else => {},
        \\        };
        \\        return false;
        \\    }
        \\};
        \\
    );
}

fn writeExtensionFeatures(
    gpa: std.mem.Allocator,
    writer: *std.Io.Writer,
    registry: []const u8,
    bindings: []const u8,
) !void {
    var generated_names: std.StringHashMapUnmanaged(void) = .empty;
    defer generated_names.deinit(gpa);
    try writer.writeAll("\npub const extension_features = struct {\n");
    var generated_count: usize = 0;
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, registry, cursor, "<type category=\"struct\"")) |start| {
        const opening_end = std.mem.indexOfScalarPos(u8, registry, start, '>') orelse return error.InvalidRegistry;
        const opening = registry[start .. opening_end + 1];
        cursor = opening_end + 1;
        const raw_name = attribute(opening, "name") orelse continue;
        const parents = attribute(opening, "structextends") orelse continue;
        if (std.mem.indexOf(u8, parents, "VkPhysicalDeviceFeatures2") == null or
            std.mem.indexOf(u8, parents, "VkDeviceCreateInfo") == null or
            !std.mem.startsWith(u8, raw_name, "VkPhysicalDevice") or
            attribute(opening, "alias") != null)
        {
            continue;
        }
        const close_line = std.mem.indexOfPos(u8, registry, opening_end, "\n        </type>") orelse continue;
        const close = close_line + "\n        ".len;
        const body = registry[opening_end + 1 .. close];
        cursor = close + "</type>".len;

        var raw_marker_buffer: [generated_name_size_max]u8 = undefined;
        const raw_marker = try std.fmt.bufPrint(&raw_marker_buffer, "pub const struct_{s} = extern struct {{", .{raw_name});
        if (std.mem.indexOf(u8, bindings, raw_marker) == null) continue;

        const structure_type = memberStructureType(body) orelse continue;
        var constant_marker_buffer: [generated_name_size_max]u8 = undefined;
        const constant_marker = try std.fmt.bufPrint(&constant_marker_buffer, "pub const {s}:", .{structure_type});
        if (std.mem.indexOf(u8, bindings, constant_marker) == null) continue;

        const zig_name = raw_name["VkPhysicalDevice".len..];
        if (zig_name.len == 0 or std.mem.startsWith(u8, zig_name, "Vulkan1")) continue;
        try writer.print("    pub const @\"{s}\" = struct {{\n", .{zig_name});

        var member_cursor: usize = 0;
        var field_count: usize = 0;
        while (std.mem.indexOfPos(u8, body, member_cursor, "<member")) |member_start| {
            const member_end = std.mem.indexOfPos(u8, body, member_start, "</member>") orelse break;
            const member = body[member_start .. member_end + "</member>".len];
            member_cursor = member_end + "</member>".len;
            if (std.mem.indexOf(u8, member, "<type>VkBool32</type>") == null) continue;
            const raw_field = elementText(member, "name") orelse continue;
            var field_buffer: [generated_name_size_max]u8 = undefined;
            const field = try camelToSnake(raw_field, &field_buffer);
            try writer.print("        {s}: bool = false,\n", .{field});
            field_count += 1;
        }
        if (field_count == 0) {
            try writer.writeAll("        _unused: bool = false,\n");
        }
        try writer.print(
            "        pub const Raw = raw.{s};\n        pub const structure_type: raw.VkStructureType = @intCast(raw.{s});\n",
            .{ raw_name, structure_type },
        );
        try writer.writeAll("        pub fn toRaw(value: @This(), next: ?*anyopaque) Raw {\n            return .{ .sType = structure_type, .pNext = next");
        member_cursor = 0;
        while (std.mem.indexOfPos(u8, body, member_cursor, "<member")) |member_start| {
            const member_end = std.mem.indexOfPos(u8, body, member_start, "</member>") orelse break;
            const member = body[member_start .. member_end + "</member>".len];
            member_cursor = member_end + "</member>".len;
            if (std.mem.indexOf(u8, member, "<type>VkBool32</type>") == null) continue;
            const raw_field = elementText(member, "name") orelse continue;
            var field_buffer: [generated_name_size_max]u8 = undefined;
            const field = try camelToSnake(raw_field, &field_buffer);
            try writer.print(", .{s} = if (value.{s}) raw.VK_TRUE else raw.VK_FALSE", .{ raw_field, field });
        }
        try writer.writeAll(" };\n        }\n        pub fn fromRaw(value: *const Raw) @This() {\n            return .{");
        member_cursor = 0;
        while (std.mem.indexOfPos(u8, body, member_cursor, "<member")) |member_start| {
            const member_end = std.mem.indexOfPos(u8, body, member_start, "</member>") orelse break;
            const member = body[member_start .. member_end + "</member>".len];
            member_cursor = member_end + "</member>".len;
            if (std.mem.indexOf(u8, member, "<type>VkBool32</type>") == null) continue;
            const raw_field = elementText(member, "name") orelse continue;
            var field_buffer: [generated_name_size_max]u8 = undefined;
            const field = try camelToSnake(raw_field, &field_buffer);
            try writer.print(" .{s} = value.{s} != raw.VK_FALSE,", .{ field, raw_field });
        }
        try writer.writeAll(" };\n        }\n    };\n");
        try generated_names.put(gpa, raw_name, {});
        generated_count += 1;
    }
    if (generated_count == 0) return error.MissingExtensionFeatureStructs;

    cursor = 0;
    while (std.mem.indexOfPos(u8, registry, cursor, "<type category=\"struct\"")) |start| {
        const opening_end = std.mem.indexOfScalarPos(u8, registry, start, '>') orelse return error.InvalidRegistry;
        const opening = registry[start .. opening_end + 1];
        cursor = opening_end + 1;
        const alias_name = attribute(opening, "name") orelse continue;
        const canonical_name = attribute(opening, "alias") orelse continue;
        if (!std.mem.startsWith(u8, alias_name, "VkPhysicalDevice") or
            !generated_names.contains(canonical_name)) continue;
        var alias_marker_buffer: [generated_name_size_max * 2]u8 = undefined;
        const alias_marker = try std.fmt.bufPrint(
            &alias_marker_buffer,
            "pub const {s} = {s};",
            .{ alias_name, canonical_name },
        );
        if (std.mem.indexOf(u8, bindings, alias_marker) == null) continue;
        try writer.print(
            "    pub const @\"{s}\" = @\"{s}\";\n",
            .{ alias_name["VkPhysicalDevice".len..], canonical_name["VkPhysicalDevice".len..] },
        );
    }
    try writer.writeAll("};\n");
}

fn memberStructureType(body: []const u8) ?[]const u8 {
    const marker = "values=\"VK_STRUCTURE_TYPE_";
    const start = std.mem.indexOf(u8, body, marker) orelse return null;
    const value_start = start + "values=\"".len;
    const end = std.mem.indexOfScalarPos(u8, body, value_start, '"') orelse return null;
    return body[value_start..end];
}

fn elementText(xml: []const u8, element: []const u8) ?[]const u8 {
    var opening_buffer: [64]u8 = undefined;
    var closing_buffer: [64]u8 = undefined;
    const opening = std.fmt.bufPrint(&opening_buffer, "<{s}>", .{element}) catch return null;
    const closing = std.fmt.bufPrint(&closing_buffer, "</{s}>", .{element}) catch return null;
    const start = std.mem.indexOf(u8, xml, opening) orelse return null;
    const value_start = start + opening.len;
    const end = std.mem.indexOfPos(u8, xml, value_start, closing) orelse return null;
    return xml[value_start..end];
}

fn camelToSnake(source: []const u8, buffer: []u8) ![]const u8 {
    const Override = struct { raw: []const u8, zig: []const u8 };
    const overrides = [_]Override{
        .{ .raw = "dualSrcBlend", .zig = "dual_source_blend" },
        .{ .raw = "sparseResidencyImage2D", .zig = "sparse_residency_image_2d" },
        .{ .raw = "sparseResidencyImage3D", .zig = "sparse_residency_image_3d" },
        .{ .raw = "sparseResidency2Samples", .zig = "sparse_residency_2_samples" },
        .{ .raw = "sparseResidency4Samples", .zig = "sparse_residency_4_samples" },
        .{ .raw = "sparseResidency8Samples", .zig = "sparse_residency_8_samples" },
        .{ .raw = "sparseResidency16Samples", .zig = "sparse_residency_16_samples" },
    };
    for (overrides) |override| if (std.mem.eql(u8, source, override.raw)) {
        if (override.zig.len > buffer.len) return error.NameTooLong;
        @memcpy(buffer[0..override.zig.len], override.zig);
        return buffer[0..override.zig.len];
    };
    var length: usize = 0;
    for (source, 0..) |character, index| {
        const upper = std.ascii.isUpper(character);
        const previous_lower_or_digit = index != 0 and (std.ascii.isLower(source[index - 1]) or std.ascii.isDigit(source[index - 1]));
        const acronym_boundary = index != 0 and upper and index + 1 < source.len and std.ascii.isLower(source[index + 1]) and std.ascii.isUpper(source[index - 1]);
        if (upper and (previous_lower_or_digit or acronym_boundary)) {
            if (length == buffer.len) return error.NameTooLong;
            buffer[length] = '_';
            length += 1;
        }
        if (length == buffer.len) return error.NameTooLong;
        buffer[length] = std.ascii.toLower(character);
        length += 1;
    }
    return buffer[0..length];
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

fn writeRegistryEnums(
    gpa: std.mem.Allocator,
    writer: *std.Io.Writer,
    registry: []const u8,
    bindings: []const u8,
    binding_constants: *const std.StringHashMapUnmanaged(void),
) !void {
    try writer.writeAll("\n/// Complete registry enum vocabulary; concise common aliases remain at module root.\npub const registry_enums = struct {\n");
    var cursor: usize = 0;
    var count: usize = 0;
    while (std.mem.indexOfPos(u8, registry, cursor, "<enums ")) |start| {
        const opening_end = std.mem.indexOfScalarPos(u8, registry, start, '>') orelse return error.InvalidRegistry;
        const opening = registry[start .. opening_end + 1];
        cursor = opening_end + 1;
        const raw_name = attribute(opening, "name") orelse continue;
        const group_type = attribute(opening, "type") orelse continue;
        if (!std.mem.eql(u8, group_type, "enum") or !std.mem.startsWith(u8, raw_name, "Vk")) continue;
        var type_marker_buffer: [generated_name_size_max]u8 = undefined;
        const type_marker = try std.fmt.bufPrint(&type_marker_buffer, "pub const {s} =", .{raw_name});
        if (std.mem.indexOf(u8, bindings, type_marker) == null) continue;

        try writer.print("    pub const @\"{s}\" = enum(raw.{s}) {{\n", .{ raw_name[2..], raw_name });
        var generated_names: std.StringHashMapUnmanaged([]const u8) = .empty;
        defer freeKeys(gpa, &generated_names);
        try writeGroupEntries(
            gpa,
            writer,
            registry,
            binding_constants,
            raw_name,
            "VK_",
            null,
            &generated_names,
        );
        try writeEnumFooter(writer, raw_name);
        count += 1;
    }
    if (count == 0) return error.MissingRegistryEnums;
    try writer.writeAll("};\n");
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

fn writeRegistryFlags(
    gpa: std.mem.Allocator,
    writer: *std.Io.Writer,
    registry: []const u8,
    bindings: []const u8,
    binding_constants: *const std.StringHashMapUnmanaged(void),
) !void {
    try writer.writeAll("\n/// Complete registry bitmask vocabulary with domain-specific sets.\npub const registry_flags = struct {\n");
    var cursor: usize = 0;
    var count: usize = 0;
    while (std.mem.indexOfPos(u8, registry, cursor, "<enums ")) |start| {
        const opening_end = std.mem.indexOfScalarPos(u8, registry, start, '>') orelse return error.InvalidRegistry;
        const opening = registry[start .. opening_end + 1];
        cursor = opening_end + 1;
        const bit_name = attribute(opening, "name") orelse continue;
        const group_type = attribute(opening, "type") orelse continue;
        if (!std.mem.eql(u8, group_type, "bitmask") or !std.mem.startsWith(u8, bit_name, "Vk")) continue;
        var flags_name_buffer: [generated_name_size_max]u8 = undefined;
        const flags_name = try deriveFlagsName(bit_name, &flags_name_buffer) orelse continue;
        var type_marker_buffer: [generated_name_size_max]u8 = undefined;
        const type_marker = try std.fmt.bufPrint(&type_marker_buffer, "pub const {s} =", .{flags_name});
        if (std.mem.indexOf(u8, bindings, type_marker) == null) continue;

        try writer.print("    pub const @\"{s}\" = struct {{\n        pub const Bit = enum(raw.{s}) {{\n", .{ bit_name[2..], flags_name });
        var generated_names: std.StringHashMapUnmanaged([]const u8) = .empty;
        defer freeKeys(gpa, &generated_names);
        try writeGroupEntries(
            gpa,
            writer,
            registry,
            binding_constants,
            bit_name,
            "VK_",
            null,
            &generated_names,
        );
        try writeEnumFooter(writer, flags_name);
        try writer.print("        pub const Set = Flags(raw.{s}, Bit);\n    }};\n", .{flags_name});
        count += 1;
    }
    if (count == 0) return error.MissingRegistryFlags;
    try writer.writeAll("};\n");
}

fn deriveFlagsName(bit_name: []const u8, buffer: []u8) !?[]const u8 {
    const bit_suffix, const flags_suffix = if (std.mem.endsWith(u8, bit_name, "FlagBits2"))
        .{ "FlagBits2", "Flags2" }
    else if (std.mem.endsWith(u8, bit_name, "FlagBits"))
        .{ "FlagBits", "Flags" }
    else
        return null;
    const prefix = bit_name[0 .. bit_name.len - bit_suffix.len];
    if (prefix.len + flags_suffix.len > buffer.len) return error.NameTooLong;
    @memcpy(buffer[0..prefix.len], prefix);
    @memcpy(buffer[prefix.len..][0..flags_suffix.len], flags_suffix);
    return buffer[0 .. prefix.len + flags_suffix.len];
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
        \\pub const MipLevelCount = union(enum) {
        \\    count: u32,
        \\    remaining,
        \\    pub fn fromRaw(value: u32) MipLevelCount { return if (value == raw.VK_REMAINING_MIP_LEVELS) .remaining else .{ .count = value }; }
        \\    pub fn toRaw(value: MipLevelCount) u32 { return switch (value) { .count => |count| count, .remaining => raw.VK_REMAINING_MIP_LEVELS }; }
        \\};
        \\pub const ArrayLayerCount = union(enum) {
        \\    count: u32,
        \\    remaining,
        \\    pub fn fromRaw(value: u32) ArrayLayerCount { return if (value == raw.VK_REMAINING_ARRAY_LAYERS) .remaining else .{ .count = value }; }
        \\    pub fn toRaw(value: ArrayLayerCount) u32 { return switch (value) { .count => |count| count, .remaining => raw.VK_REMAINING_ARRAY_LAYERS }; }
        \\};
        \\
        \\pub const ImageSubresourceRange = struct {
        \\    aspect_mask: ImageAspectFlags,
        \\    base_mip_level: u32 = 0,
        \\    level_count: MipLevelCount = .{ .count = 1 },
        \\    base_array_layer: u32 = 0,
        \\    layer_count: ArrayLayerCount = .{ .count = 1 },
        \\
        \\    pub fn toRaw(value: ImageSubresourceRange) raw.VkImageSubresourceRange {
        \\        return .{ .aspectMask = value.aspect_mask.toRaw(),
        \\            .baseMipLevel = value.base_mip_level, .levelCount = value.level_count.toRaw(),
        \\            .baseArrayLayer = value.base_array_layer, .layerCount = value.layer_count.toRaw() };
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
