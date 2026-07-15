const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const presentation = @import("presentation.zig");

const CommandFunction = command.FunctionType;
const InstanceHandle = core.NonNullHandle(raw.VkInstance);
const PhysicalDeviceHandle = core.NonNullHandle(raw.VkPhysicalDevice);
const DisplayHandle = core.NonNullHandle(raw.VkDisplayKHR);
const ModeHandle = core.NonNullHandle(raw.VkDisplayModeKHR);
pub const property_count_max = 64;
const enumeration_attempt_count_max = 4;

pub const Display = struct {
    _handle: DisplayHandle,
};

pub const Mode = struct {
    _handle: ModeHandle,
    display: Display,
};

pub const Properties = struct {
    display: Display,
    name: ?[:0]const u8,
    physical_dimensions_mm: types.Extent2D,
    resolution: types.Extent2D,
    supported_transforms: types.SurfaceTransformFlags,
    plane_reorder_possible: bool,
    persistent_content: bool,

    fn fromRaw(value: raw.VkDisplayPropertiesKHR) core.Error!Properties {
        return .{
            .display = .{ ._handle = value.display orelse return error.InvalidHandle },
            .name = if (value.displayName == null) null else @as([*:0]const u8, @ptrCast(value.displayName))[0..std.mem.len(@as([*:0]const u8, @ptrCast(value.displayName))) :0],
            .physical_dimensions_mm = .fromRaw(value.physicalDimensions),
            .resolution = .fromRaw(value.physicalResolution),
            .supported_transforms = .fromRaw(value.supportedTransforms),
            .plane_reorder_possible = value.planeReorderPossible != raw.VK_FALSE,
            .persistent_content = value.persistentContent != raw.VK_FALSE,
        };
    }
};

pub const PlaneProperties = struct {
    current_display: ?Display,
    current_stack_index: u32,
};

pub const ModeParameters = struct {
    visible_region: types.Extent2D,
    /// Refresh rate in millihertz, matching Vulkan's display API.
    refresh_rate_millihz: u32,
};

pub const ModeProperties = struct {
    mode: Mode,
    parameters: ModeParameters,
};

pub const AlphaMode = enum(raw.VkDisplayPlaneAlphaFlagsKHR) {
    opaque_ = raw.VK_DISPLAY_PLANE_ALPHA_OPAQUE_BIT_KHR,
    global = raw.VK_DISPLAY_PLANE_ALPHA_GLOBAL_BIT_KHR,
    per_pixel = raw.VK_DISPLAY_PLANE_ALPHA_PER_PIXEL_BIT_KHR,
    per_pixel_premultiplied = raw.VK_DISPLAY_PLANE_ALPHA_PER_PIXEL_PREMULTIPLIED_BIT_KHR,
    _,
};

pub const AlphaModes = types.Flags(raw.VkDisplayPlaneAlphaFlagsKHR, AlphaMode);

pub const PlaneCapabilities = struct {
    supported_alpha: AlphaModes,
    source_position_min: types.Offset2D,
    source_position_max: types.Offset2D,
    source_extent_min: types.Extent2D,
    source_extent_max: types.Extent2D,
    destination_position_min: types.Offset2D,
    destination_position_max: types.Offset2D,
    destination_extent_min: types.Extent2D,
    destination_extent_max: types.Extent2D,
};

pub const SurfaceOptions = struct {
    mode: Mode,
    plane_index: u32,
    plane_stack_index: u32,
    transform: types.SurfaceTransformBit = .identity,
    global_alpha: f32 = 1,
    alpha_mode: AlphaMode = .opaque_,
    image_extent: types.Extent2D,
};

