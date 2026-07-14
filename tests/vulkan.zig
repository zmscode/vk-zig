const std = @import("std");
const vk = @import("vulkan");

fn debugCallback(
    _: vk.raw.VkDebugUtilsMessageSeverityFlagBitsEXT,
    _: vk.raw.VkDebugUtilsMessageTypeFlagsEXT,
    _: [*c]const vk.raw.VkDebugUtilsMessengerCallbackDataEXT,
    _: ?*anyopaque,
) callconv(.c) vk.raw.VkBool32 {
    return vk.raw.VK_FALSE;
}

var typed_handler_count: u32 = 0;

fn typedDebugMessage(_: vk.ext.debug_utils.Message) void {
    typed_handler_count += 1;
}

fn abortDebugMessage(_: vk.ext.debug_utils.Message) vk.ext.debug_utils.HandlerResult {
    return .abort;
}

const HandlerContext = struct {
    count: u32 = 0,

    fn handle(
        context: *HandlerContext,
        _: vk.ext.debug_utils.Message,
    ) vk.ext.debug_utils.HandlerResult {
        context.count += 1;
        return .continue_;
    }
};

var owned_debug_extension_enabled = false;
var owned_debug_create_info_chained = false;
var owned_debug_callback_continued = false;
var owned_debug_create_count: u32 = 0;
var owned_debug_destroy_count: u32 = 0;
var owned_instance_destroy_count: u32 = 0;
var owned_destroy_order: [2]u8 = .{ 0, 0 };
var owned_destroy_order_count: u32 = 0;

fn fakeUnused() callconv(.c) void {}

fn fakeNameEquals(name: [*c]const u8, expected: []const u8) bool {
    if (name == null) return false;
    const sentinel_name: [*:0]const u8 = @ptrCast(name);
    return std.mem.eql(u8, std.mem.span(sentinel_name), expected);
}

fn fakeCreateInstance(
    create_info: [*c]const vk.raw.VkInstanceCreateInfo,
    _: [*c]const vk.raw.VkAllocationCallbacks,
    output: [*c]vk.raw.VkInstance,
) callconv(.c) vk.raw.VkResult {
    const info = create_info[0];
    for (0..info.enabledExtensionCount) |index| {
        if (fakeNameEquals(
            info.ppEnabledExtensionNames[index],
            vk.extension.ext_debug_utils.name,
        )) {
            owned_debug_extension_enabled = true;
        }
    }
    if (info.pNext) |next| {
        const debug_info: *const vk.raw.VkDebugUtilsMessengerCreateInfoEXT =
            @ptrCast(@alignCast(next));
        owned_debug_create_info_chained =
            debug_info.sType == vk.raw.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT and
            debug_info.pfnUserCallback != null;
        if (debug_info.pfnUserCallback) |callback| {
            var callback_data: vk.raw.VkDebugUtilsMessengerCallbackDataEXT = .{
                .sType = vk.raw.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CALLBACK_DATA_EXT,
                .pMessage = "instance creation message",
            };
            const result = callback(
                vk.raw.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT,
                vk.raw.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT,
                &callback_data,
                debug_info.pUserData,
            );
            owned_debug_callback_continued = result == vk.raw.VK_FALSE;
        }
    }
    output[0] = @ptrFromInt(0x1000);
    return vk.raw.VK_SUCCESS;
}

fn fakeGetDeviceProcAddr(
    _: vk.raw.VkDevice,
    _: [*c]const u8,
) callconv(.c) vk.raw.PFN_vkVoidFunction {
    return null;
}

fn fakeDestroyInstance(
    _: vk.raw.VkInstance,
    _: [*c]const vk.raw.VkAllocationCallbacks,
) callconv(.c) void {
    owned_instance_destroy_count += 1;
    owned_destroy_order[owned_destroy_order_count] = 2;
    owned_destroy_order_count += 1;
}

