const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");
const shader = @import("shader.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const CacheHandle = core.NonNullHandle(raw.VkPipelineCache);
const DeferredHandle = core.NonNullHandle(raw.VkDeferredOperationKHR);
const BinaryHandle = core.NonNullHandle(raw.VkPipelineBinaryKHR);

pub const executable_item_count_max = 256;

pub const ExecutableDispatch = struct {
    properties: CommandFunction(raw.PFN_vkGetPipelineExecutablePropertiesKHR),
    statistics: CommandFunction(raw.PFN_vkGetPipelineExecutableStatisticsKHR),
    internal_representations: CommandFunction(raw.PFN_vkGetPipelineExecutableInternalRepresentationsKHR),
};

pub const Executable = struct {
    index: u32,
    stages: shader.StageSet,
    name_buffer: [raw.VK_MAX_DESCRIPTION_SIZE]u8,
    description_buffer: [raw.VK_MAX_DESCRIPTION_SIZE]u8,
    subgroup_size: u32,

    pub fn name(value: *const Executable) []const u8 {
        return std.mem.sliceTo(&value.name_buffer, 0);
    }

    pub fn description(value: *const Executable) []const u8 {
        return std.mem.sliceTo(&value.description_buffer, 0);
    }
};

pub const StatisticValue = union(enum) {
    boolean: bool,
    signed: i64,
    unsigned: u64,
    float: f64,
};

pub const Statistic = struct {
    name_buffer: [raw.VK_MAX_DESCRIPTION_SIZE]u8,
    description_buffer: [raw.VK_MAX_DESCRIPTION_SIZE]u8,
    value: StatisticValue,

    pub fn name(statistic: *const Statistic) []const u8 {
        return std.mem.sliceTo(&statistic.name_buffer, 0);
    }

    pub fn description(statistic: *const Statistic) []const u8 {
        return std.mem.sliceTo(&statistic.description_buffer, 0);
    }
};

pub const InternalRepresentation = struct {
    name_buffer: [raw.VK_MAX_DESCRIPTION_SIZE]u8 = @splat(0),
    description_buffer: [raw.VK_MAX_DESCRIPTION_SIZE]u8 = @splat(0),
    is_text: bool = false,
    data: []u8,

    pub fn name(representation: *const InternalRepresentation) []const u8 {
        return std.mem.sliceTo(&representation.name_buffer, 0);
    }

    pub fn description(representation: *const InternalRepresentation) []const u8 {
        return std.mem.sliceTo(&representation.description_buffer, 0);
    }
};

fn executableInfo(pipeline: raw.VkPipeline, executable_index: u32) raw.VkPipelineExecutableInfoKHR {
    return .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_EXECUTABLE_INFO_KHR,
        .pipeline = pipeline,
        .executableIndex = executable_index,
    };
}

fn stagesFromRaw(bits: raw.VkShaderStageFlags) shader.StageSet {
    var stages: shader.StageSet = .{};
    inline for (std.meta.tags(shader.Stage)) |stage| {
        if (bits & stage.toRaw() != 0) stages.bits.insert(stage);
    }
    return stages;
}

pub fn executableCount(
    device: DeviceHandle,
    pipeline: raw.VkPipeline,
    get: CommandFunction(raw.PFN_vkGetPipelineExecutablePropertiesKHR),
) core.Error!u32 {
    const info: raw.VkPipelineInfoKHR = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_INFO_KHR,
        .pipeline = pipeline,
    };
    var count: u32 = 0;
    try core.checkSuccess(get(device, &info, &count, null));
    if (count > executable_item_count_max) return error.TooManyObjects;
    return count;
}

pub fn executablesInto(
    device: DeviceHandle,
    pipeline: raw.VkPipeline,
    get: CommandFunction(raw.PFN_vkGetPipelineExecutablePropertiesKHR),
    storage: []Executable,
) core.Error![]Executable {
    if (storage.len > executable_item_count_max) return error.CountOverflow;
    var values: [executable_item_count_max]raw.VkPipelineExecutablePropertiesKHR = undefined;
    for (values[0..storage.len]) |*value| value.* = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_EXECUTABLE_PROPERTIES_KHR,
    };
    const info: raw.VkPipelineInfoKHR = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_INFO_KHR,
        .pipeline = pipeline,
    };
    var count: u32 = @intCast(storage.len);
    const result = get(device, &info, &count, if (storage.len == 0) null else values[0..storage.len].ptr);
    if (result == raw.VK_INCOMPLETE or count > storage.len) return error.BufferTooSmall;
    try core.checkSuccess(result);
    for (storage[0..count], values[0..count], 0..) |*destination, source, index| destination.* = .{
        .index = @intCast(index),
        .stages = stagesFromRaw(source.stages),
        .name_buffer = source.name,
        .description_buffer = source.description,
        .subgroup_size = source.subgroupSize,
    };
    return storage[0..count];
}

pub fn statisticCount(
    device: DeviceHandle,
    pipeline: raw.VkPipeline,
    executable_index: u32,
    get: CommandFunction(raw.PFN_vkGetPipelineExecutableStatisticsKHR),
) core.Error!u32 {
    const info = executableInfo(pipeline, executable_index);
    var count: u32 = 0;
    try core.checkSuccess(get(device, &info, &count, null));
    if (count > executable_item_count_max) return error.TooManyObjects;
    return count;
}

