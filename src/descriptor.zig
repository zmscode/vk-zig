const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const shader = @import("shader.zig");
const sampler = @import("sampler.zig");
const buffer = @import("buffer.zig");
const image = @import("image.zig");
const debug_utils = @import("debug_utils.zig");
const types = @import("vulkan_types");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const LayoutHandle = core.NonNullHandle(raw.VkDescriptorSetLayout);
const PoolHandle = core.NonNullHandle(raw.VkDescriptorPool);
const SetHandle = core.NonNullHandle(raw.VkDescriptorSet);
const TemplateHandle = core.NonNullHandle(raw.VkDescriptorUpdateTemplate);
const binding_count_max = 64;
const immutable_sampler_count_max = 256;
const set_count_max = 64;
const write_count_max = 128;
const descriptor_info_count_max = 512;
const template_data_size_max = 32 * 1024;

pub const Type = enum(raw.VkDescriptorType) {
    sampler = @intCast(raw.VK_DESCRIPTOR_TYPE_SAMPLER),
    combined_image_sampler = @intCast(raw.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER),
    sampled_image = @intCast(raw.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE),
    storage_image = @intCast(raw.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE),
    uniform_texel_buffer = @intCast(raw.VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER),
    storage_texel_buffer = @intCast(raw.VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER),
    uniform_buffer = @intCast(raw.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER),
    storage_buffer = @intCast(raw.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER),
    uniform_buffer_dynamic = @intCast(raw.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC),
    storage_buffer_dynamic = @intCast(raw.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC),
    input_attachment = @intCast(raw.VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT),
    inline_uniform_block = @intCast(raw.VK_DESCRIPTOR_TYPE_INLINE_UNIFORM_BLOCK),
    acceleration_structure = @intCast(raw.VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR),
    _,

    pub fn fromRaw(value: raw.VkDescriptorType) Type {
        return @enumFromInt(value);
    }

    pub fn toRaw(value: Type) raw.VkDescriptorType {
        return @intFromEnum(value);
    }
};

pub const BindingFlags = types.DescriptorBindingFlags;

pub const Binding = struct {
    binding: u32,
    descriptor_type: Type,
    count: u32 = 1,
    stages: shader.StageSet,
    immutable_samplers: []const *const sampler.Sampler = &.{},
    flags: BindingFlags = .empty,
};

pub const LayoutOptions = struct {
    bindings: []const Binding,
    push_descriptor: bool = false,
    update_after_bind_pool: bool = false,
};

pub const Dispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateDescriptorSetLayout),
    destroy: CommandFunction(raw.PFN_vkDestroyDescriptorSetLayout),
};

pub const LayoutSupport = struct {
    supported: bool,
    max_variable_descriptor_count: u32,
};

const LayoutStorage = struct {
    bindings: [binding_count_max]raw.VkDescriptorSetLayoutBinding = undefined,
    immutable_handles: [immutable_sampler_count_max]raw.VkSampler = undefined,
    binding_flags: [binding_count_max]raw.VkDescriptorBindingFlags = undefined,
    binding_flags_info: raw.VkDescriptorSetLayoutBindingFlagsCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
    },
    info: raw.VkDescriptorSetLayoutCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
    },

    fn init(storage: *LayoutStorage, device_handle: DeviceHandle, options: LayoutOptions) core.Error!void {
        if (options.bindings.len > binding_count_max) return error.CountOverflow;
        var immutable_count: usize = 0;
        var has_binding_flags = false;
        for (options.bindings, 0..) |binding, index| {
            if (binding.count == 0 or binding.stages.toRaw() == 0) return error.InvalidOptions;
            for (options.bindings[0..index]) |previous| if (previous.binding == binding.binding) return error.InvalidOptions;
            if (binding.immutable_samplers.len != 0 and binding.immutable_samplers.len != binding.count) return error.InvalidOptions;
            if (binding.immutable_samplers.len != 0 and binding.descriptor_type != .sampler and binding.descriptor_type != .combined_image_sampler) return error.InvalidOptions;
            if (binding.flags.contains(.variable_descriptor_count)) {
                for (options.bindings) |other| if (other.binding > binding.binding) return error.InvalidOptions;
            }
            const update_after_bind = binding.flags.contains(.update_after_bind) or binding.flags.contains(.update_unused_while_pending);
            if (update_after_bind and !options.update_after_bind_pool) return error.InvalidOptions;
            const immutable_start = immutable_count;
            if (binding.immutable_samplers.len > storage.immutable_handles.len - immutable_count) return error.CountOverflow;
            for (binding.immutable_samplers) |item| {
                if (item._device_handle != device_handle) return error.InvalidHandle;
                storage.immutable_handles[immutable_count] = try item.rawHandle();
                immutable_count += 1;
            }
            storage.bindings[index] = .{
                .binding = binding.binding,
                .descriptorType = binding.descriptor_type.toRaw(),
                .descriptorCount = binding.count,
                .stageFlags = binding.stages.toRaw(),
                .pImmutableSamplers = if (binding.immutable_samplers.len == 0) null else storage.immutable_handles[immutable_start..immutable_count].ptr,
            };
            storage.binding_flags[index] = binding.flags.toRaw();
            has_binding_flags = has_binding_flags or !binding.flags.isEmpty();
        }
        storage.binding_flags_info.bindingCount = @intCast(options.bindings.len);
        storage.binding_flags_info.pBindingFlags = if (options.bindings.len == 0) null else storage.binding_flags[0..options.bindings.len].ptr;
        storage.info = .{
            .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .pNext = if (has_binding_flags) &storage.binding_flags_info else null,
            .flags = (if (options.push_descriptor) @as(raw.VkDescriptorSetLayoutCreateFlags, @intCast(raw.VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT)) else 0) |
                (if (options.update_after_bind_pool) @as(raw.VkDescriptorSetLayoutCreateFlags, @intCast(raw.VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT)) else 0),
            .bindingCount = @intCast(options.bindings.len),
            .pBindings = if (options.bindings.len == 0) null else storage.bindings[0..options.bindings.len].ptr,
        };
    }
};

pub const SetLayout = struct {
    _handle: ?LayoutHandle,
    _device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_layout: CommandFunction(raw.PFN_vkDestroyDescriptorSetLayout),
    _bindings: [binding_count_max]BindingMetadata = undefined,
    _binding_count: usize = 0,
    _push_descriptor: bool = false,

    pub fn deinit(layout: *SetLayout) void {
        const handle = layout._handle orelse return;
        layout.destroy_layout(layout._device_handle, handle, layout.allocation_callbacks);
        layout._handle = null;
    }

    pub fn rawHandle(layout: *const SetLayout) core.Error!raw.VkDescriptorSetLayout {
        return layout._handle orelse error.InactiveObject;
    }

    pub fn debugObject(layout: *const SetLayout) core.Error!debug_utils.Object {
        return .forDevice(.descriptor_set_layout, try layout.rawHandle(), layout._device_handle);
    }

    fn binding(layout: *const SetLayout, binding_index: u32) ?BindingMetadata {
        for (layout._bindings[0..layout._binding_count]) |metadata| {
            if (metadata.binding == binding_index) return metadata;
        }
        return null;
    }
};

