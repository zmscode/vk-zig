const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const commands = @import("command_buffer.zig");
const synchronization = @import("synchronization.zig");
const presentation = @import("presentation.zig");
const debug_utils = @import("debug_utils.zig");
const device_group = @import("device_group.zig");
const sparse = @import("sparse.zig");
const images = @import("image.zig");
const memory = @import("memory.zig");

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
    device_mask: device_group.Mask = .primary,
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
    bind_sparse: CommandFunction(raw.PFN_vkQueueBindSparse),
    wait_idle: CommandFunction(raw.PFN_vkQueueWaitIdle),
    present: ?CommandFunction(raw.PFN_vkQueuePresentKHR),
    begin_label: ?CommandFunction(raw.PFN_vkQueueBeginDebugUtilsLabelEXT),
    end_label: ?CommandFunction(raw.PFN_vkQueueEndDebugUtilsLabelEXT),
    insert_label: ?CommandFunction(raw.PFN_vkQueueInsertDebugUtilsLabelEXT),
};

pub const LabelScope = struct {
    _owner: core.Owner,
    queue: QueueHandle,
    end_label: CommandFunction(raw.PFN_vkQueueEndDebugUtilsLabelEXT),
    active: bool = true,

    pub fn end(scope: *LabelScope) void {
        if (!(scope._owner.release(scope) catch return)) return;
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
    _device_state: ?*core.DeviceState = null,
    _device_group_size: u32 = 1,
    _sparse_binding_enabled: bool = true,
    queue_submit: CommandFunction(raw.PFN_vkQueueSubmit),
    queue_submit2: ?CommandFunction(raw.PFN_vkQueueSubmit2),
    queue_bind_sparse: ?CommandFunction(raw.PFN_vkQueueBindSparse) = null,
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
            .queue_bind_sparse = dispatch.bind_sparse,
            .queue_wait_idle = dispatch.wait_idle,
            .queue_present_khr = dispatch.present,
            .queue_begin_debug_utils_label_ext = dispatch.begin_label,
            .queue_end_debug_utils_label_ext = dispatch.end_label,
            .queue_insert_debug_utils_label_ext = dispatch.insert_label,
        };
    }

    fn ensureDispatchAllowed(queue: *const Queue) core.Error!void {
        if (queue._device_state) |state| try state.ensureDispatchAllowed();
    }

    fn checkResult(queue: *const Queue, result: raw.VkResult) core.Error!void {
        if (queue._device_state) |state| {
            return core.checkSuccessTracked(state, result);
        }
        return core.checkSuccess(result);
    }

    pub fn rawHandle(queue: *const Queue) raw.VkQueue {
        return queue._handle;
    }

    pub fn debugObject(queue: *const Queue) core.Error!debug_utils.Object {
        return .forDevice(.queue, queue._handle, queue._device_handle);
    }

    pub fn submit(queue: *const Queue, options: SubmitOptions) core.Error!void {
        try queue.ensureDispatchAllowed();
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
        try queue.checkResult(queue.queue_submit(queue._handle, 1, &submit_info, fence_handle));
        for (options.command_buffers) |buffer| try buffer.markSubmitted();
    }

    pub fn submit2(queue: *const Queue, options: Submit2BatchOptions) core.Error!void {
        try queue.ensureDispatchAllowed();
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
                if (wait.device_index >= queue._device_group_size) return error.InvalidOptions;
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
                try submission.device_mask.validate(queue._device_group_size);
                if (!try buffer.canSubmit()) return error.InvalidOptions;
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
                    .deviceMask = submission.device_mask.bits,
                };
            }
            for (submit_options.signals, 0..) |signal, index| {
                if (signal.device_index >= queue._device_group_size) return error.InvalidOptions;
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

        try queue.checkResult(submit2_command(
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

    pub fn bindSparse(queue: *const Queue, options: sparse.BindOptions) core.Error!void {
        try queue.ensureDispatchAllowed();
        if (!queue._sparse_binding_enabled) return error.FeatureNotPresent;
        const bind_sparse = queue.queue_bind_sparse orelse return error.MissingCommand;
        if (options.batches.len > sparse.batch_count_max) return error.CountOverflow;
        const fence_handle = try fenceHandle(queue._device_handle, options.fence);
        if (options.batches.len == 0) {
            if (fence_handle == null) return;
            return queue.checkResult(bind_sparse(queue._handle, 0, null, fence_handle));
        }

        var infos: [sparse.batch_count_max]raw.VkBindSparseInfo = undefined;
        var wait_handles: [sparse.batch_count_max][sparse.semaphore_count_max]raw.VkSemaphore = undefined;
        var signal_handles: [sparse.batch_count_max][sparse.semaphore_count_max]raw.VkSemaphore = undefined;
        var buffer_infos: [sparse.resource_count_max]raw.VkSparseBufferMemoryBindInfo = undefined;
        var opaque_infos: [sparse.resource_count_max]raw.VkSparseImageOpaqueMemoryBindInfo = undefined;
        var image_infos: [sparse.resource_count_max]raw.VkSparseImageMemoryBindInfo = undefined;
        var memory_binds: [sparse.memory_bind_count_max]raw.VkSparseMemoryBind = undefined;
        var image_binds: [sparse.memory_bind_count_max]raw.VkSparseImageMemoryBind = undefined;
        var buffer_cursor: usize = 0;
        var opaque_cursor: usize = 0;
        var image_cursor: usize = 0;
        var memory_cursor: usize = 0;
        var image_memory_cursor: usize = 0;

        for (options.batches, 0..) |batch, batch_index| {
            if (batch.waits.len > sparse.semaphore_count_max or batch.signals.len > sparse.semaphore_count_max) return error.CountOverflow;
            if (batch.buffer_binds.len > sparse.resource_count_max - buffer_cursor or
                batch.opaque_image_binds.len > sparse.resource_count_max - opaque_cursor or
                batch.image_binds.len > sparse.resource_count_max - image_cursor)
            {
                return error.CountOverflow;
            }
            for (batch.waits, 0..) |semaphore, index| {
                const handle = try sparseSemaphoreHandle(queue, semaphore);
                for (wait_handles[batch_index][0..index]) |previous| {
                    if (previous == handle) return error.InvalidOptions;
                }
                wait_handles[batch_index][index] = handle;
            }
            for (batch.signals, 0..) |semaphore, index| {
                const handle = try sparseSemaphoreHandle(queue, semaphore);
                for (signal_handles[batch_index][0..index]) |previous| {
                    if (previous == handle) return error.InvalidOptions;
                }
                signal_handles[batch_index][index] = handle;
            }

            const buffer_start = buffer_cursor;
            for (batch.buffer_binds) |resource| {
                if (resource.buffer._device_handle != queue._device_handle) return error.InvalidHandle;
                if (resource.binds.len == 0) return error.InvalidOptions;
                if (resource.binds.len > sparse.memory_bind_count_max - memory_cursor) return error.CountOverflow;
                try validateSparseRanges(resource.binds);
                const requirements = try resource.buffer.memoryRequirements();
                const bind_start = memory_cursor;
                for (resource.binds) |binding| {
                    if (binding.flags.metadata) return error.InvalidOptions;
                    memory_binds[memory_cursor] = try sparseMemoryBind(queue, binding, requirements, resource.buffer.size.bytes(), false);
                    memory_cursor += 1;
                }
                buffer_infos[buffer_cursor] = .{
                    .buffer = try resource.buffer.rawHandle(),
                    .bindCount = @intCast(resource.binds.len),
                    .pBinds = memory_binds[bind_start..memory_cursor].ptr,
                };
                buffer_cursor += 1;
            }

            const opaque_start = opaque_cursor;
            for (batch.opaque_image_binds) |resource| {
                if (resource.image._device_handle != queue._device_handle) return error.InvalidHandle;
                if (resource.binds.len == 0) return error.InvalidOptions;
                if (resource.binds.len > sparse.memory_bind_count_max - memory_cursor) return error.CountOverflow;
                try validateSparseRanges(resource.binds);
                const requirements = try resource.image.memoryRequirements();
                var sparse_requirements_storage: [images.sparse_requirement_count_max]images.SparseMemoryRequirements = undefined;
                const sparse_requirements = try resource.image.sparseMemoryRequirements(&sparse_requirements_storage);
                const bind_start = memory_cursor;
                for (resource.binds) |binding| {
                    if (binding.flags.metadata) try validateMetadataTail(resource.image, binding, sparse_requirements);
                    memory_binds[memory_cursor] = try sparseMemoryBind(queue, binding, requirements, requirements.size.bytes(), true);
                    memory_cursor += 1;
                }
                opaque_infos[opaque_cursor] = .{
                    .image = try resource.image.rawHandle(),
                    .bindCount = @intCast(resource.binds.len),
                    .pBinds = memory_binds[bind_start..memory_cursor].ptr,
                };
                opaque_cursor += 1;
            }

            const image_start = image_cursor;
            for (batch.image_binds) |resource| {
                if (resource.image._device_handle != queue._device_handle) return error.InvalidHandle;
                if (resource.binds.len == 0) return error.InvalidOptions;
                if (resource.binds.len > sparse.memory_bind_count_max - image_memory_cursor) return error.CountOverflow;
                const requirements = try resource.image.memoryRequirements();
                const bind_start = image_memory_cursor;
                var sparse_requirements_storage: [images.sparse_requirement_count_max]images.SparseMemoryRequirements = undefined;
                const sparse_requirements = try resource.image.sparseMemoryRequirements(&sparse_requirements_storage);
                for (resource.binds) |binding| {
                    image_binds[image_memory_cursor] = try sparseImageMemoryBind(queue, resource.image, binding, requirements, sparse_requirements);
                    image_memory_cursor += 1;
                }
                image_infos[image_cursor] = .{
                    .image = try resource.image.rawHandle(),
                    .bindCount = @intCast(resource.binds.len),
                    .pBinds = image_binds[bind_start..image_memory_cursor].ptr,
                };
                image_cursor += 1;
            }

            infos[batch_index] = .{
                .sType = raw.VK_STRUCTURE_TYPE_BIND_SPARSE_INFO,
                .waitSemaphoreCount = @intCast(batch.waits.len),
                .pWaitSemaphores = if (batch.waits.len == 0) null else wait_handles[batch_index][0..batch.waits.len].ptr,
                .bufferBindCount = @intCast(batch.buffer_binds.len),
                .pBufferBinds = if (batch.buffer_binds.len == 0) null else buffer_infos[buffer_start..buffer_cursor].ptr,
                .imageOpaqueBindCount = @intCast(batch.opaque_image_binds.len),
                .pImageOpaqueBinds = if (batch.opaque_image_binds.len == 0) null else opaque_infos[opaque_start..opaque_cursor].ptr,
                .imageBindCount = @intCast(batch.image_binds.len),
                .pImageBinds = if (batch.image_binds.len == 0) null else image_infos[image_start..image_cursor].ptr,
                .signalSemaphoreCount = @intCast(batch.signals.len),
                .pSignalSemaphores = if (batch.signals.len == 0) null else signal_handles[batch_index][0..batch.signals.len].ptr,
            };
        }
        try queue.checkResult(bind_sparse(queue._handle, @intCast(options.batches.len), infos[0..options.batches.len].ptr, fence_handle));
    }

    /// Advanced escape hatch for extension structures not yet represented by vk-zig.
    pub fn submitRaw(
        queue: *const Queue,
        submit_infos: []const raw.VkSubmitInfo,
        fence: raw.VkFence,
    ) core.Error!void {
        try queue.ensureDispatchAllowed();
        try queue.checkResult(queue.queue_submit(
            queue._handle,
            try core.count32(submit_infos.len),
            if (submit_infos.len == 0) null else submit_infos.ptr,
            fence,
        ));
    }

    pub fn waitIdle(queue: *const Queue) core.Error!void {
        try queue.ensureDispatchAllowed();
        try queue.checkResult(queue.queue_wait_idle(queue._handle));
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
        var owner = try core.Owner.init({});
        errdefer _ = owner.release({}) catch {};
        try queue.beginLabel(options);
        return .{ ._owner = owner, .queue = queue._handle, .end_label = end_label };
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
        try queue.ensureDispatchAllowed();
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
        if ((options.device_mask == null) != (options.device_group_mode == null)) return error.InvalidOptions;
        if (options.present_id != null and options.present_id2 != null) return error.InvalidOptions;
        if (options.damaged_regions.len > 64) return error.CountOverflow;
        var next: ?*const anyopaque = null;
        var present_id_info: raw.VkPresentIdKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_PRESENT_ID_KHR };
        if (options.present_id) |present_id| {
            present_id_info.swapchainCount = 1;
            present_id_info.pPresentIds = &present_id;
            present_id_info.pNext = next;
            next = &present_id_info;
        }
        var present_id2_info: raw.VkPresentId2KHR = .{ .sType = raw.VK_STRUCTURE_TYPE_PRESENT_ID_2_KHR };
        if (options.present_id2) |present_id| {
            present_id2_info.swapchainCount = 1;
            present_id2_info.pPresentIds = &present_id;
            present_id2_info.pNext = next;
            next = &present_id2_info;
        }
        var google_time: raw.VkPresentTimeGOOGLE = .{};
        var google_info: raw.VkPresentTimesInfoGOOGLE = .{ .sType = raw.VK_STRUCTURE_TYPE_PRESENT_TIMES_INFO_GOOGLE };
        if (options.google_timing) |timing| {
            google_time = .{ .presentID = timing.id, .desiredPresentTime = timing.desired_time_ns };
            google_info.swapchainCount = 1;
            google_info.pTimes = &google_time;
            google_info.pNext = next;
            next = &google_info;
        }
        var rectangles: [64]raw.VkRectLayerKHR = undefined;
        var region: raw.VkPresentRegionKHR = .{};
        var regions_info: raw.VkPresentRegionsKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_PRESENT_REGIONS_KHR };
        if (options.damaged_regions.len != 0) {
            for (options.damaged_regions, 0..) |damaged, index| rectangles[index] = .{
                .offset = damaged.rectangle.offset.toRaw(),
                .extent = damaged.rectangle.extent.toRaw(),
                .layer = damaged.layer,
            };
            region.rectangleCount = @intCast(options.damaged_regions.len);
            region.pRectangles = rectangles[0..options.damaged_regions.len].ptr;
            regions_info.swapchainCount = 1;
            regions_info.pRegions = &region;
            regions_info.pNext = next;
            next = &regions_info;
        }
        var present_fence_handle: raw.VkFence = null;
        var fence_info: raw.VkSwapchainPresentFenceInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_SWAPCHAIN_PRESENT_FENCE_INFO_KHR };
        if (options.present_fence) |fence| {
            if (fence._device_handle != queue._device_handle) return error.InvalidHandle;
            present_fence_handle = try fence.rawHandle();
            fence_info.swapchainCount = 1;
            fence_info.pFences = &present_fence_handle;
            fence_info.pNext = next;
            next = &fence_info;
        }
        var present_mode_raw: raw.VkPresentModeKHR = 0;
        var mode_info: raw.VkSwapchainPresentModeInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_SWAPCHAIN_PRESENT_MODE_INFO_KHR };
        if (options.present_mode) |mode| {
            present_mode_raw = mode.toRaw();
            mode_info.swapchainCount = 1;
            mode_info.pPresentModes = &present_mode_raw;
            mode_info.pNext = next;
            next = &mode_info;
        }
        var latency_info: raw.VkLatencySubmissionPresentIdNV = .{ .sType = raw.VK_STRUCTURE_TYPE_LATENCY_SUBMISSION_PRESENT_ID_NV };
        if (options.latency_present_id) |present_id| {
            latency_info.presentID = present_id;
            latency_info.pNext = next;
            next = &latency_info;
        }
        var group_info: raw.VkDeviceGroupPresentInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_DEVICE_GROUP_PRESENT_INFO_KHR,
            .pNext = next,
        };
        if (options.device_mask) |mask| {
            try mask.validate(queue._device_group_size);
            group_info.swapchainCount = 1;
            group_info.pDeviceMasks = &mask.bits;
            group_info.mode = options.device_group_mode.?.toRaw();
            next = &group_info;
        }
        const present_info: raw.VkPresentInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .pNext = next,
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
        if (result == raw.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT) return .full_screen_exclusive_lost;
        try queue.checkResult(result);
        unreachable;
    }
};

