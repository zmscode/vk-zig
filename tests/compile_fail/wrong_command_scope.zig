const vk = @import("vulkan");

const WrongScope = @TypeOf(
    @as(*const vk.Instance, undefined).load(vk.command.queue_submit),
);

comptime {
    _ = WrongScope;
}