const BindingMetadata = struct {
    binding: u32,
    descriptor_type: Type,
    count: u32,
    flags: BindingFlags,
};

pub fn createLayout(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,
    options: LayoutOptions,
) core.Error!SetLayout {
    var storage: LayoutStorage = .{};
    try storage.init(device_handle, options);
    var handle: raw.VkDescriptorSetLayout = null;
    const result = dispatch.create(device_handle, &storage.info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccess(result);
        unreachable;
    }
    var layout: SetLayout = .{
        ._handle = handle orelse return error.InvalidHandle,
        ._device_handle = device_handle,
        .allocation_callbacks = allocation_callbacks,
        .destroy_layout = dispatch.destroy,
    };
    layout._binding_count = options.bindings.len;
    layout._push_descriptor = options.push_descriptor;
    for (options.bindings, 0..) |binding, index| layout._bindings[index] = .{
        .binding = binding.binding,
        .descriptor_type = binding.descriptor_type,
        .count = binding.count,
        .flags = binding.flags,
    };
    return layout;
}

pub fn queryLayoutSupport(
    device_handle: DeviceHandle,
    get_support: CommandFunction(raw.PFN_vkGetDescriptorSetLayoutSupport),
    options: LayoutOptions,
) core.Error!LayoutSupport {
    var storage: LayoutStorage = .{};
    try storage.init(device_handle, options);
    var variable: raw.VkDescriptorSetVariableDescriptorCountLayoutSupport = .{
        .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_VARIABLE_DESCRIPTOR_COUNT_LAYOUT_SUPPORT,
    };
    var support: raw.VkDescriptorSetLayoutSupport = .{
        .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_SUPPORT,
        .pNext = &variable,
    };
    get_support(device_handle, &storage.info, &support);
    return .{
        .supported = support.supported != raw.VK_FALSE,
        .max_variable_descriptor_count = variable.maxVariableDescriptorCount,
    };
}

pub const PoolSize = struct { descriptor_type: Type, count: u32 };
pub const PoolOptions = struct {
    max_sets: u32,
    sizes: []const PoolSize,
    free_individual_sets: bool = false,
    update_after_bind: bool = false,
};

pub const PoolDispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateDescriptorPool),
    destroy: CommandFunction(raw.PFN_vkDestroyDescriptorPool),
    reset: CommandFunction(raw.PFN_vkResetDescriptorPool),
    allocate: CommandFunction(raw.PFN_vkAllocateDescriptorSets),
    free: CommandFunction(raw.PFN_vkFreeDescriptorSets),
};

pub const Pool = struct {
    _handle: ?PoolHandle,
    _device_handle: DeviceHandle,
    generation: u64 = 1,
    free_individual_sets: bool,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: PoolDispatch,

    pub fn deinit(pool: *Pool) void {
        const handle = pool._handle orelse return;
        pool.dispatch.destroy(pool._device_handle, handle, pool.allocation_callbacks);
        pool._handle = null;
        pool.generation +%= 1;
    }

    pub fn reset(pool: *Pool) core.Error!void {
        const handle = pool._handle orelse return error.InactiveObject;
        try core.checkSuccess(pool.dispatch.reset(pool._device_handle, handle, 0));
        pool.generation +%= 1;
    }

    pub fn allocate(pool: *Pool, layout: *const SetLayout) core.Error!Set {
        return pool.allocateOptions(.{ .layout = layout });
    }

    pub fn allocateOptions(pool: *Pool, options: AllocateOptions) core.Error!Set {
        const pool_handle = pool._handle orelse return error.InactiveObject;
        const layout = options.layout;
        if (layout._device_handle != pool._device_handle) return error.InvalidHandle;
        const layout_handle = try layout.rawHandle();
        var variable_count: raw.VkDescriptorSetVariableDescriptorCountAllocateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_VARIABLE_DESCRIPTOR_COUNT_ALLOCATE_INFO,
        };
        if (options.variable_descriptor_count) |count| {
            if (count == 0) return error.InvalidOptions;
            const variable_binding = for (layout._bindings[0..layout._binding_count]) |binding| {
                if (binding.flags.contains(.variable_descriptor_count)) break binding;
            } else return error.InvalidOptions;
            if (count > variable_binding.count) return error.InvalidOptions;
            variable_count.descriptorSetCount = 1;
            variable_count.pDescriptorCounts = @ptrCast(&count);
        }
        const info: raw.VkDescriptorSetAllocateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .pNext = if (options.variable_descriptor_count != null) &variable_count else null,
            .descriptorPool = pool_handle,
            .descriptorSetCount = 1,
            .pSetLayouts = @ptrCast(&layout_handle),
        };
        var handle: raw.VkDescriptorSet = null;
        try core.checkSuccess(pool.dispatch.allocate(pool._device_handle, &info, &handle));
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._device_handle = pool._device_handle,
            ._pool = pool,
            ._pool_generation = pool.generation,
            .layout_handle = layout_handle orelse return error.InvalidHandle,
            .layout = layout,
            .variable_descriptor_count = options.variable_descriptor_count,
        };
    }

    pub fn allocateMany(
        pool: *Pool,
        requests: []const AllocateOptions,
        output: []Set,
    ) core.Error![]Set {
        if (requests.len == 0 or requests.len > set_count_max) return error.InvalidOptions;
        if (output.len < requests.len) return error.BufferTooSmall;
        const pool_handle = pool._handle orelse return error.InactiveObject;
        var layouts: [set_count_max]raw.VkDescriptorSetLayout = undefined;
        var variable_counts: [set_count_max]u32 = @splat(0);
        var handles: [set_count_max]raw.VkDescriptorSet = @splat(null);
        var uses_variable_counts = false;
        for (requests, 0..) |request, index| {
            if (request.layout._device_handle != pool._device_handle) return error.InvalidHandle;
            layouts[index] = try request.layout.rawHandle();
            if (request.variable_descriptor_count) |count| {
                if (count == 0) return error.InvalidOptions;
                const variable_binding = for (request.layout._bindings[0..request.layout._binding_count]) |binding| {
                    if (binding.flags.contains(.variable_descriptor_count)) break binding;
                } else return error.InvalidOptions;
                if (count > variable_binding.count) return error.InvalidOptions;
                variable_counts[index] = count;
                uses_variable_counts = true;
            }
        }
        const variable_info: raw.VkDescriptorSetVariableDescriptorCountAllocateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_VARIABLE_DESCRIPTOR_COUNT_ALLOCATE_INFO,
            .descriptorSetCount = @intCast(requests.len),
            .pDescriptorCounts = variable_counts[0..requests.len].ptr,
        };
        const info: raw.VkDescriptorSetAllocateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .pNext = if (uses_variable_counts) &variable_info else null,
            .descriptorPool = pool_handle,
            .descriptorSetCount = @intCast(requests.len),
            .pSetLayouts = layouts[0..requests.len].ptr,
        };
        try core.checkSuccess(pool.dispatch.allocate(pool._device_handle, &info, handles[0..requests.len].ptr));
        for (requests, handles[0..requests.len], 0..) |request, handle, index| {
            output[index] = .{
                ._handle = handle orelse return error.InvalidHandle,
                ._device_handle = pool._device_handle,
                ._pool = pool,
                ._pool_generation = pool.generation,
                .layout_handle = layouts[index] orelse return error.InvalidHandle,
                .layout = request.layout,
                .variable_descriptor_count = request.variable_descriptor_count,
            };
        }
        return output[0..requests.len];
    }

    pub fn debugObject(pool: *const Pool) core.Error!debug_utils.Object {
        return .forDevice(.descriptor_pool, pool._handle orelse return error.InactiveObject, pool._device_handle);
    }
};

