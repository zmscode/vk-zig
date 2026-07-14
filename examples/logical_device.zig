const std = @import("std");
const vk = @import("vulkan");
const support = @import("support.zig");

const portability_device_extensions = [_][*:0]const u8{
    "VK_KHR_portability_subset",
};

pub fn main(init: std.process.Init) !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();
    const entry = try loader.entry();

    var instance = try support.createInstance(&entry);
    defer instance.deinit();
    const physical_devices = try instance.physicalDevices(init.gpa);
    defer init.gpa.free(physical_devices);
    if (physical_devices.len == 0) return error.NoPhysicalDevice;

    const physical_device = &physical_devices[0];
    const queue_families = try physical_device.queueFamilyProperties(init.gpa);
    defer init.gpa.free(queue_families);
    const family_index = support.findGraphicsQueue(queue_families) orelse {
        return error.NoGraphicsQueue;
    };

    const priority: f32 = 1.0;
    const queue_info: vk.raw.VkDeviceQueueCreateInfo = .{
        .sType = vk.raw.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = family_index,
        .queueCount = 1,
        .pQueuePriorities = &priority,
    };
    const create_info: vk.raw.VkDeviceCreateInfo = .{
        .sType = vk.raw.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queue_info,
        .enabledExtensionCount = if (vk.platform == .metal) 1 else 0,
        .ppEnabledExtensionNames = if (vk.platform == .metal)
            @ptrCast(&portability_device_extensions)
        else
            null,
    };
    var device = try physical_device.createDevice(&create_info, null);
    defer device.deinit();

    const queue = device.queue(family_index, 0);
    try queue.waitIdle();
    try device.waitIdle();

    const properties = physical_device.properties();
    std.log.info(
        "created a logical device and graphics queue for {s}",
        .{support.cString(&properties.deviceName)},
    );
}
