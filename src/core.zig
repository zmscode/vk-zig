const std = @import("std");
const raw = @import("vulkan_raw");

pub const Error = error{
    OutOfHostMemory,
    OutOfDeviceMemory,
    InitializationFailed,
    DeviceLost,
    MemoryMapFailed,
    LayerNotPresent,
    ExtensionNotPresent,
    FeatureNotPresent,
    IncompatibleDriver,
    TooManyObjects,
    FormatNotSupported,
    FragmentedPool,
    UnknownVulkanError,
    UnexpectedVulkanResult,
    MissingCommand,
    EnumerationUnstable,
    InactiveObject,
    InvalidHandle,
    InvalidOptions,
    CountOverflow,
    PortabilityNotSupported,
    MemoryTypeNotFound,
    SurfaceLost,
    NativeWindowInUse,
    FullScreenExclusiveLost,
    BufferTooSmall,
    InvalidProperties,
    SizeOverflow,
    UnsupportedSurfaceConfiguration,
    QueueFamilyNotFound,
};

pub const LoaderError = error{
    VulkanLoaderNotFound,
    VulkanEntryPointMissing,
};

pub const Version = struct {
    variant: u3 = 0,
    major: u7,
    minor: u10,
    patch: u12,

    pub fn encode(version: Version) u32 {
        return (@as(u32, version.variant) << 29) |
            (@as(u32, version.major) << 22) |
            (@as(u32, version.minor) << 12) |
            @as(u32, version.patch);
    }

    pub fn decode(encoded: u32) Version {
        return .{
            .variant = @truncate(encoded >> 29),
            .major = @truncate(encoded >> 22),
            .minor = @truncate(encoded >> 12),
            .patch = @truncate(encoded),
        };
    }

    pub fn lessThan(version: Version, other: Version) bool {
        return version.encode() < other.encode();
    }

    pub fn atLeast(version: Version, minimum: Version) bool {
        return !version.lessThan(minimum);
    }

    pub fn format(version: Version, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        if (version.variant != 0) try writer.print("{d}:", .{version.variant});
        try writer.print("{d}.{d}.{d}", .{ version.major, version.minor, version.patch });
    }

    pub const v1_0: Version = .{ .major = 1, .minor = 0, .patch = 0 };
    pub const v1_1: Version = .{ .major = 1, .minor = 1, .patch = 0 };
    pub const v1_2: Version = .{ .major = 1, .minor = 2, .patch = 0 };
    pub const v1_3: Version = .{ .major = 1, .minor = 3, .patch = 0 };
    pub const v1_4: Version = .{ .major = 1, .minor = 4, .patch = 0 };
};

pub const QueueFamilyIndex = enum(u32) {
    _,

    pub fn fromRaw(value: u32) QueueFamilyIndex {
        return @enumFromInt(value);
    }

    pub fn toRaw(index: QueueFamilyIndex) u32 {
        return @intFromEnum(index);
    }
};

pub const QueueIndex = enum(u32) {
    first = 0,
    _,

    pub fn fromRaw(value: u32) QueueIndex {
        return @enumFromInt(value);
    }

    pub fn toRaw(index: QueueIndex) u32 {
        return @intFromEnum(index);
    }
};

pub const SwapchainImageIndex = enum(u32) {
    _,

    pub fn fromRaw(value: u32) SwapchainImageIndex {
        return @enumFromInt(value);
    }

    pub fn toRaw(index: SwapchainImageIndex) u32 {
        return @intFromEnum(index);
    }
};

pub const MemoryTypeIndex = enum(u32) {
    _,

    pub fn fromRaw(value: u32) MemoryTypeIndex {
        return @enumFromInt(value);
    }

    pub fn toRaw(index: MemoryTypeIndex) u32 {
        return @intFromEnum(index);
    }
};

pub const MemoryHeapIndex = enum(u32) {
    _,

    pub fn fromRaw(value: u32) MemoryHeapIndex {
        return @enumFromInt(value);
    }

    pub fn toRaw(index: MemoryHeapIndex) u32 {
        return @intFromEnum(index);
    }
};

pub const DeviceSize = enum(u64) {
    _,

    pub fn fromBytes(value: u64) DeviceSize {
        return @enumFromInt(value);
    }

    pub fn bytes(size: DeviceSize) u64 {
        return @intFromEnum(size);
    }
};

