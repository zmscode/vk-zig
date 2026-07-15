const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const ShaderModuleHandle = core.NonNullHandle(raw.VkShaderModule);

pub const spirv_magic: u32 = 0x0723_0203;

pub const Stage = enum {
    vertex,
    tessellation_control,
    tessellation_evaluation,
    geometry,
    fragment,
    compute,
    task,
    mesh,
    ray_generation,
    any_hit,
    closest_hit,
    miss,
    intersection,
    callable,

    pub fn toRaw(stage: Stage) raw.VkShaderStageFlagBits {
        return switch (stage) {
            .vertex => raw.VK_SHADER_STAGE_VERTEX_BIT,
            .tessellation_control => raw.VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT,
            .tessellation_evaluation => raw.VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT,
            .geometry => raw.VK_SHADER_STAGE_GEOMETRY_BIT,
            .fragment => raw.VK_SHADER_STAGE_FRAGMENT_BIT,
            .compute => raw.VK_SHADER_STAGE_COMPUTE_BIT,
            .task => raw.VK_SHADER_STAGE_TASK_BIT_EXT,
            .mesh => raw.VK_SHADER_STAGE_MESH_BIT_EXT,
            .ray_generation => raw.VK_SHADER_STAGE_RAYGEN_BIT_KHR,
            .any_hit => raw.VK_SHADER_STAGE_ANY_HIT_BIT_KHR,
            .closest_hit => raw.VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR,
            .miss => raw.VK_SHADER_STAGE_MISS_BIT_KHR,
            .intersection => raw.VK_SHADER_STAGE_INTERSECTION_BIT_KHR,
            .callable => raw.VK_SHADER_STAGE_CALLABLE_BIT_KHR,
        };
    }
};

pub const StageSet = struct {
    bits: std.EnumSet(Stage) = .initEmpty(),

    pub const empty: StageSet = .{};

    pub fn init(stages: []const Stage) StageSet {
        var set: StageSet = .{};
        for (stages) |stage| set.bits.insert(stage);
        return set;
    }

    pub fn contains(set: StageSet, stage: Stage) bool {
        return set.bits.contains(stage);
    }

    pub fn intersects(a: StageSet, b: StageSet) bool {
        inline for (std.meta.tags(Stage)) |stage| {
            if (a.contains(stage) and b.contains(stage)) return true;
        }
        return false;
    }

    pub fn toRaw(set: StageSet) raw.VkShaderStageFlags {
        var flags: raw.VkShaderStageFlags = 0;
        inline for (std.meta.tags(Stage)) |stage| {
            if (set.contains(stage)) flags |= @intCast(stage.toRaw());
        }
        return flags;
    }
};

pub const SpecializationEntry = struct {
    constant_id: u32,
    offset: usize,
    size: usize,
};

pub const Specialization = struct {
    entries: []const SpecializationEntry,
    data: []const u8,

    pub fn validate(specialization: Specialization) core.Error!void {
        if (specialization.entries.len > std.math.maxInt(u32)) return error.CountOverflow;
        for (specialization.entries, 0..) |entry, index| {
            if (entry.offset > std.math.maxInt(u32) or entry.size == 0 or entry.offset > specialization.data.len or
                entry.size > specialization.data.len - entry.offset)
            {
                return error.InvalidOptions;
            }
            for (specialization.entries[0..index]) |previous| {
                if (previous.constant_id == entry.constant_id) return error.InvalidOptions;
            }
        }
    }
};

pub const StageOptions = struct {
    stage: Stage,
    module: *const Module,
    entry_point: [:0]const u8 = "main",
    specialization: ?Specialization = null,
};

pub const Identifier = struct {
    bytes: [raw.VK_MAX_SHADER_MODULE_IDENTIFIER_SIZE_EXT]u8,
    length: u32,

    pub fn slice(identifier: *const Identifier) []const u8 {
        return identifier.bytes[0..identifier.length];
    }
};

pub const Dispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateShaderModule),
    destroy: CommandFunction(raw.PFN_vkDestroyShaderModule),
    get_identifier: ?CommandFunction(raw.PFN_vkGetShaderModuleIdentifierEXT),
    get_create_info_identifier: ?CommandFunction(raw.PFN_vkGetShaderModuleCreateInfoIdentifierEXT),
};

pub const Module = struct {
    _handle: ?ShaderModuleHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,

    pub fn deinit(module: *Module) void {
        if (!(module._owner.release(module) catch return)) return;
        const handle = module._handle orelse return;
        module.dispatch.destroy(module._device_handle, handle, module.allocation_callbacks);
        module._handle = null;
    }

    pub fn rawHandle(module: *const Module) core.Error!raw.VkShaderModule {
        try module._owner.validate(module);
        if (module._device_state) |*state| try state.ensureDispatchAllowed();
        return module._handle orelse error.InactiveObject;
    }

    pub fn identifier(module: *const Module) core.Error!Identifier {
        const get_identifier = module.dispatch.get_identifier orelse return error.MissingCommand;
        var raw_identifier: raw.VkShaderModuleIdentifierEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_SHADER_MODULE_IDENTIFIER_EXT,
        };
        get_identifier(module._device_handle, try module.rawHandle(), &raw_identifier);
        if (raw_identifier.identifierSize > raw.VK_MAX_SHADER_MODULE_IDENTIFIER_SIZE_EXT) {
            return error.InvalidProperties;
        }
        return .{ .bytes = raw_identifier.identifier, .length = raw_identifier.identifierSize };
    }

    pub fn debugObject(module: *const Module) core.Error!debug_utils.Object {
        return .forDevice(.shader_module, try module.rawHandle(), module._device_handle);
    }
};

