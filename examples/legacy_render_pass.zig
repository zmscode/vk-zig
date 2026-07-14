const std = @import("std");
const vk = @import("vulkan");

/// Creates and records a complete raw-free compatibility render pass.
pub fn record(
    device: *const vk.Device,
    command_buffer: *vk.CommandBuffer,
    color_view: *const vk.ImageView,
    format: vk.Format,
    extent: vk.Extent2D,
) !void {
    var render_pass = try device.createRenderPass(.{
        .attachments = &.{.{
            .format = format,
            .load = .clear,
            .store = .store,
            .final_layout = .color_attachment_optimal,
        }},
        .subpasses = &.{.{
            .color_attachments = &.{.{
                .attachment = .{
                    .index = 0,
                    .layout = .color_attachment_optimal,
                },
            }},
        }},
    });
    defer render_pass.deinit();

    var framebuffer = try device.createFramebuffer(.{
        .render_pass = &render_pass,
        .width = extent.width,
        .height = extent.height,
        .attachments = .{ .views = &.{color_view} },
    });
    defer framebuffer.deinit();

    try command_buffer.begin(.{ .flags = .init(&.{.one_time_submit}) });
    var scope = try command_buffer.beginRenderPass(.{
        .render_pass = &render_pass,
        .framebuffer = &framebuffer,
        .render_area = .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = extent,
        },
        .clear_values = &.{.{
            .color = .{ .float = .{ 0.03, 0.05, 0.09, 1.0 } },
        }},
    });
    try scope.end();
    try command_buffer.end();
}

pub fn main() void {
    std.log.info("legacy_render_pass.record is ready for a created image view", .{});
}
