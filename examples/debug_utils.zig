const std = @import("std");
const vk = @import("vulkan");

const extensions = [_][:0]const u8{vk.extension.ext_debug_utils.name};

pub fn main(init: std.process.Init) !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();
    const entry = try loader.entry();

    const available = try entry.instanceExtensions(init.gpa, null);
    defer init.gpa.free(available);
    if (!vk.supportsExtension(available, extensions[0])) return error.DebugUtilsUnavailable;

    const messenger_options: vk.ext.debug_utils.MessengerOptions = .{
        .callback = debugCallback,
    };
    var messenger_create_info = messenger_options.createInfo();
    var instance = try entry.createInstance(.{
        .application_name = "vk-zig-debug-utils",
        .extensions = &extensions,
        .next = &messenger_create_info,
        .enumerate_portability = vk.platform == .metal,
    });
    defer instance.deinit();

    var messenger = try vk.ext.debug_utils.Messenger.init(&instance, messenger_options);
    defer messenger.deinit();
    std.log.info("created a VK_EXT_debug_utils messenger", .{});
}

fn debugCallback(
    severity: vk.raw.VkDebugUtilsMessageSeverityFlagBitsEXT,
    message_type: vk.raw.VkDebugUtilsMessageTypeFlagsEXT,
    callback_data: [*c]const vk.raw.VkDebugUtilsMessengerCallbackDataEXT,
    _: ?*anyopaque,
) callconv(.c) vk.raw.VkBool32 {
    const message = vk.ext.debug_utils.Message.fromCallback(
        severity,
        message_type,
        callback_data,
    ) orelse return vk.raw.VK_FALSE;
    std.log.info("Vulkan [{d}]: {s}", .{ severity, message.text() orelse "(no message)" });
    return vk.raw.VK_FALSE;
}