pub const Context = struct {
    _instance: InstanceHandle,
    _physical_device: PhysicalDeviceHandle,
    _instance_borrow: ?core.Generation.Borrow,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _get_properties: ?CommandFunction(raw.PFN_vkGetPhysicalDeviceDisplayPropertiesKHR),
    _get_plane_properties: ?CommandFunction(raw.PFN_vkGetPhysicalDeviceDisplayPlanePropertiesKHR),
    _get_supported_displays: ?CommandFunction(raw.PFN_vkGetDisplayPlaneSupportedDisplaysKHR),
    _get_modes: ?CommandFunction(raw.PFN_vkGetDisplayModePropertiesKHR),
    _create_mode: ?CommandFunction(raw.PFN_vkCreateDisplayModeKHR),
    _get_plane_capabilities: ?CommandFunction(raw.PFN_vkGetDisplayPlaneCapabilitiesKHR),
    _create_surface: ?CommandFunction(raw.PFN_vkCreateDisplayPlaneSurfaceKHR),
    _destroy_surface: ?CommandFunction(raw.PFN_vkDestroySurfaceKHR),
    _release_display: ?CommandFunction(raw.PFN_vkReleaseDisplayEXT),
    _acquire_drm_display: ?CommandFunction(raw.PFN_vkAcquireDrmDisplayEXT),
    _get_drm_display: ?CommandFunction(raw.PFN_vkGetDrmDisplayEXT),

    pub fn propertyCount(context: Context) core.Error!u32 {
        const get = context._get_properties orelse return error.MissingCommand;
        var count: u32 = 0;
        try enumerationResult(get(context._physical_device, &count, null));
        if (count > property_count_max) return error.CountOverflow;
        return count;
    }

    pub fn propertiesInto(context: Context, storage: []Properties) core.Error![]Properties {
        if (storage.len > property_count_max) return error.CountOverflow;
        const get = context._get_properties orelse return error.MissingCommand;
        var raw_properties: [property_count_max]raw.VkDisplayPropertiesKHR = undefined;
        var count: u32 = @intCast(storage.len);
        const result = get(context._physical_device, &count, if (storage.len == 0) null else &raw_properties);
        if (result == raw.VK_INCOMPLETE or count > storage.len) return error.BufferTooSmall;
        try core.checkSuccess(result);
        for (storage[0..count], raw_properties[0..count]) |*property, raw_property| property.* = try .fromRaw(raw_property);
        return storage[0..count];
    }

    pub fn properties(
        context: Context,
        gpa: std.mem.Allocator,
    ) (core.Error || std.mem.Allocator.Error)![]Properties {
        var output = try gpa.alloc(Properties, try context.propertyCount());
        errdefer gpa.free(output);
        for (0..enumeration_attempt_count_max) |_| {
            const written = context.propertiesInto(output) catch |err| switch (err) {
                error.BufferTooSmall => {
                    const required = try context.propertyCount();
                    const next = if (required > output.len) required else @min(output.len * 2, property_count_max);
                    if (next <= output.len) return error.EnumerationUnstable;
                    output = try gpa.realloc(output, next);
                    continue;
                },
                else => return err,
            };
            return gpa.realloc(output, written.len);
        }
        return error.EnumerationUnstable;
    }

    pub fn planePropertyCount(context: Context) core.Error!u32 {
        const get = context._get_plane_properties orelse return error.MissingCommand;
        var count: u32 = 0;
        try enumerationResult(get(context._physical_device, &count, null));
        if (count > property_count_max) return error.CountOverflow;
        return count;
    }

    pub fn planePropertiesInto(context: Context, storage: []PlaneProperties) core.Error![]PlaneProperties {
        if (storage.len > property_count_max) return error.CountOverflow;
        const get = context._get_plane_properties orelse return error.MissingCommand;
        var values: [property_count_max]raw.VkDisplayPlanePropertiesKHR = undefined;
        var count: u32 = @intCast(storage.len);
        const result = get(context._physical_device, &count, if (storage.len == 0) null else &values);
        if (result == raw.VK_INCOMPLETE or count > storage.len) return error.BufferTooSmall;
        try core.checkSuccess(result);
        for (storage[0..count], values[0..count]) |*output, value| output.* = .{
            .current_display = if (value.currentDisplay) |handle| .{ ._handle = handle } else null,
            .current_stack_index = value.currentStackIndex,
        };
        return storage[0..count];
    }

    pub fn planeProperties(
        context: Context,
        gpa: std.mem.Allocator,
    ) (core.Error || std.mem.Allocator.Error)![]PlaneProperties {
        var output = try gpa.alloc(PlaneProperties, try context.planePropertyCount());
        errdefer gpa.free(output);
        for (0..enumeration_attempt_count_max) |_| {
            const written = context.planePropertiesInto(output) catch |err| switch (err) {
                error.BufferTooSmall => {
                    const required = try context.planePropertyCount();
                    const next = if (required > output.len) required else @min(output.len * 2, property_count_max);
                    if (next <= output.len) return error.EnumerationUnstable;
                    output = try gpa.realloc(output, next);
                    continue;
                },
                else => return err,
            };
            return gpa.realloc(output, written.len);
        }
        return error.EnumerationUnstable;
    }

    pub fn supportedDisplayCount(context: Context, plane_index: u32) core.Error!u32 {
        const get = context._get_supported_displays orelse return error.MissingCommand;
        var count: u32 = 0;
        try enumerationResult(get(context._physical_device, plane_index, &count, null));
        if (count > property_count_max) return error.CountOverflow;
        return count;
    }

    pub fn supportedDisplaysInto(
        context: Context,
        plane_index: u32,
        storage: []Display,
    ) core.Error![]Display {
        if (storage.len > property_count_max) return error.CountOverflow;
        const get = context._get_supported_displays orelse return error.MissingCommand;
        var handles: [property_count_max]raw.VkDisplayKHR = undefined;
        var count: u32 = @intCast(storage.len);
        const result = get(context._physical_device, plane_index, &count, if (storage.len == 0) null else &handles);
        if (result == raw.VK_INCOMPLETE or count > storage.len) return error.BufferTooSmall;
        try core.checkSuccess(result);
        for (storage[0..count], handles[0..count]) |*output, handle| output.* = .{
            ._handle = handle orelse return error.InvalidHandle,
        };
        return storage[0..count];
    }

    pub fn supportedDisplays(
        context: Context,
        gpa: std.mem.Allocator,
        plane_index: u32,
    ) (core.Error || std.mem.Allocator.Error)![]Display {
        var output = try gpa.alloc(Display, try context.supportedDisplayCount(plane_index));
        errdefer gpa.free(output);
        for (0..enumeration_attempt_count_max) |_| {
            const written = context.supportedDisplaysInto(plane_index, output) catch |err| switch (err) {
                error.BufferTooSmall => {
                    const required = try context.supportedDisplayCount(plane_index);
                    const next = if (required > output.len) required else @min(output.len * 2, property_count_max);
                    if (next <= output.len) return error.EnumerationUnstable;
                    output = try gpa.realloc(output, next);
                    continue;
                },
                else => return err,
            };
            return gpa.realloc(output, written.len);
        }
        return error.EnumerationUnstable;
    }

    pub fn modePropertyCount(context: Context, display: Display) core.Error!u32 {
        const get = context._get_modes orelse return error.MissingCommand;
        var count: u32 = 0;
        try enumerationResult(get(context._physical_device, display._handle, &count, null));
        if (count > property_count_max) return error.CountOverflow;
        return count;
    }

    pub fn modePropertiesInto(
        context: Context,
        display: Display,
        storage: []ModeProperties,
    ) core.Error![]ModeProperties {
        if (storage.len > property_count_max) return error.CountOverflow;
        const get = context._get_modes orelse return error.MissingCommand;
        var values: [property_count_max]raw.VkDisplayModePropertiesKHR = undefined;
        var count: u32 = @intCast(storage.len);
        const result = get(context._physical_device, display._handle, &count, if (storage.len == 0) null else &values);
        if (result == raw.VK_INCOMPLETE or count > storage.len) return error.BufferTooSmall;
        try core.checkSuccess(result);
        for (storage[0..count], values[0..count]) |*output, value| output.* = .{
            .mode = .{ ._handle = value.displayMode orelse return error.InvalidHandle, .display = display },
            .parameters = .{
                .visible_region = .fromRaw(value.parameters.visibleRegion),
                .refresh_rate_millihz = value.parameters.refreshRate,
            },
        };
        return storage[0..count];
    }

    pub fn modeProperties(
        context: Context,
        gpa: std.mem.Allocator,
        display: Display,
    ) (core.Error || std.mem.Allocator.Error)![]ModeProperties {
        var output = try gpa.alloc(ModeProperties, try context.modePropertyCount(display));
        errdefer gpa.free(output);
        for (0..enumeration_attempt_count_max) |_| {
            const written = context.modePropertiesInto(display, output) catch |err| switch (err) {
                error.BufferTooSmall => {
                    const required = try context.modePropertyCount(display);
                    const next = if (required > output.len) required else @min(output.len * 2, property_count_max);
                    if (next <= output.len) return error.EnumerationUnstable;
                    output = try gpa.realloc(output, next);
                    continue;
                },
                else => return err,
            };
            return gpa.realloc(output, written.len);
        }
        return error.EnumerationUnstable;
    }

    pub fn createMode(context: Context, display: Display, parameters: ModeParameters) core.Error!Mode {
        if (parameters.visible_region.width == 0 or parameters.visible_region.height == 0 or parameters.refresh_rate_millihz == 0) {
            return error.InvalidOptions;
        }
        const create = context._create_mode orelse return error.MissingCommand;
        const info: raw.VkDisplayModeCreateInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_DISPLAY_MODE_CREATE_INFO_KHR,
            .parameters = .{
                .visibleRegion = parameters.visible_region.toRaw(),
                .refreshRate = parameters.refresh_rate_millihz,
            },
        };
        var handle: raw.VkDisplayModeKHR = null;
        try core.checkSuccess(create(context._physical_device, display._handle, &info, context._allocation_callbacks, &handle));
        return .{ ._handle = handle orelse return error.InvalidHandle, .display = display };
    }

    pub fn planeCapabilities(context: Context, mode: Mode, plane_index: u32) core.Error!PlaneCapabilities {
        const get = context._get_plane_capabilities orelse return error.MissingCommand;
        var value: raw.VkDisplayPlaneCapabilitiesKHR = .{};
        try core.checkSuccess(get(context._physical_device, mode._handle, plane_index, &value));
        return .{
            .supported_alpha = .fromRaw(value.supportedAlpha),
            .source_position_min = .fromRaw(value.minSrcPosition),
            .source_position_max = .fromRaw(value.maxSrcPosition),
            .source_extent_min = .fromRaw(value.minSrcExtent),
            .source_extent_max = .fromRaw(value.maxSrcExtent),
            .destination_position_min = .fromRaw(value.minDstPosition),
            .destination_position_max = .fromRaw(value.maxDstPosition),
            .destination_extent_min = .fromRaw(value.minDstExtent),
            .destination_extent_max = .fromRaw(value.maxDstExtent),
        };
    }

    pub fn createSurface(context: Context, options: SurfaceOptions) core.Error!presentation.Surface {
        if (options.image_extent.width == 0 or options.image_extent.height == 0 or
            !std.math.isFinite(options.global_alpha) or options.global_alpha < 0 or options.global_alpha > 1)
        {
            return error.InvalidOptions;
        }
        const create = context._create_surface orelse return error.MissingCommand;
        const destroy = context._destroy_surface orelse return error.MissingCommand;
        const info: raw.VkDisplaySurfaceCreateInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_DISPLAY_SURFACE_CREATE_INFO_KHR,
            .displayMode = options.mode._handle,
            .planeIndex = options.plane_index,
            .planeStackIndex = options.plane_stack_index,
            .transform = options.transform.toRaw(),
            .globalAlpha = options.global_alpha,
            .alphaMode = @intFromEnum(options.alpha_mode),
            .imageExtent = options.image_extent.toRaw(),
        };
        var handle: raw.VkSurfaceKHR = null;
        try core.checkSuccess(create(context._instance, &info, context._allocation_callbacks, &handle));
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._owner = try .init(&handle),
            ._instance_handle = context._instance,
            ._instance_borrow = context._instance_borrow,
            .allocation_callbacks = context._allocation_callbacks,
            .destroy_surface = destroy,
        };
    }

    pub fn release(context: Context, display: Display) core.Error!void {
        const release_fn = context._release_display orelse return error.MissingCommand;
        try core.checkSuccess(release_fn(context._physical_device, display._handle));
    }

    pub fn acquireDrm(context: Context, descriptor: i32, display: Display) core.Error!void {
        const acquire = context._acquire_drm_display orelse return error.MissingCommand;
        try core.checkSuccess(acquire(context._physical_device, descriptor, display._handle));
    }

    pub fn drmDisplay(context: Context, descriptor: i32, connector_id: u32) core.Error!Display {
        const get = context._get_drm_display orelse return error.MissingCommand;
        var handle: raw.VkDisplayKHR = null;
        try core.checkSuccess(get(context._physical_device, descriptor, connector_id, &handle));
        return .{ ._handle = handle orelse return error.InvalidHandle };
    }
};

fn enumerationResult(result: raw.VkResult) core.Error!void {
    if (result == raw.VK_SUCCESS or result == raw.VK_INCOMPLETE) return;
    try core.checkSuccess(result);
}

test "display alpha sets remain typed" {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(Context);
    const modes = AlphaModes.init(&.{ .opaque_, .global });
    try std.testing.expect(modes.contains(.global));
}
