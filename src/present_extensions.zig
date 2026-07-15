const std = @import("std");
const builtin = @import("builtin");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const display = @import("display.zig");
const presentation = @import("presentation.zig");
const queue = @import("queue.zig");
const sync = @import("synchronization.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
pub const timing_count_max = 256;

pub const WaitStatus = enum {
    complete,
    timeout,
    suboptimal,
    out_of_date,
    full_screen_exclusive_lost,
};

pub const FullScreenStatus = enum {
    success,
    out_of_date,
    full_screen_exclusive_lost,
};

pub const PowerState = enum(raw.VkDisplayPowerStateEXT) {
    off = raw.VK_DISPLAY_POWER_STATE_OFF_EXT,
    suspended = raw.VK_DISPLAY_POWER_STATE_SUSPEND_EXT,
    on = raw.VK_DISPLAY_POWER_STATE_ON_EXT,
    _,
};

pub const Chromaticity = struct { x: f32, y: f32 };

pub const HdrMetadata = struct {
    red: Chromaticity,
    green: Chromaticity,
    blue: Chromaticity,
    white: Chromaticity,
    max_luminance: f32,
    min_luminance: f32,
    max_content_light_level: f32,
    max_frame_average_light_level: f32,

    fn toRaw(value: HdrMetadata) raw.VkHdrMetadataEXT {
        return .{
            .sType = raw.VK_STRUCTURE_TYPE_HDR_METADATA_EXT,
            .displayPrimaryRed = .{ .x = value.red.x, .y = value.red.y },
            .displayPrimaryGreen = .{ .x = value.green.x, .y = value.green.y },
            .displayPrimaryBlue = .{ .x = value.blue.x, .y = value.blue.y },
            .whitePoint = .{ .x = value.white.x, .y = value.white.y },
            .maxLuminance = value.max_luminance,
            .minLuminance = value.min_luminance,
            .maxContentLightLevel = value.max_content_light_level,
            .maxFrameAverageLightLevel = value.max_frame_average_light_level,
        };
    }
};

pub const PastTiming = struct {
    id: u32,
    desired_time_ns: u64,
    actual_time_ns: u64,
    earliest_time_ns: u64,
    margin_ns: u64,
};

pub const SleepMode = struct {
    enabled: bool = true,
    boost: bool = false,
    minimum_interval_us: u32 = 0,
};

pub const LatencyMarker = enum(raw.VkLatencyMarkerNV) {
    simulation_start = raw.VK_LATENCY_MARKER_SIMULATION_START_NV,
    simulation_end = raw.VK_LATENCY_MARKER_SIMULATION_END_NV,
    render_submit_start = raw.VK_LATENCY_MARKER_RENDERSUBMIT_START_NV,
    render_submit_end = raw.VK_LATENCY_MARKER_RENDERSUBMIT_END_NV,
    present_start = raw.VK_LATENCY_MARKER_PRESENT_START_NV,
    present_end = raw.VK_LATENCY_MARKER_PRESENT_END_NV,
    input_sample = raw.VK_LATENCY_MARKER_INPUT_SAMPLE_NV,
    trigger_flash = raw.VK_LATENCY_MARKER_TRIGGER_FLASH_NV,
    out_of_band_render_submit_start = raw.VK_LATENCY_MARKER_OUT_OF_BAND_RENDERSUBMIT_START_NV,
    out_of_band_render_submit_end = raw.VK_LATENCY_MARKER_OUT_OF_BAND_RENDERSUBMIT_END_NV,
    out_of_band_present_start = raw.VK_LATENCY_MARKER_OUT_OF_BAND_PRESENT_START_NV,
    out_of_band_present_end = raw.VK_LATENCY_MARKER_OUT_OF_BAND_PRESENT_END_NV,
    _,
};

pub const LatencyTiming = struct {
    present_id: u64,
    input_sample_us: u64,
    simulation_start_us: u64,
    simulation_end_us: u64,
    render_submit_start_us: u64,
    render_submit_end_us: u64,
    present_start_us: u64,
    present_end_us: u64,
    driver_start_us: u64,
    driver_end_us: u64,
    os_render_queue_start_us: u64,
    os_render_queue_end_us: u64,
    gpu_render_start_us: u64,
    gpu_render_end_us: u64,
};

pub const QueueWork = enum(raw.VkOutOfBandQueueTypeNV) {
    render = raw.VK_OUT_OF_BAND_QUEUE_TYPE_RENDER_NV,
    present = raw.VK_OUT_OF_BAND_QUEUE_TYPE_PRESENT_NV,
    _,
};

pub const AntiLagMode = enum(raw.VkAntiLagModeAMD) {
    driver_control = raw.VK_ANTI_LAG_MODE_DRIVER_CONTROL_AMD,
    on = raw.VK_ANTI_LAG_MODE_ON_AMD,
    off = raw.VK_ANTI_LAG_MODE_OFF_AMD,
    _,
};

pub const AntiLagStage = enum(raw.VkAntiLagStageAMD) {
    input = raw.VK_ANTI_LAG_STAGE_INPUT_AMD,
    present = raw.VK_ANTI_LAG_STAGE_PRESENT_AMD,
    _,
};

pub const AntiLagOptions = struct {
    mode: AntiLagMode = .driver_control,
    max_fps: u32 = 0,
    stage: ?AntiLagStage = null,
    frame_index: u64 = 0,
};

pub const Context = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _get_device_proc_addr: CommandFunction(raw.PFN_vkGetDeviceProcAddr),
    _wait: ?CommandFunction(raw.PFN_vkWaitForPresentKHR),
    _wait2: ?CommandFunction(raw.PFN_vkWaitForPresent2KHR),
    _release_images: ?CommandFunction(raw.PFN_vkReleaseSwapchainImagesKHR),
    _set_hdr: ?CommandFunction(raw.PFN_vkSetHdrMetadataEXT),
    _refresh_cycle: ?CommandFunction(raw.PFN_vkGetRefreshCycleDurationGOOGLE),
    _past_timings: ?CommandFunction(raw.PFN_vkGetPastPresentationTimingGOOGLE),
    _display_power: ?CommandFunction(raw.PFN_vkDisplayPowerControlEXT),
    _register_device_event: ?CommandFunction(raw.PFN_vkRegisterDeviceEventEXT),
    _register_display_event: ?CommandFunction(raw.PFN_vkRegisterDisplayEventEXT),
    _swapchain_counter: ?CommandFunction(raw.PFN_vkGetSwapchainCounterEXT),
    _set_sleep_mode: ?CommandFunction(raw.PFN_vkSetLatencySleepModeNV),
    _latency_sleep: ?CommandFunction(raw.PFN_vkLatencySleepNV),
    _set_marker: ?CommandFunction(raw.PFN_vkSetLatencyMarkerNV),
    _get_latency_timings: ?CommandFunction(raw.PFN_vkGetLatencyTimingsNV),
    _notify_queue: ?CommandFunction(raw.PFN_vkQueueNotifyOutOfBandNV),
    _anti_lag: ?CommandFunction(raw.PFN_vkAntiLagUpdateAMD),
    _destroy_fence: CommandFunction(raw.PFN_vkDestroyFence),
    _get_fence_status: CommandFunction(raw.PFN_vkGetFenceStatus),
    _reset_fences: CommandFunction(raw.PFN_vkResetFences),
    _wait_for_fences: CommandFunction(raw.PFN_vkWaitForFences),

    fn swapchainHandle(context: Context, swapchain: *const presentation.Swapchain) core.Error!raw.VkSwapchainKHR {
        try context._state.ensureDispatchAllowed();
        if (swapchain._device_handle != context._device) return error.InvalidHandle;
        return try swapchain.rawHandle();
    }

    pub fn wait(context: Context, swapchain: *const presentation.Swapchain, id: u64, timeout: core.Timeout) core.Error!WaitStatus {
        const wait_fn = context._wait orelse return error.MissingCommand;
        return waitResult(context._state, wait_fn(context._device, try context.swapchainHandle(swapchain), id, timeout.toRaw()));
    }

    pub fn wait2(context: Context, swapchain: *const presentation.Swapchain, id: u64, timeout: core.Timeout) core.Error!WaitStatus {
        const wait_fn = context._wait2 orelse return error.MissingCommand;
        const info: raw.VkPresentWait2InfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_PRESENT_WAIT_2_INFO_KHR,
            .presentId = id,
            .timeout = timeout.toRaw(),
        };
        return waitResult(context._state, wait_fn(context._device, try context.swapchainHandle(swapchain), &info));
    }

    pub fn releaseImages(context: Context, swapchain: *const presentation.Swapchain, indices: []const core.SwapchainImageIndex) core.Error!void {
        if (indices.len == 0) return error.InvalidOptions;
        var raw_indices: [presentation.image_count_max]u32 = undefined;
        if (indices.len > raw_indices.len) return error.CountOverflow;
        for (indices, raw_indices[0..indices.len]) |index, *output| output.* = index.toRaw();
        const info: raw.VkReleaseSwapchainImagesInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_RELEASE_SWAPCHAIN_IMAGES_INFO_KHR,
            .swapchain = try context.swapchainHandle(swapchain),
            .imageIndexCount = @intCast(indices.len),
            .pImageIndices = raw_indices[0..indices.len].ptr,
        };
        const release = context._release_images orelse return error.MissingCommand;
        try core.checkSuccessTracked(@constCast(context._state), release(context._device, &info));
    }

    pub fn setHdrMetadata(context: Context, swapchain: *const presentation.Swapchain, metadata: HdrMetadata) core.Error!void {
        const set = context._set_hdr orelse return error.MissingCommand;
        const handle = try context.swapchainHandle(swapchain);
        const value = metadata.toRaw();
        set(context._device, 1, @ptrCast(&handle), &value);
    }

    pub fn refreshCycleDuration(context: Context, swapchain: *const presentation.Swapchain) core.Error!u64 {
        const get = context._refresh_cycle orelse return error.MissingCommand;
        var value: raw.VkRefreshCycleDurationGOOGLE = .{};
        try core.checkSuccessTracked(@constCast(context._state), get(context._device, try context.swapchainHandle(swapchain), &value));
        return value.refreshDuration;
    }

    pub fn pastTimingCount(context: Context, swapchain: *const presentation.Swapchain) core.Error!u32 {
        const get = context._past_timings orelse return error.MissingCommand;
        var count: u32 = 0;
        const result = get(context._device, try context.swapchainHandle(swapchain), &count, null);
        if (result != raw.VK_SUCCESS and result != raw.VK_INCOMPLETE) try core.checkSuccessTracked(@constCast(context._state), result);
        if (count > timing_count_max) return error.CountOverflow;
        return count;
    }

    pub fn pastTimingsInto(context: Context, swapchain: *const presentation.Swapchain, storage: []PastTiming) core.Error![]PastTiming {
        if (storage.len > timing_count_max) return error.CountOverflow;
        const get = context._past_timings orelse return error.MissingCommand;
        var values: [timing_count_max]raw.VkPastPresentationTimingGOOGLE = undefined;
        var count: u32 = @intCast(storage.len);
        const result = get(context._device, try context.swapchainHandle(swapchain), &count, if (storage.len == 0) null else &values);
        if (result == raw.VK_INCOMPLETE or count > storage.len) return error.BufferTooSmall;
        try core.checkSuccessTracked(@constCast(context._state), result);
        for (storage[0..count], values[0..count]) |*output, value| output.* = .{
            .id = value.presentID,
            .desired_time_ns = value.desiredPresentTime,
            .actual_time_ns = value.actualPresentTime,
            .earliest_time_ns = value.earliestPresentTime,
            .margin_ns = value.presentMargin,
        };
        return storage[0..count];
    }

    pub fn setDisplayPower(context: Context, target: display.Display, state: PowerState) core.Error!void {
        const set = context._display_power orelse return error.MissingCommand;
        const info: raw.VkDisplayPowerInfoEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_DISPLAY_POWER_INFO_EXT,
            .powerState = @intFromEnum(state),
        };
        try core.checkSuccessTracked(@constCast(context._state), set(context._device, target._handle, &info));
    }

    pub fn registerHotplugEvent(context: Context) core.Error!sync.Fence {
        const register = context._register_device_event orelse return error.MissingCommand;
        const info: raw.VkDeviceEventInfoEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_DEVICE_EVENT_INFO_EXT,
            .deviceEvent = raw.VK_DEVICE_EVENT_TYPE_DISPLAY_HOTPLUG_EXT,
        };
        var handle: raw.VkFence = null;
        const result = register(context._device, &info, context._allocation_callbacks, &handle);
        return context.finishFence(result, handle);
    }

    pub fn registerFirstPixelEvent(context: Context, target: display.Display) core.Error!sync.Fence {
        const register = context._register_display_event orelse return error.MissingCommand;
        const info: raw.VkDisplayEventInfoEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_DISPLAY_EVENT_INFO_EXT,
            .displayEvent = raw.VK_DISPLAY_EVENT_TYPE_FIRST_PIXEL_OUT_EXT,
        };
        var handle: raw.VkFence = null;
        const result = register(context._device, target._handle, &info, context._allocation_callbacks, &handle);
        return context.finishFence(result, handle);
    }

    fn finishFence(context: Context, result: raw.VkResult, handle: raw.VkFence) core.Error!sync.Fence {
        try core.checkSuccessTracked(@constCast(context._state), result);
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._owner = try .init(&handle),
            ._device_handle = context._device,
            ._device_state = context._state.*,
            .allocation_callbacks = context._allocation_callbacks,
            .destroy_fence = context._destroy_fence,
            .get_fence_status = context._get_fence_status,
            .reset_fences = context._reset_fences,
            .wait_for_fences = context._wait_for_fences,
        };
    }

    pub fn verticalBlankCounter(context: Context, swapchain: *const presentation.Swapchain) core.Error!u64 {
        const get = context._swapchain_counter orelse return error.MissingCommand;
        var value: u64 = 0;
        try core.checkSuccessTracked(@constCast(context._state), get(context._device, try context.swapchainHandle(swapchain), raw.VK_SURFACE_COUNTER_VBLANK_BIT_EXT, &value));
        return value;
    }

    pub fn acquireFullScreen(context: Context, swapchain: *const presentation.Swapchain) core.Error!FullScreenStatus {
        if (comptime @hasDecl(raw, "PFN_vkAcquireFullScreenExclusiveModeEXT")) {
            const acquire = loadPlatformCommand(context, raw.PFN_vkAcquireFullScreenExclusiveModeEXT, "vkAcquireFullScreenExclusiveModeEXT") orelse return error.MissingCommand;
            return fullScreenResult(context._state, acquire(context._device, try context.swapchainHandle(swapchain)));
        } else return error.UnsupportedOperation;
    }

    pub fn releaseFullScreen(context: Context, swapchain: *const presentation.Swapchain) core.Error!FullScreenStatus {
        if (comptime @hasDecl(raw, "PFN_vkReleaseFullScreenExclusiveModeEXT")) {
            const release = loadPlatformCommand(context, raw.PFN_vkReleaseFullScreenExclusiveModeEXT, "vkReleaseFullScreenExclusiveModeEXT") orelse return error.MissingCommand;
            return fullScreenResult(context._state, release(context._device, try context.swapchainHandle(swapchain)));
        } else return error.UnsupportedOperation;
    }

    pub fn setSleepMode(context: Context, swapchain: *const presentation.Swapchain, options: SleepMode) core.Error!void {
        const set = context._set_sleep_mode orelse return error.MissingCommand;
        const info: raw.VkLatencySleepModeInfoNV = .{
            .sType = raw.VK_STRUCTURE_TYPE_LATENCY_SLEEP_MODE_INFO_NV,
            .lowLatencyMode = if (options.enabled) raw.VK_TRUE else raw.VK_FALSE,
            .lowLatencyBoost = if (options.boost) raw.VK_TRUE else raw.VK_FALSE,
            .minimumIntervalUs = options.minimum_interval_us,
        };
        try core.checkSuccessTracked(@constCast(context._state), set(context._device, try context.swapchainHandle(swapchain), &info));
    }

    pub fn latencySleep(context: Context, swapchain: *const presentation.Swapchain, semaphore: *const sync.Semaphore, value: u64) core.Error!void {
        if (semaphore._device_handle != context._device or semaphore.kind != .timeline) return error.InvalidHandle;
        const sleep = context._latency_sleep orelse return error.MissingCommand;
        const info: raw.VkLatencySleepInfoNV = .{
            .sType = raw.VK_STRUCTURE_TYPE_LATENCY_SLEEP_INFO_NV,
            .signalSemaphore = try semaphore.rawHandle(),
            .value = value,
        };
        try core.checkSuccessTracked(@constCast(context._state), sleep(context._device, try context.swapchainHandle(swapchain), &info));
    }

    pub fn markLatency(context: Context, swapchain: *const presentation.Swapchain, present_id: u64, marker: LatencyMarker) core.Error!void {
        const set = context._set_marker orelse return error.MissingCommand;
        const info: raw.VkSetLatencyMarkerInfoNV = .{
            .sType = raw.VK_STRUCTURE_TYPE_SET_LATENCY_MARKER_INFO_NV,
            .presentID = present_id,
            .marker = @intFromEnum(marker),
        };
        set(context._device, try context.swapchainHandle(swapchain), &info);
    }

    pub fn latencyTimingsInto(context: Context, swapchain: *const presentation.Swapchain, storage: []LatencyTiming) core.Error![]LatencyTiming {
        if (storage.len > timing_count_max) return error.CountOverflow;
        const get = context._get_latency_timings orelse return error.MissingCommand;
        var values: [timing_count_max]raw.VkLatencyTimingsFrameReportNV = undefined;
        for (values[0..storage.len]) |*value| value.* = .{ .sType = raw.VK_STRUCTURE_TYPE_LATENCY_TIMINGS_FRAME_REPORT_NV };
        var info: raw.VkGetLatencyMarkerInfoNV = .{
            .sType = raw.VK_STRUCTURE_TYPE_GET_LATENCY_MARKER_INFO_NV,
            .timingCount = @intCast(storage.len),
            .pTimings = if (storage.len == 0) null else &values,
        };
        get(context._device, try context.swapchainHandle(swapchain), &info);
        if (info.timingCount > storage.len) return error.BufferTooSmall;
        for (storage[0..info.timingCount], values[0..info.timingCount]) |*output, value| output.* = latencyTiming(value);
        return storage[0..info.timingCount];
    }

    pub fn notifyQueue(context: Context, target: *const queue.Queue, work: QueueWork) core.Error!void {
        if (target._device_handle != context._device) return error.InvalidHandle;
        try context._state.ensureDispatchAllowed();
        const notify = context._notify_queue orelse return error.MissingCommand;
        const info: raw.VkOutOfBandQueueTypeInfoNV = .{
            .sType = raw.VK_STRUCTURE_TYPE_OUT_OF_BAND_QUEUE_TYPE_INFO_NV,
            .queueType = @intFromEnum(work),
        };
        notify(target._handle, &info);
    }

    pub fn updateAntiLag(context: Context, options: AntiLagOptions) core.Error!void {
        try context._state.ensureDispatchAllowed();
        const update = context._anti_lag orelse return error.MissingCommand;
        var presentation_info: raw.VkAntiLagPresentationInfoAMD = .{
            .sType = raw.VK_STRUCTURE_TYPE_ANTI_LAG_PRESENTATION_INFO_AMD,
            .stage = if (options.stage) |stage| @intFromEnum(stage) else raw.VK_ANTI_LAG_STAGE_INPUT_AMD,
            .frameIndex = options.frame_index,
        };
        const data: raw.VkAntiLagDataAMD = .{
            .sType = raw.VK_STRUCTURE_TYPE_ANTI_LAG_DATA_AMD,
            .mode = @intFromEnum(options.mode),
            .maxFPS = options.max_fps,
            .pPresentationInfo = if (options.stage == null) null else &presentation_info,
        };
        update(context._device, &data);
    }
};

