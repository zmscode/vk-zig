const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const commands = @import("command_buffer.zig");
const synchronization = @import("synchronization.zig");
const presentation = @import("presentation.zig");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const QueueHandle = core.NonNullHandle(raw.VkQueue);
const submission_item_count_max = 64;
const submission_batch_count_max = 16;

pub const SemaphoreWait = struct {
    semaphore: *const synchronization.Semaphore,
    stage: types.PipelineStageFlags,
};

pub const SubmitOptions = struct {
    waits: []const SemaphoreWait = &.{},
    command_buffers: []const *commands.Buffer = &.{},
    signals: []const *const synchronization.Semaphore = &.{},
    fence: ?*const synchronization.Fence = null,
};

pub const SemaphoreSubmit = struct {
    semaphore: *const synchronization.Semaphore,
    value: u64 = 0,
    stage: types.PipelineStage2Flags = .empty,
    device_index: u32 = 0,
};

pub const CommandBufferSubmit = struct {
    command_buffer: *commands.Buffer,
    device_mask: u32 = 1,
};

pub const Submit2Options = struct {
    flags: types.SubmitFlags = .empty,
    performance_query_pass: ?u32 = null,
    waits: []const SemaphoreSubmit = &.{},
    command_buffers: []const CommandBufferSubmit = &.{},
    signals: []const SemaphoreSubmit = &.{},
};

pub const Submit2BatchOptions = struct {
    submits: []const Submit2Options = &.{},
    fence: ?*const synchronization.Fence = null,
};

pub const Dispatch = struct {
    submit: CommandFunction(raw.PFN_vkQueueSubmit),
    submit2: ?CommandFunction(raw.PFN_vkQueueSubmit2),
    wait_idle: CommandFunction(raw.PFN_vkQueueWaitIdle),
    present: ?CommandFunction(raw.PFN_vkQueuePresentKHR),
    begin_label: ?CommandFunction(raw.PFN_vkQueueBeginDebugUtilsLabelEXT),
    end_label: ?CommandFunction(raw.PFN_vkQueueEndDebugUtilsLabelEXT),
    insert_label: ?CommandFunction(raw.PFN_vkQueueInsertDebugUtilsLabelEXT),
};

pub const LabelScope = struct {
    queue: QueueHandle,
    end_label: CommandFunction(raw.PFN_vkQueueEndDebugUtilsLabelEXT),
    active: bool = true,

    pub fn end(scope: *LabelScope) void {
        if (!scope.active) return;
        scope.end_label(scope.queue);
        scope.active = false;
    }

    pub fn deinit(scope: *LabelScope) void {
        scope.end();
    }
};

