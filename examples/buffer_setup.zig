const std = @import("std");
const vk = @import("vulkan");
const support = @import("support.zig");

pub fn main(init: std.process.Init) !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();
    const entry = try loader.entry();

    var instance = try support.createInstance(&entry);
    defer instance.deinit();
    const physical_devices = try instance.physicalDevices(init.gpa);
    defer init.gpa.free(physical_devices);
    if (physical_devices.len == 0) return error.NoPhysicalDevice;

    const physical_device = &physical_devices[0];
    const queue_families = try physical_device.queueFamilies(init.gpa);
    defer init.gpa.free(queue_families);
    const family = for (queue_families) |candidate| {
        if (candidate.supports(.graphics)) break candidate;
    } else return error.NoGraphicsQueue;

    const priorities = [_]f32{1.0};
    var device = try physical_device.createDevice(.{
        .queues = &.{.{ .family_index = family.index, .priorities = &priorities }},
        .enable_portability_subset = vk.platform == .metal,
    });
    defer device.deinit();

    const memory_properties = try physical_device.memoryProperties();
    var vertex_buffer = try device.createAllocatedBufferForProperties(.{
        .buffer = .{
            .size = .fromBytes(4096),
            .usage = .init(&.{ .transfer_src, .vertex_buffer }),
        },
        .memory_properties = &memory_properties,
        .required_memory_flags = .init(&.{ .host_visible, .host_coherent }),
    });
    defer vertex_buffer.deinit();

    std.log.info("created and bound a 4096-byte vertex buffer", .{});
}
