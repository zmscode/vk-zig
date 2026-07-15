//! Typed `VK_EXT_shader_object` ownership, binary, and binding support.

const std = @import("std");
const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const commands = @import("command_buffer.zig");
const debug_utils = @import("debug_utils.zig");
const descriptors = @import("descriptor.zig");
const pipelines = @import("pipeline.zig");
const shaders = @import("shader.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const ShaderHandle = core.NonNullHandle(raw.VkShaderEXT);
const layout_count_max = 32;
const push_constant_count_max = 32;
const specialization_count_max = 256;
const binding_count_max = 32;

pub const extension = command.DeviceExtension.ext_shader_object;
pub const Features = types.extension_features.ShaderObjectFeaturesEXT;

pub const Properties = struct {
    binary_uuid: [raw.VK_UUID_SIZE]u8,
    binary_version: u32,

    pub fn fromRaw(value: raw.VkPhysicalDeviceShaderObjectPropertiesEXT) Properties {
        return .{ .binary_uuid = value.shaderBinaryUUID, .binary_version = value.shaderBinaryVersion };
    }
};

pub const Code = union(enum) {
    spirv: []const u32,
    binary: []const u8,
};

pub const CreateFlag = enum {
    link_stage,
    allow_varying_subgroup_size,
    require_full_subgroups,
    no_task_shader,
    dispatch_base,
    fragment_shading_rate_attachment,
    fragment_density_map_attachment,
    indirect_bindable,
    opacity_micromap_disallow_mixed_special_index,
    indexing_64_bit,
    independent_sets,
};

pub const CreateFlags = struct {
    bits: std.EnumSet(CreateFlag) = .initEmpty(),
    pub const empty: CreateFlags = .{};

    pub fn init(values: []const CreateFlag) CreateFlags {
        var result: CreateFlags = .{};
        for (values) |value| result.bits.insert(value);
        return result;
    }

    fn toRaw(flags: CreateFlags) raw.VkShaderCreateFlagsEXT {
        var result: raw.VkShaderCreateFlagsEXT = 0;
        inline for (std.meta.tags(CreateFlag)) |flag| {
            if (flags.bits.contains(flag)) result |= switch (flag) {
                .link_stage => raw.VK_SHADER_CREATE_LINK_STAGE_BIT_EXT,
                .allow_varying_subgroup_size => raw.VK_SHADER_CREATE_ALLOW_VARYING_SUBGROUP_SIZE_BIT_EXT,
                .require_full_subgroups => raw.VK_SHADER_CREATE_REQUIRE_FULL_SUBGROUPS_BIT_EXT,
                .no_task_shader => raw.VK_SHADER_CREATE_NO_TASK_SHADER_BIT_EXT,
                .dispatch_base => raw.VK_SHADER_CREATE_DISPATCH_BASE_BIT_EXT,
                .fragment_shading_rate_attachment => raw.VK_SHADER_CREATE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_EXT,
                .fragment_density_map_attachment => raw.VK_SHADER_CREATE_FRAGMENT_DENSITY_MAP_ATTACHMENT_BIT_EXT,
                .indirect_bindable => raw.VK_SHADER_CREATE_INDIRECT_BINDABLE_BIT_EXT,
                .opacity_micromap_disallow_mixed_special_index => raw.VK_SHADER_CREATE_OPACITY_MICROMAP_DISALLOW_MIXED_SPECIAL_INDEX_BIT_EXT,
                .indexing_64_bit => raw.VK_SHADER_CREATE_64_BIT_INDEXING_BIT_EXT,
                .independent_sets => raw.VK_SHADER_CREATE_INDEPENDENT_SETS_BIT_EXT,
            };
        }
        return result;
    }
};

pub const Options = struct {
    stage: shaders.Stage,
    next_stages: shaders.StageSet = .empty,
    code: Code,
    entry_point: [:0]const u8 = "main",
    set_layouts: []const *const descriptors.SetLayout = &.{},
    push_constants: []const pipelines.PushConstantRange = &.{},
    specialization: ?shaders.Specialization = null,
    flags: CreateFlags = .empty,
};

pub const Shader = struct {
    _handle: ?ShaderHandle,
    _owner: core.Owner,
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    stage: shaders.Stage,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _destroy: CommandFunction(raw.PFN_vkDestroyShaderEXT),
    _binary: CommandFunction(raw.PFN_vkGetShaderBinaryDataEXT),

    pub fn deinit(shader: *Shader) void {
        if (!(shader._owner.release(shader) catch return)) return;
        const handle = shader._handle orelse return;
        shader._destroy(shader._device, handle, shader.allocation_callbacks);
        shader._handle = null;
    }

    pub fn rawHandle(shader: *const Shader) core.Error!raw.VkShaderEXT {
        try shader._owner.validate(shader);
        try shader._state.ensureDispatchAllowed();
        return shader._handle orelse error.InactiveObject;
    }

    pub fn debugObject(shader: *const Shader) core.Error!debug_utils.Object {
        return .forDevice(.shader, try shader.rawHandle(), shader._device);
    }

    pub fn binarySize(shader: *const Shader) core.Error!usize {
        var size: usize = 0;
        try core.checkSuccess(shader._binary(shader._device, try shader.rawHandle(), &size, null));
        return size;
    }

    pub fn binaryInto(shader: *const Shader, destination: []u8) core.Error![]u8 {
        var size = destination.len;
        const result = shader._binary(shader._device, try shader.rawHandle(), &size, destination.ptr);
        if (result != raw.VK_SUCCESS and result != raw.VK_INCOMPLETE) try core.checkSuccess(result);
        if (size > destination.len) return error.CapacityExceeded;
        return destination[0..size];
    }

    pub fn binary(shader: *const Shader, allocator: std.mem.Allocator) (core.Error || std.mem.Allocator.Error)![]u8 {
        const result = try allocator.alloc(u8, try shader.binarySize());
        errdefer allocator.free(result);
        return shader.binaryInto(result);
    }
};

pub const Binding = struct { stage: shaders.Stage, shader: ?*const Shader = null };

pub const Context = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _create: ?CommandFunction(raw.PFN_vkCreateShadersEXT),
    _destroy: ?CommandFunction(raw.PFN_vkDestroyShaderEXT),
    _binary: ?CommandFunction(raw.PFN_vkGetShaderBinaryDataEXT),
    _bind: ?CommandFunction(raw.PFN_vkCmdBindShadersEXT),

    pub fn create(context: Context, options: Options) core.Error!Shader {
        try context._state.ensureDispatchAllowed();
        const create_command = context._create orelse return error.MissingCommand;
        const destroy = context._destroy orelse return error.MissingCommand;
        const get_binary = context._binary orelse return error.MissingCommand;
        if (options.set_layouts.len > layout_count_max or options.push_constants.len > push_constant_count_max) return error.InvalidOptions;

        var raw_layouts: [layout_count_max]raw.VkDescriptorSetLayout = undefined;
        for (options.set_layouts, 0..) |layout, index| {
            if (layout._device_handle != context._device) return error.InvalidOptions;
            raw_layouts[index] = try layout.rawHandle();
        }
        var raw_ranges: [push_constant_count_max]raw.VkPushConstantRange = undefined;
        for (options.push_constants, 0..) |range, index| raw_ranges[index] = .{
            .stageFlags = range.stages.toRaw(),
            .offset = range.offset,
            .size = range.size,
        };
        var entries: [specialization_count_max]raw.VkSpecializationMapEntry = undefined;
        var specialization: raw.VkSpecializationInfo = .{};
        var specialization_pointer: [*c]const raw.VkSpecializationInfo = null;
        if (options.specialization) |value| {
            try value.validate();
            if (value.entries.len > entries.len) return error.InvalidOptions;
            for (value.entries, 0..) |entry, index| entries[index] = .{
                .constantID = entry.constant_id,
                .offset = @intCast(entry.offset),
                .size = entry.size,
            };
            specialization = .{
                .mapEntryCount = @intCast(value.entries.len),
                .pMapEntries = entries[0..value.entries.len].ptr,
                .dataSize = value.data.len,
                .pData = value.data.ptr,
            };
            specialization_pointer = &specialization;
        }
        const code_size, const code_pointer: *const anyopaque, const code_type: raw.VkShaderCodeTypeEXT = switch (options.code) {
            .spirv => |words| blk: {
                if (words.len == 0 or words[0] != shaders.spirv_magic) return error.InvalidShader;
                break :blk .{ std.math.mul(usize, words.len, @sizeOf(u32)) catch return error.SizeOverflow, words.ptr, raw.VK_SHADER_CODE_TYPE_SPIRV_EXT };
            },
            .binary => |bytes| blk: {
                if (bytes.len == 0) return error.InvalidShader;
                break :blk .{ bytes.len, bytes.ptr, raw.VK_SHADER_CODE_TYPE_BINARY_EXT };
            },
        };
        const info: raw.VkShaderCreateInfoEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_SHADER_CREATE_INFO_EXT,
            .flags = options.flags.toRaw(),
            .stage = options.stage.toRaw(),
            .nextStage = options.next_stages.toRaw(),
            .codeType = code_type,
            .codeSize = code_size,
            .pCode = code_pointer,
            .pName = options.entry_point.ptr,
            .setLayoutCount = @intCast(options.set_layouts.len),
            .pSetLayouts = raw_layouts[0..options.set_layouts.len].ptr,
            .pushConstantRangeCount = @intCast(options.push_constants.len),
            .pPushConstantRanges = raw_ranges[0..options.push_constants.len].ptr,
            .pSpecializationInfo = specialization_pointer,
        };
        var handle: raw.VkShaderEXT = null;
        const result = create_command(context._device, 1, &info, context._allocation_callbacks, &handle);
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional| destroy(context._device, provisional, context._allocation_callbacks);
            try core.checkSuccess(result);
        }
        return .{ ._handle = handle orelse return error.InvalidHandle, ._owner = try .init(&handle), ._device = context._device, ._state = context._state, .stage = options.stage, .allocation_callbacks = context._allocation_callbacks, ._destroy = destroy, ._binary = get_binary };
    }

    pub fn bind(context: Context, command_buffer: *commands.Buffer, bindings: []const Binding) core.Error!void {
        const bind_command = context._bind orelse return error.MissingCommand;
        if (command_buffer._device_handle != context._device or command_buffer.state != .recording or bindings.len == 0 or bindings.len > binding_count_max) return error.InvalidOptions;
        var stages: [binding_count_max]raw.VkShaderStageFlagBits = undefined;
        var handles: [binding_count_max]raw.VkShaderEXT = undefined;
        for (bindings, 0..) |binding, index| {
            stages[index] = binding.stage.toRaw();
            handles[index] = if (binding.shader) |shader| blk: {
                if (shader._device != context._device or shader.stage != binding.stage) return error.InvalidOptions;
                break :blk try shader.rawHandle();
            } else null;
        }
        bind_command(try command_buffer.rawHandle(), @intCast(bindings.len), stages[0..bindings.len].ptr, handles[0..bindings.len].ptr);
    }
};

test "shader flags and code remain typed" {
    const flags = CreateFlags.init(&.{ .link_stage, .indirect_bindable });
    try std.testing.expect((flags.toRaw() & raw.VK_SHADER_CREATE_LINK_STAGE_BIT_EXT) != 0);
    try std.testing.expect((flags.toRaw() & raw.VK_SHADER_CREATE_INDIRECT_BINDABLE_BIT_EXT) != 0);
    try std.testing.expect(extension == command.DeviceExtension.ext_shader_object);
}

test "unavailable shader object command reports MissingCommand" {
    var state = try core.DeviceState.init();
    defer state.markDestroyed();
    var context: Context = undefined;
    context._state = &state;
    context._create = null;
    try std.testing.expectError(error.MissingCommand, context.create(undefined));
    context._bind = null;
    try std.testing.expectError(error.MissingCommand, context.bind(undefined, &.{}));
}