pub fn statisticsInto(
    device: DeviceHandle,
    pipeline: raw.VkPipeline,
    executable_index: u32,
    get: CommandFunction(raw.PFN_vkGetPipelineExecutableStatisticsKHR),
    storage: []Statistic,
) core.Error![]Statistic {
    if (storage.len > executable_item_count_max) return error.CountOverflow;
    var values: [executable_item_count_max]raw.VkPipelineExecutableStatisticKHR = undefined;
    for (values[0..storage.len]) |*value| value.* = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_EXECUTABLE_STATISTIC_KHR,
    };
    const info = executableInfo(pipeline, executable_index);
    var count: u32 = @intCast(storage.len);
    const result = get(device, &info, &count, if (storage.len == 0) null else values[0..storage.len].ptr);
    if (result == raw.VK_INCOMPLETE or count > storage.len) return error.BufferTooSmall;
    try core.checkSuccess(result);
    for (storage[0..count], values[0..count]) |*destination, source| destination.* = .{
        .name_buffer = source.name,
        .description_buffer = source.description,
        .value = switch (source.format) {
            raw.VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_BOOL32_KHR => .{ .boolean = source.value.b32 != raw.VK_FALSE },
            raw.VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_INT64_KHR => .{ .signed = source.value.i64 },
            raw.VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_UINT64_KHR => .{ .unsigned = source.value.u64 },
            raw.VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_FLOAT64_KHR => .{ .float = source.value.f64 },
            else => return error.UnsupportedOperation,
        },
    };
    return storage[0..count];
}

pub fn internalRepresentationCount(
    device: DeviceHandle,
    pipeline: raw.VkPipeline,
    executable_index: u32,
    get: CommandFunction(raw.PFN_vkGetPipelineExecutableInternalRepresentationsKHR),
) core.Error!u32 {
    const info = executableInfo(pipeline, executable_index);
    var count: u32 = 0;
    try core.checkSuccess(get(device, &info, &count, null));
    if (count > executable_item_count_max) return error.TooManyObjects;
    return count;
}

pub fn internalRepresentationsInto(
    device: DeviceHandle,
    pipeline: raw.VkPipeline,
    executable_index: u32,
    get: CommandFunction(raw.PFN_vkGetPipelineExecutableInternalRepresentationsKHR),
    storage: []InternalRepresentation,
) core.Error![]InternalRepresentation {
    if (storage.len > executable_item_count_max) return error.CountOverflow;
    var values: [executable_item_count_max]raw.VkPipelineExecutableInternalRepresentationKHR = undefined;
    for (values[0..storage.len]) |*value| value.* = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_EXECUTABLE_INTERNAL_REPRESENTATION_KHR,
    };
    const info = executableInfo(pipeline, executable_index);
    var count: u32 = @intCast(storage.len);
    var result = get(device, &info, &count, if (storage.len == 0) null else values[0..storage.len].ptr);
    if (result == raw.VK_INCOMPLETE or count > storage.len) return error.BufferTooSmall;
    try core.checkSuccess(result);
    for (values[0..count], storage[0..count]) |*value, destination| {
        if (value.dataSize > destination.data.len) return error.BufferTooSmall;
        value.pData = if (destination.data.len == 0) null else destination.data.ptr;
        value.dataSize = destination.data.len;
    }
    var written = count;
    result = get(device, &info, &written, if (count == 0) null else values[0..count].ptr);
    if (result == raw.VK_INCOMPLETE or written > count) return error.BufferTooSmall;
    try core.checkSuccess(result);
    for (storage[0..written], values[0..written]) |*destination, source| {
        destination.name_buffer = source.name;
        destination.description_buffer = source.description;
        destination.is_text = source.isText != raw.VK_FALSE;
        destination.data = destination.data[0..source.dataSize];
    }
    return storage[0..written];
}

pub const BinaryKey = struct {
    size: u32 = 0,
    buffer: [raw.VK_MAX_PIPELINE_BINARY_KEY_SIZE_KHR]u8 = @splat(0),

    pub fn bytes(key: *const BinaryKey) []const u8 {
        return key.buffer[0..key.size];
    }

    fn fromRaw(value: raw.VkPipelineBinaryKeyKHR) core.Error!BinaryKey {
        if (value.keySize > raw.VK_MAX_PIPELINE_BINARY_KEY_SIZE_KHR) return error.InvalidProperties;
        return .{ .size = value.keySize, .buffer = value.key };
    }

    fn toRaw(key: BinaryKey) core.Error!raw.VkPipelineBinaryKeyKHR {
        if (key.size > raw.VK_MAX_PIPELINE_BINARY_KEY_SIZE_KHR) return error.InvalidOptions;
        return .{
            .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_BINARY_KEY_KHR,
            .keySize = key.size,
            .key = key.buffer,
        };
    }
};

pub const BinaryPayload = struct {
    key: BinaryKey,
    data: []const u8,
};

pub const BinaryData = struct {
    key: BinaryKey,
    data: []u8,
};

