const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("vulkan_build_options");

/// Complete target-specific Vulkan ABI generated from the Khronos headers.
pub const raw = @import("vulkan_raw");
/// Generated command descriptors bind each Vulkan name, PFN type, and dispatch scope.
pub const command = @import("vulkan_commands");
/// Generated, strongly typed Vulkan enums, flag sets, and common value structures.
pub const types = @import("vulkan_types");
/// Converts a translated optional `PFN_vk*` type into its storable function-pointer type.
pub const CommandFunction = command.FunctionType;
/// Generated Vulkan extension descriptors with stable sentinel-terminated names.
pub const extension = command.extension;
pub const Extension = command.Extension;

pub const Flags = types.Flags;
pub const PhysicalDeviceType = types.PhysicalDeviceType;
pub const Format = types.Format;
pub const ColorSpace = types.ColorSpace;
pub const PresentMode = types.PresentMode;
pub const ImageLayout = types.ImageLayout;
pub const SharingMode = types.SharingMode;
pub const ImageViewType = types.ImageViewType;
pub const ImageType = types.ImageType;
pub const ImageTiling = types.ImageTiling;
pub const ComponentSwizzle = types.ComponentSwizzle;
pub const CommandBufferLevel = types.CommandBufferLevel;
pub const InstanceCreateBit = types.InstanceCreateBit;
pub const InstanceCreateFlags = types.InstanceCreateFlags;
pub const QueueBit = types.QueueBit;
pub const QueueFlags = types.QueueFlags;
pub const MemoryPropertyBit = types.MemoryPropertyBit;
pub const MemoryPropertyFlags = types.MemoryPropertyFlags;
pub const MemoryHeapBit = types.MemoryHeapBit;
pub const MemoryHeapFlags = types.MemoryHeapFlags;
pub const AccessBit = types.AccessBit;
pub const AccessFlags = types.AccessFlags;
pub const ImageUsageBit = types.ImageUsageBit;
pub const ImageUsageFlags = types.ImageUsageFlags;
pub const ImageCreateBit = types.ImageCreateBit;
pub const ImageCreateFlags = types.ImageCreateFlags;
pub const SampleCountBit = types.SampleCountBit;
pub const SampleCountFlags = types.SampleCountFlags;
pub const FenceCreateBit = types.FenceCreateBit;
pub const FenceCreateFlags = types.FenceCreateFlags;
pub const FormatFeatureBit = types.FormatFeatureBit;
pub const FormatFeatureFlags = types.FormatFeatureFlags;
pub const CommandBufferUsageBit = types.CommandBufferUsageBit;
pub const CommandBufferUsageFlags = types.CommandBufferUsageFlags;
pub const ImageAspectBit = types.ImageAspectBit;
pub const ImageAspectFlags = types.ImageAspectFlags;
pub const PipelineStageBit = types.PipelineStageBit;
pub const PipelineStageFlags = types.PipelineStageFlags;
pub const CommandPoolCreateBit = types.CommandPoolCreateBit;
pub const CommandPoolCreateFlags = types.CommandPoolCreateFlags;
pub const CompositeAlphaBit = types.CompositeAlphaBit;
pub const CompositeAlphaFlags = types.CompositeAlphaFlags;
pub const SurfaceTransformBit = types.SurfaceTransformBit;
pub const SurfaceTransformFlags = types.SurfaceTransformFlags;
pub const SwapchainCreateBit = types.SwapchainCreateBit;
pub const SwapchainCreateFlags = types.SwapchainCreateFlags;
pub const Extent2D = types.Extent2D;
pub const Extent3D = types.Extent3D;
pub const SurfaceFormat = types.SurfaceFormat;
pub const SurfaceCapabilities = types.SurfaceCapabilities;
pub const Offset2D = types.Offset2D;
pub const Offset3D = types.Offset3D;
pub const Rect2D = types.Rect2D;
pub const Viewport = types.Viewport;
pub const ComponentMapping = types.ComponentMapping;
pub const ImageSubresourceRange = types.ImageSubresourceRange;
pub const ClearColor = types.ClearColor;
pub const ClearDepthStencil = types.ClearDepthStencil;
pub const ClearValue = types.ClearValue;

/// A capability choice and whether the caller's preferred value was available.
pub fn Choice(comptime T: type) type {
    return struct {
        value: T,
        preferred: bool,
    };
}

pub fn clampSurfaceExtent(
    capabilities: SurfaceCapabilities,
    desired: Extent2D,
) Extent2D {
    return capabilities.extent_current orelse .{
        .width = @min(
            @max(desired.width, capabilities.extent_min.width),
            capabilities.extent_max.width,
        ),
        .height = @min(
            @max(desired.height, capabilities.extent_min.height),
            capabilities.extent_max.height,
        ),
    };
}

pub fn chooseSwapchainImageCount(
    capabilities: SurfaceCapabilities,
    preferred: ?u32,
) Choice(u32) {
    const default_count = if (capabilities.image_count_min == std.math.maxInt(u32))
        capabilities.image_count_min
    else
        capabilities.image_count_min + 1;
    const requested = preferred orelse default_count;
    const maximum = capabilities.image_count_max orelse std.math.maxInt(u32);
    const selected = @min(@max(requested, capabilities.image_count_min), maximum);
    return .{ .value = selected, .preferred = preferred == null or selected == requested };
}

pub fn chooseSurfaceFormat(
    available: []const SurfaceFormat,
    preferred: []const SurfaceFormat,
) Error!Choice(SurfaceFormat) {
    if (available.len == 0) return error.UnsupportedSurfaceConfiguration;
    if (available.len == 1 and available[0].format == .undefined_) {
        return .{
            .value = if (preferred.len == 0) available[0] else preferred[0],
            .preferred = preferred.len != 0,
        };
    }
    for (preferred) |wanted| {
        for (available) |candidate| {
            if (candidate.format == wanted.format and
                candidate.color_space == wanted.color_space)
            {
                return .{ .value = candidate, .preferred = true };
            }
        }
    }
    return .{ .value = available[0], .preferred = false };
}

pub fn choosePresentMode(
    available: []const PresentMode,
    preferred: []const PresentMode,
) Error!Choice(PresentMode) {
    if (available.len == 0) return error.UnsupportedSurfaceConfiguration;
    for (preferred) |wanted| {
        for (available) |candidate| {
            if (candidate == wanted) return .{ .value = candidate, .preferred = true };
        }
    }
    for (available) |candidate| {
        if (candidate == .fifo) return .{ .value = candidate, .preferred = false };
    }
    return .{ .value = available[0], .preferred = false };
}

pub fn chooseSurfaceTransform(
    capabilities: SurfaceCapabilities,
    preferred: []const SurfaceTransformBit,
) Choice(SurfaceTransformBit) {
    for (preferred) |wanted| {
        if (capabilities.transforms_supported.contains(wanted)) {
            return .{ .value = wanted, .preferred = true };
        }
    }
    return .{ .value = capabilities.transform_current, .preferred = false };
}

pub fn chooseCompositeAlpha(
    supported: CompositeAlphaFlags,
    preferred: []const CompositeAlphaBit,
) Error!Choice(CompositeAlphaBit) {
    for (preferred) |wanted| {
        if (supported.contains(wanted)) return .{ .value = wanted, .preferred = true };
    }
    const fallback_order = [_]CompositeAlphaBit{
        .opaque_,
        .pre_multiplied,
        .post_multiplied,
        .inherit,
    };
    for (fallback_order) |candidate| {
        if (supported.contains(candidate)) return .{ .value = candidate, .preferred = false };
    }
    return error.UnsupportedSurfaceConfiguration;
}

pub fn chooseImageUsage(
    supported: ImageUsageFlags,
    required: ImageUsageFlags,
    preferred: ImageUsageFlags,
) Error!Choice(ImageUsageFlags) {
    if (!supported.containsAll(required)) return error.UnsupportedSurfaceConfiguration;
    const optional_bits = supported.toRaw() & preferred.toRaw();
    const selected = ImageUsageFlags.fromRaw(required.toRaw() | optional_bits);
    return .{
        .value = selected,
        .preferred = supported.containsAll(preferred),
    };
}

/// Index of a queue family reported by a physical device.
pub const QueueFamilyIndex = enum(u32) {
    _,

    pub fn fromRaw(value: u32) QueueFamilyIndex {
        return @enumFromInt(value);
    }

    pub fn toRaw(index: QueueFamilyIndex) u32 {
        return @intFromEnum(index);
    }
};

/// Index of a queue within a queue family.
pub const QueueIndex = enum(u32) {
    first = 0,
    _,

    pub fn fromRaw(value: u32) QueueIndex {
        return @enumFromInt(value);
    }

    pub fn toRaw(index: QueueIndex) u32 {
        return @intFromEnum(index);
    }
};

/// Index of a borrowed image owned by a swapchain.
pub const SwapchainImageIndex = enum(u32) {
    _,

    pub fn fromRaw(value: u32) SwapchainImageIndex {
        return @enumFromInt(value);
    }

    pub fn toRaw(index: SwapchainImageIndex) u32 {
        return @intFromEnum(index);
    }
};

/// Index of a physical-device memory type.
pub const MemoryTypeIndex = enum(u32) {
    _,

    pub fn fromRaw(value: u32) MemoryTypeIndex {
        return @enumFromInt(value);
    }

    pub fn toRaw(index: MemoryTypeIndex) u32 {
        return @intFromEnum(index);
    }
};

/// Index of a physical-device memory heap.
pub const MemoryHeapIndex = enum(u32) {
    _,

    pub fn fromRaw(value: u32) MemoryHeapIndex {
        return @enumFromInt(value);
    }

    pub fn toRaw(index: MemoryHeapIndex) u32 {
        return @intFromEnum(index);
    }
};

/// Vulkan timeout without exposing the `maxInt(u64)` infinite-time sentinel.
pub const Timeout = union(enum) {
    infinite,
    nanoseconds: u64,

    pub const immediate: Timeout = .{ .nanoseconds = 0 };

    fn toRaw(timeout: Timeout) u64 {
        return switch (timeout) {
            .infinite => std.math.maxInt(u64),
            .nanoseconds => |value| value,
        };
    }
};

/// Queue-family ownership encoded without `VK_QUEUE_FAMILY_IGNORED` at call sites.
pub const QueueFamilyOwnership = union(enum) {
    ignored,
    transfer: struct {
        source: QueueFamilyIndex,
        destination: QueueFamilyIndex,
    },

    fn sourceRaw(ownership: QueueFamilyOwnership) u32 {
        return switch (ownership) {
            .ignored => raw.VK_QUEUE_FAMILY_IGNORED,
            .transfer => |transfer| transfer.source.toRaw(),
        };
    }

    fn destinationRaw(ownership: QueueFamilyOwnership) u32 {
        return switch (ownership) {
            .ignored => raw.VK_QUEUE_FAMILY_IGNORED,
            .transfer => |transfer| transfer.destination.toRaw(),
        };
    }
};

pub const Layer = struct {
    name: [:0]const u8,
};

/// Well-known Vulkan layers that applications commonly request by name.
pub const layer = struct {
    pub const khronos_validation: Layer = .{ .name = "VK_LAYER_KHRONOS_validation" };
};

pub const platform = build_options.platform;
pub const registry_commit = build_options.registry_commit;

const enumeration_attempt_count_max = 4;
const enumeration_item_count_max = 4096;
const name_count_max = 256;
const device_queue_count_max = 64;
const submission_item_count_max = 64;
const swapchain_image_count_max = 4096;
const memory_type_count_max: usize = raw.VK_MAX_MEMORY_TYPES;
const memory_heap_count_max: usize = raw.VK_MAX_MEMORY_HEAPS;

const InstanceHandle = NonNullHandle(raw.VkInstance);
const PhysicalDeviceHandle = NonNullHandle(raw.VkPhysicalDevice);
const DeviceHandle = NonNullHandle(raw.VkDevice);
const QueueHandle = NonNullHandle(raw.VkQueue);
const SurfaceHandle = NonNullHandle(raw.VkSurfaceKHR);
const DebugMessengerHandle = NonNullHandle(raw.VkDebugUtilsMessengerEXT);
const SwapchainHandle = NonNullHandle(raw.VkSwapchainKHR);
const ImageHandle = NonNullHandle(raw.VkImage);
const ImageViewHandle = NonNullHandle(raw.VkImageView);
const CommandPoolHandle = NonNullHandle(raw.VkCommandPool);
const CommandBufferHandle = NonNullHandle(raw.VkCommandBuffer);
const SemaphoreHandle = NonNullHandle(raw.VkSemaphore);
const FenceHandle = NonNullHandle(raw.VkFence);

pub const Error = error{
    OutOfHostMemory,
    OutOfDeviceMemory,
    InitializationFailed,
    DeviceLost,
    MemoryMapFailed,
    LayerNotPresent,
    ExtensionNotPresent,
    FeatureNotPresent,
    IncompatibleDriver,
    TooManyObjects,
    FormatNotSupported,
    FragmentedPool,
    UnknownVulkanError,
    UnexpectedVulkanResult,
    MissingCommand,
    EnumerationUnstable,
    InactiveObject,
    InvalidHandle,
    InvalidOptions,
    CountOverflow,
    PortabilityNotSupported,
    MemoryTypeNotFound,
    SurfaceLost,
    NativeWindowInUse,
    FullScreenExclusiveLost,
    BufferTooSmall,
    InvalidProperties,
    SizeOverflow,
    UnsupportedSurfaceConfiguration,
    QueueFamilyNotFound,
};

pub const LoaderError = error{
    VulkanLoaderNotFound,
    VulkanEntryPointMissing,
};

pub const Version = struct {
    variant: u3 = 0,
    major: u7,
    minor: u10,
    patch: u12,

    pub fn encode(version: Version) u32 {
        return (@as(u32, version.variant) << 29) |
            (@as(u32, version.major) << 22) |
            (@as(u32, version.minor) << 12) |
            @as(u32, version.patch);
    }

    pub fn decode(encoded: u32) Version {
        return .{
            .variant = @truncate(encoded >> 29),
            .major = @truncate(encoded >> 22),
            .minor = @truncate(encoded >> 12),
            .patch = @truncate(encoded),
        };
    }

    pub fn lessThan(version: Version, other: Version) bool {
        return version.encode() < other.encode();
    }

    pub fn atLeast(version: Version, minimum: Version) bool {
        return !version.lessThan(minimum);
    }

    pub fn format(version: Version, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        if (version.variant != 0) try writer.print("{d}:", .{version.variant});
        try writer.print("{d}.{d}.{d}", .{ version.major, version.minor, version.patch });
    }

    pub const v1_0: Version = .{ .major = 1, .minor = 0, .patch = 0 };
    pub const v1_1: Version = .{ .major = 1, .minor = 1, .patch = 0 };
    pub const v1_2: Version = .{ .major = 1, .minor = 2, .patch = 0 };
    pub const v1_3: Version = .{ .major = 1, .minor = 3, .patch = 0 };
    pub const v1_4: Version = .{ .major = 1, .minor = 4, .patch = 0 };
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

    pub fn instanceFlags() InstanceCreateFlags {
        return if (platform == .metal)
            .init(&.{.enumerate_portability_khr})
        else
            .empty;
    }
};

/// A fixed-capacity, allocation-free set of unique extension names.
pub fn ExtensionSet(comptime capacity: usize) type {
    if (capacity > name_count_max) {
        @compileError("extension-set capacity exceeds vk-zig's supported name count");
    }
    return struct {
        names: [capacity][:0]const u8 = undefined,
        count: usize = 0,

        const Set = @This();

        pub fn append(set: *Set, name: [:0]const u8) Error!void {
            if (set.contains(name)) return;
            if (set.count == capacity) return error.CountOverflow;
            set.names[set.count] = name;
            set.count += 1;
        }

        pub fn appendAll(set: *Set, names: []const [:0]const u8) Error!void {
            for (names) |name| try set.append(name);
        }

        /// Converts foreign sentinel pointers while copying only their borrowed views.
        pub fn appendPointerNames(
            set: *Set,
            names: []const [*:0]const u8,
        ) Error!void {
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

/// Returns the bytes before the first NUL, or the entire bounded input when none exists.
pub fn boundedCString(bytes: []const u8) []const u8 {
    const end = std.mem.indexOfScalar(u8, bytes, 0) orelse bytes.len;
    return bytes[0..end];
}

/// Borrows the extension name from `property`; the view lives as long as `property`.
pub fn extensionName(property: *const raw.VkExtensionProperties) []const u8 {
    return boundedCString(&property.extensionName);
}

/// Borrows the layer name from `property`; the view lives as long as `property`.
pub fn layerName(property: *const raw.VkLayerProperties) []const u8 {
    return boundedCString(&property.layerName);
}

/// Borrows the description from `property`; the view lives as long as `property`.
pub fn layerDescription(property: *const raw.VkLayerProperties) []const u8 {
    return boundedCString(&property.description);
}

/// Borrows the device name from `property`; the view lives as long as `property`.
pub fn physicalDeviceName(property: *const raw.VkPhysicalDeviceProperties) []const u8 {
    return boundedCString(&property.deviceName);
}

pub fn supportsExtension(
    properties: []const raw.VkExtensionProperties,
    expected: []const u8,
) bool {
    for (properties) |*property| {
        if (std.mem.eql(u8, extensionName(property), expected)) return true;
    }
    return false;
}

pub fn supportsLayer(properties: []const raw.VkLayerProperties, expected: []const u8) bool {
    for (properties) |*property| {
        if (std.mem.eql(u8, layerName(property), expected)) return true;
    }
    return false;
}

/// Resolves optional validation and debug tooling without coupling independent requests.
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
            supportsLayer(available_layers, layer.khronos_validation.name),
            supportsExtension(available_extensions, extension.ext_debug_utils.name),
        );
    }
};

pub const Loader = struct {
    library: NativeLibrary,
    active: bool = true,

    pub fn init() LoaderError!Loader {
        return .{ .library = try NativeLibrary.open() };
    }

    pub fn initFromPath(path: [:0]const u8) LoaderError!Loader {
        return .{ .library = try NativeLibrary.openPath(path) };
    }

    pub fn deinit(loader: *Loader) void {
        if (!loader.active) return;
        loader.library.close();
        loader.active = false;
    }

    pub fn entry(loader: *Loader) LoaderError!Entry {
        if (!loader.active) return error.VulkanLoaderNotFound;
        const get_instance_proc_addr = loader.library.lookup(
            CommandFunction(raw.PFN_vkGetInstanceProcAddr),
            "vkGetInstanceProcAddr",
        ) orelse return error.VulkanEntryPointMissing;
        return Entry.init(get_instance_proc_addr);
    }
};

pub const Entry = struct {
    get_instance_proc_addr: CommandFunction(raw.PFN_vkGetInstanceProcAddr),
    create_instance: CommandFunction(raw.PFN_vkCreateInstance),
    enumerate_instance_version: ?CommandFunction(raw.PFN_vkEnumerateInstanceVersion),
    enumerate_instance_extension_properties: CommandFunction(
        raw.PFN_vkEnumerateInstanceExtensionProperties,
    ),
    enumerate_instance_layer_properties: CommandFunction(
        raw.PFN_vkEnumerateInstanceLayerProperties,
    ),

    fn init(
        get_instance_proc_addr: CommandFunction(raw.PFN_vkGetInstanceProcAddr),
    ) LoaderError!Entry {
        return .{
            .get_instance_proc_addr = get_instance_proc_addr,
            .create_instance = loadInstanceRequired(
                get_instance_proc_addr,
                null,
                raw.PFN_vkCreateInstance,
                "vkCreateInstance",
            ) catch return error.VulkanEntryPointMissing,
            .enumerate_instance_version = loadInstance(
                get_instance_proc_addr,
                null,
                raw.PFN_vkEnumerateInstanceVersion,
                "vkEnumerateInstanceVersion",
            ),
            .enumerate_instance_extension_properties = loadInstanceRequired(
                get_instance_proc_addr,
                null,
                raw.PFN_vkEnumerateInstanceExtensionProperties,
                "vkEnumerateInstanceExtensionProperties",
            ) catch return error.VulkanEntryPointMissing,
            .enumerate_instance_layer_properties = loadInstanceRequired(
                get_instance_proc_addr,
                null,
                raw.PFN_vkEnumerateInstanceLayerProperties,
                "vkEnumerateInstanceLayerProperties",
            ) catch return error.VulkanEntryPointMissing,
        };
    }

    pub fn apiVersion(entry: *const Entry) Error!Version {
        const enumerate = entry.enumerate_instance_version orelse {
            return Version.decode(raw.VK_API_VERSION_1_0);
        };
        var encoded: u32 = 0;
        try checkSuccess(enumerate(&encoded));
        return Version.decode(encoded);
    }

    pub fn instanceExtensions(
        entry: *const Entry,
        gpa: std.mem.Allocator,
        layer_name: ?[:0]const u8,
    ) (Error || std.mem.Allocator.Error)![]raw.VkExtensionProperties {
        var count: u32 = 0;
        try checkSuccess(entry.enumerate_instance_extension_properties(
            optionalStringPointer(layer_name),
            &count,
            null,
        ));
        try validateEnumerationCount(count);
        if (count == 0) return gpa.alloc(raw.VkExtensionProperties, 0);

        var properties = try gpa.alloc(raw.VkExtensionProperties, count);
        errdefer gpa.free(properties);
        for (0..enumeration_attempt_count_max) |_| {
            var written: u32 = @intCast(properties.len);
            const result = entry.enumerate_instance_extension_properties(
                optionalStringPointer(layer_name),
                &written,
                properties.ptr,
            );
            if (result == raw.VK_SUCCESS) {
                return gpa.realloc(properties, written);
            }
            if (result != raw.VK_INCOMPLETE) try checkSuccess(result);

            count = 0;
            try checkSuccess(entry.enumerate_instance_extension_properties(
                optionalStringPointer(layer_name),
                &count,
                null,
            ));
            count = try nextEnumerationCapacity(count, properties.len);
            properties = try gpa.realloc(properties, count);
        }
        return error.EnumerationUnstable;
    }

    pub fn instanceLayers(
        entry: *const Entry,
        gpa: std.mem.Allocator,
    ) (Error || std.mem.Allocator.Error)![]raw.VkLayerProperties {
        var count: u32 = 0;
        try checkSuccess(entry.enumerate_instance_layer_properties(&count, null));
        try validateEnumerationCount(count);
        if (count == 0) return gpa.alloc(raw.VkLayerProperties, 0);

        var properties = try gpa.alloc(raw.VkLayerProperties, count);
        errdefer gpa.free(properties);
        for (0..enumeration_attempt_count_max) |_| {
            var written: u32 = @intCast(properties.len);
            const result = entry.enumerate_instance_layer_properties(
                &written,
                properties.ptr,
            );
            if (result == raw.VK_SUCCESS) {
                return gpa.realloc(properties, written);
            }
            if (result != raw.VK_INCOMPLETE) try checkSuccess(result);

            count = 0;
            try checkSuccess(entry.enumerate_instance_layer_properties(&count, null));
            count = try nextEnumerationCapacity(count, properties.len);
            properties = try gpa.realloc(properties, count);
        }
        return error.EnumerationUnstable;
    }

    pub fn load(
        entry: *const Entry,
        comptime descriptor: anytype,
    ) ?DescriptorFunction(descriptor, .global) {
        const Descriptor = @TypeOf(descriptor);
        return loadInstance(
            entry.get_instance_proc_addr,
            null,
            Descriptor.Pfn,
            Descriptor.name,
        );
    }

    pub fn require(
        entry: *const Entry,
        comptime descriptor: anytype,
    ) Error!DescriptorFunction(descriptor, .global) {
        return entry.load(descriptor) orelse error.MissingCommand;
    }

    /// Loads a dynamic command name without verifying that it matches the PFN type.
    pub fn loadUnchecked(
        entry: *const Entry,
        comptime OptionalFunction: type,
        name: [:0]const u8,
    ) ?CommandFunction(OptionalFunction) {
        return loadInstance(entry.get_instance_proc_addr, null, OptionalFunction, name);
    }

    pub fn createInstance(
        entry: *const Entry,
        options: InstanceOptions,
    ) Error!Instance {
        var layer_pointers: [name_count_max][*c]const u8 = undefined;
        const layer_count = try fillNamePointers(options.layers, &layer_pointers);

        var extension_pointers: [name_count_max][*c]const u8 = undefined;
        var extension_count = try fillNamePointers(options.extensions, &extension_pointers);
        if (options.debug_messenger != null) {
            const debug_utils_extension = extension.ext_debug_utils.name;
            if (!containsName(options.extensions, debug_utils_extension)) {
                if (extension_count == extension_pointers.len) return error.CountOverflow;
                extension_pointers[extension_count] = debug_utils_extension.ptr;
                extension_count += 1;
            }
        }
        var flags = options.flags;
        if (options.enumerate_portability) {
            if (platform != .metal) return error.PortabilityNotSupported;
            const portability_extension = portability_instance_extensions[0];
            if (!containsName(options.extensions, portability_extension)) {
                if (extension_count == extension_pointers.len) return error.CountOverflow;
                extension_pointers[extension_count] = portability_extension.ptr;
                extension_count += 1;
            }
            flags = flags.merge(Portability.instanceFlags());
        }

        const application_info: raw.VkApplicationInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = options.application_next,
            .pApplicationName = optionalStringPointer(options.application_name),
            .applicationVersion = options.application_version.encode(),
            .pEngineName = optionalStringPointer(options.engine_name),
            .engineVersion = options.engine_version.encode(),
            .apiVersion = options.api_version.encode(),
        };
        var debug_create_info: raw.VkDebugUtilsMessengerCreateInfoEXT = undefined;
        const instance_next: ?*const anyopaque = if (options.debug_messenger) |config| next: {
            debug_create_info = config.createInfo(options.next);
            break :next @ptrCast(&debug_create_info);
        } else options.next;
        const create_info: raw.VkInstanceCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = instance_next,
            .flags = flags.toRaw(),
            .pApplicationInfo = &application_info,
            .enabledLayerCount = @intCast(layer_count),
            .ppEnabledLayerNames = pointerArray(layer_pointers[0..layer_count]),
            .enabledExtensionCount = @intCast(extension_count),
            .ppEnabledExtensionNames = pointerArray(extension_pointers[0..extension_count]),
        };
        var instance = try entry.createInstanceRaw(&create_info, options.allocation_callbacks);
        errdefer instance.deinit();
        if (options.debug_messenger) |config| {
            instance._debug_messenger = try ext.debug_utils.Messenger.initConfig(
                &instance,
                config,
                options.allocation_callbacks,
            );
        }
        return instance;
    }

    pub fn createInstanceRaw(
        entry: *const Entry,
        create_info: *const raw.VkInstanceCreateInfo,
        allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    ) Error!Instance {
        var handle: raw.VkInstance = null;
        try checkSuccess(entry.create_instance(create_info, allocation_callbacks, &handle));
        const live_handle = handle orelse return error.InvalidHandle;

        const dispatch = InstanceDispatch.init(
            entry.get_instance_proc_addr,
            live_handle,
        ) catch |load_error| {
            if (loadInstance(
                entry.get_instance_proc_addr,
                live_handle,
                raw.PFN_vkDestroyInstance,
                "vkDestroyInstance",
            )) |destroy| {
                destroy(live_handle, allocation_callbacks);
            }
            return load_error;
        };

        return .{
            ._handle = live_handle,
            ._debug_messenger = null,
            .allocation_callbacks = allocation_callbacks,
            .dispatch = dispatch,
        };
    }
};

