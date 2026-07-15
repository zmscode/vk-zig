const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");
const types = @import("vulkan_types");
const buffers = @import("buffer.zig");
const images = @import("image.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const SemaphoreHandle = core.NonNullHandle(raw.VkSemaphore);
const FenceHandle = core.NonNullHandle(raw.VkFence);
const EventHandle = core.NonNullHandle(raw.VkEvent);

pub const MemoryBarrier = struct {
    source_stage: types.PipelineStage2Flags,
    source_access: types.Access2Flags = .empty,
    destination_stage: types.PipelineStage2Flags,
    destination_access: types.Access2Flags = .empty,

    pub fn toRaw(value: MemoryBarrier) raw.VkMemoryBarrier2 {
        return .{
            .sType = raw.VK_STRUCTURE_TYPE_MEMORY_BARRIER_2,
            .srcStageMask = value.source_stage.toRaw(),
            .srcAccessMask = value.source_access.toRaw(),
            .dstStageMask = value.destination_stage.toRaw(),
            .dstAccessMask = value.destination_access.toRaw(),
        };
    }
};

pub const BufferBarrier = struct {
    source_stage: types.PipelineStage2Flags,
    source_access: types.Access2Flags = .empty,
    destination_stage: types.PipelineStage2Flags,
    destination_access: types.Access2Flags = .empty,
    ownership: core.QueueFamilyOwnership = .ignored,
    buffer: *const buffers.Buffer,
    offset: core.DeviceOffset = .zero,
    range: core.DeviceRange = .whole,

    pub fn toRaw(value: BufferBarrier) core.Error!raw.VkBufferMemoryBarrier2 {
        const offset = value.offset.bytes();
        if (offset >= value.buffer.size.bytes()) return error.InvalidOptions;
        switch (value.range) {
            .whole => {},
            .bytes => |size| if (size.bytes() > value.buffer.size.bytes() - offset) return error.InvalidOptions,
        }
        return .{
            .sType = raw.VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER_2,
            .srcStageMask = value.source_stage.toRaw(),
            .srcAccessMask = value.source_access.toRaw(),
            .dstStageMask = value.destination_stage.toRaw(),
            .dstAccessMask = value.destination_access.toRaw(),
            .srcQueueFamilyIndex = value.ownership.sourceRaw(),
            .dstQueueFamilyIndex = value.ownership.destinationRaw(),
            .buffer = try value.buffer.rawHandle(),
            .offset = offset,
            .size = value.range.toRaw(),
        };
    }
};

pub const ImageBarrier = struct {
    source_stage: types.PipelineStage2Flags,
    source_access: types.Access2Flags = .empty,
    destination_stage: types.PipelineStage2Flags,
    destination_access: types.Access2Flags = .empty,
    old_layout: types.ImageLayout,
    new_layout: types.ImageLayout,
    ownership: core.QueueFamilyOwnership = .ignored,
    image: images.Reference,
    subresource_range: types.ImageSubresourceRange,

    pub fn transition(
        image: images.Reference,
        old_layout: types.ImageLayout,
        new_layout: types.ImageLayout,
        source_stage: types.PipelineStage2Flags,
        destination_stage: types.PipelineStage2Flags,
        range: types.ImageSubresourceRange,
    ) ImageBarrier {
        return .{
            .source_stage = source_stage,
            .destination_stage = destination_stage,
            .old_layout = old_layout,
            .new_layout = new_layout,
            .image = image,
            .subresource_range = range,
        };
    }

    pub fn toRaw(value: ImageBarrier) core.Error!raw.VkImageMemoryBarrier2 {
        return .{
            .sType = raw.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
            .srcStageMask = value.source_stage.toRaw(),
            .srcAccessMask = value.source_access.toRaw(),
            .dstStageMask = value.destination_stage.toRaw(),
            .dstAccessMask = value.destination_access.toRaw(),
            .oldLayout = value.old_layout.toRaw(),
            .newLayout = value.new_layout.toRaw(),
            .srcQueueFamilyIndex = value.ownership.sourceRaw(),
            .dstQueueFamilyIndex = value.ownership.destinationRaw(),
            .image = try value.image.handle(),
            .subresourceRange = value.subresource_range.toRaw(),
        };
    }
};

pub const DependencyInfo = struct {
    flags: types.DependencyFlags = .empty,
    memory_barriers: []const MemoryBarrier = &.{},
    buffer_barriers: []const BufferBarrier = &.{},
    image_barriers: []const ImageBarrier = &.{},
};

pub const EventStatus = enum { set, reset };

pub const EventDispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateEvent),
    destroy: CommandFunction(raw.PFN_vkDestroyEvent),
    status: CommandFunction(raw.PFN_vkGetEventStatus),
    set: CommandFunction(raw.PFN_vkSetEvent),
    reset: CommandFunction(raw.PFN_vkResetEvent),
};

