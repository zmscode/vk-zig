//! Typed external-memory and synchronization-handle interop.
//!
//! File descriptors returned by export methods belong to the caller. Vulkan
//! consumes descriptors passed to successful import methods; it does not
//! consume them when the import fails. Platform-specific methods return
//! `error.UnsupportedOperation` when their native ABI was not generated for
//! the current target.

const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const memory = @import("memory.zig");
const synchronization = @import("synchronization.zig");
const shared = @import("external_types.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);

pub const MemoryHandleType = shared.MemoryHandleType;
pub const MemoryHandleTypes = shared.MemoryHandleTypes;
pub const SemaphoreHandleType = shared.SemaphoreHandleType;
pub const SemaphoreHandleTypes = shared.SemaphoreHandleTypes;
pub const FenceHandleType = shared.FenceHandleType;
pub const FenceHandleTypes = shared.FenceHandleTypes;
pub const FileDescriptor = shared.FileDescriptor;
pub const ImportPermanence = shared.ImportPermanence;
pub const MemoryImport = shared.MemoryImport;
pub const MemoryExport = shared.MemoryExport;
pub const MemoryAllocation = shared.ExternalMemoryAllocation;
pub const MemoryHandleProperties = shared.MemoryHandleProperties;
pub const SemaphoreProperties = shared.ExternalSemaphoreProperties;
pub const FenceProperties = shared.ExternalFenceProperties;

pub const NativeHandle = *anyopaque;
pub const ZirconHandle = enum(u32) {
    _,

    pub fn fromNative(value: u32) ZirconHandle {
        return @enumFromInt(value);
    }

    pub fn native(value: ZirconHandle) u32 {
        return @intFromEnum(value);
    }
};

pub const AndroidHardwareBufferProperties = struct {
    allocation_size: core.DeviceSize,
    memory_type_bits: u32,
};

pub const Context = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _get_device_proc_addr: CommandFunction(raw.PFN_vkGetDeviceProcAddr),

    fn ensureAvailable(context: Context) core.Error!void {
        try context._state.ensureDispatchAllowed();
    }

    fn load(
        context: Context,
        comptime OptionalFunction: type,
        name: [:0]const u8,
    ) core.Error!CommandFunction(OptionalFunction) {
        try context.ensureAvailable();
        const procedure = context._get_device_proc_addr(context._device, name.ptr) orelse {
            return error.MissingCommand;
        };
        return @ptrCast(procedure);
    }

    /// Exports external memory as an fd. The returned fd is owned by the caller.
    pub fn exportMemoryFd(
        context: Context,
        allocation: *const memory.Allocation,
        handle_type: MemoryHandleType,
    ) core.Error!FileDescriptor {
        const get = try context.load(raw.PFN_vkGetMemoryFdKHR, "vkGetMemoryFdKHR");
        const info: raw.VkMemoryGetFdInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_MEMORY_GET_FD_INFO_KHR,
            .memory = try allocation.rawHandle(),
            .handleType = handle_type.toRaw(),
        };
        var descriptor: c_int = -1;
        try core.checkSuccessOptional(context._state, get(context._device, &info, &descriptor));
        return .fromNative(descriptor);
    }

    /// Queries which memory types may import an fd. The fd remains caller-owned.
    pub fn memoryFdProperties(
        context: Context,
        handle_type: MemoryHandleType,
        descriptor: FileDescriptor,
    ) core.Error!MemoryHandleProperties {
        const get = try context.load(raw.PFN_vkGetMemoryFdPropertiesKHR, "vkGetMemoryFdPropertiesKHR");
        var properties: raw.VkMemoryFdPropertiesKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_MEMORY_FD_PROPERTIES_KHR,
        };
        try core.checkSuccessOptional(context._state, get(
            context._device,
            handle_type.toRaw(),
            descriptor.native(),
            &properties,
        ));
        return .{ .memory_type_bits = properties.memoryTypeBits };
    }

    /// Imports an fd payload. Vulkan consumes the fd only when this succeeds.
    pub fn importSemaphoreFd(
        context: Context,
        semaphore: *const synchronization.Semaphore,
        handle_type: SemaphoreHandleType,
        descriptor: FileDescriptor,
        permanence: ImportPermanence,
    ) core.Error!void {
        const import = try context.load(raw.PFN_vkImportSemaphoreFdKHR, "vkImportSemaphoreFdKHR");
        const info: raw.VkImportSemaphoreFdInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_IMPORT_SEMAPHORE_FD_INFO_KHR,
            .semaphore = try semaphore.rawHandle(),
            .flags = permanence.semaphoreFlags(),
            .handleType = handle_type.toRaw(),
            .fd = descriptor.native(),
        };
        try core.checkSuccessOptional(context._state, import(context._device, &info));
    }

    /// Exports a semaphore payload as an fd owned by the caller.
    pub fn exportSemaphoreFd(
        context: Context,
        semaphore: *const synchronization.Semaphore,
        handle_type: SemaphoreHandleType,
    ) core.Error!FileDescriptor {
        const get = try context.load(raw.PFN_vkGetSemaphoreFdKHR, "vkGetSemaphoreFdKHR");
        const info: raw.VkSemaphoreGetFdInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_SEMAPHORE_GET_FD_INFO_KHR,
            .semaphore = try semaphore.rawHandle(),
            .handleType = handle_type.toRaw(),
        };
        var descriptor: c_int = -1;
        try core.checkSuccessOptional(context._state, get(context._device, &info, &descriptor));
        return .fromNative(descriptor);
    }

    /// Imports an fd payload. Vulkan consumes the fd only when this succeeds.
    pub fn importFenceFd(
        context: Context,
        fence: *const synchronization.Fence,
        handle_type: FenceHandleType,
        descriptor: FileDescriptor,
        permanence: ImportPermanence,
    ) core.Error!void {
        const import = try context.load(raw.PFN_vkImportFenceFdKHR, "vkImportFenceFdKHR");
        const info: raw.VkImportFenceFdInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_IMPORT_FENCE_FD_INFO_KHR,
            .fence = try fence.rawHandle(),
            .flags = permanence.fenceFlags(),
            .handleType = handle_type.toRaw(),
            .fd = descriptor.native(),
        };
        try core.checkSuccessOptional(context._state, import(context._device, &info));
    }

    /// Exports a fence payload as an fd owned by the caller.
    pub fn exportFenceFd(
        context: Context,
        fence: *const synchronization.Fence,
        handle_type: FenceHandleType,
    ) core.Error!FileDescriptor {
        const get = try context.load(raw.PFN_vkGetFenceFdKHR, "vkGetFenceFdKHR");
        const info: raw.VkFenceGetFdInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_FENCE_GET_FD_INFO_KHR,
            .fence = try fence.rawHandle(),
            .handleType = handle_type.toRaw(),
        };
        var descriptor: c_int = -1;
        try core.checkSuccessOptional(context._state, get(context._device, &info, &descriptor));
        return .fromNative(descriptor);
    }

    /// Queries the memory types compatible with a host pointer.
    pub fn hostPointerProperties(
        context: Context,
        handle_type: MemoryHandleType,
        pointer: *const anyopaque,
    ) core.Error!MemoryHandleProperties {
        const get = try context.load(
            raw.PFN_vkGetMemoryHostPointerPropertiesEXT,
            "vkGetMemoryHostPointerPropertiesEXT",
        );
        var properties: raw.VkMemoryHostPointerPropertiesEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_MEMORY_HOST_POINTER_PROPERTIES_EXT,
        };
        try core.checkSuccessOptional(context._state, get(
            context._device,
            handle_type.toRaw(),
            pointer,
            &properties,
        ));
        return .{ .memory_type_bits = properties.memoryTypeBits };
    }

    /// Exports a Metal object. Its retain semantics are defined by
    /// VK_EXT_external_memory_metal and the selected handle type.
    pub fn exportMemoryMetalHandle(
        context: Context,
        allocation: *const memory.Allocation,
        handle_type: MemoryHandleType,
    ) core.Error!NativeHandle {
        const get = try context.load(raw.PFN_vkGetMemoryMetalHandleEXT, "vkGetMemoryMetalHandleEXT");
        const info: raw.VkMemoryGetMetalHandleInfoEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_MEMORY_GET_METAL_HANDLE_INFO_EXT,
            .memory = try allocation.rawHandle(),
            .handleType = handle_type.toRaw(),
        };
        var handle: ?*anyopaque = null;
        try core.checkSuccessOptional(context._state, get(context._device, &info, &handle));
        return handle orelse error.InvalidExternalHandle;
    }

    pub fn memoryMetalHandleProperties(
        context: Context,
        handle_type: MemoryHandleType,
        handle: NativeHandle,
    ) core.Error!MemoryHandleProperties {
        const get = try context.load(
            raw.PFN_vkGetMemoryMetalHandlePropertiesEXT,
            "vkGetMemoryMetalHandlePropertiesEXT",
        );
        var properties: raw.VkMemoryMetalHandlePropertiesEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_MEMORY_METAL_HANDLE_PROPERTIES_EXT,
        };
        try core.checkSuccessOptional(context._state, get(
            context._device,
            handle_type.toRaw(),
            handle,
            &properties,
        ));
        return .{ .memory_type_bits = properties.memoryTypeBits };
    }

    /// Platform-sensitive Win32 memory export. On non-Win32 targets this
    /// returns `error.UnsupportedOperation` without attempting dispatch.
    pub fn exportMemoryWin32Handle(
        context: Context,
        allocation: *const memory.Allocation,
        handle_type: MemoryHandleType,
    ) core.Error!NativeHandle {
        if (comptime @hasDecl(raw, "PFN_vkGetMemoryWin32HandleKHR")) {
            const Pfn = @field(raw, "PFN_vkGetMemoryWin32HandleKHR");
            const Info = @field(raw, "VkMemoryGetWin32HandleInfoKHR");
            const get = try context.load(Pfn, "vkGetMemoryWin32HandleKHR");
            const info: Info = .{
                .sType = raw.VK_STRUCTURE_TYPE_MEMORY_GET_WIN32_HANDLE_INFO_KHR,
                .memory = try allocation.rawHandle(),
                .handleType = handle_type.toRaw(),
            };
            var handle: ?*anyopaque = null;
            try core.checkSuccessOptional(context._state, get(context._device, &info, @ptrCast(&handle)));
            return handle orelse error.InvalidExternalHandle;
        }
        return error.UnsupportedOperation;
    }

    /// Queries compatible memory types for a Win32 handle. Ownership remains
    /// with the caller.
    pub fn memoryWin32HandleProperties(
        context: Context,
        handle_type: MemoryHandleType,
        handle: NativeHandle,
    ) core.Error!MemoryHandleProperties {
        if (comptime @hasDecl(raw, "PFN_vkGetMemoryWin32HandlePropertiesKHR")) {
            const Pfn = @field(raw, "PFN_vkGetMemoryWin32HandlePropertiesKHR");
            const Properties = @field(raw, "VkMemoryWin32HandlePropertiesKHR");
            const get = try context.load(Pfn, "vkGetMemoryWin32HandlePropertiesKHR");
            var properties: Properties = .{
                .sType = raw.VK_STRUCTURE_TYPE_MEMORY_WIN32_HANDLE_PROPERTIES_KHR,
            };
            try core.checkSuccessOptional(context._state, get(
                context._device,
                handle_type.toRaw(),
                @ptrCast(handle),
                &properties,
            ));
            return .{ .memory_type_bits = properties.memoryTypeBits };
        }
        return error.UnsupportedOperation;
    }

    /// Imports a Win32 semaphore handle. Vulkan does not take ownership of
    /// opaque Win32 handles; the caller may close them after this call returns.
    pub fn importSemaphoreWin32Handle(
        context: Context,
        semaphore: *const synchronization.Semaphore,
        handle_type: SemaphoreHandleType,
        handle: NativeHandle,
        permanence: ImportPermanence,
    ) core.Error!void {
        if (comptime @hasDecl(raw, "PFN_vkImportSemaphoreWin32HandleKHR")) {
            const Pfn = @field(raw, "PFN_vkImportSemaphoreWin32HandleKHR");
            const Info = @field(raw, "VkImportSemaphoreWin32HandleInfoKHR");
            const import = try context.load(Pfn, "vkImportSemaphoreWin32HandleKHR");
            const info: Info = .{
                .sType = raw.VK_STRUCTURE_TYPE_IMPORT_SEMAPHORE_WIN32_HANDLE_INFO_KHR,
                .semaphore = try semaphore.rawHandle(),
                .flags = permanence.semaphoreFlags(),
                .handleType = handle_type.toRaw(),
                .handle = @ptrCast(handle),
            };
            try core.checkSuccessOptional(context._state, import(context._device, &info));
            return;
        }
        return error.UnsupportedOperation;
    }

    /// Exports a Win32 semaphore handle. The caller closes opaque handles;
    /// KMT handles are shared references and must not be closed.
    pub fn exportSemaphoreWin32Handle(
        context: Context,
        semaphore: *const synchronization.Semaphore,
        handle_type: SemaphoreHandleType,
    ) core.Error!NativeHandle {
        if (comptime @hasDecl(raw, "PFN_vkGetSemaphoreWin32HandleKHR")) {
            const Pfn = @field(raw, "PFN_vkGetSemaphoreWin32HandleKHR");
            const Info = @field(raw, "VkSemaphoreGetWin32HandleInfoKHR");
            const Handle = @field(raw, "HANDLE");
            const get = try context.load(Pfn, "vkGetSemaphoreWin32HandleKHR");
            const info: Info = .{
                .sType = raw.VK_STRUCTURE_TYPE_SEMAPHORE_GET_WIN32_HANDLE_INFO_KHR,
                .semaphore = try semaphore.rawHandle(),
                .handleType = handle_type.toRaw(),
            };
            var handle: Handle = null;
            try core.checkSuccessOptional(context._state, get(context._device, &info, &handle));
            return @ptrCast(handle orelse return error.InvalidExternalHandle);
        }
        return error.UnsupportedOperation;
    }

    /// Imports a Win32 fence handle without transferring caller ownership.
    pub fn importFenceWin32Handle(
        context: Context,
        fence: *const synchronization.Fence,
        handle_type: FenceHandleType,
        handle: NativeHandle,
        permanence: ImportPermanence,
    ) core.Error!void {
        if (comptime @hasDecl(raw, "PFN_vkImportFenceWin32HandleKHR")) {
            const Pfn = @field(raw, "PFN_vkImportFenceWin32HandleKHR");
            const Info = @field(raw, "VkImportFenceWin32HandleInfoKHR");
            const import = try context.load(Pfn, "vkImportFenceWin32HandleKHR");
            const info: Info = .{
                .sType = raw.VK_STRUCTURE_TYPE_IMPORT_FENCE_WIN32_HANDLE_INFO_KHR,
                .fence = try fence.rawHandle(),
                .flags = permanence.fenceFlags(),
                .handleType = handle_type.toRaw(),
                .handle = @ptrCast(handle),
            };
            try core.checkSuccessOptional(context._state, import(context._device, &info));
            return;
        }
        return error.UnsupportedOperation;
    }

    /// Exports a Win32 fence handle. The caller closes opaque handles; KMT
    /// handles must not be closed.
    pub fn exportFenceWin32Handle(
        context: Context,
        fence: *const synchronization.Fence,
        handle_type: FenceHandleType,
    ) core.Error!NativeHandle {
        if (comptime @hasDecl(raw, "PFN_vkGetFenceWin32HandleKHR")) {
            const Pfn = @field(raw, "PFN_vkGetFenceWin32HandleKHR");
            const Info = @field(raw, "VkFenceGetWin32HandleInfoKHR");
            const Handle = @field(raw, "HANDLE");
            const get = try context.load(Pfn, "vkGetFenceWin32HandleKHR");
            const info: Info = .{
                .sType = raw.VK_STRUCTURE_TYPE_FENCE_GET_WIN32_HANDLE_INFO_KHR,
                .fence = try fence.rawHandle(),
                .handleType = handle_type.toRaw(),
            };
            var handle: Handle = null;
            try core.checkSuccessOptional(context._state, get(context._device, &info, &handle));
            return @ptrCast(handle orelse return error.InvalidExternalHandle);
        }
        return error.UnsupportedOperation;
    }

    /// Platform-sensitive Zircon memory export.
    pub fn exportMemoryZirconHandle(
        context: Context,
        allocation: *const memory.Allocation,
        handle_type: MemoryHandleType,
    ) core.Error!ZirconHandle {
        if (comptime @hasDecl(raw, "PFN_vkGetMemoryZirconHandleFUCHSIA")) {
            const Pfn = @field(raw, "PFN_vkGetMemoryZirconHandleFUCHSIA");
            const Info = @field(raw, "VkMemoryGetZirconHandleInfoFUCHSIA");
            const get = try context.load(Pfn, "vkGetMemoryZirconHandleFUCHSIA");
            const info: Info = .{
                .sType = raw.VK_STRUCTURE_TYPE_MEMORY_GET_ZIRCON_HANDLE_INFO_FUCHSIA,
                .memory = try allocation.rawHandle(),
                .handleType = handle_type.toRaw(),
            };
            var handle: u32 = 0;
            try core.checkSuccessOptional(context._state, get(context._device, &info, &handle));
            return .fromNative(handle);
        }
        return error.UnsupportedOperation;
    }

    /// Queries compatible memory types without consuming the Zircon handle.
    pub fn memoryZirconHandleProperties(
        context: Context,
        handle_type: MemoryHandleType,
        handle: ZirconHandle,
    ) core.Error!MemoryHandleProperties {
        if (comptime @hasDecl(raw, "PFN_vkGetMemoryZirconHandlePropertiesFUCHSIA")) {
            const Pfn = @field(raw, "PFN_vkGetMemoryZirconHandlePropertiesFUCHSIA");
            const Properties = @field(raw, "VkMemoryZirconHandlePropertiesFUCHSIA");
            const get = try context.load(Pfn, "vkGetMemoryZirconHandlePropertiesFUCHSIA");
            var properties: Properties = .{
                .sType = raw.VK_STRUCTURE_TYPE_MEMORY_ZIRCON_HANDLE_PROPERTIES_FUCHSIA,
            };
            try core.checkSuccessOptional(context._state, get(
                context._device,
                handle_type.toRaw(),
                handle.native(),
                &properties,
            ));
            return .{ .memory_type_bits = properties.memoryTypeBits };
        }
        return error.UnsupportedOperation;
    }

    /// Imports a Zircon semaphore handle. Vulkan consumes the handle only on
    /// success.
    pub fn importSemaphoreZirconHandle(
        context: Context,
        semaphore: *const synchronization.Semaphore,
        handle: ZirconHandle,
        permanence: ImportPermanence,
    ) core.Error!void {
        if (comptime @hasDecl(raw, "PFN_vkImportSemaphoreZirconHandleFUCHSIA")) {
            const Pfn = @field(raw, "PFN_vkImportSemaphoreZirconHandleFUCHSIA");
            const Info = @field(raw, "VkImportSemaphoreZirconHandleInfoFUCHSIA");
            const import = try context.load(Pfn, "vkImportSemaphoreZirconHandleFUCHSIA");
            const info: Info = .{
                .sType = raw.VK_STRUCTURE_TYPE_IMPORT_SEMAPHORE_ZIRCON_HANDLE_INFO_FUCHSIA,
                .semaphore = try semaphore.rawHandle(),
                .flags = permanence.semaphoreFlags(),
                .handleType = SemaphoreHandleType.zircon_event.toRaw(),
                .zirconHandle = handle.native(),
            };
            try core.checkSuccessOptional(context._state, import(context._device, &info));
            return;
        }
        return error.UnsupportedOperation;
    }

    /// Exports a Zircon semaphore handle owned by the caller.
    pub fn exportSemaphoreZirconHandle(
        context: Context,
        semaphore: *const synchronization.Semaphore,
    ) core.Error!ZirconHandle {
        if (comptime @hasDecl(raw, "PFN_vkGetSemaphoreZirconHandleFUCHSIA")) {
            const Pfn = @field(raw, "PFN_vkGetSemaphoreZirconHandleFUCHSIA");
            const Info = @field(raw, "VkSemaphoreGetZirconHandleInfoFUCHSIA");
            const get = try context.load(Pfn, "vkGetSemaphoreZirconHandleFUCHSIA");
            const info: Info = .{
                .sType = raw.VK_STRUCTURE_TYPE_SEMAPHORE_GET_ZIRCON_HANDLE_INFO_FUCHSIA,
                .semaphore = try semaphore.rawHandle(),
                .handleType = SemaphoreHandleType.zircon_event.toRaw(),
            };
            var handle: u32 = 0;
            try core.checkSuccessOptional(context._state, get(context._device, &info, &handle));
            return .fromNative(handle);
        }
        return error.UnsupportedOperation;
    }

    /// Queries Android hardware-buffer allocation size and compatible memory
    /// types. The buffer remains caller-owned.
    pub fn androidHardwareBufferProperties(
        context: Context,
        buffer: NativeHandle,
    ) core.Error!AndroidHardwareBufferProperties {
        if (comptime @hasDecl(raw, "PFN_vkGetAndroidHardwareBufferPropertiesANDROID")) {
            const Pfn = @field(raw, "PFN_vkGetAndroidHardwareBufferPropertiesANDROID");
            const Properties = @field(raw, "VkAndroidHardwareBufferPropertiesANDROID");
            const get = try context.load(Pfn, "vkGetAndroidHardwareBufferPropertiesANDROID");
            var properties: Properties = .{
                .sType = raw.VK_STRUCTURE_TYPE_ANDROID_HARDWARE_BUFFER_PROPERTIES_ANDROID,
            };
            try core.checkSuccessOptional(context._state, get(context._device, @ptrCast(buffer), &properties));
            return .{
                .allocation_size = .fromBytes(properties.allocationSize),
                .memory_type_bits = properties.memoryTypeBits,
            };
        }
        return error.UnsupportedOperation;
    }

    /// Exports an Android hardware buffer. The returned reference follows
    /// Android's AHardwareBuffer acquire/release ownership rules.
    pub fn exportMemoryAndroidHardwareBuffer(
        context: Context,
        allocation: *const memory.Allocation,
    ) core.Error!NativeHandle {
        if (comptime @hasDecl(raw, "PFN_vkGetMemoryAndroidHardwareBufferANDROID")) {
            const Pfn = @field(raw, "PFN_vkGetMemoryAndroidHardwareBufferANDROID");
            const Info = @field(raw, "VkMemoryGetAndroidHardwareBufferInfoANDROID");
            const Buffer = @field(raw, "AHardwareBuffer");
            const get = try context.load(Pfn, "vkGetMemoryAndroidHardwareBufferANDROID");
            const info: Info = .{
                .sType = raw.VK_STRUCTURE_TYPE_MEMORY_GET_ANDROID_HARDWARE_BUFFER_INFO_ANDROID,
                .memory = try allocation.rawHandle(),
            };
            var buffer: ?*Buffer = null;
            try core.checkSuccessOptional(context._state, get(context._device, &info, &buffer));
            return @ptrCast(buffer orelse return error.InvalidExternalHandle);
        }
        return error.UnsupportedOperation;
    }
};