fn fakeCreateDebugMessenger(
    _: vk.raw.VkInstance,
    _: [*c]const vk.raw.VkDebugUtilsMessengerCreateInfoEXT,
    _: [*c]const vk.raw.VkAllocationCallbacks,
    output: [*c]vk.raw.VkDebugUtilsMessengerEXT,
) callconv(.c) vk.raw.VkResult {
    owned_debug_create_count += 1;
    output[0] = @ptrFromInt(0x2000);
    return vk.raw.VK_SUCCESS;
}

fn fakeDestroyDebugMessenger(
    _: vk.raw.VkInstance,
    _: vk.raw.VkDebugUtilsMessengerEXT,
    _: [*c]const vk.raw.VkAllocationCallbacks,
) callconv(.c) void {
    owned_debug_destroy_count += 1;
    owned_destroy_order[owned_destroy_order_count] = 1;
    owned_destroy_order_count += 1;
}

fn fakeGetInstanceProcAddr(
    _: vk.raw.VkInstance,
    name: [*c]const u8,
) callconv(.c) vk.raw.PFN_vkVoidFunction {
    if (fakeNameEquals(name, "vkGetDeviceProcAddr")) {
        return @ptrCast(&fakeGetDeviceProcAddr);
    }
    if (fakeNameEquals(name, "vkDestroyInstance")) {
        return @ptrCast(&fakeDestroyInstance);
    }
    if (fakeNameEquals(name, "vkCreateDebugUtilsMessengerEXT")) {
        return @ptrCast(&fakeCreateDebugMessenger);
    }
    if (fakeNameEquals(name, "vkDestroyDebugUtilsMessengerEXT")) {
        return @ptrCast(&fakeDestroyDebugMessenger);
    }
    return @ptrCast(&fakeUnused);
}

test "raw bindings contain core Vulkan declarations" {
    try std.testing.expect(@hasDecl(vk.raw, "VkInstance"));
    try std.testing.expect(@hasDecl(vk.raw, "VkDevice"));
    try std.testing.expect(@hasDecl(vk.raw, "PFN_vkGetInstanceProcAddr"));
    try std.testing.expect(@hasDecl(vk.raw, "PFN_vkCreateInstance"));
    try std.testing.expect(@hasDecl(vk.raw, "VK_API_VERSION_1_4"));
}

test "default Apple builds include Metal surface declarations" {
    if (vk.platform != .metal) return;
    try std.testing.expect(@hasDecl(vk.raw, "VkMetalSurfaceCreateInfoEXT"));
    try std.testing.expect(@hasDecl(vk.raw, "PFN_vkCreateMetalSurfaceEXT"));
}

test "API versions round trip" {
    const expected: vk.Version = .{
        .variant = 0,
        .major = 1,
        .minor = 4,
        .patch = 356,
    };
    const actual = vk.Version.decode(expected.encode());
    try std.testing.expectEqual(expected, actual);
}

test "wrapper exposes typed Vulkan lifecycle objects" {
    try std.testing.expect(@hasDecl(vk, "Loader"));
    try std.testing.expect(@hasDecl(vk.Loader, "initFromPath"));
    try std.testing.expect(@hasDecl(vk, "Entry"));
    try std.testing.expect(@hasDecl(vk, "Instance"));
    try std.testing.expect(@hasDecl(vk, "PhysicalDevice"));
    try std.testing.expect(@hasDecl(vk, "Device"));
    try std.testing.expect(@hasDecl(vk, "Queue"));
    try std.testing.expect(@hasDecl(vk, "Surface"));
    try std.testing.expect(@hasDecl(vk.ext.debug_utils, "Messenger"));
    try std.testing.expect(@hasDecl(vk.ext.debug_utils, "MessengerConfig"));
    try std.testing.expect(@hasDecl(vk.ext.debug_utils, "HandlerResult"));
}

test "generated commands bind scope, name, and function type" {
    const CreateInstance = @TypeOf(vk.command.create_instance);
    const DestroySurface = @TypeOf(vk.command.destroy_surface_khr);
    const QueueSubmit = @TypeOf(vk.command.queue_submit);
    try std.testing.expectEqual(vk.command.Scope.global, CreateInstance.scope);
    try std.testing.expectEqual(vk.command.Scope.instance, DestroySurface.scope);
    try std.testing.expectEqual(vk.command.Scope.device, QueueSubmit.scope);
    try std.testing.expectEqualStrings("vkCreateInstance", CreateInstance.name);
    try std.testing.expect(CreateInstance.Function ==
        vk.CommandFunction(vk.raw.PFN_vkCreateInstance));
}