pub fn createEvent(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: EventDispatch,
) core.Error!Event {
    const info: raw.VkEventCreateInfo = .{ .sType = raw.VK_STRUCTURE_TYPE_EVENT_CREATE_INFO };
    var handle: raw.VkEvent = null;
    const result = dispatch.create(device_handle, &info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccess(result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._owner = try .init(&handle),
        ._device_handle = device_handle,
        .allocation_callbacks = allocation_callbacks,
        .dispatch = dispatch,
    };
}

pub const Event = struct {
    _handle: ?EventHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: EventDispatch,

    pub fn deinit(event: *Event) void {
        if (!(event._owner.release(event) catch return)) return;
        const handle = event._handle orelse return;
        event.dispatch.destroy(event._device_handle, handle, event.allocation_callbacks);
        event._handle = null;
    }

    pub fn rawHandle(event: *const Event) core.Error!raw.VkEvent {
        try event._owner.validate(event);
        if (event._device_state) |*state| try state.ensureDispatchAllowed();
        return event._handle orelse error.InactiveObject;
    }

    pub fn status(event: *const Event) core.Error!EventStatus {
        const result = event.dispatch.status(event._device_handle, try event.rawHandle());
        if (result == raw.VK_EVENT_SET) return .set;
        if (result == raw.VK_EVENT_RESET) return .reset;
        try core.checkSuccess(result);
        unreachable;
    }

    pub fn set(event: *const Event) core.Error!void {
        try core.checkSuccess(event.dispatch.set(event._device_handle, try event.rawHandle()));
    }

    pub fn reset(event: *const Event) core.Error!void {
        try core.checkSuccess(event.dispatch.reset(event._device_handle, try event.rawHandle()));
    }

    pub fn debugObject(event: *const Event) core.Error!debug_utils.Object {
        return .forDevice(.event, try event.rawHandle(), event._device_handle);
    }
};

pub const SemaphoreKind = enum {
    binary,
    timeline,
};

pub const SemaphoreOptions = struct {
    kind: SemaphoreKind = .binary,
    initial_value: u64 = 0,
};

pub const TimelineWaitStatus = enum {
    success,
    timeout,
};

pub const Semaphore = struct {
    _handle: ?SemaphoreHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    kind: SemaphoreKind,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_semaphore: CommandFunction(raw.PFN_vkDestroySemaphore),
    get_counter_value: ?CommandFunction(raw.PFN_vkGetSemaphoreCounterValue),
    wait_semaphores: ?CommandFunction(raw.PFN_vkWaitSemaphores),
    signal_semaphore: ?CommandFunction(raw.PFN_vkSignalSemaphore),

    pub fn deinit(semaphore: *Semaphore) void {
        if (!(semaphore._owner.release(semaphore) catch return)) return;
        const handle = semaphore._handle orelse return;
        semaphore.destroy_semaphore(
            semaphore._device_handle,
            handle,
            semaphore.allocation_callbacks,
        );
        semaphore._handle = null;
    }

    pub fn rawHandle(semaphore: *const Semaphore) core.Error!raw.VkSemaphore {
        try semaphore._owner.validate(semaphore);
        if (semaphore._device_state) |*state| try state.ensureDispatchAllowed();
        return semaphore._handle orelse error.InactiveObject;
    }

    pub fn debugObject(semaphore: *const Semaphore) core.Error!debug_utils.Object {
        return .forDevice(.semaphore, try semaphore.rawHandle(), semaphore._device_handle);
    }

    pub fn counterValue(semaphore: *const Semaphore) core.Error!u64 {
        if (semaphore.kind != .timeline) return error.InvalidOptions;
        const handle = (try semaphore.rawHandle()) orelse return error.InvalidHandle;
        const get_counter_value = semaphore.get_counter_value orelse return error.MissingCommand;
        var value: u64 = 0;
        try core.checkSuccess(get_counter_value(semaphore._device_handle, handle, &value));
        return value;
    }

    pub fn signal(semaphore: *const Semaphore, value: u64) core.Error!void {
        if (value <= try semaphore.counterValue()) return error.InvalidOptions;
        const signal_semaphore = semaphore.signal_semaphore orelse return error.MissingCommand;
        const signal_info: raw.VkSemaphoreSignalInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_SEMAPHORE_SIGNAL_INFO,
            .semaphore = try semaphore.rawHandle(),
            .value = value,
        };
        try core.checkSuccess(signal_semaphore(semaphore._device_handle, &signal_info));
    }

    pub fn wait(
        semaphore: *const Semaphore,
        value: u64,
        timeout: core.Timeout,
    ) core.Error!TimelineWaitStatus {
        if (semaphore.kind != .timeline) return error.InvalidOptions;
        const handle = (try semaphore.rawHandle()) orelse return error.InvalidHandle;
        const wait_semaphores = semaphore.wait_semaphores orelse return error.MissingCommand;
        const wait_info: raw.VkSemaphoreWaitInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_SEMAPHORE_WAIT_INFO,
            .semaphoreCount = 1,
            .pSemaphores = @ptrCast(&handle),
            .pValues = @ptrCast(&value),
        };
        const result = wait_semaphores(
            semaphore._device_handle,
            &wait_info,
            timeout.toRaw(),
        );
        if (result == raw.VK_SUCCESS) return .success;
        if (result == raw.VK_TIMEOUT) return .timeout;
        try core.checkSuccess(result);
        unreachable;
    }
};

