const vk = @import("vulkan");

export fn deviceExtensionAsInstance() void {
    const options: vk.InstanceOptions = .{
        .extensions = &.{vk.extension.khr_swapchain},
    };
    _ = options;
}