fn sparseSemaphoreHandle(queue: *const Queue, semaphore: *const synchronization.Semaphore) core.Error!raw.VkSemaphore {
    if (semaphore._device_handle != queue._device_handle) return error.InvalidHandle;
    if (semaphore.kind != .binary) return error.InvalidOptions;
    return semaphore.rawHandle();
}

fn validateSparseRanges(binds: []const sparse.MemoryBind) core.Error!void {
    for (binds, 0..) |binding, index| {
        const start = binding.resource_offset.bytes();
        const size = binding.size.bytes();
        if (size == 0 or size > std.math.maxInt(u64) - start) return error.InvalidOptions;
        const end = start + size;
        for (binds[0..index]) |previous| {
            const previous_start = previous.resource_offset.bytes();
            const previous_size = previous.size.bytes();
            if (previous_size > std.math.maxInt(u64) - previous_start) return error.InvalidOptions;
            const previous_end = previous_start + previous_size;
            if (start < previous_end and previous_start < end) return error.InvalidOptions;
        }
    }
}

fn validateMetadataTail(
    resource: *const images.Image,
    binding: sparse.MemoryBind,
    requirements: []const images.SparseMemoryRequirements,
) core.Error!void {
    const bind_start = binding.resource_offset.bytes();
    const bind_size = binding.size.bytes();
    if (bind_size > std.math.maxInt(u64) - bind_start) return error.InvalidOptions;
    const bind_end = bind_start + bind_size;
    for (requirements) |requirement| {
        if (!requirement.aspects.contains(.metadata)) continue;
        const tail_count: u32 = if (requirement.flags.contains(.single_miptail)) 1 else resource.array_layers;
        for (0..tail_count) |layer| {
            const stride = requirement.mip_tail_stride.bytes();
            if (layer != 0 and stride > std.math.maxInt(u64) / layer) return error.InvalidProperties;
            const layer_offset = stride * layer;
            const tail_start = requirement.mip_tail_offset.bytes();
            if (layer_offset > std.math.maxInt(u64) - tail_start) return error.InvalidProperties;
            const start = tail_start + layer_offset;
            const size = requirement.mip_tail_size.bytes();
            if (size > std.math.maxInt(u64) - start) return error.InvalidProperties;
            if (bind_start >= start and bind_end <= start + size) return;
        }
    }
    return error.InvalidOptions;
}

