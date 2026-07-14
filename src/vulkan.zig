const std = @import("std");
const builtin = @import("builtin");
pub const core = @import("core.zig");
pub const capabilities = @import("capabilities.zig");
pub const configuration = @import("configuration.zig");
pub const registry = @import("registry.zig");
pub const physical_devices = @import("physical_device.zig");
pub const device_configuration = @import("device.zig");
pub const formats = @import("format.zig");
pub const memory = @import("memory.zig");
pub const buffers = @import("buffer.zig");
pub const images = @import("image.zig");
pub const samplers = @import("sampler.zig");
pub const shaders = @import("shader.zig");
pub const descriptors = @import("descriptor.zig");
pub const pipelines = @import("pipeline.zig");
pub const rendering = @import("rendering.zig");
pub const transfers = @import("transfer.zig");
pub const synchronization = @import("synchronization.zig");
pub const commands = @import("command_buffer.zig");
pub const presentation = @import("presentation.zig");
pub const queues = @import("queue.zig");
pub const debug_utils = @import("debug_utils.zig");
pub const workflows = @import("workflows.zig");
pub const optical_flow = @import("optical_flow.zig");

/// Deprecated short name retained while applications migrate to `synchronization`.
pub const sync = synchronization;
/// Deprecated name retained while applications migrate to `formats`.
pub const format_support = formats;

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
pub const DeviceFeature = device_configuration.Feature;
pub const DeviceFeatureSet = device_configuration.FeatureSet;
pub const DeviceRequirements = device_configuration.Requirements;
pub const DeviceEvaluation = device_configuration.Evaluation;
pub const DeviceRejection = device_configuration.Rejection;
pub const DeviceGlobalPriority = device_configuration.GlobalPriority;

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
pub const BufferUsageBit = types.BufferUsageBit;
pub const BufferUsageFlags = types.BufferUsageFlags;
pub const BufferCreateBit = types.BufferCreateBit;
pub const BufferCreateFlags = types.BufferCreateFlags;
pub const ImageCreateBit = types.ImageCreateBit;
pub const ImageCreateFlags = types.ImageCreateFlags;
pub const SampleCountBit = types.SampleCountBit;
pub const SampleCountFlags = types.SampleCountFlags;
pub const FenceCreateBit = types.FenceCreateBit;
pub const FenceCreateFlags = types.FenceCreateFlags;
pub const FormatFeatureBit = types.FormatFeatureBit;
pub const FormatFeatureFlags = types.FormatFeatureFlags;
pub const FormatFeature2Bit = types.FormatFeature2Bit;
pub const FormatFeature2Flags = types.FormatFeature2Flags;
pub const ExternalMemoryHandleTypeBit = types.ExternalMemoryHandleTypeBit;
pub const ExternalMemoryHandleTypeFlags = types.ExternalMemoryHandleTypeFlags;
pub const ExternalMemoryFeatureBit = types.ExternalMemoryFeatureBit;
pub const ExternalMemoryFeatureFlags = types.ExternalMemoryFeatureFlags;
pub const CommandBufferUsageBit = types.CommandBufferUsageBit;
pub const CommandBufferUsageFlags = types.CommandBufferUsageFlags;
pub const ImageAspectBit = types.ImageAspectBit;
pub const ImageAspectFlags = types.ImageAspectFlags;
pub const PipelineStageBit = types.PipelineStageBit;
pub const PipelineStageFlags = types.PipelineStageFlags;
pub const PipelineStage2Bit = types.PipelineStage2Bit;
pub const PipelineStage2Flags = types.PipelineStage2Flags;
pub const Access2Bit = types.Access2Bit;
pub const Access2Flags = types.Access2Flags;
pub const DependencyBit = types.DependencyBit;
pub const DependencyFlags = types.DependencyFlags;
pub const SubmitBit = types.SubmitBit;
pub const SubmitFlags = types.SubmitFlags;
pub const CommandPoolCreateBit = types.CommandPoolCreateBit;
pub const CommandPoolCreateFlags = types.CommandPoolCreateFlags;
pub const CompositeAlphaBit = types.CompositeAlphaBit;
pub const CompositeAlphaFlags = types.CompositeAlphaFlags;
pub const SurfaceTransformBit = types.SurfaceTransformBit;
pub const SurfaceTransformFlags = types.SurfaceTransformFlags;
pub const SwapchainCreateBit = types.SwapchainCreateBit;
pub const SwapchainCreateFlags = types.SwapchainCreateFlags;
pub const SparseImageFormatBit = types.SparseImageFormatBit;
pub const SparseImageFormatFlags = types.SparseImageFormatFlags;
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
pub const Error = core.Error;
pub const LoaderError = core.LoaderError;
pub const Version = core.Version;
pub const QueueFamilyIndex = core.QueueFamilyIndex;
pub const QueueIndex = core.QueueIndex;
pub const SwapchainImageIndex = core.SwapchainImageIndex;
pub const MemoryTypeIndex = core.MemoryTypeIndex;
pub const MemoryHeapIndex = core.MemoryHeapIndex;
pub const DeviceSize = core.DeviceSize;
pub const DeviceOffset = core.DeviceOffset;
pub const DeviceRange = core.DeviceRange;
pub const Timeout = core.Timeout;
pub const QueueFamilyOwnership = core.QueueFamilyOwnership;
pub const checkSuccess = core.checkSuccess;

const NonNullHandle = core.NonNullHandle;
const count32 = core.count32;

fn bool32(value: bool) raw.VkBool32 {
    return if (value) raw.VK_TRUE else raw.VK_FALSE;
}

pub const Choice = capabilities.Choice;
pub const clampSurfaceExtent = capabilities.clampSurfaceExtent;
pub const chooseSwapchainImageCount = capabilities.chooseSwapchainImageCount;
pub const chooseSurfaceFormat = capabilities.chooseSurfaceFormat;
pub const choosePresentMode = capabilities.choosePresentMode;
pub const chooseSurfaceTransform = capabilities.chooseSurfaceTransform;
pub const chooseCompositeAlpha = capabilities.chooseCompositeAlpha;
pub const chooseImageUsage = capabilities.chooseImageUsage;

pub const Layer = configuration.Layer;
pub const layer = configuration.layer;
pub const platform = configuration.platform;
pub const registry_commit = configuration.registry_commit;

const enumeration_attempt_count_max = 4;
const enumeration_item_count_max = 4096;
const name_count_max = 256;
const device_queue_count_max = 64;
const submission_item_count_max = 64;

const InstanceHandle = NonNullHandle(raw.VkInstance);
const PhysicalDeviceHandle = NonNullHandle(raw.VkPhysicalDevice);
const DeviceHandle = NonNullHandle(raw.VkDevice);

