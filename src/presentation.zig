const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const sync = @import("synchronization.zig");
const image = @import("image.zig");
const debug_utils = @import("debug_utils.zig");
const device_group = @import("device_group.zig");

const CommandFunction = command.FunctionType;
const InstanceHandle = core.NonNullHandle(raw.VkInstance);
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const SurfaceHandle = core.NonNullHandle(raw.VkSurfaceKHR);
const SwapchainHandle = core.NonNullHandle(raw.VkSwapchainKHR);
pub const image_count_max = 4096;
const enumeration_attempt_count_max = 4;
const queue_family_count_max = 64;

pub const MetalSurfaceOptions = struct {
    layer: *const anyopaque,
};

pub const Win32SurfaceOptions = struct {
    instance: *anyopaque,
    window: *anyopaque,
};

pub const XlibSurfaceOptions = struct {
    display: *anyopaque,
    window: c_ulong,
};

pub const XcbSurfaceOptions = struct {
    connection: *anyopaque,
    window: u32,
};

pub const WaylandSurfaceOptions = struct {
    display: *anyopaque,
    surface: *anyopaque,
};

pub const AndroidSurfaceOptions = struct {
    window: *anyopaque,
};

pub const HeadlessSurfaceOptions = struct {};

pub const Surface = struct {
    _handle: ?SurfaceHandle,
    _owner: core.Owner,
    _instance_handle: InstanceHandle,
    _instance_borrow: ?core.Generation.Borrow = null,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_surface: CommandFunction(raw.PFN_vkDestroySurfaceKHR),

    pub fn deinit(surface: *Surface) void {
        if (!(surface._owner.release(surface) catch return)) return;
        const handle = surface._handle orelse return;
        if (surface._instance_borrow) |borrow| {
            borrow.validate() catch {
                surface._handle = null;
                return;
            };
        }
        surface.destroy_surface(
            surface._instance_handle,
            handle,
            surface.allocation_callbacks,
        );
        surface._handle = null;
    }

    pub fn rawHandle(surface: *const Surface) core.Error!raw.VkSurfaceKHR {
        try surface._owner.validate(surface);
        if (surface._instance_borrow) |borrow| try borrow.validate();
        return surface._handle orelse error.InactiveObject;
    }

    pub fn debugObject(surface: *const Surface) core.Error!debug_utils.Object {
        return .forInstance(.surface, try surface.rawHandle(), surface._instance_handle);
    }
};

pub const Options = struct {
    surface: *const Surface,
    min_image_count: u32,
    image_format: types.Format,
    image_color_space: types.ColorSpace,
    image_extent: types.Extent2D,
    image_usage: types.ImageUsageFlags,
    image_array_layers: u32 = 1,
    queue_family_indices: []const core.QueueFamilyIndex = &.{},
    pre_transform: types.SurfaceTransformBit = .identity,
    composite_alpha: types.CompositeAlphaBit = .opaque_,
    present_mode: types.PresentMode = .fifo,
    clipped: bool = true,
    old_swapchain: ?*const Swapchain = null,
    flags: types.SwapchainCreateFlags = .empty,
    device_group_modes: ?device_group.PresentModes = null,
    /// Additional compatible modes enabled by swapchain-maintenance1.
    compatible_present_modes: []const types.PresentMode = &.{},
    /// Enables VK_NV_low_latency2 mode at swapchain creation.
    low_latency_mode: bool = false,
    /// Win32-only full-screen-exclusive creation policy.
    full_screen_exclusive: ?FullScreenExclusive = null,
    /// Optional native monitor for application-controlled full-screen mode.
    full_screen_monitor: ?*anyopaque = null,

    pub fn validate(
        options: Options,
        device_handle: DeviceHandle,
        instance_handle: InstanceHandle,
    ) core.Error!void {
        if (options.surface._instance_handle != instance_handle) return error.InvalidHandle;
        _ = try options.surface.rawHandle();
        if (options.min_image_count == 0 or options.image_array_layers == 0) {
            return error.InvalidOptions;
        }
        if (options.image_extent.width == 0 or options.image_extent.height == 0) {
            return error.InvalidOptions;
        }
        _ = try core.count32(options.queue_family_indices.len);
        if (options.queue_family_indices.len > queue_family_count_max) return error.CountOverflow;
        for (options.queue_family_indices, 0..) |family_index, index| {
            for (options.queue_family_indices[0..index]) |previous_index| {
                if (family_index == previous_index) return error.InvalidOptions;
            }
        }
        if (options.old_swapchain) |old| {
            if (old._device_handle != device_handle) return error.InvalidHandle;
            _ = try old.rawHandle();
        }
        if (options.compatible_present_modes.len > 16) return error.CountOverflow;
        if (options.full_screen_monitor != null and options.full_screen_exclusive == null) {
            return error.InvalidOptions;
        }
    }
};

pub const FullScreenExclusive = enum {
    default,
    allowed,
    disallowed,
    application_controlled,
};

