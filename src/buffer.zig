const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");
const memory = @import("memory.zig");
const device_group = @import("device_group.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const BufferHandle = core.NonNullHandle(raw.VkBuffer);
const BufferViewHandle = core.NonNullHandle(raw.VkBufferView);
const queue_family_count_max = 64;

pub const UsageBit = types.BufferUsageBit;
pub const UsageFlags = types.BufferUsageFlags;
pub const CreateBit = types.BufferCreateBit;
pub const CreateFlags = types.BufferCreateFlags;

pub const Size = core.DeviceSize;
pub const Offset = core.DeviceOffset;
pub const Range = core.DeviceRange;

pub const DeviceAddress = enum(u64) {
    _,

    pub fn fromRaw(value: raw.VkDeviceAddress) ?DeviceAddress {
        if (value == 0) return null;
        return @enumFromInt(value);
    }

    pub fn toRaw(address: DeviceAddress) raw.VkDeviceAddress {
        return @intFromEnum(address);
    }
};

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

pub const Options = struct {
    size: Size,
    usage: UsageFlags,
    flags: CreateFlags = .empty,
    queue_family_indices: []const core.QueueFamilyIndex = &.{},
    opaque_capture_address: ?OpaqueCaptureAddress = null,
};

pub const MemoryRequirements = memory.Requirements;

pub const ViewOptions = struct {
    format: types.Format,
    offset: Offset = .zero,
    range: Range = .whole,
};

pub const AllocationOptions = struct {
    memory_type_index: core.MemoryTypeIndex,
    device_address: bool = false,
    opaque_capture_address: ?memory.OpaqueCaptureAddress = null,
};

pub const AllocatedOptions = struct {
    buffer: Options,
    memory: AllocationOptions,
};

pub const AutoAllocatedOptions = struct {
    buffer: Options,
    memory_properties: *const memory.Properties,
    required_memory_flags: types.MemoryPropertyFlags,
    preferred_memory_flags: types.MemoryPropertyFlags = .empty,
    device_address: bool = false,
    opaque_capture_address: ?memory.OpaqueCaptureAddress = null,
};

pub const Dispatch = struct {
    create_buffer: CommandFunction(raw.PFN_vkCreateBuffer),
    destroy_buffer: CommandFunction(raw.PFN_vkDestroyBuffer),
    get_buffer_memory_requirements: CommandFunction(raw.PFN_vkGetBufferMemoryRequirements),
    get_buffer_memory_requirements2: ?CommandFunction(raw.PFN_vkGetBufferMemoryRequirements2),
    get_buffer_device_address: ?CommandFunction(raw.PFN_vkGetBufferDeviceAddress),
    get_buffer_opaque_capture_address: ?CommandFunction(raw.PFN_vkGetBufferOpaqueCaptureAddress),
    create_buffer_view: CommandFunction(raw.PFN_vkCreateBufferView),
    destroy_buffer_view: CommandFunction(raw.PFN_vkDestroyBufferView),
    bind_buffer_memory: CommandFunction(raw.PFN_vkBindBufferMemory),
    bind_buffer_memory2: ?CommandFunction(raw.PFN_vkBindBufferMemory2),
};

pub const Buffer = struct {
    _handle: ?BufferHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    _device_group_size: u32 = 1,
    size: Size,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,
    bound_memory: ?memory.Binding = null,

    pub fn deinit(buffer: *Buffer) void {
        if (!(buffer._owner.release(buffer) catch return)) return;
        const handle = buffer._handle orelse return;
        buffer.dispatch.destroy_buffer(
            buffer._device_handle,
            handle,
            buffer.allocation_callbacks,
        );
        buffer._handle = null;
    }

    pub fn rawHandle(buffer: *const Buffer) core.Error!raw.VkBuffer {
        try buffer._owner.validate(buffer);
        if (buffer._device_state) |*state| try state.ensureDispatchAllowed();
        return buffer._handle orelse error.InactiveObject;
    }

    pub fn debugObject(buffer: *const Buffer) core.Error!debug_utils.Object {
        return .forDevice(.buffer, try buffer.rawHandle(), buffer._device_handle);
    }

    pub fn memoryRequirements(buffer: *const Buffer) core.Error!MemoryRequirements {
        const handle = try buffer.rawHandle();
        if (buffer.dispatch.get_buffer_memory_requirements2) |get_requirements| {
            const info: raw.VkBufferMemoryRequirementsInfo2 = .{
                .sType = raw.VK_STRUCTURE_TYPE_BUFFER_MEMORY_REQUIREMENTS_INFO_2,
                .buffer = handle,
            };
            var output: raw.VkMemoryRequirements2 = .{
                .sType = raw.VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2,
            };
            var dedicated: raw.VkMemoryDedicatedRequirements = .{
                .sType = raw.VK_STRUCTURE_TYPE_MEMORY_DEDICATED_REQUIREMENTS,
            };
            output.pNext = &dedicated;
            get_requirements(buffer._device_handle, &info, &output);
            var requirements = MemoryRequirements.fromRaw(output.memoryRequirements);
            requirements.prefers_dedicated_allocation = dedicated.prefersDedicatedAllocation != raw.VK_FALSE;
            requirements.requires_dedicated_allocation = dedicated.requiresDedicatedAllocation != raw.VK_FALSE;
            return requirements;
        }
        var output: raw.VkMemoryRequirements = .{};
        buffer.dispatch.get_buffer_memory_requirements(
            buffer._device_handle,
            handle,
            &output,
        );
        return .fromRaw(output);
    }

    pub fn deviceAddress(buffer: *const Buffer) core.Error!?DeviceAddress {
        const get_address = buffer.dispatch.get_buffer_device_address orelse {
            return error.MissingCommand;
        };
        const info: raw.VkBufferDeviceAddressInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO,
            .buffer = try buffer.rawHandle(),
        };
        return .fromRaw(get_address(buffer._device_handle, &info));
    }

    pub fn opaqueCaptureAddress(buffer: *const Buffer) core.Error!?OpaqueCaptureAddress {
        const get_address = buffer.dispatch.get_buffer_opaque_capture_address orelse {
            return error.MissingCommand;
        };
        const info: raw.VkBufferDeviceAddressInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO,
            .buffer = try buffer.rawHandle(),
        };
        return .fromRaw(get_address(buffer._device_handle, &info));
    }

    pub fn bindMemory(
        buffer: *Buffer,
        allocation: *const memory.Allocation,
        offset: Offset,
    ) core.Error!void {
        return buffer.bindMemoryForDeviceGroup(allocation, offset, .{});
    }

    pub fn bindMemoryForDeviceGroup(
        buffer: *Buffer,
        allocation: *const memory.Allocation,
        offset: Offset,
        options: device_group.BufferBindingOptions,
    ) core.Error!void {
        if (buffer.bound_memory != null) return error.InvalidOptions;
        if (allocation._device_handle != buffer._device_handle) return error.InvalidHandle;
        try device_group.validateDeviceIndices(options.device_indices, buffer._device_group_size);
        const requirements = try buffer.memoryRequirements();
        if (!requirements.supportsMemoryType(allocation.memory_type_index)) {
            return error.InvalidOptions;
        }
        const offset_bytes = offset.bytes();
        const alignment = requirements.alignment.bytes();
        if (alignment != 0 and offset_bytes % alignment != 0) return error.InvalidOptions;
        if (offset_bytes > allocation.size.bytes() or
            requirements.size.bytes() > allocation.size.bytes() - offset_bytes)
        {
            return error.InvalidOptions;
        }
        const allocation_handle = (try allocation.rawHandle()) orelse return error.InvalidHandle;
        const buffer_handle = try buffer.rawHandle();
        if (buffer.dispatch.bind_buffer_memory2) |bind2| {
            var group_info: raw.VkBindBufferMemoryDeviceGroupInfo = .{
                .sType = raw.VK_STRUCTURE_TYPE_BIND_BUFFER_MEMORY_DEVICE_GROUP_INFO,
                .deviceIndexCount = @intCast(options.device_indices.len),
                .pDeviceIndices = if (options.device_indices.len == 0) null else options.device_indices.ptr,
            };
            const info: raw.VkBindBufferMemoryInfo = .{
                .sType = raw.VK_STRUCTURE_TYPE_BIND_BUFFER_MEMORY_INFO,
                .pNext = if (options.device_indices.len == 0) null else &group_info,
                .buffer = buffer_handle,
                .memory = allocation_handle,
                .memoryOffset = offset_bytes,
            };
            try core.checkSuccessOptional(if (buffer._device_state) |*state| state else null, bind2(buffer._device_handle, 1, &info));
        } else {
            if (options.device_indices.len != 0) return error.MissingCommand;
            try core.checkSuccessOptional(if (buffer._device_state) |*state| state else null, buffer.dispatch.bind_buffer_memory(
                buffer._device_handle,
                buffer_handle,
                allocation_handle,
                offset_bytes,
            ));
        }
        buffer.bound_memory = .{ .allocation = allocation_handle, .offset = offset };
    }
};