test "native handle wrappers round trip" {
    const descriptor = FileDescriptor.fromNative(17);
    try @import("std").testing.expectEqual(@as(c_int, 17), descriptor.native());
    const zircon = ZirconHandle.fromNative(19);
    try @import("std").testing.expectEqual(@as(u32, 19), zircon.native());
}

test "target-enabled platform method bodies compile" {
    // These calls are runtime-unreachable on executed tests, but force semantic
    // analysis when the cross-target bindings expose the corresponding ABI.
    const execute = false;
    const context: Context = undefined;
    const allocation: *const memory.Allocation = undefined;
    const semaphore: *const synchronization.Semaphore = undefined;
    const fence: *const synchronization.Fence = undefined;
    const native: NativeHandle = @ptrFromInt(1);
    if (comptime @hasDecl(raw, "PFN_vkGetMemoryWin32HandleKHR")) {
        if (execute) {
            _ = try context.exportMemoryWin32Handle(allocation, .opaque_win32);
            _ = try context.memoryWin32HandleProperties(.opaque_win32, native);
            try context.importSemaphoreWin32Handle(semaphore, .opaque_win32, native, .permanent);
            _ = try context.exportSemaphoreWin32Handle(semaphore, .opaque_win32);
            try context.importFenceWin32Handle(fence, .opaque_win32, native, .permanent);
            _ = try context.exportFenceWin32Handle(fence, .opaque_win32);
        }
    }
    if (comptime @hasDecl(raw, "PFN_vkGetMemoryZirconHandleFUCHSIA")) {
        if (execute) {
            _ = try context.exportMemoryZirconHandle(allocation, .zircon_vmo_fuchsia);
            _ = try context.memoryZirconHandleProperties(.zircon_vmo_fuchsia, .fromNative(1));
            try context.importSemaphoreZirconHandle(semaphore, .fromNative(1), .permanent);
            _ = try context.exportSemaphoreZirconHandle(semaphore);
        }
    }
    if (comptime @hasDecl(raw, "PFN_vkGetAndroidHardwareBufferPropertiesANDROID")) {
        if (execute) {
            _ = try context.androidHardwareBufferProperties(native);
            _ = try context.exportMemoryAndroidHardwareBuffer(allocation);
        }
    }
}
