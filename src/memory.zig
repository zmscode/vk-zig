const std = @import("std");
const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const core = @import("core.zig");
const command = @import("vulkan_commands");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const MemoryHandle = core.NonNullHandle(raw.VkDeviceMemory);

pub const type_count_max: usize = raw.VK_MAX_MEMORY_TYPES;
pub const heap_count_max: usize = raw.VK_MAX_MEMORY_HEAPS;

pub const OpaqueCaptureAddress = enum(u64) {
    _,

    pub fn fromRaw(value: u64) ?OpaqueCaptureAddress {
        if (value == 0) return null;
        return @enumFromInt(value);
    }

    pub fn toRaw(address: OpaqueCaptureAddress) u64 {
        return @intFromEnum(address);
    }
};

pub const AllocationOptions = struct {
    size: core.DeviceSize,
    memory_type_index: core.MemoryTypeIndex,
    /// Physical-device `non_coherent_atom_size`; use 1 for coherent memory.
    non_coherent_atom_size: core.DeviceSize = .fromBytes(1),
    device_address: bool = false,
    opaque_capture_address: ?OpaqueCaptureAddress = null,
    /// EXT_memory_priority value in the inclusive 0...1 range.
    priority: ?f32 = null,
};

pub const Requirements = struct {
    size: core.DeviceSize,
    alignment: core.DeviceSize,
    memory_type_bits: u32,
    prefers_dedicated_allocation: bool = false,
    requires_dedicated_allocation: bool = false,

    pub fn fromRaw(value: raw.VkMemoryRequirements) Requirements {
        return .{
            .size = .fromBytes(value.size),
            .alignment = .fromBytes(value.alignment),
            .memory_type_bits = value.memoryTypeBits,
        };
    }

    pub fn supportsMemoryType(requirements: Requirements, index: core.MemoryTypeIndex) bool {
        if (index.toRaw() >= 32) return false;
        return (requirements.memory_type_bits & (@as(u32, 1) << @intCast(index.toRaw()))) != 0;
    }
};

pub const Preference = enum {
    device_local,
    upload,
    readback,
    transient,

    pub fn typeOptions(preference: Preference, type_bits: u32) TypeOptions {
        return switch (preference) {
            .device_local => .{
                .type_bits = type_bits,
                .required_flags = .init(&.{.device_local}),
            },
            .upload => .{
                .type_bits = type_bits,
                .required_flags = .init(&.{.host_visible}),
                .preferred_flags = .init(&.{ .host_coherent, .device_local }),
            },
            .readback => .{
                .type_bits = type_bits,
                .required_flags = .init(&.{.host_visible}),
                .preferred_flags = .init(&.{ .host_cached, .host_coherent }),
            },
            .transient => .{
                .type_bits = type_bits,
                .required_flags = .empty,
                .preferred_flags = .init(&.{ .lazily_allocated, .device_local }),
            },
        };
    }
};

pub const HeapBudget = struct {
    heap_index: core.MemoryHeapIndex,
    budget: core.DeviceSize,
    usage: core.DeviceSize,

    pub fn available(budget: HeapBudget) core.DeviceSize {
        return .fromBytes(budget.budget.bytes() -| budget.usage.bytes());
    }
};

pub const BudgetSnapshot = struct {
    _heaps: [heap_count_max]HeapBudget,
    count: u32,

    pub fn heaps(snapshot: *const BudgetSnapshot) []const HeapBudget {
        return snapshot._heaps[0..snapshot.count];
    }
};

pub const AllocationDispatch = struct {
    allocate: CommandFunction(raw.PFN_vkAllocateMemory),
    free: CommandFunction(raw.PFN_vkFreeMemory),
    map: CommandFunction(raw.PFN_vkMapMemory),
    unmap: CommandFunction(raw.PFN_vkUnmapMemory),
    map2: ?CommandFunction(raw.PFN_vkMapMemory2),
    unmap2: ?CommandFunction(raw.PFN_vkUnmapMemory2),
    flush: CommandFunction(raw.PFN_vkFlushMappedMemoryRanges),
    invalidate: CommandFunction(raw.PFN_vkInvalidateMappedMemoryRanges),
    get_commitment: CommandFunction(raw.PFN_vkGetDeviceMemoryCommitment),
    get_opaque_capture_address: ?CommandFunction(raw.PFN_vkGetDeviceMemoryOpaqueCaptureAddress),
};

