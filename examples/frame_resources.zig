const std = @import("std");
const vk = @import("vulkan");

pub const FrameResult = enum {
    presented,
    suboptimal,
    swapchain_out_of_date,
    acquire_timeout,
};

/// Records, submits, and presents one clear-only frame. `image_initialized`
/// stores one layout bit for every image and must be reset on swapchain recreation.
pub fn clearAndPresent(
    device: *const vk.Device,
    swapchain: *const vk.Swapchain,
    graphics_queue: *const vk.Queue,
    present_queue: *const vk.Queue,
    graphics_family: vk.QueueFamilyIndex,
    format: vk.Format,
    image_initialized: []bool,
) !FrameResult {
    var command_pool = try device.createCommandPool(.{
        .family_index = graphics_family,
        .flags = .init(&.{.reset_command_buffer}),
    });
    defer command_pool.deinit();
    var command_buffer = try command_pool.allocateCommandBuffer(.{});
    defer command_buffer.deinit();

    var image_available = try device.createSemaphore(.{});
    defer image_available.deinit();
    var render_finished = try device.createSemaphore(.{});
    defer render_finished.deinit();
    var frame_finished = try device.createFence(.{ .signaled = true });
    defer frame_finished.deinit();

    switch (try frame_finished.wait(.infinite)) {
        .success => {},
        .timeout => unreachable,
    }
    const acquired_index, const acquire_suboptimal = switch (try swapchain.acquireNextImage(.{
        .timeout = .{ .nanoseconds = std.time.ns_per_s },
        .semaphore = &image_available,
    })) {
        .success => |index| .{ index, false },
        .suboptimal => |index| .{ index, true },
        .timeout, .not_ready => return .acquire_timeout,
        .out_of_date => return .swapchain_out_of_date,
    };

    var image_storage: [16]vk.SwapchainImage = undefined;
    const images = try swapchain.imagesInto(&image_storage);
    const image_offset: usize = @intCast(acquired_index.toRaw());
    if (image_offset >= images.len) return error.InvalidHandle;
    if (image_offset >= image_initialized.len) return error.BufferTooSmall;
    const image = &images[image_offset];
    const old_layout: vk.ImageLayout = if (image_initialized[image_offset])
        .present_src_khr
    else
        .undefined_;

    const color_range: vk.ImageSubresourceRange = .{
        .aspect_mask = .init(&.{.color}),
    };
    var image_view = try device.createImageView(.{
        .image = image,
        .view_type = ._2d,
        .format = format,
        .subresource_range = color_range,
    });
    defer image_view.deinit();

    // From this point onward, any error must wait for submitted device work
    // before the deferred resource destruction runs.
    errdefer device.waitIdle() catch |wait_error| {
        std.log.err("waiting for failed frame cleanup: {s}", .{@errorName(wait_error)});
    };
    try command_buffer.begin(.{ .flags = .init(&.{.one_time_submit}) });
    try command_buffer.imageBarrier(.{
        .source_stage = .init(&.{.top_of_pipe}),
        .destination_stage = .init(&.{.transfer}),
        .destination_access = .init(&.{.transfer_write}),
        .old_layout = old_layout,
        .new_layout = .transfer_dst_optimal,
        .image = image,
        .subresource_range = color_range,
    });
    try command_buffer.clearColorImage(.{
        .image = image,
        .layout = .transfer_dst_optimal,
        .color = .{ .float = .{ 0.03, 0.05, 0.09, 1.0 } },
        .subresource_range = color_range,
    });
    try command_buffer.imageBarrier(.{
        .source_stage = .init(&.{.transfer}),
        .destination_stage = .init(&.{.bottom_of_pipe}),
        .source_access = .init(&.{.transfer_write}),
        .old_layout = .transfer_dst_optimal,
        .new_layout = .present_src_khr,
        .image = image,
        .subresource_range = color_range,
    });
    try command_buffer.end();

    try frame_finished.reset();
    try graphics_queue.submit(.{
        .waits = &.{.{
            .semaphore = &image_available,
            .stage = .init(&.{.transfer}),
        }},
        .command_buffers = &.{&command_buffer},
        .signals = &.{&render_finished},
        .fence = &frame_finished,
    });
    image_initialized[image_offset] = true;
    const present_status = try present_queue.present(.{
        .swapchain = swapchain,
        .image_index = acquired_index,
        .wait_semaphores = &.{&render_finished},
    });
    try device.waitIdle();
    try command_buffer.markComplete();
    return switch (present_status) {
        .success => if (acquire_suboptimal) .suboptimal else .presented,
        .suboptimal => .suboptimal,
        .out_of_date => .swapchain_out_of_date,
    };
}

pub fn main() void {
    std.log.info(
        "frame_resources.clearAndPresent is ready for a window-created swapchain",
        .{},
    );
}