pub const AllocateOptions = struct {
    layout: *const SetLayout,
    variable_descriptor_count: ?u32 = null,
};

pub const Set = struct {
    _handle: ?SetHandle,
    _device_handle: DeviceHandle,
    _pool: *Pool,
    _pool_generation: u64,
    layout_handle: LayoutHandle,
    layout: *const SetLayout,
    variable_descriptor_count: ?u32 = null,

    pub fn rawHandle(set: *const Set) core.Error!raw.VkDescriptorSet {
        if (set._pool._handle == null or set._pool.generation != set._pool_generation) return error.InactiveObject;
        return set._handle orelse error.InactiveObject;
    }

    pub fn deinit(set: *Set) void {
        const handle = set._handle orelse return;
        const pool_handle = set._pool._handle orelse {
            set._handle = null;
            return;
        };
        if (set._pool.generation != set._pool_generation) {
            set._handle = null;
            return;
        }
        if (set._pool.free_individual_sets) {
            _ = set._pool.dispatch.free(set._device_handle, pool_handle, 1, @ptrCast(&handle));
        }
        set._handle = null;
    }

    pub fn free(set: *Set) core.Error!void {
        const handle = try set.rawHandle();
        if (!set._pool.free_individual_sets) return error.InvalidOptions;
        const pool_handle = set._pool._handle orelse return error.InactiveObject;
        try core.checkSuccess(set._pool.dispatch.free(set._device_handle, pool_handle, 1, @ptrCast(&handle)));
        set._handle = null;
    }

    pub fn debugObject(set: *const Set) core.Error!debug_utils.Object {
        return .forDevice(.descriptor_set, try set.rawHandle(), set._device_handle);
    }
};

pub const ImageInfo = struct {
    sampler: ?*const sampler.Sampler = null,
    view: ?*const image.View = null,
    layout: types.ImageLayout = .undefined_,
};

pub const BufferInfo = struct {
    buffer: *const buffer.Buffer,
    offset: core.DeviceOffset = .zero,
    range: core.DeviceRange = .whole,
};

pub const AccelerationStructureReference = struct {
    _handle: core.NonNullHandle(raw.VkAccelerationStructureKHR),
    _device_handle: DeviceHandle,
};

pub const WriteData = union(enum) {
    sampler: []const ImageInfo,
    combined_image_sampler: []const ImageInfo,
    sampled_image: []const ImageInfo,
    storage_image: []const ImageInfo,
    uniform_texel_buffer: []const *const buffer.View,
    storage_texel_buffer: []const *const buffer.View,
    uniform_buffer: []const BufferInfo,
    storage_buffer: []const BufferInfo,
    uniform_buffer_dynamic: []const BufferInfo,
    storage_buffer_dynamic: []const BufferInfo,
    input_attachment: []const ImageInfo,
    inline_uniform_block: []const u8,
    acceleration_structure: []const *const AccelerationStructureReference,

    fn descriptorType(data: WriteData) Type {
        return switch (data) {
            .sampler => .sampler,
            .combined_image_sampler => .combined_image_sampler,
            .sampled_image => .sampled_image,
            .storage_image => .storage_image,
            .uniform_texel_buffer => .uniform_texel_buffer,
            .storage_texel_buffer => .storage_texel_buffer,
            .uniform_buffer => .uniform_buffer,
            .storage_buffer => .storage_buffer,
            .uniform_buffer_dynamic => .uniform_buffer_dynamic,
            .storage_buffer_dynamic => .storage_buffer_dynamic,
            .input_attachment => .input_attachment,
            .inline_uniform_block => .inline_uniform_block,
            .acceleration_structure => .acceleration_structure,
        };
    }

    fn count(data: WriteData) usize {
        return switch (data) {
            inline else => |values| values.len,
        };
    }
};

pub const Write = struct {
    destination: *const Set,
    binding: u32,
    array_element: u32 = 0,
    data: WriteData,
};

pub const PushWrite = struct {
    binding: u32,
    array_element: u32 = 0,
    data: WriteData,
};

