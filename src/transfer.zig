const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const core = @import("core.zig");
const buffers = @import("buffer.zig");
const images = @import("image.zig");

pub const SubresourceLayers = struct {
    aspects: types.ImageAspectFlags,
    mip_level: u32 = 0,
    base_array_layer: u32 = 0,
    layer_count: u32 = 1,

    pub fn toRaw(value: SubresourceLayers) core.Error!raw.VkImageSubresourceLayers {
        if (value.aspects.isEmpty() or value.layer_count == 0) return error.InvalidOptions;
        return .{
            .aspectMask = value.aspects.toRaw(),
            .mipLevel = value.mip_level,
            .baseArrayLayer = value.base_array_layer,
            .layerCount = value.layer_count,
        };
    }
};

pub const BufferCopy = struct {
    source_offset: core.DeviceOffset = .zero,
    destination_offset: core.DeviceOffset = .zero,
    size: core.DeviceSize,
};

pub const BufferImageCopy = struct {
    buffer_offset: core.DeviceOffset = .zero,
    buffer_row_length: u32 = 0,
    buffer_image_height: u32 = 0,
    image_subresource: SubresourceLayers,
    image_offset: types.Offset3D = .{ .x = 0, .y = 0, .z = 0 },
    image_extent: types.Extent3D,

    pub fn toRaw(value: BufferImageCopy) core.Error!raw.VkBufferImageCopy {
        if (value.image_extent.width == 0 or value.image_extent.height == 0 or value.image_extent.depth == 0) {
            return error.InvalidOptions;
        }
        return .{
            .bufferOffset = value.buffer_offset.bytes(),
            .bufferRowLength = value.buffer_row_length,
            .bufferImageHeight = value.buffer_image_height,
            .imageSubresource = try value.image_subresource.toRaw(),
            .imageOffset = value.image_offset.toRaw(),
            .imageExtent = value.image_extent.toRaw(),
        };
    }

    pub fn toRaw2(value: BufferImageCopy) core.Error!raw.VkBufferImageCopy2 {
        const legacy = try value.toRaw();
        return .{ .sType = raw.VK_STRUCTURE_TYPE_BUFFER_IMAGE_COPY_2, .bufferOffset = legacy.bufferOffset, .bufferRowLength = legacy.bufferRowLength, .bufferImageHeight = legacy.bufferImageHeight, .imageSubresource = legacy.imageSubresource, .imageOffset = legacy.imageOffset, .imageExtent = legacy.imageExtent };
    }
};

pub const ImageCopy = struct {
    source_subresource: SubresourceLayers,
    source_offset: types.Offset3D = .{ .x = 0, .y = 0, .z = 0 },
    destination_subresource: SubresourceLayers,
    destination_offset: types.Offset3D = .{ .x = 0, .y = 0, .z = 0 },
    extent: types.Extent3D,

    pub fn toRaw(value: ImageCopy) core.Error!raw.VkImageCopy {
        if (value.extent.width == 0 or value.extent.height == 0 or value.extent.depth == 0) return error.InvalidOptions;
        return .{
            .srcSubresource = try value.source_subresource.toRaw(),
            .srcOffset = value.source_offset.toRaw(),
            .dstSubresource = try value.destination_subresource.toRaw(),
            .dstOffset = value.destination_offset.toRaw(),
            .extent = value.extent.toRaw(),
        };
    }

    pub fn toRaw2(value: ImageCopy) core.Error!raw.VkImageCopy2 {
        const legacy = try value.toRaw();
        return .{ .sType = raw.VK_STRUCTURE_TYPE_IMAGE_COPY_2, .srcSubresource = legacy.srcSubresource, .srcOffset = legacy.srcOffset, .dstSubresource = legacy.dstSubresource, .dstOffset = legacy.dstOffset, .extent = legacy.extent };
    }
};

pub const ImageBlit = struct {
    source_subresource: SubresourceLayers,
    source_offsets: [2]types.Offset3D,
    destination_subresource: SubresourceLayers,
    destination_offsets: [2]types.Offset3D,

    pub fn toRaw(value: ImageBlit) core.Error!raw.VkImageBlit {
        return .{
            .srcSubresource = try value.source_subresource.toRaw(),
            .srcOffsets = .{ value.source_offsets[0].toRaw(), value.source_offsets[1].toRaw() },
            .dstSubresource = try value.destination_subresource.toRaw(),
            .dstOffsets = .{ value.destination_offsets[0].toRaw(), value.destination_offsets[1].toRaw() },
        };
    }

    pub fn toRaw2(value: ImageBlit) core.Error!raw.VkImageBlit2 {
        const legacy = try value.toRaw();
        return .{ .sType = raw.VK_STRUCTURE_TYPE_IMAGE_BLIT_2, .srcSubresource = legacy.srcSubresource, .srcOffsets = legacy.srcOffsets, .dstSubresource = legacy.dstSubresource, .dstOffsets = legacy.dstOffsets };
    }
};

pub const ImageResolve = struct {
    source_subresource: SubresourceLayers,
    source_offset: types.Offset3D = .{ .x = 0, .y = 0, .z = 0 },
    destination_subresource: SubresourceLayers,
    destination_offset: types.Offset3D = .{ .x = 0, .y = 0, .z = 0 },
    extent: types.Extent3D,

    pub fn toRaw(value: ImageResolve) core.Error!raw.VkImageResolve {
        if (value.extent.width == 0 or value.extent.height == 0 or value.extent.depth == 0) return error.InvalidOptions;
        return .{
            .srcSubresource = try value.source_subresource.toRaw(),
            .srcOffset = value.source_offset.toRaw(),
            .dstSubresource = try value.destination_subresource.toRaw(),
            .dstOffset = value.destination_offset.toRaw(),
            .extent = value.extent.toRaw(),
        };
    }

    pub fn toRaw2(value: ImageResolve) core.Error!raw.VkImageResolve2 {
        const legacy = try value.toRaw();
        return .{ .sType = raw.VK_STRUCTURE_TYPE_IMAGE_RESOLVE_2, .srcSubresource = legacy.srcSubresource, .srcOffset = legacy.srcOffset, .dstSubresource = legacy.dstSubresource, .dstOffset = legacy.dstOffset, .extent = legacy.extent };
    }
};

pub const BufferToImage = struct {
    source: *const buffers.Buffer,
    destination: images.Reference,
    destination_layout: types.ImageLayout,
    regions: []const BufferImageCopy,
};

pub const ImageToBuffer = struct {
    source: images.Reference,
    source_layout: types.ImageLayout,
    destination: *const buffers.Buffer,
    regions: []const BufferImageCopy,
};

pub const ImageToImage = struct {
    source: images.Reference,
    source_layout: types.ImageLayout,
    destination: images.Reference,
    destination_layout: types.ImageLayout,
    regions: []const ImageCopy,
};

test "all transfer declarations compile" {
    @import("std").testing.refAllDecls(@This());
}
