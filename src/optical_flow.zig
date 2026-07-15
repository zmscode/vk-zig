//! Typed `VK_NV_optical_flow` support.
//!
//! Session mutation, image binding, and execution are externally synchronized. Bound image
//! views and their memory must remain alive until every submitted execution completes.

const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const image = @import("image.zig");
const debug_utils = @import("debug_utils.zig");
const commands = @import("command_buffer.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const SessionHandle = core.NonNullHandle(raw.VkOpticalFlowSessionNV);

pub const required_extension = command.extension.nv_optical_flow;
pub const format_count_max = 64;
pub const region_count_max = 256;

pub const PerformanceLevel = enum {
    slow,
    medium,
    fast,

    fn toRaw(level: PerformanceLevel) raw.VkOpticalFlowPerformanceLevelNV {
        return switch (level) {
            .slow => raw.VK_OPTICAL_FLOW_PERFORMANCE_LEVEL_SLOW_NV,
            .medium => raw.VK_OPTICAL_FLOW_PERFORMANCE_LEVEL_MEDIUM_NV,
            .fast => raw.VK_OPTICAL_FLOW_PERFORMANCE_LEVEL_FAST_NV,
        };
    }
};

pub const GridSize = enum {
    one_by_one,
    two_by_two,
    four_by_four,
    eight_by_eight,

    fn toRaw(size: GridSize) raw.VkOpticalFlowGridSizeFlagsNV {
        return switch (size) {
            .one_by_one => raw.VK_OPTICAL_FLOW_GRID_SIZE_1X1_BIT_NV,
            .two_by_two => raw.VK_OPTICAL_FLOW_GRID_SIZE_2X2_BIT_NV,
            .four_by_four => raw.VK_OPTICAL_FLOW_GRID_SIZE_4X4_BIT_NV,
            .eight_by_eight => raw.VK_OPTICAL_FLOW_GRID_SIZE_8X8_BIT_NV,
        };
    }
};

pub const Usage = enum(u32) {
    input = raw.VK_OPTICAL_FLOW_USAGE_INPUT_BIT_NV,
    output = raw.VK_OPTICAL_FLOW_USAGE_OUTPUT_BIT_NV,
    hint = raw.VK_OPTICAL_FLOW_USAGE_HINT_BIT_NV,
    cost = raw.VK_OPTICAL_FLOW_USAGE_COST_BIT_NV,
    global_flow = raw.VK_OPTICAL_FLOW_USAGE_GLOBAL_FLOW_BIT_NV,
};

pub const UsageFlags = struct {
    bits: u32 = 0,

    pub const empty: UsageFlags = .{};

    pub fn init(values: []const Usage) UsageFlags {
        var flags: UsageFlags = .empty;
        for (values) |value| flags.bits |= @intFromEnum(value);
        return flags;
    }
};

pub const BindingPoint = enum {
    input,
    reference,
    hint,
    flow_vector,
    backward_flow_vector,
    cost,
    backward_cost,
    global_flow,

    fn toRaw(point: BindingPoint) raw.VkOpticalFlowSessionBindingPointNV {
        return switch (point) {
            .input => raw.VK_OPTICAL_FLOW_SESSION_BINDING_POINT_INPUT_NV,
            .reference => raw.VK_OPTICAL_FLOW_SESSION_BINDING_POINT_REFERENCE_NV,
            .hint => raw.VK_OPTICAL_FLOW_SESSION_BINDING_POINT_HINT_NV,
            .flow_vector => raw.VK_OPTICAL_FLOW_SESSION_BINDING_POINT_FLOW_VECTOR_NV,
            .backward_flow_vector => raw.VK_OPTICAL_FLOW_SESSION_BINDING_POINT_BACKWARD_FLOW_VECTOR_NV,
            .cost => raw.VK_OPTICAL_FLOW_SESSION_BINDING_POINT_COST_NV,
            .backward_cost => raw.VK_OPTICAL_FLOW_SESSION_BINDING_POINT_BACKWARD_COST_NV,
            .global_flow => raw.VK_OPTICAL_FLOW_SESSION_BINDING_POINT_GLOBAL_FLOW_NV,
        };
    }
};

pub const Format = struct {
    value: types.Format,
};

pub const SessionOptions = struct {
    width: u32,
    height: u32,
    image_format: types.Format,
    flow_vector_format: types.Format,
    cost_format: types.Format = .undefined_,
    output_grid_size: GridSize,
    hint_grid_size: ?GridSize = null,
    performance: PerformanceLevel = .medium,
    enable_hint: bool = false,
    enable_cost: bool = false,
    enable_global_flow: bool = false,
    allow_regions: bool = false,
    both_directions: bool = false,
};

pub const ExecuteOptions = struct {
    disable_temporal_hints: bool = false,
    regions: []const types.Rect2D = &.{},
};

pub const Dispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateOpticalFlowSessionNV),
    destroy: CommandFunction(raw.PFN_vkDestroyOpticalFlowSessionNV),
    bind_image: CommandFunction(raw.PFN_vkBindOpticalFlowSessionImageNV),
    execute: CommandFunction(raw.PFN_vkCmdOpticalFlowExecuteNV),
};