pub fn push(
    device_handle: DeviceHandle,
    push_descriptors: CommandFunction(raw.PFN_vkCmdPushDescriptorSet),
    command_buffer: raw.VkCommandBuffer,
    bind_point: raw.VkPipelineBindPoint,
    pipeline_layout: raw.VkPipelineLayout,
    set_index: u32,
    set_layout: *const SetLayout,
    writes: []const PushWrite,
) core.Error!void {
    if (set_layout._device_handle != device_handle) return error.InvalidHandle;
    if (!set_layout._push_descriptor or writes.len == 0) return error.InvalidOptions;
    if (writes.len > write_count_max) return error.CountOverflow;
    var raw_writes: [write_count_max]raw.VkWriteDescriptorSet = undefined;
    var image_infos: [descriptor_info_count_max]raw.VkDescriptorImageInfo = undefined;
    var buffer_infos: [descriptor_info_count_max]raw.VkDescriptorBufferInfo = undefined;
    var texel_views: [descriptor_info_count_max]raw.VkBufferView = undefined;
    var acceleration_handles: [descriptor_info_count_max]raw.VkAccelerationStructureKHR = undefined;
    var inline_infos: [write_count_max]raw.VkWriteDescriptorSetInlineUniformBlock = undefined;
    var acceleration_infos: [write_count_max]raw.VkWriteDescriptorSetAccelerationStructureKHR = undefined;
    var image_count: usize = 0;
    var buffer_count: usize = 0;
    var texel_count: usize = 0;
    var acceleration_count: usize = 0;

    for (writes, 0..) |write, write_index| {
        const metadata = set_layout.binding(write.binding) orelse return error.InvalidOptions;
        const descriptor_type = write.data.descriptorType();
        const count = write.data.count();
        if (count == 0 or descriptor_type != metadata.descriptor_type) return error.InvalidOptions;
        const end = std.math.add(u32, write.array_element, @intCast(count)) catch return error.CountOverflow;
        if (end > metadata.count) return error.InvalidOptions;
        raw_writes[write_index] = .{
            .sType = raw.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstBinding = write.binding,
            .dstArrayElement = write.array_element,
            .descriptorCount = @intCast(count),
            .descriptorType = descriptor_type.toRaw(),
        };
        switch (write.data) {
            .sampler, .combined_image_sampler, .sampled_image, .storage_image, .input_attachment => |values| {
                if (values.len > image_infos.len - image_count) return error.CountOverflow;
                const start = image_count;
                for (values) |value| {
                    const needs_sampler = descriptor_type == .sampler or descriptor_type == .combined_image_sampler;
                    const needs_view = descriptor_type != .sampler;
                    if (needs_sampler != (value.sampler != null) or needs_view != (value.view != null)) return error.InvalidOptions;
                    const sampler_handle = if (value.sampler) |item| blk: {
                        if (item._device_handle != device_handle) return error.InvalidHandle;
                        break :blk try item.rawHandle();
                    } else null;
                    const view_handle = if (value.view) |item| blk: {
                        if (item._device_handle != device_handle) return error.InvalidHandle;
                        break :blk try item.rawHandle();
                    } else null;
                    if (needs_view and value.layout == .undefined_) return error.InvalidOptions;
                    image_infos[image_count] = .{ .sampler = sampler_handle, .imageView = view_handle, .imageLayout = value.layout.toRaw() };
                    image_count += 1;
                }
                raw_writes[write_index].pImageInfo = image_infos[start..image_count].ptr;
            },
            .uniform_buffer, .storage_buffer, .uniform_buffer_dynamic, .storage_buffer_dynamic => |values| {
                if (values.len > buffer_infos.len - buffer_count) return error.CountOverflow;
                const start = buffer_count;
                for (values) |value| {
                    if (value.buffer._device_handle != device_handle) return error.InvalidHandle;
                    const offset = value.offset.bytes();
                    if (offset >= value.buffer.size.bytes()) return error.InvalidOptions;
                    switch (value.range) {
                        .whole => {},
                        .bytes => |range_size| {
                            const size = range_size.bytes();
                            if (size == 0 or (std.math.add(u64, offset, size) catch return error.SizeOverflow) > value.buffer.size.bytes()) return error.InvalidOptions;
                        },
                    }
                    buffer_infos[buffer_count] = .{ .buffer = try value.buffer.rawHandle(), .offset = offset, .range = value.range.toRaw() };
                    buffer_count += 1;
                }
                raw_writes[write_index].pBufferInfo = buffer_infos[start..buffer_count].ptr;
            },
            .uniform_texel_buffer, .storage_texel_buffer => |values| {
                if (values.len > texel_views.len - texel_count) return error.CountOverflow;
                const start = texel_count;
                for (values) |value| {
                    if (value._device_handle != device_handle) return error.InvalidHandle;
                    texel_views[texel_count] = try value.rawHandle();
                    texel_count += 1;
                }
                raw_writes[write_index].pTexelBufferView = texel_views[start..texel_count].ptr;
            },
            .inline_uniform_block => |bytes| {
                if (bytes.len % 4 != 0) return error.InvalidOptions;
                inline_infos[write_index] = .{ .sType = raw.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_INLINE_UNIFORM_BLOCK, .dataSize = @intCast(bytes.len), .pData = bytes.ptr };
                raw_writes[write_index].pNext = &inline_infos[write_index];
            },
            .acceleration_structure => |values| {
                if (values.len > acceleration_handles.len - acceleration_count) return error.CountOverflow;
                const start = acceleration_count;
                for (values) |value| {
                    if (value._device_handle != device_handle) return error.InvalidHandle;
                    acceleration_handles[acceleration_count] = value._handle;
                    acceleration_count += 1;
                }
                acceleration_infos[write_index] = .{ .sType = raw.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_ACCELERATION_STRUCTURE_KHR, .accelerationStructureCount = @intCast(values.len), .pAccelerationStructures = acceleration_handles[start..acceleration_count].ptr };
                raw_writes[write_index].pNext = &acceleration_infos[write_index];
            },
        }
    }
    push_descriptors(command_buffer, bind_point, pipeline_layout, set_index, @intCast(writes.len), raw_writes[0..writes.len].ptr);
}

pub const Copy = struct {
    source: *const Set,
    source_binding: u32,
    source_array_element: u32 = 0,
    destination: *const Set,
    destination_binding: u32,
    destination_array_element: u32 = 0,
    count: u32,
};

pub const TemplateEntry = struct {
    binding: u32,
    array_element: u32 = 0,
    count: u32 = 1,
};

pub const TemplateOptions = struct {
    layout: *const SetLayout,
    entries: []const TemplateEntry,
};

const TemplateMetadata = struct {
    descriptor_type: Type,
    count: u32,
    offset: usize,
    stride: usize,
};

fn templateElementLayout(descriptor_type: Type) core.Error!struct { size: usize, alignment: usize } {
    return switch (descriptor_type) {
        .sampler, .combined_image_sampler, .sampled_image, .storage_image, .input_attachment => .{ .size = @sizeOf(raw.VkDescriptorImageInfo), .alignment = @alignOf(raw.VkDescriptorImageInfo) },
        .uniform_buffer, .storage_buffer, .uniform_buffer_dynamic, .storage_buffer_dynamic => .{ .size = @sizeOf(raw.VkDescriptorBufferInfo), .alignment = @alignOf(raw.VkDescriptorBufferInfo) },
        .uniform_texel_buffer, .storage_texel_buffer => .{ .size = @sizeOf(raw.VkBufferView), .alignment = @alignOf(raw.VkBufferView) },
        .inline_uniform_block => .{ .size = 1, .alignment = 1 },
        .acceleration_structure => .{ .size = @sizeOf(raw.VkAccelerationStructureKHR), .alignment = @alignOf(raw.VkAccelerationStructureKHR) },
        else => error.UnsupportedOperation,
    };
}

pub const TemplateDispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateDescriptorUpdateTemplate),
    destroy: CommandFunction(raw.PFN_vkDestroyDescriptorUpdateTemplate),
    update: CommandFunction(raw.PFN_vkUpdateDescriptorSetWithTemplate),
};

