const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const SlotHandle = core.NonNullHandle(raw.VkPrivateDataSlot);
const ValidationCacheHandle = core.NonNullHandle(raw.VkValidationCacheEXT);

pub const ToolPurposes = struct {
    bits: u32 = 0,

    pub fn validation(value: ToolPurposes) bool {
        return value.bits & raw.VK_TOOL_PURPOSE_VALIDATION_BIT != 0;
    }

    pub fn profiling(value: ToolPurposes) bool {
        return value.bits & raw.VK_TOOL_PURPOSE_PROFILING_BIT != 0;
    }

    pub fn tracing(value: ToolPurposes) bool {
        return value.bits & raw.VK_TOOL_PURPOSE_TRACING_BIT != 0;
    }

    pub fn addsFeatures(value: ToolPurposes) bool {
        return value.bits & raw.VK_TOOL_PURPOSE_ADDITIONAL_FEATURES_BIT != 0;
    }

    pub fn modifiesFeatures(value: ToolPurposes) bool {
        return value.bits & raw.VK_TOOL_PURPOSE_MODIFYING_FEATURES_BIT != 0;
    }
};

pub const Tool = struct {
    name_buffer: [raw.VK_MAX_EXTENSION_NAME_SIZE]u8,
    version_buffer: [raw.VK_MAX_EXTENSION_NAME_SIZE]u8,
    purposes: ToolPurposes,
    description_buffer: [raw.VK_MAX_DESCRIPTION_SIZE]u8,
    layer_buffer: [raw.VK_MAX_EXTENSION_NAME_SIZE]u8,

    pub fn name(tool: *const Tool) []const u8 {
        return std.mem.sliceTo(&tool.name_buffer, 0);
    }

    pub fn version(tool: *const Tool) []const u8 {
        return std.mem.sliceTo(&tool.version_buffer, 0);
    }

    pub fn description(tool: *const Tool) []const u8 {
        return std.mem.sliceTo(&tool.description_buffer, 0);
    }

    pub fn layer(tool: *const Tool) ?[]const u8 {
        const value = std.mem.sliceTo(&tool.layer_buffer, 0);
        return if (value.len == 0) null else value;
    }
};

pub fn toolCount(
    physical_device: raw.VkPhysicalDevice,
    get_properties: CommandFunction(raw.PFN_vkGetPhysicalDeviceToolProperties),
) core.Error!u32 {
    var count: u32 = 0;
    try core.checkSuccess(get_properties(physical_device, &count, null));
    return count;
}

pub fn toolsInto(
    physical_device: raw.VkPhysicalDevice,
    get_properties: CommandFunction(raw.PFN_vkGetPhysicalDeviceToolProperties),
    storage: []Tool,
) core.Error![]Tool {
    if (storage.len > 256) return error.CountOverflow;
    var raw_tools: [256]raw.VkPhysicalDeviceToolProperties = undefined;
    for (raw_tools[0..storage.len]) |*item| item.* = .{
        .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_TOOL_PROPERTIES,
    };
    var count: u32 = @intCast(storage.len);
    const result = get_properties(
        physical_device,
        &count,
        if (storage.len == 0) null else raw_tools[0..storage.len].ptr,
    );
    if (result == raw.VK_INCOMPLETE or count > storage.len) return error.BufferTooSmall;
    try core.checkSuccess(result);
    for (storage[0..count], raw_tools[0..count]) |*destination, source| destination.* = .{
        .name_buffer = source.name,
        .version_buffer = source.version,
        .purposes = .{ .bits = source.purposes },
        .description_buffer = source.description,
        .layer_buffer = source.layer,
    };
    return storage[0..count];
}

pub const FaultAddressType = enum(raw.VkDeviceFaultAddressTypeEXT) {
    none = raw.VK_DEVICE_FAULT_ADDRESS_TYPE_NONE_EXT,
    read_invalid = raw.VK_DEVICE_FAULT_ADDRESS_TYPE_READ_INVALID_EXT,
    write_invalid = raw.VK_DEVICE_FAULT_ADDRESS_TYPE_WRITE_INVALID_EXT,
    execute_invalid = raw.VK_DEVICE_FAULT_ADDRESS_TYPE_EXECUTE_INVALID_EXT,
    instruction_pointer_unknown = raw.VK_DEVICE_FAULT_ADDRESS_TYPE_INSTRUCTION_POINTER_UNKNOWN_EXT,
    instruction_pointer_invalid = raw.VK_DEVICE_FAULT_ADDRESS_TYPE_INSTRUCTION_POINTER_INVALID_EXT,
    instruction_pointer_fault = raw.VK_DEVICE_FAULT_ADDRESS_TYPE_INSTRUCTION_POINTER_FAULT_EXT,
    _,

    pub fn fromRaw(value: raw.VkDeviceFaultAddressTypeEXT) FaultAddressType {
        return @enumFromInt(value);
    }
};