pub const BinaryDispatch = struct {
    destroy: CommandFunction(raw.PFN_vkDestroyPipelineBinaryKHR),
    get_data: CommandFunction(raw.PFN_vkGetPipelineBinaryDataKHR),
};

pub const Binary = struct {
    _handle: ?BinaryHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: core.DeviceState,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: BinaryDispatch,

    pub fn deinit(binary: *Binary) void {
        if (!(binary._owner.release(binary) catch return)) return;
        const handle = binary._handle orelse return;
        binary.dispatch.destroy(binary._device_handle, handle, binary.allocation_callbacks);
        binary._handle = null;
    }

    pub fn rawHandle(binary: *const Binary) core.Error!raw.VkPipelineBinaryKHR {
        try binary._owner.validate(binary);
        try binary._device_state.ensureDispatchAllowed();
        return binary._handle orelse error.InactiveObject;
    }

    pub fn dataSize(binary: *const Binary) core.Error!usize {
        const info: raw.VkPipelineBinaryDataInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_BINARY_DATA_INFO_KHR,
            .pipelineBinary = try binary.rawHandle(),
        };
        var key: raw.VkPipelineBinaryKeyKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_BINARY_KEY_KHR,
        };
        var size: usize = 0;
        try core.checkSuccessTracked(@constCast(&binary._device_state), binary.dispatch.get_data(
            binary._device_handle,
            &info,
            &key,
            &size,
            null,
        ));
        return size;
    }

    pub fn dataInto(binary: *const Binary, storage: []u8) core.Error!BinaryData {
        const info: raw.VkPipelineBinaryDataInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_BINARY_DATA_INFO_KHR,
            .pipelineBinary = try binary.rawHandle(),
        };
        var key: raw.VkPipelineBinaryKeyKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_BINARY_KEY_KHR,
        };
        var size = storage.len;
        const result = binary.dispatch.get_data(
            binary._device_handle,
            &info,
            &key,
            &size,
            if (storage.len == 0) null else storage.ptr,
        );
        if (result == raw.VK_ERROR_NOT_ENOUGH_SPACE_KHR or size > storage.len) return error.BufferTooSmall;
        try core.checkSuccessTracked(@constCast(&binary._device_state), result);
        return .{ .key = try .fromRaw(key), .data = storage[0..size] };
    }

    pub fn data(
        binary: *const Binary,
        gpa: std.mem.Allocator,
    ) (core.Error || std.mem.Allocator.Error)!BinaryData {
        var bytes = try gpa.alloc(u8, try binary.dataSize());
        errdefer gpa.free(bytes);
        return binary.dataInto(bytes) catch |err| switch (err) {
            error.BufferTooSmall => {
                gpa.free(bytes);
                bytes = try gpa.alloc(u8, try binary.dataSize());
                return binary.dataInto(bytes);
            },
            else => return err,
        };
    }

    pub fn debugObject(binary: *const Binary) core.Error!debug_utils.Object {
        return .forDevice(.pipeline_binary, try binary.rawHandle(), binary._device_handle);
    }
};

pub const BinaryCreateStatus = enum { success, missing };

pub const BinaryCreateResult = struct {
    status: BinaryCreateStatus,
    binaries: []Binary,
};

pub const BinaryCreateDispatch = struct {
    create: CommandFunction(raw.PFN_vkCreatePipelineBinariesKHR),
    destroy: CommandFunction(raw.PFN_vkDestroyPipelineBinaryKHR),
    get_data: CommandFunction(raw.PFN_vkGetPipelineBinaryDataKHR),
};

pub fn binaryCountForPipeline(
    device_handle: DeviceHandle,
    pipeline: raw.VkPipeline,
    create: CommandFunction(raw.PFN_vkCreatePipelineBinariesKHR),
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
) core.Error!u32 {
    const create_info: raw.VkPipelineBinaryCreateInfoKHR = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_BINARY_CREATE_INFO_KHR,
        .pipeline = pipeline,
    };
    var handles: raw.VkPipelineBinaryHandlesInfoKHR = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_BINARY_HANDLES_INFO_KHR,
    };
    const result = create(device_handle, &create_info, allocation_callbacks, &handles);
    if (result == raw.VK_PIPELINE_BINARY_MISSING_KHR) return 0;
    try core.checkSuccess(result);
    if (handles.pipelineBinaryCount > executable_item_count_max) return error.TooManyObjects;
    return handles.pipelineBinaryCount;
}

