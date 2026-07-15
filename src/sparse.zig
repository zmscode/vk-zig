const buffer = @import("buffer.zig");
const core = @import("core.zig");
const image = @import("image.zig");
const memory = @import("memory.zig");
const synchronization = @import("synchronization.zig");
const types = @import("vulkan_types");

pub const batch_count_max = 16;
pub const resource_count_max = 64;
pub const memory_bind_count_max = 256;
pub const semaphore_count_max = 64;

pub const MemoryBindFlags = packed struct(u1) {
    metadata: bool = false,
};

/// A sparse memory range. A null allocation removes an existing binding.
///
/// Vulkan does not retain this CPU descriptor, but a non-null allocation must
/// remain alive and allocated for as long as the sparse pages remain resident.
pub const MemoryBind = struct {
    resource_offset: core.DeviceOffset,
    size: core.DeviceSize,
    allocation: ?*const memory.Allocation,
    memory_offset: core.DeviceOffset = .zero,
    flags: MemoryBindFlags = .{},
};

pub const BufferBind = struct {
    buffer: *const buffer.Buffer,
    binds: []const MemoryBind,
};

/// Opaque image ranges include mip tails. Set metadata only for a metadata
/// aspect requirement; ordinary image and buffer binds must leave it false.
pub const OpaqueImageBind = struct {
    image: *const image.Image,
    binds: []const MemoryBind,
};

/// A sparse image tile. A null allocation makes the tile non-resident.
pub const ImageMemoryBind = struct {
    subresource: image.Subresource,
    offset: types.Offset3D,
    extent: types.Extent3D,
    allocation: ?*const memory.Allocation,
    memory_offset: core.DeviceOffset = .zero,
};

pub const ImageBind = struct {
    image: *const image.Image,
    binds: []const ImageMemoryBind,
};

pub const Batch = struct {
    waits: []const *const synchronization.Semaphore = &.{},
    buffer_binds: []const BufferBind = &.{},
    opaque_image_binds: []const OpaqueImageBind = &.{},
    image_binds: []const ImageBind = &.{},
    signals: []const *const synchronization.Semaphore = &.{},
};

pub const BindOptions = struct {
    batches: []const Batch,
    fence: ?*const synchronization.Fence = null,
};

test "all sparse declarations compile" {
    @import("std").testing.refAllDecls(@This());
}
