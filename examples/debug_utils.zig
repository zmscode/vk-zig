const std = @import("std");
const vk = @import("vulkan");

const extensions = [_][:0]const u8{"VK_EXT_debug_utils"};

pub fn main(init: std.process.Init) !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();
    const entry = try loader.entry();

    const available = try entry.instanceExtensions(init.gpa, null);
    defer init.gpa.free(available);
    if (!vk.supportsExtension(available, extensions[0])) return error.DebugUtilsUnavailable;

    var instance = try entry.createInstance(.{
        .application_name = "vk-zig-debug-utils",
        .extensions = &extensions,
        .enumerate_portability = vk.platform == .metal,
    });
    defer instance.deinit();

    var messenger = try vk.ext.debug_utils.Messenger.init(&instance, .{
        .callback = debugCallback,
    });
    defer messenger.deinit();
    std.log.info("created a VK_EXT_debug_utils messenger", .{});
}

fn debugCallback(
    severity: vk.raw.VkDebugUtilsMessageSeverityFlagBitsEXT,
    _: vk.raw.VkDebugUtilsMessageTypeFlagsEXT,
    callback_data: [*c]const vk.raw.VkDebugUtilsMessengerCallbackDataEXT,
    _: ?*anyopaque,
) callconv(.c) vk.raw.VkBool32 {
    if (callback_data != null and callback_data[0].pMessage != null) {
        const message: [*:0]const u8 = @ptrCast(callback_data[0].pMessage);
        std.log.info("Vulkan [{d}]: {s}", .{ severity, std.mem.span(message) });
    }
    return vk.raw.VK_FALSE;
}