pub const UpdateTemplate = struct {
    _handle: ?TemplateHandle,
    _device_handle: DeviceHandle,
    _layout_handle: LayoutHandle,
    data_size: usize,
    _entries: [write_count_max]TemplateMetadata = undefined,
    _entry_count: usize,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: TemplateDispatch,

    pub fn deinit(template: *UpdateTemplate) void {
        const handle = template._handle orelse return;
        template.dispatch.destroy(template._device_handle, handle, template.allocation_callbacks);
        template._handle = null;
    }

    pub fn update(template: *const UpdateTemplate, set: *const Set, values: []const WriteData) core.Error!void {
        const handle = template._handle orelse return error.InactiveObject;
        if (set._device_handle != template._device_handle or set.layout_handle != template._layout_handle) return error.InvalidHandle;
        if (values.len != template._entry_count) return error.InvalidOptions;
        var data: [template_data_size_max]u8 align(16) = undefined;
        for (values, template._entries[0..template._entry_count]) |value, metadata| {
            if (value.descriptorType() != metadata.descriptor_type or value.count() != metadata.count) return error.InvalidOptions;
            switch (value) {
                .sampler, .combined_image_sampler, .sampled_image, .storage_image, .input_attachment => |items| for (items, 0..) |item, index| {
                    const needs_sampler = metadata.descriptor_type == .sampler or metadata.descriptor_type == .combined_image_sampler;
                    const needs_view = metadata.descriptor_type != .sampler;
                    if (needs_sampler != (item.sampler != null) or needs_view != (item.view != null)) return error.InvalidOptions;
                    const sampler_handle = if (item.sampler) |object| blk: {
                        if (object._device_handle != template._device_handle) return error.InvalidHandle;
                        break :blk try object.rawHandle();
                    } else null;
                    const view_handle = if (item.view) |object| blk: {
                        if (object._device_handle != template._device_handle) return error.InvalidHandle;
                        break :blk try object.rawHandle();
                    } else null;
                    if (needs_view and item.layout == .undefined_) return error.InvalidOptions;
                    const target: *raw.VkDescriptorImageInfo = @ptrCast(@alignCast(&data[metadata.offset + index * metadata.stride]));
                    target.* = .{ .sampler = sampler_handle, .imageView = view_handle, .imageLayout = item.layout.toRaw() };
                },
                .uniform_buffer, .storage_buffer, .uniform_buffer_dynamic, .storage_buffer_dynamic => |items| for (items, 0..) |item, index| {
                    if (item.buffer._device_handle != template._device_handle) return error.InvalidHandle;
                    const offset = item.offset.bytes();
                    if (offset >= item.buffer.size.bytes()) return error.InvalidOptions;
                    switch (item.range) {
                        .whole => {},
                        .bytes => |range_size| {
                            const size = range_size.bytes();
                            if (size == 0 or (std.math.add(u64, offset, size) catch return error.SizeOverflow) > item.buffer.size.bytes()) return error.InvalidOptions;
                        },
                    }
                    const target: *raw.VkDescriptorBufferInfo = @ptrCast(@alignCast(&data[metadata.offset + index * metadata.stride]));
                    target.* = .{ .buffer = try item.buffer.rawHandle(), .offset = offset, .range = item.range.toRaw() };
                },
                .uniform_texel_buffer, .storage_texel_buffer => |items| for (items, 0..) |item, index| {
                    if (item._device_handle != template._device_handle) return error.InvalidHandle;
                    const target: *raw.VkBufferView = @ptrCast(@alignCast(&data[metadata.offset + index * metadata.stride]));
                    target.* = try item.rawHandle();
                },
                .inline_uniform_block => |bytes| {
                    if (bytes.len % 4 != 0) return error.InvalidOptions;
                    @memcpy(data[metadata.offset..][0..bytes.len], bytes);
                },
                .acceleration_structure => |items| for (items, 0..) |item, index| {
                    if (item._device_handle != template._device_handle) return error.InvalidHandle;
                    const target: *raw.VkAccelerationStructureKHR = @ptrCast(@alignCast(&data[metadata.offset + index * metadata.stride]));
                    target.* = item._handle;
                },
            }
        }
        template.dispatch.update(template._device_handle, try set.rawHandle(), handle, &data);
    }

    pub fn rawHandle(template: *const UpdateTemplate) core.Error!raw.VkDescriptorUpdateTemplate {
        return template._handle orelse error.InactiveObject;
    }

    pub fn debugObject(template: *const UpdateTemplate) core.Error!debug_utils.Object {
        return .forDevice(.descriptor_update_template, try template.rawHandle(), template._device_handle);
    }
};

pub fn createUpdateTemplate(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: TemplateDispatch,
    options: TemplateOptions,
) core.Error!UpdateTemplate {
    if (options.layout._device_handle != device_handle) return error.InvalidHandle;
    if (options.entries.len == 0 or options.entries.len > write_count_max) return error.InvalidOptions;
    var entries: [write_count_max]raw.VkDescriptorUpdateTemplateEntry = undefined;
    var metadata_entries: [write_count_max]TemplateMetadata = undefined;
    var data_size: usize = 0;
    for (options.entries, 0..) |entry, index| {
        const metadata = options.layout.binding(entry.binding) orelse return error.InvalidOptions;
        if (entry.count == 0) return error.InvalidOptions;
        const descriptor_end = std.math.add(u32, entry.array_element, entry.count) catch return error.CountOverflow;
        if (descriptor_end > metadata.count) return error.InvalidOptions;
        const element = try templateElementLayout(metadata.descriptor_type);
        const offset = std.mem.alignForward(usize, data_size, element.alignment);
        data_size = std.math.add(usize, offset, std.math.mul(usize, element.size, entry.count) catch return error.SizeOverflow) catch return error.SizeOverflow;
        if (data_size > template_data_size_max) return error.CountOverflow;
        entries[index] = .{
            .dstBinding = entry.binding,
            .dstArrayElement = entry.array_element,
            .descriptorCount = entry.count,
            .descriptorType = metadata.descriptor_type.toRaw(),
            .offset = offset,
            .stride = element.size,
        };
        metadata_entries[index] = .{ .descriptor_type = metadata.descriptor_type, .count = entry.count, .offset = offset, .stride = element.size };
    }
    const info: raw.VkDescriptorUpdateTemplateCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_UPDATE_TEMPLATE_CREATE_INFO,
        .descriptorUpdateEntryCount = @intCast(options.entries.len),
        .pDescriptorUpdateEntries = entries[0..options.entries.len].ptr,
        .templateType = raw.VK_DESCRIPTOR_UPDATE_TEMPLATE_TYPE_DESCRIPTOR_SET,
        .descriptorSetLayout = try options.layout.rawHandle(),
    };
    var handle: raw.VkDescriptorUpdateTemplate = null;
    const result = dispatch.create(device_handle, &info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccess(result);
        unreachable;
    }
    var result_template: UpdateTemplate = .{
        ._handle = handle orelse return error.InvalidHandle,
        ._device_handle = device_handle,
        ._layout_handle = (try options.layout.rawHandle()) orelse return error.InvalidHandle,
        .data_size = data_size,
        ._entry_count = options.entries.len,
        .allocation_callbacks = allocation_callbacks,
        .dispatch = dispatch,
    };
    for (metadata_entries[0..options.entries.len], 0..) |metadata, index| result_template._entries[index] = metadata;
    return result_template;
}

