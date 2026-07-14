const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const SemaphoreHandle = core.NonNullHandle(raw.VkSemaphore);
const FenceHandle = core.NonNullHandle(raw.VkFence);

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
    _device_handle: DeviceHandle,
    kind: SemaphoreKind,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_semaphore: CommandFunction(raw.PFN_vkDestroySemaphore),
    get_counter_value: ?CommandFunction(raw.PFN_vkGetSemaphoreCounterValue),
    wait_semaphores: ?CommandFunction(raw.PFN_vkWaitSemaphores),
    signal_semaphore: ?CommandFunction(raw.PFN_vkSignalSemaphore),

    pub fn deinit(semaphore: *Semaphore) void {
        const handle = semaphore._handle orelse return;
        semaphore.destroy_semaphore(
            semaphore._device_handle,
            handle,
            semaphore.allocation_callbacks,
        );
        semaphore._handle = null;
    }

    pub fn rawHandle(semaphore: *const Semaphore) core.Error!raw.VkSemaphore {
        return semaphore._handle orelse error.InactiveObject;
    }

    pub fn debugObject(semaphore: *const Semaphore) core.Error!debug_utils.Object {
        return .forDevice(.semaphore, try semaphore.rawHandle(), semaphore._device_handle);
    }

    pub fn counterValue(semaphore: *const Semaphore) core.Error!u64 {
        if (semaphore.kind != .timeline) return error.InvalidOptions;
        const handle = semaphore._handle orelse return error.InactiveObject;
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
        const handle = semaphore._handle orelse return error.InactiveObject;
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
    _device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_fence: CommandFunction(raw.PFN_vkDestroyFence),
    get_fence_status: CommandFunction(raw.PFN_vkGetFenceStatus),
    reset_fences: CommandFunction(raw.PFN_vkResetFences),
    wait_for_fences: CommandFunction(raw.PFN_vkWaitForFences),

    pub fn deinit(fence: *Fence) void {
        const handle = fence._handle orelse return;
        fence.destroy_fence(fence._device_handle, handle, fence.allocation_callbacks);
        fence._handle = null;
    }

    pub fn reset(fence: *const Fence) core.Error!void {
        const handle = fence._handle orelse return error.InactiveObject;
        try core.checkSuccess(fence.reset_fences(fence._device_handle, 1, @ptrCast(&handle)));
    }

    pub fn status(fence: *const Fence) core.Error!FenceStatus {
        const handle = fence._handle orelse return error.InactiveObject;
        const result = fence.get_fence_status(fence._device_handle, handle);
        if (result == raw.VK_SUCCESS) return .signaled;
        if (result == raw.VK_NOT_READY) return .unsignaled;
        try core.checkSuccess(result);
        unreachable;
    }

    pub fn wait(fence: *const Fence, timeout: core.Timeout) core.Error!FenceWaitStatus {
        const handle = fence._handle orelse return error.InactiveObject;
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
        return fence._handle orelse error.InactiveObject;
    }

    pub fn debugObject(fence: *const Fence) core.Error!debug_utils.Object {
        return .forDevice(.fence, try fence.rawHandle(), fence._device_handle);
    }
};