fn createBinariesWithInfo(
    device_handle: DeviceHandle,
    device_state: core.DeviceState,
    dispatch: BinaryCreateDispatch,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    create_info: *const raw.VkPipelineBinaryCreateInfoKHR,
    output: []Binary,
) core.Error!BinaryCreateResult {
    if (output.len > executable_item_count_max) return error.CountOverflow;
    var raw_handles: [executable_item_count_max]raw.VkPipelineBinaryKHR = @splat(null);
    var handles: raw.VkPipelineBinaryHandlesInfoKHR = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_BINARY_HANDLES_INFO_KHR,
        .pipelineBinaryCount = @intCast(output.len),
        .pPipelineBinaries = if (output.len == 0) null else raw_handles[0..output.len].ptr,
    };
    const result = dispatch.create(device_handle, create_info, allocation_callbacks, &handles);
    const returned_count: usize = @min(handles.pipelineBinaryCount, output.len);
    var initialized: usize = 0;
    errdefer for (output[0..initialized]) |*binary| {
        _ = binary._owner.release(binary) catch {};
    };
    errdefer for (raw_handles[0..returned_count]) |handle| if (handle) |non_null| {
        dispatch.destroy(device_handle, non_null, allocation_callbacks);
    };
    if (result == raw.VK_PIPELINE_BINARY_MISSING_KHR) {
        for (raw_handles[0..returned_count]) |handle| if (handle) |non_null| {
            dispatch.destroy(device_handle, non_null, allocation_callbacks);
        };
        return .{ .status = .missing, .binaries = output[0..0] };
    }
    if (result == raw.VK_INCOMPLETE or handles.pipelineBinaryCount > output.len) return error.BufferTooSmall;
    try core.checkSuccessTracked(@constCast(&device_state), result);
    for (output[0..returned_count], raw_handles[0..returned_count]) |*destination, maybe_handle| {
        const handle = maybe_handle orelse return error.InvalidHandle;
        destination.* = .{
            ._handle = handle,
            ._owner = try .init(&handle),
            ._device_handle = device_handle,
            ._device_state = device_state,
            .allocation_callbacks = allocation_callbacks,
            .dispatch = .{ .destroy = dispatch.destroy, .get_data = dispatch.get_data },
        };
        initialized += 1;
    }
    return .{ .status = .success, .binaries = output[0..returned_count] };
}

pub fn createBinariesForPipelineInto(
    device_handle: DeviceHandle,
    device_state: core.DeviceState,
    dispatch: BinaryCreateDispatch,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    pipeline: raw.VkPipeline,
    output: []Binary,
) core.Error!BinaryCreateResult {
    const info: raw.VkPipelineBinaryCreateInfoKHR = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_BINARY_CREATE_INFO_KHR,
        .pipeline = pipeline,
    };
    return createBinariesWithInfo(device_handle, device_state, dispatch, allocation_callbacks, &info, output);
}

pub fn createBinariesFromDataInto(
    device_handle: DeviceHandle,
    device_state: core.DeviceState,
    dispatch: BinaryCreateDispatch,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    payloads: []const BinaryPayload,
    output: []Binary,
) core.Error!BinaryCreateResult {
    if (payloads.len == 0 or payloads.len > executable_item_count_max) return error.InvalidOptions;
    if (output.len < payloads.len) return error.BufferTooSmall;
    var keys: [executable_item_count_max]raw.VkPipelineBinaryKeyKHR = undefined;
    var data: [executable_item_count_max]raw.VkPipelineBinaryDataKHR = undefined;
    for (payloads, 0..) |payload, index| {
        keys[index] = try payload.key.toRaw();
        data[index] = .{
            .dataSize = payload.data.len,
            .pData = if (payload.data.len == 0) null else @constCast(payload.data.ptr),
        };
    }
    const keys_and_data: raw.VkPipelineBinaryKeysAndDataKHR = .{
        .binaryCount = @intCast(payloads.len),
        .pPipelineBinaryKeys = keys[0..payloads.len].ptr,
        .pPipelineBinaryData = data[0..payloads.len].ptr,
    };
    const info: raw.VkPipelineBinaryCreateInfoKHR = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_BINARY_CREATE_INFO_KHR,
        .pKeysAndDataInfo = &keys_and_data,
    };
    return createBinariesWithInfo(device_handle, device_state, dispatch, allocation_callbacks, &info, output[0..payloads.len]);
}

pub fn releaseCapturedPipelineData(
    device_handle: DeviceHandle,
    device_state: core.DeviceState,
    release: CommandFunction(raw.PFN_vkReleaseCapturedPipelineDataKHR),
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    pipeline: raw.VkPipeline,
) core.Error!void {
    const info: raw.VkReleaseCapturedPipelineDataInfoKHR = .{
        .sType = raw.VK_STRUCTURE_TYPE_RELEASE_CAPTURED_PIPELINE_DATA_INFO_KHR,
        .pipeline = pipeline,
    };
    try core.checkSuccessTracked(@constCast(&device_state), release(
        device_handle,
        &info,
        allocation_callbacks,
    ));
}

pub const CacheOptions = struct {
    initial_data: []const u8 = &.{},
    allocation_callbacks: ?*const raw.VkAllocationCallbacks = null,
};

pub const CacheDispatch = struct {
    create: CommandFunction(raw.PFN_vkCreatePipelineCache),
    destroy: CommandFunction(raw.PFN_vkDestroyPipelineCache),
    get_data: CommandFunction(raw.PFN_vkGetPipelineCacheData),
    merge: CommandFunction(raw.PFN_vkMergePipelineCaches),
};