pub const InstanceOptions = struct {
    application_name: ?[:0]const u8 = null,
    application_version: Version = .{ .major = 0, .minor = 1, .patch = 0 },
    engine_name: ?[:0]const u8 = null,
    engine_version: Version = .{ .major = 0, .minor = 1, .patch = 0 },
    api_version: Version = .{ .major = 1, .minor = 0, .patch = 0 },
    layers: []const [:0]const u8 = &.{},
    extensions: []const [:0]const u8 = &.{},
    flags: InstanceCreateFlags = .empty,
    enumerate_portability: bool = false,
    application_next: ?*const anyopaque = null,
    next: ?*const anyopaque = null,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks = null,
    debug_messenger: ?ext.debug_utils.MessengerConfig = null,
};

pub const Instance = struct {
    _handle: ?InstanceHandle,
    _debug_messenger: ?ext.debug_utils.Messenger,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: InstanceDispatch,

    pub fn deinit(instance: *Instance) void {
        const handle = instance._handle orelse return;
        if (instance._debug_messenger) |*messenger| messenger.deinit();
        instance._debug_messenger = null;
        instance.dispatch.destroy_instance(handle, instance.allocation_callbacks);
        instance._handle = null;
    }

    pub fn debugMessengerActive(instance: *const Instance) bool {
        if (instance._handle == null) return false;
        return instance._debug_messenger != null;
    }

    /// Returns the live raw handle for explicit FFI integration.
    pub fn rawHandle(instance: *const Instance) Error!raw.VkInstance {
        return instance._handle orelse error.InactiveObject;
    }

    pub fn load(
        instance: *const Instance,
        comptime descriptor: anytype,
    ) Error!?DescriptorFunction(descriptor, .instance) {
        const Descriptor = @TypeOf(descriptor);
        const handle = instance._handle orelse return error.InactiveObject;
        return loadInstance(
            instance.dispatch.get_instance_proc_addr,
            handle,
            Descriptor.Pfn,
            Descriptor.name,
        );
    }

    pub fn require(
        instance: *const Instance,
        comptime descriptor: anytype,
    ) Error!DescriptorFunction(descriptor, .instance) {
        return (try instance.load(descriptor)) orelse error.MissingCommand;
    }

    /// Loads a dynamic command name without verifying that it matches the PFN type.
    pub fn loadUnchecked(
        instance: *const Instance,
        comptime OptionalFunction: type,
        name: [:0]const u8,
    ) Error!?CommandFunction(OptionalFunction) {
        const handle = instance._handle orelse return error.InactiveObject;
        return loadInstance(
            instance.dispatch.get_instance_proc_addr,
            handle,
            OptionalFunction,
            name,
        );
    }

    pub fn physicalDevices(
        instance: *const Instance,
        gpa: std.mem.Allocator,
    ) (Error || std.mem.Allocator.Error)![]PhysicalDevice {
        const instance_handle = instance._handle orelse return error.InactiveObject;
        var count: u32 = 0;
        try checkSuccess(instance.dispatch.enumerate_physical_devices(
            instance_handle,
            &count,
            null,
        ));
        try validateEnumerationCount(count);
        if (count == 0) return gpa.alloc(PhysicalDevice, 0);

        var handles = try gpa.alloc(raw.VkPhysicalDevice, count);
        defer gpa.free(handles);

        for (0..enumeration_attempt_count_max) |_| {
            var written: u32 = @intCast(handles.len);
            const result = instance.dispatch.enumerate_physical_devices(
                instance_handle,
                &written,
                handles.ptr,
            );
            if (result == raw.VK_SUCCESS) {
                const devices = try gpa.alloc(PhysicalDevice, written);
                for (devices, handles[0..written]) |*device, handle| {
                    const live_handle = handle orelse {
                        gpa.free(devices);
                        return error.InvalidHandle;
                    };
                    device.* = .{
                        ._handle = live_handle,
                        ._instance_handle = instance_handle,
                        .dispatch = instance.dispatch,
                    };
                }
                return devices;
            }
            if (result != raw.VK_INCOMPLETE) try checkSuccess(result);

            count = 0;
            try checkSuccess(instance.dispatch.enumerate_physical_devices(
                instance_handle,
                &count,
                null,
            ));
            try validateEnumerationCount(count);
            if (count <= handles.len) {
                count = @intCast(@min(handles.len * 2, enumeration_item_count_max));
            }
            handles = try gpa.realloc(handles, count);
        }
        return error.EnumerationUnstable;
    }

    /// Takes ownership of an existing surface. Destroy it before its parent instance.
    pub fn adoptSurface(
        instance: *const Instance,
        handle: raw.VkSurfaceKHR,
        allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    ) Error!Surface {
        const instance_handle = instance._handle orelse return error.InactiveObject;
        const live_handle = handle orelse return error.InvalidHandle;
        const destroy_surface = (try instance.load(command.destroy_surface_khr)) orelse {
            return error.MissingCommand;
        };
        return .{
            ._handle = live_handle,
            ._instance_handle = instance_handle,
            .allocation_callbacks = allocation_callbacks,
            .destroy_surface = destroy_surface,
        };
    }
};

/// An owned `VkSurfaceKHR`. This wrapper must be destroyed before its parent instance.
pub const Surface = struct {
    _handle: ?SurfaceHandle,
    _instance_handle: InstanceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_surface: CommandFunction(raw.PFN_vkDestroySurfaceKHR),

    pub fn deinit(surface: *Surface) void {
        const handle = surface._handle orelse return;
        surface.destroy_surface(
            surface._instance_handle,
            handle,
            surface.allocation_callbacks,
        );
        surface._handle = null;
    }

    /// Returns the live raw handle for explicit FFI integration.
    pub fn rawHandle(surface: *const Surface) Error!raw.VkSurfaceKHR {
        return surface._handle orelse error.InactiveObject;
    }
};

/// A non-owning image whose lifetime is controlled by its swapchain.
pub const SwapchainImage = struct {
    _handle: ImageHandle,
    _device_handle: DeviceHandle,
    _swapchain_handle: SwapchainHandle,
    index: SwapchainImageIndex,

    /// Returns the valid raw image handle for explicit FFI integration.
    pub fn rawHandle(image: SwapchainImage) raw.VkImage {
        return image._handle;
    }
};

pub const ImageViewOptions = struct {
    image: *const SwapchainImage,
    format: Format,
    view_type: ImageViewType = ._2d,
    components: ComponentMapping = .{},
    subresource_range: ImageSubresourceRange,
};

/// An owned image view. Destroy it before its parent device and source image.
pub const ImageView = struct {
    _handle: ?ImageViewHandle,
    _device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_image_view: CommandFunction(raw.PFN_vkDestroyImageView),

    pub fn deinit(view: *ImageView) void {
        const handle = view._handle orelse return;
        view.destroy_image_view(view._device_handle, handle, view.allocation_callbacks);
        view._handle = null;
    }

    /// Returns the live raw handle for explicit FFI integration.
    pub fn rawHandle(view: *const ImageView) Error!raw.VkImageView {
        return view._handle orelse error.InactiveObject;
    }
};

pub const SemaphoreOptions = struct {};

/// An owned binary semaphore.
pub const Semaphore = struct {
    _handle: ?SemaphoreHandle,
    _device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_semaphore: CommandFunction(raw.PFN_vkDestroySemaphore),

    pub fn deinit(semaphore: *Semaphore) void {
        const handle = semaphore._handle orelse return;
        semaphore.destroy_semaphore(
            semaphore._device_handle,
            handle,
            semaphore.allocation_callbacks,
        );
        semaphore._handle = null;
    }

    /// Returns the live raw handle for explicit FFI integration.
    pub fn rawHandle(semaphore: *const Semaphore) Error!raw.VkSemaphore {
        return semaphore._handle orelse error.InactiveObject;
    }
};

pub const FenceOptions = struct {
    signaled: bool = false,
};

pub const FenceWaitStatus = enum {
    success,
    timeout,
};

/// An owned fence with operation-specific wait and reset behavior.
pub const Fence = struct {
    _handle: ?FenceHandle,
    _device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_fence: CommandFunction(raw.PFN_vkDestroyFence),
    reset_fences: CommandFunction(raw.PFN_vkResetFences),
    wait_for_fences: CommandFunction(raw.PFN_vkWaitForFences),

    pub fn deinit(fence: *Fence) void {
        const handle = fence._handle orelse return;
        fence.destroy_fence(fence._device_handle, handle, fence.allocation_callbacks);
        fence._handle = null;
    }

    pub fn reset(fence: *const Fence) Error!void {
        const handle = fence._handle orelse return error.InactiveObject;
        try checkSuccess(fence.reset_fences(fence._device_handle, 1, @ptrCast(&handle)));
    }

    pub fn wait(fence: *const Fence, timeout: Timeout) Error!FenceWaitStatus {
        const handle = fence._handle orelse return error.InactiveObject;
        const result = fence.wait_for_fences(
            fence._device_handle,
            1,
            @ptrCast(&handle),
            raw.VK_TRUE,
            timeout.toRaw(),
        );
        if (result == raw.VK_SUCCESS) return .success;
        if (result == raw.VK_TIMEOUT) return .timeout;
        try checkSuccess(result);
        unreachable;
    }

    /// Returns the live raw handle for explicit FFI integration.
    pub fn rawHandle(fence: *const Fence) Error!raw.VkFence {
        return fence._handle orelse error.InactiveObject;
    }
};

pub const CommandPoolOptions = struct {
    family_index: QueueFamilyIndex,
    flags: CommandPoolCreateFlags = .empty,
};

pub const CommandBufferOptions = struct {
    level: CommandBufferLevel = .primary,
};

pub const CommandBufferBeginOptions = struct {
    flags: CommandBufferUsageFlags = .empty,
};

pub const ImageBarrierOptions = struct {
    source_stage: PipelineStageFlags,
    destination_stage: PipelineStageFlags,
    source_access: AccessFlags = .empty,
    destination_access: AccessFlags = .empty,
    old_layout: ImageLayout,
    new_layout: ImageLayout,
    ownership: QueueFamilyOwnership = .ignored,
    image: *const SwapchainImage,
    subresource_range: ImageSubresourceRange,
};

pub const ClearColorImageOptions = struct {
    image: *const SwapchainImage,
    layout: ImageLayout,
    color: ClearColor,
    subresource_range: ImageSubresourceRange,
};

const CommandBufferState = enum {
    initial,
    recording,
    executable,
};

/// A command buffer allocated from and owned by a command pool.
pub const CommandBuffer = struct {
    _handle: CommandBufferHandle,
    _device_handle: DeviceHandle,
    _pool_handle: CommandPoolHandle,
    can_reset: bool,
    state: CommandBufferState = .initial,
    begin_command_buffer: CommandFunction(raw.PFN_vkBeginCommandBuffer),
    end_command_buffer: CommandFunction(raw.PFN_vkEndCommandBuffer),
    reset_command_buffer: CommandFunction(raw.PFN_vkResetCommandBuffer),
    cmd_pipeline_barrier: CommandFunction(raw.PFN_vkCmdPipelineBarrier),
    cmd_clear_color_image: CommandFunction(raw.PFN_vkCmdClearColorImage),
    cmd_begin_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdBeginDebugUtilsLabelEXT),
    cmd_end_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdEndDebugUtilsLabelEXT),
    cmd_insert_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdInsertDebugUtilsLabelEXT),

    pub fn begin(buffer: *CommandBuffer, options: CommandBufferBeginOptions) Error!void {
        if (buffer.state != .initial) return error.InvalidOptions;
        const begin_info: raw.VkCommandBufferBeginInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = options.flags.toRaw(),
        };
        try checkSuccess(buffer.begin_command_buffer(buffer._handle, &begin_info));
        buffer.state = .recording;
    }

    pub fn end(buffer: *CommandBuffer) Error!void {
        if (buffer.state != .recording) return error.InvalidOptions;
        try checkSuccess(buffer.end_command_buffer(buffer._handle));
        buffer.state = .executable;
    }

    pub fn reset(buffer: *CommandBuffer, release_resources: bool) Error!void {
        if (buffer.state == .recording) return error.InvalidOptions;
        if (!buffer.can_reset) return error.InvalidOptions;
        const flags: raw.VkCommandBufferResetFlags = if (release_resources)
            @intCast(raw.VK_COMMAND_BUFFER_RESET_RELEASE_RESOURCES_BIT)
        else
            0;
        try checkSuccess(buffer.reset_command_buffer(buffer._handle, flags));
        buffer.state = .initial;
    }

    pub fn imageBarrier(buffer: *const CommandBuffer, options: ImageBarrierOptions) Error!void {
        if (buffer.state != .recording) return error.InvalidOptions;
        if (options.image._device_handle != buffer._device_handle) return error.InvalidHandle;
        const barrier: raw.VkImageMemoryBarrier = .{
            .sType = raw.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            .srcAccessMask = options.source_access.toRaw(),
            .dstAccessMask = options.destination_access.toRaw(),
            .oldLayout = options.old_layout.toRaw(),
            .newLayout = options.new_layout.toRaw(),
            .srcQueueFamilyIndex = options.ownership.sourceRaw(),
            .dstQueueFamilyIndex = options.ownership.destinationRaw(),
            .image = options.image._handle,
            .subresourceRange = options.subresource_range.toRaw(),
        };
        buffer.cmd_pipeline_barrier(
            buffer._handle,
            options.source_stage.toRaw(),
            options.destination_stage.toRaw(),
            0,
            0,
            null,
            0,
            null,
            1,
            &barrier,
        );
    }

    pub fn clearColorImage(
        buffer: *const CommandBuffer,
        options: ClearColorImageOptions,
    ) Error!void {
        if (buffer.state != .recording) return error.InvalidOptions;
        if (options.image._device_handle != buffer._device_handle) return error.InvalidHandle;
        const color = options.color.toRaw();
        const subresource_range = options.subresource_range.toRaw();
        buffer.cmd_clear_color_image(
            buffer._handle,
            options.image._handle,
            options.layout.toRaw(),
            &color,
            1,
            &subresource_range,
        );
    }

    pub fn beginLabel(
        buffer: *const CommandBuffer,
        options: ext.debug_utils.LabelOptions,
    ) Error!CommandBufferLabelScope {
        if (buffer.state != .recording) return error.InvalidOptions;
        const begin_label = buffer.cmd_begin_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        const end_label = buffer.cmd_end_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        const label = options.createInfo();
        begin_label(buffer._handle, &label);
        return .{ .command_buffer = buffer._handle, .end_label = end_label };
    }

    pub fn insertLabel(
        buffer: *const CommandBuffer,
        options: ext.debug_utils.LabelOptions,
    ) Error!void {
        if (buffer.state != .recording) return error.InvalidOptions;
        const insert_label = buffer.cmd_insert_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        const label = options.createInfo();
        insert_label(buffer._handle, &label);
    }

    /// Returns the valid raw handle for explicit FFI integration.
    pub fn rawHandle(buffer: *const CommandBuffer) raw.VkCommandBuffer {
        return buffer._handle;
    }
};

/// An idempotent command-buffer label scope.
pub const CommandBufferLabelScope = struct {
    command_buffer: CommandBufferHandle,
    end_label: CommandFunction(raw.PFN_vkCmdEndDebugUtilsLabelEXT),
    active: bool = true,

    pub fn end(scope: *CommandBufferLabelScope) void {
        if (!scope.active) return;
        scope.end_label(scope.command_buffer);
        scope.active = false;
    }

    pub fn deinit(scope: *CommandBufferLabelScope) void {
        scope.end();
    }
};

/// An owned command pool. Allocated command buffers are invalid after `deinit`.
pub const CommandPool = struct {
    _handle: ?CommandPoolHandle,
    _device_handle: DeviceHandle,
    buffers_can_reset: bool,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_command_pool: CommandFunction(raw.PFN_vkDestroyCommandPool),
    allocate_command_buffers: CommandFunction(raw.PFN_vkAllocateCommandBuffers),
    begin_command_buffer: CommandFunction(raw.PFN_vkBeginCommandBuffer),
    end_command_buffer: CommandFunction(raw.PFN_vkEndCommandBuffer),
    reset_command_buffer: CommandFunction(raw.PFN_vkResetCommandBuffer),
    cmd_pipeline_barrier: CommandFunction(raw.PFN_vkCmdPipelineBarrier),
    cmd_clear_color_image: CommandFunction(raw.PFN_vkCmdClearColorImage),
    cmd_begin_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdBeginDebugUtilsLabelEXT),
    cmd_end_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdEndDebugUtilsLabelEXT),
    cmd_insert_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdInsertDebugUtilsLabelEXT),

    pub fn deinit(pool: *CommandPool) void {
        const handle = pool._handle orelse return;
        pool.destroy_command_pool(pool._device_handle, handle, pool.allocation_callbacks);
        pool._handle = null;
    }

    pub fn allocateCommandBuffer(
        pool: *const CommandPool,
        options: CommandBufferOptions,
    ) Error!CommandBuffer {
        const pool_handle = pool._handle orelse return error.InactiveObject;
        const allocate_info: raw.VkCommandBufferAllocateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = pool_handle,
            .level = options.level.toRaw(),
            .commandBufferCount = 1,
        };
        var handle: raw.VkCommandBuffer = null;
        try checkSuccess(pool.allocate_command_buffers(
            pool._device_handle,
            &allocate_info,
            &handle,
        ));
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._device_handle = pool._device_handle,
            ._pool_handle = pool_handle,
            .can_reset = pool.buffers_can_reset,
            .begin_command_buffer = pool.begin_command_buffer,
            .end_command_buffer = pool.end_command_buffer,
            .reset_command_buffer = pool.reset_command_buffer,
            .cmd_pipeline_barrier = pool.cmd_pipeline_barrier,
            .cmd_clear_color_image = pool.cmd_clear_color_image,
            .cmd_begin_debug_utils_label_ext = pool.cmd_begin_debug_utils_label_ext,
            .cmd_end_debug_utils_label_ext = pool.cmd_end_debug_utils_label_ext,
            .cmd_insert_debug_utils_label_ext = pool.cmd_insert_debug_utils_label_ext,
        };
    }

    /// Returns the live raw handle for explicit FFI integration.
    pub fn rawHandle(pool: *const CommandPool) Error!raw.VkCommandPool {
        return pool._handle orelse error.InactiveObject;
    }
};

pub const SwapchainOptions = struct {
    surface: *const Surface,
    min_image_count: u32,
    image_format: Format,
    image_color_space: ColorSpace,
    image_extent: Extent2D,
    image_usage: ImageUsageFlags,
    image_array_layers: u32 = 1,
    queue_family_indices: []const QueueFamilyIndex = &.{},
    pre_transform: SurfaceTransformBit = .identity,
    composite_alpha: CompositeAlphaBit = .opaque_,
    present_mode: PresentMode = .fifo,
    clipped: bool = true,
    old_swapchain: ?*const Swapchain = null,
    flags: SwapchainCreateFlags = .empty,
    next: ?*const anyopaque = null,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks = null,

    pub fn validate(options: SwapchainOptions, device: *const Device) Error!void {
        const device_handle = device._handle orelse return error.InactiveObject;
        if (options.surface._instance_handle != device._instance_handle) return error.InvalidHandle;
        _ = try options.surface.rawHandle();
        if (options.min_image_count == 0 or options.image_array_layers == 0) {
            return error.InvalidOptions;
        }
        if (options.image_extent.width == 0 or options.image_extent.height == 0) {
            return error.InvalidOptions;
        }
        _ = try count32(options.queue_family_indices.len);
        if (options.queue_family_indices.len > device_queue_count_max) {
            return error.CountOverflow;
        }
        for (options.queue_family_indices, 0..) |family_index, index| {
            for (options.queue_family_indices[0..index]) |previous_index| {
                if (family_index == previous_index) return error.InvalidOptions;
            }
        }
        if (options.old_swapchain) |old| {
            if (old._device_handle != device_handle) return error.InvalidHandle;
            _ = try old.rawHandle();
        }
    }
};

pub const AcquireOptions = struct {
    timeout: Timeout = .infinite,
    semaphore: ?*const Semaphore = null,
    fence: ?*const Fence = null,
};

pub const AcquireResult = union(enum) {
    success: SwapchainImageIndex,
    suboptimal: SwapchainImageIndex,
    timeout,
    not_ready,
    out_of_date,
};

pub const PresentOptions = struct {
    swapchain: *const Swapchain,
    image_index: SwapchainImageIndex,
    wait_semaphores: []const *const Semaphore = &.{},
    next: ?*const anyopaque = null,
};

pub const PresentStatus = enum {
    success,
    suboptimal,
    out_of_date,
};