pub const View = struct {
    _handle: ?BufferViewHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    _buffer_handle: BufferHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_buffer_view: CommandFunction(raw.PFN_vkDestroyBufferView),

    pub fn deinit(view: *View) void {
        if (!(view._owner.release(view) catch return)) return;
        const handle = view._handle orelse return;
        view.destroy_buffer_view(view._device_handle, handle, view.allocation_callbacks);
        view._handle = null;
    }

    pub fn rawHandle(view: *const View) core.Error!raw.VkBufferView {
        try view._owner.validate(view);
        if (view._device_state) |*state| try state.ensureDispatchAllowed();
        return view._handle orelse error.InactiveObject;
    }

    pub fn debugObject(view: *const View) core.Error!debug_utils.Object {
        return .forDevice(.buffer_view, try view.rawHandle(), view._device_handle);
    }
};

pub const Allocated = struct {
    buffer: Buffer,
    memory: memory.Allocation,

    pub fn deinit(allocated: *Allocated) void {
        allocated.buffer.deinit();
        allocated.memory.deinit();
    }
};

pub fn create(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,
    options: Options,
) core.Error!Buffer {
    if (options.size.bytes() == 0 or options.usage.toRaw() == 0) return error.InvalidOptions;
    if (options.queue_family_indices.len > queue_family_count_max) return error.CountOverflow;
    if (options.queue_family_indices.len == 1) return error.InvalidOptions;

    var queue_family_indices_raw: [queue_family_count_max]u32 = undefined;
    for (options.queue_family_indices, 0..) |family_index, index| {
        for (options.queue_family_indices[0..index]) |previous_index| {
            if (family_index == previous_index) return error.InvalidOptions;
        }
        queue_family_indices_raw[index] = family_index.toRaw();
    }

    var capture_info: raw.VkBufferOpaqueCaptureAddressCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_BUFFER_OPAQUE_CAPTURE_ADDRESS_CREATE_INFO,
    };
    var flags = options.flags;
    if (options.opaque_capture_address) |address| {
        capture_info.opaqueCaptureAddress = address.toRaw();
        flags = flags.with(.device_address_capture_replay);
    }
    const concurrent = options.queue_family_indices.len > 1;
    const create_info: raw.VkBufferCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .pNext = if (options.opaque_capture_address != null) &capture_info else null,
        .flags = flags.toRaw(),
        .size = options.size.bytes(),
        .usage = options.usage.toRaw(),
        .sharingMode = if (concurrent)
            types.SharingMode.concurrent.toRaw()
        else
            types.SharingMode.exclusive.toRaw(),
        .queueFamilyIndexCount = if (concurrent)
            @intCast(options.queue_family_indices.len)
        else
            0,
        .pQueueFamilyIndices = if (concurrent)
            queue_family_indices_raw[0..options.queue_family_indices.len].ptr
        else
            null,
    };
    var handle: raw.VkBuffer = null;
    const result = dispatch.create_buffer(
        device_handle,
        &create_info,
        allocation_callbacks,
        &handle,
    );
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional_handle| {
            dispatch.destroy_buffer(device_handle, provisional_handle, allocation_callbacks);
        }
        try core.checkSuccess(result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._owner = try .init(&handle),
        ._device_handle = device_handle,
        .size = options.size,
        .allocation_callbacks = allocation_callbacks,
        .dispatch = dispatch,
    };
}

