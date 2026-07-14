const std = @import("std");
const vk = @import("vulkan");

/// Creates the replacement before retiring the old swapchain. The caller keeps the old value
/// alive until all frames that reference it have completed, then deinitializes it.
pub fn recreate(
    device: *const vk.Device,
    old_swapchain: *const vk.Swapchain,
    replacement_options: vk.SwapchainOptions,
) !vk.Swapchain {
    var options = replacement_options;
    options.old_swapchain = old_swapchain;
    return device.createSwapchain(options);
}

pub fn shouldRecreate(status: anytype) bool {
    return switch (status) {
        .out_of_date, .suboptimal => true,
        else => false,
    };
}

pub fn main() void {
    std.log.info("swapchain_recreation keeps old resources alive through replacement", .{});
}