/// An owned `VkSwapchainKHR`. Destroy it before its parent device.
pub const Swapchain = struct {
    _handle: ?SwapchainHandle,
    _device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_swapchain: CommandFunction(raw.PFN_vkDestroySwapchainKHR),
    get_swapchain_images: CommandFunction(raw.PFN_vkGetSwapchainImagesKHR),
    acquire_next_image: CommandFunction(raw.PFN_vkAcquireNextImageKHR),

    pub fn deinit(swapchain: *Swapchain) void {
        const handle = swapchain._handle orelse return;
        swapchain.destroy_swapchain(
            swapchain._device_handle,
            handle,
            swapchain.allocation_callbacks,
        );
        swapchain._handle = null;
    }

    pub fn rawHandle(swapchain: *const Swapchain) Error!raw.VkSwapchainKHR {
        return swapchain._handle orelse error.InactiveObject;
    }

    pub fn imageCount(swapchain: *const Swapchain) Error!u32 {
        const handle = try swapchain.rawHandle();
        var count: u32 = 0;
        try checkSuccess(swapchain.get_swapchain_images(
            swapchain._device_handle,
            handle,
            &count,
            null,
        ));
        try validateEnumerationCount(count);
        return count;
    }

    /// Returns non-owning images whose lifetime is controlled by the swapchain.
    pub fn images(
        swapchain: *const Swapchain,
        gpa: std.mem.Allocator,
    ) (Error || std.mem.Allocator.Error)![]SwapchainImage {
        var images_buffer = try gpa.alloc(SwapchainImage, try swapchain.imageCount());
        errdefer gpa.free(images_buffer);
        for (0..enumeration_attempt_count_max) |_| {
            const written = swapchain.imagesInto(images_buffer) catch |err| switch (err) {
                error.BufferTooSmall => {
                    const count = try nextEnumerationCapacity(
                        try swapchain.imageCount(),
                        images_buffer.len,
                    );
                    images_buffer = try gpa.realloc(images_buffer, count);
                    continue;
                },
                else => |other| return other,
            };
            return gpa.realloc(images_buffer, written.len);
        }
        return error.EnumerationUnstable;
    }

    /// Writes borrowed swapchain images into caller-owned storage without allocation.
    pub fn imagesInto(
        swapchain: *const Swapchain,
        storage: []SwapchainImage,
    ) Error![]SwapchainImage {
        if (storage.len > swapchain_image_count_max) return error.CountOverflow;
        const handle = try swapchain.rawHandle();
        const live_handle = handle orelse return error.InvalidHandle;
        var raw_images: [swapchain_image_count_max]raw.VkImage = undefined;
        var written: u32 = @intCast(storage.len);
        const output: [*c]raw.VkImage = if (storage.len == 0) null else &raw_images;
        const result = swapchain.get_swapchain_images(
            swapchain._device_handle,
            handle,
            &written,
            output,
        );
        if (result == raw.VK_INCOMPLETE) return error.BufferTooSmall;
        try checkSuccess(result);
        if (written > storage.len) return error.BufferTooSmall;
        for (storage[0..written], raw_images[0..written], 0..) |*image, raw_image, index| {
            image.* = .{
                ._handle = raw_image orelse return error.InvalidHandle,
                ._device_handle = swapchain._device_handle,
                ._swapchain_handle = live_handle,
                .index = .fromRaw(@intCast(index)),
            };
        }
        return storage[0..written];
    }

    pub fn acquireNextImage(
        swapchain: *const Swapchain,
        options: AcquireOptions,
    ) Error!AcquireResult {
        if (options.semaphore == null and options.fence == null) return error.InvalidOptions;
        const semaphore = if (options.semaphore) |semaphore| blk: {
            if (semaphore._device_handle != swapchain._device_handle) return error.InvalidHandle;
            break :blk try semaphore.rawHandle();
        } else null;
        const fence = if (options.fence) |fence| blk: {
            if (fence._device_handle != swapchain._device_handle) return error.InvalidHandle;
            break :blk try fence.rawHandle();
        } else null;
        var image_index: u32 = 0;
        const result = swapchain.acquire_next_image(
            swapchain._device_handle,
            try swapchain.rawHandle(),
            options.timeout.toRaw(),
            semaphore,
            fence,
            &image_index,
        );
        if (result == raw.VK_SUCCESS) return .{ .success = .fromRaw(image_index) };
        if (result == raw.VK_SUBOPTIMAL_KHR) return .{ .suboptimal = .fromRaw(image_index) };
        if (result == raw.VK_TIMEOUT) return .timeout;
        if (result == raw.VK_NOT_READY) return .not_ready;
        if (result == raw.VK_ERROR_OUT_OF_DATE_KHR) return .out_of_date;
        try checkSuccess(result);
        unreachable;
    }
};

pub const PhysicalDeviceLimits = struct {
    max_image_dimension_2d: u32,
    max_image_dimension_3d: u32,
    max_image_dimension_cube: u32,
    max_memory_allocation_count: u32,
    max_sampler_allocation_count: u32,
    buffer_image_granularity: u64,
    sparse_address_space_size: u64,
    max_bound_descriptor_sets: u32,
    max_push_constants_size: u32,
    max_compute_shared_memory_size: u32,
    max_compute_work_group_count: [3]u32,
    max_compute_work_group_invocations: u32,
    max_compute_work_group_size: [3]u32,
    max_sampler_anisotropy: f32,
    max_viewports: u32,
    max_viewport_dimensions: [2]u32,
    viewport_bounds_range: [2]f32,
    min_uniform_buffer_offset_alignment: u64,
    min_storage_buffer_offset_alignment: u64,
    non_coherent_atom_size: u64,
    max_framebuffer_width: u32,
    max_framebuffer_height: u32,
    max_framebuffer_layers: u32,
    max_color_attachments: u32,
    timestamp_period_nanoseconds: f32,

    pub fn fromRaw(value: *const raw.VkPhysicalDeviceLimits) PhysicalDeviceLimits {
        return .{
            .max_image_dimension_2d = value.maxImageDimension2D,
            .max_image_dimension_3d = value.maxImageDimension3D,
            .max_image_dimension_cube = value.maxImageDimensionCube,
            .max_memory_allocation_count = value.maxMemoryAllocationCount,
            .max_sampler_allocation_count = value.maxSamplerAllocationCount,
            .buffer_image_granularity = value.bufferImageGranularity,
            .sparse_address_space_size = value.sparseAddressSpaceSize,
            .max_bound_descriptor_sets = value.maxBoundDescriptorSets,
            .max_push_constants_size = value.maxPushConstantsSize,
            .max_compute_shared_memory_size = value.maxComputeSharedMemorySize,
            .max_compute_work_group_count = value.maxComputeWorkGroupCount,
            .max_compute_work_group_invocations = value.maxComputeWorkGroupInvocations,
            .max_compute_work_group_size = value.maxComputeWorkGroupSize,
            .max_sampler_anisotropy = value.maxSamplerAnisotropy,
            .max_viewports = value.maxViewports,
            .max_viewport_dimensions = value.maxViewportDimensions,
            .viewport_bounds_range = value.viewportBoundsRange,
            .min_uniform_buffer_offset_alignment = value.minUniformBufferOffsetAlignment,
            .min_storage_buffer_offset_alignment = value.minStorageBufferOffsetAlignment,
            .non_coherent_atom_size = value.nonCoherentAtomSize,
            .max_framebuffer_width = value.maxFramebufferWidth,
            .max_framebuffer_height = value.maxFramebufferHeight,
            .max_framebuffer_layers = value.maxFramebufferLayers,
            .max_color_attachments = value.maxColorAttachments,
            .timestamp_period_nanoseconds = value.timestampPeriod,
        };
    }
};

pub const SparseProperties = struct {
    standard_2d_block_shape: bool,
    standard_2d_multisample_block_shape: bool,
    standard_3d_block_shape: bool,
    aligned_mip_size: bool,
    non_resident_strict: bool,

    pub fn fromRaw(value: *const raw.VkPhysicalDeviceSparseProperties) SparseProperties {
        return .{
            .standard_2d_block_shape = value.residencyStandard2DBlockShape != raw.VK_FALSE,
            .standard_2d_multisample_block_shape = value.residencyStandard2DMultisampleBlockShape != raw.VK_FALSE,
            .standard_3d_block_shape = value.residencyStandard3DBlockShape != raw.VK_FALSE,
            .aligned_mip_size = value.residencyAlignedMipSize != raw.VK_FALSE,
            .non_resident_strict = value.residencyNonResidentStrict != raw.VK_FALSE,
        };
    }
};

pub const PhysicalDeviceProperties = struct {
    api_version: Version,
    driver_version_raw: u32,
    vendor_id: u32,
    device_id: u32,
    device_type: PhysicalDeviceType,
    device_name: [raw.VK_MAX_PHYSICAL_DEVICE_NAME_SIZE]u8,
    pipeline_cache_uuid: [raw.VK_UUID_SIZE]u8,
    limits: PhysicalDeviceLimits,
    sparse: SparseProperties,

    pub fn fromRaw(value: *const raw.VkPhysicalDeviceProperties) PhysicalDeviceProperties {
        return .{
            .api_version = .decode(value.apiVersion),
            .driver_version_raw = value.driverVersion,
            .vendor_id = value.vendorID,
            .device_id = value.deviceID,
            .device_type = .fromRaw(value.deviceType),
            .device_name = value.deviceName,
            .pipeline_cache_uuid = value.pipelineCacheUUID,
            .limits = .fromRaw(&value.limits),
            .sparse = .fromRaw(&value.sparseProperties),
        };
    }

    pub fn name(properties: *const PhysicalDeviceProperties) []const u8 {
        return boundedCString(&properties.device_name);
    }

    pub fn isDiscrete(properties: PhysicalDeviceProperties) bool {
        return properties.device_type == .discrete_gpu;
    }

    pub fn supportsApiVersion(
        properties: PhysicalDeviceProperties,
        minimum: Version,
    ) bool {
        return properties.api_version.atLeast(minimum);
    }
};

pub const FormatProperties = struct {
    linear_tiling_features: FormatFeatureFlags,
    optimal_tiling_features: FormatFeatureFlags,
    buffer_features: FormatFeatureFlags,

    pub fn fromRaw(value: raw.VkFormatProperties) FormatProperties {
        return .{
            .linear_tiling_features = .fromRaw(value.linearTilingFeatures),
            .optimal_tiling_features = .fromRaw(value.optimalTilingFeatures),
            .buffer_features = .fromRaw(value.bufferFeatures),
        };
    }
};

pub const ImageFormatOptions = struct {
    format: Format,
    image_type: ImageType,
    tiling: ImageTiling,
    usage: ImageUsageFlags,
    flags: ImageCreateFlags = .empty,
};

pub const ImageFormatProperties = struct {
    extent_max: Extent3D,
    mip_level_count_max: u32,
    array_layer_count_max: u32,
    sample_counts: SampleCountFlags,
    resource_size_max: u64,

    pub fn fromRaw(value: raw.VkImageFormatProperties) ImageFormatProperties {
        return .{
            .extent_max = .fromRaw(value.maxExtent),
            .mip_level_count_max = value.maxMipLevels,
            .array_layer_count_max = value.maxArrayLayers,
            .sample_counts = .fromRaw(value.sampleCounts),
            .resource_size_max = value.maxResourceSize,
        };
    }
};

pub const PhysicalDevice = struct {
    _handle: PhysicalDeviceHandle,
    _instance_handle: InstanceHandle,
    dispatch: InstanceDispatch,

    /// Returns the non-owning raw physical-device handle for FFI integration.
    pub fn rawHandle(device: *const PhysicalDevice) raw.VkPhysicalDevice {
        return device._handle;
    }

    pub fn propertiesRaw(device: *const PhysicalDevice) raw.VkPhysicalDeviceProperties {
        var value: raw.VkPhysicalDeviceProperties = .{};
        device.dispatch.get_physical_device_properties(device._handle, &value);
        return value;
    }

    pub fn properties(device: *const PhysicalDevice) PhysicalDeviceProperties {
        const value = device.propertiesRaw();
        return .fromRaw(&value);
    }

    pub fn formatProperties(
        device: *const PhysicalDevice,
        format: Format,
    ) FormatProperties {
        var value: raw.VkFormatProperties = .{};
        device.dispatch.get_physical_device_format_properties(
            device._handle,
            format.toRaw(),
            &value,
        );
        return .fromRaw(value);
    }

    pub fn imageFormatProperties(
        device: *const PhysicalDevice,
        options: ImageFormatOptions,
    ) Error!?ImageFormatProperties {
        var value: raw.VkImageFormatProperties = .{};
        const result = device.dispatch.get_physical_device_image_format_properties(
            device._handle,
            options.format.toRaw(),
            options.image_type.toRaw(),
            options.tiling.toRaw(),
            options.usage.toRaw(),
            options.flags.toRaw(),
            &value,
        );
        if (result == raw.VK_ERROR_FORMAT_NOT_SUPPORTED) return null;
        try checkSuccess(result);
        return .fromRaw(value);
    }

    pub fn features(device: *const PhysicalDevice) raw.VkPhysicalDeviceFeatures {
        var value: raw.VkPhysicalDeviceFeatures = .{};
        device.dispatch.get_physical_device_features(device._handle, &value);
        return value;
    }

    /// Queries core and chained feature structures. `next` must point to a mutable
    /// Vulkan feature structure whose lifetime covers this call.
    pub fn features2(
        device: *const PhysicalDevice,
        next: ?*anyopaque,
    ) Error!raw.VkPhysicalDeviceFeatures2 {
        const get_features = device.dispatch.get_physical_device_features2 orelse {
            return error.MissingCommand;
        };
        var value: raw.VkPhysicalDeviceFeatures2 = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
            .pNext = next,
        };
        get_features(device._handle, &value);
        return value;
    }

    /// Returns the raw fixed-capacity Vulkan structure for diagnostics and interop.
    pub fn memoryPropertiesRaw(device: *const PhysicalDevice) raw.VkPhysicalDeviceMemoryProperties {
        var value: raw.VkPhysicalDeviceMemoryProperties = .{};
        device.dispatch.get_physical_device_memory_properties(device._handle, &value);
        return value;
    }

    /// Returns an owned typed snapshot whose slices borrow from the returned value.
    pub fn memoryProperties(device: *const PhysicalDevice) Error!MemoryProperties {
        var memory: MemoryProperties = undefined;
        try device.memoryPropertiesInto(&memory);
        return memory;
    }

    /// Initializes caller-owned typed storage without returning a large intermediate value.
    pub fn memoryPropertiesInto(
        device: *const PhysicalDevice,
        memory: *MemoryProperties,
    ) Error!void {
        const raw_properties = device.memoryPropertiesRaw();
        try memory.initFromRaw(&raw_properties);
    }

    pub fn queueFamilyProperties(
        device: *const PhysicalDevice,
        gpa: std.mem.Allocator,
    ) (Error || std.mem.Allocator.Error)![]raw.VkQueueFamilyProperties {
        var count: u32 = 0;
        device.dispatch.get_physical_device_queue_family_properties(
            device._handle,
            &count,
            null,
        );
        try validateEnumerationCount(count);
        if (count == 0) return gpa.alloc(raw.VkQueueFamilyProperties, 0);

        var queue_properties = try gpa.alloc(raw.VkQueueFamilyProperties, count);
        errdefer gpa.free(queue_properties);
        for (0..enumeration_attempt_count_max) |_| {
            var written: u32 = @intCast(queue_properties.len);
            device.dispatch.get_physical_device_queue_family_properties(
                device._handle,
                &written,
                queue_properties.ptr,
            );
            try validateEnumerationCount(written);
            if (written <= queue_properties.len) {
                return gpa.realloc(queue_properties, written);
            }
            queue_properties = try gpa.realloc(queue_properties, written);
        }
        return error.EnumerationUnstable;
    }

    pub fn queueFamilies(
        device: *const PhysicalDevice,
        gpa: std.mem.Allocator,
    ) (Error || std.mem.Allocator.Error)![]QueueFamily {
        const queue_properties = try device.queueFamilyProperties(gpa);
        defer gpa.free(queue_properties);
        const families = try gpa.alloc(QueueFamily, queue_properties.len);
        for (families, queue_properties, 0..) |*family, property, index| {
            family.* = .{
                .index = .fromRaw(@intCast(index)),
                .flags = .fromRaw(property.queueFlags),
                .queue_count = property.queueCount,
                .timestamp_valid_bits = property.timestampValidBits,
                .minimum_image_transfer_granularity = .fromRaw(
                    property.minImageTransferGranularity,
                ),
            };
        }
        return families;
    }

    pub fn deviceExtensions(
        device: *const PhysicalDevice,
        gpa: std.mem.Allocator,
        layer_name: ?[:0]const u8,
    ) (Error || std.mem.Allocator.Error)![]raw.VkExtensionProperties {
        return enumerateDeviceExtensions(
            gpa,
            device.dispatch.enumerate_device_extension_properties,
            device._handle,
            layer_name,
        );
    }

    pub fn surfaceSupport(
        device: *const PhysicalDevice,
        surface: *const Surface,
        family_index: QueueFamilyIndex,
    ) Error!bool {
        if (surface._instance_handle != device._instance_handle) return error.InvalidHandle;
        const surface_handle = try surface.rawHandle();
        const get_support = device.dispatch.get_physical_device_surface_support_khr orelse {
            return error.MissingCommand;
        };
        var supported: raw.VkBool32 = raw.VK_FALSE;
        try checkSuccess(get_support(
            device._handle,
            family_index.toRaw(),
            surface_handle,
            &supported,
        ));
        return supported != raw.VK_FALSE;
    }

    pub fn surfaceCapabilities(
        device: *const PhysicalDevice,
        surface: *const Surface,
    ) Error!SurfaceCapabilities {
        if (surface._instance_handle != device._instance_handle) return error.InvalidHandle;
        const get_capabilities =
            device.dispatch.get_physical_device_surface_capabilities_khr orelse {
                return error.MissingCommand;
            };
        var capabilities: raw.VkSurfaceCapabilitiesKHR = .{};
        try checkSuccess(get_capabilities(
            device._handle,
            try surface.rawHandle(),
            &capabilities,
        ));
        return .fromRaw(capabilities);
    }

    pub fn surfaceFormatCount(
        device: *const PhysicalDevice,
        surface: *const Surface,
    ) Error!u32 {
        if (surface._instance_handle != device._instance_handle) return error.InvalidHandle;
        const get_formats = device.dispatch.get_physical_device_surface_formats_khr orelse {
            return error.MissingCommand;
        };
        return surfaceFormatCountRaw(
            get_formats,
            device._handle,
            try surface.rawHandle(),
        );
    }

    pub fn surfaceFormats(
        device: *const PhysicalDevice,
        gpa: std.mem.Allocator,
        surface: *const Surface,
    ) (Error || std.mem.Allocator.Error)![]SurfaceFormat {
        if (surface._instance_handle != device._instance_handle) return error.InvalidHandle;
        const get_formats = device.dispatch.get_physical_device_surface_formats_khr orelse {
            return error.MissingCommand;
        };
        return enumerateSurfaceFormats(
            gpa,
            get_formats,
            device._handle,
            try surface.rawHandle(),
        );
    }

    pub fn surfaceFormatsInto(
        device: *const PhysicalDevice,
        surface: *const Surface,
        storage: []SurfaceFormat,
    ) Error![]SurfaceFormat {
        if (surface._instance_handle != device._instance_handle) return error.InvalidHandle;
        const get_formats = device.dispatch.get_physical_device_surface_formats_khr orelse {
            return error.MissingCommand;
        };
        return enumerateSurfaceFormatsInto(
            get_formats,
            device._handle,
            try surface.rawHandle(),
            storage,
        );
    }

    pub fn presentModeCount(
        device: *const PhysicalDevice,
        surface: *const Surface,
    ) Error!u32 {
        if (surface._instance_handle != device._instance_handle) return error.InvalidHandle;
        const get_present_modes =
            device.dispatch.get_physical_device_surface_present_modes_khr orelse {
                return error.MissingCommand;
            };
        return presentModeCountRaw(
            get_present_modes,
            device._handle,
            try surface.rawHandle(),
        );
    }

    pub fn presentModes(
        device: *const PhysicalDevice,
        gpa: std.mem.Allocator,
        surface: *const Surface,
    ) (Error || std.mem.Allocator.Error)![]PresentMode {
        if (surface._instance_handle != device._instance_handle) return error.InvalidHandle;
        const get_present_modes =
            device.dispatch.get_physical_device_surface_present_modes_khr orelse {
                return error.MissingCommand;
            };
        return enumeratePresentModes(
            gpa,
            get_present_modes,
            device._handle,
            try surface.rawHandle(),
        );
    }

    pub fn presentModesInto(
        device: *const PhysicalDevice,
        surface: *const Surface,
        storage: []PresentMode,
    ) Error![]PresentMode {
        if (surface._instance_handle != device._instance_handle) return error.InvalidHandle;
        const get_present_modes =
            device.dispatch.get_physical_device_surface_present_modes_khr orelse {
                return error.MissingCommand;
            };
        return enumeratePresentModesInto(
            get_present_modes,
            device._handle,
            try surface.rawHandle(),
            storage,
        );
    }

    pub fn findMemoryTypeIndex(
        device: *const PhysicalDevice,
        options: MemoryTypeOptions,
    ) Error!MemoryTypeIndex {
        const memory = try device.memoryProperties();
        return memory.findType(options);
    }

    pub fn createDevice(
        physical_device: *const PhysicalDevice,
        options: DeviceOptions,
    ) Error!Device {
        try options.validate();

        var queue_infos: [device_queue_count_max]raw.VkDeviceQueueCreateInfo = undefined;
        for (options.queues, 0..) |queue, index| {
            queue_infos[index] = .{
                .sType = raw.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .pNext = queue.next,
                .flags = queue.flags,
                .queueFamilyIndex = queue.family_index.toRaw(),
                .queueCount = @intCast(queue.priorities.len),
                .pQueuePriorities = queue.priorities.ptr,
            };
        }

        var extension_pointers: [name_count_max][*c]const u8 = undefined;
        var extension_count = try fillNamePointers(options.extensions, &extension_pointers);
        if (options.enable_portability_subset) {
            if (platform != .metal) return error.PortabilityNotSupported;
            const portability_extension = portability_device_extensions[0];
            if (!containsName(options.extensions, portability_extension)) {
                if (extension_count == extension_pointers.len) return error.CountOverflow;
                extension_pointers[extension_count] = portability_extension.ptr;
                extension_count += 1;
            }
        }

        const create_info: raw.VkDeviceCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = options.next,
            .flags = options.flags,
            .queueCreateInfoCount = @intCast(options.queues.len),
            .pQueueCreateInfos = queue_infos[0..options.queues.len].ptr,
            .enabledExtensionCount = @intCast(extension_count),
            .ppEnabledExtensionNames = pointerArray(extension_pointers[0..extension_count]),
            .pEnabledFeatures = options.enabled_features,
        };
        return physical_device.createDeviceRaw(&create_info, options.allocation_callbacks);
    }

    pub fn createDeviceRaw(
        physical_device: *const PhysicalDevice,
        create_info: *const raw.VkDeviceCreateInfo,
        allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    ) Error!Device {
        var handle: raw.VkDevice = null;
        try checkSuccess(physical_device.dispatch.create_device(
            physical_device._handle,
            create_info,
            allocation_callbacks,
            &handle,
        ));
        const live_handle = handle orelse return error.InvalidHandle;

        const dispatch = DeviceDispatch.init(
            physical_device.dispatch.get_device_proc_addr,
            live_handle,
        ) catch |load_error| {
            if (loadDevice(
                physical_device.dispatch.get_device_proc_addr,
                live_handle,
                raw.PFN_vkDestroyDevice,
                "vkDestroyDevice",
            )) |destroy| {
                destroy(live_handle, allocation_callbacks);
            }
            return load_error;
        };
        return .{
            ._handle = live_handle,
            ._instance_handle = physical_device._instance_handle,
            .allocation_callbacks = allocation_callbacks,
            .dispatch = dispatch,
        };
    }
};

pub const QueueCapability = enum {
    graphics,
    compute,
    transfer,
    sparse_binding,
    protected,
};

pub const QueueFamily = struct {
    index: QueueFamilyIndex,
    flags: QueueFlags,
    queue_count: u32,
    timestamp_valid_bits: u32,
    minimum_image_transfer_granularity: Extent3D,

    pub fn queueCount(family: QueueFamily) u32 {
        return family.queue_count;
    }

    pub fn supports(family: QueueFamily, capability: QueueCapability) bool {
        if (family.queue_count == 0) return false;
        const bit: QueueBit = switch (capability) {
            .graphics => .graphics,
            .compute => .compute,
            .transfer => .transfer,
            .sparse_binding => .sparse_binding,
            .protected => .protected,
        };
        return family.flags.contains(bit);
    }

    pub fn presentationSupport(
        family: QueueFamily,
        device: *const PhysicalDevice,
        surface: *const Surface,
    ) Error!bool {
        return device.surfaceSupport(surface, family.index);
    }
};

