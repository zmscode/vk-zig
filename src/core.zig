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
    OutOfPoolMemory,
    InvalidExternalHandle,
    Fragmentation,
    InvalidOpaqueCaptureAddress,
    InvalidPipelineCacheData,
    NoPipelineMatch,
    ValidationFailed,
    NotPermitted,
    InvalidShader,
    ImageUsageNotSupported,
    VideoPictureLayoutNotSupported,
    VideoProfileOperationNotSupported,
    VideoProfileFormatNotSupported,
    VideoProfileCodecNotSupported,
    VideoStdVersionNotSupported,
    InvalidDrmFormatModifierPlaneLayout,
    PresentTimingQueueFull,
    InvalidVideoStdParameters,
    CompressionExhausted,
    NotEnoughSpace,
    BufferTooSmall,
    InvalidProperties,
    SizeOverflow,
    UnsupportedSurfaceConfiguration,
    QueueFamilyNotFound,
    CopiedOwner,
    StaleBorrow,
    DeviceDestroyed,
    CapacityExceeded,
    UnsupportedCodec,
    UnsupportedOperation,
};

pub const LoaderError = error{
    VulkanLoaderNotFound,
    VulkanEntryPointMissing,
    CapacityExceeded,
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

/// The state shared by a device and every child wrapper created from it.
///
/// Device loss is monotonic: once observed, dispatching operations fail locally with
/// `error.DeviceLost`. Destruction remains permitted because Vulkan cleanup is host-only and
/// must stay idempotent after loss. The wrapper never attempts transparent device recovery.
pub const DeviceState = struct {
    token: Owner,

    pub const Status = enum(u8) {
        active,
        lost,
        destroyed,
    };

    pub fn init() Error!DeviceState {
        const token = try Owner.init({});
        device_status_slots[token.slot].store(@intFromEnum(Status.active), .release);
        return .{ .token = token };
    }

    pub fn status(state: *const DeviceState) Status {
        state.token.validate(state) catch return .destroyed;
        return @enumFromInt(device_status_slots[state.token.slot].load(.acquire));
    }

    pub fn ensureDispatchAllowed(state: *const DeviceState) Error!void {
        return switch (state.status()) {
            .active => {},
            .lost => error.DeviceLost,
            .destroyed => error.InactiveObject,
        };
    }

    pub fn markLost(state: *DeviceState) void {
        state.token.validate(state) catch return;
        const active = @intFromEnum(Status.active);
        const lost = @intFromEnum(Status.lost);
        _ = device_status_slots[state.token.slot].cmpxchgStrong(active, lost, .acq_rel, .acquire);
    }

    pub fn markDestroyed(state: *DeviceState) void {
        if (!(state.token.release(state) catch return)) return;
        device_status_slots[state.token.slot].store(@intFromEnum(Status.destroyed), .release);
    }
};

const owner_slot_count = 16_384;
var owner_slots: [owner_slot_count]std.atomic.Value(u64) =
    @splat(.init(0));
var device_status_slots: [owner_slot_count]std.atomic.Value(u8) =
    @splat(.init(@intFromEnum(DeviceState.Status.destroyed)));
var next_owner_token: std.atomic.Value(u64) = .init(1);

/// A process-local atomic token shared by every bitwise copy of an owning wrapper.
///
/// Zig permits struct copies, so an address-bound guard would reject ordinary return-value moves.
/// Instead, every live owner reserves a generation-tagged slot. Exactly one copy can release that
/// slot and destroy the Vulkan handle; all other copies subsequently fail validation and their
/// cleanup becomes a no-op. Slots are reused safely because the monotonically increasing token
/// prevents an old copy from matching a newer owner.
pub const Owner = struct {
    slot: u32,
    token: u64,
    active: bool = true,

    pub fn init(_: anytype) Error!Owner {
        var token = next_owner_token.fetchAdd(1, .monotonic);
        if (token == 0) token = next_owner_token.fetchAdd(1, .monotonic);
        const start: usize = @intCast(token % owner_slot_count);
        for (0..owner_slot_count) |offset| {
            const slot = (start + offset) % owner_slot_count;
            if (owner_slots[slot].cmpxchgStrong(0, token, .acq_rel, .acquire) == null) {
                return .{ .slot = @intCast(slot), .token = token };
            }
        }
        return error.CapacityExceeded;
    }

    pub fn validate(owner: *const Owner, _: anytype) Error!void {
        if (!owner.active) return error.InactiveObject;
        if (owner_slots[owner.slot].load(.acquire) != owner.token) return error.CopiedOwner;
    }

    pub fn release(owner: *Owner, _: anytype) Error!bool {
        if (!owner.active) return false;
        owner.active = false;
        return owner_slots[owner.slot].cmpxchgStrong(
            owner.token,
            0,
            .acq_rel,
            .acquire,
        ) == null;
    }

    pub fn rebind(owner: *Owner, source: anytype, _: anytype) Error!void {
        try owner.validate(source);
    }

    pub fn borrow(owner: *const Owner) Borrow {
        return .{ .slot = owner.slot, .token = owner.token };
    }

    pub const Borrow = struct {
        slot: u32,
        token: u64,

        pub fn validate(borrowed: Borrow) Error!void {
            if (owner_slots[borrowed.slot].load(.acquire) != borrowed.token) {
                return error.StaleBorrow;
            }
        }
    };
};

/// A parent generation shared with borrowed child handles.
pub const Generation = struct {
    value: u64 = 1,
    active: bool = true,

    pub fn borrow(generation: *const Generation) Borrow {
        return .{ .parent = generation, .value = generation.value };
    }

    pub fn borrowOwner(generation: *const Generation, owner: *const Owner) Borrow {
        return .{
            .parent = generation,
            .value = generation.value,
            .owner = owner.borrow(),
        };
    }

    pub fn advance(generation: *Generation) void {
        generation.value +%= 1;
        if (generation.value == 0) generation.value = 1;
    }

    pub fn invalidate(generation: *Generation) void {
        if (!generation.active) return;
        generation.active = false;
        generation.advance();
    }

    pub const Borrow = struct {
        parent: *const Generation,
        value: u64,
        owner: ?Owner.Borrow = null,

        pub fn validate(borrowed: Borrow) Error!void {
            if (borrowed.owner) |owner| try owner.validate();
            if (!borrowed.parent.active) return error.StaleBorrow;
            if (borrowed.parent.value != borrowed.value) return error.StaleBorrow;
        }
    };
};

/// Host synchronization and GPU-lifetime metadata attached to public wrapper operations.
/// No hidden mutex is taken; callers retain ownership of their threading policy.
pub const Contract = struct {
    host_access: HostAccess,
    gpu_lifetime: GpuLifetime = .not_retained,

    pub const HostAccess = enum {
        immutable_query,
        distinct_children_concurrent,
        externally_synchronized,
    };

    pub const GpuLifetime = enum {
        not_retained,
        until_command_recording_ends,
        until_submission_completes,
    };
};

/// Non-fatal Vulkan outcomes that must not be collapsed into a success-only helper.
pub const ResultStatus = enum {
    success,
    not_ready,
    timeout,
    incomplete,
    suboptimal,
    out_of_date,
    pipeline_compile_required,
    deferred,
    thread_done,
    thread_idle,
    operation_deferred,
    operation_not_deferred,
    incompatible_shader_binary,
    pipeline_binary_missing,
};

/// Classifies every common Vulkan status and maps fatal results to the shared error set.
pub fn classifyResult(result: raw.VkResult) Error!ResultStatus {
    if (result == raw.VK_SUCCESS) return .success;
    if (result == raw.VK_NOT_READY) return .not_ready;
    if (result == raw.VK_TIMEOUT) return .timeout;
    if (result == raw.VK_INCOMPLETE) return .incomplete;
    if (result == raw.VK_SUBOPTIMAL_KHR) return .suboptimal;
    if (result == raw.VK_ERROR_OUT_OF_DATE_KHR) return .out_of_date;
    if (result == raw.VK_PIPELINE_COMPILE_REQUIRED) return .pipeline_compile_required;
    if (result == raw.VK_THREAD_DONE_KHR) return .thread_done;
    if (result == raw.VK_THREAD_IDLE_KHR) return .thread_idle;
    if (result == raw.VK_OPERATION_DEFERRED_KHR) return .operation_deferred;
    if (result == raw.VK_OPERATION_NOT_DEFERRED_KHR) return .operation_not_deferred;
    if (result == raw.VK_INCOMPATIBLE_SHADER_BINARY_EXT) return .incompatible_shader_binary;
    if (result == raw.VK_PIPELINE_BINARY_MISSING_KHR) return .pipeline_binary_missing;
    return mapFatalResult(result);
}

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
    return mapFatalResult(result);
}

