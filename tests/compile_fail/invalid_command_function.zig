const vk = @import("vulkan");

comptime {
    _ = vk.CommandFunction(fn () void);
}
