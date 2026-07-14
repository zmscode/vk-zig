const std = @import("std");
const vk = @import("vulkan");

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

    const messenger_config = vk.debug_utils.Config.fromHandler(
        debugMessage,
        .{},
    );
    var instance = try entry.createInstance(.{
        .application_name = "vk-zig-debug-utils",
        .debug_messenger = messenger_config,
        .enumerate_portability = vk.platform == .metal,
    });
    defer instance.deinit();

    std.debug.assert(instance.debugMessengerActive());
    std.log.info("created a VK_EXT_debug_utils messenger", .{});
}

fn debugMessage(message: vk.debug_utils.Message) void {
    const text = message.text() orelse "(no message)";
    if (message.isError()) {
        std.log.err("Vulkan: {s}", .{text});
    } else {
        std.log.warn("Vulkan: {s}", .{text});
    }
}
