const raw = @import("vulkan_raw");
const std = @import("std");
const types = @import("vulkan_types");
const images = @import("image.zig");
const core = @import("core.zig");

/// Dynamic-rendering behavior flags. The three core/KHR flags are named
/// directly so callers never need to assemble `VkRenderingFlags` values.
pub const Flags = packed struct(u32) {
    secondary_command_buffers: bool = false,
    suspending: bool = false,
    resuming: bool = false,
    _reserved: u29 = 0,

    pub fn toRaw(flags: Flags) raw.VkRenderingFlags {
        var value: raw.VkRenderingFlags = 0;
        if (flags.secondary_command_buffers) value |= raw.VK_RENDERING_CONTENTS_SECONDARY_COMMAND_BUFFERS_BIT;
        if (flags.suspending) value |= raw.VK_RENDERING_SUSPENDING_BIT;
        if (flags.resuming) value |= raw.VK_RENDERING_RESUMING_BIT;
        return value;
    }
};

pub const LoadOperation = enum {
    load,
    clear,
    discard,
    none,

    pub fn toRaw(value: LoadOperation) raw.VkAttachmentLoadOp {
        return switch (value) {
            .load => raw.VK_ATTACHMENT_LOAD_OP_LOAD,
            .clear => raw.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .discard => raw.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            .none => raw.VK_ATTACHMENT_LOAD_OP_NONE,
        };
    }
};

pub const StoreOperation = enum {
    store,
    discard,
    none,

    pub fn toRaw(value: StoreOperation) raw.VkAttachmentStoreOp {
        return switch (value) {
            .store => raw.VK_ATTACHMENT_STORE_OP_STORE,
            .discard => raw.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            .none => raw.VK_ATTACHMENT_STORE_OP_NONE,
        };
    }
};

pub const ResolveMode = enum {
    sample_zero,
    average,
    minimum,
    maximum,

    fn toRaw(value: ResolveMode) raw.VkResolveModeFlagBits {
        return switch (value) {
            .sample_zero => raw.VK_RESOLVE_MODE_SAMPLE_ZERO_BIT,
            .average => raw.VK_RESOLVE_MODE_AVERAGE_BIT,
            .minimum => raw.VK_RESOLVE_MODE_MIN_BIT,
            .maximum => raw.VK_RESOLVE_MODE_MAX_BIT,
        };
    }
};

pub const Resolve = struct {
    mode: ResolveMode,
    view: *const images.View,
    layout: types.ImageLayout,
};

pub const FragmentShadingRateAttachment = struct {
    view: *const images.View,
    layout: types.ImageLayout,
    texel_size: types.Extent2D,
};

pub const FragmentDensityMapAttachment = struct {
    view: *const images.View,
    layout: types.ImageLayout,
};

pub const Attachment = struct {
    view: *const images.View,
    layout: types.ImageLayout,
    resolve: ?Resolve = null,
    load: LoadOperation = .load,
    store: StoreOperation = .store,
    clear: ?types.ClearValue = null,

    pub fn validate(attachment: Attachment, device_handle: core.NonNullHandle(raw.VkDevice)) core.Error!void {
        if (attachment.view._device_handle != device_handle) return error.InvalidHandle;
        if ((attachment.load == .clear) != (attachment.clear != null)) return error.InvalidOptions;
        if (attachment.resolve) |resolve| {
            if (resolve.view._device_handle != device_handle or resolve.view._handle == null) return error.InvalidHandle;
            if (resolve.mode == .average and (attachment.layout == .depth_stencil_attachment_optimal or
                attachment.layout == .depth_attachment_optimal or
                attachment.layout == .stencil_attachment_optimal)) return error.InvalidOptions;
        }
    }

    pub fn toRaw(attachment: Attachment) core.Error!raw.VkRenderingAttachmentInfo {
        const clear_value = if (attachment.clear) |value| value.toRaw() else std.mem.zeroes(raw.VkClearValue);
        return .{
            .sType = raw.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
            .imageView = try attachment.view.rawHandle(),
            .imageLayout = attachment.layout.toRaw(),
            .resolveMode = if (attachment.resolve) |resolve| resolve.mode.toRaw() else raw.VK_RESOLVE_MODE_NONE,
            .resolveImageView = if (attachment.resolve) |resolve| try resolve.view.rawHandle() else null,
            .resolveImageLayout = if (attachment.resolve) |resolve| resolve.layout.toRaw() else raw.VK_IMAGE_LAYOUT_UNDEFINED,
            .loadOp = attachment.load.toRaw(),
            .storeOp = attachment.store.toRaw(),
            .clearValue = clear_value,
        };
    }
};