pub const MapOptions = struct {
    offset: core.DeviceOffset = .zero,
    range: core.DeviceRange = .whole,
};

pub const Binding = struct {
    allocation: MemoryHandle,
    offset: core.DeviceOffset,
};

pub const Allocation = struct {
    _handle: ?MemoryHandle,
    _device_handle: DeviceHandle,
    size: core.DeviceSize,
    memory_type_index: core.MemoryTypeIndex,
    non_coherent_atom_size: core.DeviceSize,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: AllocationDispatch,
    _mapped: bool = false,
    _mapping_generation: u64 = 0,

    pub fn deinit(allocation: *Allocation) void {
        const handle = allocation._handle orelse return;
        if (allocation._mapped) allocation.unmapInternal(handle) catch {};
        allocation.dispatch.free(
            allocation._device_handle,
            handle,
            allocation.allocation_callbacks,
        );
        allocation._handle = null;
    }

    pub fn map(allocation: *Allocation, options: MapOptions) core.Error!MappedRange {
        const handle = allocation._handle orelse return error.InactiveObject;
        if (allocation._mapped) return error.InvalidOptions;
        const resolved = try allocation.resolveRange(options);
        var pointer: ?*anyopaque = null;
        if (allocation.dispatch.map2) |map2| {
            const info: raw.VkMemoryMapInfo = .{
                .sType = raw.VK_STRUCTURE_TYPE_MEMORY_MAP_INFO,
                .memory = handle,
                .offset = resolved.offset,
                .size = resolved.raw_size,
            };
            try core.checkSuccess(map2(allocation._device_handle, &info, &pointer));
        } else {
            try core.checkSuccess(allocation.dispatch.map(
                allocation._device_handle,
                handle,
                resolved.offset,
                resolved.raw_size,
                0,
                &pointer,
            ));
        }
        const mapped_pointer = pointer orelse return error.InvalidHandle;
        allocation._mapped = true;
        allocation._mapping_generation +%= 1;
        if (allocation._mapping_generation == 0) allocation._mapping_generation = 1;
        return .{
            ._allocation = allocation,
            ._generation = allocation._mapping_generation,
            ._pointer = @ptrCast(mapped_pointer),
            .offset = .fromBytes(resolved.offset),
            .size = .fromBytes(resolved.size),
        };
    }

    pub fn unmap(allocation: *Allocation) core.Error!void {
        const handle = allocation._handle orelse return error.InactiveObject;
        if (!allocation._mapped) return error.InvalidOptions;
        try allocation.unmapInternal(handle);
    }

    fn unmapInternal(allocation: *Allocation, handle: MemoryHandle) core.Error!void {
        if (allocation.dispatch.unmap2) |unmap2| {
            const info: raw.VkMemoryUnmapInfo = .{
                .sType = raw.VK_STRUCTURE_TYPE_MEMORY_UNMAP_INFO,
                .memory = handle,
            };
            try core.checkSuccess(unmap2(allocation._device_handle, &info));
        } else {
            allocation.dispatch.unmap(allocation._device_handle, handle);
        }
        allocation._mapped = false;
        allocation._mapping_generation +%= 1;
    }

    pub fn flush(allocation: *Allocation, options: MapOptions) core.Error!void {
        try allocation.cacheOperation(options, allocation.dispatch.flush);
    }

    pub fn invalidate(allocation: *Allocation, options: MapOptions) core.Error!void {
        try allocation.cacheOperation(options, allocation.dispatch.invalidate);
    }

    fn cacheOperation(
        allocation: *Allocation,
        options: MapOptions,
        operation: CommandFunction(raw.PFN_vkFlushMappedMemoryRanges),
    ) core.Error!void {
        const handle = allocation._handle orelse return error.InactiveObject;
        if (!allocation._mapped) return error.InvalidOptions;
        const normalized = try allocation.normalizedCacheRange(options);
        const range: raw.VkMappedMemoryRange = .{
            .sType = raw.VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
            .memory = handle,
            .offset = normalized.offset,
            .size = normalized.raw_size,
        };
        try core.checkSuccess(operation(allocation._device_handle, 1, &range));
    }

    pub fn committedBytes(allocation: *const Allocation) core.Error!core.DeviceSize {
        const handle = allocation._handle orelse return error.InactiveObject;
        var bytes: raw.VkDeviceSize = 0;
        allocation.dispatch.get_commitment(allocation._device_handle, handle, &bytes);
        if (bytes > allocation.size.bytes()) return error.InvalidProperties;
        return .fromBytes(bytes);
    }

    const ResolvedRange = struct {
        offset: u64,
        size: u64,
        raw_size: u64,
    };

    fn resolveRange(allocation: *const Allocation, options: MapOptions) core.Error!ResolvedRange {
        const allocation_size = allocation.size.bytes();
        const offset = options.offset.bytes();
        if (offset > allocation_size) return error.InvalidOptions;
        const size = switch (options.range) {
            .whole => allocation_size - offset,
            .bytes => |value| value.bytes(),
        };
        if (size == 0 or size > allocation_size - offset) return error.InvalidOptions;
        return .{
            .offset = offset,
            .size = size,
            .raw_size = switch (options.range) {
                .whole => raw.VK_WHOLE_SIZE,
                .bytes => size,
            },
        };
    }

    fn normalizedCacheRange(
        allocation: *const Allocation,
        options: MapOptions,
    ) core.Error!ResolvedRange {
        const resolved = try allocation.resolveRange(options);
        const atom = allocation.non_coherent_atom_size.bytes();
        if (atom == 0) return error.InvalidProperties;
        const start = resolved.offset - (resolved.offset % atom);
        const end_unaligned = std.math.add(u64, resolved.offset, resolved.size) catch return error.SizeOverflow;
        const remainder = end_unaligned % atom;
        const end = if (remainder == 0)
            end_unaligned
        else
            @min(allocation.size.bytes(), std.math.add(u64, end_unaligned, atom - remainder) catch return error.SizeOverflow);
        return .{
            .offset = start,
            .size = end - start,
            .raw_size = if (end == allocation.size.bytes()) raw.VK_WHOLE_SIZE else end - start,
        };
    }

    pub fn rawHandle(allocation: *const Allocation) core.Error!raw.VkDeviceMemory {
        return allocation._handle orelse error.InactiveObject;
    }

    pub fn opaqueCaptureAddress(
        allocation: *const Allocation,
    ) core.Error!?OpaqueCaptureAddress {
        const get_address = allocation.dispatch.get_opaque_capture_address orelse {
            return error.MissingCommand;
        };
        const info: raw.VkDeviceMemoryOpaqueCaptureAddressInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_DEVICE_MEMORY_OPAQUE_CAPTURE_ADDRESS_INFO,
            .memory = try allocation.rawHandle(),
        };
        return .fromRaw(get_address(allocation._device_handle, &info));
    }

    pub fn debugObject(allocation: *const Allocation) core.Error!debug_utils.Object {
        return .forDevice(.device_memory, try allocation.rawHandle(), allocation._device_handle);
    }
};