fn sparseMemoryBind(
    queue: *const Queue,
    binding: sparse.MemoryBind,
    requirements: memory.Requirements,
    resource_size: u64,
    metadata_allowed: bool,
) core.Error!raw.VkSparseMemoryBind {
    const offset = binding.resource_offset.bytes();
    const size = binding.size.bytes();
    const alignment = requirements.alignment.bytes();
    if (size == 0 or offset > resource_size or size > resource_size - offset) return error.InvalidOptions;
    if (alignment != 0) {
        if (offset % alignment != 0) return error.InvalidOptions;
        if (size % alignment != 0 and offset + size != resource_size) return error.InvalidOptions;
    }
    if (binding.flags.metadata and !metadata_allowed) return error.InvalidOptions;
    return .{
        .resourceOffset = offset,
        .size = size,
        .memory = try sparseAllocationHandle(queue, binding.allocation, binding.memory_offset, size, alignment, requirements),
        .memoryOffset = binding.memory_offset.bytes(),
        .flags = if (binding.flags.metadata) raw.VK_SPARSE_MEMORY_BIND_METADATA_BIT else 0,
    };
}

fn sparseImageMemoryBind(
    queue: *const Queue,
    resource: *const images.Image,
    binding: sparse.ImageMemoryBind,
    requirements: memory.Requirements,
    sparse_requirements: []const images.SparseMemoryRequirements,
) core.Error!raw.VkSparseImageMemoryBind {
    if (binding.subresource.aspect == .none or binding.subresource.aspect == .metadata or
        binding.subresource.mip_level >= resource.mip_levels or
        binding.subresource.array_layer >= resource.array_layers or
        binding.offset.x < 0 or binding.offset.y < 0 or binding.offset.z < 0 or
        binding.extent.width == 0 or binding.extent.height == 0 or binding.extent.depth == 0)
    {
        return error.InvalidOptions;
    }
    const mip_width = mipDimension(resource.extent.width, binding.subresource.mip_level);
    const mip_height = mipDimension(resource.extent.height, binding.subresource.mip_level);
    const mip_depth = mipDimension(resource.extent.depth, binding.subresource.mip_level);
    const x: u32 = @intCast(binding.offset.x);
    const y: u32 = @intCast(binding.offset.y);
    const z: u32 = @intCast(binding.offset.z);
    if (x > mip_width or binding.extent.width > mip_width - x or
        y > mip_height or binding.extent.height > mip_height - y or
        z > mip_depth or binding.extent.depth > mip_depth - z)
    {
        return error.InvalidOptions;
    }

    var granularity: ?types.Extent3D = null;
    for (sparse_requirements) |candidate| {
        if (candidate.aspects.contains(binding.subresource.aspect)) {
            granularity = candidate.granularity;
            break;
        }
    }
    const block = granularity orelse return error.InvalidOptions;
    if (!sparseAxisValid(x, binding.extent.width, mip_width, block.width) or
        !sparseAxisValid(y, binding.extent.height, mip_height, block.height) or
        !sparseAxisValid(z, binding.extent.depth, mip_depth, block.depth))
    {
        return error.InvalidOptions;
    }
    const block_count = try checkedProduct3(
        divideRoundUp(binding.extent.width, block.width),
        divideRoundUp(binding.extent.height, block.height),
        divideRoundUp(binding.extent.depth, block.depth),
    );
    const alignment = requirements.alignment.bytes();
    if (alignment != 0 and block_count > std.math.maxInt(u64) / alignment) return error.InvalidOptions;
    const required_bytes = block_count * alignment;
    return .{
        .subresource = binding.subresource.toRaw(),
        .offset = binding.offset.toRaw(),
        .extent = binding.extent.toRaw(),
        .memory = try sparseAllocationHandle(queue, binding.allocation, binding.memory_offset, required_bytes, alignment, requirements),
        .memoryOffset = binding.memory_offset.bytes(),
    };
}

