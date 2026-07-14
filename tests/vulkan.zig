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

test "generated enums preserve known and unknown Vulkan values" {
    try std.testing.expectEqual(
        @as(vk.raw.VkFormat, @intCast(vk.raw.VK_FORMAT_B8G8R8A8_SRGB)),
        vk.Format.b8g8r8a8_srgb.toRaw(),
    );
    try std.testing.expectEqual(
        @as(vk.raw.VkPresentModeKHR, @intCast(vk.raw.VK_PRESENT_MODE_FIFO_KHR)),
        vk.PresentMode.fifo.toRaw(),
    );

    const unknown_raw: vk.raw.VkFormat = 0xf000_0001;
    const unknown = vk.Format.fromRaw(unknown_raw);
    try std.testing.expectEqual(unknown_raw, unknown.toRaw());
}

test "typed versions and physical-device properties hide packed fields" {
    try std.testing.expect(vk.Version.v1_4.atLeast(.v1_3));
    try std.testing.expect(vk.Version.v1_0.lessThan(.v1_1));
    try std.testing.expectEqual(vk.Version.v1_3, vk.Version.decode(vk.Version.v1_3.encode()));

    var raw_properties: vk.raw.VkPhysicalDeviceProperties = .{};
    raw_properties.apiVersion = vk.Version.v1_3.encode();
    raw_properties.driverVersion = 77;
    raw_properties.vendorID = 0x1234;
    raw_properties.deviceID = 0x5678;
    raw_properties.deviceType = @intCast(vk.raw.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU);
    const name = "typed-device";
    @memcpy(raw_properties.deviceName[0..name.len], name);
    raw_properties.limits.maxImageDimension2D = 8192;
    raw_properties.limits.maxPushConstantsSize = 256;
    raw_properties.limits.nonCoherentAtomSize = 64;
    raw_properties.limits.timestampPeriod = 1.5;
    raw_properties.sparseProperties.residencyStandard2DBlockShape = vk.raw.VK_TRUE;

    const properties = vk.PhysicalDeviceProperties.fromRaw(&raw_properties);
    try std.testing.expectEqualStrings(name, properties.name());
    try std.testing.expect(properties.isDiscrete());
    try std.testing.expect(properties.supportsApiVersion(.v1_2));
    try std.testing.expectEqual(@as(u32, 0x1234), properties.vendor_id);
    try std.testing.expectEqual(@as(u32, 8192), properties.limits.max_image_dimension_2d);
    try std.testing.expectEqual(@as(u32, 256), properties.limits.max_push_constants_size);
    try std.testing.expectEqual(@as(u64, 64), properties.limits.non_coherent_atom_size);
    try std.testing.expect(properties.sparse.standard_2d_block_shape);
}

test "generated flag sets are typed and preserve unknown bits" {
    const usage = vk.ImageUsageFlags.init(&.{ .transfer_dst, .color_attachment });
    try std.testing.expect(usage.contains(.transfer_dst));
    try std.testing.expect(usage.contains(.color_attachment));
    try std.testing.expect(!usage.contains(.sampled));

    const unknown_raw: vk.raw.VkImageUsageFlags = 0x8000_0000;
    const extended = vk.ImageUsageFlags.fromRaw(unknown_raw).merge(usage);
    try std.testing.expectEqual(unknown_raw, extended.toRaw() & unknown_raw);
    try std.testing.expect(extended.containsAll(usage));
    try std.testing.expect(extended.without(.transfer_dst).contains(.color_attachment));
    try std.testing.expect(!extended.without(.transfer_dst).contains(.transfer_dst));
    try std.testing.expect(vk.ImageUsageFlags.empty.isEmpty());
    try std.testing.expect(vk.ImageUsageFlags != vk.MemoryPropertyFlags);
}

test "generated value types convert at the raw boundary" {
    const extent: vk.Extent2D = .{ .width = 1920, .height = 1080 };
    try std.testing.expectEqual(@as(u32, 1920), extent.toRaw().width);
    try std.testing.expectEqual(extent, vk.Extent2D.fromRaw(extent.toRaw()));

    const range: vk.ImageSubresourceRange = .{
        .aspect_mask = .init(&.{.color}),
        .level_count = 4,
        .layer_count = 2,
    };
    const raw_range = range.toRaw();
    try std.testing.expectEqual(
        @as(vk.raw.VkImageAspectFlags, @intCast(vk.raw.VK_IMAGE_ASPECT_COLOR_BIT)),
        raw_range.aspectMask,
    );
    try std.testing.expectEqual(@as(u32, 4), raw_range.levelCount);
    try std.testing.expectEqual(@as(u32, 2), raw_range.layerCount);

    const raw_color = (vk.ClearColor{ .float = .{ 0.1, 0.2, 0.3, 1.0 } }).toRaw();
    try std.testing.expectEqual(@as(f32, 1.0), raw_color.float32[3]);
}