pub fn createView(buffer: *const Buffer, options: ViewOptions) core.Error!View {
    const buffer_handle = (try buffer.rawHandle()) orelse return error.InvalidHandle;
    const offset = options.offset.bytes();
    if (offset >= buffer.size.bytes()) return error.InvalidOptions;
    switch (options.range) {
        .whole => {},
        .bytes => |size| {
            const range_size = size.bytes();
            if (range_size == 0 or range_size > buffer.size.bytes() - offset) {
                return error.InvalidOptions;
            }
        },
    }
    const create_info: raw.VkBufferViewCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_BUFFER_VIEW_CREATE_INFO,
        .buffer = buffer_handle,
        .format = options.format.toRaw(),
        .offset = offset,
        .range = options.range.toRaw(),
    };
    var handle: raw.VkBufferView = null;
    const result = buffer.dispatch.create_buffer_view(
        buffer._device_handle,
        &create_info,
        buffer.allocation_callbacks,
        &handle,
    );
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional_handle| {
            buffer.dispatch.destroy_buffer_view(
                buffer._device_handle,
                provisional_handle,
                buffer.allocation_callbacks,
            );
        }
        try core.checkSuccess(result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._owner = try .init(&handle),
        ._device_handle = buffer._device_handle,
        ._buffer_handle = buffer_handle,
        .allocation_callbacks = buffer.allocation_callbacks,
        .destroy_buffer_view = buffer.dispatch.destroy_buffer_view,
    };
}
