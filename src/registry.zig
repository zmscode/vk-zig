const std = @import("std");
const raw = @import("vulkan_raw");
const core = @import("core.zig");

pub const name_count_max = 256;

pub const ExtensionProperty = struct {
    _name: [raw.VK_MAX_EXTENSION_NAME_SIZE]u8,
    revision: u32,

    pub fn fromRaw(property: raw.VkExtensionProperties) ExtensionProperty {
        return .{ ._name = property.extensionName, .revision = property.specVersion };
    }

    pub fn name(property: *const ExtensionProperty) []const u8 {
        return boundedCString(&property._name);
    }
};

pub const LayerProperty = struct {
    _name: [raw.VK_MAX_EXTENSION_NAME_SIZE]u8,
    spec_version: core.Version,
    implementation_version: core.Version,
    _description: [raw.VK_MAX_DESCRIPTION_SIZE]u8,

    pub fn fromRaw(property: raw.VkLayerProperties) LayerProperty {
        return .{
            ._name = property.layerName,
            .spec_version = .decode(property.specVersion),
            .implementation_version = .decode(property.implementationVersion),
            ._description = property.description,
        };
    }

    pub fn name(property: *const LayerProperty) []const u8 {
        return boundedCString(&property._name);
    }

    pub fn description(property: *const LayerProperty) []const u8 {
        return boundedCString(&property._description);
    }
};

/// A fixed-capacity, allocation-free set of unique extension or layer names.
pub fn NameSet(comptime capacity: usize) type {
    if (capacity > name_count_max) {
        @compileError("name-set capacity exceeds vk-zig's supported name count");
    }
    return struct {
        names: [capacity][:0]const u8 = undefined,
        count: usize = 0,

        const Set = @This();

        pub fn append(set: *Set, name: [:0]const u8) core.Error!void {
            if (set.contains(name)) return;
            if (set.count == capacity) return error.CountOverflow;
            set.names[set.count] = name;
            set.count += 1;
        }

        pub fn appendAll(set: *Set, names: []const [:0]const u8) core.Error!void {
            for (names) |name| try set.append(name);
        }

        pub fn appendPointerNames(set: *Set, names: []const [*:0]const u8) core.Error!void {
            for (names) |name| try set.append(std.mem.span(name));
        }

        pub fn contains(set: *const Set, expected: []const u8) bool {
            return containsName(set.slice(), expected);
        }

        pub fn slice(set: *const Set) []const [:0]const u8 {
            return set.names[0..set.count];
        }
    };
}

pub fn boundedCString(bytes: []const u8) []const u8 {
    const end = std.mem.indexOfScalar(u8, bytes, 0) orelse bytes.len;
    return bytes[0..end];
}

pub fn extensionName(property: *const raw.VkExtensionProperties) []const u8 {
    return boundedCString(&property.extensionName);
}

pub fn layerName(property: *const raw.VkLayerProperties) []const u8 {
    return boundedCString(&property.layerName);
}

pub fn layerDescription(property: *const raw.VkLayerProperties) []const u8 {
    return boundedCString(&property.description);
}

pub fn physicalDeviceName(property: *const raw.VkPhysicalDeviceProperties) []const u8 {
    return boundedCString(&property.deviceName);
}

pub fn supportsExtensionRaw(
    properties: []const raw.VkExtensionProperties,
    expected: []const u8,
) bool {
    for (properties) |*property| {
        if (std.mem.eql(u8, extensionName(property), expected)) return true;
    }
    return false;
}

pub fn supportsLayerRaw(properties: []const raw.VkLayerProperties, expected: []const u8) bool {
    for (properties) |*property| {
        if (std.mem.eql(u8, layerName(property), expected)) return true;
    }
    return false;
}

pub fn supportsExtension(properties: []const ExtensionProperty, expected: []const u8) bool {
    for (properties) |*property| {
        if (std.mem.eql(u8, property.name(), expected)) return true;
    }
    return false;
}

pub fn supportsLayer(properties: []const LayerProperty, expected: []const u8) bool {
    for (properties) |*property| {
        if (std.mem.eql(u8, property.name(), expected)) return true;
    }
    return false;
}

pub fn containsName(names: []const [:0]const u8, expected: []const u8) bool {
    for (names) |name| {
        if (std.mem.eql(u8, name, expected)) return true;
    }
    return false;
}