pub const MappedRange = struct {
    _allocation: *Allocation,
    _generation: u64,
    _pointer: [*]u8,
    offset: core.DeviceOffset,
    size: core.DeviceSize,

    pub fn bytes(mapped: *const MappedRange) core.Error![]u8 {
        _ = mapped._allocation._handle orelse return error.InactiveObject;
        if (!mapped._allocation._mapped or
            mapped._allocation._mapping_generation != mapped._generation)
        {
            return error.InactiveObject;
        }
        return mapped._pointer[0..mapped.size.bytes()];
    }

    pub fn flush(mapped: *const MappedRange) core.Error!void {
        try mapped.ensureActive();
        try mapped._allocation.flush(.{ .offset = mapped.offset, .range = .{ .bytes = mapped.size } });
    }

    pub fn invalidate(mapped: *const MappedRange) core.Error!void {
        try mapped.ensureActive();
        try mapped._allocation.invalidate(.{ .offset = mapped.offset, .range = .{ .bytes = mapped.size } });
    }

    pub fn unmap(mapped: *MappedRange) core.Error!void {
        try mapped.ensureActive();
        try mapped._allocation.unmap();
    }

    pub fn deinit(mapped: *MappedRange) void {
        mapped.unmap() catch {};
    }

    fn ensureActive(mapped: *const MappedRange) core.Error!void {
        _ = try mapped.bytes();
    }
};