pub const FaultAddress = struct {
    kind: FaultAddressType,
    address: u64,
    precision: u64,
};

pub const VendorFault = struct {
    description_buffer: [raw.VK_MAX_DESCRIPTION_SIZE]u8,
    code: u64,
    data: u64,

    pub fn description(fault: *const VendorFault) []const u8 {
        return std.mem.sliceTo(&fault.description_buffer, 0);
    }
};

pub const FaultReport = struct {
    _owner: core.Owner,
    description_buffer: [raw.VK_MAX_DESCRIPTION_SIZE]u8,
    addresses: []FaultAddress,
    vendor_faults: []VendorFault,
    vendor_binary: []u8,
    _address_allocation: []FaultAddress,
    _vendor_allocation: []VendorFault,
    _binary_allocation: []u8,

    pub fn description(report: *const FaultReport) []const u8 {
        return std.mem.sliceTo(&report.description_buffer, 0);
    }

    pub fn deinit(report: *FaultReport, gpa: std.mem.Allocator) void {
        if (!(report._owner.release(report) catch return)) return;
        gpa.free(report._address_allocation);
        gpa.free(report._vendor_allocation);
        gpa.free(report._binary_allocation);
        report.* = undefined;
    }
};

pub fn getFaultReport(
    device_handle: DeviceHandle,
    get_fault: CommandFunction(raw.PFN_vkGetDeviceFaultInfoEXT),
    gpa: std.mem.Allocator,
) (core.Error || std.mem.Allocator.Error)!FaultReport {
    for (0..3) |_| {
        return getFaultReportOnce(device_handle, get_fault, gpa) catch |err| switch (err) {
            error.BufferTooSmall => continue,
            else => return err,
        };
    }
    return error.EnumerationUnstable;
}

fn getFaultReportOnce(
    device_handle: DeviceHandle,
    get_fault: CommandFunction(raw.PFN_vkGetDeviceFaultInfoEXT),
    gpa: std.mem.Allocator,
) (core.Error || std.mem.Allocator.Error)!FaultReport {
    var counts: raw.VkDeviceFaultCountsEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_DEVICE_FAULT_COUNTS_EXT };
    try core.checkSuccess(get_fault(device_handle, &counts, null));
    const address_count: usize = counts.addressInfoCount;
    const vendor_count: usize = counts.vendorInfoCount;
    const binary_size: usize = std.math.cast(usize, counts.vendorBinarySize) orelse return error.SizeOverflow;
    var raw_addresses = try gpa.alloc(raw.VkDeviceFaultAddressInfoEXT, address_count);
    defer gpa.free(raw_addresses);
    var raw_vendors = try gpa.alloc(raw.VkDeviceFaultVendorInfoEXT, vendor_count);
    defer gpa.free(raw_vendors);
    const addresses = try gpa.alloc(FaultAddress, address_count);
    errdefer gpa.free(addresses);
    const vendors = try gpa.alloc(VendorFault, vendor_count);
    errdefer gpa.free(vendors);
    const binary = try gpa.alloc(u8, binary_size);
    errdefer gpa.free(binary);
    counts.addressInfoCount = @intCast(raw_addresses.len);
    counts.vendorInfoCount = @intCast(raw_vendors.len);
    counts.vendorBinarySize = binary.len;
    var info: raw.VkDeviceFaultInfoEXT = .{
        .sType = raw.VK_STRUCTURE_TYPE_DEVICE_FAULT_INFO_EXT,
        .pAddressInfos = if (raw_addresses.len == 0) null else raw_addresses.ptr,
        .pVendorInfos = if (raw_vendors.len == 0) null else raw_vendors.ptr,
        .pVendorBinaryData = if (binary.len == 0) null else binary.ptr,
    };
    try core.checkSuccess(get_fault(device_handle, &counts, &info));
    if (counts.addressInfoCount > raw_addresses.len or counts.vendorInfoCount > raw_vendors.len or counts.vendorBinarySize > binary.len) return error.BufferTooSmall;
    for (raw_addresses[0..counts.addressInfoCount], addresses[0..counts.addressInfoCount]) |source, *destination| destination.* = .{
        .kind = .fromRaw(source.addressType),
        .address = source.reportedAddress,
        .precision = source.addressPrecision,
    };
    for (raw_vendors[0..counts.vendorInfoCount], vendors[0..counts.vendorInfoCount]) |source, *destination| destination.* = .{
        .description_buffer = source.description,
        .code = source.vendorFaultCode,
        .data = source.vendorFaultData,
    };
    return .{
        ._owner = try .init(&info),
        .description_buffer = info.description,
        .addresses = addresses[0..counts.addressInfoCount],
        .vendor_faults = vendors[0..counts.vendorInfoCount],
        .vendor_binary = binary[0..@intCast(counts.vendorBinarySize)],
        ._address_allocation = addresses,
        ._vendor_allocation = vendors,
        ._binary_allocation = binary,
    };
}