pub fn update(
    device_handle: DeviceHandle,
    update_descriptors: CommandFunction(raw.PFN_vkUpdateDescriptorSets),
    writes: []const Write,
    copies: []const Copy,
) core.Error!void {
    if (writes.len > write_count_max or copies.len > write_count_max) return error.CountOverflow;
    var raw_writes: [write_count_max]raw.VkWriteDescriptorSet = undefined;
    var raw_copies: [write_count_max]raw.VkCopyDescriptorSet = undefined;
    var image_infos: [descriptor_info_count_max]raw.VkDescriptorImageInfo = undefined;
    var buffer_infos: [descriptor_info_count_max]raw.VkDescriptorBufferInfo = undefined;
    var texel_views: [descriptor_info_count_max]raw.VkBufferView = undefined;
    var acceleration_handles: [descriptor_info_count_max]raw.VkAccelerationStructureKHR = undefined;
    var inline_infos: [write_count_max]raw.VkWriteDescriptorSetInlineUniformBlock = undefined;
    var acceleration_infos: [write_count_max]raw.VkWriteDescriptorSetAccelerationStructureKHR = undefined;
    var image_count: usize = 0;
    var buffer_count: usize = 0;
    var texel_count: usize = 0;
    var acceleration_count: usize = 0;

    for (writes, 0..) |write, write_index| {
        if (write.destination._device_handle != device_handle) return error.InvalidHandle;
        const set_handle = try write.destination.rawHandle();
        const metadata = write.destination.layout.binding(write.binding) orelse return error.InvalidOptions;
        const descriptor_type = write.data.descriptorType();
        const count = write.data.count();
        if (count == 0 or descriptor_type != metadata.descriptor_type) return error.InvalidOptions;
        const binding_count = if (metadata.flags.contains(.variable_descriptor_count))
            write.destination.variable_descriptor_count orelse metadata.count
        else
            metadata.count;
        const end = std.math.add(u32, write.array_element, @intCast(count)) catch return error.CountOverflow;
        if (end > binding_count) return error.InvalidOptions;
        raw_writes[write_index] = .{
            .sType = raw.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = set_handle,
            .dstBinding = write.binding,
            .dstArrayElement = write.array_element,
            .descriptorCount = @intCast(count),
            .descriptorType = descriptor_type.toRaw(),
        };
        switch (write.data) {
            .sampler, .combined_image_sampler, .sampled_image, .storage_image, .input_attachment => |values| {
                if (values.len > image_infos.len - image_count) return error.CountOverflow;
                const start = image_count;
                for (values) |value| {
                    const needs_sampler = descriptor_type == .sampler or descriptor_type == .combined_image_sampler;
                    const needs_view = descriptor_type != .sampler;
                    if (needs_sampler != (value.sampler != null) or needs_view != (value.view != null)) return error.InvalidOptions;
                    const sampler_handle = if (value.sampler) |item| blk: {
                        if (item._device_handle != device_handle) return error.InvalidHandle;
                        break :blk try item.rawHandle();
                    } else null;
                    const view_handle = if (value.view) |item| blk: {
                        if (item._device_handle != device_handle) return error.InvalidHandle;
                        break :blk try item.rawHandle();
                    } else null;
                    if (needs_view and value.layout == .undefined_) return error.InvalidOptions;
                    image_infos[image_count] = .{
                        .sampler = sampler_handle,
                        .imageView = view_handle,
                        .imageLayout = value.layout.toRaw(),
                    };
                    image_count += 1;
                }
                raw_writes[write_index].pImageInfo = image_infos[start..image_count].ptr;
            },
            .uniform_buffer, .storage_buffer, .uniform_buffer_dynamic, .storage_buffer_dynamic => |values| {
                if (values.len > buffer_infos.len - buffer_count) return error.CountOverflow;
                const start = buffer_count;
                for (values) |value| {
                    if (value.buffer._device_handle != device_handle) return error.InvalidHandle;
                    const offset = value.offset.bytes();
                    if (offset >= value.buffer.size.bytes()) return error.InvalidOptions;
                    switch (value.range) {
                        .whole => {},
                        .bytes => |range_size| {
                            const size = range_size.bytes();
                            if (size == 0 or (std.math.add(u64, offset, size) catch return error.SizeOverflow) > value.buffer.size.bytes()) return error.InvalidOptions;
                        },
                    }
                    buffer_infos[buffer_count] = .{
                        .buffer = try value.buffer.rawHandle(),
                        .offset = offset,
                        .range = value.range.toRaw(),
                    };
                    buffer_count += 1;
                }
                raw_writes[write_index].pBufferInfo = buffer_infos[start..buffer_count].ptr;
            },
            .uniform_texel_buffer, .storage_texel_buffer => |values| {
                if (values.len > texel_views.len - texel_count) return error.CountOverflow;
                const start = texel_count;
                for (values) |value| {
                    if (value._device_handle != device_handle) return error.InvalidHandle;
                    texel_views[texel_count] = try value.rawHandle();
                    texel_count += 1;
                }
                raw_writes[write_index].pTexelBufferView = texel_views[start..texel_count].ptr;
            },
            .inline_uniform_block => |bytes| {
                if (bytes.len % 4 != 0) return error.InvalidOptions;
                inline_infos[write_index] = .{
                    .sType = raw.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_INLINE_UNIFORM_BLOCK,
                    .dataSize = @intCast(bytes.len),
                    .pData = bytes.ptr,
                };
                raw_writes[write_index].pNext = &inline_infos[write_index];
            },
            .acceleration_structure => |values| {
                if (values.len > acceleration_handles.len - acceleration_count) return error.CountOverflow;
                const start = acceleration_count;
                for (values) |value| {
                    if (value._device_handle != device_handle) return error.InvalidHandle;
                    acceleration_handles[acceleration_count] = value._handle;
                    acceleration_count += 1;
                }
                acceleration_infos[write_index] = .{
                    .sType = raw.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET_ACCELERATION_STRUCTURE_KHR,
                    .accelerationStructureCount = @intCast(values.len),
                    .pAccelerationStructures = acceleration_handles[start..acceleration_count].ptr,
                };
                raw_writes[write_index].pNext = &acceleration_infos[write_index];
            },
        }
    }

    for (copies, 0..) |copy, index| {
        if (copy.count == 0 or copy.source._device_handle != device_handle or copy.destination._device_handle != device_handle) return error.InvalidHandle;
        const source_metadata = copy.source.layout.binding(copy.source_binding) orelse return error.InvalidOptions;
        const destination_metadata = copy.destination.layout.binding(copy.destination_binding) orelse return error.InvalidOptions;
        if (source_metadata.descriptor_type != destination_metadata.descriptor_type or
            copy.source_array_element + copy.count > source_metadata.count or
            copy.destination_array_element + copy.count > destination_metadata.count)
        {
            return error.InvalidOptions;
        }
        raw_copies[index] = .{
            .sType = raw.VK_STRUCTURE_TYPE_COPY_DESCRIPTOR_SET,
            .srcSet = try copy.source.rawHandle(),
            .srcBinding = copy.source_binding,
            .srcArrayElement = copy.source_array_element,
            .dstSet = try copy.destination.rawHandle(),
            .dstBinding = copy.destination_binding,
            .dstArrayElement = copy.destination_array_element,
            .descriptorCount = copy.count,
        };
    }
    update_descriptors(
        device_handle,
        @intCast(writes.len),
        if (writes.len == 0) null else raw_writes[0..writes.len].ptr,
        @intCast(copies.len),
        if (copies.len == 0) null else raw_copies[0..copies.len].ptr,
    );
}

