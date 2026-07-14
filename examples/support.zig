const vk = @import("vulkan");

pub fn createInstance(entry: *const vk.Entry) !vk.Instance {
    return entry.createInstance(.{
        .application_name = "vk-zig-example",
        .engine_name = "vk-zig",
        .api_version = .{ .major = 1, .minor = 1, .patch = 0 },
        .enumerate_portability = vk.platform == .metal,
    });
}

pub fn deviceTypeName(device_type: vk.raw.VkPhysicalDeviceType) []const u8 {
    if (device_type == vk.raw.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU) return "integrated GPU";
    if (device_type == vk.raw.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) return "discrete GPU";
    if (device_type == vk.raw.VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU) return "virtual GPU";
    if (device_type == vk.raw.VK_PHYSICAL_DEVICE_TYPE_CPU) return "CPU";
    return "other";
}

pub fn boolName(value: vk.raw.VkBool32) []const u8 {
    return if (value == vk.raw.VK_TRUE) "yes" else "no";
}