test "swapchain selection helpers clamp capabilities and report fallbacks" {
    const capabilities: vk.SurfaceCapabilities = .{
        .image_count_min = 2,
        .image_count_max = 4,
        .extent_current = null,
        .extent_min = .{ .width = 320, .height = 200 },
        .extent_max = .{ .width = 1920, .height = 1080 },
        .image_array_layer_count_max = 1,
        .transforms_supported = .init(&.{ .identity, .rotate_90 }),
        .transform_current = .rotate_90,
        .composite_alpha_supported = .init(&.{ .opaque_, .inherit }),
        .image_usage_supported = .init(&.{ .color_attachment, .transfer_dst }),
    };

    try std.testing.expectEqual(
        vk.Extent2D{ .width = 320, .height = 1080 },
        vk.clampSurfaceExtent(capabilities, .{ .width = 100, .height = 2000 }),
    );
    const count_default = vk.chooseSwapchainImageCount(capabilities, null);
    try std.testing.expectEqual(@as(u32, 3), count_default.value);
    try std.testing.expect(count_default.preferred);
    const count_clamped = vk.chooseSwapchainImageCount(capabilities, 8);
    try std.testing.expectEqual(@as(u32, 4), count_clamped.value);
    try std.testing.expect(!count_clamped.preferred);

    const wanted_format: vk.SurfaceFormat = .{
        .format = .b8g8r8a8_srgb,
        .color_space = .srgb_nonlinear,
    };
    const format = try vk.chooseSurfaceFormat(&.{wanted_format}, &.{wanted_format});
    try std.testing.expectEqual(wanted_format.format, format.value.format);
    try std.testing.expect(format.preferred);
    try std.testing.expectError(
        error.UnsupportedSurfaceConfiguration,
        vk.chooseSurfaceFormat(&.{}, &.{wanted_format}),
    );

    const mode = try vk.choosePresentMode(&.{ .fifo, .mailbox }, &.{.mailbox});
    try std.testing.expectEqual(vk.PresentMode.mailbox, mode.value);
    try std.testing.expect(mode.preferred);
    const fallback_mode = try vk.choosePresentMode(&.{.fifo}, &.{.mailbox});
    try std.testing.expectEqual(vk.PresentMode.fifo, fallback_mode.value);
    try std.testing.expect(!fallback_mode.preferred);

    const transform = vk.chooseSurfaceTransform(capabilities, &.{.identity});
    try std.testing.expectEqual(vk.SurfaceTransformBit.identity, transform.value);
    try std.testing.expect(transform.preferred);
    const alpha = try vk.chooseCompositeAlpha(
        capabilities.composite_alpha_supported,
        &.{.pre_multiplied},
    );
    try std.testing.expectEqual(vk.CompositeAlphaBit.opaque_, alpha.value);
    try std.testing.expect(!alpha.preferred);

    const usage = try vk.chooseImageUsage(
        capabilities.image_usage_supported,
        .init(&.{.color_attachment}),
        .init(&.{.transfer_dst}),
    );
    try std.testing.expect(usage.value.contains(.color_attachment));
    try std.testing.expect(usage.value.contains(.transfer_dst));
    try std.testing.expect(usage.preferred);
    try std.testing.expectError(
        error.UnsupportedSurfaceConfiguration,
        vk.chooseImageUsage(
            capabilities.image_usage_supported,
            .init(&.{.sampled}),
            .empty,
        ),
    );
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
        .index = .fromRaw(3),
        .flags = .init(&.{ .graphics, .transfer }),
        .queue_count = 2,
        .timestamp_valid_bits = 48,
        .minimum_image_transfer_granularity = .{ .width = 1, .height = 1, .depth = 1 },
    };
    try std.testing.expect(graphics_transfer.supports(.graphics));
    try std.testing.expect(graphics_transfer.supports(.transfer));
    try std.testing.expect(!graphics_transfer.supports(.compute));
    try std.testing.expectEqual(@as(u32, 2), graphics_transfer.queueCount());
    const compute_only: vk.QueueFamily = .{
        .index = .fromRaw(4),
        .flags = .init(&.{.compute}),
        .queue_count = 1,
        .timestamp_valid_bits = 64,
        .minimum_image_transfer_granularity = .{ .width = 1, .height = 1, .depth = 1 },
    };
    try std.testing.expectEqual(
        vk.QueueFamilyIndex.fromRaw(3),
        try vk.selectQueueFamily(&.{ graphics_transfer, compute_only }, .{
            .required = .init(&.{.transfer}),
            .preferred = .init(&.{.graphics}),
        }),
    );
    try std.testing.expectError(
        error.QueueFamilyNotFound,
        vk.selectQueueFamily(&.{graphics_transfer}, .{
            .required = .init(&.{.sparse_binding}),
        }),
    );

    var memory: vk.raw.VkPhysicalDeviceMemoryProperties = .{};
    memory.memoryHeapCount = 1;
    memory.memoryTypeCount = 3;
    memory.memoryTypes[0].propertyFlags =
        vk.MemoryPropertyFlags.init(&.{.host_visible}).toRaw();
    memory.memoryTypes[1].propertyFlags =
        vk.MemoryPropertyFlags.init(&.{ .host_visible, .host_coherent }).toRaw();
    memory.memoryTypes[2].propertyFlags =
        vk.MemoryPropertyFlags.init(&.{.device_local}).toRaw();
    const typed_memory = try vk.MemoryProperties.fromRaw(&memory);
    try std.testing.expectEqual(vk.MemoryTypeIndex.fromRaw(1), try vk.selectMemoryTypeIndex(&typed_memory, .{
        .type_bits = 0b111,
        .required_flags = .init(&.{.host_visible}),
        .preferred_flags = .init(&.{.host_coherent}),
    }));
    try std.testing.expectError(error.MemoryTypeNotFound, vk.selectMemoryTypeIndex(&typed_memory, .{
        .type_bits = 0b011,
        .required_flags = .init(&.{.device_local}),
    }));
}