pub const Portability = configuration.Portability;
pub const ExtensionSet = registry.NameSet;
pub const boundedCString = registry.boundedCString;
pub const extensionName = registry.extensionName;
pub const layerName = registry.layerName;
pub const layerDescription = registry.layerDescription;
pub const physicalDeviceName = registry.physicalDeviceName;
pub const supportsExtension = registry.supportsExtension;
pub const supportsLayer = registry.supportsLayer;
pub const diagnostics = configuration.diagnostics;

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
        return loadInstanceDescriptor(
            entry.get_instance_proc_addr,
            null,
            descriptor,
            .global,
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
            const portability_extension = Portability.instanceExtensions()[0];
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
            debug_create_info = config.createInfoRaw(options.next);
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
            instance._debug_messenger = try instance.createDebugMessenger(
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
    debug_messenger: ?debug_utils.Config = null,
};

pub const Instance = struct {
    _handle: ?InstanceHandle,
    _debug_messenger: ?debug_utils.Messenger,
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

    pub fn createDebugMessenger(
        instance: *const Instance,
        config: debug_utils.Config,
        allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    ) Error!debug_utils.Messenger {
        const instance_handle = instance._handle orelse return error.InactiveObject;
        const create = (try instance.load(command.create_debug_utils_messenger_ext)) orelse {
            return error.MissingCommand;
        };
        const destroy = (try instance.load(command.destroy_debug_utils_messenger_ext)) orelse {
            return error.MissingCommand;
        };
        return debug_utils.createMessenger(
            instance_handle,
            allocation_callbacks,
            .{ .create = create, .destroy = destroy },
            config,
        );
    }

    /// Returns the live raw handle for explicit FFI integration.
    pub fn rawHandle(instance: *const Instance) Error!raw.VkInstance {
        return instance._handle orelse error.InactiveObject;
    }

    pub fn load(
        instance: *const Instance,
        comptime descriptor: anytype,
    ) Error!?DescriptorFunction(descriptor, .instance) {
        const handle = instance._handle orelse return error.InactiveObject;
        return loadInstanceDescriptor(
            instance.dispatch.get_instance_proc_addr,
            handle,
            descriptor,
            .instance,
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
pub const Surface = presentation.Surface;
pub const SwapchainImage = images.SwapchainImage;
pub const ImageViewOptions = images.ViewOptions;
pub const ImageView = images.View;
pub const Image = images.Image;
pub const ImageOptions = images.Options;
pub const ImageReference = images.Reference;
pub const ImageMemoryRequirements = images.MemoryRequirements;

pub const SemaphoreKind = sync.SemaphoreKind;
pub const SemaphoreOptions = sync.SemaphoreOptions;
pub const TimelineWaitStatus = sync.TimelineWaitStatus;
pub const Semaphore = sync.Semaphore;
pub const FenceOptions = sync.FenceOptions;
pub const FenceWaitStatus = sync.FenceWaitStatus;
pub const FenceStatus = sync.FenceStatus;
pub const WaitMode = sync.WaitMode;
pub const TimelineSemaphoreWait = sync.TimelineSemaphoreWait;
pub const Fence = sync.Fence;
pub const Event = sync.Event;
pub const MemoryBarrier = sync.MemoryBarrier;
pub const BufferMemoryBarrier = sync.BufferBarrier;
pub const ImageMemoryBarrier = sync.ImageBarrier;
pub const DependencyInfo = sync.DependencyInfo;
pub const RenderingFlags = rendering.Flags;
pub const RenderingAttachment = rendering.Attachment;
pub const RenderingOptions = rendering.Options;
pub const RenderingLoadOperation = rendering.LoadOperation;
pub const RenderingStoreOperation = rendering.StoreOperation;
pub const RenderingResolve = rendering.Resolve;
pub const RenderingResolveMode = rendering.ResolveMode;
pub const ImageSubresourceLayers = transfers.SubresourceLayers;
pub const BufferCopy = transfers.BufferCopy;
pub const BufferImageCopy = transfers.BufferImageCopy;
pub const ImageCopy = transfers.ImageCopy;
pub const ImageBlit = transfers.ImageBlit;
pub const ImageResolve = transfers.ImageResolve;

pub const CommandPoolOptions = commands.PoolOptions;
pub const CommandBufferOptions = commands.Options;
pub const SecondaryCommandBufferInheritance = commands.SecondaryInheritance;
pub const CommandBufferBeginOptions = commands.BeginOptions;
pub const ImageBarrierOptions = commands.ImageBarrierOptions;
pub const ClearColorImageOptions = commands.ClearColorImageOptions;
pub const ClearDepthStencilImageOptions = commands.ClearDepthStencilImageOptions;
pub const VertexBufferBinding = commands.VertexBufferBinding;
pub const IndexType = commands.IndexType;
pub const DrawOptions = commands.DrawOptions;
pub const DrawIndexedOptions = commands.DrawIndexedOptions;
pub const DispatchOptions = commands.DispatchOptions;
pub const CommandBuffer = commands.Buffer;
pub const CommandBufferLabelScope = commands.LabelScope;
pub const CommandPool = commands.Pool;

pub const SwapchainOptions = presentation.Options;
pub const AcquireOptions = presentation.AcquireOptions;
pub const AcquireResult = presentation.AcquireResult;
pub const PresentOptions = presentation.PresentOptions;
pub const PresentStatus = presentation.PresentStatus;
pub const Swapchain = presentation.Swapchain;

pub const PhysicalDeviceLimits = physical_devices.Limits;
pub const SparseProperties = physical_devices.SparseProperties;
pub const PhysicalDeviceProperties = physical_devices.Properties;

pub const FormatProperties = format_support.Properties;
pub const ImageFormatOptions = format_support.ImageOptions;
pub const DrmFormatModifierQuery = format_support.DrmModifierQuery;
pub const ImageFormatQueryOptions = format_support.ImageQueryOptions;
pub const ImageFormatProperties = format_support.ImageProperties;
pub const ExternalMemoryProperties = format_support.ExternalMemoryProperties;
pub const ImageFormatQueryResult = format_support.ImageQueryResult;
pub const DrmFormatModifierProperties = format_support.DrmModifierProperties;
pub const SparseImageFormatOptions = format_support.SparseImageOptions;
pub const SparseImageFormatProperties = format_support.SparseImageProperties;
pub const sparse_image_format_property_count_max = format_support.sparse_image_property_count_max;
pub const drm_format_modifier_property_count_max = format_support.drm_modifier_property_count_max;

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

    /// Uses the Vulkan 1.1/KHR promoted query and resolves either command name.
    pub fn formatProperties2(
        device: *const PhysicalDevice,
        format: Format,
    ) Error!FormatProperties {
        const get_properties = device.dispatch.get_physical_device_format_properties2 orelse {
            return error.MissingCommand;
        };
        var value: raw.VkFormatProperties2 = .{
            .sType = raw.VK_STRUCTURE_TYPE_FORMAT_PROPERTIES_2,
        };
        get_properties(device._handle, format.toRaw(), &value);
        return .fromRaw(value.formatProperties);
    }

    /// Uses the Vulkan 1.1/KHR promoted query. Unsupported combinations return null.
    pub fn imageFormatProperties2(
        device: *const PhysicalDevice,
        options: ImageFormatQueryOptions,
    ) Error!?ImageFormatQueryResult {
        const get_properties = device.dispatch.get_physical_device_image_format_properties2 orelse {
            return error.MissingCommand;
        };
        var queue_family_indices_raw: [device_queue_count_max]u32 = undefined;
        var external_info: raw.VkPhysicalDeviceExternalImageFormatInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO,
        };
        var drm_info: raw.VkPhysicalDeviceImageDrmFormatModifierInfoEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_DRM_FORMAT_MODIFIER_INFO_EXT,
        };
        var input_next: ?*const anyopaque = null;
        if (options.drm_format_modifier) |drm| {
            if (options.tiling != .drm_format_modifier_ext) return error.InvalidOptions;
            if (drm.queue_family_indices.len > device_queue_count_max) return error.CountOverflow;
            if (drm.queue_family_indices.len == 1) return error.InvalidOptions;
            for (drm.queue_family_indices, 0..) |family_index, index| {
                for (drm.queue_family_indices[0..index]) |previous_index| {
                    if (family_index == previous_index) return error.InvalidOptions;
                }
                queue_family_indices_raw[index] = family_index.toRaw();
            }
            drm_info.drmFormatModifier = drm.modifier;
            drm_info.sharingMode = if (drm.queue_family_indices.len > 1)
                SharingMode.concurrent.toRaw()
            else
                SharingMode.exclusive.toRaw();
            drm_info.queueFamilyIndexCount = @intCast(drm.queue_family_indices.len);
            drm_info.pQueueFamilyIndices = if (drm.queue_family_indices.len == 0)
                null
            else
                queue_family_indices_raw[0..drm.queue_family_indices.len].ptr;
            input_next = &drm_info;
        }
        if (options.external_memory_handle_type) |handle_type| {
            external_info.handleType = handle_type.toRaw();
            external_info.pNext = input_next;
            input_next = &external_info;
        }
        var info: raw.VkPhysicalDeviceImageFormatInfo2 = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
            .pNext = input_next,
            .format = options.format.toRaw(),
            .type = options.image_type.toRaw(),
            .tiling = options.tiling.toRaw(),
            .usage = options.usage.toRaw(),
            .flags = options.flags.toRaw(),
        };
        var value: raw.VkImageFormatProperties2 = .{
            .sType = raw.VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2,
        };
        var external_properties: raw.VkExternalImageFormatProperties = .{
            .sType = raw.VK_STRUCTURE_TYPE_EXTERNAL_IMAGE_FORMAT_PROPERTIES,
        };
        if (options.external_memory_handle_type != null) value.pNext = &external_properties;
        const result = get_properties(device._handle, &info, &value);
        if (result == raw.VK_ERROR_FORMAT_NOT_SUPPORTED) return null;
        try checkSuccess(result);
        return .{
            .properties = .fromRaw(value.imageFormatProperties),
            .external_memory = if (options.external_memory_handle_type != null)
                .fromRaw(external_properties.externalMemoryProperties)
            else
                null,
        };
    }

    pub fn drmFormatModifierPropertyCount(
        device: *const PhysicalDevice,
        format: Format,
    ) Error!u32 {
        const get_properties = device.dispatch.get_physical_device_format_properties2 orelse {
            return error.MissingCommand;
        };
        var list: raw.VkDrmFormatModifierPropertiesListEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT,
        };
        var value: raw.VkFormatProperties2 = .{
            .sType = raw.VK_STRUCTURE_TYPE_FORMAT_PROPERTIES_2,
            .pNext = &list,
        };
        get_properties(device._handle, format.toRaw(), &value);
        try validateEnumerationCount(list.drmFormatModifierCount);
        if (list.drmFormatModifierCount > drm_format_modifier_property_count_max) {
            return error.CountOverflow;
        }
        return list.drmFormatModifierCount;
    }

    pub fn drmFormatModifierPropertiesInto(
        device: *const PhysicalDevice,
        format: Format,
        storage: []DrmFormatModifierProperties,
    ) Error![]DrmFormatModifierProperties {
        if (storage.len > drm_format_modifier_property_count_max) return error.CountOverflow;
        const get_properties = device.dispatch.get_physical_device_format_properties2 orelse {
            return error.MissingCommand;
        };
        var raw_properties: [drm_format_modifier_property_count_max]raw.VkDrmFormatModifierPropertiesEXT = undefined;
        var list: raw.VkDrmFormatModifierPropertiesListEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT,
            .drmFormatModifierCount = @intCast(storage.len),
            .pDrmFormatModifierProperties = if (storage.len == 0)
                null
            else
                raw_properties[0..storage.len].ptr,
        };
        var value: raw.VkFormatProperties2 = .{
            .sType = raw.VK_STRUCTURE_TYPE_FORMAT_PROPERTIES_2,
            .pNext = &list,
        };
        get_properties(device._handle, format.toRaw(), &value);
        if (list.drmFormatModifierCount > storage.len) return error.BufferTooSmall;
        for (storage[0..list.drmFormatModifierCount], raw_properties[0..list.drmFormatModifierCount]) |*property, raw_property| {
            property.* = .fromRaw(raw_property);
        }
        return storage[0..list.drmFormatModifierCount];
    }

    pub fn drmFormatModifierProperties(
        device: *const PhysicalDevice,
        gpa: std.mem.Allocator,
        format: Format,
    ) (Error || std.mem.Allocator.Error)![]DrmFormatModifierProperties {
        const count = try device.drmFormatModifierPropertyCount(format);
        const output = try gpa.alloc(DrmFormatModifierProperties, count);
        errdefer gpa.free(output);
        const written = try device.drmFormatModifierPropertiesInto(format, output);
        return gpa.realloc(output, written.len);
    }

    pub fn sparseImageFormatPropertyCount(
        device: *const PhysicalDevice,
        options: SparseImageFormatOptions,
    ) Error!u32 {
        const get_properties = device.dispatch.get_physical_device_sparse_image_format_properties2 orelse {
            return error.MissingCommand;
        };
        var info = options.toRaw();
        var count: u32 = 0;
        get_properties(device._handle, &info, &count, null);
        try validateEnumerationCount(count);
        if (count > sparse_image_format_property_count_max) return error.CountOverflow;
        return count;
    }

    pub fn sparseImageFormatPropertiesInto(
        device: *const PhysicalDevice,
        options: SparseImageFormatOptions,
        storage: []SparseImageFormatProperties,
    ) Error![]SparseImageFormatProperties {
        if (storage.len > sparse_image_format_property_count_max) return error.CountOverflow;
        const get_properties = device.dispatch.get_physical_device_sparse_image_format_properties2 orelse {
            return error.MissingCommand;
        };
        var info = options.toRaw();
        var raw_properties: [sparse_image_format_property_count_max]raw.VkSparseImageFormatProperties2 = undefined;
        for (raw_properties[0..storage.len]) |*property| {
            property.* = .{ .sType = raw.VK_STRUCTURE_TYPE_SPARSE_IMAGE_FORMAT_PROPERTIES_2 };
        }
        var count: u32 = @intCast(storage.len);
        get_properties(device._handle, &info, &count, raw_properties[0..storage.len].ptr);
        if (count > storage.len) return error.BufferTooSmall;
        for (storage[0..count], raw_properties[0..count]) |*property, raw_property| {
            property.* = .fromRaw(raw_property.properties);
        }
        return storage[0..count];
    }

    pub fn sparseImageFormatProperties(
        device: *const PhysicalDevice,
        gpa: std.mem.Allocator,
        options: SparseImageFormatOptions,
    ) (Error || std.mem.Allocator.Error)![]SparseImageFormatProperties {
        const count = try device.sparseImageFormatPropertyCount(options);
        const output = try gpa.alloc(SparseImageFormatProperties, count);
        errdefer gpa.free(output);
        const written = try device.sparseImageFormatPropertiesInto(options, output);
        return gpa.realloc(output, written.len);
    }

    /// Returns the raw Vulkan 1.0 feature structure for explicit FFI interop.
    pub fn featuresRaw(device: *const PhysicalDevice) raw.VkPhysicalDeviceFeatures {
        var value: raw.VkPhysicalDeviceFeatures = .{};
        device.dispatch.get_physical_device_features(device._handle, &value);
        return value;
    }

    /// Queries a raw-free snapshot of supported core and promoted modern features.
    pub fn features(device: *const PhysicalDevice) Error!DeviceFeatureSet {
        const device_properties = device.properties();
        const get_features2 = device.dispatch.get_physical_device_features2 orelse {
            const core_features = device.featuresRaw();
            return .fromCoreRaw(&core_features);
        };

        var features_11: raw.VkPhysicalDeviceVulkan11Features = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
        };
        var features_12: raw.VkPhysicalDeviceVulkan12Features = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
        };
        var features_13: raw.VkPhysicalDeviceVulkan13Features = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
        };
        var features_14: raw.VkPhysicalDeviceVulkan14Features = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_4_FEATURES,
        };
        var root: raw.VkPhysicalDeviceFeatures2 = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
        };
        if (device_properties.api_version.atLeast(.v1_1)) root.pNext = &features_11;
        if (device_properties.api_version.atLeast(.v1_2)) features_11.pNext = &features_12;
        if (device_properties.api_version.atLeast(.v1_3)) features_12.pNext = &features_13;
        if (device_properties.api_version.atLeast(.v1_4)) features_13.pNext = &features_14;
        get_features2(device._handle, &root);

        var supported = DeviceFeatureSet.fromCoreRaw(&root.features);
        if (features_11.protectedMemory != raw.VK_FALSE) supported.enable(.protected_memory);
        if (features_11.samplerYcbcrConversion != raw.VK_FALSE) supported.enable(.sampler_ycbcr_conversion);
        if (features_11.multiview != raw.VK_FALSE) supported.enable(.multiview);
        if (features_11.shaderDrawParameters != raw.VK_FALSE) supported.enable(.shader_draw_parameters);
        if (features_12.drawIndirectCount != raw.VK_FALSE) supported.enable(.draw_indirect_count);
        if (features_12.timelineSemaphore != raw.VK_FALSE) supported.enable(.timeline_semaphore);
        if (features_12.bufferDeviceAddress != raw.VK_FALSE) supported.enable(.buffer_device_address);
        if (features_12.descriptorIndexing != raw.VK_FALSE) supported.enable(.descriptor_indexing);
        if (features_13.synchronization2 != raw.VK_FALSE) supported.enable(.synchronization2);
        if (features_13.dynamicRendering != raw.VK_FALSE) supported.enable(.dynamic_rendering);
        if (features_13.maintenance4 != raw.VK_FALSE) supported.enable(.maintenance4);
        if (features_14.globalPriorityQuery != raw.VK_FALSE) supported.enable(.global_priority_query);
        if (features_14.hostImageCopy != raw.VK_FALSE) supported.enable(.host_image_copy);
        if (features_14.pushDescriptor != raw.VK_FALSE) supported.enable(.push_descriptor);
        return supported;
    }

    /// Queries core and chained feature structures. `next` must point to a mutable
    /// Vulkan feature structure whose lifetime covers this call.
    pub fn features2Raw(
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

    /// Deprecated raw escape hatch. Prefer `features`; use `features2Raw` only
    /// when interoperating with a feature structure not yet wrapped by vk-zig.
    pub const features2 = features2Raw;

    /// Returns the raw fixed-capacity Vulkan structure for diagnostics and interop.
    pub fn memoryPropertiesRaw(device: *const PhysicalDevice) raw.VkPhysicalDeviceMemoryProperties {
        var value: raw.VkPhysicalDeviceMemoryProperties = .{};
        device.dispatch.get_physical_device_memory_properties(device._handle, &value);
        return value;
    }

    /// Returns an owned typed snapshot whose slices borrow from the returned value.
    pub fn memoryProperties(device: *const PhysicalDevice) Error!MemoryProperties {
        var snapshot: MemoryProperties = undefined;
        try device.memoryPropertiesInto(&snapshot);
        return snapshot;
    }

    /// Initializes caller-owned typed storage without returning a large intermediate value.
    pub fn memoryPropertiesInto(
        device: *const PhysicalDevice,
        output: *MemoryProperties,
    ) Error!void {
        const raw_properties = device.memoryPropertiesRaw();
        try output.initFromRaw(&raw_properties);
    }

    pub fn memoryBudget(device: *const PhysicalDevice) Error!memory.BudgetSnapshot {
        const get_properties = device.dispatch.get_physical_device_memory_properties2 orelse {
            return error.MissingCommand;
        };
        var budget: raw.VkPhysicalDeviceMemoryBudgetPropertiesEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_BUDGET_PROPERTIES_EXT,
        };
        var memory_properties: raw.VkPhysicalDeviceMemoryProperties2 = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_PROPERTIES_2,
            .pNext = &budget,
        };
        get_properties(device._handle, &memory_properties);
        if (memory_properties.memoryProperties.memoryHeapCount > memory.heap_count_max) {
            return error.InvalidProperties;
        }
        var snapshot: memory.BudgetSnapshot = .{
            ._heaps = undefined,
            .count = memory_properties.memoryProperties.memoryHeapCount,
        };
        for (0..snapshot.count) |index| snapshot._heaps[index] = .{
            .heap_index = .fromRaw(@intCast(index)),
            .budget = .fromBytes(budget.heapBudget[index]),
            .usage = .fromBytes(budget.heapUsage[index]),
        };
        return snapshot;
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
        var surface_capabilities: raw.VkSurfaceCapabilitiesKHR = .{};
        try checkSuccess(get_capabilities(
            device._handle,
            try surface.rawHandle(),
            &surface_capabilities,
        ));
        return .fromRaw(surface_capabilities);
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
        const snapshot = try device.memoryProperties();
        return snapshot.findType(options);
    }

    /// Evaluates logical-device requirements without creating a device or
    /// assigning an application-specific suitability score.
    pub fn evaluateDeviceRequirements(
        physical_device: *const PhysicalDevice,
        requirements: DeviceRequirements,
    ) Error!DeviceEvaluation {
        var extension_count: u32 = 0;
        try checkSuccess(physical_device.dispatch.enumerate_device_extension_properties(
            physical_device._handle,
            null,
            &extension_count,
            null,
        ));
        if (extension_count > device_configuration.extension_count_max) return error.CountOverflow;
        var extension_properties: [device_configuration.extension_count_max]raw.VkExtensionProperties = undefined;
        var extension_written = extension_count;
        const extension_result = physical_device.dispatch.enumerate_device_extension_properties(
            physical_device._handle,
            null,
            &extension_written,
            extension_properties[0..extension_count].ptr,
        );
        if (extension_result == raw.VK_INCOMPLETE) return error.EnumerationUnstable;
        try checkSuccess(extension_result);

        var family_count: u32 = 0;
        physical_device.dispatch.get_physical_device_queue_family_properties(
            physical_device._handle,
            &family_count,
            null,
        );
        if (family_count > device_configuration.queue_count_max) return error.CountOverflow;
        var raw_families: [device_configuration.queue_count_max]raw.VkQueueFamilyProperties = undefined;
        var family_written = family_count;
        physical_device.dispatch.get_physical_device_queue_family_properties(
            physical_device._handle,
            &family_written,
            raw_families[0..family_count].ptr,
        );
        if (family_written > family_count) return error.EnumerationUnstable;
        var families: [device_configuration.queue_count_max]QueueFamily = undefined;
        for (raw_families[0..family_written], 0..) |property, index| {
            families[index] = .{
                .index = .fromRaw(@intCast(index)),
                .flags = .fromRaw(property.queueFlags),
                .queue_count = property.queueCount,
                .timestamp_valid_bits = property.timestampValidBits,
                .minimum_image_transfer_granularity = .fromRaw(property.minImageTransferGranularity),
            };
        }
        return device_configuration.evaluate(requirements, .{
            .api_version = physical_device.properties().api_version,
            .extensions = extension_properties[0..extension_written],
            .features = try physical_device.features(),
            .queue_families = families[0..family_written],
        });
    }

    pub fn createDevice(
        physical_device: *const PhysicalDevice,
        options: DeviceOptions,
    ) Error!Device {
        if (options.enable_portability_subset and platform != .metal) {
            return error.PortabilityNotSupported;
        }
        const evaluation = try physical_device.evaluateDeviceRequirements(options);
        if (!evaluation.supported()) {
            return switch (evaluation.reasons()[0]) {
                .missing_extension, .unsatisfied_extension_dependency, .instance_extension_used_as_device_extension => error.ExtensionNotPresent,
                .missing_feature => error.FeatureNotPresent,
                .missing_queue_family, .insufficient_queue_count, .queue_capability_missing => error.QueueFamilyNotFound,
                .invalid_options => error.InvalidOptions,
            };
        }

        var queue_infos: [device_queue_count_max]raw.VkDeviceQueueCreateInfo = undefined;
        var priority_infos: [device_queue_count_max]raw.VkDeviceQueueGlobalPriorityCreateInfo = undefined;
        for (options.queues, 0..) |queue, index| {
            priority_infos[index] = .{
                .sType = raw.VK_STRUCTURE_TYPE_DEVICE_QUEUE_GLOBAL_PRIORITY_CREATE_INFO,
                .globalPriority = if (queue.global_priority) |priority| priority.toRaw() else raw.VK_QUEUE_GLOBAL_PRIORITY_MEDIUM,
            };
            queue_infos[index] = .{
                .sType = raw.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .pNext = if (queue.global_priority != null) &priority_infos[index] else null,
                .flags = if (queue.protected) @intCast(raw.VK_DEVICE_QUEUE_CREATE_PROTECTED_BIT) else 0,
                .queueFamilyIndex = queue.family_index.toRaw(),
                .queueCount = @intCast(queue.priorities.len),
                .pQueuePriorities = queue.priorities.ptr,
            };
        }

        var extension_pointers: [name_count_max][*c]const u8 = undefined;
        var enabled_extensions: [name_count_max]Extension = undefined;
        var extension_count: usize = 0;
        for (options.extensions) |item| {
            if (extension_count == extension_pointers.len) return error.CountOverflow;
            extension_pointers[extension_count] = item.name.ptr;
            enabled_extensions[extension_count] = item;
            extension_count += 1;
        }
        if (options.enable_portability_subset) {
            const portability_extension = extension.khr_portability_subset;
            var found = false;
            for (options.extensions) |item| {
                if (std.mem.eql(u8, item.name, portability_extension.name)) found = true;
            }
            if (!found) {
                if (extension_count == extension_pointers.len) return error.CountOverflow;
                extension_pointers[extension_count] = portability_extension.name.ptr;
                enabled_extensions[extension_count] = portability_extension;
                extension_count += 1;
            }
        }

        const enabled_core_features = options.features.coreRaw();
        var features_11: raw.VkPhysicalDeviceVulkan11Features = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
            .protectedMemory = bool32(options.features.contains(.protected_memory)),
            .samplerYcbcrConversion = bool32(options.features.contains(.sampler_ycbcr_conversion)),
            .multiview = bool32(options.features.contains(.multiview)),
            .shaderDrawParameters = bool32(options.features.contains(.shader_draw_parameters)),
        };
        var features_12: raw.VkPhysicalDeviceVulkan12Features = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
            .drawIndirectCount = bool32(options.features.contains(.draw_indirect_count)),
            .timelineSemaphore = bool32(options.features.contains(.timeline_semaphore)),
            .bufferDeviceAddress = bool32(options.features.contains(.buffer_device_address)),
            .descriptorIndexing = bool32(options.features.contains(.descriptor_indexing)),
        };
        var features_13: raw.VkPhysicalDeviceVulkan13Features = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
            .synchronization2 = bool32(options.features.contains(.synchronization2)),
            .dynamicRendering = bool32(options.features.contains(.dynamic_rendering)),
            .maintenance4 = bool32(options.features.contains(.maintenance4)),
        };
        var features_14: raw.VkPhysicalDeviceVulkan14Features = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_4_FEATURES,
            .globalPriorityQuery = bool32(options.features.contains(.global_priority_query)),
            .hostImageCopy = bool32(options.features.contains(.host_image_copy)),
            .pushDescriptor = bool32(options.features.contains(.push_descriptor)),
        };
        var feature_root: raw.VkPhysicalDeviceFeatures2 = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
            .features = enabled_core_features,
        };
        const api_version = physical_device.properties().api_version;
        if (api_version.atLeast(.v1_1)) feature_root.pNext = &features_11;
        if (api_version.atLeast(.v1_2)) features_11.pNext = &features_12;
        if (api_version.atLeast(.v1_3)) features_12.pNext = &features_13;
        if (api_version.atLeast(.v1_4)) features_13.pNext = &features_14;

        const create_info: raw.VkDeviceCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = if (options.features.hasPromoted()) &feature_root else null,
            .queueCreateInfoCount = @intCast(options.queues.len),
            .pQueueCreateInfos = queue_infos[0..options.queues.len].ptr,
            .enabledExtensionCount = @intCast(extension_count),
            .ppEnabledExtensionNames = pointerArray(extension_pointers[0..extension_count]),
            .pEnabledFeatures = if (options.features.hasPromoted()) null else &enabled_core_features,
        };
        var device = try physical_device.createDeviceRaw(&create_info, null);
        device.enabled_capabilities = .init(enabled_extensions[0..extension_count], options.features);
        device._max_push_constant_size = physical_device.properties().limits.max_push_constants_size;
        return device;
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
            .enabled_capabilities = .{},
        };
    }
};

pub const QueueCapability = physical_devices.QueueCapability;
pub const QueueFamily = physical_devices.QueueFamily;
pub const QueueFamilySelectionOptions = physical_devices.QueueSelectionOptions;
pub const selectQueueFamily = physical_devices.selectQueueFamily;
pub const selectQueueFamilyForSurface = physical_devices.selectQueueFamilyForSurface;

pub const MemoryTypeOptions = memory.TypeOptions;
pub const MemoryType = memory.Type;
pub const MemoryHeap = memory.Heap;
pub const MemoryProperties = memory.Properties;
pub const MemoryAllocationOptions = memory.AllocationOptions;
pub const MemoryAllocation = memory.Allocation;
pub const MemoryMapOptions = memory.MapOptions;
pub const MappedMemory = memory.MappedRange;
pub const MemoryRequirements = memory.Requirements;
pub const MemoryPreference = memory.Preference;
pub const MemoryHeapBudget = memory.HeapBudget;
pub const MemoryBudgetSnapshot = memory.BudgetSnapshot;
pub const Sampler = samplers.Sampler;
pub const SamplerOptions = samplers.Options;
pub const SamplerFilter = samplers.Filter;
pub const SamplerAddressMode = samplers.AddressMode;
pub const SamplerMipmapMode = samplers.MipmapMode;
pub const SamplerCompareOperation = samplers.CompareOperation;
pub const SamplerReductionMode = samplers.ReductionMode;
pub const SamplerBorderColor = samplers.BorderColor;
pub const SamplerYcbcrConversion = samplers.YcbcrConversion;
pub const SamplerYcbcrOptions = samplers.YcbcrOptions;
pub const ShaderModule = shaders.Module;
pub const ShaderStage = shaders.Stage;
pub const ShaderStageOptions = shaders.StageOptions;
pub const ShaderSpecialization = shaders.Specialization;
pub const ShaderSpecializationEntry = shaders.SpecializationEntry;
pub const ShaderStageSet = shaders.StageSet;
pub const DescriptorType = descriptors.Type;
pub const DescriptorBinding = descriptors.Binding;
pub const DescriptorSetLayout = descriptors.SetLayout;
pub const DescriptorSetLayoutOptions = descriptors.LayoutOptions;
pub const DescriptorPool = descriptors.Pool;
pub const DescriptorPoolOptions = descriptors.PoolOptions;
pub const DescriptorPoolSize = descriptors.PoolSize;
pub const DescriptorSet = descriptors.Set;
pub const PipelineLayout = pipelines.Layout;
pub const PipelineLayoutOptions = pipelines.LayoutOptions;
pub const PushConstantRange = pipelines.PushConstantRange;
pub const Pipeline = pipelines.Pipeline;
pub const PipelineCreateResult = pipelines.CreateResult;
pub const GraphicsPipelineOptions = pipelines.GraphicsOptions;
pub const ComputePipelineOptions = pipelines.ComputeOptions;
pub const PipelineBindPoint = pipelines.BindPoint;
pub const selectMemoryTypeIndex = memory.selectTypeIndex;
pub const selectMemoryTypeIndexRaw = memory.selectTypeIndexRaw;

pub const DeviceQueueOptions = device_configuration.QueueOptions;
pub const DeviceOptions = device_configuration.Requirements;

