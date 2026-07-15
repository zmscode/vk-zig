const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const SlotHandle = core.NonNullHandle(raw.VkPrivateDataSlot);

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

    pub fn description(report: *const FaultReport) []const u8 {
        return std.mem.sliceTo(&report.description_buffer, 0);
    }

    pub fn deinit(report: *FaultReport, gpa: std.mem.Allocator) void {
        if (!(report._owner.release(report) catch return)) return;
        gpa.free(report.addresses);
        gpa.free(report.vendor_faults);
        gpa.free(report.vendor_binary);
        report.* = undefined;
    }
};

pub fn getFaultReport(
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
