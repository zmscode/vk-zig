const vk = @import("vulkan");

export fn instanceExtensionAsDevice() void {
    const options: vk.DeviceOptions = .{
        .queues = &.{.{
            .family_index = .fromRaw(0),
            .priorities = &.{1},
        }},
        .extensions = &.{vk.extension.khr_surface},
    };
    _ = options;
}
