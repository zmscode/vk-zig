const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const CacheHandle = core.NonNullHandle(raw.VkPipelineCache);
const DeferredHandle = core.NonNullHandle(raw.VkDeferredOperationKHR);

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

fn testCreateCache(_: raw.VkDevice, _: [*c]const raw.VkPipelineCacheCreateInfo, _: [*c]const raw.VkAllocationCallbacks, output: [*c]raw.VkPipelineCache) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x2000);
    return raw.VK_SUCCESS;
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