pub fn allocate(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: AllocationDispatch,
    options: AllocationOptions,
) core.Error!Allocation {
    if (options.size.bytes() == 0 or options.memory_type_index.toRaw() >= type_count_max) {
        return error.InvalidOptions;
    }
    if (options.non_coherent_atom_size.bytes() == 0) return error.InvalidOptions;
    if (options.priority) |priority| {
        if (!std.math.isFinite(priority) or priority < 0 or priority > 1) return error.InvalidOptions;
    }
    var flags: raw.VkMemoryAllocateFlags = 0;
    if (options.device_address) flags |= raw.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;
    if (options.opaque_capture_address != null) {
        flags |= raw.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT;
    }
    var flags_info: raw.VkMemoryAllocateFlagsInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO,
        .flags = flags,
    };
    var capture_info: raw.VkMemoryOpaqueCaptureAddressAllocateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_MEMORY_OPAQUE_CAPTURE_ADDRESS_ALLOCATE_INFO,
        .opaqueCaptureAddress = if (options.opaque_capture_address) |address|
            address.toRaw()
        else
            0,
    };
    if (options.opaque_capture_address != null) flags_info.pNext = &capture_info;
    var priority_info: raw.VkMemoryPriorityAllocateInfoEXT = .{
        .sType = raw.VK_STRUCTURE_TYPE_MEMORY_PRIORITY_ALLOCATE_INFO_EXT,
        .priority = options.priority orelse 0.5,
    };
    if (options.priority != null) {
        priority_info.pNext = if (flags != 0) &flags_info else null;
    }
    const info: raw.VkMemoryAllocateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = if (options.priority != null) &priority_info else if (flags != 0) &flags_info else null,
        .allocationSize = options.size.bytes(),
        .memoryTypeIndex = options.memory_type_index.toRaw(),
    };
    var handle: raw.VkDeviceMemory = null;
    const result = dispatch.allocate(device_handle, &info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional_handle| {
            dispatch.free(device_handle, provisional_handle, allocation_callbacks);
        }
        try core.checkSuccess(result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._device_handle = device_handle,
        .size = options.size,
        .memory_type_index = options.memory_type_index,
        .non_coherent_atom_size = options.non_coherent_atom_size,
        .allocation_callbacks = allocation_callbacks,
        .dispatch = dispatch,
    };
}

pub const TypeOptions = struct {
    type_bits: u32,
    required_flags: types.MemoryPropertyFlags,
    preferred_flags: types.MemoryPropertyFlags = .empty,
};

pub const Type = struct {
    index: core.MemoryTypeIndex,
    heap_index: core.MemoryHeapIndex,
    flags: types.MemoryPropertyFlags,

    pub fn supports(memory_type: Type, required_flags: types.MemoryPropertyFlags) bool {
        return memory_type.flags.containsAll(required_flags);
    }
};

pub const Heap = struct {
    index: core.MemoryHeapIndex,
    size_bytes: u64,
    flags: types.MemoryHeapFlags,

    pub fn isDeviceLocal(heap: Heap) bool {
        return heap.flags.contains(.device_local);
    }
};