pub const Cache = struct {
    _handle: ?CacheHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: core.DeviceState,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: CacheDispatch,

    pub fn deinit(cache: *Cache) void {
        if (!(cache._owner.release(cache) catch return)) return;
        const handle = cache._handle orelse return;
        cache.dispatch.destroy(cache._device_handle, handle, cache.allocation_callbacks);
        cache._handle = null;
    }

    pub fn rawHandle(cache: *const Cache) core.Error!raw.VkPipelineCache {
        try cache._owner.validate(cache);
        try cache._device_state.ensureDispatchAllowed();
        return cache._handle orelse error.InactiveObject;
    }

    pub fn dataSize(cache: *const Cache) core.Error!usize {
        var size: usize = 0;
        try core.checkSuccessTracked(@constCast(&cache._device_state), cache.dispatch.get_data(
            cache._device_handle,
            try cache.rawHandle(),
            &size,
            null,
        ));
        return size;
    }

    pub fn dataInto(cache: *const Cache, storage: []u8) core.Error![]u8 {
        const required = try cache.dataSize();
        if (storage.len < required) return error.BufferTooSmall;
        var written = storage.len;
        const result = cache.dispatch.get_data(cache._device_handle, try cache.rawHandle(), &written, storage.ptr);
        if (result == raw.VK_INCOMPLETE or written > storage.len) return error.BufferTooSmall;
        try core.checkSuccessTracked(@constCast(&cache._device_state), result);
        return storage[0..written];
    }

    pub fn data(cache: *const Cache, gpa: std.mem.Allocator) (core.Error || std.mem.Allocator.Error)![]u8 {
        var bytes = try gpa.alloc(u8, try cache.dataSize());
        errdefer gpa.free(bytes);
        return cache.dataInto(bytes) catch |err| switch (err) {
            error.BufferTooSmall => {
                gpa.free(bytes);
                bytes = try gpa.alloc(u8, try cache.dataSize());
                return cache.dataInto(bytes);
            },
            else => return err,
        };
    }

    pub fn merge(cache: *Cache, sources: []const *const Cache) core.Error!void {
        if (sources.len == 0 or sources.len > 64) return error.InvalidOptions;
        var handles: [64]raw.VkPipelineCache = undefined;
        for (sources, 0..) |source, index| {
            if (source == cache or source._device_handle != cache._device_handle) return error.InvalidHandle;
            handles[index] = try source.rawHandle();
        }
        try core.checkSuccessTracked(&cache._device_state, cache.dispatch.merge(
            cache._device_handle,
            try cache.rawHandle(),
            @intCast(sources.len),
            handles[0..sources.len].ptr,
        ));
    }

    pub fn debugObject(cache: *const Cache) core.Error!debug_utils.Object {
        return .forDevice(.pipeline_cache, try cache.rawHandle(), cache._device_handle);
    }
};

pub fn createCache(
    device_handle: DeviceHandle,
    device_state: core.DeviceState,
    dispatch: CacheDispatch,
    options: CacheOptions,
) core.Error!Cache {
    try device_state.ensureDispatchAllowed();
    const info: raw.VkPipelineCacheCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO,
        .initialDataSize = options.initial_data.len,
        .pInitialData = if (options.initial_data.len == 0) null else options.initial_data.ptr,
    };
    var handle: raw.VkPipelineCache = null;
    const result = dispatch.create(device_handle, &info, options.allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, options.allocation_callbacks);
        try core.checkSuccessOptional(&device_state, result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._owner = try .init(&handle),
        ._device_handle = device_handle,
        ._device_state = device_state,
        .allocation_callbacks = options.allocation_callbacks,
        .dispatch = dispatch,
    };
}

pub const JoinStatus = enum { success, thread_done, thread_idle };
pub const CompletionStatus = enum { pending, success };

pub const DeferredDispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateDeferredOperationKHR),
    destroy: CommandFunction(raw.PFN_vkDestroyDeferredOperationKHR),
    max_concurrency: CommandFunction(raw.PFN_vkGetDeferredOperationMaxConcurrencyKHR),
    result: CommandFunction(raw.PFN_vkGetDeferredOperationResultKHR),
    join: CommandFunction(raw.PFN_vkDeferredOperationJoinKHR),
};

pub const DeferredOperation = struct {
    _handle: ?DeferredHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: core.DeviceState,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: DeferredDispatch,

    pub fn deinit(operation: *DeferredOperation) void {
        if (!(operation._owner.release(operation) catch return)) return;
        const handle = operation._handle orelse return;
        operation.dispatch.destroy(operation._device_handle, handle, operation.allocation_callbacks);
        operation._handle = null;
    }

    pub fn rawHandle(operation: *const DeferredOperation) core.Error!raw.VkDeferredOperationKHR {
        try operation._owner.validate(operation);
        try operation._device_state.ensureDispatchAllowed();
        return operation._handle orelse error.InactiveObject;
    }

    pub fn maxConcurrency(operation: *const DeferredOperation) core.Error!u32 {
        return operation.dispatch.max_concurrency(operation._device_handle, try operation.rawHandle());
    }

    pub fn completion(operation: *const DeferredOperation) core.Error!CompletionStatus {
        const result = operation.dispatch.result(operation._device_handle, try operation.rawHandle());
        if (result == raw.VK_NOT_READY) return .pending;
        try core.checkSuccessTracked(@constCast(&operation._device_state), result);
        return .success;
    }

    pub fn join(operation: *DeferredOperation) core.Error!JoinStatus {
        const result = operation.dispatch.join(operation._device_handle, try operation.rawHandle());
        if (result == raw.VK_SUCCESS) return .success;
        if (result == raw.VK_THREAD_DONE_KHR) return .thread_done;
        if (result == raw.VK_THREAD_IDLE_KHR) return .thread_idle;
        try core.checkSuccessTracked(&operation._device_state, result);
        unreachable;
    }

    pub fn debugObject(operation: *const DeferredOperation) core.Error!debug_utils.Object {
        return .forDevice(.deferred_operation, try operation.rawHandle(), operation._device_handle);
    }
};

