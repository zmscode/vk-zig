const std = @import("std");
const vk = @import("vulkan");

const extensions = [_][:0]const u8{vk.extension.ext_debug_utils.name};

pub fn main(init: std.process.Init) !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();
    const entry = try loader.entry();

    const available = try entry.instanceExtensions(init.gpa, null);
    defer init.gpa.free(available);
    const available_layers = try entry.instanceLayers(init.gpa);
    defer init.gpa.free(available_layers);
    const diagnostics = vk.diagnostics.detect(
        .{ .debug_messenger = true },
        available_layers,
        available,
    );
    if (!diagnostics.debug_messenger_enabled) return error.DebugUtilsUnavailable;

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
    const text = message.text() orelse "(no message)";
    if (message.isError()) {
        std.log.err("Vulkan: {s}", .{text});
    } else {
        std.log.warn("Vulkan: {s}", .{text});
    }
    return vk.raw.VK_FALSE;
}