pub const Device = struct {
    _handle: ?DeviceHandle,
    _instance_handle: InstanceHandle,
    _state: core.DeviceState = .{},
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: DeviceDispatch,
    enabled_capabilities: device_configuration.EnabledCapabilities = .{},
    _max_push_constant_size: u32 = 128,

    pub fn deinit(device: *Device) void {
        const handle = device._handle orelse return;
        device.dispatch.destroy_device(handle, device.allocation_callbacks);
        device._handle = null;
        device._state.markDestroyed();
    }

    /// Returns the live raw handle for explicit FFI integration.
    pub fn rawHandle(device: *const Device) Error!raw.VkDevice {
        return device._handle orelse error.InactiveObject;
    }

    pub fn debugObject(device: *const Device) Error!debug_utils.Object {
        const handle = device._handle orelse return error.InactiveObject;
        return .forDevice(.device, handle, handle);
    }

    /// Returns the monotonic device status shared with child wrappers.
    pub fn status(device: *const Device) core.DeviceState.Status {
        return device._state.status();
    }

    fn dispatchHandle(device: *const Device) Error!DeviceHandle {
        try device._state.ensureDispatchAllowed();
        return device._handle orelse error.InactiveObject;
    }

    pub fn waitIdle(device: *const Device) Error!void {
        const handle = try device.dispatchHandle();
        try core.checkSuccessTracked(@constCast(&device._state), device.dispatch.device_wait_idle(handle));
    }

    pub fn enabledExtensions(device: *const Device) []const [:0]const u8 {
        return device.enabled_capabilities.extensions();
    }

    pub fn supportsExtension(device: *const Device, item: Extension) bool {
        return device.enabled_capabilities.supportsExtension(item);
    }

    pub fn supportsFeature(device: *const Device, feature: DeviceFeature) bool {
        return device.enabled_capabilities.supportsFeature(feature);
    }

    pub fn queue(
        device: *const Device,
        family_index: QueueFamilyIndex,
        queue_index: QueueIndex,
    ) Error!Queue {
        const device_handle = try device.dispatchHandle();
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
            ._device_state = @constCast(&device._state),
            .queue_submit = device.dispatch.queue_submit,
            .queue_submit2 = device.dispatch.queue_submit2,
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
        const handle = device._handle orelse return error.InactiveObject;
        return loadDeviceDescriptor(
            device.dispatch.get_device_proc_addr,
            handle,
            descriptor,
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
        object: anytype,
        name: [:0]const u8,
    ) Error!void {
        const device_handle = device._handle orelse return error.InactiveObject;
        const set_name = device.dispatch.set_debug_utils_object_name_ext orelse {
            return error.MissingCommand;
        };
        const object_info = try object.debugObject();
        try object_info.validateParent(device_handle, device._instance_handle);
        const name_info: raw.VkDebugUtilsObjectNameInfoEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT,
            .objectType = object_info.object_type.toRaw(),
            .objectHandle = object_info.handle,
            .pObjectName = name.ptr,
        };
        try checkSuccess(set_name(device_handle, &name_info));
    }

    pub fn createBuffer(
        device: *const Device,
        options: buffers.Options,
    ) Error!buffers.Buffer {
        const device_handle = device._handle orelse return error.InactiveObject;
        return buffers.create(
            device_handle,
            device.allocation_callbacks,
            .{
                .create_buffer = device.dispatch.create_buffer,
                .destroy_buffer = device.dispatch.destroy_buffer,
                .get_buffer_memory_requirements = device.dispatch.get_buffer_memory_requirements,
                .get_buffer_memory_requirements2 = device.dispatch.get_buffer_memory_requirements2,
                .get_buffer_device_address = device.dispatch.get_buffer_device_address,
                .get_buffer_opaque_capture_address = device.dispatch.get_buffer_opaque_capture_address,
                .create_buffer_view = device.dispatch.create_buffer_view,
                .destroy_buffer_view = device.dispatch.destroy_buffer_view,
                .bind_buffer_memory = device.dispatch.bind_buffer_memory,
                .bind_buffer_memory2 = device.dispatch.bind_buffer_memory2,
            },
            options,
        );
    }

    pub fn createBufferView(
        device: *const Device,
        buffer: *const buffers.Buffer,
        options: buffers.ViewOptions,
    ) Error!buffers.View {
        const device_handle = device._handle orelse return error.InactiveObject;
        if (buffer._device_handle != device_handle) return error.InvalidHandle;
        return buffers.createView(buffer, options);
    }

    pub fn allocateMemory(
        device: *const Device,
        options: memory.AllocationOptions,
    ) Error!memory.Allocation {
        const device_handle = device._handle orelse return error.InactiveObject;
        return memory.allocate(
            device_handle,
            device.allocation_callbacks,
            .{
                .allocate = device.dispatch.allocate_memory,
                .free = device.dispatch.free_memory,
                .map = device.dispatch.map_memory,
                .unmap = device.dispatch.unmap_memory,
                .map2 = device.dispatch.map_memory2,
                .unmap2 = device.dispatch.unmap_memory2,
                .flush = device.dispatch.flush_mapped_memory_ranges,
                .invalidate = device.dispatch.invalidate_mapped_memory_ranges,
                .get_commitment = device.dispatch.get_device_memory_commitment,
                .get_opaque_capture_address = device.dispatch.get_device_memory_opaque_capture_address,
            },
            options,
        );
    }

    pub fn createSampler(device: *const Device, options: samplers.Options) Error!samplers.Sampler {
        const device_handle = try device.dispatchHandle();
        return samplers.create(device_handle, device.allocation_callbacks, .{
            .create = device.dispatch.create_sampler,
            .destroy = device.dispatch.destroy_sampler,
        }, options);
    }

    pub fn createSamplerYcbcrConversion(
        device: *const Device,
        options: samplers.YcbcrOptions,
    ) Error!samplers.YcbcrConversion {
        const device_handle = try device.dispatchHandle();
        const create_conversion = device.dispatch.create_sampler_ycbcr_conversion orelse return error.MissingCommand;
        const destroy_conversion = device.dispatch.destroy_sampler_ycbcr_conversion orelse return error.MissingCommand;
        return samplers.createYcbcrConversion(device_handle, device.allocation_callbacks, .{
            .create = create_conversion,
            .destroy = destroy_conversion,
        }, options);
    }

    pub fn createShaderModule(
        device: *const Device,
        words: []const u32,
    ) Error!shaders.Module {
        const device_handle = try device.dispatchHandle();
        return shaders.createWords(device_handle, device.allocation_callbacks, .{
            .create = device.dispatch.create_shader_module,
            .destroy = device.dispatch.destroy_shader_module,
            .get_identifier = device.dispatch.get_shader_module_identifier_ext,
        }, words);
    }

    pub fn createShaderModuleBytes(
        device: *const Device,
        bytes: []align(4) const u8,
    ) Error!shaders.Module {
        const device_handle = try device.dispatchHandle();
        return shaders.createBytes(device_handle, device.allocation_callbacks, .{
            .create = device.dispatch.create_shader_module,
            .destroy = device.dispatch.destroy_shader_module,
            .get_identifier = device.dispatch.get_shader_module_identifier_ext,
        }, bytes);
    }

    pub fn createDescriptorSetLayout(
        device: *const Device,
        options: descriptors.LayoutOptions,
    ) Error!descriptors.SetLayout {
        const device_handle = try device.dispatchHandle();
        return descriptors.createLayout(device_handle, device.allocation_callbacks, .{
            .create = device.dispatch.create_descriptor_set_layout,
            .destroy = device.dispatch.destroy_descriptor_set_layout,
        }, options);
    }

    pub fn createDescriptorPool(
        device: *const Device,
        options: descriptors.PoolOptions,
    ) Error!descriptors.Pool {
        const device_handle = try device.dispatchHandle();
        return descriptors.createPool(device_handle, device.allocation_callbacks, .{
            .create = device.dispatch.create_descriptor_pool,
            .destroy = device.dispatch.destroy_descriptor_pool,
            .reset = device.dispatch.reset_descriptor_pool,
            .allocate = device.dispatch.allocate_descriptor_sets,
            .free = device.dispatch.free_descriptor_sets,
        }, options);
    }

    pub fn createPipelineLayout(
        device: *const Device,
        options: pipelines.LayoutOptions,
    ) Error!pipelines.Layout {
        const device_handle = try device.dispatchHandle();
        return pipelines.createLayout(device_handle, device.allocation_callbacks, .{
            .create = device.dispatch.create_pipeline_layout,
            .destroy = device.dispatch.destroy_pipeline_layout,
        }, device._max_push_constant_size, options);
    }

    pub fn createGraphicsPipeline(
        device: *const Device,
        options: pipelines.GraphicsOptions,
    ) Error!pipelines.CreateResult {
        const device_handle = try device.dispatchHandle();
        return pipelines.createGraphics(device_handle, device.allocation_callbacks, .{
            .create_graphics = device.dispatch.create_graphics_pipelines,
            .create_compute = device.dispatch.create_compute_pipelines,
            .destroy = device.dispatch.destroy_pipeline,
        }, options);
    }

    pub fn createComputePipeline(
        device: *const Device,
        options: pipelines.ComputeOptions,
    ) Error!pipelines.CreateResult {
        const device_handle = try device.dispatchHandle();
        return pipelines.createCompute(device_handle, device.allocation_callbacks, .{
            .create_graphics = device.dispatch.create_graphics_pipelines,
            .create_compute = device.dispatch.create_compute_pipelines,
            .destroy = device.dispatch.destroy_pipeline,
        }, options);
    }

    pub fn createAllocatedBuffer(
        device: *const Device,
        options: buffers.AllocatedOptions,
    ) Error!buffers.Allocated {
        var buffer = try device.createBuffer(options.buffer);
        errdefer buffer.deinit();
        const requirements = try buffer.memoryRequirements();
        var allocation = try device.allocateMemory(.{
            .size = requirements.size,
            .memory_type_index = options.memory.memory_type_index,
            .device_address = options.memory.device_address,
            .opaque_capture_address = options.memory.opaque_capture_address,
        });
        errdefer allocation.deinit();
        try buffer.bindMemory(&allocation, .zero);
        return .{ .buffer = buffer, .memory = allocation };
    }

    pub fn createAllocatedBufferForProperties(
        device: *const Device,
        options: buffers.AutoAllocatedOptions,
    ) Error!buffers.Allocated {
        var buffer = try device.createBuffer(options.buffer);
        errdefer buffer.deinit();
        const requirements = try buffer.memoryRequirements();
        const memory_type_index = try options.memory_properties.findType(.{
            .type_bits = requirements.memory_type_bits,
            .required_flags = options.required_memory_flags,
            .preferred_flags = options.preferred_memory_flags,
        });
        var allocation = try device.allocateMemory(.{
            .size = requirements.size,
            .memory_type_index = memory_type_index,
            .device_address = options.device_address,
            .opaque_capture_address = options.opaque_capture_address,
        });
        errdefer allocation.deinit();
        try buffer.bindMemory(&allocation, .zero);
        return .{ .buffer = buffer, .memory = allocation };
    }

    pub fn createImageView(
        device: *const Device,
        options: ImageViewOptions,
    ) Error!ImageView {
        const device_handle = device._handle orelse return error.InactiveObject;
        return images.createView(
            device_handle,
            device.allocation_callbacks,
            device.dispatch.create_image_view,
            device.dispatch.destroy_image_view,
            options,
        );
    }

    pub fn createImage(device: *const Device, options: images.Options) Error!images.Image {
        const device_handle = try device.dispatchHandle();
        return images.create(device_handle, device.allocation_callbacks, .{
            .create_image = device.dispatch.create_image,
            .destroy_image = device.dispatch.destroy_image,
            .get_image_memory_requirements = device.dispatch.get_image_memory_requirements,
            .get_image_memory_requirements2 = device.dispatch.get_image_memory_requirements2,
            .bind_image_memory = device.dispatch.bind_image_memory,
            .bind_image_memory2 = device.dispatch.bind_image_memory2,
        }, options);
    }

    pub fn createSemaphore(
        device: *const Device,
        options: SemaphoreOptions,
    ) Error!Semaphore {
        const device_handle = device._handle orelse return error.InactiveObject;
        if (options.kind == .binary and options.initial_value != 0) {
            return error.InvalidOptions;
        }
        var type_create_info: raw.VkSemaphoreTypeCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_SEMAPHORE_TYPE_CREATE_INFO,
            .semaphoreType = switch (options.kind) {
                .binary => raw.VK_SEMAPHORE_TYPE_BINARY,
                .timeline => raw.VK_SEMAPHORE_TYPE_TIMELINE,
            },
            .initialValue = options.initial_value,
        };
        const create_info: raw.VkSemaphoreCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            .pNext = if (options.kind == .timeline) &type_create_info else null,
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
            .kind = options.kind,
            .allocation_callbacks = device.allocation_callbacks,
            .destroy_semaphore = device.dispatch.destroy_semaphore,
            .get_counter_value = device.dispatch.get_semaphore_counter_value,
            .wait_semaphores = device.dispatch.wait_semaphores,
            .signal_semaphore = device.dispatch.signal_semaphore,
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
            .get_fence_status = device.dispatch.get_fence_status,
            .reset_fences = device.dispatch.reset_fences,
            .wait_for_fences = device.dispatch.wait_for_fences,
        };
    }

    pub fn createEvent(device: *const Device) Error!sync.Event {
        const device_handle = try device.dispatchHandle();
        return sync.createEvent(device_handle, device.allocation_callbacks, .{
            .create = device.dispatch.create_event,
            .destroy = device.dispatch.destroy_event,
            .status = device.dispatch.get_event_status,
            .set = device.dispatch.set_event,
            .reset = device.dispatch.reset_event,
        });
    }

    pub fn resetFences(device: *const Device, fences: []const *const Fence) Error!void {
        const device_handle = device._handle orelse return error.InactiveObject;
        if (fences.len == 0) return;
        if (fences.len > submission_item_count_max) return error.CountOverflow;
        var handles: [submission_item_count_max]raw.VkFence = undefined;
        for (fences, handles[0..fences.len]) |fence, *handle| {
            if (fence._device_handle != device_handle) return error.InvalidHandle;
            handle.* = try fence.rawHandle();
        }
        try checkSuccess(device.dispatch.reset_fences(
            device_handle,
            @intCast(fences.len),
            handles[0..fences.len].ptr,
        ));
    }

    pub fn waitFences(
        device: *const Device,
        fences: []const *const Fence,
        mode: WaitMode,
        timeout: Timeout,
    ) Error!FenceWaitStatus {
        const device_handle = device._handle orelse return error.InactiveObject;
        if (fences.len == 0) return .success;
        if (fences.len > submission_item_count_max) return error.CountOverflow;
        var handles: [submission_item_count_max]raw.VkFence = undefined;
        for (fences, handles[0..fences.len]) |fence, *handle| {
            if (fence._device_handle != device_handle) return error.InvalidHandle;
            handle.* = try fence.rawHandle();
        }
        const result = device.dispatch.wait_for_fences(
            device_handle,
            @intCast(fences.len),
            handles[0..fences.len].ptr,
            if (mode == .all) raw.VK_TRUE else raw.VK_FALSE,
            timeout.toRaw(),
        );
        if (result == raw.VK_SUCCESS) return .success;
        if (result == raw.VK_TIMEOUT) return .timeout;
        try checkSuccess(result);
        unreachable;
    }

    pub fn waitTimelineSemaphores(
        device: *const Device,
        waits: []const TimelineSemaphoreWait,
        mode: WaitMode,
        timeout: Timeout,
    ) Error!TimelineWaitStatus {
        const device_handle = device._handle orelse return error.InactiveObject;
        if (waits.len == 0) return .success;
        if (waits.len > submission_item_count_max) return error.CountOverflow;
        const wait_semaphores = device.dispatch.wait_semaphores orelse {
            return error.MissingCommand;
        };
        var handles: [submission_item_count_max]raw.VkSemaphore = undefined;
        var values: [submission_item_count_max]u64 = undefined;
        for (waits, handles[0..waits.len], values[0..waits.len]) |wait, *handle, *value| {
            if (wait.semaphore._device_handle != device_handle) return error.InvalidHandle;
            if (wait.semaphore.kind != .timeline) return error.InvalidOptions;
            handle.* = try wait.semaphore.rawHandle();
            value.* = wait.value;
        }
        const wait_info: raw.VkSemaphoreWaitInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_SEMAPHORE_WAIT_INFO,
            .flags = if (mode == .any) raw.VK_SEMAPHORE_WAIT_ANY_BIT else 0,
            .semaphoreCount = @intCast(waits.len),
            .pSemaphores = handles[0..waits.len].ptr,
            .pValues = values[0..waits.len].ptr,
        };
        const result = wait_semaphores(device_handle, &wait_info, timeout.toRaw());
        if (result == raw.VK_SUCCESS) return .success;
        if (result == raw.VK_TIMEOUT) return .timeout;
        try checkSuccess(result);
        unreachable;
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
            .free_command_buffers = device.dispatch.free_command_buffers,
            .reset_command_pool = device.dispatch.reset_command_pool,
            .begin_command_buffer = device.dispatch.begin_command_buffer,
            .end_command_buffer = device.dispatch.end_command_buffer,
            .reset_command_buffer = device.dispatch.reset_command_buffer,
            .cmd_pipeline_barrier = device.dispatch.cmd_pipeline_barrier,
            .cmd_pipeline_barrier2 = device.dispatch.cmd_pipeline_barrier2,
            .cmd_set_event2 = device.dispatch.cmd_set_event2,
            .cmd_reset_event2 = device.dispatch.cmd_reset_event2,
            .cmd_wait_events2 = device.dispatch.cmd_wait_events2,
            .cmd_begin_rendering = device.dispatch.cmd_begin_rendering,
            .cmd_end_rendering = device.dispatch.cmd_end_rendering,
            .cmd_clear_color_image = device.dispatch.cmd_clear_color_image,
            .cmd_clear_depth_stencil_image = device.dispatch.cmd_clear_depth_stencil_image,
            .cmd_fill_buffer = device.dispatch.cmd_fill_buffer,
            .cmd_update_buffer = device.dispatch.cmd_update_buffer,
            .cmd_copy_buffer = device.dispatch.cmd_copy_buffer,
            .cmd_copy_buffer2 = device.dispatch.cmd_copy_buffer2,
            .cmd_copy_buffer_to_image = device.dispatch.cmd_copy_buffer_to_image,
            .cmd_copy_image_to_buffer = device.dispatch.cmd_copy_image_to_buffer,
            .cmd_copy_image = device.dispatch.cmd_copy_image,
            .cmd_blit_image = device.dispatch.cmd_blit_image,
            .cmd_resolve_image = device.dispatch.cmd_resolve_image,
            .cmd_bind_pipeline = device.dispatch.cmd_bind_pipeline,
            .cmd_bind_descriptor_sets = device.dispatch.cmd_bind_descriptor_sets,
            .cmd_bind_vertex_buffers = device.dispatch.cmd_bind_vertex_buffers,
            .cmd_bind_index_buffer = device.dispatch.cmd_bind_index_buffer,
            .cmd_set_viewport = device.dispatch.cmd_set_viewport,
            .cmd_set_scissor = device.dispatch.cmd_set_scissor,
            .cmd_set_line_width = device.dispatch.cmd_set_line_width,
            .cmd_set_depth_bias = device.dispatch.cmd_set_depth_bias,
            .cmd_set_blend_constants = device.dispatch.cmd_set_blend_constants,
            .cmd_set_depth_bounds = device.dispatch.cmd_set_depth_bounds,
            .cmd_push_constants = device.dispatch.cmd_push_constants,
            .cmd_draw = device.dispatch.cmd_draw,
            .cmd_draw_indexed = device.dispatch.cmd_draw_indexed,
            .cmd_draw_indirect = device.dispatch.cmd_draw_indirect,
            .cmd_draw_indexed_indirect = device.dispatch.cmd_draw_indexed_indirect,
            .cmd_draw_indirect_count = device.dispatch.cmd_draw_indirect_count,
            .cmd_draw_indexed_indirect_count = device.dispatch.cmd_draw_indexed_indirect_count,
            .cmd_dispatch = device.dispatch.cmd_dispatch,
            .cmd_dispatch_indirect = device.dispatch.cmd_dispatch_indirect,
            .cmd_dispatch_base = device.dispatch.cmd_dispatch_base,
            .cmd_execute_commands = device.dispatch.cmd_execute_commands,
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
        try options.validate(device_handle, device._instance_handle);
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
        options: debug_utils.LabelOptions,
    ) Error!void {
        _ = device._handle orelse return error.InactiveObject;
        const begin_label = device.dispatch.cmd_begin_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        const live_command_buffer = command_buffer orelse return error.InvalidHandle;
        const label = options.toRaw();
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
        options: debug_utils.LabelOptions,
    ) Error!void {
        _ = device._handle orelse return error.InactiveObject;
        const insert_label = device.dispatch.cmd_insert_debug_utils_label_ext orelse {
            return error.MissingCommand;
        };
        const live_command_buffer = command_buffer orelse return error.InvalidHandle;
        const label = options.toRaw();
        insert_label(live_command_buffer, &label);
    }
};