pub const Options = struct {
    flags: Flags = .{},
    render_area: types.Rect2D,
    layer_count: u32 = 1,
    view_mask: u32 = 0,
    color_attachments: []const Attachment = &.{},
    depth_attachment: ?Attachment = null,
    stencil_attachment: ?Attachment = null,
    fragment_shading_rate_attachment: ?FragmentShadingRateAttachment = null,
    fragment_density_map_attachment: ?FragmentDensityMapAttachment = null,

    pub fn validate(options: Options, device_handle: core.NonNullHandle(raw.VkDevice)) core.Error!void {
        if (options.render_area.extent.width == 0 or options.render_area.extent.height == 0) return error.InvalidOptions;
        if ((options.view_mask == 0 and options.layer_count == 0) or
            (options.view_mask != 0 and options.layer_count != 1)) return error.InvalidOptions;
        if (options.color_attachments.len > 16) return error.CountOverflow;
        for (options.color_attachments) |attachment| try attachment.validate(device_handle);
        if (options.depth_attachment) |attachment| try attachment.validate(device_handle);
        if (options.stencil_attachment) |attachment| try attachment.validate(device_handle);
        if (options.fragment_shading_rate_attachment) |attachment| {
            if (attachment.view._device_handle != device_handle or attachment.view._handle == null) return error.InvalidHandle;
            if (attachment.texel_size.width == 0 or attachment.texel_size.height == 0) return error.InvalidOptions;
        }
        if (options.fragment_density_map_attachment) |attachment| {
            if (attachment.view._device_handle != device_handle or attachment.view._handle == null) return error.InvalidHandle;
        }
    }
};

test "all rendering declarations compile" {
    std.testing.refAllDecls(@This());
}

test "dynamic rendering options validate clear, multiview, and suspend state" {
    const device_handle: core.NonNullHandle(raw.VkDevice) = @ptrFromInt(0x1000);
    const view: images.View = .{
        ._handle = @ptrFromInt(0x2000),
        ._owner = core.Owner.init({}) catch unreachable,
        ._device_handle = device_handle,
        .format = .r8g8b8a8_unorm,
        .samples = ._1,
        .extent = .{ .width = 32, .height = 32, .depth = 1 },
        .layer_count = 1,
        .allocation_callbacks = null,
        .destroy_image_view = undefined,
    };
    const color: Attachment = .{
        .view = &view,
        .layout = .color_attachment_optimal,
        .load = .clear,
        .clear = .{ .color = .{ .float = .{ 0, 0, 0, 1 } } },
    };
    const resolve_view: images.View = .{
        ._handle = @ptrFromInt(0x3000),
        ._owner = core.Owner.init({}) catch unreachable,
        ._device_handle = device_handle,
        .format = .r8g8b8a8_unorm,
        .samples = ._1,
        .extent = .{ .width = 32, .height = 32, .depth = 1 },
        .layer_count = 1,
        .allocation_callbacks = null,
        .destroy_image_view = undefined,
    };
    const resolved_color: Attachment = .{
        .view = &view,
        .layout = .color_attachment_optimal,
        .resolve = .{
            .mode = .average,
            .view = &resolve_view,
            .layout = .color_attachment_optimal,
        },
    };
    try resolved_color.validate(device_handle);
    const raw_resolved = try resolved_color.toRaw();
    try std.testing.expectEqual(@as(raw.VkResolveModeFlagBits, @intCast(raw.VK_RESOLVE_MODE_AVERAGE_BIT)), raw_resolved.resolveMode);
    try Options.validate(.{
        .render_area = .{ .offset = .{ .x = 0, .y = 0 }, .extent = .{ .width = 32, .height = 32 } },
        .view_mask = 0b11,
        .color_attachments = &.{color},
    }, device_handle);
    try Options.validate(.{
        .flags = .{ .suspending = true, .resuming = true },
        .render_area = .{ .offset = .{ .x = 0, .y = 0 }, .extent = .{ .width = 32, .height = 32 } },
        .color_attachments = &.{color},
    }, device_handle);
    const continuation_flags = (Flags{ .suspending = true, .resuming = true }).toRaw();
    try std.testing.expect((continuation_flags & raw.VK_RENDERING_SUSPENDING_BIT) != 0);
    try std.testing.expect((continuation_flags & raw.VK_RENDERING_RESUMING_BIT) != 0);
    var missing_clear = color;
    missing_clear.clear = null;
    try std.testing.expectError(error.InvalidOptions, Options.validate(.{
        .render_area = .{ .offset = .{ .x = 0, .y = 0 }, .extent = .{ .width = 32, .height = 32 } },
        .color_attachments = &.{missing_clear},
    }, device_handle));
    var invalid_depth_resolve = resolved_color;
    invalid_depth_resolve.layout = .depth_attachment_optimal;
    try std.testing.expectError(error.InvalidOptions, invalid_depth_resolve.validate(device_handle));
}