test "typed memory properties validate counts and own their slice storage" {
    var raw_memory: vk.raw.VkPhysicalDeviceMemoryProperties = .{};
    const empty = try vk.MemoryProperties.fromRaw(&raw_memory);
    try std.testing.expectEqual(@as(usize, 0), empty.types().len);
    try std.testing.expectEqual(@as(usize, 0), empty.heaps().len);
    try std.testing.expectEqual(@as(u64, 0), try empty.deviceLocalBytes());

    raw_memory.memoryHeapCount = @intCast(raw_memory.memoryHeaps.len);
    raw_memory.memoryTypeCount = @intCast(raw_memory.memoryTypes.len);
    for (&raw_memory.memoryTypes) |*memory_type| memory_type.heapIndex = 0;
    const maximum = try vk.MemoryProperties.fromRaw(&raw_memory);
    try std.testing.expectEqual(raw_memory.memoryTypes.len, maximum.types().len);
    try std.testing.expectEqual(raw_memory.memoryHeaps.len, maximum.heaps().len);

    raw_memory.memoryTypeCount = @intCast(raw_memory.memoryTypes.len + 1);
    try std.testing.expectError(
        error.InvalidProperties,
        vk.MemoryProperties.fromRaw(&raw_memory),
    );
    raw_memory.memoryTypeCount = 0;
    raw_memory.memoryHeapCount = @intCast(raw_memory.memoryHeaps.len + 1);
    try std.testing.expectError(
        error.InvalidProperties,
        vk.MemoryProperties.fromRaw(&raw_memory),
    );
}