pub fn createDeferred(
    device_handle: DeviceHandle,
    device_state: core.DeviceState,
    dispatch: DeferredDispatch,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
) core.Error!DeferredOperation {
    try device_state.ensureDispatchAllowed();
    var handle: raw.VkDeferredOperationKHR = null;
    const result = dispatch.create(device_handle, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccessOptional(&device_state, result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._owner = try .init(&handle),
        ._device_handle = device_handle,
        ._device_state = device_state,
        .allocation_callbacks = allocation_callbacks,
        .dispatch = dispatch,
    };
}

test "all pipeline-tool declarations compile" {
    std.testing.refAllDecls(@This());
}

var test_cache_destroy_count: usize = 0;
var test_merge_count: u32 = 0;
var test_deferred_destroy_count: usize = 0;
var test_deferred_result: raw.VkResult = raw.VK_SUCCESS;
var test_join_result: raw.VkResult = raw.VK_SUCCESS;
var test_cache_create_result: raw.VkResult = raw.VK_SUCCESS;
var test_binary_create_result: raw.VkResult = raw.VK_SUCCESS;
var test_binary_destroy_count: usize = 0;
var test_release_count: usize = 0;

fn testCreateCache(_: raw.VkDevice, _: [*c]const raw.VkPipelineCacheCreateInfo, _: [*c]const raw.VkAllocationCallbacks, output: [*c]raw.VkPipelineCache) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x2000);
    return test_cache_create_result;
}

fn testDestroyCache(_: raw.VkDevice, _: raw.VkPipelineCache, _: [*c]const raw.VkAllocationCallbacks) callconv(.c) void {
    test_cache_destroy_count += 1;
}

fn testCacheData(_: raw.VkDevice, _: raw.VkPipelineCache, size: [*c]usize, data: ?*anyopaque) callconv(.c) raw.VkResult {
    const bytes = [_]u8{ 1, 2, 3, 4 };
    if (data == null) {
        size.* = bytes.len;
        return raw.VK_SUCCESS;
    }
    if (size.* < bytes.len) {
        size.* = bytes.len;
        return raw.VK_INCOMPLETE;
    }
    const destination: [*]u8 = @ptrCast(data.?);
    @memcpy(destination[0..bytes.len], &bytes);
    size.* = bytes.len;
    return raw.VK_SUCCESS;
}

fn testMerge(_: raw.VkDevice, _: raw.VkPipelineCache, count: u32, _: [*c]const raw.VkPipelineCache) callconv(.c) raw.VkResult {
    test_merge_count = count;
    return raw.VK_SUCCESS;
}

fn testCreateDeferred(_: raw.VkDevice, _: [*c]const raw.VkAllocationCallbacks, output: [*c]raw.VkDeferredOperationKHR) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x3000);
    return raw.VK_SUCCESS;
}

fn testDestroyDeferred(_: raw.VkDevice, _: raw.VkDeferredOperationKHR, _: [*c]const raw.VkAllocationCallbacks) callconv(.c) void {
    test_deferred_destroy_count += 1;
}

fn testDeferredConcurrency(_: raw.VkDevice, _: raw.VkDeferredOperationKHR) callconv(.c) u32 {
    return 3;
}

fn testDeferredResult(_: raw.VkDevice, _: raw.VkDeferredOperationKHR) callconv(.c) raw.VkResult {
    return test_deferred_result;
}

fn testDeferredJoin(_: raw.VkDevice, _: raw.VkDeferredOperationKHR) callconv(.c) raw.VkResult {
    return test_join_result;
}

fn testExecutableProperties(
    _: raw.VkDevice,
    _: [*c]const raw.VkPipelineInfoKHR,
    count: [*c]u32,
    properties: [*c]raw.VkPipelineExecutablePropertiesKHR,
) callconv(.c) raw.VkResult {
    if (properties == null) {
        count.* = 1;
        return raw.VK_SUCCESS;
    }
    if (count.* < 1) return raw.VK_INCOMPLETE;
    properties[0].stages = raw.VK_SHADER_STAGE_VERTEX_BIT | raw.VK_SHADER_STAGE_FRAGMENT_BIT;
    @memcpy(properties[0].name[0..4], "main");
    properties[0].subgroupSize = 32;
    count.* = 1;
    return raw.VK_SUCCESS;
}

fn testExecutableStatistics(
    _: raw.VkDevice,
    _: [*c]const raw.VkPipelineExecutableInfoKHR,
    count: [*c]u32,
    statistics: [*c]raw.VkPipelineExecutableStatisticKHR,
) callconv(.c) raw.VkResult {
    if (statistics == null) {
        count.* = 1;
        return raw.VK_SUCCESS;
    }
    statistics[0].format = raw.VK_PIPELINE_EXECUTABLE_STATISTIC_FORMAT_UINT64_KHR;
    statistics[0].value.u64 = 42;
    @memcpy(statistics[0].name[0..9], "registers");
    count.* = 1;
    return raw.VK_SUCCESS;
}