pub const SemaphoreWait = queues.SemaphoreWait;
pub const SubmitOptions = queues.SubmitOptions;
pub const SemaphoreSubmit = queues.SemaphoreSubmit;
pub const CommandBufferSubmit = queues.CommandBufferSubmit;
pub const Submit2Options = queues.Submit2Options;
pub const Submit2BatchOptions = queues.Submit2BatchOptions;
pub const QueueLabelScope = queues.LabelScope;
pub const Queue = queues.Queue;

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
    get_physical_device_format_properties2: ?CommandFunction(
        raw.PFN_vkGetPhysicalDeviceFormatProperties2,
    ),
    get_physical_device_image_format_properties2: ?CommandFunction(
        raw.PFN_vkGetPhysicalDeviceImageFormatProperties2,
    ),
    get_physical_device_sparse_image_format_properties2: ?CommandFunction(
        raw.PFN_vkGetPhysicalDeviceSparseImageFormatProperties2,
    ),
    get_physical_device_features: CommandFunction(raw.PFN_vkGetPhysicalDeviceFeatures),
    get_physical_device_features2: ?CommandFunction(raw.PFN_vkGetPhysicalDeviceFeatures2),
    get_physical_device_memory_properties: CommandFunction(
        raw.PFN_vkGetPhysicalDeviceMemoryProperties,
    ),
    get_physical_device_memory_properties2: ?CommandFunction(
        raw.PFN_vkGetPhysicalDeviceMemoryProperties2,
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
            .get_physical_device_format_properties2 = loadInstanceDescriptor(
                get_instance_proc_addr,
                handle,
                command.get_physical_device_format_properties2,
                .instance,
            ),
            .get_physical_device_image_format_properties2 = loadInstanceDescriptor(
                get_instance_proc_addr,
                handle,
                command.get_physical_device_image_format_properties2,
                .instance,
            ),
            .get_physical_device_sparse_image_format_properties2 = loadInstanceDescriptor(
                get_instance_proc_addr,
                handle,
                command.get_physical_device_sparse_image_format_properties2,
                .instance,
            ),
            .get_physical_device_features = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceFeatures,
                "vkGetPhysicalDeviceFeatures",
            ),
            .get_physical_device_features2 = loadInstanceDescriptor(
                get_instance_proc_addr,
                handle,
                command.get_physical_device_features2,
                .instance,
            ),
            .get_physical_device_memory_properties = try loadInstanceRequired(
                get_instance_proc_addr,
                handle,
                raw.PFN_vkGetPhysicalDeviceMemoryProperties,
                "vkGetPhysicalDeviceMemoryProperties",
            ),
            .get_physical_device_memory_properties2 = loadInstanceDescriptor(
                get_instance_proc_addr,
                handle,
                command.get_physical_device_memory_properties2,
                .instance,
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
    queue_submit2: ?CommandFunction(raw.PFN_vkQueueSubmit2),
    queue_wait_idle: CommandFunction(raw.PFN_vkQueueWaitIdle),
    device_wait_idle: CommandFunction(raw.PFN_vkDeviceWaitIdle),
    allocate_memory: CommandFunction(raw.PFN_vkAllocateMemory),
    free_memory: CommandFunction(raw.PFN_vkFreeMemory),
    map_memory: CommandFunction(raw.PFN_vkMapMemory),
    unmap_memory: CommandFunction(raw.PFN_vkUnmapMemory),
    map_memory2: ?CommandFunction(raw.PFN_vkMapMemory2),
    unmap_memory2: ?CommandFunction(raw.PFN_vkUnmapMemory2),
    flush_mapped_memory_ranges: CommandFunction(raw.PFN_vkFlushMappedMemoryRanges),
    invalidate_mapped_memory_ranges: CommandFunction(raw.PFN_vkInvalidateMappedMemoryRanges),
    get_device_memory_commitment: CommandFunction(raw.PFN_vkGetDeviceMemoryCommitment),
    get_device_memory_opaque_capture_address: ?CommandFunction(
        raw.PFN_vkGetDeviceMemoryOpaqueCaptureAddress,
    ),
    create_sampler: CommandFunction(raw.PFN_vkCreateSampler),
    destroy_sampler: CommandFunction(raw.PFN_vkDestroySampler),
    create_sampler_ycbcr_conversion: ?CommandFunction(raw.PFN_vkCreateSamplerYcbcrConversion),
    destroy_sampler_ycbcr_conversion: ?CommandFunction(raw.PFN_vkDestroySamplerYcbcrConversion),
    create_shader_module: CommandFunction(raw.PFN_vkCreateShaderModule),
    destroy_shader_module: CommandFunction(raw.PFN_vkDestroyShaderModule),
    get_shader_module_identifier_ext: ?CommandFunction(raw.PFN_vkGetShaderModuleIdentifierEXT),
    create_descriptor_set_layout: CommandFunction(raw.PFN_vkCreateDescriptorSetLayout),
    destroy_descriptor_set_layout: CommandFunction(raw.PFN_vkDestroyDescriptorSetLayout),
    create_descriptor_pool: CommandFunction(raw.PFN_vkCreateDescriptorPool),
    destroy_descriptor_pool: CommandFunction(raw.PFN_vkDestroyDescriptorPool),
    reset_descriptor_pool: CommandFunction(raw.PFN_vkResetDescriptorPool),
    allocate_descriptor_sets: CommandFunction(raw.PFN_vkAllocateDescriptorSets),
    free_descriptor_sets: CommandFunction(raw.PFN_vkFreeDescriptorSets),
    create_pipeline_layout: CommandFunction(raw.PFN_vkCreatePipelineLayout),
    destroy_pipeline_layout: CommandFunction(raw.PFN_vkDestroyPipelineLayout),
    create_graphics_pipelines: CommandFunction(raw.PFN_vkCreateGraphicsPipelines),
    create_compute_pipelines: CommandFunction(raw.PFN_vkCreateComputePipelines),
    destroy_pipeline: CommandFunction(raw.PFN_vkDestroyPipeline),
    create_buffer: CommandFunction(raw.PFN_vkCreateBuffer),
    destroy_buffer: CommandFunction(raw.PFN_vkDestroyBuffer),
    get_buffer_memory_requirements: CommandFunction(raw.PFN_vkGetBufferMemoryRequirements),
    get_buffer_memory_requirements2: ?CommandFunction(raw.PFN_vkGetBufferMemoryRequirements2),
    get_buffer_device_address: ?CommandFunction(raw.PFN_vkGetBufferDeviceAddress),
    get_buffer_opaque_capture_address: ?CommandFunction(raw.PFN_vkGetBufferOpaqueCaptureAddress),
    create_buffer_view: CommandFunction(raw.PFN_vkCreateBufferView),
    destroy_buffer_view: CommandFunction(raw.PFN_vkDestroyBufferView),
    bind_buffer_memory: CommandFunction(raw.PFN_vkBindBufferMemory),
    bind_buffer_memory2: ?CommandFunction(raw.PFN_vkBindBufferMemory2),
    create_image: CommandFunction(raw.PFN_vkCreateImage),
    destroy_image: CommandFunction(raw.PFN_vkDestroyImage),
    get_image_memory_requirements: CommandFunction(raw.PFN_vkGetImageMemoryRequirements),
    get_image_memory_requirements2: ?CommandFunction(raw.PFN_vkGetImageMemoryRequirements2),
    bind_image_memory: CommandFunction(raw.PFN_vkBindImageMemory),
    bind_image_memory2: ?CommandFunction(raw.PFN_vkBindImageMemory2),
    create_image_view: CommandFunction(raw.PFN_vkCreateImageView),
    destroy_image_view: CommandFunction(raw.PFN_vkDestroyImageView),
    create_semaphore: CommandFunction(raw.PFN_vkCreateSemaphore),
    destroy_semaphore: CommandFunction(raw.PFN_vkDestroySemaphore),
    get_semaphore_counter_value: ?CommandFunction(raw.PFN_vkGetSemaphoreCounterValue),
    wait_semaphores: ?CommandFunction(raw.PFN_vkWaitSemaphores),
    signal_semaphore: ?CommandFunction(raw.PFN_vkSignalSemaphore),
    create_fence: CommandFunction(raw.PFN_vkCreateFence),
    destroy_fence: CommandFunction(raw.PFN_vkDestroyFence),
    get_fence_status: CommandFunction(raw.PFN_vkGetFenceStatus),
    reset_fences: CommandFunction(raw.PFN_vkResetFences),
    wait_for_fences: CommandFunction(raw.PFN_vkWaitForFences),
    create_event: CommandFunction(raw.PFN_vkCreateEvent),
    destroy_event: CommandFunction(raw.PFN_vkDestroyEvent),
    get_event_status: CommandFunction(raw.PFN_vkGetEventStatus),
    set_event: CommandFunction(raw.PFN_vkSetEvent),
    reset_event: CommandFunction(raw.PFN_vkResetEvent),
    create_command_pool: CommandFunction(raw.PFN_vkCreateCommandPool),
    destroy_command_pool: CommandFunction(raw.PFN_vkDestroyCommandPool),
    allocate_command_buffers: CommandFunction(raw.PFN_vkAllocateCommandBuffers),
    free_command_buffers: CommandFunction(raw.PFN_vkFreeCommandBuffers),
    reset_command_pool: CommandFunction(raw.PFN_vkResetCommandPool),
    begin_command_buffer: CommandFunction(raw.PFN_vkBeginCommandBuffer),
    end_command_buffer: CommandFunction(raw.PFN_vkEndCommandBuffer),
    reset_command_buffer: CommandFunction(raw.PFN_vkResetCommandBuffer),
    cmd_pipeline_barrier: CommandFunction(raw.PFN_vkCmdPipelineBarrier),
    cmd_pipeline_barrier2: ?CommandFunction(raw.PFN_vkCmdPipelineBarrier2),
    cmd_set_event2: ?CommandFunction(raw.PFN_vkCmdSetEvent2),
    cmd_reset_event2: ?CommandFunction(raw.PFN_vkCmdResetEvent2),
    cmd_wait_events2: ?CommandFunction(raw.PFN_vkCmdWaitEvents2),
    cmd_begin_rendering: ?CommandFunction(raw.PFN_vkCmdBeginRendering),
    cmd_end_rendering: ?CommandFunction(raw.PFN_vkCmdEndRendering),
    cmd_clear_color_image: CommandFunction(raw.PFN_vkCmdClearColorImage),
    cmd_clear_depth_stencil_image: CommandFunction(raw.PFN_vkCmdClearDepthStencilImage),
    cmd_fill_buffer: CommandFunction(raw.PFN_vkCmdFillBuffer),
    cmd_update_buffer: CommandFunction(raw.PFN_vkCmdUpdateBuffer),
    cmd_copy_buffer: CommandFunction(raw.PFN_vkCmdCopyBuffer),
    cmd_copy_buffer2: ?CommandFunction(raw.PFN_vkCmdCopyBuffer2),
    cmd_copy_buffer_to_image: CommandFunction(raw.PFN_vkCmdCopyBufferToImage),
    cmd_copy_image_to_buffer: CommandFunction(raw.PFN_vkCmdCopyImageToBuffer),
    cmd_copy_image: CommandFunction(raw.PFN_vkCmdCopyImage),
    cmd_blit_image: CommandFunction(raw.PFN_vkCmdBlitImage),
    cmd_resolve_image: CommandFunction(raw.PFN_vkCmdResolveImage),
    cmd_bind_pipeline: CommandFunction(raw.PFN_vkCmdBindPipeline),
    cmd_bind_descriptor_sets: CommandFunction(raw.PFN_vkCmdBindDescriptorSets),
    cmd_bind_vertex_buffers: CommandFunction(raw.PFN_vkCmdBindVertexBuffers),
    cmd_bind_index_buffer: CommandFunction(raw.PFN_vkCmdBindIndexBuffer),
    cmd_set_viewport: CommandFunction(raw.PFN_vkCmdSetViewport),
    cmd_set_scissor: CommandFunction(raw.PFN_vkCmdSetScissor),
    cmd_set_line_width: CommandFunction(raw.PFN_vkCmdSetLineWidth),
    cmd_set_depth_bias: CommandFunction(raw.PFN_vkCmdSetDepthBias),
    cmd_set_blend_constants: CommandFunction(raw.PFN_vkCmdSetBlendConstants),
    cmd_set_depth_bounds: CommandFunction(raw.PFN_vkCmdSetDepthBounds),
    cmd_push_constants: CommandFunction(raw.PFN_vkCmdPushConstants),
    cmd_draw: CommandFunction(raw.PFN_vkCmdDraw),
    cmd_draw_indexed: CommandFunction(raw.PFN_vkCmdDrawIndexed),
    cmd_draw_indirect: CommandFunction(raw.PFN_vkCmdDrawIndirect),
    cmd_draw_indexed_indirect: CommandFunction(raw.PFN_vkCmdDrawIndexedIndirect),
    cmd_draw_indirect_count: ?CommandFunction(raw.PFN_vkCmdDrawIndirectCount),
    cmd_draw_indexed_indirect_count: ?CommandFunction(raw.PFN_vkCmdDrawIndexedIndirectCount),
    cmd_dispatch: CommandFunction(raw.PFN_vkCmdDispatch),
    cmd_dispatch_indirect: CommandFunction(raw.PFN_vkCmdDispatchIndirect),
    cmd_dispatch_base: ?CommandFunction(raw.PFN_vkCmdDispatchBase),
    cmd_execute_commands: CommandFunction(raw.PFN_vkCmdExecuteCommands),
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
            .queue_submit2 = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.queue_submit2,
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
            .allocate_memory = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkAllocateMemory,
                "vkAllocateMemory",
            ),
            .free_memory = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkFreeMemory,
                "vkFreeMemory",
            ),
            .map_memory = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkMapMemory,
                "vkMapMemory",
            ),
            .unmap_memory = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkUnmapMemory,
                "vkUnmapMemory",
            ),
            .map_memory2 = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.map_memory2,
            ),
            .unmap_memory2 = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.unmap_memory2,
            ),
            .flush_mapped_memory_ranges = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkFlushMappedMemoryRanges,
                "vkFlushMappedMemoryRanges",
            ),
            .invalidate_mapped_memory_ranges = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkInvalidateMappedMemoryRanges,
                "vkInvalidateMappedMemoryRanges",
            ),
            .get_device_memory_commitment = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkGetDeviceMemoryCommitment,
                "vkGetDeviceMemoryCommitment",
            ),
            .create_sampler = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateSampler,
                "vkCreateSampler",
            ),
            .destroy_sampler = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroySampler,
                "vkDestroySampler",
            ),
            .create_sampler_ycbcr_conversion = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.create_sampler_ycbcr_conversion,
            ),
            .destroy_sampler_ycbcr_conversion = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.destroy_sampler_ycbcr_conversion,
            ),
            .create_shader_module = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateShaderModule,
                "vkCreateShaderModule",
            ),
            .destroy_shader_module = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyShaderModule,
                "vkDestroyShaderModule",
            ),
            .get_shader_module_identifier_ext = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.get_shader_module_identifier_ext,
            ),
            .create_descriptor_set_layout = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateDescriptorSetLayout,
                "vkCreateDescriptorSetLayout",
            ),
            .destroy_descriptor_set_layout = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyDescriptorSetLayout,
                "vkDestroyDescriptorSetLayout",
            ),
            .create_descriptor_pool = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateDescriptorPool,
                "vkCreateDescriptorPool",
            ),
            .destroy_descriptor_pool = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyDescriptorPool,
                "vkDestroyDescriptorPool",
            ),
            .reset_descriptor_pool = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkResetDescriptorPool,
                "vkResetDescriptorPool",
            ),
            .allocate_descriptor_sets = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkAllocateDescriptorSets,
                "vkAllocateDescriptorSets",
            ),
            .free_descriptor_sets = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkFreeDescriptorSets,
                "vkFreeDescriptorSets",
            ),
            .create_pipeline_layout = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreatePipelineLayout,
                "vkCreatePipelineLayout",
            ),
            .destroy_pipeline_layout = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyPipelineLayout,
                "vkDestroyPipelineLayout",
            ),
            .create_graphics_pipelines = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateGraphicsPipelines,
                "vkCreateGraphicsPipelines",
            ),
            .create_compute_pipelines = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateComputePipelines,
                "vkCreateComputePipelines",
            ),
            .destroy_pipeline = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyPipeline,
                "vkDestroyPipeline",
            ),
            .get_device_memory_opaque_capture_address = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.get_device_memory_opaque_capture_address,
            ),
            .create_buffer = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateBuffer,
                "vkCreateBuffer",
            ),
            .destroy_buffer = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyBuffer,
                "vkDestroyBuffer",
            ),
            .get_buffer_memory_requirements = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkGetBufferMemoryRequirements,
                "vkGetBufferMemoryRequirements",
            ),
            .get_buffer_memory_requirements2 = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.get_buffer_memory_requirements2,
            ),
            .get_buffer_device_address = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.get_buffer_device_address,
            ),
            .get_buffer_opaque_capture_address = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.get_buffer_opaque_capture_address,
            ),
            .create_buffer_view = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateBufferView,
                "vkCreateBufferView",
            ),
            .destroy_buffer_view = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyBufferView,
                "vkDestroyBufferView",
            ),
            .bind_buffer_memory = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkBindBufferMemory,
                "vkBindBufferMemory",
            ),
            .bind_buffer_memory2 = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.bind_buffer_memory2,
            ),
            .create_image = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateImage,
                "vkCreateImage",
            ),
            .destroy_image = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyImage,
                "vkDestroyImage",
            ),
            .get_image_memory_requirements = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkGetImageMemoryRequirements,
                "vkGetImageMemoryRequirements",
            ),
            .get_image_memory_requirements2 = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.get_image_memory_requirements2,
            ),
            .bind_image_memory = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkBindImageMemory,
                "vkBindImageMemory",
            ),
            .bind_image_memory2 = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.bind_image_memory2,
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
            .get_semaphore_counter_value = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.get_semaphore_counter_value,
            ),
            .wait_semaphores = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.wait_semaphores,
            ),
            .signal_semaphore = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.signal_semaphore,
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
            .get_fence_status = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkGetFenceStatus,
                "vkGetFenceStatus",
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
            .create_event = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCreateEvent,
                "vkCreateEvent",
            ),
            .destroy_event = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkDestroyEvent,
                "vkDestroyEvent",
            ),
            .get_event_status = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkGetEventStatus,
                "vkGetEventStatus",
            ),
            .set_event = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkSetEvent,
                "vkSetEvent",
            ),
            .reset_event = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkResetEvent,
                "vkResetEvent",
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
            .free_command_buffers = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkFreeCommandBuffers,
                "vkFreeCommandBuffers",
            ),
            .reset_command_pool = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkResetCommandPool,
                "vkResetCommandPool",
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
            .cmd_pipeline_barrier2 = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.cmd_pipeline_barrier2,
            ),
            .cmd_set_event2 = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.cmd_set_event2,
            ),
            .cmd_reset_event2 = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.cmd_reset_event2,
            ),
            .cmd_wait_events2 = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.cmd_wait_events2,
            ),
            .cmd_begin_rendering = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.cmd_begin_rendering,
            ),
            .cmd_end_rendering = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.cmd_end_rendering,
            ),
            .cmd_clear_color_image = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdClearColorImage,
                "vkCmdClearColorImage",
            ),
            .cmd_clear_depth_stencil_image = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdClearDepthStencilImage,
                "vkCmdClearDepthStencilImage",
            ),
            .cmd_fill_buffer = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdFillBuffer,
                "vkCmdFillBuffer",
            ),
            .cmd_update_buffer = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdUpdateBuffer,
                "vkCmdUpdateBuffer",
            ),
            .cmd_copy_buffer = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdCopyBuffer,
                "vkCmdCopyBuffer",
            ),
            .cmd_copy_buffer2 = loadDeviceDescriptor(
                get_device_proc_addr,
                handle,
                command.cmd_copy_buffer2,
            ),
            .cmd_copy_buffer_to_image = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdCopyBufferToImage,
                "vkCmdCopyBufferToImage",
            ),
            .cmd_copy_image_to_buffer = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdCopyImageToBuffer,
                "vkCmdCopyImageToBuffer",
            ),
            .cmd_copy_image = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdCopyImage,
                "vkCmdCopyImage",
            ),
            .cmd_blit_image = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdBlitImage,
                "vkCmdBlitImage",
            ),
            .cmd_resolve_image = try loadDeviceRequired(
                get_device_proc_addr,
                handle,
                raw.PFN_vkCmdResolveImage,
                "vkCmdResolveImage",
            ),
            .cmd_bind_pipeline = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdBindPipeline, "vkCmdBindPipeline"),
            .cmd_bind_descriptor_sets = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdBindDescriptorSets, "vkCmdBindDescriptorSets"),
            .cmd_bind_vertex_buffers = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdBindVertexBuffers, "vkCmdBindVertexBuffers"),
            .cmd_bind_index_buffer = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdBindIndexBuffer, "vkCmdBindIndexBuffer"),
            .cmd_set_viewport = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdSetViewport, "vkCmdSetViewport"),
            .cmd_set_scissor = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdSetScissor, "vkCmdSetScissor"),
            .cmd_set_line_width = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdSetLineWidth, "vkCmdSetLineWidth"),
            .cmd_set_depth_bias = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdSetDepthBias, "vkCmdSetDepthBias"),
            .cmd_set_blend_constants = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdSetBlendConstants, "vkCmdSetBlendConstants"),
            .cmd_set_depth_bounds = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdSetDepthBounds, "vkCmdSetDepthBounds"),
            .cmd_push_constants = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdPushConstants, "vkCmdPushConstants"),
            .cmd_draw = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdDraw, "vkCmdDraw"),
            .cmd_draw_indexed = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdDrawIndexed, "vkCmdDrawIndexed"),
            .cmd_draw_indirect = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdDrawIndirect, "vkCmdDrawIndirect"),
            .cmd_draw_indexed_indirect = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdDrawIndexedIndirect, "vkCmdDrawIndexedIndirect"),
            .cmd_draw_indirect_count = loadDeviceDescriptor(get_device_proc_addr, handle, command.cmd_draw_indirect_count),
            .cmd_draw_indexed_indirect_count = loadDeviceDescriptor(get_device_proc_addr, handle, command.cmd_draw_indexed_indirect_count),
            .cmd_dispatch = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdDispatch, "vkCmdDispatch"),
            .cmd_dispatch_indirect = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdDispatchIndirect, "vkCmdDispatchIndirect"),
            .cmd_dispatch_base = loadDeviceDescriptor(get_device_proc_addr, handle, command.cmd_dispatch_base),
            .cmd_execute_commands = try loadDeviceRequired(get_device_proc_addr, handle, raw.PFN_vkCmdExecuteCommands, "vkCmdExecuteCommands"),
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
        !@hasDecl(Descriptor, "scope") or
        !@hasDecl(Descriptor, "aliases"))
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

