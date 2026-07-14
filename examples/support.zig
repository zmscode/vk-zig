const vk = @import("vulkan");

pub fn createInstance(entry: *const vk.Entry) !vk.Instance {
    return entry.createInstance(.{
        .application_name = "vk-zig-example",
        .engine_name = "vk-zig",
        .api_version = .{ .major = 1, .minor = 1, .patch = 0 },
        .enumerate_portability = vk.platform == .metal,
    });
}

pub fn deviceTypeName(device_type: vk.PhysicalDeviceType) []const u8 {
    if (device_type == .integrated_gpu) return "integrated GPU";
    if (device_type == .discrete_gpu) return "discrete GPU";
    if (device_type == .virtual_gpu) return "virtual GPU";
    if (device_type == .cpu) return "CPU";
    return "other";
}

pub fn boolName(value: bool) []const u8 {
    return if (value) "yes" else "no";
}