test "generated extension names compose without duplicates" {
    try std.testing.expectEqualStrings("VK_KHR_surface", vk.extension.khr_surface.name);
    try std.testing.expectEqualStrings("VK_KHR_swapchain", vk.extension.khr_swapchain.name);
    try std.testing.expectEqualStrings("VK_EXT_debug_utils", vk.extension.ext_debug_utils.name);

    var extensions: vk.ExtensionSet(4) = .{};
    try extensions.append(vk.extension.khr_surface.name);
    try extensions.append(vk.extension.khr_surface.name);
    try extensions.appendAll(&.{
        vk.extension.ext_debug_utils.name,
        vk.extension.khr_swapchain.name,
    });
    try std.testing.expectEqual(@as(usize, 3), extensions.slice().len);
    try std.testing.expect(extensions.contains("VK_EXT_debug_utils"));
    try std.testing.expect(!extensions.contains("VK_EXT_missing"));
    try extensions.append("VK_EXT_fourth");
    try std.testing.expectError(error.CountOverflow, extensions.append("VK_EXT_fifth"));
}

test "diagnostic availability recognizes names and resolves independent requests" {
    var validation_layer: vk.raw.VkLayerProperties = .{};
    @memcpy(
        validation_layer.layerName[0..vk.layer.khronos_validation.name.len],
        vk.layer.khronos_validation.name,
    );
    var debug_extension: vk.raw.VkExtensionProperties = .{};
    @memcpy(
        debug_extension.extensionName[0..vk.extension.ext_debug_utils.name.len],
        vk.extension.ext_debug_utils.name,
    );

    const available = vk.diagnostics.detect(.{
        .validation = true,
        .debug_messenger = true,
        .gpu_labels = true,
    }, &.{validation_layer}, &.{debug_extension});
    try std.testing.expect(available.validation_enabled);
    try std.testing.expect(available.debug_utils_enabled);
    try std.testing.expect(available.debug_messenger_enabled);
    try std.testing.expect(available.gpu_labels_enabled);

    const missing_debug_utils = vk.diagnostics.resolve(.{
        .validation = true,
        .debug_messenger = true,
        .gpu_labels = true,
    }, true, false);
    try std.testing.expect(missing_debug_utils.validation_enabled);
    try std.testing.expect(!missing_debug_utils.debug_utils_enabled);
    try std.testing.expect(!missing_debug_utils.debug_messenger_enabled);
    try std.testing.expect(!missing_debug_utils.gpu_labels_enabled);

    const missing_validation = vk.diagnostics.resolve(.{
        .validation = true,
        .debug_messenger = true,
    }, false, true);
    try std.testing.expect(!missing_validation.validation_enabled);
    try std.testing.expect(missing_validation.debug_utils_enabled);
    try std.testing.expect(missing_validation.debug_messenger_enabled);

    const labels_without_messenger = vk.diagnostics.resolve(.{
        .gpu_labels = true,
    }, true, true);
    try std.testing.expect(!labels_without_messenger.validation_enabled);
    try std.testing.expect(labels_without_messenger.debug_utils_enabled);
    try std.testing.expect(!labels_without_messenger.debug_messenger_enabled);
    try std.testing.expect(labels_without_messenger.gpu_labels_enabled);

    const disabled = vk.diagnostics.resolve(.{}, true, true);
    try std.testing.expect(!disabled.validation_enabled);
    try std.testing.expect(!disabled.debug_utils_enabled);
    try std.testing.expect(!disabled.debug_messenger_enabled);
    try std.testing.expect(!disabled.gpu_labels_enabled);
}