test "typed memory properties convert flags and sum every device-local heap" {
    var raw_memory: vk.raw.VkPhysicalDeviceMemoryProperties = .{};
    raw_memory.memoryHeapCount = 3;
    raw_memory.memoryHeaps[0] = .{
        .size = 256,
        .flags = vk.MemoryHeapFlags.init(&.{.device_local}).toRaw(),
    };
    raw_memory.memoryHeaps[1] = .{ .size = 512 };
    raw_memory.memoryHeaps[2] = .{
        .size = 1024,
        .flags = vk.MemoryHeapFlags.init(&.{.device_local}).toRaw(),
    };
    raw_memory.memoryTypeCount = 2;
    raw_memory.memoryTypes[0] = .{
        .propertyFlags = vk.MemoryPropertyFlags.init(&.{.host_visible}).toRaw(),
        .heapIndex = 1,
    };
    raw_memory.memoryTypes[1] = .{
        .propertyFlags = vk.MemoryPropertyFlags.init(&.{ .device_local, .host_visible }).toRaw(),
        .heapIndex = 2,
    };

    const memory = try vk.MemoryProperties.fromRaw(&raw_memory);
    try std.testing.expect(memory.heaps()[0].isDeviceLocal());
    try std.testing.expect(!memory.heaps()[1].isDeviceLocal());
    try std.testing.expect(memory.types()[1].supports(.init(&.{.device_local})));
    try std.testing.expectEqual(@as(u64, 1280), try memory.deviceLocalBytes());
    try std.testing.expectEqual(
        vk.MemoryHeapIndex.fromRaw(2),
        memory.types()[1].heap_index,
    );
    try std.testing.expectEqual(
        @as(u64, 1024),
        memory.heap(memory.types()[1].heap_index).?.size_bytes,
    );

    const selected = try memory.findType(.{
        .type_bits = 0b11,
        .required_flags = .init(&.{.host_visible}),
        .preferred_flags = .init(&.{.device_local}),
    });
    try std.testing.expectEqual(vk.MemoryTypeIndex.fromRaw(1), selected);

    raw_memory.memoryHeapCount = 2;
    raw_memory.memoryHeaps[0] = .{
        .size = std.math.maxInt(u64),
        .flags = vk.MemoryHeapFlags.init(&.{.device_local}).toRaw(),
    };
    raw_memory.memoryHeaps[1] = .{
        .size = 1,
        .flags = vk.MemoryHeapFlags.init(&.{.device_local}).toRaw(),
    };
    raw_memory.memoryTypeCount = 0;
    const overflowing = try vk.MemoryProperties.fromRaw(&raw_memory);
    try std.testing.expectError(error.SizeOverflow, overflowing.deviceLocalBytes());

    raw_memory.memoryHeapCount = 3;
    raw_memory.memoryTypeCount = 2;
    raw_memory.memoryTypes[1].heapIndex = 3;
    try std.testing.expectError(
        error.InvalidProperties,
        vk.MemoryProperties.fromRaw(&raw_memory),
    );
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
        .family_index = .fromRaw(0),
        .priorities = &priorities,
    };
    try (vk.DeviceOptions{ .queues = &.{queue} }).validate();
    const second_queue: vk.DeviceQueueOptions = .{
        .family_index = .fromRaw(1),
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
            .family_index = .fromRaw(0),
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
        .family_index = .fromRaw(1),
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
                .family_index = .fromRaw(1),
                .priorities = &.{priority},
            }} }).validate(),
        );
    }
}