/// Immutable properties retained from successful swapchain creation.
pub const Metadata = struct {
    extent: types.Extent2D,
    format: types.Format,
    color_space: types.ColorSpace,
    min_image_count: u32,
    image_count: u32,
    image_array_layers: u32,
    usage: types.ImageUsageFlags,
    sharing_mode: types.SharingMode,
    queue_family_count: u32,
    present_mode: types.PresentMode,
};

/// Common options for creating one 2D color view per swapchain image.
pub const ImageViewOptions = struct {
    components: types.ComponentMapping = .{},
    aspect: types.ImageAspectFlags = .init(&.{.color}),
};

pub const AcquireOptions = struct {
    timeout: core.Timeout = .infinite,
    semaphore: ?*const sync.Semaphore = null,
    fence: ?*const sync.Fence = null,
};

pub const AcquireResult = union(enum) {
    success: core.SwapchainImageIndex,
    suboptimal: core.SwapchainImageIndex,
    timeout,
    not_ready,
    out_of_date,
};

pub const PresentOptions = struct {
    swapchain: *const Swapchain,
    image_index: core.SwapchainImageIndex,
    wait_semaphores: []const *const sync.Semaphore = &.{},
    device_mask: ?device_group.Mask = null,
    device_group_mode: ?device_group.PresentMode = null,
    /// Monotonically increasing KHR_present_id value.
    present_id: ?u64 = null,
    /// KHR_present_id2 value; mutually exclusive with `present_id`.
    present_id2: ?u64 = null,
    /// GOOGLE_display_timing desired presentation request.
    google_timing: ?GooglePresentTime = null,
    /// Damaged regions for KHR_incremental_present.
    damaged_regions: []const PresentRegion = &.{},
    /// Fence signaled when this presentation is retired (maintenance1).
    present_fence: ?*const sync.Fence = null,
    /// Optional per-present mode selected from swapchain-compatible modes.
    present_mode: ?types.PresentMode = null,
    /// NV_low_latency2 presentation identifier.
    latency_present_id: ?u64 = null,
};

pub const GooglePresentTime = struct {
    id: u32,
    desired_time_ns: u64,
};

pub const PresentRegion = struct {
    rectangle: types.Rect2D,
    layer: u32 = 0,
};

pub const PresentStatus = enum {
    success,
    suboptimal,
    out_of_date,
    full_screen_exclusive_lost,
};

