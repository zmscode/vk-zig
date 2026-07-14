const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const shader = @import("shader.zig");
const sampler = @import("sampler.zig");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const LayoutHandle = core.NonNullHandle(raw.VkDescriptorSetLayout);
const PoolHandle = core.NonNullHandle(raw.VkDescriptorPool);
const SetHandle = core.NonNullHandle(raw.VkDescriptorSet);
const binding_count_max = 64;
const immutable_sampler_count_max = 256;

pub const Type = enum {
    sampler,
    combined_image_sampler,
    sampled_image,
    storage_image,
    uniform_texel_buffer,
    storage_texel_buffer,
    uniform_buffer,
    storage_buffer,
    uniform_buffer_dynamic,
    storage_buffer_dynamic,
    input_attachment,
    inline_uniform_block,
    acceleration_structure,

    fn toRaw(value: Type) raw.VkDescriptorType {
        return switch (value) {
            .sampler => raw.VK_DESCRIPTOR_TYPE_SAMPLER,
            .combined_image_sampler => raw.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            .sampled_image => raw.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
            .storage_image => raw.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .uniform_texel_buffer => raw.VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER,
            .storage_texel_buffer => raw.VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER,
            .uniform_buffer => raw.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .storage_buffer => raw.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .uniform_buffer_dynamic => raw.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC,
            .storage_buffer_dynamic => raw.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC,
            .input_attachment => raw.VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT,
            .inline_uniform_block => raw.VK_DESCRIPTOR_TYPE_INLINE_UNIFORM_BLOCK,
            .acceleration_structure => raw.VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR,
        };
    }
};

pub const Binding = struct {
    binding: u32,
    descriptor_type: Type,
    count: u32 = 1,
    stages: shader.StageSet,
    immutable_samplers: []const *const sampler.Sampler = &.{},
};

pub const LayoutOptions = struct {
    bindings: []const Binding,
    push_descriptor: bool = false,
};

pub const Dispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateDescriptorSetLayout),
    destroy: CommandFunction(raw.PFN_vkDestroyDescriptorSetLayout),
};

pub const SetLayout = struct {
    _handle: ?LayoutHandle,
    _device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_layout: CommandFunction(raw.PFN_vkDestroyDescriptorSetLayout),

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
};

pub fn createLayout(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,
    options: LayoutOptions,
) core.Error!SetLayout {
    if (options.bindings.len > binding_count_max) return error.CountOverflow;
    var raw_bindings: [binding_count_max]raw.VkDescriptorSetLayoutBinding = undefined;
    var immutable_handles: [immutable_sampler_count_max]raw.VkSampler = undefined;
    var immutable_count: usize = 0;
    for (options.bindings, 0..) |binding, index| {
        if (binding.count == 0 or binding.stages.toRaw() == 0) return error.InvalidOptions;
        for (options.bindings[0..index]) |previous| {
            if (previous.binding == binding.binding) return error.InvalidOptions;
        }
        if (binding.immutable_samplers.len != 0 and binding.immutable_samplers.len != binding.count) {
            return error.InvalidOptions;
        }
        const immutable_start = immutable_count;
        if (binding.immutable_samplers.len > immutable_handles.len - immutable_count) return error.CountOverflow;
        for (binding.immutable_samplers) |item| {
            if (item._device_handle != device_handle) return error.InvalidHandle;
            immutable_handles[immutable_count] = try item.rawHandle();
            immutable_count += 1;
        }
        raw_bindings[index] = .{
            .binding = binding.binding,
            .descriptorType = binding.descriptor_type.toRaw(),
            .descriptorCount = binding.count,
            .stageFlags = binding.stages.toRaw(),
            .pImmutableSamplers = if (binding.immutable_samplers.len == 0) null else immutable_handles[immutable_start..immutable_count].ptr,
        };
    }
    const info: raw.VkDescriptorSetLayoutCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .flags = if (options.push_descriptor) @intCast(raw.VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT) else 0,
        .bindingCount = @intCast(options.bindings.len),
        .pBindings = if (options.bindings.len == 0) null else raw_bindings[0..options.bindings.len].ptr,
    };
    var handle: raw.VkDescriptorSetLayout = null;
    const result = dispatch.create(device_handle, &info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccess(result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._device_handle = device_handle,
        .allocation_callbacks = allocation_callbacks,
        .destroy_layout = dispatch.destroy,
    };
}

pub const PoolSize = struct { descriptor_type: Type, count: u32 };
pub const PoolOptions = struct {
    max_sets: u32,
    sizes: []const PoolSize,
    free_individual_sets: bool = false,
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
        const pool_handle = pool._handle orelse return error.InactiveObject;
        if (layout._device_handle != pool._device_handle) return error.InvalidHandle;
        const layout_handle = try layout.rawHandle();
        const info: raw.VkDescriptorSetAllocateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
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
            .layout_handle = layout_handle,
        };
    }

    pub fn debugObject(pool: *const Pool) core.Error!debug_utils.Object {
        return .forDevice(.descriptor_pool, pool._handle orelse return error.InactiveObject, pool._device_handle);
    }
};

pub const Set = struct {
    _handle: ?SetHandle,
    _device_handle: DeviceHandle,
    _pool: *Pool,
    _pool_generation: u64,
    layout_handle: LayoutHandle,

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

    pub fn debugObject(set: *const Set) core.Error!debug_utils.Object {
        return .forDevice(.descriptor_set, try set.rawHandle(), set._device_handle);
    }
};

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
        .flags = if (options.free_individual_sets) @intCast(raw.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT) else 0,
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
    @import("std").testing.refAllDecls(@This());
}