fn waitResult(state: *const core.DeviceState, result: raw.VkResult) core.Error!WaitStatus {
    return switch (result) {
        raw.VK_SUCCESS => .complete,
        raw.VK_TIMEOUT => .timeout,
        raw.VK_SUBOPTIMAL_KHR => .suboptimal,
        raw.VK_ERROR_OUT_OF_DATE_KHR => .out_of_date,
        raw.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT => .full_screen_exclusive_lost,
        else => core.checkSuccessTracked(@constCast(state), result) catch |err| return err,
    };
}

fn fullScreenResult(state: *const core.DeviceState, result: raw.VkResult) core.Error!FullScreenStatus {
    return switch (result) {
        raw.VK_SUCCESS => .success,
        raw.VK_ERROR_OUT_OF_DATE_KHR => .out_of_date,
        raw.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT => .full_screen_exclusive_lost,
        else => core.checkSuccessTracked(@constCast(state), result) catch |err| return err,
    };
}

fn latencyTiming(value: raw.VkLatencyTimingsFrameReportNV) LatencyTiming {
    return .{
        .present_id = value.presentID,
        .input_sample_us = value.inputSampleTimeUs,
        .simulation_start_us = value.simStartTimeUs,
        .simulation_end_us = value.simEndTimeUs,
        .render_submit_start_us = value.renderSubmitStartTimeUs,
        .render_submit_end_us = value.renderSubmitEndTimeUs,
        .present_start_us = value.presentStartTimeUs,
        .present_end_us = value.presentEndTimeUs,
        .driver_start_us = value.driverStartTimeUs,
        .driver_end_us = value.driverEndTimeUs,
        .os_render_queue_start_us = value.osRenderQueueStartTimeUs,
        .os_render_queue_end_us = value.osRenderQueueEndTimeUs,
        .gpu_render_start_us = value.gpuRenderStartTimeUs,
        .gpu_render_end_us = value.gpuRenderEndTimeUs,
    };
}