test "typed queue capabilities and memory selection avoid raw bit arithmetic" {
    const graphics_transfer: vk.QueueFamily = .{
        .index = 3,
        .properties = .{
            .queueFlags = @intCast(
                vk.raw.VK_QUEUE_GRAPHICS_BIT | vk.raw.VK_QUEUE_TRANSFER_BIT,
            ),
            .queueCount = 2,
        },
    };
    try std.testing.expect(graphics_transfer.supports(.graphics));
    try std.testing.expect(graphics_transfer.supports(.transfer));
    try std.testing.expect(!graphics_transfer.supports(.compute));
    try std.testing.expectEqual(@as(u32, 2), graphics_transfer.queueCount());

    var memory: vk.raw.VkPhysicalDeviceMemoryProperties = .{};
    memory.memoryTypeCount = 3;
    memory.memoryTypes[0].propertyFlags = vk.raw.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT;
    memory.memoryTypes[1].propertyFlags = @intCast(
        vk.raw.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
            vk.raw.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    );
    memory.memoryTypes[2].propertyFlags = vk.raw.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
    try std.testing.expectEqual(@as(u32, 1), try vk.selectMemoryTypeIndex(memory, .{
        .type_bits = 0b111,
        .required_flags = vk.raw.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
        .preferred_flags = vk.raw.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    }));
    try std.testing.expectError(error.MemoryTypeNotFound, vk.selectMemoryTypeIndex(memory, .{
        .type_bits = 0b011,
        .required_flags = vk.raw.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
    }));
}

test "debug utility options produce reusable callback and label views" {
    const messenger_options: vk.ext.debug_utils.MessengerOptions = .{
        .callback = debugCallback,
    };
    const messenger_info = messenger_options.createInfo();
    try std.testing.expectEqual(
        @as(vk.raw.VkStructureType, @intCast(
            vk.raw.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        )),
        messenger_info.sType,
    );
    try std.testing.expect(messenger_info.pfnUserCallback != null);
    try std.testing.expectEqual(
        vk.ext.debug_utils.severity_flags.warning_and_error,
        messenger_info.messageSeverity,
    );
    try std.testing.expectEqual(
        vk.ext.debug_utils.message_type_flags.standard,
        messenger_info.messageType,
    );
    try std.testing.expect(
        (messenger_info.messageSeverity & vk.ext.debug_utils.severity_flags.info) == 0,
    );
    try std.testing.expect(
        (messenger_info.messageSeverity & vk.ext.debug_utils.severity_flags.verbose) == 0,
    );

    const label = (vk.ext.debug_utils.LabelOptions{
        .name = "frame",
        .color = .{ 1.0, 0.5, 0.25, 1.0 },
    }).createInfo();
    try std.testing.expectEqualStrings("frame", std.mem.span(label.pLabelName));
    try std.testing.expectEqual(@as(f32, 0.5), label.color[1]);

    var callback_data: vk.raw.VkDebugUtilsMessengerCallbackDataEXT = .{
        .sType = vk.raw.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CALLBACK_DATA_EXT,
        .pMessageIdName = "validation-id",
        .pMessage = "validation message",
    };
    const message = vk.ext.debug_utils.Message.fromCallback(
        vk.raw.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        vk.raw.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT,
        &callback_data,
    ).?;
    try std.testing.expect(message.isError());
    try std.testing.expect(!message.isWarning());
    try std.testing.expectEqualStrings("validation-id", message.idName().?);
    try std.testing.expectEqualStrings("validation message", message.text().?);
    try std.testing.expectEqual(@as(usize, 0), message.objects().len);

    typed_handler_count = 0;
    const typed_config = vk.ext.debug_utils.MessengerConfig.fromHandler(
        typedDebugMessage,
        .{},
    );
    try std.testing.expectEqual(
        vk.ext.debug_utils.HandlerResult.continue_,
        typed_config.dispatch(message),
    );
    try std.testing.expectEqual(@as(u32, 1), typed_handler_count);

    const abort_config = vk.ext.debug_utils.MessengerConfig.fromHandler(
        abortDebugMessage,
        .{},
    );
    try std.testing.expectEqual(
        vk.ext.debug_utils.HandlerResult.abort,
        abort_config.dispatch(message),
    );

    var context: HandlerContext = .{};
    const context_config = vk.ext.debug_utils.MessengerConfig.fromHandlerWithContext(
        &context,
        .{},
        HandlerContext.handle,
    );
    try std.testing.expectEqual(
        vk.ext.debug_utils.HandlerResult.continue_,
        context_config.dispatch(message),
    );
    try std.testing.expectEqual(@as(u32, 1), context.count);

    const instance_options: vk.InstanceOptions = .{ .debug_messenger = typed_config };
    try std.testing.expect(instance_options.debug_messenger != null);
}