pub const QueueFamilySelectionOptions = struct {
    required: QueueFlags,
    preferred: QueueFlags = .empty,
};

pub fn selectQueueFamily(
    families: []const QueueFamily,
    options: QueueFamilySelectionOptions,
) Error!QueueFamilyIndex {
    var selected: ?QueueFamilyIndex = null;
    var selected_score: u32 = 0;
    for (families) |family| {
        if (family.queue_count == 0) continue;
        if (!family.flags.containsAll(options.required)) continue;
        const score: u32 = @intCast(@popCount(
            family.flags.toRaw() & options.preferred.toRaw(),
        ));
        if (selected == null or score > selected_score) {
            selected = family.index;
            selected_score = score;
        }
    }
    return selected orelse error.QueueFamilyNotFound;
}

pub fn selectQueueFamilyForSurface(
    device: *const PhysicalDevice,
    families: []const QueueFamily,
    surface: *const Surface,
    options: QueueFamilySelectionOptions,
) Error!QueueFamilyIndex {
    var selected: ?QueueFamilyIndex = null;
    var selected_score: u32 = 0;
    for (families) |family| {
        if (family.queue_count == 0) continue;
        if (!family.flags.containsAll(options.required)) continue;
        if (!try family.presentationSupport(device, surface)) continue;
        const score: u32 = @intCast(@popCount(
            family.flags.toRaw() & options.preferred.toRaw(),
        ));
        if (selected == null or score > selected_score) {
            selected = family.index;
            selected_score = score;
        }
    }
    return selected orelse error.QueueFamilyNotFound;
}

pub const MemoryTypeOptions = struct {
    type_bits: u32,
    required_flags: MemoryPropertyFlags,
    preferred_flags: MemoryPropertyFlags = .empty,
};

pub const MemoryType = struct {
    index: MemoryTypeIndex,
    heap_index: MemoryHeapIndex,
    flags: MemoryPropertyFlags,

    pub fn supports(memory_type: MemoryType, required_flags: MemoryPropertyFlags) bool {
        return memory_type.flags.containsAll(required_flags);
    }
};

pub const MemoryHeap = struct {
    index: MemoryHeapIndex,
    size_bytes: u64,
    flags: MemoryHeapFlags,

    pub fn isDeviceLocal(heap: MemoryHeap) bool {
        return heap.flags.contains(.device_local);
    }
};

/// An owned typed snapshot of a physical device's bounded memory properties.
/// Slices returned by `types` and `heaps` borrow from this value.
pub const MemoryProperties = struct {
    _memory_types: [memory_type_count_max]MemoryType,
    _memory_heaps: [memory_heap_count_max]MemoryHeap,
    _memory_type_count: u32,
    _memory_heap_count: u32,

    pub fn fromRaw(
        raw_properties: *const raw.VkPhysicalDeviceMemoryProperties,
    ) Error!MemoryProperties {
        var properties: MemoryProperties = undefined;
        try properties.initFromRaw(raw_properties);
        return properties;
    }

    pub fn initFromRaw(
        properties: *MemoryProperties,
        raw_properties: *const raw.VkPhysicalDeviceMemoryProperties,
    ) Error!void {
        if (raw_properties.memoryTypeCount > memory_type_count_max) {
            return error.InvalidProperties;
        }
        if (raw_properties.memoryHeapCount > memory_heap_count_max) {
            return error.InvalidProperties;
        }

        properties._memory_type_count = raw_properties.memoryTypeCount;
        properties._memory_heap_count = raw_properties.memoryHeapCount;
        for (
            raw_properties.memoryHeaps[0..raw_properties.memoryHeapCount],
            properties._memory_heaps[0..raw_properties.memoryHeapCount],
            0..,
        ) |raw_heap, *memory_heap, index| {
            memory_heap.* = .{
                .index = .fromRaw(@intCast(index)),
                .size_bytes = raw_heap.size,
                .flags = .fromRaw(raw_heap.flags),
            };
        }
        for (
            raw_properties.memoryTypes[0..raw_properties.memoryTypeCount],
            properties._memory_types[0..raw_properties.memoryTypeCount],
            0..,
        ) |raw_type, *memory_type, index| {
            if (raw_type.heapIndex >= raw_properties.memoryHeapCount) {
                return error.InvalidProperties;
            }
            memory_type.* = .{
                .index = .fromRaw(@intCast(index)),
                .heap_index = .fromRaw(raw_type.heapIndex),
                .flags = .fromRaw(raw_type.propertyFlags),
            };
        }
    }

    pub fn types(properties: *const MemoryProperties) []const MemoryType {
        return properties._memory_types[0..properties._memory_type_count];
    }

    pub fn heaps(properties: *const MemoryProperties) []const MemoryHeap {
        return properties._memory_heaps[0..properties._memory_heap_count];
    }

    pub fn heap(
        properties: *const MemoryProperties,
        index: MemoryHeapIndex,
    ) ?*const MemoryHeap {
        const offset: usize = index.toRaw();
        if (offset >= properties._memory_heap_count) return null;
        return &properties._memory_heaps[offset];
    }

    pub fn deviceLocalBytes(properties: *const MemoryProperties) Error!u64 {
        var size_bytes_total: u64 = 0;
        for (properties.heaps()) |memory_heap| {
            if (!memory_heap.isDeviceLocal()) continue;
            size_bytes_total = std.math.add(u64, size_bytes_total, memory_heap.size_bytes) catch {
                return error.SizeOverflow;
            };
        }
        return size_bytes_total;
    }

    /// Selects a compatible type, preferring the candidate with the most preferred flags.
    pub fn findType(
        properties: *const MemoryProperties,
        options: MemoryTypeOptions,
    ) Error!MemoryTypeIndex {
        var best_index: ?MemoryTypeIndex = null;
        var best_score: u32 = 0;
        for (properties.types()) |memory_type| {
            const index_u32 = memory_type.index.toRaw();
            const type_bit = @as(u32, 1) << @intCast(index_u32);
            if ((options.type_bits & type_bit) == 0) continue;
            if (!memory_type.supports(options.required_flags)) continue;

            const score: u32 = @intCast(@popCount(
                memory_type.flags.toRaw() & options.preferred_flags.toRaw(),
            ));
            if (best_index == null or score > best_score) {
                best_index = memory_type.index;
                best_score = score;
            }
        }
        return best_index orelse error.MemoryTypeNotFound;
    }
};

/// Selects a compatible type from typed memory properties.
pub fn selectMemoryTypeIndex(
    properties: *const MemoryProperties,
    options: MemoryTypeOptions,
) Error!MemoryTypeIndex {
    return properties.findType(options);
}

/// Performs typed selection from a raw snapshot for advanced diagnostics and interop.
pub fn selectMemoryTypeIndexRaw(
    raw_properties: *const raw.VkPhysicalDeviceMemoryProperties,
    options: MemoryTypeOptions,
) Error!MemoryTypeIndex {
    const properties = try MemoryProperties.fromRaw(raw_properties);
    return properties.findType(options);
}

pub const DeviceQueueOptions = struct {
    family_index: QueueFamilyIndex,
    priorities: []const f32,
    flags: raw.VkDeviceQueueCreateFlags = 0,
    next: ?*const anyopaque = null,
};

pub const DeviceOptions = struct {
    queues: []const DeviceQueueOptions,
    extensions: []const [:0]const u8 = &.{},
    enabled_features: ?*const raw.VkPhysicalDeviceFeatures = null,
    flags: raw.VkDeviceCreateFlags = 0,
    next: ?*const anyopaque = null,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks = null,
    enable_portability_subset: bool = false,

    /// Validates the bounded queue and extension inputs without calling Vulkan.
    pub fn validate(options: DeviceOptions) Error!void {
        if (options.queues.len == 0) return error.InvalidOptions;
        if (options.queues.len > device_queue_count_max) return error.CountOverflow;
        if (options.extensions.len > name_count_max) return error.CountOverflow;
        for (options.queues, 0..) |queue, queue_index| {
            if (queue.priorities.len == 0) return error.InvalidOptions;
            if (queue.priorities.len > std.math.maxInt(u32)) return error.CountOverflow;
            for (queue.priorities) |priority| {
                if (!std.math.isFinite(priority)) return error.InvalidOptions;
                if (priority < 0.0) return error.InvalidOptions;
                if (priority > 1.0) return error.InvalidOptions;
            }
            for (options.queues[0..queue_index]) |previous_queue| {
                if (previous_queue.family_index == queue.family_index) {
                    return error.InvalidOptions;
                }
            }
        }
        if (options.enable_portability_subset and platform != .metal) {
            return error.PortabilityNotSupported;
        }
    }
};

pub const Device = struct {
    _handle: ?DeviceHandle,
    _instance_handle: InstanceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: DeviceDispatch,

    pub fn deinit(device: *Device) void {
        const handle = device._handle orelse return;
        device.dispatch.destroy_device(handle, device.allocation_callbacks);
        device._handle = null;
    }

    /// Returns the live raw handle for explicit FFI integration.
    pub fn rawHandle(device: *const Device) Error!raw.VkDevice {
        return device._handle orelse error.InactiveObject;
    }

    pub fn waitIdle(device: *const Device) Error!void {
        const handle = device._handle orelse return error.InactiveObject;
        try checkSuccess(device.dispatch.device_wait_idle(handle));
    }

    pub fn queue(
        device: *const Device,
        family_index: QueueFamilyIndex,
        queue_index: QueueIndex,
    ) Error!Queue {
        const device_handle = device._handle orelse return error.InactiveObject;
        var handle: raw.VkQueue = null;
        device.dispatch.get_device_queue(
            device_handle,
            family_index.toRaw(),
            queue_index.toRaw(),
            &handle,
        );
        const insert_label = device.dispatch.queue_insert_debug_utils_label_ext;
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._device_handle = device_handle,
            .queue_submit = device.dispatch.queue_submit,
            .queue_wait_idle = device.dispatch.queue_wait_idle,
            .queue_present_khr = device.dispatch.queue_present_khr,
            .queue_begin_debug_utils_label_ext = device.dispatch.queue_begin_debug_utils_label_ext,
            .queue_end_debug_utils_label_ext = device.dispatch.queue_end_debug_utils_label_ext,
            .queue_insert_debug_utils_label_ext = insert_label,
        };
    }

    pub fn load(
        device: *const Device,
        comptime descriptor: anytype,
    ) Error!?DescriptorFunction(descriptor, .device) {
        const Descriptor = @TypeOf(descriptor);
        const handle = device._handle orelse return error.InactiveObject;
        return loadDevice(
            device.dispatch.get_device_proc_addr,
            handle,
            Descriptor.Pfn,
            Descriptor.name,
        );
    }

    pub fn require(
        device: *const Device,
        comptime descriptor: anytype,
    ) Error!DescriptorFunction(descriptor, .device) {
        return (try device.load(descriptor)) orelse error.MissingCommand;
    }

    /// Loads a dynamic command name without verifying that it matches the PFN type.
    pub fn loadUnchecked(
        device: *const Device,
        comptime OptionalFunction: type,
        name: [:0]const u8,
    ) Error!?CommandFunction(OptionalFunction) {
        const handle = device._handle orelse return error.InactiveObject;
        return loadDevice(device.dispatch.get_device_proc_addr, handle, OptionalFunction, name);
    }

    pub fn setObjectName(
        device: *const Device,
        object: ext.debug_utils.Object,
        name: [:0]const u8,
    ) Error!void {
        const device_handle = device._handle orelse return error.InactiveObject;
        const set_name = device.dispatch.set_debug_utils_object_name_ext orelse {
            return error.MissingCommand;
        };
        try object.validateParent(device);
        const object_info = try object.info();
        const name_info: raw.VkDebugUtilsObjectNameInfoEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT,
            .objectType = object_info.object_type,
            .objectHandle = object_info.handle,
            .pObjectName = name.ptr,
        };
        try checkSuccess(set_name(device_handle, &name_info));
    }

    pub fn createImageView(
        device: *const Device,
        options: ImageViewOptions,
    ) Error!ImageView {
        const device_handle = device._handle orelse return error.InactiveObject;
        if (options.image._device_handle != device_handle) return error.InvalidHandle;
        const create_info: raw.VkImageViewCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = options.image._handle,
            .viewType = options.view_type.toRaw(),
            .format = options.format.toRaw(),
            .components = options.components.toRaw(),
            .subresourceRange = options.subresource_range.toRaw(),
        };
        var handle: raw.VkImageView = null;
        const result = device.dispatch.create_image_view(
            device_handle,
            &create_info,
            device.allocation_callbacks,
            &handle,
        );
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional_handle| {
                device.dispatch.destroy_image_view(
                    device_handle,
                    provisional_handle,
                    device.allocation_callbacks,
                );
            }
            try checkSuccess(result);
            unreachable;
        }
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._device_handle = device_handle,
            .allocation_callbacks = device.allocation_callbacks,
            .destroy_image_view = device.dispatch.destroy_image_view,
        };
    }

    pub fn createSemaphore(
        device: *const Device,
        _: SemaphoreOptions,
    ) Error!Semaphore {
        const device_handle = device._handle orelse return error.InactiveObject;
        const create_info: raw.VkSemaphoreCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        };
        var handle: raw.VkSemaphore = null;
        const result = device.dispatch.create_semaphore(
            device_handle,
            &create_info,
            device.allocation_callbacks,
            &handle,
        );
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional_handle| {
                device.dispatch.destroy_semaphore(
                    device_handle,
                    provisional_handle,
                    device.allocation_callbacks,
                );
            }
            try checkSuccess(result);
            unreachable;
        }
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._device_handle = device_handle,
            .allocation_callbacks = device.allocation_callbacks,
            .destroy_semaphore = device.dispatch.destroy_semaphore,
        };
    }

    pub fn createFence(device: *const Device, options: FenceOptions) Error!Fence {
        const device_handle = device._handle orelse return error.InactiveObject;
        const flags = if (options.signaled)
            FenceCreateFlags.init(&.{.signaled})
        else
            FenceCreateFlags.empty;
        const create_info: raw.VkFenceCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .flags = flags.toRaw(),
        };
        var handle: raw.VkFence = null;
        const result = device.dispatch.create_fence(
            device_handle,
            &create_info,
            device.allocation_callbacks,
            &handle,
        );
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional_handle| {
                device.dispatch.destroy_fence(
                    device_handle,
                    provisional_handle,
                    device.allocation_callbacks,
                );
            }
            try checkSuccess(result);
            unreachable;
        }
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._device_handle = device_handle,
            .allocation_callbacks = device.allocation_callbacks,
            .destroy_fence = device.dispatch.destroy_fence,
            .reset_fences = device.dispatch.reset_fences,
            .wait_for_fences = device.dispatch.wait_for_fences,
        };
    }

    pub fn createCommandPool(
        device: *const Device,
        options: CommandPoolOptions,
    ) Error!CommandPool {
        const device_handle = device._handle orelse return error.InactiveObject;
        const create_info: raw.VkCommandPoolCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .flags = options.flags.toRaw(),
            .queueFamilyIndex = options.family_index.toRaw(),
        };
        var handle: raw.VkCommandPool = null;
        const result = device.dispatch.create_command_pool(
            device_handle,
            &create_info,
            device.allocation_callbacks,
            &handle,
        );
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional_handle| {
                device.dispatch.destroy_command_pool(
                    device_handle,
                    provisional_handle,
                    device.allocation_callbacks,
                );
            }
            try checkSuccess(result);
            unreachable;
        }
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._device_handle = device_handle,
            .buffers_can_reset = options.flags.contains(.reset_command_buffer),
            .allocation_callbacks = device.allocation_callbacks,
            .destroy_command_pool = device.dispatch.destroy_command_pool,
            .allocate_command_buffers = device.dispatch.allocate_command_buffers,
            .begin_command_buffer = device.dispatch.begin_command_buffer,
            .end_command_buffer = device.dispatch.end_command_buffer,
            .reset_command_buffer = device.dispatch.reset_command_buffer,
            .cmd_pipeline_barrier = device.dispatch.cmd_pipeline_barrier,
            .cmd_clear_color_image = device.dispatch.cmd_clear_color_image,
            .cmd_begin_debug_utils_label_ext = device.dispatch.cmd_begin_debug_utils_label_ext,
            .cmd_end_debug_utils_label_ext = device.dispatch.cmd_end_debug_utils_label_ext,
            .cmd_insert_debug_utils_label_ext = device.dispatch.cmd_insert_debug_utils_label_ext,
        };
    }

    pub fn createSwapchain(
        device: *const Device,
        options: SwapchainOptions,
    ) Error!Swapchain {
        const device_handle = device._handle orelse return error.InactiveObject;
        try options.validate(device);
        const create_swapchain = device.dispatch.create_swapchain_khr orelse {
            return error.MissingCommand;
        };
        const destroy_swapchain = device.dispatch.destroy_swapchain_khr orelse {
            return error.MissingCommand;
        };
        const get_images = device.dispatch.get_swapchain_images_khr orelse {
            return error.MissingCommand;
        };
        const acquire_next_image = device.dispatch.acquire_next_image_khr orelse {
            return error.MissingCommand;
        };

        const old_handle = if (options.old_swapchain) |old|
            try old.rawHandle()
        else
            null;
        const concurrent = options.queue_family_indices.len > 1;
        var queue_family_indices_raw: [device_queue_count_max]u32 = undefined;
        for (options.queue_family_indices, queue_family_indices_raw[0..options.queue_family_indices.len]) |family_index, *raw_index| {
            raw_index.* = family_index.toRaw();
        }
        const create_info: raw.VkSwapchainCreateInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .pNext = options.next,
            .flags = options.flags.toRaw(),
            .surface = try options.surface.rawHandle(),
            .minImageCount = options.min_image_count,
            .imageFormat = options.image_format.toRaw(),
            .imageColorSpace = options.image_color_space.toRaw(),
            .imageExtent = options.image_extent.toRaw(),
            .imageArrayLayers = options.image_array_layers,
            .imageUsage = options.image_usage.toRaw(),
            .imageSharingMode = if (concurrent)
                raw.VK_SHARING_MODE_CONCURRENT
            else
                raw.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = if (concurrent)
                @intCast(options.queue_family_indices.len)
            else
                0,
            .pQueueFamilyIndices = if (concurrent)
                queue_family_indices_raw[0..options.queue_family_indices.len].ptr
            else
                null,
            .preTransform = options.pre_transform.toRaw(),
            .compositeAlpha = options.composite_alpha.toRaw(),
            .presentMode = options.present_mode.toRaw(),
            .clipped = if (options.clipped) raw.VK_TRUE else raw.VK_FALSE,
            .oldSwapchain = old_handle,
        };
        var handle: raw.VkSwapchainKHR = null;
        const result = create_swapchain(
            device_handle,
            &create_info,
            options.allocation_callbacks,
            &handle,
        );
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional_handle| {
                destroy_swapchain(device_handle, provisional_handle, options.allocation_callbacks);
            }
            try checkSuccess(result);
            unreachable;
        }
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._device_handle = device_handle,
            .allocation_callbacks = options.allocation_callbacks,
            .destroy_swapchain = destroy_swapchain,
            .get_swapchain_images = get_images,
            .acquire_next_image = acquire_next_image,
        };
    }

    pub fn beginCommandBufferLabelRaw(
        device: *const Device,
        command_buffer: raw.VkCommandBuffer,
        options: ext.debug_utils.LabelOptions,
    ) Error!void {
        _ = device._handle orelse return error.InactiveObject;
        const begin_label = device.dispatch.cmd_begin_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        const live_command_buffer = command_buffer orelse return error.InvalidHandle;
        const label = options.createInfo();
        begin_label(live_command_buffer, &label);
    }

    pub fn endCommandBufferLabelRaw(
        device: *const Device,
        command_buffer: raw.VkCommandBuffer,
    ) Error!void {
        _ = device._handle orelse return error.InactiveObject;
        const end_label = device.dispatch.cmd_end_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        end_label(command_buffer orelse return error.InvalidHandle);
    }

    pub fn insertCommandBufferLabelRaw(
        device: *const Device,
        command_buffer: raw.VkCommandBuffer,
        options: ext.debug_utils.LabelOptions,
    ) Error!void {
        _ = device._handle orelse return error.InactiveObject;
        const insert_label = device.dispatch.cmd_insert_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        const live_command_buffer = command_buffer orelse return error.InvalidHandle;
        const label = options.createInfo();
        insert_label(live_command_buffer, &label);
    }
};

pub const SemaphoreWait = struct {
    semaphore: *const Semaphore,
    stage: PipelineStageFlags,
};

pub const SubmitOptions = struct {
    waits: []const SemaphoreWait = &.{},
    command_buffers: []const *const CommandBuffer = &.{},
    signals: []const *const Semaphore = &.{},
    fence: ?*const Fence = null,
};

pub const QueueLabelScope = struct {
    queue: QueueHandle,
    end_label: CommandFunction(raw.PFN_vkQueueEndDebugUtilsLabelEXT),
    active: bool = true,

    pub fn end(scope: *QueueLabelScope) void {
        if (!scope.active) return;
        scope.end_label(scope.queue);
        scope.active = false;
    }

    pub fn deinit(scope: *QueueLabelScope) void {
        scope.end();
    }
};

