const std = @import("std");
const vk = @import("vulkan");

/// Submits one executable command buffer with timeline wait/signal values.
/// The logical device must have enabled the timeline-semaphore and
/// synchronization2 capabilities before creating these objects.
pub fn submitAndWait(
    queue: *const vk.Queue,
    command_buffer: *vk.CommandBuffer,
    timeline: *const vk.Semaphore,
    fence: *const vk.Fence,
    wait_value: u64,
    signal_value: u64,
) !void {
    try fence.reset();
    try queue.submit2(.{
        .submits = &.{.{
            .waits = &.{.{
                .semaphore = timeline,
                .value = wait_value,
                .stage = .init(&.{.all_commands}),
            }},
            .command_buffers = &.{.{ .command_buffer = command_buffer }},
            .signals = &.{.{
                .semaphore = timeline,
                .value = signal_value,
                .stage = .init(&.{.all_commands}),
            }},
        }},
        .fence = fence,
    });
    switch (try fence.wait(.infinite)) {
        .success => try command_buffer.markComplete(),
        .timeout => unreachable,
    }
}

pub fn main() void {
    std.log.info("timeline_submit.submitAndWait is ready for an enabled Vulkan 1.3 device", .{});
}