test "instance owns typed debug messenger lifecycle" {
    owned_debug_extension_enabled = false;
    owned_debug_create_info_chained = false;
    owned_debug_callback_continued = false;
    owned_debug_create_count = 0;
    owned_debug_destroy_count = 0;
    owned_instance_destroy_count = 0;
    owned_destroy_order = .{ 0, 0 };
    owned_destroy_order_count = 0;

    const entry: vk.Entry = .{
        .get_instance_proc_addr = fakeGetInstanceProcAddr,
        .create_instance = fakeCreateInstance,
        .enumerate_instance_version = null,
        .enumerate_instance_extension_properties = @ptrCast(&fakeUnused),
        .enumerate_instance_layer_properties = @ptrCast(&fakeUnused),
    };
    var context: HandlerContext = .{};
    const messenger_config = vk.ext.debug_utils.MessengerConfig.fromHandlerWithContext(
        &context,
        .{},
        HandlerContext.handle,
    );
    var instance = try entry.createInstance(.{
        .debug_messenger = messenger_config,
    });

    try std.testing.expect(owned_debug_extension_enabled);
    try std.testing.expect(owned_debug_create_info_chained);
    try std.testing.expect(owned_debug_callback_continued);
    try std.testing.expectEqual(@as(u32, 1), context.count);
    try std.testing.expectEqual(@as(u32, 1), owned_debug_create_count);
    try std.testing.expect(instance.debugMessengerActive());

    instance.deinit();
    instance.deinit();
    try std.testing.expect(!instance.debugMessengerActive());
    try std.testing.expectEqual(@as(u32, 1), owned_debug_destroy_count);
    try std.testing.expectEqual(@as(u32, 1), owned_instance_destroy_count);
    try std.testing.expectEqual(@as(u32, 2), owned_destroy_order_count);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2 }, &owned_destroy_order);
}

test "bounded property names and support checks do not allocate" {
    var extension: vk.raw.VkExtensionProperties = .{};
    @memcpy(extension.extensionName[0..6], "VK_EXT");
    try std.testing.expectEqualStrings("VK_EXT", vk.extensionName(&extension));
    try std.testing.expect(vk.supportsExtension(&.{extension}, "VK_EXT"));
    try std.testing.expect(!vk.supportsExtension(&.{extension}, "VK_EX"));
    try std.testing.expect(!vk.supportsExtension(&.{extension}, ""));

    var empty: vk.raw.VkExtensionProperties = .{};
    try std.testing.expectEqualStrings("", vk.extensionName(&empty));
    try std.testing.expect(vk.supportsExtension(&.{empty}, ""));

    var full: vk.raw.VkExtensionProperties = .{};
    @memset(&full.extensionName, 'x');
    try std.testing.expectEqual(full.extensionName.len, vk.extensionName(&full).len);

    var layer: vk.raw.VkLayerProperties = .{};
    @memcpy(layer.layerName[0..8], "VK_LAYER");
    try std.testing.expect(vk.supportsLayer(&.{layer}, "VK_LAYER"));
    try std.testing.expect(!vk.supportsLayer(&.{layer}, "VK_LAY"));
}