pub const Session = struct {
    _handle: ?SessionHandle,
    _device_handle: DeviceHandle,
    _device_state: *core.DeviceState,
    _owner: core.Owner,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,

    pub const synchronization_contract: core.Contract = .{
        .host_access = .externally_synchronized,
        .gpu_lifetime = .until_submission_completes,
    };

    pub fn close(session: *Session) core.Error!void {
        if (!try session._owner.release(session)) return;
        const handle = session._handle orelse return;
        session.dispatch.destroy(
            session._device_handle,
            handle,
            session.allocation_callbacks,
        );
        session._handle = null;
    }

    pub fn deinit(session: *Session) void {
        session.close() catch |err| {
            std.debug.panic("invalid optical-flow session ownership: {t}", .{err});
        };
    }

    pub fn moveTo(session: *Session, destination: *Session) core.Error!void {
        try session._owner.validate(session);
        destination.* = session.*;
        try destination._owner.rebind(session, destination);
        session._handle = null;
        session._owner.active = false;
    }

    pub fn rawHandle(session: *const Session) core.Error!raw.VkOpticalFlowSessionNV {
        try session._owner.validate(session);
        try session._device_state.ensureDispatchAllowed();
        return session._handle orelse error.InactiveObject;
    }

    pub fn debugObject(session: *const Session) core.Error!debug_utils.Object {
        return .forDevice(.optical_flow_session, try session.rawHandle(), session._device_handle);
    }

    pub fn bindImage(
        session: *const Session,
        point: BindingPoint,
        view: *const image.View,
        layout: types.ImageLayout,
    ) core.Error!void {
        try session._device_state.ensureDispatchAllowed();
        if (view._device_handle != session._device_handle) return error.InvalidHandle;
        const result = session.dispatch.bind_image(
            session._device_handle,
            try session.rawHandle(),
            point.toRaw(),
            try view.rawHandle(),
            layout.toRaw(),
        );
        try core.checkSuccessTracked(session._device_state, result);
    }

    pub fn execute(
        session: *const Session,
        command_buffer: *commands.Buffer,
        options: ExecuteOptions,
    ) core.Error!void {
        try session._device_state.ensureDispatchAllowed();
        if (command_buffer._device_handle != session._device_handle) return error.InvalidHandle;
        if (options.regions.len > region_count_max) return error.CountOverflow;
        var raw_regions: [region_count_max]raw.VkRect2D = undefined;
        for (options.regions, raw_regions[0..options.regions.len]) |region, *output| {
            output.* = region.toRaw();
        }
        const info: raw.VkOpticalFlowExecuteInfoNV = .{
            .sType = raw.VK_STRUCTURE_TYPE_OPTICAL_FLOW_EXECUTE_INFO_NV,
            .flags = if (options.disable_temporal_hints)
                raw.VK_OPTICAL_FLOW_EXECUTE_DISABLE_TEMPORAL_HINTS_BIT_NV
            else
                0,
            .regionCount = @intCast(options.regions.len),
            .pRegions = if (options.regions.len == 0)
                null
            else
                raw_regions[0..options.regions.len].ptr,
        };
        session.dispatch.execute(try command_buffer.rawHandle(), try session.rawHandle(), &info);
    }
};