pub const FenceOptions = struct {
    signaled: bool = false,
};

pub const FenceWaitStatus = enum {
    success,
    timeout,
};

pub const FenceStatus = enum {
    signaled,
    unsignaled,
};

pub const WaitMode = enum {
    all,
    any,
};

pub const TimelineSemaphoreWait = struct {
    semaphore: *const Semaphore,
    value: u64,
};

pub const Fence = struct {
    _handle: ?FenceHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_fence: CommandFunction(raw.PFN_vkDestroyFence),
    get_fence_status: CommandFunction(raw.PFN_vkGetFenceStatus),
    reset_fences: CommandFunction(raw.PFN_vkResetFences),
    wait_for_fences: CommandFunction(raw.PFN_vkWaitForFences),

    pub fn deinit(fence: *Fence) void {
        if (!(fence._owner.release(fence) catch return)) return;
        const handle = fence._handle orelse return;
        fence.destroy_fence(fence._device_handle, handle, fence.allocation_callbacks);
        fence._handle = null;
    }

    pub fn reset(fence: *const Fence) core.Error!void {
        const handle = (try fence.rawHandle()) orelse return error.InvalidHandle;
        try core.checkSuccess(fence.reset_fences(fence._device_handle, 1, @ptrCast(&handle)));
    }

    pub fn status(fence: *const Fence) core.Error!FenceStatus {
        const handle = (try fence.rawHandle()) orelse return error.InvalidHandle;
        const result = fence.get_fence_status(fence._device_handle, handle);
        if (result == raw.VK_SUCCESS) return .signaled;
        if (result == raw.VK_NOT_READY) return .unsignaled;
        try core.checkSuccess(result);
        unreachable;
    }

    pub fn wait(fence: *const Fence, timeout: core.Timeout) core.Error!FenceWaitStatus {
        const handle = (try fence.rawHandle()) orelse return error.InvalidHandle;
        const result = fence.wait_for_fences(
            fence._device_handle,
            1,
            @ptrCast(&handle),
            raw.VK_TRUE,
            timeout.toRaw(),
        );
        if (result == raw.VK_SUCCESS) return .success;
        if (result == raw.VK_TIMEOUT) return .timeout;
        try core.checkSuccess(result);
        unreachable;
    }

    pub fn rawHandle(fence: *const Fence) core.Error!raw.VkFence {
        try fence._owner.validate(fence);
        if (fence._device_state) |*state| try state.ensureDispatchAllowed();
        return fence._handle orelse error.InactiveObject;
    }

    pub fn debugObject(fence: *const Fence) core.Error!debug_utils.Object {
        return .forDevice(.fence, try fence.rawHandle(), fence._device_handle);
    }
};