test "typed device options reject invalid input before dispatch" {
    const priorities = [_]f32{1.0};
    const queue: vk.DeviceQueueOptions = .{
        .family_index = 0,
        .priorities = &priorities,
    };
    try (vk.DeviceOptions{ .queues = &.{queue} }).validate();
    const second_queue: vk.DeviceQueueOptions = .{
        .family_index = 1,
        .priorities = &priorities,
    };
    try (vk.DeviceOptions{ .queues = &.{ queue, second_queue } }).validate();
    try std.testing.expectError(
        error.InvalidOptions,
        (vk.DeviceOptions{ .queues = &.{ queue, queue } }).validate(),
    );
    try std.testing.expectError(
        error.InvalidOptions,
        (vk.DeviceOptions{ .queues = &.{} }).validate(),
    );
    try std.testing.expectError(
        error.InvalidOptions,
        (vk.DeviceOptions{ .queues = &.{.{
            .family_index = 0,
            .priorities = &.{},
        }} }).validate(),
    );
    const too_many = [_]vk.DeviceQueueOptions{queue} ** 65;
    try std.testing.expectError(
        error.CountOverflow,
        (vk.DeviceOptions{ .queues = &too_many }).validate(),
    );

    const valid_boundary_priorities = [_]f32{ 0.0, 1.0 };
    try (vk.DeviceOptions{ .queues = &.{.{
        .family_index = 1,
        .priorities = &valid_boundary_priorities,
    }} }).validate();

    const invalid_priorities = [_]f32{
        -0.01,
        1.01,
        std.math.nan(f32),
        std.math.inf(f32),
        -std.math.inf(f32),
    };
    for (invalid_priorities) |priority| {
        try std.testing.expectError(
            error.InvalidOptions,
            (vk.DeviceOptions{ .queues = &.{.{
                .family_index = 1,
                .priorities = &.{priority},
            }} }).validate(),
        );
    }
}

test "portability helpers match the selected build platform" {
    if (vk.platform == .metal) {
        try std.testing.expectEqual(@as(usize, 1), vk.Portability.instanceExtensions().len);
        try std.testing.expectEqual(@as(usize, 1), vk.Portability.deviceExtensions().len);
        try std.testing.expect(vk.Portability.instanceFlags() != 0);
    } else {
        try std.testing.expectEqual(@as(usize, 0), vk.Portability.instanceExtensions().len);
        try std.testing.expectEqual(@as(usize, 0), vk.Portability.deviceExtensions().len);
        try std.testing.expectEqual(
            @as(vk.raw.VkInstanceCreateFlags, 0),
            vk.Portability.instanceFlags(),
        );
    }
}

test "checkSuccess maps only success-only Vulkan results" {
    try vk.checkSuccess(vk.raw.VK_SUCCESS);
    const cases = [_]struct { vk.raw.VkResult, anyerror }{
        .{ vk.raw.VK_ERROR_OUT_OF_HOST_MEMORY, error.OutOfHostMemory },
        .{ vk.raw.VK_ERROR_OUT_OF_DEVICE_MEMORY, error.OutOfDeviceMemory },
        .{ vk.raw.VK_ERROR_INITIALIZATION_FAILED, error.InitializationFailed },
        .{ vk.raw.VK_ERROR_DEVICE_LOST, error.DeviceLost },
        .{ vk.raw.VK_ERROR_MEMORY_MAP_FAILED, error.MemoryMapFailed },
        .{ vk.raw.VK_ERROR_LAYER_NOT_PRESENT, error.LayerNotPresent },
        .{ vk.raw.VK_ERROR_EXTENSION_NOT_PRESENT, error.ExtensionNotPresent },
        .{ vk.raw.VK_ERROR_FEATURE_NOT_PRESENT, error.FeatureNotPresent },
        .{ vk.raw.VK_ERROR_INCOMPATIBLE_DRIVER, error.IncompatibleDriver },
        .{ vk.raw.VK_ERROR_TOO_MANY_OBJECTS, error.TooManyObjects },
        .{ vk.raw.VK_ERROR_FORMAT_NOT_SUPPORTED, error.FormatNotSupported },
        .{ vk.raw.VK_ERROR_FRAGMENTED_POOL, error.FragmentedPool },
        .{ vk.raw.VK_ERROR_UNKNOWN, error.UnknownVulkanError },
        .{ vk.raw.VK_ERROR_SURFACE_LOST_KHR, error.SurfaceLost },
        .{ vk.raw.VK_ERROR_NATIVE_WINDOW_IN_USE_KHR, error.NativeWindowInUse },
    };
    for (cases) |case| try std.testing.expectError(case[1], vk.checkSuccess(case[0]));
    try std.testing.expectError(error.UnexpectedVulkanResult, vk.checkSuccess(-1234567));
    try std.testing.expectError(error.UnexpectedVulkanResult, vk.checkSuccess(vk.raw.VK_TIMEOUT));
    try std.testing.expectError(
        error.UnexpectedVulkanResult,
        vk.checkSuccess(vk.raw.VK_INCOMPLETE),
    );
    try std.testing.expectError(
        error.UnexpectedVulkanResult,
        vk.checkSuccess(vk.raw.VK_SUBOPTIMAL_KHR),
    );
}