pub fn createPool(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: PoolDispatch,
    options: PoolOptions,
) core.Error!Pool {
    if (options.max_sets == 0 or options.sizes.len == 0 or options.sizes.len > 64) return error.InvalidOptions;
    var sizes: [64]raw.VkDescriptorPoolSize = undefined;
    for (options.sizes, 0..) |size, index| {
        if (size.count == 0) return error.InvalidOptions;
        sizes[index] = .{ .type = size.descriptor_type.toRaw(), .descriptorCount = size.count };
    }
    const info: raw.VkDescriptorPoolCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .flags = (if (options.free_individual_sets) @as(raw.VkDescriptorPoolCreateFlags, @intCast(raw.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT)) else 0) |
            (if (options.update_after_bind) @as(raw.VkDescriptorPoolCreateFlags, @intCast(raw.VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT)) else 0),
        .maxSets = options.max_sets,
        .poolSizeCount = @intCast(options.sizes.len),
        .pPoolSizes = sizes[0..options.sizes.len].ptr,
    };
    var handle: raw.VkDescriptorPool = null;
    const result = dispatch.create(device_handle, &info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccess(result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._device_handle = device_handle,
        .free_individual_sets = options.free_individual_sets,
        .allocation_callbacks = allocation_callbacks,
        .dispatch = dispatch,
    };
}

test "all descriptor declarations compile" {
    std.testing.refAllDecls(@This());
}

var test_result: raw.VkResult = raw.VK_SUCCESS;
var test_allocate_count: u32 = 0;
var test_variable_count: u32 = 0;
var test_free_count: usize = 0;
var test_reset_count: usize = 0;
var test_write_count: u32 = 0;
var test_copy_count: u32 = 0;
var test_first_write_type: raw.VkDescriptorType = raw.VK_DESCRIPTOR_TYPE_SAMPLER;
var test_template_update_count: usize = 0;
var test_template_destroy_count: usize = 0;
var test_push_write_count: u32 = 0;
var test_destroy_layout_count: usize = 0;
var test_destroy_pool_count: usize = 0;

fn testCreateLayout(
    _: raw.VkDevice,
    _: [*c]const raw.VkDescriptorSetLayoutCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkDescriptorSetLayout,
) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x2000);
    return test_result;
}

fn testDestroyLayout(_: raw.VkDevice, _: raw.VkDescriptorSetLayout, _: [*c]const raw.VkAllocationCallbacks) callconv(.c) void {
    test_destroy_layout_count += 1;
}

fn testCreatePool(
    _: raw.VkDevice,
    _: [*c]const raw.VkDescriptorPoolCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkDescriptorPool,
) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x3000);
    return test_result;
}

fn testDestroyPool(_: raw.VkDevice, _: raw.VkDescriptorPool, _: [*c]const raw.VkAllocationCallbacks) callconv(.c) void {
    test_destroy_pool_count += 1;
}

fn testResetPool(_: raw.VkDevice, _: raw.VkDescriptorPool, _: raw.VkDescriptorPoolResetFlags) callconv(.c) raw.VkResult {
    test_reset_count += 1;
    return test_result;
}

fn testAllocateSets(
    _: raw.VkDevice,
    info: [*c]const raw.VkDescriptorSetAllocateInfo,
    output: [*c]raw.VkDescriptorSet,
) callconv(.c) raw.VkResult {
    test_allocate_count = info.*.descriptorSetCount;
    test_variable_count = 0;
    if (info.*.pNext) |next| {
        const variable: *const raw.VkDescriptorSetVariableDescriptorCountAllocateInfo = @ptrCast(@alignCast(next));
        if (variable.descriptorSetCount != 0) test_variable_count = variable.pDescriptorCounts[0];
    }
    for (0..info.*.descriptorSetCount) |index| output[index] = @ptrFromInt(0x4000 + index * 0x10);
    return test_result;
}

fn testFreeSets(_: raw.VkDevice, _: raw.VkDescriptorPool, count: u32, _: [*c]const raw.VkDescriptorSet) callconv(.c) raw.VkResult {
    test_free_count += count;
    return test_result;
}

fn testUpdateSets(
    _: raw.VkDevice,
    write_count: u32,
    writes: [*c]const raw.VkWriteDescriptorSet,
    copy_count: u32,
    _: [*c]const raw.VkCopyDescriptorSet,
) callconv(.c) void {
    test_write_count = write_count;
    test_copy_count = copy_count;
    if (write_count != 0) test_first_write_type = writes[0].descriptorType;
}

fn testGetLayoutSupport(
    _: raw.VkDevice,
    _: [*c]const raw.VkDescriptorSetLayoutCreateInfo,
    support: [*c]raw.VkDescriptorSetLayoutSupport,
) callconv(.c) void {
    support.*.supported = raw.VK_TRUE;
    if (support.*.pNext) |next| {
        const variable: *raw.VkDescriptorSetVariableDescriptorCountLayoutSupport = @ptrCast(@alignCast(next));
        variable.maxVariableDescriptorCount = 128;
    }
}

fn testCreateTemplate(
    _: raw.VkDevice,
    _: [*c]const raw.VkDescriptorUpdateTemplateCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkDescriptorUpdateTemplate,
) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x6000);
    return test_result;
}

fn testDestroyTemplate(_: raw.VkDevice, _: raw.VkDescriptorUpdateTemplate, _: [*c]const raw.VkAllocationCallbacks) callconv(.c) void {
    test_template_destroy_count += 1;
}

fn testUpdateTemplate(_: raw.VkDevice, _: raw.VkDescriptorSet, _: raw.VkDescriptorUpdateTemplate, _: ?*const anyopaque) callconv(.c) void {
    test_template_update_count += 1;
}

fn testPushDescriptors(
    _: raw.VkCommandBuffer,
    _: raw.VkPipelineBindPoint,
    _: raw.VkPipelineLayout,
    _: u32,
    write_count: u32,
    _: [*c]const raw.VkWriteDescriptorSet,
) callconv(.c) void {
    test_push_write_count = write_count;
}