pub const ValidationCacheOptions = struct {
    initial_data: []const u8 = &.{},
    allocation_callbacks: ?*const raw.VkAllocationCallbacks = null,
};

pub const ValidationCacheDispatch = struct {
    destroy: CommandFunction(raw.PFN_vkDestroyValidationCacheEXT),
    merge: CommandFunction(raw.PFN_vkMergeValidationCachesEXT),
    get_data: CommandFunction(raw.PFN_vkGetValidationCacheDataEXT),
};

pub const ValidationCache = struct {
    _handle: ?ValidationCacheHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: core.DeviceState,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: ValidationCacheDispatch,

    pub fn deinit(cache: *ValidationCache) void {
        if (!(cache._owner.release(cache) catch return)) return;
        const handle = cache._handle orelse return;
        cache.dispatch.destroy(cache._device_handle, handle, cache.allocation_callbacks);
        cache._handle = null;
    }

    pub fn rawHandle(cache: *const ValidationCache) core.Error!raw.VkValidationCacheEXT {
        try cache._owner.validate(cache);
        try cache._device_state.ensureDispatchAllowed();
        return cache._handle orelse error.InactiveObject;
    }

    pub fn dataSize(cache: *const ValidationCache) core.Error!usize {
        var size: usize = 0;
        try core.checkSuccessTracked(@constCast(&cache._device_state), cache.dispatch.get_data(
            cache._device_handle,
            try cache.rawHandle(),
            &size,
            null,
        ));
        return size;
    }

    pub fn dataInto(cache: *const ValidationCache, storage: []u8) core.Error![]u8 {
        const required = try cache.dataSize();
        if (storage.len < required) return error.BufferTooSmall;
        var written = storage.len;
        const result = cache.dispatch.get_data(
            cache._device_handle,
            try cache.rawHandle(),
            &written,
            if (storage.len == 0) null else storage.ptr,
        );
        if (result == raw.VK_INCOMPLETE or written > storage.len) return error.BufferTooSmall;
        try core.checkSuccessTracked(@constCast(&cache._device_state), result);
        return storage[0..written];
    }

    pub fn data(
        cache: *const ValidationCache,
        gpa: std.mem.Allocator,
    ) (core.Error || std.mem.Allocator.Error)![]u8 {
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

    pub fn merge(cache: *ValidationCache, sources: []const *const ValidationCache) core.Error!void {
        if (sources.len == 0 or sources.len > 64) return error.InvalidOptions;
        var handles: [64]raw.VkValidationCacheEXT = undefined;
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

    pub fn debugObject(cache: *const ValidationCache) core.Error!debug_utils.Object {
        return .forDevice(.validation_cache, try cache.rawHandle(), cache._device_handle);
    }
};

pub fn createValidationCache(
    device_handle: DeviceHandle,
    device_state: core.DeviceState,
    create: CommandFunction(raw.PFN_vkCreateValidationCacheEXT),
    dispatch: ValidationCacheDispatch,
    options: ValidationCacheOptions,
) core.Error!ValidationCache {
    try device_state.ensureDispatchAllowed();
    const info: raw.VkValidationCacheCreateInfoEXT = .{
        .sType = raw.VK_STRUCTURE_TYPE_VALIDATION_CACHE_CREATE_INFO_EXT,
        .initialDataSize = options.initial_data.len,
        .pInitialData = if (options.initial_data.len == 0) null else options.initial_data.ptr,
    };
    var handle: raw.VkValidationCacheEXT = null;
    const result = create(device_handle, &info, options.allocation_callbacks, &handle);
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

pub const PrivateDataDispatch = struct {
    destroy: CommandFunction(raw.PFN_vkDestroyPrivateDataSlot),
    set: CommandFunction(raw.PFN_vkSetPrivateData),
    get: CommandFunction(raw.PFN_vkGetPrivateData),
};

pub const PrivateDataSlot = struct {
    _handle: ?SlotHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: core.DeviceState,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: PrivateDataDispatch,

    pub fn deinit(slot: *PrivateDataSlot) void {
        if (!(slot._owner.release(slot) catch return)) return;
        const handle = slot._handle orelse return;
        slot.dispatch.destroy(slot._device_handle, handle, slot.allocation_callbacks);
        slot._handle = null;
    }

    pub fn rawHandle(slot: *const PrivateDataSlot) core.Error!raw.VkPrivateDataSlot {
        try slot._owner.validate(slot);
        try slot._device_state.ensureDispatchAllowed();
        return slot._handle orelse error.InactiveObject;
    }

    pub fn set(slot: *const PrivateDataSlot, object: anytype, value: u64) core.Error!void {
        const target = try debug_utils.nameTarget(object);
        try target.validateParent(slot._device_handle, null);
        try core.checkSuccessTracked(@constCast(&slot._device_state), slot.dispatch.set(
            slot._device_handle,
            target.object_type.toRaw(),
            target.handle,
            try slot.rawHandle(),
            value,
        ));
    }

    pub fn get(slot: *const PrivateDataSlot, object: anytype) core.Error!u64 {
        const target = try debug_utils.nameTarget(object);
        try target.validateParent(slot._device_handle, null);
        var value: u64 = 0;
        slot.dispatch.get(slot._device_handle, target.object_type.toRaw(), target.handle, try slot.rawHandle(), &value);
        return value;
    }

    pub fn debugObject(slot: *const PrivateDataSlot) core.Error!debug_utils.Object {
        return .forDevice(.private_data_slot, try slot.rawHandle(), slot._device_handle);
    }
};

pub fn createPrivateDataSlot(
    device_handle: DeviceHandle,
    device_state: core.DeviceState,
    create: CommandFunction(raw.PFN_vkCreatePrivateDataSlot),
    dispatch: PrivateDataDispatch,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
) core.Error!PrivateDataSlot {
    try device_state.ensureDispatchAllowed();
    const info: raw.VkPrivateDataSlotCreateInfo = .{ .sType = raw.VK_STRUCTURE_TYPE_PRIVATE_DATA_SLOT_CREATE_INFO };
    var handle: raw.VkPrivateDataSlot = null;
    const result = create(device_handle, &info, allocation_callbacks, &handle);
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

test "all diagnostic declarations compile" {
    std.testing.refAllDecls(@This());
}

var test_private_value: u64 = 0;
var test_private_destroy_count: usize = 0;
var test_validation_destroy_count: usize = 0;
var test_validation_merge_count: u32 = 0;
var test_validation_create_result: raw.VkResult = raw.VK_SUCCESS;
var test_fault_growth_pending = false;

fn testFaultInfo(_: raw.VkDevice, counts: [*c]raw.VkDeviceFaultCountsEXT, info: [*c]raw.VkDeviceFaultInfoEXT) callconv(.c) raw.VkResult {
    if (info == null) {
        counts.*.addressInfoCount = 1;
        counts.*.vendorInfoCount = 1;
        counts.*.vendorBinarySize = 4;
        return raw.VK_SUCCESS;
    }
    @memcpy(info.*.description[0..5], "fault");
    info.*.pAddressInfos[0] = .{ .addressType = raw.VK_DEVICE_FAULT_ADDRESS_TYPE_READ_INVALID_EXT, .reportedAddress = 0x1234, .addressPrecision = 16 };
    info.*.pVendorInfos[0].vendorFaultCode = 7;
    info.*.pVendorInfos[0].vendorFaultData = 9;
    const binary: [*]u8 = @ptrCast(info.*.pVendorBinaryData.?);
    const bytes = [_]u8{ 1, 2, 3, 4 };
    @memcpy(binary[0..4], &bytes);
    return raw.VK_SUCCESS;
}

fn testGrowingFaultInfo(
    _: raw.VkDevice,
    counts: [*c]raw.VkDeviceFaultCountsEXT,
    info: [*c]raw.VkDeviceFaultInfoEXT,
) callconv(.c) raw.VkResult {
    if (info == null) {
        counts.*.addressInfoCount = if (test_fault_growth_pending) 2 else 1;
        counts.*.vendorInfoCount = 0;
        counts.*.vendorBinarySize = 0;
        return raw.VK_SUCCESS;
    }
    if (!test_fault_growth_pending) {
        test_fault_growth_pending = true;
        counts.*.addressInfoCount = 2;
        return raw.VK_SUCCESS;
    }
    info.*.pAddressInfos[0] = .{ .addressType = raw.VK_DEVICE_FAULT_ADDRESS_TYPE_READ_INVALID_EXT };
    info.*.pAddressInfos[1] = .{ .addressType = raw.VK_DEVICE_FAULT_ADDRESS_TYPE_WRITE_INVALID_EXT };
    counts.*.addressInfoCount = 2;
    return raw.VK_SUCCESS;
}

fn testCreatePrivate(_: raw.VkDevice, _: [*c]const raw.VkPrivateDataSlotCreateInfo, _: [*c]const raw.VkAllocationCallbacks, output: [*c]raw.VkPrivateDataSlot) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x2000);
    return raw.VK_SUCCESS;
}

fn testDestroyPrivate(_: raw.VkDevice, _: raw.VkPrivateDataSlot, _: [*c]const raw.VkAllocationCallbacks) callconv(.c) void {
    test_private_destroy_count += 1;
}

fn testSetPrivate(_: raw.VkDevice, _: raw.VkObjectType, _: u64, _: raw.VkPrivateDataSlot, value: u64) callconv(.c) raw.VkResult {
    test_private_value = value;
    return raw.VK_SUCCESS;
}

fn testGetPrivate(_: raw.VkDevice, _: raw.VkObjectType, _: u64, _: raw.VkPrivateDataSlot, output: [*c]u64) callconv(.c) void {
    output.* = test_private_value;
}

fn testTools(
    _: raw.VkPhysicalDevice,
    count: [*c]u32,
    properties: [*c]raw.VkPhysicalDeviceToolProperties,
) callconv(.c) raw.VkResult {
    if (properties == null) {
        count.* = 2;
        return raw.VK_SUCCESS;
    }
    if (count.* < 2) {
        count.* = 2;
        return raw.VK_INCOMPLETE;
    }
    @memcpy(properties[0].name[0..10], "validation");
    properties[0].purposes = raw.VK_TOOL_PURPOSE_VALIDATION_BIT;
    @memcpy(properties[1].name[0..8], "profiler");
    properties[1].purposes = raw.VK_TOOL_PURPOSE_PROFILING_BIT | raw.VK_TOOL_PURPOSE_TRACING_BIT;
    count.* = 2;
    return raw.VK_SUCCESS;
}

fn testNoTools(
    _: raw.VkPhysicalDevice,
    count: [*c]u32,
    _: [*c]raw.VkPhysicalDeviceToolProperties,
) callconv(.c) raw.VkResult {
    count.* = 0;
    return raw.VK_SUCCESS;
}

fn testCreateValidation(
    _: raw.VkDevice,
    _: [*c]const raw.VkValidationCacheCreateInfoEXT,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkValidationCacheEXT,
) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x4000);
    return test_validation_create_result;
}

