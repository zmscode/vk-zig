const raw = @import("vulkan_raw");
const types = @import("vulkan_types");

pub const MemoryHandleType = types.ExternalMemoryHandleTypeBit;
pub const MemoryHandleTypes = types.ExternalMemoryHandleTypeFlags;

pub const SemaphoreHandleType = enum(raw.VkExternalSemaphoreHandleTypeFlags) {
    opaque_fd = raw.VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_FD_BIT,
    opaque_win32 = raw.VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_BIT,
    opaque_win32_kmt = raw.VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT,
    d3d12_fence = raw.VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D12_FENCE_BIT,
    sync_fd = raw.VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_SYNC_FD_BIT,
    zircon_event = raw.VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_ZIRCON_EVENT_BIT_FUCHSIA,
    _,

    pub fn fromRaw(value: raw.VkExternalSemaphoreHandleTypeFlags) SemaphoreHandleType {
        return @enumFromInt(value);
    }

    pub fn toRaw(value: SemaphoreHandleType) raw.VkExternalSemaphoreHandleTypeFlags {
        return @intFromEnum(value);
    }
};

pub const SemaphoreHandleTypes = types.Flags(
    raw.VkExternalSemaphoreHandleTypeFlags,
    SemaphoreHandleType,
);

pub const FenceHandleType = enum(raw.VkExternalFenceHandleTypeFlags) {
    opaque_fd = raw.VK_EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_FD_BIT,
    opaque_win32 = raw.VK_EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_WIN32_BIT,
    opaque_win32_kmt = raw.VK_EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT,
    sync_fd = raw.VK_EXTERNAL_FENCE_HANDLE_TYPE_SYNC_FD_BIT,
    _,

    pub fn fromRaw(value: raw.VkExternalFenceHandleTypeFlags) FenceHandleType {
        return @enumFromInt(value);
    }

    pub fn toRaw(value: FenceHandleType) raw.VkExternalFenceHandleTypeFlags {
        return @intFromEnum(value);
    }
};

pub const FenceHandleTypes = types.Flags(
    raw.VkExternalFenceHandleTypeFlags,
    FenceHandleType,
);

/// A native POSIX file descriptor. Vulkan consumes imported descriptors only
/// when the import succeeds. Descriptors exported by Vulkan are owned by the
/// caller and must be closed by the caller.
pub const FileDescriptor = enum(c_int) {
    _,

    pub fn fromNative(value: c_int) FileDescriptor {
        return @enumFromInt(value);
    }

    pub fn native(descriptor: FileDescriptor) c_int {
        return @intFromEnum(descriptor);
    }
};

/// Whether an imported semaphore or fence payload temporarily replaces the
/// object's payload or permanently becomes its payload.
pub const ImportPermanence = enum {
    permanent,
    temporary,

    pub fn semaphoreFlags(value: ImportPermanence) raw.VkSemaphoreImportFlags {
        return if (value == .temporary) raw.VK_SEMAPHORE_IMPORT_TEMPORARY_BIT else 0;
    }

    pub fn fenceFlags(value: ImportPermanence) raw.VkFenceImportFlags {
        return if (value == .temporary) raw.VK_FENCE_IMPORT_TEMPORARY_BIT else 0;
    }
};

pub const MemoryImport = union(enum) {
    /// Consumed by Vulkan on successful allocation; retained by the caller on failure.
    file_descriptor: struct {
        handle_type: MemoryHandleType,
        descriptor: FileDescriptor,
    },
    /// The pointed-to allocation must remain valid for the Vulkan allocation lifetime.
    host_pointer: struct {
        handle_type: MemoryHandleType,
        pointer: *anyopaque,
    },
    /// The Metal object remains governed by the extension's retain/ownership rules.
    metal_handle: struct {
        handle_type: MemoryHandleType,
        handle: *anyopaque,
    },
    /// Win32 HANDLE imports are available only in Win32-targeted bindings.
    win32_handle: struct {
        handle_type: MemoryHandleType,
        handle: *anyopaque,
    },
    /// The Zircon VMO is consumed on successful allocation and retained on failure.
    zircon_vmo: struct {
        handle_type: MemoryHandleType,
        handle: u32,
    },
    /// The hardware buffer must remain valid according to Android's ownership rules.
    android_hardware_buffer: *anyopaque,
};

pub const MemoryExport = struct {
    handle_types: MemoryHandleTypes,
};

pub const ExternalMemoryAllocation = union(enum) {
    export_handles: MemoryExport,
    import_handle: MemoryImport,
};

pub const MemoryHandleProperties = struct {
    memory_type_bits: u32,
};

pub const ExternalSemaphoreProperties = struct {
    export_from_imported_handle_types: SemaphoreHandleTypes,
    compatible_handle_types: SemaphoreHandleTypes,
    exportable: bool,
    importable: bool,

    pub fn fromRaw(value: raw.VkExternalSemaphoreProperties) ExternalSemaphoreProperties {
        return .{
            .export_from_imported_handle_types = .fromRaw(value.exportFromImportedHandleTypes),
            .compatible_handle_types = .fromRaw(value.compatibleHandleTypes),
            .exportable = (value.externalSemaphoreFeatures & raw.VK_EXTERNAL_SEMAPHORE_FEATURE_EXPORTABLE_BIT) != 0,
            .importable = (value.externalSemaphoreFeatures & raw.VK_EXTERNAL_SEMAPHORE_FEATURE_IMPORTABLE_BIT) != 0,
        };
    }
};

pub const ExternalFenceProperties = struct {
    export_from_imported_handle_types: FenceHandleTypes,
    compatible_handle_types: FenceHandleTypes,
    exportable: bool,
    importable: bool,

    pub fn fromRaw(value: raw.VkExternalFenceProperties) ExternalFenceProperties {
        return .{
            .export_from_imported_handle_types = .fromRaw(value.exportFromImportedHandleTypes),
            .compatible_handle_types = .fromRaw(value.compatibleHandleTypes),
            .exportable = (value.externalFenceFeatures & raw.VK_EXTERNAL_FENCE_FEATURE_EXPORTABLE_BIT) != 0,
            .importable = (value.externalFenceFeatures & raw.VK_EXTERNAL_FENCE_FEATURE_IMPORTABLE_BIT) != 0,
        };
    }
};

test "external handle sets remain typed" {
    const semaphores = SemaphoreHandleTypes.init(&.{ .opaque_fd, .sync_fd });
    try @import("std").testing.expect(semaphores.contains(.opaque_fd));
    try @import("std").testing.expect(!semaphores.contains(.opaque_win32));

    const fences = FenceHandleTypes.init(&.{.opaque_fd});
    try @import("std").testing.expect(fences.contains(.opaque_fd));
}
