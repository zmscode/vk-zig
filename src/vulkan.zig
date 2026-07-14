const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("vulkan_build_options");

/// Complete target-specific Vulkan ABI generated from the Khronos headers.
pub const raw = @import("vulkan_raw");

pub const platform = build_options.platform;
pub const registry_commit = build_options.registry_commit;

const enumeration_attempt_count_max = 4;
const enumeration_item_count_max = 4096;

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
            Function(raw.PFN_vkGetInstanceProcAddr),
            "vkGetInstanceProcAddr",
        ) orelse return error.VulkanEntryPointMissing;
        return Entry.init(get_instance_proc_addr);
    }
};

pub const Entry = struct {
    get_instance_proc_addr: Function(raw.PFN_vkGetInstanceProcAddr),
    create_instance: Function(raw.PFN_vkCreateInstance),
    enumerate_instance_version: ?Function(raw.PFN_vkEnumerateInstanceVersion),
    enumerate_instance_extension_properties: Function(
        raw.PFN_vkEnumerateInstanceExtensionProperties,
    ),
    enumerate_instance_layer_properties: Function(raw.PFN_vkEnumerateInstanceLayerProperties),

    fn init(
        get_instance_proc_addr: Function(raw.PFN_vkGetInstanceProcAddr),
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
        try check(enumerate(&encoded));
        return Version.decode(encoded);
    }

    pub fn instanceExtensions(
        entry: *const Entry,
        gpa: std.mem.Allocator,
        layer_name: ?[:0]const u8,
    ) (Error || std.mem.Allocator.Error)![]raw.VkExtensionProperties {
        var count: u32 = 0;
        try check(entry.enumerate_instance_extension_properties(
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
            if (result != raw.VK_INCOMPLETE) try check(result);

            count = 0;
            try check(entry.enumerate_instance_extension_properties(
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
        try check(entry.enumerate_instance_layer_properties(&count, null));
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
            if (result != raw.VK_INCOMPLETE) try check(result);

            count = 0;
            try check(entry.enumerate_instance_layer_properties(&count, null));
            count = try nextEnumerationCapacity(count, properties.len);
            properties = try gpa.realloc(properties, count);
        }
        return error.EnumerationUnstable;
    }

    pub fn load(
        entry: *const Entry,
        comptime OptionalFunction: type,
        name: [:0]const u8,
    ) ?Function(OptionalFunction) {
        return loadInstance(
            entry.get_instance_proc_addr,
            null,
            OptionalFunction,
            name,
        );
    }

    pub fn createInstance(
        entry: *const Entry,
        options: InstanceOptions,
    ) Error!Instance {
        var application_info: raw.VkApplicationInfo = .{
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
            .flags = options.flags,
            .pApplicationInfo = &application_info,
            .enabledLayerCount = @intCast(options.layers.len),
            .ppEnabledLayerNames = namePointer(options.layers),
            .enabledExtensionCount = @intCast(options.extensions.len),
            .ppEnabledExtensionNames = namePointer(options.extensions),
        };
        return entry.createInstanceRaw(&create_info, options.allocation_callbacks);
    }

    pub fn createInstanceRaw(
        entry: *const Entry,
        create_info: *const raw.VkInstanceCreateInfo,
        allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    ) Error!Instance {
        var handle: raw.VkInstance = null;
        try check(entry.create_instance(create_info, allocation_callbacks, &handle));
        if (handle == null) return error.InitializationFailed;

        const dispatch = InstanceDispatch.init(
            entry.get_instance_proc_addr,
            handle,
        ) catch |load_error| {
            if (loadInstance(
                entry.get_instance_proc_addr,
                handle,
                raw.PFN_vkDestroyInstance,
                "vkDestroyInstance",
            )) |destroy| {
                destroy(handle, allocation_callbacks);
            }
            return load_error;
        };

        return .{
            .handle = handle,
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
    layers: []const [*:0]const u8 = &.{},
    extensions: []const [*:0]const u8 = &.{},
    flags: raw.VkInstanceCreateFlags = 0,
    application_next: ?*const anyopaque = null,
    next: ?*const anyopaque = null,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks = null,
};

pub const Instance = struct {
    handle: raw.VkInstance,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: InstanceDispatch,

    pub fn deinit(instance: *Instance) void {
        const handle = instance.handle orelse return;
        instance.dispatch.destroy_instance(handle, instance.allocation_callbacks);
        instance.handle = null;
    }

    pub fn load(
        instance: *const Instance,
        comptime OptionalFunction: type,
        name: [:0]const u8,
    ) ?Function(OptionalFunction) {
        return loadInstance(
            instance.dispatch.get_instance_proc_addr,
            instance.handle,
            OptionalFunction,
            name,
        );
    }

    pub fn physicalDevices(
        instance: *const Instance,
        gpa: std.mem.Allocator,
    ) (Error || std.mem.Allocator.Error)![]PhysicalDevice {
        const instance_handle = instance.handle orelse return error.InitializationFailed;
        var count: u32 = 0;
        try check(instance.dispatch.enumerate_physical_devices(
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
                    device.* = .{
                        .handle = handle,
                        .instance_handle = instance_handle,
                        .dispatch = instance.dispatch,
                    };
                }
                return devices;
            }
            if (result != raw.VK_INCOMPLETE) try check(result);

            count = 0;
            try check(instance.dispatch.enumerate_physical_devices(
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
};

pub const PhysicalDevice = struct {
    handle: raw.VkPhysicalDevice,
    instance_handle: raw.VkInstance,
    dispatch: InstanceDispatch,

    pub fn properties(device: *const PhysicalDevice) raw.VkPhysicalDeviceProperties {
        var value: raw.VkPhysicalDeviceProperties = .{};
        device.dispatch.get_physical_device_properties(device.handle, &value);
        return value;
    }

    pub fn memoryProperties(device: *const PhysicalDevice) raw.VkPhysicalDeviceMemoryProperties {
        var value: raw.VkPhysicalDeviceMemoryProperties = .{};
        device.dispatch.get_physical_device_memory_properties(device.handle, &value);
        return value;
    }

    pub fn queueFamilyProperties(
        device: *const PhysicalDevice,
        gpa: std.mem.Allocator,
    ) (Error || std.mem.Allocator.Error)![]raw.VkQueueFamilyProperties {
        var count: u32 = 0;
        device.dispatch.get_physical_device_queue_family_properties(
            device.handle,
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
                device.handle,
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

    pub fn createDevice(
        physical_device: *const PhysicalDevice,
        create_info: *const raw.VkDeviceCreateInfo,
        allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    ) Error!Device {
        var handle: raw.VkDevice = null;
        try check(physical_device.dispatch.create_device(
            physical_device.handle,
            create_info,
            allocation_callbacks,
            &handle,
        ));
        if (handle == null) return error.InitializationFailed;

        const dispatch = DeviceDispatch.init(
            physical_device.dispatch.get_device_proc_addr,
            handle,
        ) catch |load_error| {
            if (loadDevice(
                physical_device.dispatch.get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyDevice,
                "vkDestroyDevice",
            )) |destroy| {
                destroy(handle, allocation_callbacks);
            }
            return load_error;
        };
        return .{
            .handle = handle,
            .allocation_callbacks = allocation_callbacks,
            .dispatch = dispatch,
        };
    }
};

pub const Device = struct {
    handle: raw.VkDevice,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: DeviceDispatch,

    pub fn deinit(device: *Device) void {
        const handle = device.handle orelse return;
        device.dispatch.destroy_device(handle, device.allocation_callbacks);
        device.handle = null;
    }

    pub fn waitIdle(device: *const Device) Error!void {
        const handle = device.handle orelse return error.DeviceLost;
        try check(device.dispatch.device_wait_idle(handle));
    }

    pub fn queue(device: *const Device, family_index: u32, queue_index: u32) Queue {
        var handle: raw.VkQueue = null;
        device.dispatch.get_device_queue(
            device.handle,
            family_index,
            queue_index,
            &handle,
        );
        return .{
            .handle = handle,
            .queue_submit = device.dispatch.queue_submit,
            .queue_wait_idle = device.dispatch.queue_wait_idle,
        };
    }

    pub fn load(
        device: *const Device,
        comptime OptionalFunction: type,
        name: [:0]const u8,
    ) ?Function(OptionalFunction) {
        return loadDevice(
            device.dispatch.get_device_proc_addr,
            device.handle,
            OptionalFunction,
            name,
        );
    }
};

pub const Queue = struct {
    handle: raw.VkQueue,
    queue_submit: Function(raw.PFN_vkQueueSubmit),
    queue_wait_idle: Function(raw.PFN_vkQueueWaitIdle),

    pub fn submit(
        queue: *const Queue,
        submit_infos: []const raw.VkSubmitInfo,
        fence: raw.VkFence,
    ) Error!void {
        try check(queue.queue_submit(
            queue.handle,
            @intCast(submit_infos.len),
            if (submit_infos.len == 0) null else submit_infos.ptr,
            fence,
        ));
    }

    pub fn waitIdle(queue: *const Queue) Error!void {
        try check(queue.queue_wait_idle(queue.handle));
    }
};

const InstanceDispatch = struct {
    get_instance_proc_addr: Function(raw.PFN_vkGetInstanceProcAddr),
    get_device_proc_addr: Function(raw.PFN_vkGetDeviceProcAddr),
    destroy_instance: Function(raw.PFN_vkDestroyInstance),
    enumerate_physical_devices: Function(raw.PFN_vkEnumeratePhysicalDevices),
    get_physical_device_properties: Function(raw.PFN_vkGetPhysicalDeviceProperties),
    get_physical_device_memory_properties: Function(raw.PFN_vkGetPhysicalDeviceMemoryProperties),
    get_physical_device_queue_family_properties: Function(
        raw.PFN_vkGetPhysicalDeviceQueueFamilyProperties,
    ),
    create_device: Function(raw.PFN_vkCreateDevice),

    fn init(
        get_instance_proc_addr: Function(raw.PFN_vkGetInstanceProcAddr),
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
    get_device_proc_addr: Function(raw.PFN_vkGetDeviceProcAddr),
    destroy_device: Function(raw.PFN_vkDestroyDevice),
    get_device_queue: Function(raw.PFN_vkGetDeviceQueue),
    queue_submit: Function(raw.PFN_vkQueueSubmit),
    queue_wait_idle: Function(raw.PFN_vkQueueWaitIdle),
    device_wait_idle: Function(raw.PFN_vkDeviceWaitIdle),

    fn init(
        get_device_proc_addr: Function(raw.PFN_vkGetDeviceProcAddr),
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
        };
    }
};

fn Function(comptime OptionalFunction: type) type {
    return switch (@typeInfo(OptionalFunction)) {
        .optional => |optional| optional.child,
        else => @compileError("expected a Vulkan PFN_ optional function-pointer type"),
    };
}

fn loadInstance(
    get_instance_proc_addr: Function(raw.PFN_vkGetInstanceProcAddr),
    instance: raw.VkInstance,
    comptime OptionalFunction: type,
    name: [:0]const u8,
) ?Function(OptionalFunction) {
    const procedure = get_instance_proc_addr(instance, name.ptr) orelse return null;
    return @ptrCast(procedure);
}

fn loadInstanceRequired(
    get_instance_proc_addr: Function(raw.PFN_vkGetInstanceProcAddr),
    instance: raw.VkInstance,
    comptime OptionalFunction: type,
    name: [:0]const u8,
) Error!Function(OptionalFunction) {
    return loadInstance(
        get_instance_proc_addr,
        instance,
        OptionalFunction,
        name,
    ) orelse error.MissingCommand;
}

fn loadDevice(
    get_device_proc_addr: Function(raw.PFN_vkGetDeviceProcAddr),
    device: raw.VkDevice,
    comptime OptionalFunction: type,
    name: [:0]const u8,
) ?Function(OptionalFunction) {
    const procedure = get_device_proc_addr(device, name.ptr) orelse return null;
    return @ptrCast(procedure);
}

fn loadDeviceRequired(
    get_device_proc_addr: Function(raw.PFN_vkGetDeviceProcAddr),
    device: raw.VkDevice,
    comptime OptionalFunction: type,
    name: [:0]const u8,
) Error!Function(OptionalFunction) {
    return loadDevice(
        get_device_proc_addr,
        device,
        OptionalFunction,
        name,
    ) orelse error.MissingCommand;
}

fn check(result: raw.VkResult) Error!void {
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
    return error.UnexpectedVulkanResult;
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

fn namePointer(names: []const [*:0]const u8) [*c]const [*c]const u8 {
    return if (names.len == 0) null else @ptrCast(names.ptr);
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
