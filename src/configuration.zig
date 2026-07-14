const std = @import("std");
const build_options = @import("vulkan_build_options");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const raw = @import("vulkan_raw");
const core = @import("core.zig");
const registry = @import("registry.zig");

pub const platform = build_options.platform;
pub const registry_commit = build_options.registry_commit;

pub const Layer = struct {
    name: [:0]const u8,
};

pub const layer = struct {
    pub const khronos_validation: Layer = .{ .name = "VK_LAYER_KHRONOS_validation" };
};

const portability_instance_extensions = [_][:0]const u8{
    "VK_KHR_portability_enumeration",
};
const portability_device_extensions = [_][:0]const u8{
    "VK_KHR_portability_subset",
};

pub const Portability = struct {
    pub fn instanceExtensions() []const [:0]const u8 {
        return if (platform == .metal) &portability_instance_extensions else &.{};
    }

    pub fn deviceExtensions() []const [:0]const u8 {
        return if (platform == .metal) &portability_device_extensions else &.{};
    }

    pub fn instanceFlags() types.InstanceCreateFlags {
        return if (platform == .metal)
            .init(&.{.enumerate_portability_khr})
        else
            .empty;
    }
};

const metal_surface_extensions = [_][:0]const u8{ "VK_KHR_surface", "VK_EXT_metal_surface" };
const win32_surface_extensions = [_][:0]const u8{ "VK_KHR_surface", "VK_KHR_win32_surface" };
const xlib_surface_extensions = [_][:0]const u8{ "VK_KHR_surface", "VK_KHR_xlib_surface" };
const xcb_surface_extensions = [_][:0]const u8{ "VK_KHR_surface", "VK_KHR_xcb_surface" };
const wayland_surface_extensions = [_][:0]const u8{ "VK_KHR_surface", "VK_KHR_wayland_surface" };
const android_surface_extensions = [_][:0]const u8{ "VK_KHR_surface", "VK_KHR_android_surface" };
const headless_surface_extensions = [_][:0]const u8{ "VK_KHR_surface", "VK_EXT_headless_surface" };

/// Instance extensions needed by the surface constructor selected at build time.
pub const SurfaceConfiguration = struct {
    pub fn instanceExtensions() []const [:0]const u8 {
        return switch (platform) {
            .metal => &metal_surface_extensions,
            .win32 => &win32_surface_extensions,
            .xlib => &xlib_surface_extensions,
            .xcb => &xcb_surface_extensions,
            .wayland => &wayland_surface_extensions,
            .android => &android_surface_extensions,
            .none => &.{},
        };
    }

    pub fn headlessInstanceExtensions() []const [:0]const u8 {
        return &headless_surface_extensions;
    }
};

pub const ValidationFeature = types.ValidationFeature;
pub const DisabledValidationFeature = types.DisabledValidationFeature;
pub const DisabledValidationCheck = types.DisabledValidationCheck;

pub const ValidationOptions = struct {
    enabled: []const ValidationFeature = &.{},
    disabled: []const DisabledValidationFeature = &.{},
    disabled_checks: []const DisabledValidationCheck = &.{},

    pub fn isEmpty(options: ValidationOptions) bool {
        return options.enabled.len == 0 and options.disabled.len == 0 and
            options.disabled_checks.len == 0;
    }
};

pub const LayerSettingValues = union(enum) {
    bools: []const bool,
    i32s: []const i32,
    i64s: []const i64,
    u32s: []const u32,
    u64s: []const u64,
    f32s: []const f32,
    f64s: []const f64,
    strings: []const [:0]const u8,

    pub fn len(values: LayerSettingValues) usize {
        return switch (values) {
            inline else => |items| items.len,
        };
    }
};

pub const LayerSetting = struct {
    layer_name: [:0]const u8,
    name: [:0]const u8,
    values: LayerSettingValues,
};

pub const instance_chain_node_count_max = 3;
pub const validation_feature_count_max = 32;
pub const layer_setting_count_max = 64;
pub const layer_setting_value_count_max = 256;