fn loadInstanceDescriptor(
    get_instance_proc_addr: CommandFunction(raw.PFN_vkGetInstanceProcAddr),
    instance: raw.VkInstance,
    comptime descriptor: anytype,
    comptime expected_scope: command.Scope,
) ?DescriptorFunction(descriptor, expected_scope) {
    const Descriptor = @TypeOf(descriptor);
    if (loadInstance(
        get_instance_proc_addr,
        instance,
        Descriptor.Pfn,
        Descriptor.name,
    )) |function| return function;
    inline for (Descriptor.aliases) |alias| {
        if (loadInstance(
            get_instance_proc_addr,
            instance,
            Descriptor.Pfn,
            alias,
        )) |function| return function;
    }
    return null;
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

fn loadDeviceDescriptor(
    get_device_proc_addr: CommandFunction(raw.PFN_vkGetDeviceProcAddr),
    device: raw.VkDevice,
    comptime descriptor: anytype,
) ?DescriptorFunction(descriptor, .device) {
    const Descriptor = @TypeOf(descriptor);
    if (loadDevice(
        get_device_proc_addr,
        device,
        Descriptor.Pfn,
        Descriptor.name,
    )) |function| return function;
    inline for (Descriptor.aliases) |alias| {
        if (loadDevice(
            get_device_proc_addr,
            device,
            Descriptor.Pfn,
            alias,
        )) |function| return function;
    }
    return null;
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

    var surface_formats = try gpa.alloc(SurfaceFormat, count);
    errdefer gpa.free(surface_formats);
    for (0..enumeration_attempt_count_max) |_| {
        const written = enumerateSurfaceFormatsInto(
            enumerate,
            physical_device,
            surface,
            surface_formats,
        ) catch |enumeration_error| switch (enumeration_error) {
            error.BufferTooSmall => null,
            else => return enumeration_error,
        };
        if (written) |items| return gpa.realloc(surface_formats, items.len);

        count = try surfaceFormatCountRaw(enumerate, physical_device, surface);
        count = try nextEnumerationCapacity(count, surface_formats.len);
        surface_formats = try gpa.realloc(surface_formats, count);
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
    features2_alias_only,
    format_properties2_alias_only,
    submit2_alias_only,
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
var test_queue_submit2_call_count: usize = 0;
var test_queue_submit2_batch_count: u32 = 0;
var test_queue_submit2_result: raw.VkResult = raw.VK_SUCCESS;
var test_submit2_wait_value: u64 = 0;
var test_submit2_command_device_mask: u32 = 0;
var test_submit2_signal_value: u64 = 0;
var test_submit2_flags: raw.VkSubmitFlags = 0;
var test_submit2_performance_pass: ?u32 = null;
var test_named_object_type: raw.VkObjectType = 0;
var test_named_object_handle: u64 = 0;
var test_resource_result: raw.VkResult = raw.VK_SUCCESS;
var test_resource_null_handle = false;
var test_wait_result: raw.VkResult = raw.VK_SUCCESS;
var test_fence_status_result: raw.VkResult = raw.VK_SUCCESS;
var test_fence_batch_count: u32 = 0;
var test_fence_wait_all: raw.VkBool32 = raw.VK_FALSE;
var test_timeline_counter: u64 = 0;
var test_timeline_wait_count: u32 = 0;
var test_timeline_wait_flags: raw.VkSemaphoreWaitFlags = 0;
var test_timeline_signal_value: u64 = 0;
var test_created_semaphore_kind: SemaphoreKind = .binary;
var test_created_semaphore_initial_value: u64 = 0;
var test_destroy_image_view_count: usize = 0;
var test_destroy_buffer_count: usize = 0;
var test_destroy_buffer_view_count: usize = 0;
var test_free_memory_count: usize = 0;
var test_bind_buffer_count: usize = 0;
var test_buffer_size: u64 = 0;
var test_buffer_sharing_mode: raw.VkSharingMode = raw.VK_SHARING_MODE_EXCLUSIVE;
var test_buffer_queue_family_count: u32 = 0;
var test_buffer_usage: raw.VkBufferUsageFlags = 0;
var test_buffer_create_flags: raw.VkBufferCreateFlags = 0;
var test_buffer_capture_address: u64 = 0;
var test_buffer_view_offset: u64 = 0;
var test_buffer_view_range: u64 = 0;
var test_bound_memory_offset: u64 = 0;
var test_allocated_memory_size: u64 = 0;
var test_allocated_memory_type: u32 = 0;
var test_map_result: raw.VkResult = raw.VK_SUCCESS;
var test_unmap_result: raw.VkResult = raw.VK_SUCCESS;
var test_map_count: usize = 0;
var test_unmap_count: usize = 0;
var test_cache_offset: u64 = 0;
var test_cache_size: u64 = 0;
var test_mapped_storage: [256]u8 = undefined;
var test_destroy_semaphore_count: usize = 0;
var test_destroy_fence_count: usize = 0;
var test_destroy_command_pool_count: usize = 0;
var test_free_command_buffer_count: usize = 0;
var test_reset_command_pool_count: usize = 0;
var test_allocated_command_buffer_level: raw.VkCommandBufferLevel = raw.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
var test_begin_has_inheritance = false;
var test_begin_occlusion_query = raw.VK_FALSE;
var test_begin_command_buffer_count: usize = 0;
var test_end_command_buffer_count: usize = 0;
var test_reset_command_buffer_count: usize = 0;
var test_pipeline_barrier_count: usize = 0;
var test_clear_color_count: usize = 0;
var test_begin_rendering_count: usize = 0;
var test_end_rendering_count: usize = 0;
var test_rendering_flags: raw.VkRenderingFlags = 0;
var test_rendering_color_count: u32 = 0;
var test_destroy_pipeline_layout_count: usize = 0;
var test_push_constant_count: usize = 0;
var test_push_constant_offset: u32 = 0;
var test_push_constant_size: u32 = 0;
var test_end_command_label_count: usize = 0;
var test_acquire_result: raw.VkResult = raw.VK_SUCCESS;
var test_acquire_image_index: u32 = 0;
var test_present_result: raw.VkResult = raw.VK_SUCCESS;
var test_memory_properties: raw.VkPhysicalDeviceMemoryProperties = .{};
var test_format_properties: raw.VkFormatProperties = .{};
var test_image_format_properties: raw.VkImageFormatProperties = .{};
var test_image_format_result: raw.VkResult = raw.VK_SUCCESS;
var test_sparse_image_format_properties: [2]raw.VkSparseImageFormatProperties = .{ .{}, .{} };
var test_sparse_image_format_property_count: u32 = 0;
var test_drm_format_modifier_properties: [2]raw.VkDrmFormatModifierPropertiesEXT = .{ .{}, .{} };
var test_drm_format_modifier_property_count: u32 = 0;
var test_external_memory_properties: raw.VkExternalMemoryProperties = .{};
var test_external_memory_handle_type: raw.VkExternalMemoryHandleTypeFlagBits = 0;
var test_drm_format_modifier: u64 = 0;
var test_drm_sharing_mode: raw.VkSharingMode = raw.VK_SHARING_MODE_EXCLUSIVE;
var test_drm_queue_family_count: u32 = 0;

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
    if (testNameEquals(name, "vkGetPhysicalDeviceFeatures2")) {
        if (test_missing_command == .features2_alias_only) return null;
        return @ptrCast(&testUnused);
    }
    if (testNameEquals(name, "vkGetPhysicalDeviceFeatures2KHR")) {
        return @ptrCast(&testUnused);
    }
    if (testNameEquals(name, "vkGetPhysicalDeviceFormatProperties2")) {
        if (test_missing_command == .format_properties2_alias_only) return null;
        return @ptrCast(&testGetPhysicalDeviceFormatProperties2);
    }
    if (testNameEquals(name, "vkGetPhysicalDeviceFormatProperties2KHR")) {
        return @ptrCast(&testGetPhysicalDeviceFormatProperties2);
    }
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
    if (testNameEquals(name, "vkQueueSubmit2")) {
        if (test_missing_command == .submit2_alias_only) return null;
        return @ptrCast(&testQueueSubmit2);
    }
    if (testNameEquals(name, "vkQueueSubmit2KHR")) return @ptrCast(&testQueueSubmit2);
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

fn testGetPhysicalDeviceFormatProperties2(
    _: raw.VkPhysicalDevice,
    _: raw.VkFormat,
    properties: [*c]raw.VkFormatProperties2,
) callconv(.c) void {
    properties.*.formatProperties = test_format_properties;
    if (properties.*.pNext) |next| {
        const base: *raw.VkBaseOutStructure = @ptrCast(@alignCast(next));
        if (base.sType == raw.VK_STRUCTURE_TYPE_DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT) {
            const list: *raw.VkDrmFormatModifierPropertiesListEXT = @ptrCast(@alignCast(next));
            const capacity = list.drmFormatModifierCount;
            const written = @min(capacity, test_drm_format_modifier_property_count);
            for (0..written) |index| {
                list.pDrmFormatModifierProperties[index] = test_drm_format_modifier_properties[index];
            }
            list.drmFormatModifierCount = test_drm_format_modifier_property_count;
        }
    }
}

fn testGetPhysicalDeviceImageFormatProperties2(
    _: raw.VkPhysicalDevice,
    info: [*c]const raw.VkPhysicalDeviceImageFormatInfo2,
    properties: [*c]raw.VkImageFormatProperties2,
) callconv(.c) raw.VkResult {
    var next: [*c]const raw.VkBaseInStructure = @ptrCast(@alignCast(info.*.pNext));
    while (next != null) : (next = next.*.pNext) {
        if (next.*.sType == raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO) {
            const external: *const raw.VkPhysicalDeviceExternalImageFormatInfo =
                @ptrCast(@alignCast(next));
            test_external_memory_handle_type = external.handleType;
        } else if (next.*.sType == raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_DRM_FORMAT_MODIFIER_INFO_EXT) {
            const drm: *const raw.VkPhysicalDeviceImageDrmFormatModifierInfoEXT =
                @ptrCast(@alignCast(next));
            test_drm_format_modifier = drm.drmFormatModifier;
            test_drm_sharing_mode = drm.sharingMode;
            test_drm_queue_family_count = drm.queueFamilyIndexCount;
        }
    }
    properties.*.imageFormatProperties = test_image_format_properties;
    if (properties.*.pNext) |next_output| {
        const external: *raw.VkExternalImageFormatProperties = @ptrCast(@alignCast(next_output));
        external.externalMemoryProperties = test_external_memory_properties;
    }
    return test_image_format_result;
}

fn testGetPhysicalDeviceSparseImageFormatProperties2(
    _: raw.VkPhysicalDevice,
    _: [*c]const raw.VkPhysicalDeviceSparseImageFormatInfo2,
    count: [*c]u32,
    properties: [*c]raw.VkSparseImageFormatProperties2,
) callconv(.c) void {
    if (properties == null) {
        count.* = test_sparse_image_format_property_count;
        return;
    }
    const capacity = count.*;
    const written = @min(capacity, test_sparse_image_format_property_count);
    for (0..written) |index| {
        properties[index].properties = test_sparse_image_format_properties[index];
    }
    count.* = test_sparse_image_format_property_count;
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

fn testCreateBuffer(
    _: raw.VkDevice,
    create_info: [*c]const raw.VkBufferCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    handle: [*c]raw.VkBuffer,
) callconv(.c) raw.VkResult {
    test_buffer_size = create_info.*.size;
    test_buffer_sharing_mode = create_info.*.sharingMode;
    test_buffer_queue_family_count = create_info.*.queueFamilyIndexCount;
    test_buffer_usage = create_info.*.usage;
    test_buffer_create_flags = create_info.*.flags;
    test_buffer_capture_address = 0;
    if (create_info.*.pNext) |next| {
        const capture: *const raw.VkBufferOpaqueCaptureAddressCreateInfo =
            @ptrCast(@alignCast(next));
        test_buffer_capture_address = capture.opaqueCaptureAddress;
    }
    handle.* = if (test_resource_null_handle) null else testHandle(raw.VkBuffer, 0x5600);
    return test_resource_result;
}

fn testDestroyBuffer(
    _: raw.VkDevice,
    _: raw.VkBuffer,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_buffer_count += 1;
}

fn testGetBufferMemoryRequirements(
    _: raw.VkDevice,
    _: raw.VkBuffer,
    requirements: [*c]raw.VkMemoryRequirements,
) callconv(.c) void {
    requirements.* = .{ .size = 1024, .alignment = 256, .memoryTypeBits = 1 };
}

fn testGetBufferDeviceAddress(
    _: raw.VkDevice,
    _: [*c]const raw.VkBufferDeviceAddressInfo,
) callconv(.c) raw.VkDeviceAddress {
    return 0x7000;
}

fn testGetBufferOpaqueCaptureAddress(
    _: raw.VkDevice,
    _: [*c]const raw.VkBufferDeviceAddressInfo,
) callconv(.c) u64 {
    return 0x8000;
}

fn testCreateBufferView(
    _: raw.VkDevice,
    create_info: [*c]const raw.VkBufferViewCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    handle: [*c]raw.VkBufferView,
) callconv(.c) raw.VkResult {
    test_buffer_view_offset = create_info.*.offset;
    test_buffer_view_range = create_info.*.range;
    handle.* = if (test_resource_null_handle) null else testHandle(raw.VkBufferView, 0x5700);
    return test_resource_result;
}

fn testDestroyBufferView(
    _: raw.VkDevice,
    _: raw.VkBufferView,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_buffer_view_count += 1;
}

fn testAllocateMemory(
    _: raw.VkDevice,
    info: [*c]const raw.VkMemoryAllocateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    handle: [*c]raw.VkDeviceMemory,
) callconv(.c) raw.VkResult {
    test_allocated_memory_size = info.*.allocationSize;
    test_allocated_memory_type = info.*.memoryTypeIndex;
    handle.* = if (test_resource_null_handle) null else testHandle(raw.VkDeviceMemory, 0x5800);
    return test_resource_result;
}

fn testMapMemory(
    _: raw.VkDevice,
    _: raw.VkDeviceMemory,
    offset: raw.VkDeviceSize,
    _: raw.VkDeviceSize,
    _: raw.VkMemoryMapFlags,
    output: [*c]?*anyopaque,
) callconv(.c) raw.VkResult {
    test_map_count += 1;
    if (test_map_result == raw.VK_SUCCESS) output.* = @ptrCast(&test_mapped_storage[offset]);
    return test_map_result;
}

fn testUnmapMemory(_: raw.VkDevice, _: raw.VkDeviceMemory) callconv(.c) void {
    test_unmap_count += 1;
}

fn testMapMemory2(
    _: raw.VkDevice,
    info: [*c]const raw.VkMemoryMapInfo,
    output: [*c]?*anyopaque,
) callconv(.c) raw.VkResult {
    test_map_count += 1;
    if (test_map_result == raw.VK_SUCCESS) output.* = @ptrCast(&test_mapped_storage[info.*.offset]);
    return test_map_result;
}

fn testUnmapMemory2(
    _: raw.VkDevice,
    _: [*c]const raw.VkMemoryUnmapInfo,
) callconv(.c) raw.VkResult {
    test_unmap_count += 1;
    return test_unmap_result;
}

fn testCacheMemory(
    _: raw.VkDevice,
    count: u32,
    ranges: [*c]const raw.VkMappedMemoryRange,
) callconv(.c) raw.VkResult {
    if (count != 0) {
        test_cache_offset = ranges[0].offset;
        test_cache_size = ranges[0].size;
    }
    return test_map_result;
}

fn testFreeMemory(
    _: raw.VkDevice,
    _: raw.VkDeviceMemory,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_free_memory_count += 1;
}

fn testBindBufferMemory(
    _: raw.VkDevice,
    _: raw.VkBuffer,
    _: raw.VkDeviceMemory,
    offset: u64,
) callconv(.c) raw.VkResult {
    test_bind_buffer_count += 1;
    test_bound_memory_offset = offset;
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
    create_info: [*c]const raw.VkSemaphoreCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    handle: [*c]raw.VkSemaphore,
) callconv(.c) raw.VkResult {
    test_created_semaphore_kind = .binary;
    test_created_semaphore_initial_value = 0;
    if (create_info.*.pNext) |next| {
        const type_info: *const raw.VkSemaphoreTypeCreateInfo = @ptrCast(@alignCast(next));
        test_created_semaphore_kind = if (type_info.semaphoreType == raw.VK_SEMAPHORE_TYPE_TIMELINE)
            .timeline
        else
            .binary;
        test_created_semaphore_initial_value = type_info.initialValue;
    }
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
    count: u32,
    _: [*c]const raw.VkFence,
) callconv(.c) raw.VkResult {
    test_fence_batch_count = count;
    return test_resource_result;
}

fn testWaitForFences(
    _: raw.VkDevice,
    count: u32,
    _: [*c]const raw.VkFence,
    wait_all: raw.VkBool32,
    _: u64,
) callconv(.c) raw.VkResult {
    test_fence_batch_count = count;
    test_fence_wait_all = wait_all;
    return test_wait_result;
}

fn testGetFenceStatus(
    _: raw.VkDevice,
    _: raw.VkFence,
) callconv(.c) raw.VkResult {
    return test_fence_status_result;
}

fn testGetSemaphoreCounterValue(
    _: raw.VkDevice,
    _: raw.VkSemaphore,
    value: [*c]u64,
) callconv(.c) raw.VkResult {
    value.* = test_timeline_counter;
    return test_resource_result;
}

fn testWaitSemaphores(
    _: raw.VkDevice,
    wait_info: [*c]const raw.VkSemaphoreWaitInfo,
    _: u64,
) callconv(.c) raw.VkResult {
    test_timeline_wait_count = wait_info.*.semaphoreCount;
    test_timeline_wait_flags = wait_info.*.flags;
    return test_wait_result;
}

fn testSignalSemaphore(
    _: raw.VkDevice,
    signal_info: [*c]const raw.VkSemaphoreSignalInfo,
) callconv(.c) raw.VkResult {
    test_timeline_signal_value = signal_info.*.value;
    if (test_resource_result == raw.VK_SUCCESS) {
        test_timeline_counter = signal_info.*.value;
    }
    return test_resource_result;
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
    allocate_info: [*c]const raw.VkCommandBufferAllocateInfo,
    handle: [*c]raw.VkCommandBuffer,
) callconv(.c) raw.VkResult {
    test_allocated_command_buffer_level = allocate_info.*.level;
    handle.* = if (test_resource_null_handle) null else testHandle(raw.VkCommandBuffer, 0x5500);
    return test_resource_result;
}

fn testFreeCommandBuffers(
    _: raw.VkDevice,
    _: raw.VkCommandPool,
    count: u32,
    _: [*c]const raw.VkCommandBuffer,
) callconv(.c) void {
    test_free_command_buffer_count += count;
}

fn testResetCommandPool(
    _: raw.VkDevice,
    _: raw.VkCommandPool,
    _: raw.VkCommandPoolResetFlags,
) callconv(.c) raw.VkResult {
    test_reset_command_pool_count += 1;
    return test_resource_result;
}

fn testBeginCommandBuffer(
    _: raw.VkCommandBuffer,
    begin_info: [*c]const raw.VkCommandBufferBeginInfo,
) callconv(.c) raw.VkResult {
    test_begin_command_buffer_count += 1;
    test_begin_has_inheritance = begin_info.*.pInheritanceInfo != null;
    test_begin_occlusion_query = if (begin_info.*.pInheritanceInfo) |inheritance|
        inheritance.*.occlusionQueryEnable
    else
        raw.VK_FALSE;
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

fn testCmdBeginRendering(
    _: raw.VkCommandBuffer,
    info: [*c]const raw.VkRenderingInfo,
) callconv(.c) void {
    test_begin_rendering_count += 1;
    test_rendering_flags = info.*.flags;
    test_rendering_color_count = info.*.colorAttachmentCount;
}

fn testCmdEndRendering(_: raw.VkCommandBuffer) callconv(.c) void {
    test_end_rendering_count += 1;
}

fn testCreatePipelineLayout(
    _: raw.VkDevice,
    _: [*c]const raw.VkPipelineLayoutCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkPipelineLayout,
) callconv(.c) raw.VkResult {
    output.* = testHandle(raw.VkPipelineLayout, 0x5900);
    return test_resource_result;
}

fn testDestroyPipelineLayout(
    _: raw.VkDevice,
    _: raw.VkPipelineLayout,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_pipeline_layout_count += 1;
}

fn testCmdPushConstants(
    _: raw.VkCommandBuffer,
    _: raw.VkPipelineLayout,
    _: raw.VkShaderStageFlags,
    offset: u32,
    size: u32,
    _: ?*const anyopaque,
) callconv(.c) void {
    test_push_constant_count += 1;
    test_push_constant_offset = offset;
    test_push_constant_size = size;
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
    output_images: [*c]raw.VkImage,
) callconv(.c) raw.VkResult {
    if (output_images == null) {
        count.* = 2;
        return raw.VK_SUCCESS;
    }
    if (count.* < 2) {
        count.* = 2;
        return raw.VK_INCOMPLETE;
    }
    output_images[0] = testHandle(raw.VkImage, 0x5000);
    output_images[1] = testHandle(raw.VkImage, 0x5001);
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

fn testQueueSubmit2(
    _: raw.VkQueue,
    submit_count: u32,
    submits: [*c]const raw.VkSubmitInfo2,
    _: raw.VkFence,
) callconv(.c) raw.VkResult {
    test_queue_submit2_call_count += 1;
    test_queue_submit2_batch_count = submit_count;
    if (submit_count > 0) {
        const submit = submits[0];
        test_submit2_flags = submit.flags;
        test_submit2_performance_pass = if (submit.pNext) |next| blk: {
            const performance_info: *const raw.VkPerformanceQuerySubmitInfoKHR =
                @ptrCast(@alignCast(next));
            break :blk performance_info.counterPassIndex;
        } else null;
        if (submit.waitSemaphoreInfoCount > 0) {
            test_submit2_wait_value = submit.pWaitSemaphoreInfos[0].value;
        }
        if (submit.commandBufferInfoCount > 0) {
            test_submit2_command_device_mask = submit.pCommandBufferInfos[0].deviceMask;
        }
        if (submit.signalSemaphoreInfoCount > 0) {
            test_submit2_signal_value = submit.pSignalSemaphoreInfos[0].value;
        }
    }
    return test_queue_submit2_result;
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
    output_formats: [*c]raw.VkSurfaceFormatKHR,
) callconv(.c) raw.VkResult {
    if (output_formats == null) {
        count[0] = 2;
        return raw.VK_SUCCESS;
    }
    if (count[0] < 2) {
        count[0] = 2;
        return raw.VK_INCOMPLETE;
    }
    output_formats[0] = .{
        .format = raw.VK_FORMAT_B8G8R8A8_SRGB,
        .colorSpace = raw.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
    };
    output_formats[1] = .{
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
            .get_physical_device_format_properties2 = testGetPhysicalDeviceFormatProperties2,
            .get_physical_device_image_format_properties2 = testGetPhysicalDeviceImageFormatProperties2,
            .get_physical_device_sparse_image_format_properties2 = testGetPhysicalDeviceSparseImageFormatProperties2,
            .get_physical_device_features = testFunction(raw.PFN_vkGetPhysicalDeviceFeatures),
            .get_physical_device_features2 = testFunction(raw.PFN_vkGetPhysicalDeviceFeatures2),
            .get_physical_device_memory_properties = testGetPhysicalDeviceMemoryProperties,
            .get_physical_device_memory_properties2 = null,
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
            .queue_submit2 = testQueueSubmit2,
            .queue_wait_idle = testFunction(raw.PFN_vkQueueWaitIdle),
            .device_wait_idle = testFunction(raw.PFN_vkDeviceWaitIdle),
            .allocate_memory = testAllocateMemory,
            .free_memory = testFreeMemory,
            .map_memory = testFunction(raw.PFN_vkMapMemory),
            .unmap_memory = testFunction(raw.PFN_vkUnmapMemory),
            .map_memory2 = null,
            .unmap_memory2 = null,
            .flush_mapped_memory_ranges = testFunction(raw.PFN_vkFlushMappedMemoryRanges),
            .invalidate_mapped_memory_ranges = testFunction(raw.PFN_vkInvalidateMappedMemoryRanges),
            .get_device_memory_commitment = testFunction(raw.PFN_vkGetDeviceMemoryCommitment),
            .get_device_memory_opaque_capture_address = null,
            .create_sampler = testFunction(raw.PFN_vkCreateSampler),
            .destroy_sampler = testFunction(raw.PFN_vkDestroySampler),
            .create_sampler_ycbcr_conversion = null,
            .destroy_sampler_ycbcr_conversion = null,
            .create_shader_module = testFunction(raw.PFN_vkCreateShaderModule),
            .destroy_shader_module = testFunction(raw.PFN_vkDestroyShaderModule),
            .get_shader_module_identifier_ext = null,
            .create_descriptor_set_layout = testFunction(raw.PFN_vkCreateDescriptorSetLayout),
            .destroy_descriptor_set_layout = testFunction(raw.PFN_vkDestroyDescriptorSetLayout),
            .create_descriptor_pool = testFunction(raw.PFN_vkCreateDescriptorPool),
            .destroy_descriptor_pool = testFunction(raw.PFN_vkDestroyDescriptorPool),
            .reset_descriptor_pool = testFunction(raw.PFN_vkResetDescriptorPool),
            .allocate_descriptor_sets = testFunction(raw.PFN_vkAllocateDescriptorSets),
            .free_descriptor_sets = testFunction(raw.PFN_vkFreeDescriptorSets),
            .create_pipeline_layout = testFunction(raw.PFN_vkCreatePipelineLayout),
            .destroy_pipeline_layout = testFunction(raw.PFN_vkDestroyPipelineLayout),
            .create_graphics_pipelines = testFunction(raw.PFN_vkCreateGraphicsPipelines),
            .create_compute_pipelines = testFunction(raw.PFN_vkCreateComputePipelines),
            .destroy_pipeline = testFunction(raw.PFN_vkDestroyPipeline),
            .create_buffer = testCreateBuffer,
            .destroy_buffer = testDestroyBuffer,
            .get_buffer_memory_requirements = testGetBufferMemoryRequirements,
            .get_buffer_memory_requirements2 = null,
            .get_buffer_device_address = testGetBufferDeviceAddress,
            .get_buffer_opaque_capture_address = testGetBufferOpaqueCaptureAddress,
            .create_buffer_view = testCreateBufferView,
            .destroy_buffer_view = testDestroyBufferView,
            .bind_buffer_memory = testBindBufferMemory,
            .bind_buffer_memory2 = null,
            .create_image = testFunction(raw.PFN_vkCreateImage),
            .destroy_image = testFunction(raw.PFN_vkDestroyImage),
            .get_image_memory_requirements = testFunction(raw.PFN_vkGetImageMemoryRequirements),
            .get_image_memory_requirements2 = null,
            .bind_image_memory = testFunction(raw.PFN_vkBindImageMemory),
            .bind_image_memory2 = null,
            .create_image_view = testCreateImageView,
            .destroy_image_view = testDestroyImageView,
            .create_semaphore = testCreateSemaphore,
            .destroy_semaphore = testDestroySemaphore,
            .get_semaphore_counter_value = testGetSemaphoreCounterValue,
            .wait_semaphores = testWaitSemaphores,
            .signal_semaphore = testSignalSemaphore,
            .create_fence = testCreateFence,
            .destroy_fence = testDestroyFence,
            .get_fence_status = testGetFenceStatus,
            .reset_fences = testResetFences,
            .wait_for_fences = testWaitForFences,
            .create_event = testFunction(raw.PFN_vkCreateEvent),
            .destroy_event = testFunction(raw.PFN_vkDestroyEvent),
            .get_event_status = testFunction(raw.PFN_vkGetEventStatus),
            .set_event = testFunction(raw.PFN_vkSetEvent),
            .reset_event = testFunction(raw.PFN_vkResetEvent),
            .create_command_pool = testCreateCommandPool,
            .destroy_command_pool = testDestroyCommandPool,
            .allocate_command_buffers = testAllocateCommandBuffers,
            .free_command_buffers = testFreeCommandBuffers,
            .reset_command_pool = testResetCommandPool,
            .begin_command_buffer = testBeginCommandBuffer,
            .end_command_buffer = testEndCommandBuffer,
            .reset_command_buffer = testResetCommandBuffer,
            .cmd_pipeline_barrier = testCmdPipelineBarrier,
            .cmd_pipeline_barrier2 = null,
            .cmd_set_event2 = null,
            .cmd_reset_event2 = null,
            .cmd_wait_events2 = null,
            .cmd_begin_rendering = null,
            .cmd_end_rendering = null,
            .cmd_clear_color_image = testCmdClearColorImage,
            .cmd_clear_depth_stencil_image = testFunction(raw.PFN_vkCmdClearDepthStencilImage),
            .cmd_fill_buffer = testFunction(raw.PFN_vkCmdFillBuffer),
            .cmd_update_buffer = testFunction(raw.PFN_vkCmdUpdateBuffer),
            .cmd_copy_buffer = testFunction(raw.PFN_vkCmdCopyBuffer),
            .cmd_copy_buffer2 = null,
            .cmd_copy_buffer_to_image = testFunction(raw.PFN_vkCmdCopyBufferToImage),
            .cmd_copy_image_to_buffer = testFunction(raw.PFN_vkCmdCopyImageToBuffer),
            .cmd_copy_image = testFunction(raw.PFN_vkCmdCopyImage),
            .cmd_blit_image = testFunction(raw.PFN_vkCmdBlitImage),
            .cmd_resolve_image = testFunction(raw.PFN_vkCmdResolveImage),
            .cmd_bind_pipeline = testFunction(raw.PFN_vkCmdBindPipeline),
            .cmd_bind_descriptor_sets = testFunction(raw.PFN_vkCmdBindDescriptorSets),
            .cmd_bind_vertex_buffers = testFunction(raw.PFN_vkCmdBindVertexBuffers),
            .cmd_bind_index_buffer = testFunction(raw.PFN_vkCmdBindIndexBuffer),
            .cmd_set_viewport = testFunction(raw.PFN_vkCmdSetViewport),
            .cmd_set_scissor = testFunction(raw.PFN_vkCmdSetScissor),
            .cmd_set_line_width = testFunction(raw.PFN_vkCmdSetLineWidth),
            .cmd_set_depth_bias = testFunction(raw.PFN_vkCmdSetDepthBias),
            .cmd_set_blend_constants = testFunction(raw.PFN_vkCmdSetBlendConstants),
            .cmd_set_depth_bounds = testFunction(raw.PFN_vkCmdSetDepthBounds),
            .cmd_push_constants = testFunction(raw.PFN_vkCmdPushConstants),
            .cmd_draw = testFunction(raw.PFN_vkCmdDraw),
            .cmd_draw_indexed = testFunction(raw.PFN_vkCmdDrawIndexed),
            .cmd_draw_indirect = testFunction(raw.PFN_vkCmdDrawIndirect),
            .cmd_draw_indexed_indirect = testFunction(raw.PFN_vkCmdDrawIndexedIndirect),
            .cmd_draw_indirect_count = null,
            .cmd_draw_indexed_indirect_count = null,
            .cmd_dispatch = testFunction(raw.PFN_vkCmdDispatch),
            .cmd_dispatch_indirect = testFunction(raw.PFN_vkCmdDispatchIndirect),
            .cmd_dispatch_base = null,
            .cmd_execute_commands = testFunction(raw.PFN_vkCmdExecuteCommands),
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

test "generated command descriptors resolve promoted aliases internally" {
    var instance = testInstance();
    defer instance.deinit();
    test_missing_command = .features2_alias_only;
    defer test_missing_command = .none;
    try std.testing.expect((try instance.load(command.get_physical_device_features2)) != null);
    try std.testing.expectEqualStrings(
        "vkGetPhysicalDeviceFeatures2KHR",
        @TypeOf(command.get_physical_device_features2).aliases[0],
    );
    try std.testing.expectEqual(
        command.Scope.instance,
        @TypeOf(command.get_physical_device_features2_khr).scope,
    );

    test_missing_command = .format_properties2_alias_only;
    try std.testing.expect(
        (try instance.load(command.get_physical_device_format_properties2)) != null,
    );
    try std.testing.expectEqualStrings(
        "vkGetPhysicalDeviceFormatProperties2KHR",
        @TypeOf(command.get_physical_device_format_properties2).aliases[0],
    );
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
    const returned_formats = try enumerateSurfaceFormatsInto(
        testSurfaceFormats,
        physical_device,
        surface,
        &format_storage,
    );
    try std.testing.expectEqual(@as(usize, 2), returned_formats.len);
    try std.testing.expectEqual(Format.b8g8r8a8_srgb, returned_formats[0].format);
    try std.testing.expectEqual(ColorSpace.srgb_nonlinear, returned_formats[0].color_space);
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
        .queue_submit2 = testQueueSubmit2,
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
        .image = .{ .swapchain = &image },
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
        .image = .{ .swapchain = &image },
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
        .image = .{ .swapchain = &image },
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
        .queue_submit2 = testQueueSubmit2,
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
    try command_buffer.markComplete();
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

test "fence status and batches preserve typed outcomes and validate parents" {
    test_resource_result = raw.VK_SUCCESS;
    test_resource_null_handle = false;
    test_wait_result = raw.VK_SUCCESS;
    test_fence_status_result = raw.VK_SUCCESS;
    test_fence_batch_count = 99;

    var device = testDevice();
    defer device.deinit();
    var first = try device.createFence(.{});
    defer first.deinit();
    var second = try device.createFence(.{ .signaled = true });
    defer second.deinit();

    try std.testing.expectEqual(FenceStatus.signaled, try first.status());
    test_fence_status_result = raw.VK_NOT_READY;
    try std.testing.expectEqual(FenceStatus.unsignaled, try first.status());
    test_fence_status_result = raw.VK_ERROR_DEVICE_LOST;
    try std.testing.expectError(error.DeviceLost, first.status());
    test_fence_status_result = raw.VK_SUCCESS;

    try std.testing.expectEqual(
        FenceWaitStatus.success,
        try device.waitFences(&.{}, .all, .infinite),
    );
    try std.testing.expectEqual(@as(u32, 99), test_fence_batch_count);
    try std.testing.expectEqual(
        FenceWaitStatus.success,
        try device.waitFences(&.{ &first, &second }, .all, .infinite),
    );
    try std.testing.expectEqual(@as(u32, 2), test_fence_batch_count);
    try std.testing.expectEqual(raw.VK_TRUE, test_fence_wait_all);
    test_wait_result = raw.VK_TIMEOUT;
    try std.testing.expectEqual(
        FenceWaitStatus.timeout,
        try device.waitFences(&.{ &first, &second }, .any, .{ .nanoseconds = 1 }),
    );
    try std.testing.expectEqual(raw.VK_FALSE, test_fence_wait_all);
    test_wait_result = raw.VK_SUCCESS;

    test_fence_batch_count = 99;
    try device.resetFences(&.{});
    try std.testing.expectEqual(@as(u32, 99), test_fence_batch_count);
    try device.resetFences(&.{ &first, &second });
    try std.testing.expectEqual(@as(u32, 2), test_fence_batch_count);

    var foreign = first;
    foreign._device_handle = testHandle(raw.VkDevice, 0x9000);
    try std.testing.expectError(
        error.InvalidHandle,
        device.waitFences(&.{&foreign}, .all, .infinite),
    );
    try std.testing.expectError(error.InvalidHandle, device.resetFences(&.{&foreign}));
}

test "timeline semaphore host operations are typed and kind checked" {
    test_resource_result = raw.VK_SUCCESS;
    test_resource_null_handle = false;
    test_wait_result = raw.VK_SUCCESS;
    test_timeline_counter = 5;
    test_timeline_wait_count = 0;
    test_timeline_wait_flags = 0;
    test_timeline_signal_value = 0;

    var device = testDevice();
    defer device.deinit();
    try std.testing.expectError(
        error.InvalidOptions,
        device.createSemaphore(.{ .kind = .binary, .initial_value = 1 }),
    );
    var binary = try device.createSemaphore(.{});
    defer binary.deinit();
    try std.testing.expectEqual(SemaphoreKind.binary, test_created_semaphore_kind);
    try std.testing.expectError(error.InvalidOptions, binary.counterValue());
    try std.testing.expectError(error.InvalidOptions, binary.wait(1, .infinite));

    var timeline = try device.createSemaphore(.{
        .kind = .timeline,
        .initial_value = 5,
    });
    defer timeline.deinit();
    try std.testing.expectEqual(SemaphoreKind.timeline, timeline.kind);
    try std.testing.expectEqual(SemaphoreKind.timeline, test_created_semaphore_kind);
    try std.testing.expectEqual(@as(u64, 5), test_created_semaphore_initial_value);
    try std.testing.expectEqual(@as(u64, 5), try timeline.counterValue());
    try std.testing.expectError(error.InvalidOptions, timeline.signal(5));
    try timeline.signal(6);
    try std.testing.expectEqual(@as(u64, 6), test_timeline_signal_value);
    try std.testing.expectEqual(@as(u64, 6), try timeline.counterValue());
    try std.testing.expectEqual(
        TimelineWaitStatus.success,
        try timeline.wait(6, .infinite),
    );

    try std.testing.expectEqual(
        TimelineWaitStatus.success,
        try device.waitTimelineSemaphores(&.{}, .all, .infinite),
    );
    try std.testing.expectEqual(@as(u32, 1), test_timeline_wait_count);
    try std.testing.expectEqual(
        TimelineWaitStatus.success,
        try device.waitTimelineSemaphores(
            &.{.{ .semaphore = &timeline, .value = 6 }},
            .any,
            .infinite,
        ),
    );
    try std.testing.expectEqual(@as(u32, 1), test_timeline_wait_count);
    try std.testing.expectEqual(
        @as(raw.VkSemaphoreWaitFlags, raw.VK_SEMAPHORE_WAIT_ANY_BIT),
        test_timeline_wait_flags,
    );
    try std.testing.expectError(
        error.InvalidOptions,
        device.waitTimelineSemaphores(
            &.{.{ .semaphore = &binary, .value = 1 }},
            .all,
            .infinite,
        ),
    );

    var foreign = timeline;
    foreign._device_handle = testHandle(raw.VkDevice, 0x9000);
    try std.testing.expectError(
        error.InvalidHandle,
        device.waitTimelineSemaphores(
            &.{.{ .semaphore = &foreign, .value = 7 }},
            .all,
            .infinite,
        ),
    );

    test_timeline_counter = std.math.maxInt(u64);
    try std.testing.expectError(
        error.InvalidOptions,
        timeline.signal(std.math.maxInt(u64)),
    );
    test_timeline_counter = 6;

    timeline.wait_semaphores = null;
    try std.testing.expectError(error.MissingCommand, timeline.wait(7, .infinite));
    timeline.get_counter_value = null;
    try std.testing.expectError(error.MissingCommand, timeline.counterValue());
}

test "legacy submission rejects timeline semaphores before dispatch" {
    test_resource_result = raw.VK_SUCCESS;
    test_queue_submit_count = 0;
    var device = testDevice();
    defer device.deinit();
    var timeline = try device.createSemaphore(.{ .kind = .timeline });
    defer timeline.deinit();
    const queue: Queue = .{
        ._handle = testHandle(raw.VkQueue, 0x2100),
        ._device_handle = device._handle.?,
        .queue_submit = testQueueSubmit,
        .queue_submit2 = testQueueSubmit2,
        .queue_wait_idle = testFunction(raw.PFN_vkQueueWaitIdle),
        .queue_present_khr = null,
        .queue_begin_debug_utils_label_ext = null,
        .queue_end_debug_utils_label_ext = null,
        .queue_insert_debug_utils_label_ext = null,
    };
    try std.testing.expectError(
        error.InvalidOptions,
        queue.submit(.{ .signals = &.{&timeline} }),
    );
    try std.testing.expectEqual(@as(usize, 0), test_queue_submit_count);
}

test "submit2 assembles typed timeline and device-group submissions" {
    test_resource_result = raw.VK_SUCCESS;
    test_resource_null_handle = false;
    test_queue_submit2_call_count = 0;
    test_queue_submit2_batch_count = 0;
    test_queue_submit2_result = raw.VK_SUCCESS;
    test_submit2_wait_value = 0;
    test_submit2_command_device_mask = 0;
    test_submit2_signal_value = 0;
    test_submit2_flags = 0;
    test_submit2_performance_pass = null;

    var device = testDevice();
    defer device.deinit();
    var pool = try device.createCommandPool(.{ .family_index = .fromRaw(0) });
    defer pool.deinit();
    var command_buffer = try pool.allocateCommandBuffer(.{});
    defer command_buffer.deinit();
    try command_buffer.begin(.{});
    try command_buffer.end();
    var timeline = try device.createSemaphore(.{ .kind = .timeline });
    defer timeline.deinit();
    var fence = try device.createFence(.{});
    defer fence.deinit();
    var queue: Queue = .{
        ._handle = testHandle(raw.VkQueue, 0x2100),
        ._device_handle = device._handle.?,
        .queue_submit = testQueueSubmit,
        .queue_submit2 = testQueueSubmit2,
        .queue_wait_idle = testFunction(raw.PFN_vkQueueWaitIdle),
        .queue_present_khr = null,
        .queue_begin_debug_utils_label_ext = null,
        .queue_end_debug_utils_label_ext = null,
        .queue_insert_debug_utils_label_ext = null,
    };

    try queue.submit2(.{});
    try std.testing.expectEqual(@as(usize, 0), test_queue_submit2_call_count);
    try queue.submit2(.{ .submits = &.{ .{}, .{} } });
    try std.testing.expectEqual(@as(u32, 2), test_queue_submit2_batch_count);

    try queue.submit2(.{
        .submits = &.{.{
            .flags = .init(&.{.protected}),
            .performance_query_pass = 2,
            .waits = &.{.{
                .semaphore = &timeline,
                .value = 3,
                .stage = .init(&.{.all_commands}),
                .device_index = 1,
            }},
            .command_buffers = &.{.{
                .command_buffer = &command_buffer,
                .device_mask = 3,
            }},
            .signals = &.{.{
                .semaphore = &timeline,
                .value = 4,
                .stage = .init(&.{.all_commands}),
                .device_index = 1,
            }},
        }},
        .fence = &fence,
    });
    try std.testing.expectEqual(@as(u64, 3), test_submit2_wait_value);
    try std.testing.expectEqual(@as(u32, 3), test_submit2_command_device_mask);
    try std.testing.expectEqual(@as(u64, 4), test_submit2_signal_value);
    try std.testing.expectEqual(
        SubmitFlags.init(&.{.protected}).toRaw(),
        test_submit2_flags,
    );
    try std.testing.expectEqual(@as(?u32, 2), test_submit2_performance_pass);
    try std.testing.expectError(error.InvalidOptions, command_buffer.reset(false));
    try command_buffer.markComplete();

    queue.queue_submit2 = null;
    try std.testing.expectError(
        error.MissingCommand,
        queue.submit2(.{ .submits = &.{.{}} }),
    );
}

test "submit2 rejects invalid handles, values, masks, and duplicates before dispatch" {
    test_resource_result = raw.VK_SUCCESS;
    test_queue_submit2_call_count = 0;
    var device = testDevice();
    defer device.deinit();
    var pool = try device.createCommandPool(.{ .family_index = .fromRaw(0) });
    defer pool.deinit();
    var command_buffer = try pool.allocateCommandBuffer(.{});
    defer command_buffer.deinit();
    try command_buffer.begin(.{});
    try command_buffer.end();
    var binary = try device.createSemaphore(.{});
    defer binary.deinit();
    var timeline = try device.createSemaphore(.{ .kind = .timeline });
    defer timeline.deinit();
    const queue: Queue = .{
        ._handle = testHandle(raw.VkQueue, 0x2100),
        ._device_handle = device._handle.?,
        .queue_submit = testQueueSubmit,
        .queue_submit2 = testQueueSubmit2,
        .queue_wait_idle = testFunction(raw.PFN_vkQueueWaitIdle),
        .queue_present_khr = null,
        .queue_begin_debug_utils_label_ext = null,
        .queue_end_debug_utils_label_ext = null,
        .queue_insert_debug_utils_label_ext = null,
    };

    try std.testing.expectError(error.InvalidOptions, queue.submit2(.{
        .submits = &.{.{ .waits = &.{.{ .semaphore = &binary, .value = 1 }} }},
    }));
    try std.testing.expectError(error.InvalidOptions, queue.submit2(.{
        .submits = &.{.{ .waits = &.{
            .{ .semaphore = &binary },
            .{ .semaphore = &binary },
        } }},
    }));
    try std.testing.expectError(error.InvalidOptions, queue.submit2(.{
        .submits = &.{.{ .signals = &.{.{ .semaphore = &timeline, .value = 0 }} }},
    }));
    try std.testing.expectError(error.InvalidOptions, queue.submit2(.{
        .submits = &.{.{ .command_buffers = &.{.{
            .command_buffer = &command_buffer,
            .device_mask = 0,
        }} }},
    }));
    try std.testing.expectError(error.InvalidOptions, queue.submit2(.{
        .submits = &.{.{ .command_buffers = &.{
            .{ .command_buffer = &command_buffer },
            .{ .command_buffer = &command_buffer },
        } }},
    }));
    var foreign = binary;
    foreign._device_handle = testHandle(raw.VkDevice, 0x9000);
    try std.testing.expectError(error.InvalidHandle, queue.submit2(.{
        .submits = &.{.{ .signals = &.{.{ .semaphore = &foreign }} }},
    }));
    try std.testing.expectEqual(@as(usize, 0), test_queue_submit2_call_count);
}

test "submit2 preserves device loss and resolves its KHR alias" {
    var device = testDevice();
    defer device.deinit();
    test_missing_command = .submit2_alias_only;
    defer test_missing_command = .none;
    try std.testing.expect((try device.load(command.queue_submit2)) != null);

    var queue: Queue = .{
        ._handle = testHandle(raw.VkQueue, 0x2100),
        ._device_handle = device._handle.?,
        .queue_submit = testQueueSubmit,
        .queue_submit2 = testQueueSubmit2,
        .queue_wait_idle = testFunction(raw.PFN_vkQueueWaitIdle),
        .queue_present_khr = null,
        .queue_begin_debug_utils_label_ext = null,
        .queue_end_debug_utils_label_ext = null,
        .queue_insert_debug_utils_label_ext = null,
    };
    test_queue_submit2_result = raw.VK_ERROR_DEVICE_LOST;
    defer test_queue_submit2_result = raw.VK_SUCCESS;
    try std.testing.expectError(
        error.DeviceLost,
        queue.submit2(.{ .submits = &.{.{}} }),
    );
}

test "command pools reset generations and command buffers track pending state" {
    test_resource_result = raw.VK_SUCCESS;
    test_resource_null_handle = false;
    test_reset_command_pool_count = 0;
    test_free_command_buffer_count = 0;
    test_queue_submit_count = 0;

    var device = testDevice();
    defer device.deinit();
    var pool = try device.createCommandPool(.{
        .family_index = .fromRaw(0),
        .flags = .init(&.{.reset_command_buffer}),
    });
    defer pool.deinit();
    var command_buffer = try pool.allocateCommandBuffer(.{});
    defer command_buffer.deinit();
    const queue: Queue = .{
        ._handle = testHandle(raw.VkQueue, 0x2100),
        ._device_handle = device._handle.?,
        .queue_submit = testQueueSubmit,
        .queue_submit2 = testQueueSubmit2,
        .queue_wait_idle = testFunction(raw.PFN_vkQueueWaitIdle),
        .queue_present_khr = null,
        .queue_begin_debug_utils_label_ext = null,
        .queue_end_debug_utils_label_ext = null,
        .queue_insert_debug_utils_label_ext = null,
    };

    var wrong_device_buffer = command_buffer;
    wrong_device_buffer._device_handle = testHandle(raw.VkDevice, 0x9000);
    try std.testing.expectError(
        error.InvalidHandle,
        queue.submit(.{ .command_buffers = &.{&wrong_device_buffer} }),
    );

    try command_buffer.begin(.{});
    try command_buffer.end();
    try queue.submit(.{ .command_buffers = &.{&command_buffer} });
    try std.testing.expectError(error.InvalidOptions, command_buffer.reset(false));
    try std.testing.expectError(
        error.InvalidOptions,
        queue.submit(.{ .command_buffers = &.{&command_buffer} }),
    );
    try command_buffer.markComplete();
    try command_buffer.reset(false);

    try command_buffer.begin(.{ .flags = .init(&.{.simultaneous_use}) });
    try command_buffer.end();
    try queue.submit(.{ .command_buffers = &.{&command_buffer} });
    try queue.submit(.{ .command_buffers = &.{&command_buffer} });
    try command_buffer.markComplete();
    try std.testing.expectError(error.InvalidOptions, command_buffer.reset(false));
    try command_buffer.markComplete();

    const old_generation = pool.generation;
    try pool.reset(true);
    try std.testing.expectEqual(old_generation +% 1, pool.generation);
    try std.testing.expectEqual(@as(usize, 1), test_reset_command_pool_count);
    try command_buffer.begin(.{});
    try command_buffer.end();
    try std.testing.expectEqual(pool.generation, command_buffer._pool_generation);
}

test "secondary command buffers use typed inheritance and free idempotently" {
    test_resource_result = raw.VK_SUCCESS;
    test_resource_null_handle = false;
    test_free_command_buffer_count = 0;
    test_begin_has_inheritance = false;
    test_begin_occlusion_query = raw.VK_FALSE;

    var device = testDevice();
    defer device.deinit();
    var pool = try device.createCommandPool(.{ .family_index = .fromRaw(0) });
    defer pool.deinit();
    var secondary = try pool.allocateCommandBuffer(.{ .level = .secondary });
    try std.testing.expectEqual(
        @as(raw.VkCommandBufferLevel, raw.VK_COMMAND_BUFFER_LEVEL_SECONDARY),
        test_allocated_command_buffer_level,
    );
    try std.testing.expectError(error.InvalidOptions, secondary.begin(.{}));
    try secondary.begin(.{ .inheritance = .{ .occlusion_query_enable = true } });
    try std.testing.expect(test_begin_has_inheritance);
    try std.testing.expectEqual(raw.VK_TRUE, test_begin_occlusion_query);
    try secondary.end();

    var other_pool = try device.createCommandPool(.{ .family_index = .fromRaw(1) });
    defer other_pool.deinit();
    try std.testing.expectError(
        error.InvalidHandle,
        other_pool.freeCommandBuffer(&secondary),
    );
    try pool.freeCommandBuffer(&secondary);
    try pool.freeCommandBuffer(&secondary);
    secondary.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_free_command_buffer_count);

    var primary = try pool.allocateCommandBuffer(.{});
    defer primary.deinit();
    try std.testing.expectError(
        error.InvalidOptions,
        primary.begin(.{ .inheritance = .{} }),
    );
}

test "dynamic rendering scopes record typed attachments and end once" {
    test_resource_result = raw.VK_SUCCESS;
    test_resource_null_handle = false;
    test_begin_rendering_count = 0;
    test_end_rendering_count = 0;
    test_rendering_flags = 0;
    test_rendering_color_count = 0;

    var device = testDevice();
    defer device.deinit();
    device.dispatch.cmd_begin_rendering = testCmdBeginRendering;
    device.dispatch.cmd_end_rendering = testCmdEndRendering;
    var pool = try device.createCommandPool(.{ .family_index = .fromRaw(0) });
    defer pool.deinit();
    var command_buffer = try pool.allocateCommandBuffer(.{});
    defer command_buffer.deinit();
    try command_buffer.begin(.{});

    const view: ImageView = .{
        ._handle = testHandle(raw.VkImageView, 0x5100),
        ._device_handle = device._handle.?,
        .allocation_callbacks = null,
        .destroy_image_view = testDestroyImageView,
    };
    var scope = try command_buffer.beginRendering(.{
        .flags = .{ .suspending = true },
        .render_area = .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = 64, .height = 64 },
        },
        .color_attachments = &.{.{
            .view = &view,
            .layout = .color_attachment_optimal,
            .load = .clear,
            .clear = .{ .color = .{ .float = .{ 0, 0, 0, 1 } } },
        }},
    });
    try std.testing.expectError(error.InvalidOptions, command_buffer.end());
    try scope.end();
    try scope.end();
    try command_buffer.end();

    try std.testing.expectEqual(@as(usize, 1), test_begin_rendering_count);
    try std.testing.expectEqual(@as(usize, 1), test_end_rendering_count);
    try std.testing.expectEqual(@as(u32, 1), test_rendering_color_count);
    try std.testing.expect((test_rendering_flags & raw.VK_RENDERING_SUSPENDING_BIT) != 0);
}

test "pipeline layouts validate and record typed push constants" {
    test_resource_result = raw.VK_SUCCESS;
    test_destroy_pipeline_layout_count = 0;
    test_push_constant_count = 0;

    var device = testDevice();
    defer device.deinit();
    device.dispatch.create_pipeline_layout = testCreatePipelineLayout;
    device.dispatch.destroy_pipeline_layout = testDestroyPipelineLayout;
    device.dispatch.cmd_push_constants = testCmdPushConstants;
    const stages = ShaderStageSet.init(&.{ .vertex, .fragment });
    var layout = try device.createPipelineLayout(.{
        .push_constants = &.{.{ .stages = stages, .offset = 4, .size = 16 }},
    });
    defer layout.deinit();

    var pool = try device.createCommandPool(.{ .family_index = .fromRaw(0) });
    defer pool.deinit();
    var command_buffer = try pool.allocateCommandBuffer(.{});
    defer command_buffer.deinit();
    const Value = extern struct { x: u32, y: u32 };
    try std.testing.expectError(
        error.InvalidOptions,
        command_buffer.pushConstantsValue(&layout, stages, 4, Value{ .x = 1, .y = 2 }),
    );
    try command_buffer.begin(.{});
    try command_buffer.pushConstantsValue(&layout, stages, 4, Value{ .x = 1, .y = 2 });
    try std.testing.expectEqual(@as(usize, 1), test_push_constant_count);
    try std.testing.expectEqual(@as(u32, 4), test_push_constant_offset);
    try std.testing.expectEqual(@as(u32, @sizeOf(Value)), test_push_constant_size);
    var foreign_layout = layout;
    foreign_layout._device_handle = testHandle(raw.VkDevice, 0x9999);
    try std.testing.expectError(
        error.InvalidOptions,
        command_buffer.pushConstantsValue(&foreign_layout, stages, 4, Value{ .x = 1, .y = 2 }),
    );
    try command_buffer.end();

    layout.deinit();
    layout.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_pipeline_layout_count);
}

test "destroyed command pools invalidate their borrowed command buffers" {
    test_resource_result = raw.VK_SUCCESS;
    var device = testDevice();
    defer device.deinit();
    var pool = try device.createCommandPool(.{ .family_index = .fromRaw(0) });
    var command_buffer = try pool.allocateCommandBuffer(.{});
    pool.deinit();
    try std.testing.expectError(error.InactiveObject, command_buffer.begin(.{}));
    command_buffer.deinit();
    command_buffer.deinit();
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
    const swapchain_images = try swapchain.imagesInto(&image_storage);
    try std.testing.expectEqual(@as(usize, 2), swapchain_images.len);
    try std.testing.expectEqual(@as(u32, 1), swapchain_images[1].index.toRaw());

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
        .queue_submit2 = testQueueSubmit2,
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
    const config = debug_utils.Config.fromHandler(
        struct {
            fn handle(_: debug_utils.Message) void {}
        }.handle,
        .{},
    );

    var messenger = try instance.createDebugMessenger(config, null);
    messenger.deinit();
    messenger.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_messenger_count);
    try std.testing.expectError(error.InactiveObject, messenger.rawHandle());

    test_create_null_handle = true;
    try std.testing.expectError(
        error.InvalidHandle,
        instance.createDebugMessenger(config, null),
    );

    test_create_null_handle = false;
    test_create_result = raw.VK_ERROR_INITIALIZATION_FAILED;
    test_destroy_messenger_count = 0;
    try std.testing.expectError(
        error.InitializationFailed,
        instance.createDebugMessenger(config, null),
    );
    try std.testing.expectEqual(@as(usize, 1), test_destroy_messenger_count);

    test_create_result = raw.VK_SUCCESS;
    test_missing_command = .destroy_messenger;
    test_create_messenger_count = 0;
    try std.testing.expectError(
        error.MissingCommand,
        instance.createDebugMessenger(config, null),
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
    try device.setObjectName(&device, "test-device");
    try std.testing.expectEqual(
        @as(raw.VkObjectType, @intCast(raw.VK_OBJECT_TYPE_DEVICE)),
        test_named_object_type,
    );
    try std.testing.expectEqual(@as(u64, 0x2000), test_named_object_handle);
    const queue: Queue = .{
        ._handle = testHandle(raw.VkQueue, 0x2100),
        ._device_handle = testHandle(raw.VkDevice, 0x2000),
        .queue_submit = testFunction(raw.PFN_vkQueueSubmit),
        .queue_submit2 = testQueueSubmit2,
        .queue_wait_idle = testFunction(raw.PFN_vkQueueWaitIdle),
        .queue_present_khr = null,
        .queue_begin_debug_utils_label_ext = null,
        .queue_end_debug_utils_label_ext = null,
        .queue_insert_debug_utils_label_ext = null,
    };
    try device.setObjectName(&queue, "test-queue");
    try std.testing.expectEqual(
        @as(raw.VkObjectType, @intCast(raw.VK_OBJECT_TYPE_QUEUE)),
        test_named_object_type,
    );
    try std.testing.expectEqual(@as(u64, 0x2100), test_named_object_handle);
    test_name_result = raw.VK_ERROR_OUT_OF_HOST_MEMORY;
    try std.testing.expectError(
        error.OutOfHostMemory,
        device.setObjectName(&device, "test-device"),
    );
    device.dispatch.set_debug_utils_object_name_ext = null;
    try std.testing.expectError(
        error.MissingCommand,
        device.setObjectName(&device, "test-device"),
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

test "buffer wrappers cover creation views addresses sharing and checked binding" {
    test_resource_result = raw.VK_SUCCESS;
    test_resource_null_handle = false;
    test_destroy_buffer_count = 0;
    test_destroy_buffer_view_count = 0;
    test_free_memory_count = 0;
    test_bind_buffer_count = 0;
    test_name_result = raw.VK_SUCCESS;
    var device = testDevice();
    defer device.deinit();

    var buffer = try device.createBuffer(.{
        .size = .fromBytes(2048),
        .usage = .init(&.{ .vertex_buffer, .uniform_texel_buffer }),
        .queue_family_indices = &.{ .fromRaw(1), .fromRaw(2) },
        .opaque_capture_address = buffers.OpaqueCaptureAddress.fromRaw(0x9000).?,
    });
    defer buffer.deinit();
    try std.testing.expectEqual(@as(u64, 2048), test_buffer_size);
    try std.testing.expectEqual(
        @as(raw.VkSharingMode, @intCast(raw.VK_SHARING_MODE_CONCURRENT)),
        test_buffer_sharing_mode,
    );
    try std.testing.expectEqual(@as(u32, 2), test_buffer_queue_family_count);
    try std.testing.expect((test_buffer_usage & raw.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT) != 0);
    try std.testing.expect(
        (test_buffer_create_flags & raw.VK_BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT) != 0,
    );
    try std.testing.expectEqual(@as(u64, 0x9000), test_buffer_capture_address);

    const requirements = try buffer.memoryRequirements();
    try std.testing.expectEqual(@as(u64, 1024), requirements.size.bytes());
    try std.testing.expectEqual(@as(u64, 256), requirements.alignment.bytes());
    try std.testing.expect(requirements.supportsMemoryType(.fromRaw(0)));
    try std.testing.expect(!requirements.supportsMemoryType(.fromRaw(1)));
    try std.testing.expectEqual(@as(u64, 0x7000), (try buffer.deviceAddress()).?.toRaw());
    try std.testing.expectEqual(
        @as(u64, 0x8000),
        (try buffer.opaqueCaptureAddress()).?.toRaw(),
    );
    try device.setObjectName(&buffer, "vertex-buffer");
    try std.testing.expectEqual(
        @as(raw.VkObjectType, @intCast(raw.VK_OBJECT_TYPE_BUFFER)),
        test_named_object_type,
    );

    var view = try device.createBufferView(&buffer, .{
        .format = .r32_uint,
        .offset = .fromBytes(256),
        .range = .{ .bytes = .fromBytes(512) },
    });
    view.deinit();
    view.deinit();
    try std.testing.expectEqual(@as(u64, 256), test_buffer_view_offset);
    try std.testing.expectEqual(@as(u64, 512), test_buffer_view_range);
    try std.testing.expectEqual(@as(usize, 1), test_destroy_buffer_view_count);

    var allocation = try device.allocateMemory(.{
        .size = .fromBytes(2048),
        .memory_type_index = .fromRaw(0),
    });
    defer allocation.deinit();
    var foreign_allocation = allocation;
    foreign_allocation._device_handle = testHandle(raw.VkDevice, 0x9999);
    try std.testing.expectError(
        error.InvalidHandle,
        buffer.bindMemory(&foreign_allocation, .zero),
    );
    var incompatible_allocation = allocation;
    incompatible_allocation.memory_type_index = .fromRaw(1);
    try std.testing.expectError(
        error.InvalidOptions,
        buffer.bindMemory(&incompatible_allocation, .zero),
    );
    try std.testing.expectError(
        error.InvalidOptions,
        buffer.bindMemory(&allocation, .fromBytes(1)),
    );
    try std.testing.expectEqual(@as(usize, 0), test_bind_buffer_count);
    try buffer.bindMemory(&allocation, .fromBytes(256));
    try std.testing.expectEqual(@as(usize, 1), test_bind_buffer_count);
    try std.testing.expectEqual(@as(u64, 256), test_bound_memory_offset);
    try std.testing.expectError(
        error.InvalidOptions,
        buffer.bindMemory(&allocation, .fromBytes(256)),
    );

    buffer.deinit();
    buffer.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_buffer_count);
}

test "buffer and allocation creation roll back provisional handles" {
    test_resource_null_handle = false;
    test_resource_result = raw.VK_ERROR_OUT_OF_DEVICE_MEMORY;
    test_destroy_buffer_count = 0;
    test_free_memory_count = 0;
    var device = testDevice();
    defer device.deinit();

    try std.testing.expectError(
        error.OutOfDeviceMemory,
        device.createBuffer(.{
            .size = .fromBytes(64),
            .usage = .init(&.{.storage_buffer}),
        }),
    );
    try std.testing.expectEqual(@as(usize, 1), test_destroy_buffer_count);
    try std.testing.expectError(
        error.OutOfDeviceMemory,
        device.allocateMemory(.{
            .size = .fromBytes(64),
            .memory_type_index = .fromRaw(0),
        }),
    );
    try std.testing.expectEqual(@as(usize, 1), test_free_memory_count);
    test_resource_result = raw.VK_SUCCESS;
}

test "mapped memory bounds cache ranges and supports legacy and map2 paths" {
    test_resource_result = raw.VK_SUCCESS;
    test_resource_null_handle = false;
    test_map_result = raw.VK_SUCCESS;
    test_unmap_result = raw.VK_SUCCESS;
    test_map_count = 0;
    test_unmap_count = 0;
    test_cache_offset = 0;
    test_cache_size = 0;

    var device = testDevice();
    defer device.deinit();
    device.dispatch.map_memory = testMapMemory;
    device.dispatch.unmap_memory = testUnmapMemory;
    device.dispatch.flush_mapped_memory_ranges = testCacheMemory;
    device.dispatch.invalidate_mapped_memory_ranges = testCacheMemory;
    var allocation = try device.allocateMemory(.{
        .size = .fromBytes(256),
        .memory_type_index = .fromRaw(0),
        .non_coherent_atom_size = .fromBytes(64),
    });
    defer allocation.deinit();

    var mapped = try allocation.map(.{
        .offset = .fromBytes(3),
        .range = .{ .bytes = .fromBytes(10) },
    });
    try std.testing.expectEqual(@as(usize, 10), (try mapped.bytes()).len);
    try mapped.flush();
    try std.testing.expectEqual(@as(u64, 0), test_cache_offset);
    try std.testing.expectEqual(@as(u64, 64), test_cache_size);
    try mapped.invalidate();
    try mapped.unmap();
    try std.testing.expectError(error.InactiveObject, mapped.bytes());
    try std.testing.expectError(error.InvalidOptions, allocation.unmap());
    mapped.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_unmap_count);

    device.dispatch.map_memory2 = testMapMemory2;
    device.dispatch.unmap_memory2 = testUnmapMemory2;
    var map2_allocation = try device.allocateMemory(.{
        .size = .fromBytes(256),
        .memory_type_index = .fromRaw(0),
    });
    defer map2_allocation.deinit();
    var whole = try map2_allocation.map(.{});
    try std.testing.expectEqual(@as(usize, 256), (try whole.bytes()).len);
    try whole.unmap();

    test_map_result = raw.VK_ERROR_DEVICE_LOST;
    defer test_map_result = raw.VK_SUCCESS;
    try std.testing.expectError(error.DeviceLost, map2_allocation.map(.{}));
    try std.testing.expectEqual(@as(usize, 3), test_map_count);
    try std.testing.expectEqual(@as(usize, 2), test_unmap_count);
}

test "allocated buffer convenience owns and binds both resources" {
    test_resource_result = raw.VK_SUCCESS;
    test_resource_null_handle = false;
    test_destroy_buffer_count = 0;
    test_free_memory_count = 0;
    test_bind_buffer_count = 0;
    var device = testDevice();
    defer device.deinit();

    var allocated = try device.createAllocatedBuffer(.{
        .buffer = .{
            .size = .fromBytes(1024),
            .usage = .init(&.{ .transfer_src, .uniform_buffer }),
        },
        .memory = .{ .memory_type_index = .fromRaw(0) },
    });
    try std.testing.expectEqual(@as(u64, 1024), test_allocated_memory_size);
    try std.testing.expectEqual(@as(u32, 0), test_allocated_memory_type);
    try std.testing.expectEqual(@as(usize, 1), test_bind_buffer_count);
    allocated.deinit();
    allocated.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_buffer_count);
    try std.testing.expectEqual(@as(usize, 1), test_free_memory_count);
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

    const unknown_feature: raw.VkFormatFeatureFlags = @as(raw.VkFormatFeatureFlags, 1) << 31;
    test_format_properties.bufferFeatures |= unknown_feature;
    const format2 = try physical_device.formatProperties2(.b8g8r8a8_srgb);
    try std.testing.expect(format2.buffer_features.contains(.vertex_buffer));
    try std.testing.expectEqual(
        test_format_properties.bufferFeatures,
        format2.buffer_features.toRaw(),
    );

    const image = (try physical_device.imageFormatProperties(.{
        .format = .b8g8r8a8_srgb,
        .image_type = ._2d,
        .tiling = .optimal,
        .usage = .init(&.{ .sampled, .color_attachment }),
    })).?;
    try std.testing.expectEqual(@as(u32, 4096), image.extent_max.width);
    try std.testing.expectEqual(@as(u32, 13), image.mip_level_count_max);
    try std.testing.expect(image.sample_counts.contains(._4));

    const image2 = (try physical_device.imageFormatProperties2(.{
        .format = .b8g8r8a8_srgb,
        .image_type = ._2d,
        .tiling = .optimal,
        .usage = .init(&.{ .sampled, .color_attachment }),
    })).?;
    try std.testing.expectEqual(@as(u32, 256), image2.properties.array_layer_count_max);
    try std.testing.expect(image2.external_memory == null);

    test_external_memory_properties = .{
        .externalMemoryFeatures = @intCast(
            raw.VK_EXTERNAL_MEMORY_FEATURE_EXPORTABLE_BIT |
                raw.VK_EXTERNAL_MEMORY_FEATURE_IMPORTABLE_BIT,
        ),
        .exportFromImportedHandleTypes = @intCast(
            raw.VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT,
        ),
        .compatibleHandleTypes = @intCast(
            raw.VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT |
                raw.VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT,
        ),
    };
    test_external_memory_handle_type = 0;
    test_drm_format_modifier = 0;
    test_drm_queue_family_count = 0;
    const chained = (try physical_device.imageFormatProperties2(.{
        .format = .b8g8r8a8_srgb,
        .image_type = ._2d,
        .tiling = .drm_format_modifier_ext,
        .usage = .init(&.{.sampled}),
        .external_memory_handle_type = .opaque_fd,
        .drm_format_modifier = .{
            .modifier = 0xabcd,
            .queue_family_indices = &.{ .fromRaw(2), .fromRaw(5) },
        },
    })).?;
    try std.testing.expectEqual(
        ExternalMemoryHandleTypeBit.opaque_fd.toRaw(),
        test_external_memory_handle_type,
    );
    try std.testing.expectEqual(@as(u64, 0xabcd), test_drm_format_modifier);
    try std.testing.expectEqual(
        @as(raw.VkSharingMode, @intCast(raw.VK_SHARING_MODE_CONCURRENT)),
        test_drm_sharing_mode,
    );
    try std.testing.expectEqual(@as(u32, 2), test_drm_queue_family_count);
    try std.testing.expect(chained.external_memory.?.features.contains(.exportable));
    try std.testing.expect(chained.external_memory.?.features.contains(.importable));
    try std.testing.expect(
        chained.external_memory.?.compatible_handle_types.contains(.dma_buf_ext),
    );
    try std.testing.expectError(
        error.InvalidOptions,
        physical_device.imageFormatProperties2(.{
            .format = .b8g8r8a8_srgb,
            .image_type = ._2d,
            .tiling = .optimal,
            .usage = .init(&.{.sampled}),
            .drm_format_modifier = .{ .modifier = 1 },
        }),
    );
    try std.testing.expectError(
        error.InvalidOptions,
        physical_device.imageFormatProperties2(.{
            .format = .b8g8r8a8_srgb,
            .image_type = ._2d,
            .tiling = .drm_format_modifier_ext,
            .usage = .init(&.{.sampled}),
            .drm_format_modifier = .{
                .modifier = 1,
                .queue_family_indices = &.{.fromRaw(2)},
            },
        }),
    );

    test_drm_format_modifier_properties = .{
        .{
            .drmFormatModifier = 0xabcd,
            .drmFormatModifierPlaneCount = 2,
            .drmFormatModifierTilingFeatures = @intCast(
                raw.VK_FORMAT_FEATURE_SAMPLED_IMAGE_BIT,
            ),
        },
        .{
            .drmFormatModifier = 0xef01,
            .drmFormatModifierPlaneCount = 1,
            .drmFormatModifierTilingFeatures = @intCast(
                raw.VK_FORMAT_FEATURE_COLOR_ATTACHMENT_BIT,
            ),
        },
    };
    test_drm_format_modifier_property_count = 2;
    try std.testing.expectEqual(
        @as(u32, 2),
        try physical_device.drmFormatModifierPropertyCount(.b8g8r8a8_srgb),
    );
    var drm_storage: [2]DrmFormatModifierProperties = undefined;
    const drm_properties = try physical_device.drmFormatModifierPropertiesInto(
        .b8g8r8a8_srgb,
        &drm_storage,
    );
    try std.testing.expectEqual(@as(usize, 2), drm_properties.len);
    try std.testing.expectEqual(@as(u64, 0xabcd), drm_properties[0].modifier);
    try std.testing.expectEqual(@as(u32, 2), drm_properties[0].plane_count);
    try std.testing.expect(drm_properties[1].tiling_features.contains(.color_attachment));
    var short_drm_storage: [1]DrmFormatModifierProperties = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        physical_device.drmFormatModifierPropertiesInto(
            .b8g8r8a8_srgb,
            &short_drm_storage,
        ),
    );
    const allocated_drm = try physical_device.drmFormatModifierProperties(
        std.testing.allocator,
        .b8g8r8a8_srgb,
    );
    defer std.testing.allocator.free(allocated_drm);
    try std.testing.expectEqual(@as(usize, 2), allocated_drm.len);

    test_sparse_image_format_properties = .{
        .{
            .aspectMask = @intCast(raw.VK_IMAGE_ASPECT_COLOR_BIT),
            .imageGranularity = .{ .width = 64, .height = 64, .depth = 1 },
            .flags = @intCast(raw.VK_SPARSE_IMAGE_FORMAT_SINGLE_MIPTAIL_BIT),
        },
        .{
            .aspectMask = @intCast(raw.VK_IMAGE_ASPECT_METADATA_BIT),
            .imageGranularity = .{ .width = 128, .height = 64, .depth = 1 },
            .flags = 0,
        },
    };
    test_sparse_image_format_property_count = 2;
    const sparse_options: SparseImageFormatOptions = .{
        .format = .b8g8r8a8_srgb,
        .image_type = ._2d,
        .sample_count = ._1,
        .usage = .init(&.{.sampled}),
        .tiling = .optimal,
    };
    try std.testing.expectEqual(
        @as(u32, 2),
        try physical_device.sparseImageFormatPropertyCount(sparse_options),
    );
    var sparse_storage: [2]SparseImageFormatProperties = undefined;
    const sparse = try physical_device.sparseImageFormatPropertiesInto(
        sparse_options,
        &sparse_storage,
    );
    try std.testing.expectEqual(@as(usize, 2), sparse.len);
    try std.testing.expect(sparse[0].aspect_mask.contains(.color));
    try std.testing.expect(sparse[0].flags.contains(.single_miptail));
    try std.testing.expectEqual(@as(u32, 128), sparse[1].image_granularity.width);
    var short_sparse_storage: [1]SparseImageFormatProperties = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        physical_device.sparseImageFormatPropertiesInto(
            sparse_options,
            &short_sparse_storage,
        ),
    );
    const allocated_sparse = try physical_device.sparseImageFormatProperties(
        std.testing.allocator,
        sparse_options,
    );
    defer std.testing.allocator.free(allocated_sparse);
    try std.testing.expectEqual(@as(usize, 2), allocated_sparse.len);

    test_image_format_result = raw.VK_ERROR_FORMAT_NOT_SUPPORTED;
    try std.testing.expect((try physical_device.imageFormatProperties(.{
        .format = .b8g8r8a8_srgb,
        .image_type = ._2d,
        .tiling = .optimal,
        .usage = .init(&.{.sampled}),
    })) == null);
    try std.testing.expect((try physical_device.imageFormatProperties2(.{
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
    try std.testing.expectError(
        error.OutOfDeviceMemory,
        physical_device.imageFormatProperties2(.{
            .format = .b8g8r8a8_srgb,
            .image_type = ._2d,
            .tiling = .optimal,
            .usage = .init(&.{.sampled}),
        }),
    );
    test_image_format_result = raw.VK_SUCCESS;

    var missing = physical_device;
    missing.dispatch.get_physical_device_format_properties2 = null;
    missing.dispatch.get_physical_device_image_format_properties2 = null;
    missing.dispatch.get_physical_device_sparse_image_format_properties2 = null;
    try std.testing.expectError(
        error.MissingCommand,
        missing.formatProperties2(.b8g8r8a8_srgb),
    );
    try std.testing.expectError(
        error.MissingCommand,
        missing.imageFormatProperties2(.{
            .format = .b8g8r8a8_srgb,
            .image_type = ._2d,
            .tiling = .optimal,
            .usage = .init(&.{.sampled}),
        }),
    );
    try std.testing.expectError(
        error.MissingCommand,
        missing.sparseImageFormatPropertyCount(sparse_options),
    );
}