pub const Queue = struct {
    _handle: QueueHandle,
    _device_handle: DeviceHandle,
    queue_submit: CommandFunction(raw.PFN_vkQueueSubmit),
    queue_wait_idle: CommandFunction(raw.PFN_vkQueueWaitIdle),
    queue_present_khr: ?CommandFunction(raw.PFN_vkQueuePresentKHR),
    queue_begin_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkQueueBeginDebugUtilsLabelEXT),
    queue_end_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkQueueEndDebugUtilsLabelEXT),
    queue_insert_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkQueueInsertDebugUtilsLabelEXT),

    /// Returns the valid raw queue handle for explicit FFI integration.
    pub fn rawHandle(queue: *const Queue) raw.VkQueue {
        return queue._handle;
    }

    pub fn submit(
        queue: *const Queue,
        options: SubmitOptions,
    ) Error!void {
        if (options.waits.len > submission_item_count_max or
            options.command_buffers.len > submission_item_count_max or
            options.signals.len > submission_item_count_max)
        {
            return error.CountOverflow;
        }

        var wait_handles: [submission_item_count_max]raw.VkSemaphore = undefined;
        var wait_stages: [submission_item_count_max]raw.VkPipelineStageFlags = undefined;
        for (options.waits, wait_handles[0..options.waits.len], wait_stages[0..options.waits.len]) |wait, *handle, *stage| {
            if (wait.semaphore._device_handle != queue._device_handle) return error.InvalidHandle;
            handle.* = try wait.semaphore.rawHandle();
            stage.* = wait.stage.toRaw();
        }

        var command_handles: [submission_item_count_max]raw.VkCommandBuffer = undefined;
        for (options.command_buffers, command_handles[0..options.command_buffers.len]) |command_buffer, *handle| {
            if (command_buffer._device_handle != queue._device_handle) return error.InvalidHandle;
            if (command_buffer.state != .executable) return error.InvalidOptions;
            handle.* = command_buffer.rawHandle();
        }

        var signal_handles: [submission_item_count_max]raw.VkSemaphore = undefined;
        for (options.signals, signal_handles[0..options.signals.len]) |semaphore, *handle| {
            if (semaphore._device_handle != queue._device_handle) return error.InvalidHandle;
            handle.* = try semaphore.rawHandle();
        }

        const fence_handle = if (options.fence) |fence| blk: {
            if (fence._device_handle != queue._device_handle) return error.InvalidHandle;
            break :blk try fence.rawHandle();
        } else null;
        const submit_info: raw.VkSubmitInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = @intCast(options.waits.len),
            .pWaitSemaphores = if (options.waits.len == 0) null else wait_handles[0..options.waits.len].ptr,
            .pWaitDstStageMask = if (options.waits.len == 0) null else wait_stages[0..options.waits.len].ptr,
            .commandBufferCount = @intCast(options.command_buffers.len),
            .pCommandBuffers = if (options.command_buffers.len == 0) null else command_handles[0..options.command_buffers.len].ptr,
            .signalSemaphoreCount = @intCast(options.signals.len),
            .pSignalSemaphores = if (options.signals.len == 0) null else signal_handles[0..options.signals.len].ptr,
        };
        try checkSuccess(queue.queue_submit(queue._handle, 1, &submit_info, fence_handle));
    }

    /// Submits raw Vulkan structures for advanced extension or interop use.
    pub fn submitRaw(
        queue: *const Queue,
        submit_infos: []const raw.VkSubmitInfo,
        fence: raw.VkFence,
    ) Error!void {
        const submit_info_count = try count32(submit_infos.len);
        try checkSuccess(queue.queue_submit(
            queue._handle,
            submit_info_count,
            if (submit_infos.len == 0) null else submit_infos.ptr,
            fence,
        ));
    }

    pub fn waitIdle(queue: *const Queue) Error!void {
        try checkSuccess(queue.queue_wait_idle(queue._handle));
    }

    pub fn beginLabel(queue: *const Queue, options: ext.debug_utils.LabelOptions) Error!void {
        const begin_label = queue.queue_begin_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        const label = options.createInfo();
        begin_label(queue._handle, &label);
    }

    pub fn beginLabelScope(
        queue: *const Queue,
        options: ext.debug_utils.LabelOptions,
    ) Error!QueueLabelScope {
        const end_label = queue.queue_end_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        try queue.beginLabel(options);
        return .{ .queue = queue._handle, .end_label = end_label };
    }

    pub fn endLabel(queue: *const Queue) Error!void {
        const end_label = queue.queue_end_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        end_label(queue._handle);
    }

    pub fn insertLabel(queue: *const Queue, options: ext.debug_utils.LabelOptions) Error!void {
        const insert_label = queue.queue_insert_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        const label = options.createInfo();
        insert_label(queue._handle, &label);
    }

    pub fn present(queue: *const Queue, options: PresentOptions) Error!PresentStatus {
        const present_command = queue.queue_present_khr orelse return error.MissingCommand;
        if (options.swapchain._device_handle != queue._device_handle) return error.InvalidHandle;
        if (options.wait_semaphores.len > submission_item_count_max) return error.CountOverflow;
        const wait_count = try count32(options.wait_semaphores.len);
        var wait_handles: [submission_item_count_max]raw.VkSemaphore = undefined;
        for (options.wait_semaphores, wait_handles[0..options.wait_semaphores.len]) |semaphore, *handle| {
            if (semaphore._device_handle != queue._device_handle) return error.InvalidHandle;
            handle.* = try semaphore.rawHandle();
        }
        const swapchain_handle = try options.swapchain.rawHandle();
        const image_index = options.image_index.toRaw();
        const present_info: raw.VkPresentInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .pNext = options.next,
            .waitSemaphoreCount = wait_count,
            .pWaitSemaphores = if (options.wait_semaphores.len == 0)
                null
            else
                wait_handles[0..options.wait_semaphores.len].ptr,
            .swapchainCount = 1,
            .pSwapchains = @ptrCast(&swapchain_handle),
            .pImageIndices = @ptrCast(&image_index),
            .pResults = null,
        };
        const result = present_command(queue._handle, &present_info);
        if (result == raw.VK_SUCCESS) return .success;
        if (result == raw.VK_SUBOPTIMAL_KHR) return .suboptimal;
        if (result == raw.VK_ERROR_OUT_OF_DATE_KHR) return .out_of_date;
        try checkSuccess(result);
        unreachable;
    }
};

pub const ext = struct {
    pub const debug_utils = struct {
        pub const severity_flags = struct {
            pub const verbose: raw.VkDebugUtilsMessageSeverityFlagsEXT = @intCast(
                raw.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT,
            );
            pub const info: raw.VkDebugUtilsMessageSeverityFlagsEXT = @intCast(
                raw.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT,
            );
            pub const warning: raw.VkDebugUtilsMessageSeverityFlagsEXT = @intCast(
                raw.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT,
            );
            pub const err: raw.VkDebugUtilsMessageSeverityFlagsEXT = @intCast(
                raw.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            );
            pub const warning_and_error: raw.VkDebugUtilsMessageSeverityFlagsEXT =
                warning | err;
            pub const all: raw.VkDebugUtilsMessageSeverityFlagsEXT =
                verbose | info | warning | err;
        };

        pub const message_type_flags = struct {
            pub const general: raw.VkDebugUtilsMessageTypeFlagsEXT = @intCast(
                raw.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT,
            );
            pub const validation: raw.VkDebugUtilsMessageTypeFlagsEXT = @intCast(
                raw.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT,
            );
            pub const performance: raw.VkDebugUtilsMessageTypeFlagsEXT = @intCast(
                raw.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            );
            pub const device_address_binding: raw.VkDebugUtilsMessageTypeFlagsEXT = @intCast(
                raw.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT,
            );
            pub const standard: raw.VkDebugUtilsMessageTypeFlagsEXT =
                general | validation | performance;
            pub const all: raw.VkDebugUtilsMessageTypeFlagsEXT =
                standard | device_address_binding;
        };

        pub const HandlerResult = enum {
            continue_,
            abort,
        };

        pub const MessengerConfigOptions = struct {
            severity: raw.VkDebugUtilsMessageSeverityFlagsEXT =
                severity_flags.warning_and_error,
            message_types: raw.VkDebugUtilsMessageTypeFlagsEXT =
                message_type_flags.standard,
        };

        /// Type-erased configuration whose generated C trampoline remains private to vk-zig.
        pub const MessengerConfig = struct {
            _callback: CommandFunction(raw.PFN_vkDebugUtilsMessengerCallbackEXT),
            _handler: *const fn (?*anyopaque, Message) HandlerResult,
            _user_data: ?*anyopaque,
            _severity: raw.VkDebugUtilsMessageSeverityFlagsEXT,
            _message_types: raw.VkDebugUtilsMessageTypeFlagsEXT,

            /// The handler may return `void` to continue, or `HandlerResult` to allow aborting.
            /// Vulkan can invoke it concurrently, so captured global state must be synchronized.
            pub fn fromHandler(
                comptime handler: anytype,
                options: MessengerConfigOptions,
            ) MessengerConfig {
                validateHandler(@TypeOf(handler), null);
                const Adapter = HandlerAdapter(handler);
                return .{
                    ._callback = Adapter.callback,
                    ._handler = Adapter.handle,
                    ._user_data = null,
                    ._severity = options.severity,
                    ._message_types = options.message_types,
                };
            }

            /// The context pointer must remain valid until the parent instance is deinitialized.
            pub fn fromHandlerWithContext(
                context: anytype,
                options: MessengerConfigOptions,
                comptime handler: anytype,
            ) MessengerConfig {
                const ContextPointer = @TypeOf(context);
                const pointer_info = switch (@typeInfo(ContextPointer)) {
                    .pointer => |pointer| pointer,
                    else => @compileError("debug messenger context must be a pointer"),
                };
                if (pointer_info.size != .one) {
                    @compileError("debug messenger context must be a single-item pointer");
                }
                if (pointer_info.is_allowzero) {
                    @compileError("debug messenger context must not allow a zero address");
                }
                validateHandler(@TypeOf(handler), ContextPointer);

                const Adapter = ContextHandlerAdapter(ContextPointer, handler);
                const user_data: *anyopaque = if (pointer_info.is_const)
                    @ptrCast(@constCast(context))
                else
                    @ptrCast(context);
                return .{
                    ._callback = Adapter.callback,
                    ._handler = Adapter.handle,
                    ._user_data = user_data,
                    ._severity = options.severity,
                    ._message_types = options.message_types,
                };
            }

            /// Invokes the typed handler directly, primarily for application-level tests.
            pub fn dispatch(config: MessengerConfig, message: Message) HandlerResult {
                return config._handler(config._user_data, message);
            }

            fn createInfo(
                config: MessengerConfig,
                next: ?*const anyopaque,
            ) raw.VkDebugUtilsMessengerCreateInfoEXT {
                return .{
                    .sType = raw.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
                    .pNext = next,
                    .messageSeverity = config._severity,
                    .messageType = config._message_types,
                    .pfnUserCallback = config._callback,
                    .pUserData = config._user_data,
                };
            }

            fn rawOptions(
                config: MessengerConfig,
                allocation_callbacks: ?*const raw.VkAllocationCallbacks,
            ) MessengerOptions {
                return .{
                    .callback = config._callback,
                    .user_data = config._user_data,
                    .severity = config._severity,
                    .message_type = config._message_types,
                    .allocation_callbacks = allocation_callbacks,
                };
            }
        };

        /// Advanced raw-ABI configuration. Prefer `MessengerConfig` for normal Zig code.
        pub const MessengerOptions = struct {
            callback: CommandFunction(raw.PFN_vkDebugUtilsMessengerCallbackEXT),
            user_data: ?*anyopaque = null,
            severity: raw.VkDebugUtilsMessageSeverityFlagsEXT = severity_flags.warning_and_error,
            message_type: raw.VkDebugUtilsMessageTypeFlagsEXT = message_type_flags.standard,
            flags: raw.VkDebugUtilsMessengerCreateFlagsEXT = 0,
            next: ?*const anyopaque = null,
            allocation_callbacks: ?*const raw.VkAllocationCallbacks = null,

            /// Produces the same create info used by `Messenger.init`, suitable for
            /// chaining through `InstanceOptions.next` to receive creation messages.
            pub fn createInfo(options: MessengerOptions) raw.VkDebugUtilsMessengerCreateInfoEXT {
                return .{
                    .sType = raw.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
                    .pNext = options.next,
                    .flags = options.flags,
                    .messageSeverity = options.severity,
                    .messageType = options.message_type,
                    .pfnUserCallback = options.callback,
                    .pUserData = options.user_data,
                };
            }
        };

        /// A safe borrowed view over callback data. It is valid only during the callback.
        pub const Message = struct {
            severity: raw.VkDebugUtilsMessageSeverityFlagBitsEXT,
            message_type: raw.VkDebugUtilsMessageTypeFlagsEXT,
            data: *const raw.VkDebugUtilsMessengerCallbackDataEXT,

            pub fn fromCallback(
                severity: raw.VkDebugUtilsMessageSeverityFlagBitsEXT,
                message_type: raw.VkDebugUtilsMessageTypeFlagsEXT,
                data: [*c]const raw.VkDebugUtilsMessengerCallbackDataEXT,
            ) ?Message {
                if (data == null) return null;
                return .{
                    .severity = severity,
                    .message_type = message_type,
                    .data = @ptrCast(data),
                };
            }

            pub fn text(message: Message) ?[]const u8 {
                return optionalCString(message.data.pMessage);
            }

            pub fn idName(message: Message) ?[]const u8 {
                return optionalCString(message.data.pMessageIdName);
            }

            pub fn isError(message: Message) bool {
                return (message.severity & severity_flags.err) != 0;
            }

            pub fn isWarning(message: Message) bool {
                return (message.severity & severity_flags.warning) != 0;
            }

            pub fn isInfo(message: Message) bool {
                return (message.severity & severity_flags.info) != 0;
            }

            pub fn isVerbose(message: Message) bool {
                return (message.severity & severity_flags.verbose) != 0;
            }

            pub fn objects(message: Message) []const raw.VkDebugUtilsObjectNameInfoEXT {
                if (message.data.objectCount == 0 or message.data.pObjects == null) return &.{};
                return message.data.pObjects[0..message.data.objectCount];
            }

            pub fn queueLabels(message: Message) []const raw.VkDebugUtilsLabelEXT {
                if (message.data.queueLabelCount == 0 or
                    message.data.pQueueLabels == null) return &.{};
                return message.data.pQueueLabels[0..message.data.queueLabelCount];
            }

            pub fn commandBufferLabels(message: Message) []const raw.VkDebugUtilsLabelEXT {
                if (message.data.cmdBufLabelCount == 0 or
                    message.data.pCmdBufLabels == null) return &.{};
                return message.data.pCmdBufLabels[0..message.data.cmdBufLabelCount];
            }
        };

        fn validateHandler(
            comptime Handler: type,
            comptime ContextPointer: ?type,
        ) void {
            const function_info = switch (@typeInfo(Handler)) {
                .@"fn" => |function| function,
                else => @compileError("debug message handler must be a function"),
            };
            const parameter_count: usize = if (ContextPointer == null) 1 else 2;
            if (function_info.params.len != parameter_count) {
                @compileError("debug message handler has the wrong parameter count");
            }
            if (ContextPointer) |ExpectedContext| {
                const actual_context = function_info.params[0].type orelse {
                    @compileError("debug message handler context type must be explicit");
                };
                if (actual_context != ExpectedContext) {
                    @compileError("debug message handler context type does not match its pointer");
                }
            }
            const message_index: usize = if (ContextPointer == null) 0 else 1;
            const actual_message = function_info.params[message_index].type orelse {
                @compileError("debug message handler message type must be explicit");
            };
            if (actual_message != Message) {
                @compileError("debug message handler must accept debug_utils.Message");
            }
            const Return = function_info.return_type orelse {
                @compileError("debug message handler must have an explicit return type");
            };
            if (Return != void and Return != HandlerResult) {
                @compileError("debug message handler must return void or HandlerResult");
            }
        }

        fn invokeHandler(
            comptime handler: anytype,
            arguments: anytype,
        ) HandlerResult {
            const Return = @typeInfo(@TypeOf(handler)).@"fn".return_type.?;
            if (Return == void) {
                @call(.auto, handler, arguments);
                return .continue_;
            }
            return @call(.auto, handler, arguments);
        }

        fn rawHandlerResult(result: HandlerResult) raw.VkBool32 {
            return switch (result) {
                .continue_ => raw.VK_FALSE,
                .abort => raw.VK_TRUE,
            };
        }

        fn HandlerAdapter(comptime handler: anytype) type {
            return struct {
                fn handle(_: ?*anyopaque, message: Message) HandlerResult {
                    return invokeHandler(handler, .{message});
                }

                fn callback(
                    severity: raw.VkDebugUtilsMessageSeverityFlagBitsEXT,
                    message_type: raw.VkDebugUtilsMessageTypeFlagsEXT,
                    callback_data: [*c]const raw.VkDebugUtilsMessengerCallbackDataEXT,
                    _: ?*anyopaque,
                ) callconv(.c) raw.VkBool32 {
                    const message = Message.fromCallback(
                        severity,
                        message_type,
                        callback_data,
                    ) orelse return raw.VK_FALSE;
                    return rawHandlerResult(handle(null, message));
                }
            };
        }

        fn ContextHandlerAdapter(
            comptime ContextPointer: type,
            comptime handler: anytype,
        ) type {
            return struct {
                fn handle(user_data: ?*anyopaque, message: Message) HandlerResult {
                    const opaque_context = user_data orelse return .continue_;
                    const context: ContextPointer = @ptrCast(@alignCast(opaque_context));
                    return invokeHandler(handler, .{ context, message });
                }

                fn callback(
                    severity: raw.VkDebugUtilsMessageSeverityFlagBitsEXT,
                    message_type: raw.VkDebugUtilsMessageTypeFlagsEXT,
                    callback_data: [*c]const raw.VkDebugUtilsMessengerCallbackDataEXT,
                    user_data: ?*anyopaque,
                ) callconv(.c) raw.VkBool32 {
                    const message = Message.fromCallback(
                        severity,
                        message_type,
                        callback_data,
                    ) orelse return raw.VK_FALSE;
                    return rawHandlerResult(handle(user_data, message));
                }
            };
        }

        pub const LabelOptions = struct {
            name: [:0]const u8,
            color: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },
            next: ?*const anyopaque = null,

            pub fn createInfo(options: LabelOptions) raw.VkDebugUtilsLabelEXT {
                return .{
                    .sType = raw.VK_STRUCTURE_TYPE_DEBUG_UTILS_LABEL_EXT,
                    .pNext = options.next,
                    .pLabelName = options.name.ptr,
                    .color = options.color,
                };
            }
        };

        pub const Messenger = struct {
            _handle: ?DebugMessengerHandle,
            _instance_handle: InstanceHandle,
            allocation_callbacks: ?*const raw.VkAllocationCallbacks,
            destroy_messenger: CommandFunction(raw.PFN_vkDestroyDebugUtilsMessengerEXT),

            fn initConfig(
                instance: *const Instance,
                config: MessengerConfig,
                allocation_callbacks: ?*const raw.VkAllocationCallbacks,
            ) Error!Messenger {
                return init(instance, config.rawOptions(allocation_callbacks));
            }

            /// Advanced raw-ABI creation. Prefer `InstanceOptions.debug_messenger`.
            pub fn init(instance: *const Instance, options: MessengerOptions) Error!Messenger {
                const instance_handle = instance._handle orelse return error.InactiveObject;
                const create_messenger = (try instance.load(
                    command.create_debug_utils_messenger_ext,
                )) orelse return error.MissingCommand;
                const destroy_messenger = (try instance.load(
                    command.destroy_debug_utils_messenger_ext,
                )) orelse return error.MissingCommand;

                const create_info = options.createInfo();
                var handle: raw.VkDebugUtilsMessengerEXT = null;
                const result = create_messenger(
                    instance_handle,
                    &create_info,
                    options.allocation_callbacks,
                    &handle,
                );
                if (result != raw.VK_SUCCESS) {
                    if (handle) |provisional_handle| {
                        destroy_messenger(
                            instance_handle,
                            provisional_handle,
                            options.allocation_callbacks,
                        );
                    }
                    try checkSuccess(result);
                    unreachable;
                }

                return .{
                    ._handle = handle orelse return error.InvalidHandle,
                    ._instance_handle = instance_handle,
                    .allocation_callbacks = options.allocation_callbacks,
                    .destroy_messenger = destroy_messenger,
                };
            }

            pub fn deinit(messenger: *Messenger) void {
                const handle = messenger._handle orelse return;
                messenger.destroy_messenger(
                    messenger._instance_handle,
                    handle,
                    messenger.allocation_callbacks,
                );
                messenger._handle = null;
            }

            /// Returns the live raw handle for explicit FFI integration.
            pub fn rawHandle(messenger: *const Messenger) Error!raw.VkDebugUtilsMessengerEXT {
                return messenger._handle orelse error.InactiveObject;
            }
        };

        pub const Object = union(enum) {
            device: *const Device,
            queue: *const Queue,
            surface: *const Surface,
            swapchain: *const Swapchain,
            semaphore: *const Semaphore,
            command_buffer: *const CommandBuffer,
            fence: *const Fence,
            image: *const SwapchainImage,
            image_view: *const ImageView,
            command_pool: *const CommandPool,
            raw_semaphore: raw.VkSemaphore,
            raw_command_buffer: raw.VkCommandBuffer,
            raw_fence: raw.VkFence,
            device_memory: raw.VkDeviceMemory,
            buffer: raw.VkBuffer,
            raw_image: raw.VkImage,
            event: raw.VkEvent,
            query_pool: raw.VkQueryPool,
            buffer_view: raw.VkBufferView,
            raw_image_view: raw.VkImageView,
            shader_module: raw.VkShaderModule,
            pipeline_cache: raw.VkPipelineCache,
            pipeline_layout: raw.VkPipelineLayout,
            render_pass: raw.VkRenderPass,
            pipeline: raw.VkPipeline,
            descriptor_set_layout: raw.VkDescriptorSetLayout,
            sampler: raw.VkSampler,
            descriptor_pool: raw.VkDescriptorPool,
            descriptor_set: raw.VkDescriptorSet,
            framebuffer: raw.VkFramebuffer,
            raw_command_pool: raw.VkCommandPool,
            raw_surface: raw.VkSurfaceKHR,
            raw_swapchain: raw.VkSwapchainKHR,

            const Info = struct {
                object_type: raw.VkObjectType,
                handle: u64,
            };

            fn info(object: Object) Error!Info {
                return switch (object) {
                    .device => |device| .{
                        .object_type = @intCast(raw.VK_OBJECT_TYPE_DEVICE),
                        .handle = try handleValue(try device.rawHandle()),
                    },
                    .queue => |queue| .{
                        .object_type = @intCast(raw.VK_OBJECT_TYPE_QUEUE),
                        .handle = try handleValue(queue.rawHandle()),
                    },
                    .surface => |surface| .{
                        .object_type = @intCast(raw.VK_OBJECT_TYPE_SURFACE_KHR),
                        .handle = try handleValue(try surface.rawHandle()),
                    },
                    .swapchain => |swapchain| .{
                        .object_type = @intCast(raw.VK_OBJECT_TYPE_SWAPCHAIN_KHR),
                        .handle = try handleValue(try swapchain.rawHandle()),
                    },
                    .semaphore => |semaphore| .{
                        .object_type = @intCast(raw.VK_OBJECT_TYPE_SEMAPHORE),
                        .handle = try handleValue(try semaphore.rawHandle()),
                    },
                    .command_buffer => |command_buffer| .{
                        .object_type = @intCast(raw.VK_OBJECT_TYPE_COMMAND_BUFFER),
                        .handle = try handleValue(command_buffer.rawHandle()),
                    },
                    .fence => |fence| .{
                        .object_type = @intCast(raw.VK_OBJECT_TYPE_FENCE),
                        .handle = try handleValue(try fence.rawHandle()),
                    },
                    .image => |image| .{
                        .object_type = @intCast(raw.VK_OBJECT_TYPE_IMAGE),
                        .handle = try handleValue(image.rawHandle()),
                    },
                    .image_view => |image_view| .{
                        .object_type = @intCast(raw.VK_OBJECT_TYPE_IMAGE_VIEW),
                        .handle = try handleValue(try image_view.rawHandle()),
                    },
                    .command_pool => |command_pool| .{
                        .object_type = @intCast(raw.VK_OBJECT_TYPE_COMMAND_POOL),
                        .handle = try handleValue(try command_pool.rawHandle()),
                    },
                    inline else => |handle, tag| .{
                        .object_type = objectType(tag),
                        .handle = try handleValue(handle),
                    },
                };
            }

            fn objectType(comptime tag: std.meta.Tag(Object)) raw.VkObjectType {
                return @intCast(switch (tag) {
                    .device,
                    .queue,
                    .surface,
                    .swapchain,
                    .semaphore,
                    .command_buffer,
                    .fence,
                    .image,
                    .image_view,
                    .command_pool,
                    => unreachable,
                    .raw_semaphore => raw.VK_OBJECT_TYPE_SEMAPHORE,
                    .raw_command_buffer => raw.VK_OBJECT_TYPE_COMMAND_BUFFER,
                    .raw_fence => raw.VK_OBJECT_TYPE_FENCE,
                    .device_memory => raw.VK_OBJECT_TYPE_DEVICE_MEMORY,
                    .buffer => raw.VK_OBJECT_TYPE_BUFFER,
                    .raw_image => raw.VK_OBJECT_TYPE_IMAGE,
                    .event => raw.VK_OBJECT_TYPE_EVENT,
                    .query_pool => raw.VK_OBJECT_TYPE_QUERY_POOL,
                    .buffer_view => raw.VK_OBJECT_TYPE_BUFFER_VIEW,
                    .raw_image_view => raw.VK_OBJECT_TYPE_IMAGE_VIEW,
                    .shader_module => raw.VK_OBJECT_TYPE_SHADER_MODULE,
                    .pipeline_cache => raw.VK_OBJECT_TYPE_PIPELINE_CACHE,
                    .pipeline_layout => raw.VK_OBJECT_TYPE_PIPELINE_LAYOUT,
                    .render_pass => raw.VK_OBJECT_TYPE_RENDER_PASS,
                    .pipeline => raw.VK_OBJECT_TYPE_PIPELINE,
                    .descriptor_set_layout => raw.VK_OBJECT_TYPE_DESCRIPTOR_SET_LAYOUT,
                    .sampler => raw.VK_OBJECT_TYPE_SAMPLER,
                    .descriptor_pool => raw.VK_OBJECT_TYPE_DESCRIPTOR_POOL,
                    .descriptor_set => raw.VK_OBJECT_TYPE_DESCRIPTOR_SET,
                    .framebuffer => raw.VK_OBJECT_TYPE_FRAMEBUFFER,
                    .raw_command_pool => raw.VK_OBJECT_TYPE_COMMAND_POOL,
                    .raw_surface => raw.VK_OBJECT_TYPE_SURFACE_KHR,
                    .raw_swapchain => raw.VK_OBJECT_TYPE_SWAPCHAIN_KHR,
                });
            }

            fn validateParent(object: Object, device: *const Device) Error!void {
                const device_handle = device._handle orelse return error.InactiveObject;
                switch (object) {
                    .device => |named_device| {
                        if (try named_device.rawHandle() != device_handle) {
                            return error.InvalidHandle;
                        }
                    },
                    .queue => |queue| {
                        if (queue._device_handle != device_handle) return error.InvalidHandle;
                    },
                    .surface => |surface| {
                        if (surface._instance_handle != device._instance_handle) {
                            return error.InvalidHandle;
                        }
                    },
                    .swapchain => |swapchain| {
                        if (swapchain._device_handle != device_handle) return error.InvalidHandle;
                    },
                    .semaphore => |semaphore| {
                        if (semaphore._device_handle != device_handle) return error.InvalidHandle;
                        _ = try semaphore.rawHandle();
                    },
                    .command_buffer => |command_buffer| {
                        if (command_buffer._device_handle != device_handle) return error.InvalidHandle;
                    },
                    .fence => |fence| {
                        if (fence._device_handle != device_handle) return error.InvalidHandle;
                        _ = try fence.rawHandle();
                    },
                    .image => |image| {
                        if (image._device_handle != device_handle) return error.InvalidHandle;
                    },
                    .image_view => |image_view| {
                        if (image_view._device_handle != device_handle) return error.InvalidHandle;
                        _ = try image_view.rawHandle();
                    },
                    .command_pool => |command_pool| {
                        if (command_pool._device_handle != device_handle) return error.InvalidHandle;
                        _ = try command_pool.rawHandle();
                    },
                    else => {},
                }
            }
        };
    };
};