/// Caller-owned backing storage for typed `VkInstanceCreateInfo` extension nodes.
/// Build it only after the storage has reached its final address.
pub const InstanceChainStorage = struct {
    validation_enabled: [validation_feature_count_max]raw.VkValidationFeatureEnableEXT = undefined,
    validation_disabled: [validation_feature_count_max]raw.VkValidationFeatureDisableEXT = undefined,
    validation_checks: [validation_feature_count_max]raw.VkValidationCheckEXT = undefined,
    bool_values: [layer_setting_value_count_max]raw.VkBool32 = undefined,
    string_pointers: [layer_setting_value_count_max][*c]const u8 = undefined,
    settings: [layer_setting_count_max]raw.VkLayerSettingEXT = undefined,
    validation_features: raw.VkValidationFeaturesEXT = .{
        .sType = raw.VK_STRUCTURE_TYPE_VALIDATION_FEATURES_EXT,
    },
    validation_flags: raw.VkValidationFlagsEXT = .{
        .sType = raw.VK_STRUCTURE_TYPE_VALIDATION_FLAGS_EXT,
    },
    layer_settings: raw.VkLayerSettingsCreateInfoEXT = .{
        .sType = raw.VK_STRUCTURE_TYPE_LAYER_SETTINGS_CREATE_INFO_EXT,
    },

    pub fn link(
        storage: *InstanceChainStorage,
        validation: ValidationOptions,
        layer_setting_options: []const LayerSetting,
        tail: ?*const anyopaque,
    ) core.Error!?*const anyopaque {
        if (validation.enabled.len > validation_feature_count_max or
            validation.disabled.len > validation_feature_count_max or
            validation.disabled_checks.len > validation_feature_count_max or
            layer_setting_options.len > layer_setting_count_max)
        {
            return error.CountOverflow;
        }

        for (validation.enabled, 0..) |value, index| {
            storage.validation_enabled[index] = value.toRaw();
        }
        for (validation.disabled, 0..) |value, index| {
            storage.validation_disabled[index] = value.toRaw();
        }
        for (validation.disabled_checks, 0..) |value, index| {
            storage.validation_checks[index] = value.toRaw();
        }

        var bool_count: usize = 0;
        var string_count: usize = 0;
        for (layer_setting_options, 0..) |setting, index| {
            if (setting.values.len() == 0 or setting.values.len() > layer_setting_value_count_max) {
                return error.InvalidOptions;
            }
            for (layer_setting_options[0..index]) |previous| {
                if (std.mem.eql(u8, previous.layer_name, setting.layer_name) and
                    std.mem.eql(u8, previous.name, setting.name)) return error.InvalidOptions;
            }

            var raw_setting: raw.VkLayerSettingEXT = .{
                .pLayerName = setting.layer_name.ptr,
                .pSettingName = setting.name.ptr,
                .type = undefined,
                .valueCount = @intCast(setting.values.len()),
                .pValues = null,
            };
            switch (setting.values) {
                .bools => |values| {
                    if (values.len > storage.bool_values.len - bool_count) return error.CountOverflow;
                    const start = bool_count;
                    for (values) |value| {
                        storage.bool_values[bool_count] = if (value) raw.VK_TRUE else raw.VK_FALSE;
                        bool_count += 1;
                    }
                    raw_setting.type = raw.VK_LAYER_SETTING_TYPE_BOOL32_EXT;
                    raw_setting.pValues = @ptrCast(&storage.bool_values[start]);
                },
                .strings => |values| {
                    if (values.len > storage.string_pointers.len - string_count) return error.CountOverflow;
                    const start = string_count;
                    for (values) |value| {
                        storage.string_pointers[string_count] = value.ptr;
                        string_count += 1;
                    }
                    raw_setting.type = raw.VK_LAYER_SETTING_TYPE_STRING_EXT;
                    raw_setting.pValues = @ptrCast(&storage.string_pointers[start]);
                },
                .i32s => |values| setDirectValues(&raw_setting, values, raw.VK_LAYER_SETTING_TYPE_INT32_EXT),
                .i64s => |values| setDirectValues(&raw_setting, values, raw.VK_LAYER_SETTING_TYPE_INT64_EXT),
                .u32s => |values| setDirectValues(&raw_setting, values, raw.VK_LAYER_SETTING_TYPE_UINT32_EXT),
                .u64s => |values| setDirectValues(&raw_setting, values, raw.VK_LAYER_SETTING_TYPE_UINT64_EXT),
                .f32s => |values| setDirectValues(&raw_setting, values, raw.VK_LAYER_SETTING_TYPE_FLOAT32_EXT),
                .f64s => |values| setDirectValues(&raw_setting, values, raw.VK_LAYER_SETTING_TYPE_FLOAT64_EXT),
            }
            storage.settings[index] = raw_setting;
        }

        storage.validation_features = .{
            .sType = raw.VK_STRUCTURE_TYPE_VALIDATION_FEATURES_EXT,
            .enabledValidationFeatureCount = @intCast(validation.enabled.len),
            .pEnabledValidationFeatures = if (validation.enabled.len == 0) null else &storage.validation_enabled,
            .disabledValidationFeatureCount = @intCast(validation.disabled.len),
            .pDisabledValidationFeatures = if (validation.disabled.len == 0) null else &storage.validation_disabled,
        };
        storage.validation_flags = .{
            .sType = raw.VK_STRUCTURE_TYPE_VALIDATION_FLAGS_EXT,
            .disabledValidationCheckCount = @intCast(validation.disabled_checks.len),
            .pDisabledValidationChecks = if (validation.disabled_checks.len == 0) null else &storage.validation_checks,
        };
        storage.layer_settings = .{
            .sType = raw.VK_STRUCTURE_TYPE_LAYER_SETTINGS_CREATE_INFO_EXT,
            .settingCount = @intCast(layer_setting_options.len),
            .pSettings = if (layer_setting_options.len == 0) null else &storage.settings,
        };

        var head = tail;
        if (layer_setting_options.len != 0) {
            storage.layer_settings.pNext = head;
            head = @ptrCast(&storage.layer_settings);
        }
        if (validation.disabled_checks.len != 0) {
            storage.validation_flags.pNext = head;
            head = @ptrCast(&storage.validation_flags);
        }
        if (validation.enabled.len != 0 or validation.disabled.len != 0) {
            storage.validation_features.pNext = head;
            head = @ptrCast(&storage.validation_features);
        }
        return head;
    }
};