/// An owned typed snapshot of a physical device's bounded memory properties.
/// Slices returned by `types` and `heaps` borrow from this value.
pub const Properties = struct {
    _memory_types: [type_count_max]Type,
    _memory_heaps: [heap_count_max]Heap,
    _memory_type_count: u32,
    _memory_heap_count: u32,

    pub fn fromRaw(raw_properties: *const raw.VkPhysicalDeviceMemoryProperties) core.Error!Properties {
        var properties: Properties = undefined;
        try properties.initFromRaw(raw_properties);
        return properties;
    }

    pub fn initFromRaw(
        properties: *Properties,
        raw_properties: *const raw.VkPhysicalDeviceMemoryProperties,
    ) core.Error!void {
        if (raw_properties.memoryTypeCount > type_count_max) return error.InvalidProperties;
        if (raw_properties.memoryHeapCount > heap_count_max) return error.InvalidProperties;

        properties._memory_type_count = raw_properties.memoryTypeCount;
        properties._memory_heap_count = raw_properties.memoryHeapCount;
        for (
            raw_properties.memoryHeaps[0..raw_properties.memoryHeapCount],
            properties._memory_heaps[0..raw_properties.memoryHeapCount],
            0..,
        ) |raw_heap, *memory_heap, index| {
            memory_heap.* = .{
                .index = .fromRaw(@intCast(index)),
                .size_bytes = raw_heap.size,
                .flags = .fromRaw(raw_heap.flags),
            };
        }
        for (
            raw_properties.memoryTypes[0..raw_properties.memoryTypeCount],
            properties._memory_types[0..raw_properties.memoryTypeCount],
            0..,
        ) |raw_type, *memory_type, index| {
            if (raw_type.heapIndex >= raw_properties.memoryHeapCount) {
                return error.InvalidProperties;
            }
            memory_type.* = .{
                .index = .fromRaw(@intCast(index)),
                .heap_index = .fromRaw(raw_type.heapIndex),
                .flags = .fromRaw(raw_type.propertyFlags),
            };
        }
    }

    pub fn types(properties: *const Properties) []const Type {
        return properties._memory_types[0..properties._memory_type_count];
    }

    pub fn heaps(properties: *const Properties) []const Heap {
        return properties._memory_heaps[0..properties._memory_heap_count];
    }

    pub fn heap(properties: *const Properties, index: core.MemoryHeapIndex) ?*const Heap {
        const offset: usize = index.toRaw();
        if (offset >= properties._memory_heap_count) return null;
        return &properties._memory_heaps[offset];
    }

    pub fn deviceLocalBytes(properties: *const Properties) core.Error!u64 {
        var size_bytes_total: u64 = 0;
        for (properties.heaps()) |memory_heap| {
            if (!memory_heap.isDeviceLocal()) continue;
            size_bytes_total = std.math.add(u64, size_bytes_total, memory_heap.size_bytes) catch {
                return error.SizeOverflow;
            };
        }
        return size_bytes_total;
    }

    pub fn findType(
        properties: *const Properties,
        options: TypeOptions,
    ) core.Error!core.MemoryTypeIndex {
        var best_index: ?core.MemoryTypeIndex = null;
        var best_score: u32 = 0;
        for (properties.types()) |memory_type| {
            const index_u32 = memory_type.index.toRaw();
            const type_bit = @as(u32, 1) << @intCast(index_u32);
            if ((options.type_bits & type_bit) == 0) continue;
            if (!memory_type.supports(options.required_flags)) continue;

            const score: u32 = @intCast(@popCount(
                memory_type.flags.toRaw() & options.preferred_flags.toRaw(),
            ));
            if (best_index == null or score > best_score) {
                best_index = memory_type.index;
                best_score = score;
            }
        }
        return best_index orelse error.MemoryTypeNotFound;
    }
};

pub fn selectTypeIndex(
    properties: *const Properties,
    options: TypeOptions,
) core.Error!core.MemoryTypeIndex {
    return properties.findType(options);
}

pub fn selectTypeIndexRaw(
    raw_properties: *const raw.VkPhysicalDeviceMemoryProperties,
    options: TypeOptions,
) core.Error!core.MemoryTypeIndex {
    const properties = try Properties.fromRaw(raw_properties);
    return properties.findType(options);
}

test "all memory declarations compile" {
    std.testing.refAllDecls(@This());
}