fn testDestroyValidation(
    _: raw.VkDevice,
    _: raw.VkValidationCacheEXT,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_validation_destroy_count += 1;
}

fn testValidationData(
    _: raw.VkDevice,
    _: raw.VkValidationCacheEXT,
    size: [*c]usize,
    data: ?*anyopaque,
) callconv(.c) raw.VkResult {
    const bytes = [_]u8{ 4, 3, 2, 1 };
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

fn testMergeValidation(
    _: raw.VkDevice,
    _: raw.VkValidationCacheEXT,
    count: u32,
    _: [*c]const raw.VkValidationCacheEXT,
) callconv(.c) raw.VkResult {
    test_validation_merge_count = count;
    return raw.VK_SUCCESS;
}

const TestObject = struct {
    _device_handle: DeviceHandle,

    pub fn debugObject(object: *const TestObject) core.Error!debug_utils.Object {
        return .forDevice(.buffer, @as(raw.VkBuffer, @ptrFromInt(0x3000)), object._device_handle);
    }
};

test "fault reports own variable data and private slots stay typed" {
    const device: DeviceHandle = @ptrFromInt(0x1000);
    var report = try getFaultReport(device, testFaultInfo, std.testing.allocator);
    defer report.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("fault", report.description());
    try std.testing.expectEqual(@as(usize, 1), report.addresses.len);
    try std.testing.expectEqual(FaultAddressType.read_invalid, report.addresses[0].kind);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, report.vendor_binary);

    var state = try core.DeviceState.init();
    defer state.markDestroyed();
    test_private_destroy_count = 0;
    var slot = try createPrivateDataSlot(device, state, testCreatePrivate, .{
        .destroy = testDestroyPrivate,
        .set = testSetPrivate,
        .get = testGetPrivate,
    }, null);
    const object: TestObject = .{ ._device_handle = device };
    try slot.set(&object, 42);
    try std.testing.expectEqual(@as(u64, 42), try slot.get(&object));
    var copied = slot;
    copied.deinit();
    slot.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_private_destroy_count);
}

