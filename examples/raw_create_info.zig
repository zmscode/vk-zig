const std = @import("std");
const vk = @import("vulkan");

const portability_extensions = [_][*:0]const u8{
    "VK_KHR_portability_enumeration",
};

pub fn main() !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();
    const entry = try loader.entry();

    const application_info: vk.raw.VkApplicationInfo = .{
        .sType = vk.raw.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "vk-zig-raw-create-info",
        .applicationVersion = (vk.Version{
            .major = 1,
            .minor = 0,
            .patch = 0,
        }).encode(),
        .pEngineName = "none",
        .apiVersion = (vk.Version{
            .major = 1,
            .minor = 0,
            .patch = 0,
        }).encode(),
    };
    const create_info: vk.raw.VkInstanceCreateInfo = .{
        .sType = vk.raw.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .flags = if (vk.platform_support.metal)
            @intCast(vk.raw.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR)
        else
            0,
        .pApplicationInfo = &application_info,
        .enabledExtensionCount = if (vk.platform_support.metal) 1 else 0,
        .ppEnabledExtensionNames = if (vk.platform_support.metal)
            @ptrCast(&portability_extensions)
        else
            null,
    };
    var instance = try entry.createInstanceRaw(&create_info, null);
    defer instance.deinit();

    std.log.info("created an instance from raw Vulkan create-info structs", .{});
}
