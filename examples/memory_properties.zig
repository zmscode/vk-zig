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
        const memory = device.memoryProperties();
        std.log.info("{s} memory heaps:", .{vk.physicalDeviceName(&device_properties)});

        for (memory.memoryHeaps[0..memory.memoryHeapCount], 0..) |heap, index| {
            const size_mib = @divFloor(heap.size, 1024 * 1024);
            std.log.info(
                "  heap {d}: {d} MiB, flags=0x{x}",
                .{ index, size_mib, heap.flags },
            );
        }
        for (memory.memoryTypes[0..memory.memoryTypeCount], 0..) |memory_type, index| {
            std.log.info(
                "  type {d}: heap={d}, flags=0x{x}",
                .{ index, memory_type.heapIndex, memory_type.propertyFlags },
            );
        }
    }
}