const InstanceDispatch = struct {
    get_instance_proc_addr: CommandFunction(raw.PFN_vkGetInstanceProcAddr),
    get_device_proc_addr: CommandFunction(raw.PFN_vkGetDeviceProcAddr),
    destroy_instance: CommandFunction(raw.PFN_vkDestroyInstance),
    enumerate_physical_devices: CommandFunction(raw.PFN_vkEnumeratePhysicalDevices),
    get_physical_device_properties: CommandFunction(raw.PFN_vkGetPhysicalDeviceProperties),
    get_physical_device_format_properties: CommandFunction(
        raw.PFN_vkGetPhysicalDeviceFormatProperties,
    ),
    get_physical_device_image_format_properties: CommandFunction(
        raw.PFN_vkGetPhysicalDeviceImageFormatProperties,
    ),
    get_physical_device_features: CommandFunction(raw.PFN_vkGetPhysicalDeviceFeatures),
    get_physical_device_features2: ?CommandFunction(raw.PFN_vkGetPhysicalDeviceFeatures2),
    get_physical_device_memory_properties: CommandFunction(
        raw.PFN_vkGetPhysicalDeviceMemoryProperties,
    ),
    get_physical_device_queue_family_properties: CommandFunction(
        raw.PFN_vkGetPhysicalDeviceQueueFamilyProperties,
    ),
    enumerate_device_extension_properties: CommandFunction(
        raw.PFN_vkEnumerateDeviceExtensionProperties,
    ),
    get_physical_device_surface_support_khr: ?CommandFunction(
        raw.PFN_vkGetPhysicalDeviceSurfaceSupportKHR,
    ),
    get_physical_device_surface_capabilities_khr: ?CommandFunction(
        raw.PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR,
    ),
    get_physical_device_surface_formats_khr: ?CommandFunction(
        raw.PFN_vkGetPhysicalDeviceSurfaceFormatsKHR,
    ),
    get_physical_device_surface_present_modes_khr: ?CommandFunction(
        raw.PFN_vkGetPhysicalDeviceSurfacePresentModesKHR,
    ),
    create_device: CommandFunction(raw.PFN_vkCreateDevice),

    fn init(
        get_instance_proc_addr: CommandFunction(raw.PFN_vkGetInstanceProcAddr),
        handle: raw.VkInstance,
    ) Error!InstanceDispatch {
        return .{
            .get_instance_proc_addr = get_instance_proc_addr,
            .get_device_proc_addr = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetDeviceProcAddr,
                "vkGetDeviceProcAddr",
            ),
            .destroy_instance = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkDestroyInstance,
                "vkDestroyInstance",
            ),
            .enumerate_physical_devices = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkEnumeratePhysicalDevices,
                "vkEnumeratePhysicalDevices",
            ),
            .get_physical_device_properties = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceProperties,
                "vkGetPhysicalDeviceProperties",
            ),
            .get_physical_device_format_properties = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceFormatProperties,
                "vkGetPhysicalDeviceFormatProperties",
            ),
            .get_physical_device_image_format_properties = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceImageFormatProperties,
                "vkGetPhysicalDeviceImageFormatProperties",
            ),
            .get_physical_device_features = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceFeatures,
                "vkGetPhysicalDeviceFeatures",
            ),
            .get_physical_device_features2 = loadInstance(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceFeatures2,
                "vkGetPhysicalDeviceFeatures2",
            ) orelse loadInstance(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceFeatures2,
                "vkGetPhysicalDeviceFeatures2KHR",
            ),
            .get_physical_device_memory_properties = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceMemoryProperties,
                "vkGetPhysicalDeviceMemoryProperties",
            ),
            .get_physical_device_queue_family_properties = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceQueueFamilyProperties,
                "vkGetPhysicalDeviceQueueFamilyProperties",
            ),
            .enumerate_device_extension_properties = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkEnumerateDeviceExtensionProperties,
                "vkEnumerateDeviceExtensionProperties",
            ),
            .get_physical_device_surface_support_khr = loadInstance(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceSurfaceSupportKHR,
                "vkGetPhysicalDeviceSurfaceSupportKHR",
            ),
            .get_physical_device_surface_capabilities_khr = loadInstance(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR,
                "vkGetPhysicalDeviceSurfaceCapabilitiesKHR",
            ),
            .get_physical_device_surface_formats_khr = loadInstance(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceSurfaceFormatsKHR,
                "vkGetPhysicalDeviceSurfaceFormatsKHR",
            ),
            .get_physical_device_surface_present_modes_khr = loadInstance(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceSurfacePresentModesKHR,
                "vkGetPhysicalDeviceSurfacePresentModesKHR",
            ),
            .create_device = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkCreateDevice,
                "vkCreateDevice",
            ),
        };
    }
};

const DeviceDispatch = struct {
    get_device_proc_addr: CommandFunction(raw.PFN_vkGetDeviceProcAddr),
    destroy_device: CommandFunction(raw.PFN_vkDestroyDevice),
    get_device_queue: CommandFunction(raw.PFN_vkGetDeviceQueue),
    queue_submit: CommandFunction(raw.PFN_vkQueueSubmit),
    queue_wait_idle: CommandFunction(raw.PFN_vkQueueWaitIdle),
    device_wait_idle: CommandFunction(raw.PFN_vkDeviceWaitIdle),
    create_image_view: CommandFunction(raw.PFN_vkCreateImageView),
    destroy_image_view: CommandFunction(raw.PFN_vkDestroyImageView),
    create_semaphore: CommandFunction(raw.PFN_vkCreateSemaphore),
    destroy_semaphore: CommandFunction(raw.PFN_vkDestroySemaphore),
    create_fence: CommandFunction(raw.PFN_vkCreateFence),
    destroy_fence: CommandFunction(raw.PFN_vkDestroyFence),
    reset_fences: CommandFunction(raw.PFN_vkResetFences),
    wait_for_fences: CommandFunction(raw.PFN_vkWaitForFences),
    create_command_pool: CommandFunction(raw.PFN_vkCreateCommandPool),
    destroy_command_pool: CommandFunction(raw.PFN_vkDestroyCommandPool),
    allocate_command_buffers: CommandFunction(raw.PFN_vkAllocateCommandBuffers),
    begin_command_buffer: CommandFunction(raw.PFN_vkBeginCommandBuffer),
    end_command_buffer: CommandFunction(raw.PFN_vkEndCommandBuffer),
    reset_command_buffer: CommandFunction(raw.PFN_vkResetCommandBuffer),
    cmd_pipeline_barrier: CommandFunction(raw.PFN_vkCmdPipelineBarrier),
    cmd_clear_color_image: CommandFunction(raw.PFN_vkCmdClearColorImage),
    create_swapchain_khr: ?CommandFunction(raw.PFN_vkCreateSwapchainKHR),
    destroy_swapchain_khr: ?CommandFunction(raw.PFN_vkDestroySwapchainKHR),
    get_swapchain_images_khr: ?CommandFunction(raw.PFN_vkGetSwapchainImagesKHR),
    acquire_next_image_khr: ?CommandFunction(raw.PFN_vkAcquireNextImageKHR),
    queue_present_khr: ?CommandFunction(raw.PFN_vkQueuePresentKHR),
    set_debug_utils_object_name_ext: ?CommandFunction(raw.PFN_vkSetDebugUtilsObjectNameEXT),
    queue_begin_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkQueueBeginDebugUtilsLabelEXT),
    queue_end_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkQueueEndDebugUtilsLabelEXT),
    queue_insert_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkQueueInsertDebugUtilsLabelEXT),
    cmd_begin_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdBeginDebugUtilsLabelEXT),
    cmd_end_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdEndDebugUtilsLabelEXT),
    cmd_insert_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkCmdInsertDebugUtilsLabelEXT),

    fn init(
        get_device_proc_addr: CommandFunction(raw.PFN_vkGetDeviceProcAddr),
        handle: raw.VkDevice,
    ) Error!DeviceDispatch {
        return .{
            .get_device_proc_addr = get_device_proc_addr,
            .destroy_device = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyDevice,
                "vkDestroyDevice",
            ),
            .get_device_queue = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkGetDeviceQueue,
                "vkGetDeviceQueue",
            ),
            .queue_submit = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkQueueSubmit,
                "vkQueueSubmit",
            ),
            .queue_wait_idle = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkQueueWaitIdle,
                "vkQueueWaitIdle",
            ),
            .device_wait_idle = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDeviceWaitIdle,
                "vkDeviceWaitIdle",
            ),
            .create_image_view = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateImageView,
                "vkCreateImageView",
            ),
            .destroy_image_view = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyImageView,
                "vkDestroyImageView",
            ),
            .create_semaphore = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateSemaphore,
                "vkCreateSemaphore",
            ),
            .destroy_semaphore = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroySemaphore,
                "vkDestroySemaphore",
            ),
            .create_fence = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateFence,
                "vkCreateFence",
            ),
            .destroy_fence = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyFence,
                "vkDestroyFence",
            ),
            .reset_fences = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkResetFences,
                "vkResetFences",
            ),
            .wait_for_fences = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkWaitForFences,
                "vkWaitForFences",
            ),
            .create_command_pool = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateCommandPool,
                "vkCreateCommandPool",
            ),
            .destroy_command_pool = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyCommandPool,
                "vkDestroyCommandPool",
            ),
            .allocate_command_buffers = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkAllocateCommandBuffers,
                "vkAllocateCommandBuffers",
            ),
            .begin_command_buffer = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkBeginCommandBuffer,
                "vkBeginCommandBuffer",
            ),
            .end_command_buffer = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkEndCommandBuffer,
                "vkEndCommandBuffer",
            ),
            .reset_command_buffer = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkResetCommandBuffer,
                "vkResetCommandBuffer",
            ),
            .cmd_pipeline_barrier = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdPipelineBarrier,
                "vkCmdPipelineBarrier",
            ),
            .cmd_clear_color_image = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdClearColorImage,
                "vkCmdClearColorImage",
            ),
            .create_swapchain_khr = loadDevice(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateSwapchainKHR,
                "vkCreateSwapchainKHR",
            ),
            .destroy_swapchain_khr = loadDevice(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroySwapchainKHR,
                "vkDestroySwapchainKHR",
            ),
            .get_swapchain_images_khr = loadDevice(
                get_device_proc_addr,
                handle,
                raw.PFN_vkGetSwapchainImagesKHR,
                "vkGetSwapchainImagesKHR",
            ),
            .acquire_next_image_khr = loadDevice(
                get_device_proc_addr,
                handle,
                raw.PFN_vkAcquireNextImageKHR,
                "vkAcquireNextImageKHR",
            ),
            .queue_present_khr = loadDevice(
                get_device_proc_addr,
                handle,
                raw.PFN_vkQueuePresentKHR,
                "vkQueuePresentKHR",
            ),
            .set_debug_utils_object_name_ext = loadDevice(
                get_device_proc_addr,
                handle,
                raw.PFN_vkSetDebugUtilsObjectNameEXT,
                "vkSetDebugUtilsObjectNameEXT",
            ),
            .queue_begin_debug_utils_label_ext = loadDevice(
                get_device_proc_addr,
                handle,
                raw.PFN_vkQueueBeginDebugUtilsLabelEXT,
                "vkQueueBeginDebugUtilsLabelEXT",
            ),
            .queue_end_debug_utils_label_ext = loadDevice(
                get_device_proc_addr,
                handle,
                raw.PFN_vkQueueEndDebugUtilsLabelEXT,
                "vkQueueEndDebugUtilsLabelEXT",
            ),
            .queue_insert_debug_utils_label_ext = loadDevice(
                get_device_proc_addr,
                handle,
                raw.PFN_vkQueueInsertDebugUtilsLabelEXT,
                "vkQueueInsertDebugUtilsLabelEXT",
            ),
            .cmd_begin_debug_utils_label_ext = loadDevice(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdBeginDebugUtilsLabelEXT,
                "vkCmdBeginDebugUtilsLabelEXT",
            ),
            .cmd_end_debug_utils_label_ext = loadDevice(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdEndDebugUtilsLabelEXT,
                "vkCmdEndDebugUtilsLabelEXT",
            ),
            .cmd_insert_debug_utils_label_ext = loadDevice(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdInsertDebugUtilsLabelEXT,
                "vkCmdInsertDebugUtilsLabelEXT",
            ),
        };
    }
};

fn DescriptorFunction(comptime descriptor: anytype, comptime expected_scope: command.Scope) type {
    const Descriptor = @TypeOf(descriptor);
    if (!@hasDecl(Descriptor, "Pfn") or
        !@hasDecl(Descriptor, "Function") or
        !@hasDecl(Descriptor, "name") or
        !@hasDecl(Descriptor, "scope"))
    {
        @compileError("expected a generated Vulkan command descriptor");
    }
    if (Descriptor.scope != expected_scope) {
        @compileError("Vulkan command descriptor has the wrong dispatch scope");
    }
    return Descriptor.Function;
}

fn loadInstance(
    get_instance_proc_addr: CommandFunction(raw.PFN_vkGetInstanceProcAddr),
    instance: raw.VkInstance,
    comptime OptionalFunction: type,
    name: [:0]const u8,
) ?CommandFunction(OptionalFunction) {
    const procedure = get_instance_proc_addr(instance, name.ptr) orelse return null;
    return @ptrCast(procedure);
}

fn loadInstanceRequired(
    get_instance_proc_addr: CommandFunction(raw.PFN_vkGetInstanceProcAddr),
    instance: raw.VkInstance,
    comptime OptionalFunction: type,
    name: [:0]const u8,
) Error!CommandFunction(OptionalFunction) {
    return loadInstance(
        get_instance_proc_addr,
        instance,
        OptionalFunction,
        name,
    ) orelse error.MissingCommand;
}

fn loadDevice(
    get_device_proc_addr: CommandFunction(raw.PFN_vkGetDeviceProcAddr),
    device: raw.VkDevice,
    comptime OptionalFunction: type,
    name: [:0]const u8,
) ?CommandFunction(OptionalFunction) {
    const procedure = get_device_proc_addr(device, name.ptr) orelse return null;
    return @ptrCast(procedure);
}

fn loadDeviceRequired(
    get_device_proc_addr: CommandFunction(raw.PFN_vkGetDeviceProcAddr),
    device: raw.VkDevice,
    comptime OptionalFunction: type,
    name: [:0]const u8,
) Error!CommandFunction(OptionalFunction) {
    return loadDevice(
        get_device_proc_addr,
        device,
        OptionalFunction,
        name,
    ) orelse error.MissingCommand;
}

fn enumerateDeviceExtensions(
    gpa: std.mem.Allocator,
    enumerate: CommandFunction(raw.PFN_vkEnumerateDeviceExtensionProperties),
    physical_device: raw.VkPhysicalDevice,
    layer_name: ?[:0]const u8,
) (Error || std.mem.Allocator.Error)![]raw.VkExtensionProperties {
    var count: u32 = 0;
    try checkSuccess(enumerate(
        physical_device,
        optionalStringPointer(layer_name),
        &count,
        null,
    ));
    try validateEnumerationCount(count);
    if (count == 0) return gpa.alloc(raw.VkExtensionProperties, 0);

    var properties = try gpa.alloc(raw.VkExtensionProperties, count);
    errdefer gpa.free(properties);
    for (0..enumeration_attempt_count_max) |_| {
        var written: u32 = @intCast(properties.len);
        const result = enumerate(
            physical_device,
            optionalStringPointer(layer_name),
            &written,
            properties.ptr,
        );
        if (result == raw.VK_SUCCESS) return gpa.realloc(properties, written);
        if (result != raw.VK_INCOMPLETE) try checkSuccess(result);

        count = 0;
        try checkSuccess(enumerate(
            physical_device,
            optionalStringPointer(layer_name),
            &count,
            null,
        ));
        count = try nextEnumerationCapacity(count, properties.len);
        properties = try gpa.realloc(properties, count);
    }
    return error.EnumerationUnstable;
}

fn enumerateSurfaceFormats(
    gpa: std.mem.Allocator,
    enumerate: CommandFunction(raw.PFN_vkGetPhysicalDeviceSurfaceFormatsKHR),
    physical_device: raw.VkPhysicalDevice,
    surface: raw.VkSurfaceKHR,
) (Error || std.mem.Allocator.Error)![]SurfaceFormat {
    var count = try surfaceFormatCountRaw(enumerate, physical_device, surface);
    if (count == 0) return gpa.alloc(SurfaceFormat, 0);

    var formats = try gpa.alloc(SurfaceFormat, count);
    errdefer gpa.free(formats);
    for (0..enumeration_attempt_count_max) |_| {
        const written = enumerateSurfaceFormatsInto(
            enumerate,
            physical_device,
            surface,
            formats,
        ) catch |enumeration_error| switch (enumeration_error) {
            error.BufferTooSmall => null,
            else => return enumeration_error,
        };
        if (written) |items| return gpa.realloc(formats, items.len);

        count = try surfaceFormatCountRaw(enumerate, physical_device, surface);
        count = try nextEnumerationCapacity(count, formats.len);
        formats = try gpa.realloc(formats, count);
    }
    return error.EnumerationUnstable;
}

fn surfaceFormatCountRaw(
    enumerate: CommandFunction(raw.PFN_vkGetPhysicalDeviceSurfaceFormatsKHR),
    physical_device: raw.VkPhysicalDevice,
    surface: raw.VkSurfaceKHR,
) Error!u32 {
    var count: u32 = 0;
    try checkSuccess(enumerate(physical_device, surface, &count, null));
    try validateEnumerationCount(count);
    return count;
}

fn enumerateSurfaceFormatsInto(
    enumerate: CommandFunction(raw.PFN_vkGetPhysicalDeviceSurfaceFormatsKHR),
    physical_device: raw.VkPhysicalDevice,
    surface: raw.VkSurfaceKHR,
    storage: []SurfaceFormat,
) Error![]SurfaceFormat {
    if (storage.len > std.math.maxInt(u32)) return error.CountOverflow;
    var written: u32 = @intCast(storage.len);
    const output: [*c]raw.VkSurfaceFormatKHR = if (storage.len == 0)
        null
    else
        @ptrCast(storage.ptr);
    const result = enumerate(physical_device, surface, &written, output);
    if (result == raw.VK_INCOMPLETE) return error.BufferTooSmall;
    try checkSuccess(result);
    if (written > storage.len) return error.CountOverflow;
    return storage[0..written];
}

fn enumeratePresentModes(
    gpa: std.mem.Allocator,
    enumerate: CommandFunction(raw.PFN_vkGetPhysicalDeviceSurfacePresentModesKHR),
    physical_device: raw.VkPhysicalDevice,
    surface: raw.VkSurfaceKHR,
) (Error || std.mem.Allocator.Error)![]PresentMode {
    var count = try presentModeCountRaw(enumerate, physical_device, surface);
    if (count == 0) return gpa.alloc(PresentMode, 0);

    var modes = try gpa.alloc(PresentMode, count);
    errdefer gpa.free(modes);
    for (0..enumeration_attempt_count_max) |_| {
        const written = enumeratePresentModesInto(
            enumerate,
            physical_device,
            surface,
            modes,
        ) catch |enumeration_error| switch (enumeration_error) {
            error.BufferTooSmall => null,
            else => return enumeration_error,
        };
        if (written) |items| return gpa.realloc(modes, items.len);

        count = try presentModeCountRaw(enumerate, physical_device, surface);
        count = try nextEnumerationCapacity(count, modes.len);
        modes = try gpa.realloc(modes, count);
    }
    return error.EnumerationUnstable;
}

fn presentModeCountRaw(
    enumerate: CommandFunction(raw.PFN_vkGetPhysicalDeviceSurfacePresentModesKHR),
    physical_device: raw.VkPhysicalDevice,
    surface: raw.VkSurfaceKHR,
) Error!u32 {
    var count: u32 = 0;
    try checkSuccess(enumerate(physical_device, surface, &count, null));
    try validateEnumerationCount(count);
    return count;
}

fn enumeratePresentModesInto(
    enumerate: CommandFunction(raw.PFN_vkGetPhysicalDeviceSurfacePresentModesKHR),
    physical_device: raw.VkPhysicalDevice,
    surface: raw.VkSurfaceKHR,
    storage: []PresentMode,
) Error![]PresentMode {
    if (storage.len > std.math.maxInt(u32)) return error.CountOverflow;
    var written: u32 = @intCast(storage.len);
    const output: [*c]raw.VkPresentModeKHR = if (storage.len == 0)
        null
    else
        @ptrCast(storage.ptr);
    const result = enumerate(physical_device, surface, &written, output);
    if (result == raw.VK_INCOMPLETE) return error.BufferTooSmall;
    try checkSuccess(result);
    if (written > storage.len) return error.CountOverflow;
    return storage[0..written];
}

/// Maps errors for commands whose only successful result is `VK_SUCCESS`.
/// Do not use this for enumerate, wait, acquire, or present commands that allow status results.
pub fn checkSuccess(result: raw.VkResult) Error!void {
    if (result == raw.VK_SUCCESS) return;
    if (result == raw.VK_ERROR_OUT_OF_HOST_MEMORY) return error.OutOfHostMemory;
    if (result == raw.VK_ERROR_OUT_OF_DEVICE_MEMORY) return error.OutOfDeviceMemory;
    if (result == raw.VK_ERROR_INITIALIZATION_FAILED) return error.InitializationFailed;
    if (result == raw.VK_ERROR_DEVICE_LOST) return error.DeviceLost;
    if (result == raw.VK_ERROR_MEMORY_MAP_FAILED) return error.MemoryMapFailed;
    if (result == raw.VK_ERROR_LAYER_NOT_PRESENT) return error.LayerNotPresent;
    if (result == raw.VK_ERROR_EXTENSION_NOT_PRESENT) return error.ExtensionNotPresent;
    if (result == raw.VK_ERROR_FEATURE_NOT_PRESENT) return error.FeatureNotPresent;
    if (result == raw.VK_ERROR_INCOMPATIBLE_DRIVER) return error.IncompatibleDriver;
    if (result == raw.VK_ERROR_TOO_MANY_OBJECTS) return error.TooManyObjects;
    if (result == raw.VK_ERROR_FORMAT_NOT_SUPPORTED) return error.FormatNotSupported;
    if (result == raw.VK_ERROR_FRAGMENTED_POOL) return error.FragmentedPool;
    if (result == raw.VK_ERROR_UNKNOWN) return error.UnknownVulkanError;
    if (result == raw.VK_ERROR_SURFACE_LOST_KHR) return error.SurfaceLost;
    if (result == raw.VK_ERROR_NATIVE_WINDOW_IN_USE_KHR) return error.NativeWindowInUse;
    if (result == raw.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT) {
        return error.FullScreenExclusiveLost;
    }
    return error.UnexpectedVulkanResult;
}