pub const DeviceOffset = enum(u64) {
    zero = 0,
    _,

    pub fn fromBytes(value: u64) DeviceOffset {
        return @enumFromInt(value);
    }

    pub fn bytes(offset: DeviceOffset) u64 {
        return @intFromEnum(offset);
    }
};

pub const DeviceRange = union(enum) {
    whole,
    bytes: DeviceSize,

    pub fn toRaw(range: DeviceRange) u64 {
        return switch (range) {
            .whole => raw.VK_WHOLE_SIZE,
            .bytes => |size| size.bytes(),
        };
    }
};

pub const Timeout = union(enum) {
    infinite,
    nanoseconds: u64,

    pub const immediate: Timeout = .{ .nanoseconds = 0 };

    pub fn toRaw(timeout: Timeout) u64 {
        return switch (timeout) {
            .infinite => std.math.maxInt(u64),
            .nanoseconds => |value| value,
        };
    }
};

pub const QueueFamilyOwnership = union(enum) {
    ignored,
    transfer: struct {
        source: QueueFamilyIndex,
        destination: QueueFamilyIndex,
    },

    pub fn sourceRaw(ownership: QueueFamilyOwnership) u32 {
        return switch (ownership) {
            .ignored => raw.VK_QUEUE_FAMILY_IGNORED,
            .transfer => |transfer| transfer.source.toRaw(),
        };
    }

    pub fn destinationRaw(ownership: QueueFamilyOwnership) u32 {
        return switch (ownership) {
            .ignored => raw.VK_QUEUE_FAMILY_IGNORED,
            .transfer => |transfer| transfer.destination.toRaw(),
        };
    }
};

pub fn NonNullHandle(comptime OptionalHandle: type) type {
    return switch (@typeInfo(OptionalHandle)) {
        .optional => |optional| optional.child,
        else => @compileError("expected an optional Vulkan handle type"),
    };
}

/// Maps errors for commands whose only successful result is `VK_SUCCESS`.
/// Do not use this for enumerate, wait, acquire, or present commands that allow status results.
pub fn checkSuccess(result: raw.VkResult) Error!void {
    if (result == raw.VK_SUCCESS) return;
    if (result == raw.VK_ERROR_OUT_OF_HOST_MEMORY) return error.OutOfHostMemory;
    if (result == raw.VK_ERROR_OUT_OF_DEVICE_MEMORY) return error.OutOfDeviceMemory;
    if (result == raw.VK_ERROR_INITIALIZATION_FAILED) return error.InitializationFailed;
    if (result == raw.VK_ERROR_DEVICE_LOST) return error.DeviceLost;
    if (result == raw.VK_ERROR_MEMORY_MAP_FAILED) return error.MemoryMapFailed;
    if (result == raw.VK_ERROR_LAYER_NOT_PRESENT) return error.LayerNotPresent;
    if (result == raw.VK_ERROR_EXTENSION_NOT_PRESENT) return error.ExtensionNotPresent;
    if (result == raw.VK_ERROR_FEATURE_NOT_PRESENT) return error.FeatureNotPresent;
    if (result == raw.VK_ERROR_INCOMPATIBLE_DRIVER) return error.IncompatibleDriver;
    if (result == raw.VK_ERROR_TOO_MANY_OBJECTS) return error.TooManyObjects;
    if (result == raw.VK_ERROR_FORMAT_NOT_SUPPORTED) return error.FormatNotSupported;
    if (result == raw.VK_ERROR_FRAGMENTED_POOL) return error.FragmentedPool;
    if (result == raw.VK_ERROR_UNKNOWN) return error.UnknownVulkanError;
    if (result == raw.VK_ERROR_SURFACE_LOST_KHR) return error.SurfaceLost;
    if (result == raw.VK_ERROR_NATIVE_WINDOW_IN_USE_KHR) return error.NativeWindowInUse;
    if (result == raw.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT) {
        return error.FullScreenExclusiveLost;
    }
    return error.UnexpectedVulkanResult;
}

pub fn count32(count: usize) Error!u32 {
    return std.math.cast(u32, count) orelse error.CountOverflow;
}

pub fn handleValue(handle: anytype) Error!u64 {
    const Handle = @TypeOf(handle);
    return switch (@typeInfo(Handle)) {
        .optional => if (handle) |live_handle| handleValue(live_handle) else error.InvalidHandle,
        .pointer => @intCast(@intFromPtr(handle)),
        .int => if (handle == 0) error.InvalidHandle else @intCast(handle),
        else => @compileError("expected a Vulkan pointer or integer handle"),
    };
}