pub const Queue = struct {
    _handle: QueueHandle,
    _device_handle: DeviceHandle,
    queue_submit: CommandFunction(raw.PFN_vkQueueSubmit),
    queue_submit2: ?CommandFunction(raw.PFN_vkQueueSubmit2),
    queue_wait_idle: CommandFunction(raw.PFN_vkQueueWaitIdle),
    queue_present_khr: ?CommandFunction(raw.PFN_vkQueuePresentKHR),
    queue_begin_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkQueueBeginDebugUtilsLabelEXT),
    queue_end_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkQueueEndDebugUtilsLabelEXT),
    queue_insert_debug_utils_label_ext: ?CommandFunction(raw.PFN_vkQueueInsertDebugUtilsLabelEXT),

    pub fn init(handle: QueueHandle, device_handle: DeviceHandle, dispatch: Dispatch) Queue {
        return .{
            ._handle = handle,
            ._device_handle = device_handle,
            .queue_submit = dispatch.submit,
            .queue_submit2 = dispatch.submit2,
            .queue_wait_idle = dispatch.wait_idle,
            .queue_present_khr = dispatch.present,
            .queue_begin_debug_utils_label_ext = dispatch.begin_label,
            .queue_end_debug_utils_label_ext = dispatch.end_label,
            .queue_insert_debug_utils_label_ext = dispatch.insert_label,
        };
    }

    pub fn rawHandle(queue: *const Queue) raw.VkQueue {
        return queue._handle;
    }

    pub fn debugObject(queue: *const Queue) core.Error!debug_utils.Object {
        return .forDevice(.queue, queue._handle, queue._device_handle);
    }

    pub fn submit(queue: *const Queue, options: SubmitOptions) core.Error!void {
        if (options.waits.len > submission_item_count_max or
            options.command_buffers.len > submission_item_count_max or
            options.signals.len > submission_item_count_max)
        {
            return error.CountOverflow;
        }

        var wait_handles: [submission_item_count_max]raw.VkSemaphore = undefined;
        var wait_stages: [submission_item_count_max]raw.VkPipelineStageFlags = undefined;
        for (options.waits, 0..) |wait, index| {
            if (wait.semaphore._device_handle != queue._device_handle) return error.InvalidHandle;
            if (wait.semaphore.kind != .binary) return error.InvalidOptions;
            wait_handles[index] = try wait.semaphore.rawHandle();
            wait_stages[index] = wait.stage.toRaw();
        }

        var command_handles: [submission_item_count_max]raw.VkCommandBuffer = undefined;
        for (options.command_buffers, 0..) |buffer, index| {
            if (buffer._device_handle != queue._device_handle) return error.InvalidHandle;
            if (!try buffer.canSubmit()) return error.InvalidOptions;
            command_handles[index] = try buffer.rawHandle();
        }

        var signal_handles: [submission_item_count_max]raw.VkSemaphore = undefined;
        for (options.signals, 0..) |semaphore, index| {
            if (semaphore._device_handle != queue._device_handle) return error.InvalidHandle;
            if (semaphore.kind != .binary) return error.InvalidOptions;
            signal_handles[index] = try semaphore.rawHandle();
        }

        const fence_handle = try fenceHandle(queue._device_handle, options.fence);
        const submit_info: raw.VkSubmitInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = @intCast(options.waits.len),
            .pWaitSemaphores = if (options.waits.len == 0) null else wait_handles[0..options.waits.len].ptr,
            .pWaitDstStageMask = if (options.waits.len == 0) null else wait_stages[0..options.waits.len].ptr,
            .commandBufferCount = @intCast(options.command_buffers.len),
            .pCommandBuffers = if (options.command_buffers.len == 0) null else command_handles[0..options.command_buffers.len].ptr,
            .signalSemaphoreCount = @intCast(options.signals.len),
            .pSignalSemaphores = if (options.signals.len == 0) null else signal_handles[0..options.signals.len].ptr,
        };
        try core.checkSuccess(queue.queue_submit(queue._handle, 1, &submit_info, fence_handle));
        for (options.command_buffers) |buffer| try buffer.markSubmitted();
    }

    pub fn submit2(queue: *const Queue, options: Submit2BatchOptions) core.Error!void {
        if (options.submits.len > submission_batch_count_max) return error.CountOverflow;
        const fence_handle = try fenceHandle(queue._device_handle, options.fence);
        if (options.submits.len == 0 and fence_handle == null) return;
        const submit2_command = queue.queue_submit2 orelse return error.MissingCommand;

        var wait_infos: [submission_batch_count_max][submission_item_count_max]raw.VkSemaphoreSubmitInfo = undefined;
        var command_infos: [submission_batch_count_max][submission_item_count_max]raw.VkCommandBufferSubmitInfo = undefined;
        var signal_infos: [submission_batch_count_max][submission_item_count_max]raw.VkSemaphoreSubmitInfo = undefined;
        var performance_infos: [submission_batch_count_max]raw.VkPerformanceQuerySubmitInfoKHR = undefined;
        var submit_infos: [submission_batch_count_max]raw.VkSubmitInfo2 = undefined;

        for (options.submits, 0..) |submit_options, submit_index| {
            if (submit_options.waits.len > submission_item_count_max or
                submit_options.command_buffers.len > submission_item_count_max or
                submit_options.signals.len > submission_item_count_max)
            {
                return error.CountOverflow;
            }
            for (submit_options.waits, 0..) |wait, index| {
                if (wait.semaphore._device_handle != queue._device_handle) return error.InvalidHandle;
                if (wait.semaphore.kind == .binary and wait.value != 0) return error.InvalidOptions;
                const handle = try wait.semaphore.rawHandle();
                for (submit_options.waits[0..index]) |previous| {
                    if (try previous.semaphore.rawHandle() == handle) return error.InvalidOptions;
                }
                wait_infos[submit_index][index] = .{
                    .sType = raw.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO,
                    .semaphore = handle,
                    .value = wait.value,
                    .stageMask = wait.stage.toRaw(),
                    .deviceIndex = wait.device_index,
                };
            }
            for (submit_options.command_buffers, 0..) |submission, index| {
                const buffer = submission.command_buffer;
                if (buffer._device_handle != queue._device_handle) return error.InvalidHandle;
                if (submission.device_mask == 0 or !try buffer.canSubmit()) return error.InvalidOptions;
                const handle = try buffer.rawHandle();
                for (options.submits[0..submit_index]) |previous_submit| {
                    for (previous_submit.command_buffers) |previous| {
                        if (try previous.command_buffer.rawHandle() == handle) return error.InvalidOptions;
                    }
                }
                for (submit_options.command_buffers[0..index]) |previous| {
                    if (try previous.command_buffer.rawHandle() == handle) return error.InvalidOptions;
                }
                command_infos[submit_index][index] = .{
                    .sType = raw.VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO,
                    .commandBuffer = handle,
                    .deviceMask = submission.device_mask,
                };
            }
            for (submit_options.signals, 0..) |signal, index| {
                if (signal.semaphore._device_handle != queue._device_handle) return error.InvalidHandle;
                if (signal.semaphore.kind == .binary and signal.value != 0) return error.InvalidOptions;
                if (signal.semaphore.kind == .timeline and signal.value == 0) return error.InvalidOptions;
                const handle = try signal.semaphore.rawHandle();
                for (submit_options.signals[0..index]) |previous| {
                    if (try previous.semaphore.rawHandle() == handle) return error.InvalidOptions;
                }
                for (submit_options.waits) |wait| {
                    if (try wait.semaphore.rawHandle() != handle) continue;
                    if (signal.semaphore.kind == .binary or signal.value <= wait.value) {
                        return error.InvalidOptions;
                    }
                }
                signal_infos[submit_index][index] = .{
                    .sType = raw.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO,
                    .semaphore = handle,
                    .value = signal.value,
                    .stageMask = signal.stage.toRaw(),
                    .deviceIndex = signal.device_index,
                };
            }
            if (submit_options.performance_query_pass) |counter_pass_index| {
                performance_infos[submit_index] = .{
                    .sType = raw.VK_STRUCTURE_TYPE_PERFORMANCE_QUERY_SUBMIT_INFO_KHR,
                    .counterPassIndex = counter_pass_index,
                };
            }
            submit_infos[submit_index] = .{
                .sType = raw.VK_STRUCTURE_TYPE_SUBMIT_INFO_2,
                .pNext = if (submit_options.performance_query_pass != null)
                    &performance_infos[submit_index]
                else
                    null,
                .flags = submit_options.flags.toRaw(),
                .waitSemaphoreInfoCount = @intCast(submit_options.waits.len),
                .pWaitSemaphoreInfos = if (submit_options.waits.len == 0) null else wait_infos[submit_index][0..submit_options.waits.len].ptr,
                .commandBufferInfoCount = @intCast(submit_options.command_buffers.len),
                .pCommandBufferInfos = if (submit_options.command_buffers.len == 0) null else command_infos[submit_index][0..submit_options.command_buffers.len].ptr,
                .signalSemaphoreInfoCount = @intCast(submit_options.signals.len),
                .pSignalSemaphoreInfos = if (submit_options.signals.len == 0) null else signal_infos[submit_index][0..submit_options.signals.len].ptr,
            };
        }

        try core.checkSuccess(submit2_command(
            queue._handle,
            @intCast(options.submits.len),
            if (options.submits.len == 0) null else submit_infos[0..options.submits.len].ptr,
            fence_handle,
        ));
        for (options.submits) |submit_options| {
            for (submit_options.command_buffers) |submission| {
                try submission.command_buffer.markSubmitted();
            }
        }
    }

    /// Advanced escape hatch for extension structures not yet represented by vk-zig.
    pub fn submitRaw(
        queue: *const Queue,
        submit_infos: []const raw.VkSubmitInfo,
        fence: raw.VkFence,
    ) core.Error!void {
        try core.checkSuccess(queue.queue_submit(
            queue._handle,
            try core.count32(submit_infos.len),
            if (submit_infos.len == 0) null else submit_infos.ptr,
            fence,
        ));
    }

    pub fn waitIdle(queue: *const Queue) core.Error!void {
        try core.checkSuccess(queue.queue_wait_idle(queue._handle));
    }

    pub fn beginLabel(queue: *const Queue, options: debug_utils.LabelOptions) core.Error!void {
        const begin_label = queue.queue_begin_debug_utils_label_ext orelse return error.MissingCommand;
        const label = options.toRaw();
        begin_label(queue._handle, &label);
    }

    pub fn beginLabelScope(
        queue: *const Queue,
        options: debug_utils.LabelOptions,
    ) core.Error!LabelScope {
        const end_label = queue.queue_end_debug_utils_label_ext orelse return error.MissingCommand;
        try queue.beginLabel(options);
        return .{ .queue = queue._handle, .end_label = end_label };
    }

    pub fn endLabel(queue: *const Queue) core.Error!void {
        const end_label = queue.queue_end_debug_utils_label_ext orelse return error.MissingCommand;
        end_label(queue._handle);
    }

    pub fn insertLabel(queue: *const Queue, options: debug_utils.LabelOptions) core.Error!void {
        const insert_label = queue.queue_insert_debug_utils_label_ext orelse return error.MissingCommand;
        const label = options.toRaw();
        insert_label(queue._handle, &label);
    }

    pub fn present(
        queue: *const Queue,
        options: presentation.PresentOptions,
    ) core.Error!presentation.PresentStatus {
        const present_command = queue.queue_present_khr orelse return error.MissingCommand;
        if (options.swapchain._device_handle != queue._device_handle) return error.InvalidHandle;
        if (options.wait_semaphores.len > submission_item_count_max) return error.CountOverflow;
        var wait_handles: [submission_item_count_max]raw.VkSemaphore = undefined;
        for (options.wait_semaphores, 0..) |semaphore, index| {
            if (semaphore._device_handle != queue._device_handle) return error.InvalidHandle;
            if (semaphore.kind != .binary) return error.InvalidOptions;
            wait_handles[index] = try semaphore.rawHandle();
        }
        const swapchain_handle = try options.swapchain.rawHandle();
        const image_index = options.image_index.toRaw();
        const present_info: raw.VkPresentInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .pNext = options.next,
            .waitSemaphoreCount = @intCast(options.wait_semaphores.len),
            .pWaitSemaphores = if (options.wait_semaphores.len == 0) null else wait_handles[0..options.wait_semaphores.len].ptr,
            .swapchainCount = 1,
            .pSwapchains = @ptrCast(&swapchain_handle),
            .pImageIndices = @ptrCast(&image_index),
        };
        const result = present_command(queue._handle, &present_info);
        if (result == raw.VK_SUCCESS) return .success;
        if (result == raw.VK_SUBOPTIMAL_KHR) return .suboptimal;
        if (result == raw.VK_ERROR_OUT_OF_DATE_KHR) return .out_of_date;
        try core.checkSuccess(result);
        unreachable;
    }
};

fn fenceHandle(
    device_handle: DeviceHandle,
    fence: ?*const synchronization.Fence,
) core.Error!raw.VkFence {
    if (fence) |value| {
        if (value._device_handle != device_handle) return error.InvalidHandle;
        return try value.rawHandle();
    }
    return null;
}
