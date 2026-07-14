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
        const device_name = device.properties().name();
        const depth_format = try chooseDepthFormat(device);
        const limits = (try device.imageFormatProperties2(.{
            .format = depth_format,
            .image_type = ._2d,
            .tiling = .optimal,
            .usage = .init(&.{.depth_stencil_attachment}),
        })) orelse return error.DepthFormatUnsupported;

        std.log.info("{s}: selected {s}", .{ device_name, @tagName(depth_format) });
        std.log.info(
            "  maximum extent: {}x{}, mip levels: {}, samples: 0x{x}",
            .{
                limits.properties.extent_max.width,
                limits.properties.extent_max.height,
                limits.properties.mip_level_count_max,
                limits.properties.sample_counts.toRaw(),
            },
        );
    }
}

fn chooseDepthFormat(device: *const vk.PhysicalDevice) !vk.Format {
    const candidates = [_]vk.Format{
        .d32_sfloat,
        .d32_sfloat_s8_uint,
        .d24_unorm_s8_uint,
    };
    for (candidates) |format| {
        const properties = try device.formatProperties2(format);
        if (properties.optimal_tiling_features.contains(.depth_stencil_attachment)) {
            return format;
        }
    }
    return error.DepthFormatUnsupported;
}
