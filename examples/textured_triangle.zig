const std = @import("std");
const vk = @import("vulkan");

pub fn uploadTexture(
    command_buffer: *vk.CommandBuffer,
    staging_buffer: *const vk.Buffer,
    texture: *const vk.Image,
    extent: vk.Extent3D,
) !void {
    const image: vk.ImageReference = .{ .owned = texture };
    const range: vk.ImageSubresourceRange = .{ .aspect_mask = .init(&.{.color}) };
    try command_buffer.begin(.{ .flags = .init(&.{.one_time_submit}) });
    try command_buffer.pipelineBarrier(.{ .image_barriers = &.{.{
        .source_stage = .init(&.{.top_of_pipe}),
        .destination_stage = .init(&.{.transfer}),
        .destination_access = .init(&.{.transfer_write}),
        .old_layout = .undefined_,
        .new_layout = .transfer_dst_optimal,
        .image = image,
        .subresource_range = range,
    }} });
    try command_buffer.copyBufferToImage(.{
        .source = staging_buffer,
        .destination = image,
        .destination_layout = .transfer_dst_optimal,
        .regions = &.{.{
            .image_subresource = .{ .aspects = .init(&.{.color}) },
            .image_extent = extent,
        }},
    });
    try command_buffer.pipelineBarrier(.{ .image_barriers = &.{.{
        .source_stage = .init(&.{.transfer}),
        .source_access = .init(&.{.transfer_write}),
        .destination_stage = .init(&.{.fragment_shader}),
        .destination_access = .init(&.{.shader_read}),
        .old_layout = .transfer_dst_optimal,
        .new_layout = .shader_read_only_optimal,
        .image = image,
        .subresource_range = range,
    }} });
    try command_buffer.end();
}

pub fn updateTextureDescriptor(
    device: *const vk.Device,
    descriptor_set: *const vk.DescriptorSet,
    sampler: *const vk.Sampler,
    texture_view: *const vk.ImageView,
) !void {
    try device.updateDescriptorSets(&.{.{
        .destination = descriptor_set,
        .binding = 0,
        .data = .{ .combined_image_sampler = &.{.{
            .sampler = sampler,
            .view = texture_view,
            .layout = .shader_read_only_optimal,
        }} },
    }}, &.{});
}

/// Records the draw after the texture upload and descriptor update have completed.
pub fn record(
    command_buffer: *vk.CommandBuffer,
    pipeline: *const vk.Pipeline,
    pipeline_layout: *const vk.PipelineLayout,
    texture_set: *const vk.DescriptorSet,
    vertex_buffer: *const vk.Buffer,
    color_view: *const vk.ImageView,
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
            .clear = .{ .color = .{ .float = .{ 0.0, 0.0, 0.0, 1.0 } } },
        }},
    });
    try command_buffer.bindPipeline(pipeline);
    try command_buffer.bindDescriptorSets(.graphics, pipeline_layout, 0, &.{texture_set}, &.{});
    try command_buffer.bindVertexBuffers(0, &.{.{ .buffer = vertex_buffer }});
    try command_buffer.draw(.{ .vertex_count = 3 });
    try rendering.end();
    try command_buffer.end();
}

pub fn main() void {
    std.log.info("textured_triangle.record uses typed descriptors and dynamic rendering", .{});
}