fn sparseAllocationHandle(
    queue: *const Queue,
    allocation: ?*const memory.Allocation,
    memory_offset: core.DeviceOffset,
    required_bytes: u64,
    alignment: u64,
    requirements: memory.Requirements,
) core.Error!raw.VkDeviceMemory {
    const value = allocation orelse {
        if (memory_offset != .zero) return error.InvalidOptions;
        return null;
    };
    if (value._device_handle != queue._device_handle) return error.InvalidHandle;
    if (!requirements.supportsMemoryType(value.memory_type_index)) return error.InvalidOptions;
    const offset = memory_offset.bytes();
    if (alignment != 0 and offset % alignment != 0) return error.InvalidOptions;
    if (offset > value.size.bytes() or required_bytes > value.size.bytes() - offset) return error.InvalidOptions;
    return (try value.rawHandle()) orelse error.InvalidHandle;
}

fn mipDimension(base: u32, level: u32) u32 {
    if (level >= 32) return 1;
    return @max(base >> @intCast(level), 1);
}

fn sparseAxisValid(offset: u32, extent: u32, total: u32, granularity: u32) bool {
    if (granularity == 0 or offset % granularity != 0) return false;
    return extent % granularity == 0 or offset + extent == total;
}

fn divideRoundUp(value: u32, divisor: u32) u64 {
    return (@as(u64, value) + divisor - 1) / divisor;
}

fn checkedProduct3(a: u64, b: u64, c: u64) core.Error!u64 {
    if (a != 0 and b > std.math.maxInt(u64) / a) return error.InvalidOptions;
    const ab = a * b;
    if (ab != 0 and c > std.math.maxInt(u64) / ab) return error.InvalidOptions;
    return ab * c;
}

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