fn setDirectValues(
    setting: *raw.VkLayerSettingEXT,
    values: anytype,
    setting_type: raw.VkLayerSettingTypeEXT,
) void {
    setting.type = setting_type;
    setting.pValues = @ptrCast(values.ptr);
}

pub const diagnostics = struct {
    pub const Requests = struct {
        validation: bool = false,
        debug_messenger: bool = false,
        gpu_labels: bool = false,
    };

    pub const Availability = struct {
        validation_enabled: bool,
        debug_utils_enabled: bool,
        debug_messenger_enabled: bool,
        gpu_labels_enabled: bool,
    };

    pub fn resolve(
        requests: Requests,
        validation_layer_available: bool,
        debug_utils_available: bool,
    ) Availability {
        const validation_enabled = requests.validation and validation_layer_available;
        const debug_utils_requested = requests.debug_messenger or requests.gpu_labels;
        const debug_utils_enabled = debug_utils_requested and debug_utils_available;
        return .{
            .validation_enabled = validation_enabled,
            .debug_utils_enabled = debug_utils_enabled,
            .debug_messenger_enabled = requests.debug_messenger and debug_utils_enabled,
            .gpu_labels_enabled = requests.gpu_labels and debug_utils_enabled,
        };
    }

    pub fn detect(
        requests: Requests,
        available_layers: []const registry.LayerProperty,
        available_extensions: []const registry.ExtensionProperty,
    ) Availability {
        return resolve(
            requests,
            registry.supportsLayer(available_layers, layer.khronos_validation.name),
            registry.supportsExtension(available_extensions, command.extension.ext_debug_utils.name),
        );
    }
};

test "typed instance chains have stable caller-owned ordering and values" {
    var storage: InstanceChainStorage = .{};
    const settings = [_]LayerSetting{
        .{
            .layer_name = "VK_LAYER_KHRONOS_validation",
            .name = "validate_sync",
            .values = .{ .bools = &.{true} },
        },
        .{
            .layer_name = "VK_LAYER_KHRONOS_validation",
            .name = "report_flags",
            .values = .{ .strings = &.{ "error", "warn" } },
        },
    };
    const head = try storage.link(.{
        .enabled = &.{ .best_practices, .synchronization_validation },
        .disabled_checks = &.{.shaders},
    }, &settings, null);

    try std.testing.expect(head == @as(?*const anyopaque, @ptrCast(&storage.validation_features)));
    try std.testing.expect(storage.validation_features.pNext == @as(?*const anyopaque, @ptrCast(&storage.validation_flags)));
    try std.testing.expect(storage.validation_flags.pNext == @as(?*const anyopaque, @ptrCast(&storage.layer_settings)));
    try std.testing.expect(storage.layer_settings.pNext == null);
    try std.testing.expectEqual(@as(u32, 2), storage.validation_features.enabledValidationFeatureCount);
    try std.testing.expectEqual(raw.VK_TRUE, storage.bool_values[0]);
    try std.testing.expectEqualStrings("error", std.mem.span(storage.string_pointers[0]));
}

test "typed instance chains reject duplicates, empty values, and excessive counts" {
    var storage: InstanceChainStorage = .{};
    const duplicate = [_]LayerSetting{
        .{ .layer_name = "layer", .name = "setting", .values = .{ .u32s = &.{1} } },
        .{ .layer_name = "layer", .name = "setting", .values = .{ .u32s = &.{2} } },
    };
    try std.testing.expectError(error.InvalidOptions, storage.link(.{}, &duplicate, null));
    try std.testing.expectError(error.InvalidOptions, storage.link(.{}, &.{.{
        .layer_name = "layer",
        .name = "empty",
        .values = .{ .f32s = &.{} },
    }}, null));
    const too_many = [_]ValidationFeature{.best_practices} ** (validation_feature_count_max + 1);
    try std.testing.expectError(error.CountOverflow, storage.link(.{ .enabled = &too_many }, &.{}, null));
}

test "validation option enums preserve unknown future values" {
    const future = ValidationFeature.fromRaw(0x7fff_0000);
    try std.testing.expectEqual(@as(raw.VkValidationFeatureEnableEXT, 0x7fff_0000), future.toRaw());
}
