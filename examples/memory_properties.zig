const std = @import("std");
const vk = @import("vulkan");
const support = @import("support.zig");

pub fn main(init: std.process.Init) !void {
    var loader = try vk.Loader.init();
    defer loader.deinit();
    const entry = try loader.entry();

    var instance = try support.createInstance(&entry);
    defer instance.deinit();
    const devices = try instance.physicalDevices(init.gpa);
    defer init.gpa.free(devices);

    for (devices) |*device| {
        const device_properties = device.properties();
        const memory = try device.memoryProperties();
        std.log.info("{s} memory heaps:", .{vk.physicalDeviceName(&device_properties)});

        for (memory.heaps()) |heap| {
            const size_mib = @divFloor(heap.size_bytes, 1024 * 1024);
            std.log.info(
                "  heap {d}: {d} MiB, device-local={}",
                .{ heap.index.toRaw(), size_mib, heap.isDeviceLocal() },
            );
        }
        for (memory.types()) |memory_type| {
            std.log.info(
                "  type {d}: heap={d}, device-local={}, host-visible={}, host-coherent={}",
                .{
                    memory_type.index.toRaw(),
                    memory_type.heap_index.toRaw(),
                    memory_type.flags.contains(.device_local),
                    memory_type.flags.contains(.host_visible),
                    memory_type.flags.contains(.host_coherent),
                },
            );
        }
        std.log.info(
            "  total device-local memory: {d} MiB",
            .{@divFloor(try memory.deviceLocalBytes(), 1024 * 1024)},
        );
        const host_visible = device.findMemoryTypeIndex(.{
            .type_bits = std.math.maxInt(u32),
            .required_flags = .init(&.{.host_visible}),
            .preferred_flags = .init(&.{.host_coherent}),
        }) catch null;
        if (host_visible) |index| {
            std.log.info("  preferred host-visible type: {d}", .{index});
        }
    }
}
