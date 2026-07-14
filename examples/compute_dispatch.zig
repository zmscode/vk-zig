const std = @import("std");
const vk = @import("vulkan");

pub fn upload(buffer: *vk.AllocatedBuffer, bytes: []const u8) !void {
    var mapped = try buffer.memory.map(.{
        .range = .{ .bytes = .fromBytes(bytes.len) },
    });
    defer mapped.deinit();
    @memcpy((try mapped.bytes())[0..bytes.len], bytes);
    try mapped.flush();
}

pub fn record(
    command_buffer: *vk.CommandBuffer,
    pipeline: *const vk.Pipeline,
    layout: *const vk.PipelineLayout,
    descriptor_set: *const vk.DescriptorSet,
    group_count: vk.DispatchOptions,
) !void {
    try command_buffer.begin(.{ .flags = .init(&.{.one_time_submit}) });
    try command_buffer.bindPipeline(pipeline);
    try command_buffer.bindDescriptorSets(.compute, layout, 0, &.{descriptor_set}, &.{});
    try command_buffer.dispatch(group_count);
    try command_buffer.end();
}

pub fn readback(buffer: *vk.AllocatedBuffer, output: []u8) !void {
    var mapped = try buffer.memory.map(.{
        .range = .{ .bytes = .fromBytes(output.len) },
    });
    defer mapped.deinit();
    try mapped.invalidate();
    @memcpy(output, (try mapped.bytes())[0..output.len]);
}

pub fn main() void {
    std.log.info("compute_dispatch exposes typed upload, dispatch, and readback helpers", .{});
}