/// Maps a success-only command and records confirmed device loss for future short-circuiting.
pub fn checkSuccessTracked(state: *DeviceState, result: raw.VkResult) Error!void {
    if (result == raw.VK_SUCCESS) return;
    if (result == raw.VK_ERROR_DEVICE_LOST) state.markLost();
    return mapFatalResult(result);
}

/// Maps a success-only child operation, recording device loss when the wrapper belongs to a
/// tracked `Device`. Standalone low-level wrappers may pass `null` and retain ordinary mapping.
pub fn checkSuccessOptional(state: ?*const DeviceState, result: raw.VkResult) Error!void {
    if (state) |tracked| return checkSuccessTracked(@constCast(tracked), result);
    return checkSuccess(result);
}

/// Classifies a status-bearing command and records confirmed device loss.
pub fn classifyResultTracked(state: *DeviceState, result: raw.VkResult) Error!ResultStatus {
    if (result == raw.VK_ERROR_DEVICE_LOST) state.markLost();
    return classifyResult(result);
}

fn mapFatalResult(result: raw.VkResult) Error {
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
    if (result == raw.VK_ERROR_OUT_OF_POOL_MEMORY) return error.OutOfPoolMemory;
    if (result == raw.VK_ERROR_INVALID_EXTERNAL_HANDLE) return error.InvalidExternalHandle;
    if (result == raw.VK_ERROR_FRAGMENTATION) return error.Fragmentation;
    if (result == raw.VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS) return error.InvalidOpaqueCaptureAddress;
    if (comptime @hasDecl(raw, "VK_ERROR_INVALID_PIPELINE_CACHE_DATA")) {
        if (result == @field(raw, "VK_ERROR_INVALID_PIPELINE_CACHE_DATA")) {
            return error.InvalidPipelineCacheData;
        }
    }
    if (comptime @hasDecl(raw, "VK_ERROR_NO_PIPELINE_MATCH")) {
        if (result == @field(raw, "VK_ERROR_NO_PIPELINE_MATCH")) return error.NoPipelineMatch;
    }
    if (result == raw.VK_ERROR_VALIDATION_FAILED) return error.ValidationFailed;
    if (result == raw.VK_ERROR_NOT_PERMITTED) return error.NotPermitted;
    if (result == raw.VK_ERROR_INVALID_SHADER_NV) return error.InvalidShader;
    if (result == raw.VK_ERROR_IMAGE_USAGE_NOT_SUPPORTED_KHR) return error.ImageUsageNotSupported;
    if (result == raw.VK_ERROR_VIDEO_PICTURE_LAYOUT_NOT_SUPPORTED_KHR) {
        return error.VideoPictureLayoutNotSupported;
    }
    if (result == raw.VK_ERROR_VIDEO_PROFILE_OPERATION_NOT_SUPPORTED_KHR) {
        return error.VideoProfileOperationNotSupported;
    }
    if (result == raw.VK_ERROR_VIDEO_PROFILE_FORMAT_NOT_SUPPORTED_KHR) {
        return error.VideoProfileFormatNotSupported;
    }
    if (result == raw.VK_ERROR_VIDEO_PROFILE_CODEC_NOT_SUPPORTED_KHR) {
        return error.VideoProfileCodecNotSupported;
    }
    if (result == raw.VK_ERROR_VIDEO_STD_VERSION_NOT_SUPPORTED_KHR) {
        return error.VideoStdVersionNotSupported;
    }
    if (result == raw.VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT) {
        return error.InvalidDrmFormatModifierPlaneLayout;
    }
    if (result == raw.VK_ERROR_PRESENT_TIMING_QUEUE_FULL_EXT) return error.PresentTimingQueueFull;
    if (result == raw.VK_ERROR_INVALID_VIDEO_STD_PARAMETERS_KHR) {
        return error.InvalidVideoStdParameters;
    }
    if (result == raw.VK_ERROR_COMPRESSION_EXHAUSTED_EXT) return error.CompressionExhausted;
    if (result == raw.VK_ERROR_NOT_ENOUGH_SPACE_KHR) return error.NotEnoughSpace;
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