pub fn createWords(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,
    words: []const u32,
) core.Error!Module {
    try validateSpirv(words);
    const info: raw.VkShaderModuleCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = std.math.mul(usize, words.len, @sizeOf(u32)) catch return error.SizeOverflow,
        .pCode = words.ptr,
    };
    var handle: raw.VkShaderModule = null;
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

pub fn createBytes(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,
    bytes: []align(4) const u8,
) core.Error!Module {
    if (bytes.len % @sizeOf(u32) != 0) return error.InvalidOptions;
    const words: []const u32 = @as([*]const u32, @ptrCast(bytes.ptr))[0 .. bytes.len / @sizeOf(u32)];
    return createWords(device_handle, allocation_callbacks, dispatch, words);
}

pub fn identifyWords(device_handle: DeviceHandle, dispatch: Dispatch, words: []const u32) core.Error!Identifier {
    try validateSpirv(words);
    const get_identifier = dispatch.get_create_info_identifier orelse return error.MissingCommand;
    const info: raw.VkShaderModuleCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = std.math.mul(usize, words.len, @sizeOf(u32)) catch return error.SizeOverflow,
        .pCode = words.ptr,
    };
    var raw_identifier: raw.VkShaderModuleIdentifierEXT = .{
        .sType = raw.VK_STRUCTURE_TYPE_SHADER_MODULE_IDENTIFIER_EXT,
    };
    get_identifier(device_handle, &info, &raw_identifier);
    if (raw_identifier.identifierSize > raw.VK_MAX_SHADER_MODULE_IDENTIFIER_SIZE_EXT) return error.InvalidProperties;
    return .{ .bytes = raw_identifier.identifier, .length = raw_identifier.identifierSize };
}

pub fn identifyBytes(device_handle: DeviceHandle, dispatch: Dispatch, bytes: []align(4) const u8) core.Error!Identifier {
    if (bytes.len % @sizeOf(u32) != 0) return error.InvalidOptions;
    const words: []const u32 = @as([*]const u32, @ptrCast(bytes.ptr))[0 .. bytes.len / @sizeOf(u32)];
    return identifyWords(device_handle, dispatch, words);
}

pub fn validateSpirv(words: []const u32) core.Error!void {
    if (words.len < 5 or words[0] != spirv_magic or words[3] == 0 or words[4] != 0) {
        return error.InvalidOptions;
    }
    const major = (words[1] >> 16) & 0xff;
    const minor = (words[1] >> 8) & 0xff;
    if (major == 0 or major > 1 or minor > 6) return error.InvalidOptions;
}

test "all shader declarations compile" {
    std.testing.refAllDecls(@This());
}

var test_result: raw.VkResult = raw.VK_SUCCESS;
var test_destroy_count: usize = 0;

fn testCreate(_: raw.VkDevice, _: [*c]const raw.VkShaderModuleCreateInfo, _: [*c]const raw.VkAllocationCallbacks, output: [*c]raw.VkShaderModule) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x2000);
    return test_result;
}

fn testDestroy(_: raw.VkDevice, _: raw.VkShaderModule, _: [*c]const raw.VkAllocationCallbacks) callconv(.c) void {
    test_destroy_count += 1;
}

fn testIdentify(_: raw.VkDevice, _: [*c]const raw.VkShaderModuleCreateInfo, output: [*c]raw.VkShaderModuleIdentifierEXT) callconv(.c) void {
    output.*.identifierSize = 4;
    output.*.identifier[0..4].* = .{ 1, 2, 3, 4 };
}

test "shader words, bytes, specialization, identifiers, and rollback are validated" {
    const words align(4) = [_]u32{ spirv_magic, 0x0001_0000, 0, 1, 0 };
    const dispatch: Dispatch = .{ .create = testCreate, .destroy = testDestroy, .get_identifier = null, .get_create_info_identifier = testIdentify };
    var module = try createWords(@ptrFromInt(0x1000), null, dispatch, &words);
    module.deinit();
    try std.testing.expectError(error.InvalidOptions, createBytes(@ptrFromInt(0x1000), null, dispatch, std.mem.asBytes(&words)[0..19]));
    const identifier = try identifyWords(@ptrFromInt(0x1000), dispatch, &words);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, identifier.slice());
    try (Specialization{ .entries = &.{.{ .constant_id = 0, .offset = 0, .size = 4 }}, .data = std.mem.asBytes(&words[0]) }).validate();
    try std.testing.expectError(error.InvalidOptions, (Specialization{ .entries = &.{ .{ .constant_id = 0, .offset = 0, .size = 4 }, .{ .constant_id = 0, .offset = 4, .size = 4 } }, .data = std.mem.asBytes(&words) }).validate());

    test_result = raw.VK_ERROR_OUT_OF_DEVICE_MEMORY;
    defer test_result = raw.VK_SUCCESS;
    test_destroy_count = 0;
    try std.testing.expectError(error.OutOfDeviceMemory, createWords(@ptrFromInt(0x1000), null, dispatch, &words));
    try std.testing.expectEqual(@as(usize, 1), test_destroy_count);
}