fn count32(count: usize) Error!u32 {
    return std.math.cast(u32, count) orelse error.CountOverflow;
}

fn validateEnumerationCount(count: u32) Error!void {
    if (count <= enumeration_item_count_max) return;
    return error.TooManyObjects;
}

fn nextEnumerationCapacity(required: u32, current: usize) Error!u32 {
    try validateEnumerationCount(required);
    if (required > current) return required;

    const doubled = @min(current * 2, enumeration_item_count_max);
    if (doubled <= current) return error.EnumerationUnstable;
    return @intCast(doubled);
}

fn optionalStringPointer(value: ?[:0]const u8) [*c]const u8 {
    return if (value) |string| string.ptr else null;
}

fn fillNamePointers(
    names: []const [:0]const u8,
    output: [][*c]const u8,
) Error!usize {
    if (names.len > output.len) return error.CountOverflow;
    for (names, output[0..names.len]) |name, *pointer| pointer.* = name.ptr;
    return names.len;
}

fn pointerArray(names: []const [*c]const u8) [*c]const [*c]const u8 {
    return if (names.len == 0) null else names.ptr;
}

fn containsName(names: []const [:0]const u8, expected: []const u8) bool {
    for (names) |name| {
        if (std.mem.eql(u8, name, expected)) return true;
    }
    return false;
}

fn optionalCString(pointer: [*c]const u8) ?[]const u8 {
    if (pointer == null) return null;
    const sentinel: [*:0]const u8 = @ptrCast(pointer);
    return std.mem.span(sentinel);
}

fn handleValue(handle: anytype) Error!u64 {
    const Handle = @TypeOf(handle);
    return switch (@typeInfo(Handle)) {
        .optional => if (handle) |live_handle| handleValue(live_handle) else error.InvalidHandle,
        .pointer => @intCast(@intFromPtr(handle)),
        .int => if (handle == 0) error.InvalidHandle else @intCast(handle),
        else => @compileError("expected a Vulkan pointer or integer handle"),
    };
}

fn NonNullHandle(comptime OptionalHandle: type) type {
    return switch (@typeInfo(OptionalHandle)) {
        .optional => |optional| optional.child,
        else => @compileError("expected an optional Vulkan handle type"),
    };
}

const NativeLibrary = if (builtin.os.tag == .windows) WindowsLibrary else PosixLibrary;

const PosixLibrary = struct {
    inner: std.DynLib,

    fn open() LoaderError!PosixLibrary {
        for (loader_names) |name| {
            const inner = std.DynLib.open(name) catch continue;
            return .{ .inner = inner };
        }
        return error.VulkanLoaderNotFound;
    }

    fn openPath(path: []const u8) LoaderError!PosixLibrary {
        const inner = std.DynLib.open(path) catch return error.VulkanLoaderNotFound;
        return .{ .inner = inner };
    }

    fn close(library: *PosixLibrary) void {
        library.inner.close();
    }

    fn lookup(
        library: *PosixLibrary,
        comptime FunctionType: type,
        name: [:0]const u8,
    ) ?FunctionType {
        return library.inner.lookup(FunctionType, name);
    }
};

const WindowsLibrary = struct {
    handle: std.os.windows.HMODULE,

    fn open() LoaderError!WindowsLibrary {
        return openPath("vulkan-1.dll");
    }

    fn openPath(path: [:0]const u8) LoaderError!WindowsLibrary {
        const handle = LoadLibraryA(path.ptr) orelse {
            return error.VulkanLoaderNotFound;
        };
        return .{ .handle = handle };
    }

    fn close(library: *WindowsLibrary) void {
        std.debug.assert(FreeLibrary(library.handle) != 0);
    }

    fn lookup(
        library: *WindowsLibrary,
        comptime FunctionType: type,
        name: [:0]const u8,
    ) ?FunctionType {
        const address = GetProcAddress(library.handle, name.ptr) orelse return null;
        return @ptrCast(address);
    }

    extern "kernel32" fn LoadLibraryA(
        name: [*:0]const u8,
    ) callconv(.winapi) ?std.os.windows.HMODULE;
    extern "kernel32" fn FreeLibrary(module: std.os.windows.HMODULE) callconv(.winapi) i32;
    extern "kernel32" fn GetProcAddress(
        module: std.os.windows.HMODULE,
        name: [*:0]const u8,
    ) callconv(.winapi) ?*const anyopaque;
};

const loader_names = switch (builtin.os.tag) {
    .macos => [_][]const u8{
        "libvulkan.1.dylib",
        "libvulkan.dylib",
        "libMoltenVK.dylib",
        "/opt/homebrew/lib/libvulkan.1.dylib",
        "/opt/homebrew/lib/libvulkan.dylib",
        "/opt/homebrew/lib/libMoltenVK.dylib",
        "/usr/local/lib/libvulkan.1.dylib",
        "/usr/local/lib/libvulkan.dylib",
        "/usr/local/lib/libMoltenVK.dylib",
        "/opt/local/lib/libvulkan.1.dylib",
        "/opt/local/lib/libvulkan.dylib",
        "/opt/local/lib/libMoltenVK.dylib",
    },
    .linux, .freebsd, .netbsd, .openbsd, .dragonfly => [_][]const u8{
        "libvulkan.so.1",
        "libvulkan.so",
    },
    else => [_][]const u8{},
};

const TestCommand = enum {
    none,
    create_messenger,
    destroy_messenger,
    destroy_surface,
    surface_support,
    set_object_name,
};

var test_missing_command: TestCommand = .none;
var test_create_result: raw.VkResult = raw.VK_SUCCESS;
var test_create_null_handle = false;
var test_surface_result: raw.VkResult = raw.VK_SUCCESS;
var test_surface_supported: raw.VkBool32 = raw.VK_TRUE;
var test_name_result: raw.VkResult = raw.VK_SUCCESS;
var test_destroy_instance_count: usize = 0;
var test_destroy_device_count: usize = 0;
var test_destroy_messenger_count: usize = 0;
var test_destroy_surface_count: usize = 0;
var test_create_messenger_count: usize = 0;
var test_queue_submit_count: usize = 0;
var test_named_object_type: raw.VkObjectType = 0;
var test_named_object_handle: u64 = 0;
var test_resource_result: raw.VkResult = raw.VK_SUCCESS;
var test_resource_null_handle = false;
var test_wait_result: raw.VkResult = raw.VK_SUCCESS;
var test_destroy_image_view_count: usize = 0;
var test_destroy_semaphore_count: usize = 0;
var test_destroy_fence_count: usize = 0;
var test_destroy_command_pool_count: usize = 0;
var test_begin_command_buffer_count: usize = 0;
var test_end_command_buffer_count: usize = 0;
var test_reset_command_buffer_count: usize = 0;
var test_pipeline_barrier_count: usize = 0;
var test_clear_color_count: usize = 0;
var test_end_command_label_count: usize = 0;
var test_acquire_result: raw.VkResult = raw.VK_SUCCESS;
var test_acquire_image_index: u32 = 0;
var test_present_result: raw.VkResult = raw.VK_SUCCESS;
var test_memory_properties: raw.VkPhysicalDeviceMemoryProperties = .{};
var test_format_properties: raw.VkFormatProperties = .{};
var test_image_format_properties: raw.VkImageFormatProperties = .{};
var test_image_format_result: raw.VkResult = raw.VK_SUCCESS;

fn testHandle(comptime OptionalHandle: type, address: usize) NonNullHandle(OptionalHandle) {
    return @ptrFromInt(address);
}

fn testUnused() callconv(.c) void {}

fn testFunction(comptime Pfn: type) CommandFunction(Pfn) {
    return @ptrCast(&testUnused);
}

fn testNameEquals(name: [*c]const u8, expected: []const u8) bool {
    if (name == null) return false;
    const sentinel: [*:0]const u8 = @ptrCast(name);
    return std.mem.eql(u8, std.mem.span(sentinel), expected);
}

fn testGetInstanceProcAddr(
    _: raw.VkInstance,
    name: [*c]const u8,
) callconv(.c) raw.PFN_vkVoidFunction {
    if (testNameEquals(name, "vkCreateDebugUtilsMessengerEXT")) {
        if (test_missing_command == .create_messenger) return null;
        return @ptrCast(&testCreateMessenger);
    }
    if (testNameEquals(name, "vkDestroyDebugUtilsMessengerEXT")) {
        if (test_missing_command == .destroy_messenger) return null;
        return @ptrCast(&testDestroyMessenger);
    }
    if (testNameEquals(name, "vkDestroySurfaceKHR")) {
        if (test_missing_command == .destroy_surface) return null;
        return @ptrCast(&testDestroySurface);
    }
    if (testNameEquals(name, "vkGetPhysicalDeviceSurfaceSupportKHR")) {
        if (test_missing_command == .surface_support) return null;
        return @ptrCast(&testSurfaceSupport);
    }
    return null;
}

fn testGetDeviceProcAddr(
    _: raw.VkDevice,
    name: [*c]const u8,
) callconv(.c) raw.PFN_vkVoidFunction {
    if (!testNameEquals(name, "vkSetDebugUtilsObjectNameEXT")) return null;
    if (test_missing_command == .set_object_name) return null;
    return @ptrCast(&testSetObjectName);
}

fn testDestroyInstance(
    _: raw.VkInstance,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_instance_count += 1;
}

fn testDestroyDevice(
    _: raw.VkDevice,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_device_count += 1;
}

fn testGetPhysicalDeviceMemoryProperties(
    _: raw.VkPhysicalDevice,
    properties: [*c]raw.VkPhysicalDeviceMemoryProperties,
) callconv(.c) void {
    properties.* = test_memory_properties;
}

fn testGetPhysicalDeviceFormatProperties(
    _: raw.VkPhysicalDevice,
    _: raw.VkFormat,
    properties: [*c]raw.VkFormatProperties,
) callconv(.c) void {
    properties.* = test_format_properties;
}

fn testGetPhysicalDeviceImageFormatProperties(
    _: raw.VkPhysicalDevice,
    _: raw.VkFormat,
    _: raw.VkImageType,
    _: raw.VkImageTiling,
    _: raw.VkImageUsageFlags,
    _: raw.VkImageCreateFlags,
    properties: [*c]raw.VkImageFormatProperties,
) callconv(.c) raw.VkResult {
    properties.* = test_image_format_properties;
    return test_image_format_result;
}

fn testCreateImageView(
    _: raw.VkDevice,
    _: [*c]const raw.VkImageViewCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    handle: [*c]raw.VkImageView,
) callconv(.c) raw.VkResult {
    handle.* = if (test_resource_null_handle) null else testHandle(raw.VkImageView, 0x5100);
    return test_resource_result;
}

fn testDestroyImageView(
    _: raw.VkDevice,
    _: raw.VkImageView,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_image_view_count += 1;
}

fn testCreateSemaphore(
    _: raw.VkDevice,
    _: [*c]const raw.VkSemaphoreCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    handle: [*c]raw.VkSemaphore,
) callconv(.c) raw.VkResult {
    handle.* = if (test_resource_null_handle) null else testHandle(raw.VkSemaphore, 0x5200);
    return test_resource_result;
}

fn testDestroySemaphore(
    _: raw.VkDevice,
    _: raw.VkSemaphore,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_semaphore_count += 1;
}

fn testCreateFence(
    _: raw.VkDevice,
    _: [*c]const raw.VkFenceCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    handle: [*c]raw.VkFence,
) callconv(.c) raw.VkResult {
    handle.* = if (test_resource_null_handle) null else testHandle(raw.VkFence, 0x5300);
    return test_resource_result;
}

fn testDestroyFence(
    _: raw.VkDevice,
    _: raw.VkFence,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_fence_count += 1;
}

fn testResetFences(
    _: raw.VkDevice,
    _: u32,
    _: [*c]const raw.VkFence,
) callconv(.c) raw.VkResult {
    return test_resource_result;
}

fn testWaitForFences(
    _: raw.VkDevice,
    _: u32,
    _: [*c]const raw.VkFence,
    _: raw.VkBool32,
    _: u64,
) callconv(.c) raw.VkResult {
    return test_wait_result;
}

fn testCreateCommandPool(
    _: raw.VkDevice,
    _: [*c]const raw.VkCommandPoolCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    handle: [*c]raw.VkCommandPool,
) callconv(.c) raw.VkResult {
    handle.* = if (test_resource_null_handle) null else testHandle(raw.VkCommandPool, 0x5400);
    return test_resource_result;
}

fn testDestroyCommandPool(
    _: raw.VkDevice,
    _: raw.VkCommandPool,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_command_pool_count += 1;
}

fn testAllocateCommandBuffers(
    _: raw.VkDevice,
    _: [*c]const raw.VkCommandBufferAllocateInfo,
    handle: [*c]raw.VkCommandBuffer,
) callconv(.c) raw.VkResult {
    handle.* = if (test_resource_null_handle) null else testHandle(raw.VkCommandBuffer, 0x5500);
    return test_resource_result;
}

fn testBeginCommandBuffer(
    _: raw.VkCommandBuffer,
    _: [*c]const raw.VkCommandBufferBeginInfo,
) callconv(.c) raw.VkResult {
    test_begin_command_buffer_count += 1;
    return test_resource_result;
}

fn testEndCommandBuffer(_: raw.VkCommandBuffer) callconv(.c) raw.VkResult {
    test_end_command_buffer_count += 1;
    return test_resource_result;
}

fn testResetCommandBuffer(
    _: raw.VkCommandBuffer,
    _: raw.VkCommandBufferResetFlags,
) callconv(.c) raw.VkResult {
    test_reset_command_buffer_count += 1;
    return test_resource_result;
}

fn testCmdPipelineBarrier(
    _: raw.VkCommandBuffer,
    _: raw.VkPipelineStageFlags,
    _: raw.VkPipelineStageFlags,
    _: raw.VkDependencyFlags,
    _: u32,
    _: [*c]const raw.VkMemoryBarrier,
    _: u32,
    _: [*c]const raw.VkBufferMemoryBarrier,
    _: u32,
    _: [*c]const raw.VkImageMemoryBarrier,
) callconv(.c) void {
    test_pipeline_barrier_count += 1;
}

fn testCmdClearColorImage(
    _: raw.VkCommandBuffer,
    _: raw.VkImage,
    _: raw.VkImageLayout,
    _: [*c]const raw.VkClearColorValue,
    _: u32,
    _: [*c]const raw.VkImageSubresourceRange,
) callconv(.c) void {
    test_clear_color_count += 1;
}

fn testCmdEndLabel(_: raw.VkCommandBuffer) callconv(.c) void {
    test_end_command_label_count += 1;
}

fn testDestroySwapchain(
    _: raw.VkDevice,
    _: raw.VkSwapchainKHR,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {}

fn testGetSwapchainImages(
    _: raw.VkDevice,
    _: raw.VkSwapchainKHR,
    count: [*c]u32,
    images: [*c]raw.VkImage,
) callconv(.c) raw.VkResult {
    if (images == null) {
        count.* = 2;
        return raw.VK_SUCCESS;
    }
    if (count.* < 2) {
        count.* = 2;
        return raw.VK_INCOMPLETE;
    }
    images[0] = testHandle(raw.VkImage, 0x5000);
    images[1] = testHandle(raw.VkImage, 0x5001);
    count.* = 2;
    return raw.VK_SUCCESS;
}

fn testAcquireNextImage(
    _: raw.VkDevice,
    _: raw.VkSwapchainKHR,
    _: u64,
    _: raw.VkSemaphore,
    _: raw.VkFence,
    image_index: [*c]u32,
) callconv(.c) raw.VkResult {
    image_index.* = test_acquire_image_index;
    return test_acquire_result;
}

fn testQueuePresent(
    _: raw.VkQueue,
    _: [*c]const raw.VkPresentInfoKHR,
) callconv(.c) raw.VkResult {
    return test_present_result;
}

fn testGetNullQueue(
    _: raw.VkDevice,
    _: u32,
    _: u32,
    output: [*c]raw.VkQueue,
) callconv(.c) void {
    output[0] = null;
}

fn testQueueSubmit(
    _: raw.VkQueue,
    _: u32,
    _: [*c]const raw.VkSubmitInfo,
    _: raw.VkFence,
) callconv(.c) raw.VkResult {
    test_queue_submit_count += 1;
    return raw.VK_SUCCESS;
}

fn testCreateMessenger(
    _: raw.VkInstance,
    _: [*c]const raw.VkDebugUtilsMessengerCreateInfoEXT,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkDebugUtilsMessengerEXT,
) callconv(.c) raw.VkResult {
    test_create_messenger_count += 1;
    output[0] = if (test_create_null_handle)
        null
    else
        testHandle(raw.VkDebugUtilsMessengerEXT, 0x4000);
    return test_create_result;
}

fn testDestroyMessenger(
    _: raw.VkInstance,
    _: raw.VkDebugUtilsMessengerEXT,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_messenger_count += 1;
}

fn testDestroySurface(
    _: raw.VkInstance,
    _: raw.VkSurfaceKHR,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_surface_count += 1;
}

fn testSurfaceSupport(
    _: raw.VkPhysicalDevice,
    _: u32,
    _: raw.VkSurfaceKHR,
    supported: [*c]raw.VkBool32,
) callconv(.c) raw.VkResult {
    supported[0] = test_surface_supported;
    return test_surface_result;
}

fn testSurfaceFormats(
    _: raw.VkPhysicalDevice,
    _: raw.VkSurfaceKHR,
    count: [*c]u32,
    formats: [*c]raw.VkSurfaceFormatKHR,
) callconv(.c) raw.VkResult {
    if (formats == null) {
        count[0] = 2;
        return raw.VK_SUCCESS;
    }
    if (count[0] < 2) {
        count[0] = 2;
        return raw.VK_INCOMPLETE;
    }
    formats[0] = .{
        .format = raw.VK_FORMAT_B8G8R8A8_SRGB,
        .colorSpace = raw.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
    };
    formats[1] = .{
        .format = raw.VK_FORMAT_R8G8B8A8_SRGB,
        .colorSpace = raw.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
    };
    count[0] = 2;
    return raw.VK_SUCCESS;
}

fn testPresentModes(
    _: raw.VkPhysicalDevice,
    _: raw.VkSurfaceKHR,
    count: [*c]u32,
    modes: [*c]raw.VkPresentModeKHR,
) callconv(.c) raw.VkResult {
    if (modes == null) {
        count[0] = 2;
        return raw.VK_SUCCESS;
    }
    if (count[0] < 2) {
        count[0] = 2;
        return raw.VK_INCOMPLETE;
    }
    modes[0] = raw.VK_PRESENT_MODE_FIFO_KHR;
    modes[1] = raw.VK_PRESENT_MODE_MAILBOX_KHR;
    count[0] = 2;
    return raw.VK_SUCCESS;
}

fn testSetObjectName(
    _: raw.VkDevice,
    name_info: [*c]const raw.VkDebugUtilsObjectNameInfoEXT,
) callconv(.c) raw.VkResult {
    test_named_object_type = name_info[0].objectType;
    test_named_object_handle = name_info[0].objectHandle;
    return test_name_result;
}

fn testDebugCallback(
    _: raw.VkDebugUtilsMessageSeverityFlagBitsEXT,
    _: raw.VkDebugUtilsMessageTypeFlagsEXT,
    _: [*c]const raw.VkDebugUtilsMessengerCallbackDataEXT,
    _: ?*anyopaque,
) callconv(.c) raw.VkBool32 {
    return raw.VK_FALSE;
}

fn testInstance() Instance {
    return .{
        ._handle = testHandle(raw.VkInstance, 0x1000),
        ._debug_messenger = null,
        .allocation_callbacks = null,
        .dispatch = .{
            .get_instance_proc_addr = testGetInstanceProcAddr,
            .get_device_proc_addr = testFunction(raw.PFN_vkGetDeviceProcAddr),
            .destroy_instance = testDestroyInstance,
            .enumerate_physical_devices = testFunction(raw.PFN_vkEnumeratePhysicalDevices),
            .get_physical_device_properties = testFunction(raw.PFN_vkGetPhysicalDeviceProperties),
            .get_physical_device_format_properties = testGetPhysicalDeviceFormatProperties,
            .get_physical_device_image_format_properties = testGetPhysicalDeviceImageFormatProperties,
            .get_physical_device_features = testFunction(raw.PFN_vkGetPhysicalDeviceFeatures),
            .get_physical_device_features2 = testFunction(raw.PFN_vkGetPhysicalDeviceFeatures2),
            .get_physical_device_memory_properties = testGetPhysicalDeviceMemoryProperties,
            .get_physical_device_queue_family_properties = testFunction(
                raw.PFN_vkGetPhysicalDeviceQueueFamilyProperties,
            ),
            .enumerate_device_extension_properties = testFunction(
                raw.PFN_vkEnumerateDeviceExtensionProperties,
            ),
            .get_physical_device_surface_support_khr = testSurfaceSupport,
            .get_physical_device_surface_capabilities_khr = testFunction(
                raw.PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR,
            ),
            .get_physical_device_surface_formats_khr = testFunction(
                raw.PFN_vkGetPhysicalDeviceSurfaceFormatsKHR,
            ),
            .get_physical_device_surface_present_modes_khr = testFunction(
                raw.PFN_vkGetPhysicalDeviceSurfacePresentModesKHR,
            ),
            .create_device = testFunction(raw.PFN_vkCreateDevice),
        },
    };
}

fn testDevice() Device {
    return .{
        ._handle = testHandle(raw.VkDevice, 0x2000),
        ._instance_handle = testHandle(raw.VkInstance, 0x1000),
        .allocation_callbacks = null,
        .dispatch = .{
            .get_device_proc_addr = testGetDeviceProcAddr,
            .destroy_device = testDestroyDevice,
            .get_device_queue = testGetNullQueue,
            .queue_submit = testFunction(raw.PFN_vkQueueSubmit),
            .queue_wait_idle = testFunction(raw.PFN_vkQueueWaitIdle),
            .device_wait_idle = testFunction(raw.PFN_vkDeviceWaitIdle),
            .create_image_view = testCreateImageView,
            .destroy_image_view = testDestroyImageView,
            .create_semaphore = testCreateSemaphore,
            .destroy_semaphore = testDestroySemaphore,
            .create_fence = testCreateFence,
            .destroy_fence = testDestroyFence,
            .reset_fences = testResetFences,
            .wait_for_fences = testWaitForFences,
            .create_command_pool = testCreateCommandPool,
            .destroy_command_pool = testDestroyCommandPool,
            .allocate_command_buffers = testAllocateCommandBuffers,
            .begin_command_buffer = testBeginCommandBuffer,
            .end_command_buffer = testEndCommandBuffer,
            .reset_command_buffer = testResetCommandBuffer,
            .cmd_pipeline_barrier = testCmdPipelineBarrier,
            .cmd_clear_color_image = testCmdClearColorImage,
            .create_swapchain_khr = null,
            .destroy_swapchain_khr = null,
            .get_swapchain_images_khr = null,
            .acquire_next_image_khr = null,
            .queue_present_khr = null,
            .set_debug_utils_object_name_ext = testSetObjectName,
            .queue_begin_debug_utils_label_ext = null,
            .queue_end_debug_utils_label_ext = null,
            .queue_insert_debug_utils_label_ext = null,
            .cmd_begin_debug_utils_label_ext = null,
            .cmd_end_debug_utils_label_ext = null,
            .cmd_insert_debug_utils_label_ext = null,
        },
    };
}

test "owned handles reject inactive use and deinit is idempotent" {
    test_destroy_instance_count = 0;
    var instance = testInstance();
    instance.deinit();
    instance.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_instance_count);
    try std.testing.expectError(error.InactiveObject, instance.rawHandle());
    try std.testing.expectError(
        error.InactiveObject,
        instance.load(command.destroy_surface_khr),
    );
    try std.testing.expectError(
        error.InactiveObject,
        instance.physicalDevices(std.testing.allocator),
    );

    test_destroy_device_count = 0;
    var device = testDevice();
    try std.testing.expectError(
        error.InvalidHandle,
        device.queue(.fromRaw(0), .fromRaw(0)),
    );
    device.deinit();
    device.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_device_count);
    try std.testing.expectError(error.InactiveObject, device.rawHandle());
    try std.testing.expectError(
        error.InactiveObject,
        device.queue(.fromRaw(0), .fromRaw(0)),
    );
    try std.testing.expectError(error.InactiveObject, device.waitIdle());
    try std.testing.expectError(
        error.InactiveObject,
        device.load(command.set_debug_utils_object_name_ext),
    );
}