fn testInternalRepresentations(
    _: raw.VkDevice,
    _: [*c]const raw.VkPipelineExecutableInfoKHR,
    count: [*c]u32,
    representations: [*c]raw.VkPipelineExecutableInternalRepresentationKHR,
) callconv(.c) raw.VkResult {
    if (representations == null) {
        count.* = 1;
        return raw.VK_SUCCESS;
    }
    @memcpy(representations[0].name[0..3], "ISA");
    representations[0].isText = raw.VK_TRUE;
    if (representations[0].pData == null) {
        representations[0].dataSize = 3;
    } else {
        const destination: [*]u8 = @ptrCast(representations[0].pData.?);
        @memcpy(destination[0..3], "asm");
        representations[0].dataSize = 3;
    }
    count.* = 1;
    return raw.VK_SUCCESS;
}

fn testCreateBinaries(
    _: raw.VkDevice,
    _: [*c]const raw.VkPipelineBinaryCreateInfoKHR,
    _: [*c]const raw.VkAllocationCallbacks,
    handles: [*c]raw.VkPipelineBinaryHandlesInfoKHR,
) callconv(.c) raw.VkResult {
    if (handles.*.pPipelineBinaries == null) {
        handles.*.pipelineBinaryCount = 1;
        return test_binary_create_result;
    }
    if (handles.*.pipelineBinaryCount == 0) return raw.VK_INCOMPLETE;
    handles.*.pPipelineBinaries[0] = @ptrFromInt(0x6000);
    handles.*.pipelineBinaryCount = 1;
    return test_binary_create_result;
}

fn testDestroyBinary(_: raw.VkDevice, _: raw.VkPipelineBinaryKHR, _: [*c]const raw.VkAllocationCallbacks) callconv(.c) void {
    test_binary_destroy_count += 1;
}

fn testBinaryData(
    _: raw.VkDevice,
    _: [*c]const raw.VkPipelineBinaryDataInfoKHR,
    key: [*c]raw.VkPipelineBinaryKeyKHR,
    size: [*c]usize,
    data: ?*anyopaque,
) callconv(.c) raw.VkResult {
    key.*.keySize = 2;
    key.*.key = [_]u8{ 7, 8 } ++ [_]u8{0} ** 30;
    if (data == null) {
        size.* = 3;
        return raw.VK_SUCCESS;
    }
    if (size.* < 3) {
        size.* = 3;
        return raw.VK_ERROR_NOT_ENOUGH_SPACE_KHR;
    }
    const destination: [*]u8 = @ptrCast(data.?);
    @memcpy(destination[0..3], "\x01\x02\x03");
    size.* = 3;
    return raw.VK_SUCCESS;
}

fn testReleaseCaptured(
    _: raw.VkDevice,
    _: [*c]const raw.VkReleaseCapturedPipelineDataInfoKHR,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) raw.VkResult {
    test_release_count += 1;
    return raw.VK_SUCCESS;
}

test "pipeline cache data merge and deferred statuses stay typed" {
    var state = try core.DeviceState.init();
    defer state.markDestroyed();
    const device: DeviceHandle = @ptrFromInt(0x1000);
    const cache_dispatch: CacheDispatch = .{ .create = testCreateCache, .destroy = testDestroyCache, .get_data = testCacheData, .merge = testMerge };
    test_cache_destroy_count = 0;
    var first = try createCache(device, state, cache_dispatch, .{});
    var second = try createCache(device, state, cache_dispatch, .{});
    defer second.deinit();
    var too_small: [2]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, first.dataInto(&too_small));
    var storage: [4]u8 = undefined;
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, try first.dataInto(&storage));
    const allocated = try first.data(std.testing.allocator);
    defer std.testing.allocator.free(allocated);
    try std.testing.expectEqualSlices(u8, &storage, allocated);
    try first.merge(&.{&second});
    try std.testing.expectEqual(@as(u32, 1), test_merge_count);
    try std.testing.expectError(error.InvalidHandle, first.merge(&.{&first}));
    var first_copy = first;
    first_copy.deinit();
    first.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_cache_destroy_count);

    const deferred_dispatch: DeferredDispatch = .{
        .create = testCreateDeferred,
        .destroy = testDestroyDeferred,
        .max_concurrency = testDeferredConcurrency,
        .result = testDeferredResult,
        .join = testDeferredJoin,
    };
    test_deferred_destroy_count = 0;
    var operation = try createDeferred(device, state, deferred_dispatch, null);
    defer operation.deinit();
    try std.testing.expectEqual(@as(u32, 3), try operation.maxConcurrency());
    test_deferred_result = raw.VK_NOT_READY;
    try std.testing.expectEqual(CompletionStatus.pending, try operation.completion());
    test_deferred_result = raw.VK_SUCCESS;
    try std.testing.expectEqual(CompletionStatus.success, try operation.completion());
    test_join_result = raw.VK_THREAD_IDLE_KHR;
    try std.testing.expectEqual(JoinStatus.thread_idle, try operation.join());
    test_join_result = raw.VK_THREAD_DONE_KHR;
    try std.testing.expectEqual(JoinStatus.thread_done, try operation.join());
}