pub fn create(
    output: *Session,
    device_handle: DeviceHandle,
    device_state: *core.DeviceState,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,
    options: SessionOptions,
) core.Error!void {
    try device_state.ensureDispatchAllowed();
    if (options.width == 0 or options.height == 0) return error.InvalidOptions;
    if (options.enable_hint != (options.hint_grid_size != null)) return error.InvalidOptions;
    var flags: raw.VkOpticalFlowSessionCreateFlagsNV = 0;
    if (options.enable_hint) flags |= raw.VK_OPTICAL_FLOW_SESSION_CREATE_ENABLE_HINT_BIT_NV;
    if (options.enable_cost) flags |= raw.VK_OPTICAL_FLOW_SESSION_CREATE_ENABLE_COST_BIT_NV;
    if (options.enable_global_flow) {
        flags |= raw.VK_OPTICAL_FLOW_SESSION_CREATE_ENABLE_GLOBAL_FLOW_BIT_NV;
    }
    if (options.allow_regions) flags |= raw.VK_OPTICAL_FLOW_SESSION_CREATE_ALLOW_REGIONS_BIT_NV;
    if (options.both_directions) {
        flags |= raw.VK_OPTICAL_FLOW_SESSION_CREATE_BOTH_DIRECTIONS_BIT_NV;
    }
    const info: raw.VkOpticalFlowSessionCreateInfoNV = .{
        .sType = raw.VK_STRUCTURE_TYPE_OPTICAL_FLOW_SESSION_CREATE_INFO_NV,
        .width = options.width,
        .height = options.height,
        .imageFormat = options.image_format.toRaw(),
        .flowVectorFormat = options.flow_vector_format.toRaw(),
        .costFormat = options.cost_format.toRaw(),
        .outputGridSize = options.output_grid_size.toRaw(),
        .hintGridSize = if (options.hint_grid_size) |size| size.toRaw() else 0,
        .performanceLevel = options.performance.toRaw(),
        .flags = flags,
    };
    var handle: raw.VkOpticalFlowSessionNV = null;
    const result = dispatch.create(device_handle, &info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccessTracked(device_state, result);
        unreachable;
    }
    output.* = .{
        ._handle = handle orelse return error.InvalidHandle,
        ._device_handle = device_handle,
        ._device_state = device_state,
        ._owner = undefined,
        .allocation_callbacks = allocation_callbacks,
        .dispatch = dispatch,
    };
    output._owner = try .init(output);
}

pub fn formatsInto(
    physical_device: raw.VkPhysicalDevice,
    get_formats: CommandFunction(raw.PFN_vkGetPhysicalDeviceOpticalFlowImageFormatsNV),
    usage: UsageFlags,
    storage: []Format,
) core.Error![]Format {
    if (storage.len > format_count_max) return error.CountOverflow;
    const info: raw.VkOpticalFlowImageFormatInfoNV = .{
        .sType = raw.VK_STRUCTURE_TYPE_OPTICAL_FLOW_IMAGE_FORMAT_INFO_NV,
        .usage = usage.bits,
    };
    var raw_formats: [format_count_max]raw.VkOpticalFlowImageFormatPropertiesNV = undefined;
    for (raw_formats[0..storage.len]) |*item| {
        item.* = .{ .sType = raw.VK_STRUCTURE_TYPE_OPTICAL_FLOW_IMAGE_FORMAT_PROPERTIES_NV };
    }
    var count: u32 = @intCast(storage.len);
    const result = get_formats(
        physical_device,
        &info,
        &count,
        if (storage.len == 0) null else raw_formats[0..storage.len].ptr,
    );
    if (result == raw.VK_INCOMPLETE or count > storage.len) return error.BufferTooSmall;
    try core.checkSuccess(result);
    for (storage[0..count], raw_formats[0..count]) |*item, raw_item| {
        item.* = .{ .value = .fromRaw(raw_item.format) };
    }
    return storage[0..count];
}

pub fn formatCount(
    physical_device: raw.VkPhysicalDevice,
    get_formats: CommandFunction(raw.PFN_vkGetPhysicalDeviceOpticalFlowImageFormatsNV),
    usage: UsageFlags,
) core.Error!u32 {
    const info: raw.VkOpticalFlowImageFormatInfoNV = .{
        .sType = raw.VK_STRUCTURE_TYPE_OPTICAL_FLOW_IMAGE_FORMAT_INFO_NV,
        .usage = usage.bits,
    };
    var count: u32 = 0;
    const result = get_formats(physical_device, &info, &count, null);
    if (result != raw.VK_SUCCESS and result != raw.VK_INCOMPLETE) try core.checkSuccess(result);
    if (count > format_count_max) return error.CountOverflow;
    return count;
}

pub fn formats(
    gpa: std.mem.Allocator,
    physical_device: raw.VkPhysicalDevice,
    get_formats: CommandFunction(raw.PFN_vkGetPhysicalDeviceOpticalFlowImageFormatsNV),
    usage: UsageFlags,
) (core.Error || std.mem.Allocator.Error)![]Format {
    var output = try gpa.alloc(Format, try formatCount(physical_device, get_formats, usage));
    errdefer gpa.free(output);
    for (0..4) |_| {
        const written = formatsInto(physical_device, get_formats, usage, output) catch |err| switch (err) {
            error.BufferTooSmall => {
                const required = try formatCount(physical_device, get_formats, usage);
                const next = if (required > output.len) required else @min(output.len * 2, format_count_max);
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

test "all optical-flow declarations compile" {
    std.testing.refAllDecls(@This());
}
