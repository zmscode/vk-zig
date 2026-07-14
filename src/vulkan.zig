const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("vulkan_build_options");

/// Complete target-specific Vulkan ABI generated from the Khronos headers.
pub const raw = @import("vulkan_raw");
/// Generated command descriptors bind each Vulkan name, PFN type, and dispatch scope.
pub const command = @import("vulkan_commands");
/// Converts a translated optional `PFN_vk*` type into its storable function-pointer type.
pub const CommandFunction = command.FunctionType;
/// Generated Vulkan extension descriptors with stable sentinel-terminated names.
pub const extension = command.extension;
pub const Extension = command.Extension;

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

const InstanceHandle = NonNullHandle(raw.VkInstance);
const PhysicalDeviceHandle = NonNullHandle(raw.VkPhysicalDevice);
const DeviceHandle = NonNullHandle(raw.VkDevice);
const QueueHandle = NonNullHandle(raw.VkQueue);
const SurfaceHandle = NonNullHandle(raw.VkSurfaceKHR);
const DebugMessengerHandle = NonNullHandle(raw.VkDebugUtilsMessengerEXT);
const SwapchainHandle = NonNullHandle(raw.VkSwapchainKHR);

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

    pub fn instanceFlags() raw.VkInstanceCreateFlags {
        return if (platform == .metal)
            @intCast(raw.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR)
        else
            0;
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
        var flags = options.flags;
        if (options.enumerate_portability) {
            if (platform != .metal) return error.PortabilityNotSupported;
            const portability_extension = portability_instance_extensions[0];
            if (!containsName(options.extensions, portability_extension)) {
                if (extension_count == extension_pointers.len) return error.CountOverflow;
                extension_pointers[extension_count] = portability_extension.ptr;
                extension_count += 1;
            }
            flags |= Portability.instanceFlags();
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
        const create_info: raw.VkInstanceCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = options.next,
            .flags = flags,
            .pApplicationInfo = &application_info,
            .enabledLayerCount = @intCast(layer_count),
            .ppEnabledLayerNames = pointerArray(layer_pointers[0..layer_count]),
            .enabledExtensionCount = @intCast(extension_count),
            .ppEnabledExtensionNames = pointerArray(extension_pointers[0..extension_count]),
        };
        return entry.createInstanceRaw(&create_info, options.allocation_callbacks);
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
    flags: raw.VkInstanceCreateFlags = 0,
    enumerate_portability: bool = false,
    application_next: ?*const anyopaque = null,
    next: ?*const anyopaque = null,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks = null,
};