test "invalid cache data rolls back a provisional cache" {
    if (comptime !@hasDecl(raw, "VK_ERROR_INVALID_PIPELINE_CACHE_DATA")) return;
    var state = try core.DeviceState.init();
    defer state.markDestroyed();
    test_cache_create_result = @field(raw, "VK_ERROR_INVALID_PIPELINE_CACHE_DATA");
    test_cache_destroy_count = 0;
    defer test_cache_create_result = raw.VK_SUCCESS;
    try std.testing.expectError(error.InvalidPipelineCacheData, createCache(@ptrFromInt(0x1000), state, .{
        .create = testCreateCache,
        .destroy = testDestroyCache,
        .get_data = testCacheData,
        .merge = testMerge,
    }, .{ .initial_data = &.{1} }));
    try std.testing.expectEqual(@as(usize, 1), test_cache_destroy_count);
}

test "pipeline executable metadata uses typed caller storage" {
    const device: DeviceHandle = @ptrFromInt(0x1000);
    const pipeline: raw.VkPipeline = @ptrFromInt(0x5000);
    try std.testing.expectEqual(@as(u32, 1), try executableCount(device, pipeline, testExecutableProperties));
    var executables: [1]Executable = undefined;
    const values = try executablesInto(device, pipeline, testExecutableProperties, &executables);
    try std.testing.expectEqualStrings("main", values[0].name());
    try std.testing.expect(values[0].stages.contains(.vertex));
    try std.testing.expect(values[0].stages.contains(.fragment));

    var statistics: [1]Statistic = undefined;
    const stats = try statisticsInto(device, pipeline, 0, testExecutableStatistics, &statistics);
    try std.testing.expectEqualStrings("registers", stats[0].name());
    try std.testing.expectEqual(@as(u64, 42), stats[0].value.unsigned);

    var too_small_data: [2]u8 = undefined;
    var too_small = [_]InternalRepresentation{.{ .data = &too_small_data }};
    try std.testing.expectError(error.BufferTooSmall, internalRepresentationsInto(device, pipeline, 0, testInternalRepresentations, &too_small));
    var representation_data: [3]u8 = undefined;
    var representations = [_]InternalRepresentation{.{ .data = &representation_data }};
    const internal = try internalRepresentationsInto(device, pipeline, 0, testInternalRepresentations, &representations);
    try std.testing.expect(internal[0].is_text);
    try std.testing.expectEqualStrings("ISA", internal[0].name());
    try std.testing.expectEqualSlices(u8, "asm", internal[0].data);
}

test "pipeline binaries preserve key data status rollback and copy ownership" {
    var state = try core.DeviceState.init();
    defer state.markDestroyed();
    const device: DeviceHandle = @ptrFromInt(0x1000);
    const pipeline: raw.VkPipeline = @ptrFromInt(0x5000);
    const dispatch: BinaryCreateDispatch = .{
        .create = testCreateBinaries,
        .destroy = testDestroyBinary,
        .get_data = testBinaryData,
    };
    test_binary_create_result = raw.VK_SUCCESS;
    test_binary_destroy_count = 0;
    try std.testing.expectEqual(@as(u32, 1), try binaryCountForPipeline(device, pipeline, testCreateBinaries, null));
    var output: [1]Binary = undefined;
    const created = try createBinariesForPipelineInto(device, state, dispatch, null, pipeline, &output);
    try std.testing.expectEqual(BinaryCreateStatus.success, created.status);
    var too_small: [2]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, created.binaries[0].dataInto(&too_small));
    const binary_data = try created.binaries[0].data(std.testing.allocator);
    defer std.testing.allocator.free(binary_data.data);
    try std.testing.expectEqualSlices(u8, &.{ 7, 8 }, binary_data.key.bytes());
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, binary_data.data);
    var copied = created.binaries[0];
    copied.deinit();
    created.binaries[0].deinit();
    try std.testing.expectEqual(@as(usize, 1), test_binary_destroy_count);

    test_binary_create_result = raw.VK_PIPELINE_BINARY_MISSING_KHR;
    var missing_output: [1]Binary = undefined;
    const missing = try createBinariesForPipelineInto(device, state, dispatch, null, pipeline, &missing_output);
    try std.testing.expectEqual(BinaryCreateStatus.missing, missing.status);
    try std.testing.expectEqual(@as(usize, 2), test_binary_destroy_count);

    test_binary_create_result = raw.VK_SUCCESS;
    var restored_output: [1]Binary = undefined;
    const restored = try createBinariesFromDataInto(device, state, dispatch, null, &.{.{
        .key = binary_data.key,
        .data = binary_data.data,
    }}, &restored_output);
    try std.testing.expectEqual(BinaryCreateStatus.success, restored.status);
    restored.binaries[0].deinit();

    test_release_count = 0;
    try releaseCapturedPipelineData(device, state, testReleaseCaptured, null, pipeline);
    try std.testing.expectEqual(@as(usize, 1), test_release_count);
}