test "all public wrapper declarations compile" {
    std.testing.refAllDecls(vk);
    _ = &vk.Entry.apiVersion;
    _ = &vk.Entry.instanceExtensions;
    _ = &vk.Entry.instanceLayers;
    _ = &vk.Entry.load;
    _ = &vk.Entry.require;
    _ = &vk.Entry.loadUnchecked;
    _ = &vk.Entry.createInstance;
    _ = &vk.Entry.createInstanceRaw;
    _ = &vk.Instance.deinit;
    _ = &vk.Instance.rawHandle;
    _ = &vk.Instance.load;
    _ = &vk.Instance.require;
    _ = &vk.Instance.loadUnchecked;
    _ = &vk.Instance.adoptSurface;
    _ = &vk.Instance.physicalDevices;
    _ = &vk.PhysicalDevice.properties;
    _ = &vk.PhysicalDevice.features;
    _ = &vk.PhysicalDevice.features2;
    _ = &vk.PhysicalDevice.memoryProperties;
    _ = &vk.PhysicalDevice.queueFamilyProperties;
    _ = &vk.PhysicalDevice.queueFamilies;
    _ = &vk.PhysicalDevice.deviceExtensions;
    _ = &vk.PhysicalDevice.surfaceSupport;
    _ = &vk.PhysicalDevice.surfaceCapabilities;
    _ = &vk.PhysicalDevice.surfaceFormats;
    _ = &vk.PhysicalDevice.presentModes;
    _ = &vk.PhysicalDevice.findMemoryTypeIndex;
    _ = &vk.PhysicalDevice.createDevice;
    _ = &vk.PhysicalDevice.createDeviceRaw;
    _ = &vk.Device.deinit;
    _ = &vk.Device.load;
    _ = &vk.Device.require;
    _ = &vk.Device.loadUnchecked;
    _ = &vk.Device.waitIdle;
    _ = &vk.Device.queue;
    _ = &vk.Device.setObjectName;
    _ = &vk.Device.createSwapchain;
    _ = &vk.Device.beginCommandBufferLabel;
    _ = &vk.Device.endCommandBufferLabel;
    _ = &vk.Device.insertCommandBufferLabel;
    _ = &vk.Surface.deinit;
    _ = &vk.Instance.debugMessengerActive;
    _ = &vk.Swapchain.deinit;
    _ = &vk.Swapchain.images;
    _ = &vk.Swapchain.acquireNextImage;
    _ = &vk.ext.debug_utils.Messenger.init;
    _ = &vk.ext.debug_utils.MessengerConfig.fromHandler;
    _ = &vk.ext.debug_utils.MessengerConfig.fromHandlerWithContext;
    _ = &vk.Queue.submit;
    _ = &vk.Queue.waitIdle;
    _ = &vk.Queue.present;
    _ = &vk.Queue.beginLabel;
    _ = &vk.Queue.endLabel;
    _ = &vk.Queue.insertLabel;
}

test "vendored registry revision is recorded" {
    try std.testing.expectEqual(@as(usize, 40), vk.registry_commit.len);
}