pub const Instance = struct {
    _handle: ?InstanceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: InstanceDispatch,

    pub fn deinit(instance: *Instance) void {
        const handle = instance._handle orelse return;
        instance.dispatch.destroy_instance(handle, instance.allocation_callbacks);
        instance._handle = null;
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

pub const SwapchainOptions = struct {
    surface: *const Surface,
    min_image_count: u32,
    image_format: raw.VkFormat,
    image_color_space: raw.VkColorSpaceKHR,
    image_extent: raw.VkExtent2D,
    image_usage: raw.VkImageUsageFlags,
    image_array_layers: u32 = 1,
    queue_family_indices: []const u32 = &.{},
    pre_transform: raw.VkSurfaceTransformFlagBitsKHR = raw.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
    composite_alpha: raw.VkCompositeAlphaFlagBitsKHR = raw.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
    present_mode: raw.VkPresentModeKHR = raw.VK_PRESENT_MODE_FIFO_KHR,
    clipped: bool = true,
    old_swapchain: ?*const Swapchain = null,
    flags: raw.VkSwapchainCreateFlagsKHR = 0,
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
    timeout_ns: u64 = std.math.maxInt(u64),
    semaphore: raw.VkSemaphore = null,
    fence: raw.VkFence = null,
};

pub const AcquireResult = union(enum) {
    success: u32,
    suboptimal: u32,
    timeout,
    not_ready,
    out_of_date,
};

pub const PresentOptions = struct {
    swapchain: *const Swapchain,
    image_index: u32,
    wait_semaphores: []const raw.VkSemaphore = &.{},
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

    /// Returns non-owning images whose lifetime is controlled by the swapchain.
    pub fn images(
        swapchain: *const Swapchain,
        gpa: std.mem.Allocator,
    ) (Error || std.mem.Allocator.Error)![]raw.VkImage {
        const handle = try swapchain.rawHandle();
        var count: u32 = 0;
        try checkSuccess(swapchain.get_swapchain_images(
            swapchain._device_handle,
            handle,
            &count,
            null,
        ));
        try validateEnumerationCount(count);
        if (count == 0) return gpa.alloc(raw.VkImage, 0);

        var image_handles = try gpa.alloc(raw.VkImage, count);
        errdefer gpa.free(image_handles);
        for (0..enumeration_attempt_count_max) |_| {
            var written: u32 = @intCast(image_handles.len);
            const result = swapchain.get_swapchain_images(
                swapchain._device_handle,
                handle,
                &written,
                image_handles.ptr,
            );
            if (result == raw.VK_SUCCESS) return gpa.realloc(image_handles, written);
            if (result != raw.VK_INCOMPLETE) try checkSuccess(result);

            count = 0;
            try checkSuccess(swapchain.get_swapchain_images(
                swapchain._device_handle,
                handle,
                &count,
                null,
            ));
            count = try nextEnumerationCapacity(count, image_handles.len);
            image_handles = try gpa.realloc(image_handles, count);
        }
        return error.EnumerationUnstable;
    }

    pub fn acquireNextImage(
        swapchain: *const Swapchain,
        options: AcquireOptions,
    ) Error!AcquireResult {
        if (options.semaphore == null and options.fence == null) return error.InvalidOptions;
        var image_index: u32 = 0;
        const result = swapchain.acquire_next_image(
            swapchain._device_handle,
            try swapchain.rawHandle(),
            options.timeout_ns,
            options.semaphore,
            options.fence,
            &image_index,
        );
        if (result == raw.VK_SUCCESS) return .{ .success = image_index };
        if (result == raw.VK_SUBOPTIMAL_KHR) return .{ .suboptimal = image_index };
        if (result == raw.VK_TIMEOUT) return .timeout;
        if (result == raw.VK_NOT_READY) return .not_ready;
        if (result == raw.VK_ERROR_OUT_OF_DATE_KHR) return .out_of_date;
        try checkSuccess(result);
        unreachable;
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

    pub fn properties(device: *const PhysicalDevice) raw.VkPhysicalDeviceProperties {
        var value: raw.VkPhysicalDeviceProperties = .{};
        device.dispatch.get_physical_device_properties(device._handle, &value);
        return value;
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

    pub fn memoryProperties(device: *const PhysicalDevice) raw.VkPhysicalDeviceMemoryProperties {
        var value: raw.VkPhysicalDeviceMemoryProperties = .{};
        device.dispatch.get_physical_device_memory_properties(device._handle, &value);
        return value;
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
                .index = @intCast(index),
                .properties = property,
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
        family_index: u32,
    ) Error!bool {
        if (surface._instance_handle != device._instance_handle) return error.InvalidHandle;
        const surface_handle = try surface.rawHandle();
        const get_support = device.dispatch.get_physical_device_surface_support_khr orelse {
            return error.MissingCommand;
        };
        var supported: raw.VkBool32 = raw.VK_FALSE;
        try checkSuccess(get_support(
            device._handle,
            family_index,
            surface_handle,
            &supported,
        ));
        return supported != raw.VK_FALSE;
    }

    pub fn surfaceCapabilities(
        device: *const PhysicalDevice,
        surface: *const Surface,
    ) Error!raw.VkSurfaceCapabilitiesKHR {
        if (surface._instance_handle != device._instance_handle) return error.InvalidHandle;
        const get_capabilities = device.dispatch.get_physical_device_surface_capabilities_khr orelse {
            return error.MissingCommand;
        };
        var capabilities: raw.VkSurfaceCapabilitiesKHR = .{};
        try checkSuccess(get_capabilities(
            device._handle,
            try surface.rawHandle(),
            &capabilities,
        ));
        return capabilities;
    }

    pub fn surfaceFormats(
        device: *const PhysicalDevice,
        gpa: std.mem.Allocator,
        surface: *const Surface,
    ) (Error || std.mem.Allocator.Error)![]raw.VkSurfaceFormatKHR {
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

    pub fn presentModes(
        device: *const PhysicalDevice,
        gpa: std.mem.Allocator,
        surface: *const Surface,
    ) (Error || std.mem.Allocator.Error)![]raw.VkPresentModeKHR {
        if (surface._instance_handle != device._instance_handle) return error.InvalidHandle;
        const get_present_modes = device.dispatch.get_physical_device_surface_present_modes_khr orelse {
            return error.MissingCommand;
        };
        return enumeratePresentModes(
            gpa,
            get_present_modes,
            device._handle,
            try surface.rawHandle(),
        );
    }

    pub fn findMemoryTypeIndex(
        device: *const PhysicalDevice,
        options: MemoryTypeOptions,
    ) Error!u32 {
        return selectMemoryTypeIndex(device.memoryProperties(), options);
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
                .queueFamilyIndex = queue.family_index,
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
    index: u32,
    properties: raw.VkQueueFamilyProperties,

    pub fn queueCount(family: QueueFamily) u32 {
        return family.properties.queueCount;
    }

    pub fn supports(family: QueueFamily, capability: QueueCapability) bool {
        if (family.properties.queueCount == 0) return false;
        const bit: raw.VkQueueFlags = switch (capability) {
            .graphics => @intCast(raw.VK_QUEUE_GRAPHICS_BIT),
            .compute => @intCast(raw.VK_QUEUE_COMPUTE_BIT),
            .transfer => @intCast(raw.VK_QUEUE_TRANSFER_BIT),
            .sparse_binding => @intCast(raw.VK_QUEUE_SPARSE_BINDING_BIT),
            .protected => @intCast(raw.VK_QUEUE_PROTECTED_BIT),
        };
        return (family.properties.queueFlags & bit) != 0;
    }

    pub fn presentationSupport(
        family: QueueFamily,
        device: *const PhysicalDevice,
        surface: *const Surface,
    ) Error!bool {
        return device.surfaceSupport(surface, family.index);
    }
};

pub const MemoryTypeOptions = struct {
    type_bits: u32,
    required_flags: raw.VkMemoryPropertyFlags,
    preferred_flags: raw.VkMemoryPropertyFlags = 0,
};

/// Selects a compatible memory type, preferring the candidate with the most
/// requested preferred flags. Equal candidates preserve Vulkan's order.
pub fn selectMemoryTypeIndex(
    memory: raw.VkPhysicalDeviceMemoryProperties,
    options: MemoryTypeOptions,
) Error!u32 {
    if (memory.memoryTypeCount > memory.memoryTypes.len) return error.InvalidOptions;
    var best_index: ?u32 = null;
    var best_score: u32 = 0;
    for (memory.memoryTypes[0..memory.memoryTypeCount], 0..) |memory_type, index| {
        const index_u32: u32 = @intCast(index);
        const type_bit = @as(u32, 1) << @intCast(index_u32);
        if ((options.type_bits & type_bit) == 0) continue;
        if ((memory_type.propertyFlags & options.required_flags) != options.required_flags) {
            continue;
        }
        const score: u32 = @intCast(@popCount(
            memory_type.propertyFlags & options.preferred_flags,
        ));
        if (best_index == null or score > best_score) {
            best_index = index_u32;
            best_score = score;
        }
    }
    return best_index orelse error.MemoryTypeNotFound;
}

pub const DeviceQueueOptions = struct {
    family_index: u32,
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

    pub fn queue(device: *const Device, family_index: u32, queue_index: u32) Error!Queue {
        const device_handle = device._handle orelse return error.InactiveObject;
        var handle: raw.VkQueue = null;
        device.dispatch.get_device_queue(
            device_handle,
            family_index,
            queue_index,
            &handle,
        );
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._device_handle = device_handle,
            .queue_submit = device.dispatch.queue_submit,
            .queue_wait_idle = device.dispatch.queue_wait_idle,
            .queue_present_khr = device.dispatch.queue_present_khr,
            .queue_begin_debug_utils_label_ext = device.dispatch.queue_begin_debug_utils_label_ext,
            .queue_end_debug_utils_label_ext = device.dispatch.queue_end_debug_utils_label_ext,
            .queue_insert_debug_utils_label_ext = device.dispatch.queue_insert_debug_utils_label_ext,
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
        const create_info: raw.VkSwapchainCreateInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .pNext = options.next,
            .flags = options.flags,
            .surface = try options.surface.rawHandle(),
            .minImageCount = options.min_image_count,
            .imageFormat = options.image_format,
            .imageColorSpace = options.image_color_space,
            .imageExtent = options.image_extent,
            .imageArrayLayers = options.image_array_layers,
            .imageUsage = options.image_usage,
            .imageSharingMode = if (concurrent)
                raw.VK_SHARING_MODE_CONCURRENT
            else
                raw.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = if (concurrent)
                @intCast(options.queue_family_indices.len)
            else
                0,
            .pQueueFamilyIndices = if (concurrent)
                options.queue_family_indices.ptr
            else
                null,
            .preTransform = options.pre_transform,
            .compositeAlpha = options.composite_alpha,
            .presentMode = options.present_mode,
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

    pub fn beginCommandBufferLabel(
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

    pub fn endCommandBufferLabel(
        device: *const Device,
        command_buffer: raw.VkCommandBuffer,
    ) Error!void {
        _ = device._handle orelse return error.InactiveObject;
        const end_label = device.dispatch.cmd_end_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        end_label(command_buffer orelse return error.InvalidHandle);
    }

    pub fn insertCommandBufferLabel(
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
        const wait_count = try count32(options.wait_semaphores.len);
        const swapchain_handle = try options.swapchain.rawHandle();
        const present_info: raw.VkPresentInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .pNext = options.next,
            .waitSemaphoreCount = wait_count,
            .pWaitSemaphores = if (options.wait_semaphores.len == 0)
                null
            else
                options.wait_semaphores.ptr,
            .swapchainCount = 1,
            .pSwapchains = @ptrCast(&swapchain_handle),
            .pImageIndices = @ptrCast(&options.image_index),
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
                if (message.data.queueLabelCount == 0 or message.data.pQueueLabels == null) return &.{};
                return message.data.pQueueLabels[0..message.data.queueLabelCount];
            }

            pub fn commandBufferLabels(message: Message) []const raw.VkDebugUtilsLabelEXT {
                if (message.data.cmdBufLabelCount == 0 or message.data.pCmdBufLabels == null) return &.{};
                return message.data.pCmdBufLabels[0..message.data.cmdBufLabelCount];
            }
        };

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
            semaphore: raw.VkSemaphore,
            command_buffer: raw.VkCommandBuffer,
            fence: raw.VkFence,
            device_memory: raw.VkDeviceMemory,
            buffer: raw.VkBuffer,
            image: raw.VkImage,
            event: raw.VkEvent,
            query_pool: raw.VkQueryPool,
            buffer_view: raw.VkBufferView,
            image_view: raw.VkImageView,
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
            command_pool: raw.VkCommandPool,
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
                    inline else => |handle, tag| .{
                        .object_type = objectType(tag),
                        .handle = try handleValue(handle),
                    },
                };
            }

            fn objectType(comptime tag: std.meta.Tag(Object)) raw.VkObjectType {
                return @intCast(switch (tag) {
                    .device, .queue, .surface, .swapchain => unreachable,
                    .semaphore => raw.VK_OBJECT_TYPE_SEMAPHORE,
                    .command_buffer => raw.VK_OBJECT_TYPE_COMMAND_BUFFER,
                    .fence => raw.VK_OBJECT_TYPE_FENCE,
                    .device_memory => raw.VK_OBJECT_TYPE_DEVICE_MEMORY,
                    .buffer => raw.VK_OBJECT_TYPE_BUFFER,
                    .image => raw.VK_OBJECT_TYPE_IMAGE,
                    .event => raw.VK_OBJECT_TYPE_EVENT,
                    .query_pool => raw.VK_OBJECT_TYPE_QUERY_POOL,
                    .buffer_view => raw.VK_OBJECT_TYPE_BUFFER_VIEW,
                    .image_view => raw.VK_OBJECT_TYPE_IMAGE_VIEW,
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
                    .command_pool => raw.VK_OBJECT_TYPE_COMMAND_POOL,
                    .raw_surface => raw.VK_OBJECT_TYPE_SURFACE_KHR,
                    .raw_swapchain => raw.VK_OBJECT_TYPE_SWAPCHAIN_KHR,
                });
            }

            fn validateParent(object: Object, device: *const Device) Error!void {
                const device_handle = device._handle orelse return error.InactiveObject;
                switch (object) {
                    .device => |named_device| {
                        if (try named_device.rawHandle() != device_handle) return error.InvalidHandle;
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
) (Error || std.mem.Allocator.Error)![]raw.VkSurfaceFormatKHR {
    var count: u32 = 0;
    try checkSuccess(enumerate(physical_device, surface, &count, null));
    try validateEnumerationCount(count);
    if (count == 0) return gpa.alloc(raw.VkSurfaceFormatKHR, 0);

    var formats = try gpa.alloc(raw.VkSurfaceFormatKHR, count);
    errdefer gpa.free(formats);
    for (0..enumeration_attempt_count_max) |_| {
        var written: u32 = @intCast(formats.len);
        const result = enumerate(physical_device, surface, &written, formats.ptr);
        if (result == raw.VK_SUCCESS) return gpa.realloc(formats, written);
        if (result != raw.VK_INCOMPLETE) try checkSuccess(result);

        count = 0;
        try checkSuccess(enumerate(physical_device, surface, &count, null));
        count = try nextEnumerationCapacity(count, formats.len);
        formats = try gpa.realloc(formats, count);
    }
    return error.EnumerationUnstable;
}

fn enumeratePresentModes(
    gpa: std.mem.Allocator,
    enumerate: CommandFunction(raw.PFN_vkGetPhysicalDeviceSurfacePresentModesKHR),
    physical_device: raw.VkPhysicalDevice,
    surface: raw.VkSurfaceKHR,
) (Error || std.mem.Allocator.Error)![]raw.VkPresentModeKHR {
    var count: u32 = 0;
    try checkSuccess(enumerate(physical_device, surface, &count, null));
    try validateEnumerationCount(count);
    if (count == 0) return gpa.alloc(raw.VkPresentModeKHR, 0);

    var modes = try gpa.alloc(raw.VkPresentModeKHR, count);
    errdefer gpa.free(modes);
    for (0..enumeration_attempt_count_max) |_| {
        var written: u32 = @intCast(modes.len);
        const result = enumerate(physical_device, surface, &written, modes.ptr);
        if (result == raw.VK_SUCCESS) return gpa.realloc(modes, written);
        if (result != raw.VK_INCOMPLETE) try checkSuccess(result);

        count = 0;
        try checkSuccess(enumerate(physical_device, surface, &count, null));
        count = try nextEnumerationCapacity(count, modes.len);
        modes = try gpa.realloc(modes, count);
    }
    return error.EnumerationUnstable;
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
        .allocation_callbacks = null,
        .dispatch = .{
            .get_instance_proc_addr = testGetInstanceProcAddr,
            .get_device_proc_addr = testFunction(raw.PFN_vkGetDeviceProcAddr),
            .destroy_instance = testDestroyInstance,
            .enumerate_physical_devices = testFunction(raw.PFN_vkEnumeratePhysicalDevices),
            .get_physical_device_properties = testFunction(raw.PFN_vkGetPhysicalDeviceProperties),
            .get_physical_device_features = testFunction(raw.PFN_vkGetPhysicalDeviceFeatures),
            .get_physical_device_features2 = testFunction(raw.PFN_vkGetPhysicalDeviceFeatures2),
            .get_physical_device_memory_properties = testFunction(
                raw.PFN_vkGetPhysicalDeviceMemoryProperties,
            ),
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
    try std.testing.expectError(error.InvalidHandle, device.queue(0, 0));
    device.deinit();
    device.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_device_count);
    try std.testing.expectError(error.InactiveObject, device.rawHandle());
    try std.testing.expectError(error.InactiveObject, device.queue(0, 0));
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

    if (@bitSizeOf(usize) > @bitSizeOf(u32)) {
        const too_many = @as(usize, std.math.maxInt(u32)) + 1;
        const submit_pointer: [*]const raw.VkSubmitInfo = @ptrFromInt(0x1000);
        try std.testing.expectError(
            error.CountOverflow,
            queue.submit(submit_pointer[0..too_many], null),
        );
        try std.testing.expectEqual(@as(usize, 0), test_queue_submit_count);
    }

    try queue.submit(&.{}, null);
    try std.testing.expectEqual(@as(usize, 1), test_queue_submit_count);
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
    try std.testing.expect(try physical_device.surfaceSupport(&surface, 0));
    test_missing_command = .surface_support;
    try std.testing.expectError(
        error.MissingCommand,
        physical_device.surfaceSupport(&surface, 0),
    );
    test_missing_command = .none;
    test_surface_supported = raw.VK_FALSE;
    try std.testing.expect(!try physical_device.surfaceSupport(&surface, 0));
    test_surface_result = raw.VK_ERROR_SURFACE_LOST_KHR;
    try std.testing.expectError(
        error.UnexpectedVulkanResult,
        physical_device.surfaceSupport(&surface, 0),
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
    test_missing_command = .set_object_name;
    try std.testing.expectError(
        error.MissingCommand,
        device.setObjectName(.{ .device = &device }, "test-device"),
    );
}