test "descriptor layouts pools batches updates and generations remain typed" {
    const device_handle: DeviceHandle = @ptrFromInt(0x1000);
    var layout = try createLayout(device_handle, null, .{
        .create = testCreateLayout,
        .destroy = testDestroyLayout,
    }, .{
        .bindings = &.{.{
            .binding = 0,
            .descriptor_type = .uniform_buffer,
            .count = 4,
            .stages = .init(&.{.compute}),
            .flags = .init(&.{ .partially_bound, .variable_descriptor_count }),
        }},
    });
    defer layout.deinit();
    var pool = try createPool(device_handle, null, .{
        .create = testCreatePool,
        .destroy = testDestroyPool,
        .reset = testResetPool,
        .allocate = testAllocateSets,
        .free = testFreeSets,
    }, .{
        .max_sets = 4,
        .sizes = &.{.{ .descriptor_type = .uniform_buffer, .count = 16 }},
        .free_individual_sets = true,
    });
    defer pool.deinit();

    var sets: [2]Set = undefined;
    const allocated = try pool.allocateMany(&.{
        .{ .layout = &layout, .variable_descriptor_count = 3 },
        .{ .layout = &layout, .variable_descriptor_count = 2 },
    }, &sets);
    try std.testing.expectEqual(@as(u32, 2), test_allocate_count);
    try std.testing.expectEqual(@as(u32, 3), test_variable_count);
    try allocated[1].free();
    try std.testing.expectEqual(@as(usize, 1), test_free_count);

    const owned_buffer: buffer.Buffer = .{
        ._handle = @ptrFromInt(0x5000),
        ._device_handle = device_handle,
        .size = .fromBytes(256),
        .allocation_callbacks = null,
        .dispatch = undefined,
    };
    test_write_count = 0;
    test_copy_count = 0;
    try update(device_handle, testUpdateSets, &.{.{
        .destination = &allocated[0],
        .binding = 0,
        .data = .{ .uniform_buffer = &.{.{
            .buffer = &owned_buffer,
            .offset = .fromBytes(16),
            .range = .{ .bytes = .fromBytes(64) },
        }} },
    }}, &.{.{
        .source = &allocated[0],
        .source_binding = 0,
        .destination = &allocated[0],
        .destination_binding = 0,
        .count = 1,
    }});
    try std.testing.expectEqual(@as(u32, 1), test_write_count);
    try std.testing.expectEqual(@as(u32, 1), test_copy_count);
    try std.testing.expectEqual(@as(raw.VkDescriptorType, @intCast(raw.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER)), test_first_write_type);
    try std.testing.expectError(error.InvalidOptions, update(device_handle, testUpdateSets, &.{.{
        .destination = &allocated[0],
        .binding = 0,
        .array_element = 3,
        .data = .{ .uniform_buffer = &.{.{ .buffer = &owned_buffer }} },
    }}, &.{}));

    const foreign_buffer: buffer.Buffer = .{
        ._handle = @ptrFromInt(0x5100),
        ._device_handle = @ptrFromInt(0x9999),
        .size = .fromBytes(256),
        .allocation_callbacks = null,
        .dispatch = undefined,
    };
    try std.testing.expectError(error.InvalidHandle, update(device_handle, testUpdateSets, &.{.{
        .destination = &allocated[0],
        .binding = 0,
        .data = .{ .uniform_buffer = &.{.{ .buffer = &foreign_buffer }} },
    }}, &.{}));

    var foreign_layout = layout;
    foreign_layout._device_handle = @ptrFromInt(0x9999);
    try std.testing.expectError(error.InvalidHandle, pool.allocate(&foreign_layout));
    test_result = raw.VK_ERROR_FRAGMENTED_POOL;
    try std.testing.expectError(error.FragmentedPool, pool.allocate(&layout));
    test_result = raw.VK_SUCCESS;

    try pool.reset();
    try std.testing.expectEqual(@as(usize, 1), test_reset_count);
    try std.testing.expectError(error.InactiveObject, allocated[0].rawHandle());
}

test "descriptor support templates and push writes hide pointer graphs" {
    const device_handle: DeviceHandle = @ptrFromInt(0x1000);
    const binding: Binding = .{
        .binding = 0,
        .descriptor_type = .uniform_buffer,
        .count = 4,
        .stages = .init(&.{.compute}),
        .flags = .init(&.{.variable_descriptor_count}),
    };
    const support = try queryLayoutSupport(device_handle, testGetLayoutSupport, .{ .bindings = &.{binding} });
    try std.testing.expect(support.supported);
    try std.testing.expectEqual(@as(u32, 128), support.max_variable_descriptor_count);

    test_destroy_layout_count = 0;
    test_result = raw.VK_ERROR_OUT_OF_HOST_MEMORY;
    try std.testing.expectError(error.OutOfHostMemory, createLayout(device_handle, null, .{ .create = testCreateLayout, .destroy = testDestroyLayout }, .{ .bindings = &.{binding} }));
    try std.testing.expectEqual(@as(usize, 1), test_destroy_layout_count);
    test_result = raw.VK_SUCCESS;

    var layout = try createLayout(device_handle, null, .{ .create = testCreateLayout, .destroy = testDestroyLayout }, .{ .bindings = &.{binding} });
    defer layout.deinit();
    test_destroy_pool_count = 0;
    test_result = raw.VK_ERROR_OUT_OF_DEVICE_MEMORY;
    try std.testing.expectError(error.OutOfDeviceMemory, createPool(device_handle, null, .{ .create = testCreatePool, .destroy = testDestroyPool, .reset = testResetPool, .allocate = testAllocateSets, .free = testFreeSets }, .{
        .max_sets = 1,
        .sizes = &.{.{ .descriptor_type = .uniform_buffer, .count = 4 }},
    }));
    try std.testing.expectEqual(@as(usize, 1), test_destroy_pool_count);
    test_result = raw.VK_SUCCESS;
    var pool = try createPool(device_handle, null, .{ .create = testCreatePool, .destroy = testDestroyPool, .reset = testResetPool, .allocate = testAllocateSets, .free = testFreeSets }, .{
        .max_sets = 1,
        .sizes = &.{.{ .descriptor_type = .uniform_buffer, .count = 4 }},
    });
    defer pool.deinit();
    var set = try pool.allocateOptions(.{ .layout = &layout, .variable_descriptor_count = 4 });
    const owned_buffer: buffer.Buffer = .{ ._handle = @ptrFromInt(0x5000), ._device_handle = device_handle, .size = .fromBytes(256), .allocation_callbacks = null, .dispatch = undefined };

    test_template_update_count = 0;
    test_template_destroy_count = 0;
    var template = try createUpdateTemplate(device_handle, null, .{
        .create = testCreateTemplate,
        .destroy = testDestroyTemplate,
        .update = testUpdateTemplate,
    }, .{
        .layout = &layout,
        .entries = &.{.{ .binding = 0 }},
    });
    try template.update(&set, &.{.{ .uniform_buffer = &.{.{ .buffer = &owned_buffer, .range = .{ .bytes = .fromBytes(64) } }} }});
    try std.testing.expectEqual(@as(usize, 1), test_template_update_count);
    template.deinit();
    template.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_template_destroy_count);

    var push_layout = try createLayout(device_handle, null, .{ .create = testCreateLayout, .destroy = testDestroyLayout }, .{
        .bindings = &.{.{ .binding = 0, .descriptor_type = .uniform_buffer, .stages = .init(&.{.compute}) }},
        .push_descriptor = true,
    });
    defer push_layout.deinit();
    test_push_write_count = 0;
    try push(device_handle, testPushDescriptors, @ptrFromInt(0x7000), raw.VK_PIPELINE_BIND_POINT_COMPUTE, @ptrFromInt(0x8000), 0, &push_layout, &.{.{
        .binding = 0,
        .data = .{ .uniform_buffer = &.{.{ .buffer = &owned_buffer, .range = .{ .bytes = .fromBytes(64) } }} },
    }});
    try std.testing.expectEqual(@as(u32, 1), test_push_write_count);
}