test "tool discovery converts properties and reports caller capacity" {
    const physical_device: raw.VkPhysicalDevice = @ptrFromInt(0x5000);
    try std.testing.expectEqual(@as(u32, 0), try toolCount(physical_device, testNoTools));
    try std.testing.expectEqual(@as(usize, 0), (try toolsInto(physical_device, testNoTools, &.{})).len);
    try std.testing.expectEqual(@as(u32, 2), try toolCount(physical_device, testTools));
    var too_small: [1]Tool = undefined;
    try std.testing.expectError(error.BufferTooSmall, toolsInto(physical_device, testTools, &too_small));
    var storage: [2]Tool = undefined;
    const tools = try toolsInto(physical_device, testTools, &storage);
    try std.testing.expectEqualStrings("validation", tools[0].name());
    try std.testing.expect(tools[0].purposes.validation());
    try std.testing.expectEqualStrings("profiler", tools[1].name());
    try std.testing.expect(tools[1].purposes.profiling());
    try std.testing.expect(tools[1].purposes.tracing());
}

test "fault report allocation retries when record counts grow" {
    const device: DeviceHandle = @ptrFromInt(0x1000);
    test_fault_growth_pending = false;
    var report = try getFaultReport(device, testGrowingFaultInfo, std.testing.allocator);
    defer report.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), report.addresses.len);
    try std.testing.expectEqual(FaultAddressType.write_invalid, report.addresses[1].kind);
}

