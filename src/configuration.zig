const build_options = @import("vulkan_build_options");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const raw = @import("vulkan_raw");
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
        available_layers: []const raw.VkLayerProperties,
        available_extensions: []const raw.VkExtensionProperties,
    ) Availability {
        return resolve(
            requests,
            registry.supportsLayer(available_layers, layer.khronos_validation.name),
            registry.supportsExtension(available_extensions, command.extension.ext_debug_utils.name),
        );
    }
};