pub const Swapchain = struct {
    _handle: ?SwapchainHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?*core.DeviceState = null,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_swapchain: CommandFunction(raw.PFN_vkDestroySwapchainKHR),
    get_swapchain_images: CommandFunction(raw.PFN_vkGetSwapchainImagesKHR),
    acquire_next_image: CommandFunction(raw.PFN_vkAcquireNextImageKHR),
    create_image_view: CommandFunction(raw.PFN_vkCreateImageView),
    destroy_image_view: CommandFunction(raw.PFN_vkDestroyImageView),
    metadata_value: Metadata,
    _image_generation: core.Generation = .{},

    pub fn deinit(swapchain: *Swapchain) void {
        if (!(swapchain._owner.release(swapchain) catch return)) return;
        const handle = swapchain._handle orelse return;
        swapchain.destroy_swapchain(
            swapchain._device_handle,
            handle,
            swapchain.allocation_callbacks,
        );
        swapchain._handle = null;
        swapchain._image_generation.invalidate();
    }

    pub fn rawHandle(swapchain: *const Swapchain) core.Error!raw.VkSwapchainKHR {
        try swapchain._owner.validate(swapchain);
        if (swapchain._device_state) |state| try state.ensureDispatchAllowed();
        return swapchain._handle orelse error.InactiveObject;
    }

    pub fn debugObject(swapchain: *const Swapchain) core.Error!debug_utils.Object {
        return .forDevice(.swapchain, try swapchain.rawHandle(), swapchain._device_handle);
    }

    pub fn metadata(swapchain: *const Swapchain) core.Error!Metadata {
        _ = try swapchain.rawHandle();
        return swapchain.metadata_value;
    }

    pub fn imageCount(swapchain: *const Swapchain) core.Error!u32 {
        try swapchain.ensureDispatchAllowed();
        const handle = try swapchain.rawHandle();
        var count: u32 = 0;
        try swapchain.checkResult(swapchain.get_swapchain_images(
            swapchain._device_handle,
            handle,
            &count,
            null,
        ));
        if (count > image_count_max) return error.TooManyObjects;
        return count;
    }

    pub fn images(
        swapchain: *const Swapchain,
        gpa: std.mem.Allocator,
    ) (core.Error || std.mem.Allocator.Error)![]image.SwapchainImage {
        var output = try gpa.alloc(image.SwapchainImage, try swapchain.imageCount());
        errdefer gpa.free(output);
        for (0..enumeration_attempt_count_max) |_| {
            const written = swapchain.imagesInto(output) catch |err| switch (err) {
                error.BufferTooSmall => {
                    const required = try swapchain.imageCount();
                    const next = if (required > output.len)
                        required
                    else
                        @min(output.len * 2, image_count_max);
                    if (next <= output.len) return error.EnumerationUnstable;
                    output = try gpa.realloc(output, next);
                    continue;
                },
                else => |other| return other,
            };
            return gpa.realloc(output, written.len);
        }
        return error.EnumerationUnstable;
    }

    pub fn imagesInto(
        swapchain: *const Swapchain,
        storage: []image.SwapchainImage,
    ) core.Error![]image.SwapchainImage {
        try swapchain.ensureDispatchAllowed();
        if (storage.len > image_count_max) return error.CountOverflow;
        const live_handle = (try swapchain.rawHandle()) orelse return error.InvalidHandle;
        var raw_images: [image_count_max]raw.VkImage = undefined;
        var written: u32 = @intCast(storage.len);
        const output: [*c]raw.VkImage = if (storage.len == 0) null else &raw_images;
        const result = swapchain.get_swapchain_images(
            swapchain._device_handle,
            live_handle,
            &written,
            output,
        );
        if (result == raw.VK_INCOMPLETE) return error.BufferTooSmall;
        try swapchain.checkResult(result);
        if (written > storage.len) return error.BufferTooSmall;
        for (storage[0..written], raw_images[0..written], 0..) |*swapchain_image, raw_image, index| {
            swapchain_image.* = .{
                ._handle = raw_image orelse return error.InvalidHandle,
                ._device_handle = swapchain._device_handle,
                ._swapchain_handle = live_handle,
                ._swapchain_borrow = swapchain._image_generation.borrowOwner(&swapchain._owner),
                .index = .fromRaw(@intCast(index)),
            };
        }
        return storage[0..written];
    }

    /// Creates one view for every current swapchain image. On failure all views created by this
    /// call are destroyed before returning.
    pub fn createImageViews(
        swapchain: *const Swapchain,
        gpa: std.mem.Allocator,
        options: ImageViewOptions,
    ) (core.Error || std.mem.Allocator.Error)![]image.View {
        const swapchain_images = try swapchain.images(gpa);
        defer gpa.free(swapchain_images);

        const views = try gpa.alloc(image.View, swapchain_images.len);
        errdefer gpa.free(views);
        var initialized: usize = 0;
        errdefer for (views[0..initialized]) |*view| view.deinit();

        for (swapchain_images, views) |*swapchain_image, *view| {
            view.* = image.createView(
                swapchain._device_handle,
                swapchain.allocation_callbacks,
                swapchain.create_image_view,
                swapchain.destroy_image_view,
                .{
                    .image = .{ .swapchain = swapchain_image },
                    .format = swapchain.metadata_value.format,
                    .components = options.components,
                    .subresource_range = .{
                        .aspect_mask = options.aspect,
                        .base_mip_level = 0,
                        .level_count = .{ .count = 1 },
                        .base_array_layer = 0,
                        .layer_count = .{ .count = swapchain.metadata_value.image_array_layers },
                    },
                },
            ) catch |err| {
                if (err == error.DeviceLost) swapchain.markLost();
                return err;
            };
            initialized += 1;
        }
        return views;
    }

    pub fn acquireNextImage(
        swapchain: *const Swapchain,
        options: AcquireOptions,
    ) core.Error!AcquireResult {
        try swapchain.ensureDispatchAllowed();
        if (options.semaphore == null and options.fence == null) return error.InvalidOptions;
        const semaphore = if (options.semaphore) |semaphore| blk: {
            if (semaphore._device_handle != swapchain._device_handle) return error.InvalidHandle;
            if (semaphore.kind != .binary) return error.InvalidOptions;
            break :blk try semaphore.rawHandle();
        } else null;
        const fence = if (options.fence) |fence| blk: {
            if (fence._device_handle != swapchain._device_handle) return error.InvalidHandle;
            break :blk try fence.rawHandle();
        } else null;
        var image_index: u32 = 0;
        const result = swapchain.acquire_next_image(
            swapchain._device_handle,
            try swapchain.rawHandle(),
            options.timeout.toRaw(),
            semaphore,
            fence,
            &image_index,
        );
        if (result == raw.VK_SUCCESS) return .{ .success = .fromRaw(image_index) };
        if (result == raw.VK_SUBOPTIMAL_KHR) return .{ .suboptimal = .fromRaw(image_index) };
        if (result == raw.VK_TIMEOUT) return .timeout;
        if (result == raw.VK_NOT_READY) return .not_ready;
        if (result == raw.VK_ERROR_OUT_OF_DATE_KHR) return .out_of_date;
        try swapchain.checkResult(result);
        unreachable;
    }

    fn ensureDispatchAllowed(swapchain: *const Swapchain) core.Error!void {
        if (swapchain._device_state) |state| try state.ensureDispatchAllowed();
    }

    fn checkResult(swapchain: *const Swapchain, result: raw.VkResult) core.Error!void {
        if (swapchain._device_state) |state| return core.checkSuccessTracked(state, result);
        return core.checkSuccess(result);
    }

    fn markLost(swapchain: *const Swapchain) void {
        if (swapchain._device_state) |state| state.markLost();
    }
};
