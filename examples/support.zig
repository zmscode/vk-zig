const std = @import("std");
const vk = @import("vulkan");

const portability_extensions = [_][*:0]const u8{
    "VK_KHR_portability_enumeration",
};

pub fn createInstance(entry: *const vk.Entry) !vk.Instance {
    const use_portability = vk.platform == .metal;
    return entry.createInstance(.{
        .application_name = "vk-zig-example",
        .engine_name = "vk-zig",
        .api_version = .{ .major = 1, .minor = 1, .patch = 0 },
        .extensions = if (use_portability) &portability_extensions else &.{},
        .flags = if (use_portability)
            @intCast(vk.raw.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR)
        else
            0,
    });
}

pub fn cString(bytes: []const u8) []const u8 {
    return std.mem.sliceTo(bytes, 0);
}

pub fn deviceTypeName(device_type: vk.raw.VkPhysicalDeviceType) []const u8 {
    if (device_type == vk.raw.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU) return "integrated GPU";
    if (device_type == vk.raw.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) return "discrete GPU";
    if (device_type == vk.raw.VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU) return "virtual GPU";
    if (device_type == vk.raw.VK_PHYSICAL_DEVICE_TYPE_CPU) return "CPU";
    return "other";
}

pub fn findGraphicsQueue(properties: []const vk.raw.VkQueueFamilyProperties) ?u32 {
    for (properties, 0..) |queue_family, index| {
        const graphics_bit: vk.raw.VkQueueFlags = @intCast(vk.raw.VK_QUEUE_GRAPHICS_BIT);
        if (queue_family.queueCount == 0) continue;
        if ((queue_family.queueFlags & graphics_bit) != 0) return @intCast(index);
    }
    return null;
}

pub fn boolName(value: vk.raw.VkBool32) []const u8 {
    return if (value == vk.raw.VK_TRUE) "yes" else "no";
}