test "Vulkan u32 counts reject narrowing overflow" {
    try std.testing.expectEqual(
        std.math.maxInt(u32),
        try count32(std.math.maxInt(u32)),
    );
    if (@bitSizeOf(usize) > @bitSizeOf(u32)) {
        const too_large = @as(usize, std.math.maxInt(u32)) + 1;
        try std.testing.expectError(error.CountOverflow, count32(too_large));
    }
}

test "surface capability sentinels become optionals" {
    var raw_capabilities: raw.VkSurfaceCapabilitiesKHR = .{};
    raw_capabilities.maxImageCount = 0;
    raw_capabilities.currentExtent = .{
        .width = std.math.maxInt(u32),
        .height = std.math.maxInt(u32),
    };
    const variable = SurfaceCapabilities.fromRaw(raw_capabilities);
    try std.testing.expectEqual(@as(?u32, null), variable.image_count_max);
    try std.testing.expectEqual(@as(?Extent2D, null), variable.extent_current);

    raw_capabilities.maxImageCount = 3;
    raw_capabilities.currentExtent = .{ .width = 1280, .height = 720 };
    const fixed = SurfaceCapabilities.fromRaw(raw_capabilities);
    try std.testing.expectEqual(@as(?u32, 3), fixed.image_count_max);
    try std.testing.expectEqual(
        @as(?Extent2D, .{ .width = 1280, .height = 720 }),
        fixed.extent_current,
    );
}

test "surface enumeration supports typed caller storage" {
    const physical_device = testHandle(raw.VkPhysicalDevice, 0x1100);
    const surface = testHandle(raw.VkSurfaceKHR, 0x3000);

    try std.testing.expectEqual(
        @as(u32, 2),
        try surfaceFormatCountRaw(testSurfaceFormats, physical_device, surface),
    );
    var format_storage: [2]SurfaceFormat = undefined;
    const formats = try enumerateSurfaceFormatsInto(
        testSurfaceFormats,
        physical_device,
        surface,
        &format_storage,
    );
    try std.testing.expectEqual(@as(usize, 2), formats.len);
    try std.testing.expectEqual(Format.b8g8r8a8_srgb, formats[0].format);
    try std.testing.expectEqual(ColorSpace.srgb_nonlinear, formats[0].color_space);
    var format_storage_small: [1]SurfaceFormat = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        enumerateSurfaceFormatsInto(
            testSurfaceFormats,
            physical_device,
            surface,
            &format_storage_small,
        ),
    );

    try std.testing.expectEqual(
        @as(u32, 2),
        try presentModeCountRaw(testPresentModes, physical_device, surface),
    );
    var mode_storage: [2]PresentMode = undefined;
    const modes = try enumeratePresentModesInto(
        testPresentModes,
        physical_device,
        surface,
        &mode_storage,
    );
    try std.testing.expectEqualSlices(
        PresentMode,
        &.{ .fifo, .mailbox },
        modes,
    );
    var mode_storage_small: [1]PresentMode = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        enumeratePresentModesInto(
            testPresentModes,
            physical_device,
            surface,
            &mode_storage_small,
        ),
    );
}

test "queue submit rejects oversized slices before dispatch" {
    const queue: Queue = .{
        ._handle = testHandle(raw.VkQueue, 0x2100),
        ._device_handle = testHandle(raw.VkDevice, 0x2000),
        .queue_submit = testQueueSubmit,
        .queue_wait_idle = testFunction(raw.PFN_vkQueueWaitIdle),
        .queue_present_khr = null,
        .queue_begin_debug_utils_label_ext = null,
        .queue_end_debug_utils_label_ext = null,
        .queue_insert_debug_utils_label_ext = null,
    };
    test_queue_submit_count = 0;

    const wait_pointer: [*]const SemaphoreWait = @ptrFromInt(0x1000);
    try std.testing.expectError(
        error.CountOverflow,
        queue.submit(.{ .waits = wait_pointer[0 .. submission_item_count_max + 1] }),
    );
    try std.testing.expectEqual(@as(usize, 0), test_queue_submit_count);

    try queue.submit(.{});
    try std.testing.expectEqual(@as(usize, 1), test_queue_submit_count);
}

test "owned frame resources clean up success and provisional failure exactly once" {
    test_resource_result = raw.VK_SUCCESS;
    test_resource_null_handle = false;
    test_destroy_image_view_count = 0;
    test_destroy_semaphore_count = 0;
    test_destroy_fence_count = 0;
    test_destroy_command_pool_count = 0;

    var device = testDevice();
    defer device.deinit();
    const image: SwapchainImage = .{
        ._handle = testHandle(raw.VkImage, 0x5000),
        ._device_handle = device._handle.?,
        ._swapchain_handle = testHandle(raw.VkSwapchainKHR, 0x4000),
        .index = .fromRaw(0),
    };
    var image_view = try device.createImageView(.{
        .image = &image,
        .view_type = ._2d,
        .format = .b8g8r8a8_srgb,
        .subresource_range = .{ .aspect_mask = .init(&.{.color}) },
    });
    var semaphore = try device.createSemaphore(.{});
    var fence = try device.createFence(.{ .signaled = true });
    var command_pool = try device.createCommandPool(.{ .family_index = .fromRaw(0) });

    image_view.deinit();
    image_view.deinit();
    semaphore.deinit();
    semaphore.deinit();
    fence.deinit();
    fence.deinit();
    command_pool.deinit();
    command_pool.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_image_view_count);
    try std.testing.expectEqual(@as(usize, 1), test_destroy_semaphore_count);
    try std.testing.expectEqual(@as(usize, 1), test_destroy_fence_count);
    try std.testing.expectEqual(@as(usize, 1), test_destroy_command_pool_count);

    test_resource_result = raw.VK_ERROR_OUT_OF_HOST_MEMORY;
    try std.testing.expectError(error.OutOfHostMemory, device.createImageView(.{
        .image = &image,
        .view_type = ._2d,
        .format = .b8g8r8a8_srgb,
        .subresource_range = .{ .aspect_mask = .init(&.{.color}) },
    }));
    try std.testing.expectError(error.OutOfHostMemory, device.createSemaphore(.{}));
    try std.testing.expectError(error.OutOfHostMemory, device.createFence(.{}));
    try std.testing.expectError(
        error.OutOfHostMemory,
        device.createCommandPool(.{ .family_index = .fromRaw(0) }),
    );
    try std.testing.expectEqual(@as(usize, 2), test_destroy_image_view_count);
    try std.testing.expectEqual(@as(usize, 2), test_destroy_semaphore_count);
    try std.testing.expectEqual(@as(usize, 2), test_destroy_fence_count);
    try std.testing.expectEqual(@as(usize, 2), test_destroy_command_pool_count);
    test_resource_result = raw.VK_SUCCESS;
}

test "typed command recording and fence results avoid raw Vulkan at call sites" {
    test_resource_result = raw.VK_SUCCESS;
    test_resource_null_handle = false;
    test_begin_command_buffer_count = 0;
    test_end_command_buffer_count = 0;
    test_reset_command_buffer_count = 0;
    test_pipeline_barrier_count = 0;
    test_clear_color_count = 0;

    var device = testDevice();
    defer device.deinit();
    var pool = try device.createCommandPool(.{
        .family_index = .fromRaw(0),
        .flags = .init(&.{.reset_command_buffer}),
    });
    defer pool.deinit();
    var command_buffer = try pool.allocateCommandBuffer(.{});
    const image: SwapchainImage = .{
        ._handle = testHandle(raw.VkImage, 0x5000),
        ._device_handle = device._handle.?,
        ._swapchain_handle = testHandle(raw.VkSwapchainKHR, 0x4000),
        .index = .fromRaw(0),
    };
    const color_range: ImageSubresourceRange = .{ .aspect_mask = .init(&.{.color}) };

    try command_buffer.begin(.{ .flags = .init(&.{.one_time_submit}) });
    try command_buffer.imageBarrier(.{
        .source_stage = .init(&.{.top_of_pipe}),
        .destination_stage = .init(&.{.transfer}),
        .destination_access = .init(&.{.transfer_write}),
        .old_layout = .undefined_,
        .new_layout = .transfer_dst_optimal,
        .image = &image,
        .subresource_range = color_range,
    });
    try command_buffer.clearColorImage(.{
        .image = &image,
        .layout = .transfer_dst_optimal,
        .color = .{ .float = .{ 0.1, 0.2, 0.3, 1.0 } },
        .subresource_range = color_range,
    });
    try command_buffer.imageBarrier(.{
        .source_stage = .init(&.{.transfer}),
        .destination_stage = .init(&.{.bottom_of_pipe}),
        .source_access = .init(&.{.transfer_write}),
        .old_layout = .transfer_dst_optimal,
        .new_layout = .present_src_khr,
        .image = &image,
        .subresource_range = color_range,
    });
    try command_buffer.end();
    var acquire_semaphore = try device.createSemaphore(.{});
    defer acquire_semaphore.deinit();
    var render_semaphore = try device.createSemaphore(.{});
    defer render_semaphore.deinit();
    var fence = try device.createFence(.{ .signaled = true });
    defer fence.deinit();
    const queue: Queue = .{
        ._handle = testHandle(raw.VkQueue, 0x2100),
        ._device_handle = device._handle.?,
        .queue_submit = testQueueSubmit,
        .queue_wait_idle = testFunction(raw.PFN_vkQueueWaitIdle),
        .queue_present_khr = null,
        .queue_begin_debug_utils_label_ext = null,
        .queue_end_debug_utils_label_ext = null,
        .queue_insert_debug_utils_label_ext = null,
    };
    test_queue_submit_count = 0;
    try queue.submit(.{
        .waits = &.{.{
            .semaphore = &acquire_semaphore,
            .stage = .init(&.{.transfer}),
        }},
        .command_buffers = &.{&command_buffer},
        .signals = &.{&render_semaphore},
        .fence = &fence,
    });
    try command_buffer.reset(false);
    try std.testing.expectEqual(@as(usize, 1), test_begin_command_buffer_count);
    try std.testing.expectEqual(@as(usize, 1), test_end_command_buffer_count);
    try std.testing.expectEqual(@as(usize, 1), test_reset_command_buffer_count);
    try std.testing.expectEqual(@as(usize, 2), test_pipeline_barrier_count);
    try std.testing.expectEqual(@as(usize, 1), test_clear_color_count);
    try std.testing.expectEqual(@as(usize, 1), test_queue_submit_count);

    test_wait_result = raw.VK_SUCCESS;
    try std.testing.expectEqual(FenceWaitStatus.success, try fence.wait(.infinite));
    test_wait_result = raw.VK_TIMEOUT;
    try std.testing.expectEqual(
        FenceWaitStatus.timeout,
        try fence.wait(.{ .nanoseconds = 1_000_000 }),
    );
    test_wait_result = raw.VK_ERROR_DEVICE_LOST;
    try std.testing.expectError(error.DeviceLost, fence.wait(.infinite));
    test_wait_result = raw.VK_SUCCESS;
}

test "debug label scopes end once" {
    test_end_command_label_count = 0;
    var scope: CommandBufferLabelScope = .{
        .command_buffer = testHandle(raw.VkCommandBuffer, 0x5500),
        .end_label = testCmdEndLabel,
    };
    scope.end();
    scope.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_end_command_label_count);
}

test "swapchain acquisition and presentation preserve operation statuses" {
    test_resource_result = raw.VK_SUCCESS;
    test_resource_null_handle = false;
    var device = testDevice();
    defer device.deinit();
    var semaphore = try device.createSemaphore(.{});
    defer semaphore.deinit();
    var swapchain: Swapchain = .{
        ._handle = testHandle(raw.VkSwapchainKHR, 0x4000),
        ._device_handle = device._handle.?,
        .allocation_callbacks = null,
        .destroy_swapchain = testDestroySwapchain,
        .get_swapchain_images = testGetSwapchainImages,
        .acquire_next_image = testAcquireNextImage,
    };
    defer swapchain.deinit();

    var image_storage: [2]SwapchainImage = undefined;
    const images = try swapchain.imagesInto(&image_storage);
    try std.testing.expectEqual(@as(usize, 2), images.len);
    try std.testing.expectEqual(@as(u32, 1), images[1].index.toRaw());

    test_acquire_image_index = 1;
    test_acquire_result = raw.VK_SUCCESS;
    const success = try swapchain.acquireNextImage(.{ .semaphore = &semaphore });
    try std.testing.expectEqual(@as(u32, 1), success.success.toRaw());
    test_acquire_result = raw.VK_SUBOPTIMAL_KHR;
    const suboptimal = try swapchain.acquireNextImage(.{ .semaphore = &semaphore });
    try std.testing.expectEqual(@as(u32, 1), suboptimal.suboptimal.toRaw());
    test_acquire_result = raw.VK_TIMEOUT;
    try std.testing.expectEqual(
        AcquireResult.timeout,
        try swapchain.acquireNextImage(.{ .semaphore = &semaphore }),
    );
    test_acquire_result = raw.VK_ERROR_OUT_OF_DATE_KHR;
    try std.testing.expectEqual(
        AcquireResult.out_of_date,
        try swapchain.acquireNextImage(.{ .semaphore = &semaphore }),
    );
    test_acquire_result = raw.VK_ERROR_DEVICE_LOST;
    try std.testing.expectError(
        error.DeviceLost,
        swapchain.acquireNextImage(.{ .semaphore = &semaphore }),
    );

    const queue: Queue = .{
        ._handle = testHandle(raw.VkQueue, 0x2100),
        ._device_handle = device._handle.?,
        .queue_submit = testQueueSubmit,
        .queue_wait_idle = testFunction(raw.PFN_vkQueueWaitIdle),
        .queue_present_khr = testQueuePresent,
        .queue_begin_debug_utils_label_ext = null,
        .queue_end_debug_utils_label_ext = null,
        .queue_insert_debug_utils_label_ext = null,
    };
    const present_options: PresentOptions = .{
        .swapchain = &swapchain,
        .image_index = .fromRaw(1),
        .wait_semaphores = &.{&semaphore},
    };
    test_present_result = raw.VK_SUCCESS;
    try std.testing.expectEqual(PresentStatus.success, try queue.present(present_options));
    test_present_result = raw.VK_SUBOPTIMAL_KHR;
    try std.testing.expectEqual(PresentStatus.suboptimal, try queue.present(present_options));
    test_present_result = raw.VK_ERROR_OUT_OF_DATE_KHR;
    try std.testing.expectEqual(PresentStatus.out_of_date, try queue.present(present_options));
    test_present_result = raw.VK_ERROR_DEVICE_LOST;
    try std.testing.expectError(error.DeviceLost, queue.present(present_options));
    test_acquire_result = raw.VK_SUCCESS;
    test_present_result = raw.VK_SUCCESS;
}

test "debug messenger handles fake dispatch success and failures" {
    test_missing_command = .none;
    test_create_result = raw.VK_SUCCESS;
    test_create_null_handle = false;
    test_create_messenger_count = 0;
    test_destroy_messenger_count = 0;
    var instance = testInstance();
    defer instance.deinit();
    const options: ext.debug_utils.MessengerOptions = .{ .callback = testDebugCallback };

    var messenger = try ext.debug_utils.Messenger.init(&instance, options);
    messenger.deinit();
    messenger.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_messenger_count);
    try std.testing.expectError(error.InactiveObject, messenger.rawHandle());

    test_create_null_handle = true;
    try std.testing.expectError(
        error.InvalidHandle,
        ext.debug_utils.Messenger.init(&instance, options),
    );

    test_create_null_handle = false;
    test_create_result = raw.VK_ERROR_INITIALIZATION_FAILED;
    test_destroy_messenger_count = 0;
    try std.testing.expectError(
        error.InitializationFailed,
        ext.debug_utils.Messenger.init(&instance, options),
    );
    try std.testing.expectEqual(@as(usize, 1), test_destroy_messenger_count);

    test_create_result = raw.VK_SUCCESS;
    test_missing_command = .destroy_messenger;
    test_create_messenger_count = 0;
    try std.testing.expectError(
        error.MissingCommand,
        ext.debug_utils.Messenger.init(&instance, options),
    );
    try std.testing.expectEqual(@as(usize, 0), test_create_messenger_count);
}

test "surface and object-name wrappers normalize fake dispatch results" {
    test_missing_command = .none;
    test_destroy_surface_count = 0;
    var instance = testInstance();
    defer instance.deinit();
    try std.testing.expectError(error.InvalidHandle, instance.adoptSurface(null, null));
    test_missing_command = .destroy_surface;
    try std.testing.expectError(
        error.MissingCommand,
        instance.adoptSurface(testHandle(raw.VkSurfaceKHR, 0x3000), null),
    );
    test_missing_command = .none;

    var surface = try instance.adoptSurface(testHandle(raw.VkSurfaceKHR, 0x3000), null);
    const physical_device: PhysicalDevice = .{
        ._handle = testHandle(raw.VkPhysicalDevice, 0x1100),
        ._instance_handle = testHandle(raw.VkInstance, 0x1000),
        .dispatch = instance.dispatch,
    };
    test_surface_result = raw.VK_SUCCESS;
    test_surface_supported = raw.VK_TRUE;
    try std.testing.expect(try physical_device.surfaceSupport(&surface, .fromRaw(0)));
    var missing_surface_support = physical_device;
    missing_surface_support.dispatch.get_physical_device_surface_support_khr = null;
    try std.testing.expectError(
        error.MissingCommand,
        missing_surface_support.surfaceSupport(&surface, .fromRaw(0)),
    );
    test_surface_supported = raw.VK_FALSE;
    try std.testing.expect(!try physical_device.surfaceSupport(&surface, .fromRaw(0)));
    test_surface_result = raw.VK_ERROR_SURFACE_LOST_KHR;
    try std.testing.expectError(
        error.SurfaceLost,
        physical_device.surfaceSupport(&surface, .fromRaw(0)),
    );

    surface.deinit();
    surface.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_surface_count);
    try std.testing.expectError(error.InactiveObject, surface.rawHandle());

    var device = testDevice();
    defer device.deinit();
    test_name_result = raw.VK_SUCCESS;
    try device.setObjectName(.{ .device = &device }, "test-device");
    try std.testing.expectEqual(
        @as(raw.VkObjectType, @intCast(raw.VK_OBJECT_TYPE_DEVICE)),
        test_named_object_type,
    );
    try std.testing.expectEqual(@as(u64, 0x2000), test_named_object_handle);
    const queue: Queue = .{
        ._handle = testHandle(raw.VkQueue, 0x2100),
        ._device_handle = testHandle(raw.VkDevice, 0x2000),
        .queue_submit = testFunction(raw.PFN_vkQueueSubmit),
        .queue_wait_idle = testFunction(raw.PFN_vkQueueWaitIdle),
        .queue_present_khr = null,
        .queue_begin_debug_utils_label_ext = null,
        .queue_end_debug_utils_label_ext = null,
        .queue_insert_debug_utils_label_ext = null,
    };
    try device.setObjectName(.{ .queue = &queue }, "test-queue");
    try std.testing.expectEqual(
        @as(raw.VkObjectType, @intCast(raw.VK_OBJECT_TYPE_QUEUE)),
        test_named_object_type,
    );
    try std.testing.expectEqual(@as(u64, 0x2100), test_named_object_handle);
    test_name_result = raw.VK_ERROR_OUT_OF_HOST_MEMORY;
    try std.testing.expectError(
        error.OutOfHostMemory,
        device.setObjectName(.{ .device = &device }, "test-device"),
    );
    device.dispatch.set_debug_utils_object_name_ext = null;
    try std.testing.expectError(
        error.MissingCommand,
        device.setObjectName(.{ .device = &device }, "test-device"),
    );
}

test "physical device memory queries produce validated owned snapshots" {
    test_memory_properties = .{};
    test_memory_properties.memoryHeapCount = 2;
    test_memory_properties.memoryHeaps[0] = .{
        .size = 512,
        .flags = @intCast(raw.VK_MEMORY_HEAP_DEVICE_LOCAL_BIT),
    };
    test_memory_properties.memoryHeaps[1] = .{
        .size = 256,
        .flags = 0,
    };
    test_memory_properties.memoryTypeCount = 1;
    test_memory_properties.memoryTypes[0] = .{
        .propertyFlags = @intCast(
            raw.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT |
                raw.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
        ),
        .heapIndex = 0,
    };

    var instance = testInstance();
    defer instance.deinit();
    const physical_device: PhysicalDevice = .{
        ._handle = testHandle(raw.VkPhysicalDevice, 0x1100),
        ._instance_handle = testHandle(raw.VkInstance, 0x1000),
        .dispatch = instance.dispatch,
    };

    const raw_snapshot = physical_device.memoryPropertiesRaw();
    try std.testing.expectEqual(@as(u32, 2), raw_snapshot.memoryHeapCount);

    var into: MemoryProperties = undefined;
    try physical_device.memoryPropertiesInto(&into);
    try std.testing.expectEqual(@as(usize, 2), into.heaps().len);
    try std.testing.expectEqual(@as(u64, 512), try into.deviceLocalBytes());
    try std.testing.expect(into.types()[0].flags.contains(.host_visible));

    const returned = try physical_device.memoryProperties();
    test_memory_properties = .{};
    try std.testing.expectEqual(@as(usize, 1), returned.types().len);
    try std.testing.expectEqual(@as(u64, 512), try returned.deviceLocalBytes());
}

test "physical device format queries preserve support and typed capabilities" {
    test_format_properties = .{
        .linearTilingFeatures = @intCast(raw.VK_FORMAT_FEATURE_SAMPLED_IMAGE_BIT),
        .optimalTilingFeatures = @intCast(
            raw.VK_FORMAT_FEATURE_SAMPLED_IMAGE_BIT |
                raw.VK_FORMAT_FEATURE_COLOR_ATTACHMENT_BIT,
        ),
        .bufferFeatures = @intCast(raw.VK_FORMAT_FEATURE_VERTEX_BUFFER_BIT),
    };
    test_image_format_properties = .{
        .maxExtent = .{ .width = 4096, .height = 4096, .depth = 1 },
        .maxMipLevels = 13,
        .maxArrayLayers = 256,
        .sampleCounts = @intCast(
            raw.VK_SAMPLE_COUNT_1_BIT |
                raw.VK_SAMPLE_COUNT_4_BIT,
        ),
        .maxResourceSize = 1 << 30,
    };
    test_image_format_result = raw.VK_SUCCESS;

    var instance = testInstance();
    defer instance.deinit();
    const physical_device: PhysicalDevice = .{
        ._handle = testHandle(raw.VkPhysicalDevice, 0x1100),
        ._instance_handle = testHandle(raw.VkInstance, 0x1000),
        .dispatch = instance.dispatch,
    };

    const format = physical_device.formatProperties(.b8g8r8a8_srgb);
    try std.testing.expect(format.optimal_tiling_features.contains(.sampled_image));
    try std.testing.expect(format.optimal_tiling_features.contains(.color_attachment));
    try std.testing.expect(format.buffer_features.contains(.vertex_buffer));

    const image = (try physical_device.imageFormatProperties(.{
        .format = .b8g8r8a8_srgb,
        .image_type = ._2d,
        .tiling = .optimal,
        .usage = .init(&.{ .sampled, .color_attachment }),
    })).?;
    try std.testing.expectEqual(@as(u32, 4096), image.extent_max.width);
    try std.testing.expectEqual(@as(u32, 13), image.mip_level_count_max);
    try std.testing.expect(image.sample_counts.contains(._4));

    test_image_format_result = raw.VK_ERROR_FORMAT_NOT_SUPPORTED;
    try std.testing.expect((try physical_device.imageFormatProperties(.{
        .format = .b8g8r8a8_srgb,
        .image_type = ._2d,
        .tiling = .optimal,
        .usage = .init(&.{.sampled}),
    })) == null);
    test_image_format_result = raw.VK_ERROR_OUT_OF_DEVICE_MEMORY;
    try std.testing.expectError(
        error.OutOfDeviceMemory,
        physical_device.imageFormatProperties(.{
            .format = .b8g8r8a8_srgb,
            .image_type = ._2d,
            .tiling = .optimal,
            .usage = .init(&.{.sampled}),
        }),
    );
    test_image_format_result = raw.VK_SUCCESS;
}
