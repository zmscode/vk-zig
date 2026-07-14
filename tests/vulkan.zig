const std = @import("std");
const vk = @import("vulkan");

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
    _ = &vk.Entry.loadUnchecked;
    _ = &vk.Entry.createInstance;
    _ = &vk.Entry.createInstanceRaw;
    _ = &vk.Instance.deinit;
    _ = &vk.Instance.rawHandle;
    _ = &vk.Instance.load;
    _ = &vk.Instance.loadUnchecked;
    _ = &vk.Instance.adoptSurface;
    _ = &vk.Instance.physicalDevices;
    _ = &vk.PhysicalDevice.properties;
    _ = &vk.PhysicalDevice.memoryProperties;
    _ = &vk.PhysicalDevice.queueFamilyProperties;
    _ = &vk.PhysicalDevice.surfaceSupport;
    _ = &vk.PhysicalDevice.createDevice;
    _ = &vk.PhysicalDevice.createDeviceRaw;
    _ = &vk.Device.deinit;
    _ = &vk.Device.load;
    _ = &vk.Device.loadUnchecked;
    _ = &vk.Device.waitIdle;
    _ = &vk.Device.queue;
    _ = &vk.Device.setObjectName;
    _ = &vk.Surface.deinit;
    _ = &vk.ext.debug_utils.Messenger.init;
    _ = &vk.Queue.submit;
    _ = &vk.Queue.waitIdle;
}

test "vendored registry revision is recorded" {
    try std.testing.expectEqual(@as(usize, 40), vk.registry_commit.len);
}