test "validation caches own data, validate merges, and destroy once" {
    const device: DeviceHandle = @ptrFromInt(0x1000);
    var state = try core.DeviceState.init();
    defer state.markDestroyed();
    const dispatch: ValidationCacheDispatch = .{
        .destroy = testDestroyValidation,
        .merge = testMergeValidation,
        .get_data = testValidationData,
    };
    test_validation_create_result = raw.VK_SUCCESS;
    test_validation_destroy_count = 0;
    test_validation_merge_count = 0;
    var destination = try createValidationCache(device, state, testCreateValidation, dispatch, .{});
    var source = try createValidationCache(device, state, testCreateValidation, dispatch, .{});
    defer source.deinit();
    const bytes = try destination.data(std.testing.allocator);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &.{ 4, 3, 2, 1 }, bytes);
    try destination.merge(&.{&source});
    try std.testing.expectEqual(@as(u32, 1), test_validation_merge_count);
    try std.testing.expectError(error.InvalidHandle, destination.merge(&.{&destination}));
    var copied = destination;
    copied.deinit();
    destination.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_validation_destroy_count);
}

test "validation cache failed creation rolls back a provisional handle" {
    const device: DeviceHandle = @ptrFromInt(0x1000);
    var state = try core.DeviceState.init();
    defer state.markDestroyed();
    test_validation_create_result = raw.VK_ERROR_OUT_OF_HOST_MEMORY;
    test_validation_destroy_count = 0;
    defer test_validation_create_result = raw.VK_SUCCESS;
    try std.testing.expectError(error.OutOfHostMemory, createValidationCache(device, state, testCreateValidation, .{
        .destroy = testDestroyValidation,
        .merge = testMergeValidation,
        .get_data = testValidationData,
    }, .{}));
    try std.testing.expectEqual(@as(usize, 1), test_validation_destroy_count);
}
