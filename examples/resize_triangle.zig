const std = @import("std");
const vk = @import("vulkan");

/// Records a triangle with dynamic viewport/scissor state, so resize only changes `extent`.
pub fn record(
    command_buffer: *vk.CommandBuffer,
    pipeline: *const vk.Pipeline,
    color_view: *const vk.ImageView,
    vertex_buffer: *const vk.Buffer,
    extent: vk.Extent2D,
) !void {
    try command_buffer.begin(.{ .flags = .init(&.{.one_time_submit}) });
    var rendering = try command_buffer.beginRendering(.{
        .render_area = .{ .offset = .{ .x = 0, .y = 0 }, .extent = extent },
        .color_attachments = &.{.{
            .view = color_view,
            .layout = .color_attachment_optimal,
            .load = .clear,
            .store = .store,
            .clear = .{ .color = .{ .float = .{ 0.02, 0.03, 0.05, 1.0 } } },
        }},
    });
    try command_buffer.bindPipeline(pipeline);
    try command_buffer.setViewport(.{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(extent.width),
        .height = @floatFromInt(extent.height),
    });
    try command_buffer.setScissor(.{ .offset = .{ .x = 0, .y = 0 }, .extent = extent });
    try command_buffer.bindVertexBuffers(0, &.{.{ .buffer = vertex_buffer }});
    try command_buffer.draw(.{ .vertex_count = 3 });
    try rendering.end();
    try command_buffer.end();
}

pub fn main() void {
    std.log.info("resize_triangle.record rebuilds only extent-dependent state", .{});
}