fn loadPlatformCommand(context: Context, comptime OptionalFunction: type, comptime name: [:0]const u8) OptionalFunction {
    const address = context._get_device_proc_addr(context._device, name.ptr) orelse return null;
    return @ptrCast(address);
}

test "presentation wait statuses preserve timing and full-screen results" {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(Context);
    var state: core.DeviceState = .{};
    try std.testing.expectEqual(WaitStatus.timeout, try waitResult(&state, raw.VK_TIMEOUT));
    try std.testing.expectEqual(WaitStatus.suboptimal, try waitResult(&state, raw.VK_SUBOPTIMAL_KHR));
    try std.testing.expectEqual(WaitStatus.out_of_date, try waitResult(&state, raw.VK_ERROR_OUT_OF_DATE_KHR));
    try std.testing.expectEqual(WaitStatus.full_screen_exclusive_lost, try waitResult(&state, raw.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT));
}

test "unavailable presentation commands and platform guards are explicit" {
    var context: Context = undefined;
    context._wait = null;
    const unavailable_swapchain: *const presentation.Swapchain = undefined;
    try std.testing.expectError(error.MissingCommand, context.wait(unavailable_swapchain, 1, .immediate));
    if (builtin.os.tag != .windows) {
        try std.testing.expectError(error.UnsupportedOperation, context.acquireFullScreen(unavailable_swapchain));
    }
}