test "portability helpers match the selected build platform" {
    if (vk.platform == .metal) {
        try std.testing.expectEqual(@as(usize, 1), vk.Portability.instanceExtensions().len);
        try std.testing.expectEqual(@as(usize, 1), vk.Portability.deviceExtensions().len);
        try std.testing.expect(
            vk.Portability.instanceFlags().contains(.enumerate_portability_khr),
        );
    } else {
        try std.testing.expectEqual(@as(usize, 0), vk.Portability.instanceExtensions().len);
        try std.testing.expectEqual(@as(usize, 0), vk.Portability.deviceExtensions().len);
        try std.testing.expect(vk.Portability.instanceFlags().isEmpty());
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
        .{
            vk.raw.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT,
            error.FullScreenExclusiveLost,
        },
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
    _ = &vk.PhysicalDevice.propertiesRaw;
    _ = &vk.PhysicalDevice.formatProperties;
    _ = &vk.PhysicalDevice.imageFormatProperties;
    _ = &vk.PhysicalDevice.features;
    _ = &vk.PhysicalDevice.features2;
    _ = &vk.PhysicalDevice.memoryProperties;
    _ = &vk.PhysicalDevice.memoryPropertiesInto;
    _ = &vk.PhysicalDevice.memoryPropertiesRaw;
    _ = &vk.PhysicalDevice.queueFamilyProperties;
    _ = &vk.PhysicalDevice.queueFamilies;
    _ = &vk.PhysicalDevice.deviceExtensions;
    _ = &vk.PhysicalDevice.surfaceSupport;
    _ = &vk.PhysicalDevice.surfaceCapabilities;
    _ = &vk.PhysicalDevice.surfaceFormats;
    _ = &vk.PhysicalDevice.presentModes;
    _ = &vk.PhysicalDevice.findMemoryTypeIndex;
    _ = &vk.clampSurfaceExtent;
    _ = &vk.chooseSwapchainImageCount;
    _ = &vk.chooseSurfaceFormat;
    _ = &vk.choosePresentMode;
    _ = &vk.chooseSurfaceTransform;
    _ = &vk.chooseCompositeAlpha;
    _ = &vk.chooseImageUsage;
    _ = &vk.selectQueueFamily;
    _ = &vk.selectQueueFamilyForSurface;
    _ = &vk.MemoryProperties.fromRaw;
    _ = &vk.MemoryProperties.initFromRaw;
    _ = &vk.MemoryProperties.types;
    _ = &vk.MemoryProperties.heaps;
    _ = &vk.MemoryProperties.heap;
    _ = &vk.MemoryProperties.deviceLocalBytes;
    _ = &vk.MemoryProperties.findType;
    _ = &vk.selectMemoryTypeIndex;
    _ = &vk.selectMemoryTypeIndexRaw;
    _ = &vk.PhysicalDevice.createDevice;
    _ = &vk.PhysicalDevice.createDeviceRaw;
    _ = &vk.Device.deinit;
    _ = &vk.Device.load;
    _ = &vk.Device.require;
    _ = &vk.Device.loadUnchecked;
    _ = &vk.Device.waitIdle;
    _ = &vk.Device.queue;
    _ = &vk.Device.setObjectName;
    _ = &vk.Device.createImageView;
    _ = &vk.Device.createSemaphore;
    _ = &vk.Device.createFence;
    _ = &vk.Device.resetFences;
    _ = &vk.Device.waitFences;
    _ = &vk.Device.waitTimelineSemaphores;
    _ = &vk.Device.createCommandPool;
    _ = &vk.Device.createSwapchain;
    _ = &vk.Device.beginCommandBufferLabelRaw;
    _ = &vk.Device.endCommandBufferLabelRaw;
    _ = &vk.Device.insertCommandBufferLabelRaw;
    _ = &vk.Surface.deinit;
    _ = &vk.Instance.debugMessengerActive;
    _ = &vk.Swapchain.deinit;
    _ = &vk.Swapchain.imageCount;
    _ = &vk.Swapchain.images;
    _ = &vk.Swapchain.imagesInto;
    _ = &vk.Swapchain.acquireNextImage;
    _ = &vk.ImageView.deinit;
    _ = &vk.Semaphore.deinit;
    _ = &vk.Semaphore.counterValue;
    _ = &vk.Semaphore.signal;
    _ = &vk.Semaphore.wait;
    _ = &vk.Fence.deinit;
    _ = &vk.Fence.status;
    _ = &vk.Fence.reset;
    _ = &vk.Fence.wait;
    _ = &vk.CommandPool.deinit;
    _ = &vk.CommandPool.reset;
    _ = &vk.CommandPool.allocateCommandBuffer;
    _ = &vk.CommandPool.freeCommandBuffer;
    _ = &vk.CommandBuffer.deinit;
    _ = &vk.CommandBuffer.begin;
    _ = &vk.CommandBuffer.end;
    _ = &vk.CommandBuffer.reset;
    _ = &vk.CommandBuffer.markComplete;
    _ = &vk.CommandBuffer.imageBarrier;
    _ = &vk.CommandBuffer.clearColorImage;
    _ = &vk.CommandBuffer.beginLabel;
    _ = &vk.CommandBuffer.insertLabel;
    _ = &vk.ext.debug_utils.Messenger.init;
    _ = &vk.ext.debug_utils.MessengerConfig.fromHandler;
    _ = &vk.ext.debug_utils.MessengerConfig.fromHandlerWithContext;
    _ = &vk.Queue.submit;
    _ = &vk.Queue.submitRaw;
    _ = &vk.Queue.waitIdle;
    _ = &vk.Queue.present;
    _ = &vk.Queue.beginLabel;
    _ = &vk.Queue.beginLabelScope;
    _ = &vk.Queue.endLabel;
    _ = &vk.Queue.insertLabel;
}

test "vendored registry revision is recorded" {
    try std.testing.expectEqual(@as(usize, 40), vk.registry_commit.len);
}
