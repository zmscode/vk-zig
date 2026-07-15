//! Cooperative matrix and vector discovery plus NV matrix conversion.

const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const commands = @import("command_buffer.zig");
const buffers = @import("buffer.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const PhysicalDeviceHandle = core.NonNullHandle(raw.VkPhysicalDevice);
pub const property_count_max = 256;

pub const ComponentType = enum(raw.VkComponentTypeKHR) {
    float16 = raw.VK_COMPONENT_TYPE_FLOAT16_KHR,
    float32 = raw.VK_COMPONENT_TYPE_FLOAT32_KHR,
    float64 = raw.VK_COMPONENT_TYPE_FLOAT64_KHR,
    sint8 = raw.VK_COMPONENT_TYPE_SINT8_KHR,
    sint16 = raw.VK_COMPONENT_TYPE_SINT16_KHR,
    sint32 = raw.VK_COMPONENT_TYPE_SINT32_KHR,
    sint64 = raw.VK_COMPONENT_TYPE_SINT64_KHR,
    uint8 = raw.VK_COMPONENT_TYPE_UINT8_KHR,
    uint16 = raw.VK_COMPONENT_TYPE_UINT16_KHR,
    uint32 = raw.VK_COMPONENT_TYPE_UINT32_KHR,
    uint64 = raw.VK_COMPONENT_TYPE_UINT64_KHR,
    bfloat16 = raw.VK_COMPONENT_TYPE_BFLOAT16_KHR,
    sint8_packed = raw.VK_COMPONENT_TYPE_SINT8_PACKED_NV,
    uint8_packed = raw.VK_COMPONENT_TYPE_UINT8_PACKED_NV,
    float8_e4m3 = raw.VK_COMPONENT_TYPE_FLOAT8_E4M3_EXT,
    float8_e5m2 = raw.VK_COMPONENT_TYPE_FLOAT8_E5M2_EXT,
    _,
};

pub const Scope = enum(raw.VkScopeKHR) {
    device = raw.VK_SCOPE_DEVICE_KHR,
    workgroup = raw.VK_SCOPE_WORKGROUP_KHR,
    subgroup = raw.VK_SCOPE_SUBGROUP_KHR,
    queue_family = raw.VK_SCOPE_QUEUE_FAMILY_KHR,
    _,
};

pub const MatrixProperties = struct {
    rows: u32,
    columns: u32,
    depth: u32,
    a: ComponentType,
    b: ComponentType,
    accumulator: ComponentType,
    result: ComponentType,
    saturating_accumulation: bool,
    scope: Scope,
};

pub const VectorProperties = struct {
    input: ComponentType,
    input_interpretation: ComponentType,
    matrix_interpretation: ComponentType,
    bias_interpretation: ComponentType,
    result: ComponentType,
    transpose: bool,
};

pub const QueryContext = struct {
    _physical_device: PhysicalDeviceHandle,
    _matrix_khr: ?CommandFunction(raw.PFN_vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR),
    _matrix_nv: ?CommandFunction(raw.PFN_vkGetPhysicalDeviceCooperativeMatrixPropertiesNV),
    _vector_nv: ?CommandFunction(raw.PFN_vkGetPhysicalDeviceCooperativeVectorPropertiesNV),

    pub fn matrixCount(context: QueryContext) core.Error!u32 {
        if (context._matrix_khr) |enumerate| return countProperties(raw.VkCooperativeMatrixPropertiesKHR, context._physical_device, enumerate);
        if (context._matrix_nv) |enumerate| return countProperties(raw.VkCooperativeMatrixPropertiesNV, context._physical_device, enumerate);
        return error.MissingCommand;
    }

    pub fn matricesInto(context: QueryContext, output: []MatrixProperties) core.Error![]MatrixProperties {
        if (output.len > property_count_max) return error.CountOverflow;
        if (context._matrix_khr) |enumerate| {
            var values: [property_count_max]raw.VkCooperativeMatrixPropertiesKHR = undefined;
            for (values[0..output.len]) |*value| value.* = .{ .sType = raw.VK_STRUCTURE_TYPE_COOPERATIVE_MATRIX_PROPERTIES_KHR };
            var count: u32 = @intCast(output.len);
            const result = enumerate(context._physical_device, &count, if (output.len == 0) null else &values);
            if (result == raw.VK_INCOMPLETE or count > output.len) return error.BufferTooSmall;
            try core.checkSuccess(result);
            for (output[0..count], values[0..count]) |*item, value| item.* = .{
                .rows = value.MSize,
                .columns = value.NSize,
                .depth = value.KSize,
                .a = @enumFromInt(value.AType),
                .b = @enumFromInt(value.BType),
                .accumulator = @enumFromInt(value.CType),
                .result = @enumFromInt(value.ResultType),
                .saturating_accumulation = value.saturatingAccumulation != raw.VK_FALSE,
                .scope = @enumFromInt(value.scope),
            };
            return output[0..count];
        }
        const enumerate = context._matrix_nv orelse return error.MissingCommand;
        var values: [property_count_max]raw.VkCooperativeMatrixPropertiesNV = undefined;
        for (values[0..output.len]) |*value| value.* = .{ .sType = raw.VK_STRUCTURE_TYPE_COOPERATIVE_MATRIX_PROPERTIES_NV };
        var count: u32 = @intCast(output.len);
        const result = enumerate(context._physical_device, &count, if (output.len == 0) null else &values);
        if (result == raw.VK_INCOMPLETE or count > output.len) return error.BufferTooSmall;
        try core.checkSuccess(result);
        for (output[0..count], values[0..count]) |*item, value| item.* = .{
            .rows = value.MSize,
            .columns = value.NSize,
            .depth = value.KSize,
            .a = @enumFromInt(value.AType),
            .b = @enumFromInt(value.BType),
            .accumulator = @enumFromInt(value.CType),
            .result = @enumFromInt(value.DType),
            .saturating_accumulation = false,
            .scope = @enumFromInt(value.scope),
        };
        return output[0..count];
    }

    pub fn matrices(context: QueryContext, gpa: std.mem.Allocator) (core.Error || std.mem.Allocator.Error)![]MatrixProperties {
        const output = try gpa.alloc(MatrixProperties, try context.matrixCount());
        errdefer gpa.free(output);
        const written = try context.matricesInto(output);
        return gpa.realloc(output, written.len);
    }

    pub fn vectorCount(context: QueryContext) core.Error!u32 {
        const enumerate = context._vector_nv orelse return error.MissingCommand;
        return countProperties(raw.VkCooperativeVectorPropertiesNV, context._physical_device, enumerate);
    }

    pub fn vectorsInto(context: QueryContext, output: []VectorProperties) core.Error![]VectorProperties {
        if (output.len > property_count_max) return error.CountOverflow;
        const enumerate = context._vector_nv orelse return error.MissingCommand;
        var values: [property_count_max]raw.VkCooperativeVectorPropertiesNV = undefined;
        for (values[0..output.len]) |*value| value.* = .{ .sType = raw.VK_STRUCTURE_TYPE_COOPERATIVE_VECTOR_PROPERTIES_NV };
        var count: u32 = @intCast(output.len);
        const result = enumerate(context._physical_device, &count, if (output.len == 0) null else &values);
        if (result == raw.VK_INCOMPLETE or count > output.len) return error.BufferTooSmall;
        try core.checkSuccess(result);
        for (output[0..count], values[0..count]) |*item, value| item.* = .{
            .input = @enumFromInt(value.inputType),
            .input_interpretation = @enumFromInt(value.inputInterpretation),
            .matrix_interpretation = @enumFromInt(value.matrixInterpretation),
            .bias_interpretation = @enumFromInt(value.biasInterpretation),
            .result = @enumFromInt(value.resultType),
            .transpose = value.transpose != raw.VK_FALSE,
        };
        return output[0..count];
    }

    pub fn vectors(context: QueryContext, gpa: std.mem.Allocator) (core.Error || std.mem.Allocator.Error)![]VectorProperties {
        const output = try gpa.alloc(VectorProperties, try context.vectorCount());
        errdefer gpa.free(output);
        const written = try context.vectorsInto(output);
        return gpa.realloc(output, written.len);
    }
};

fn countProperties(comptime T: type, physical_device: PhysicalDeviceHandle, enumerate: anytype) core.Error!u32 {
    _ = T;
    var count: u32 = 0;
    const result = enumerate(physical_device, &count, null);
    if (result != raw.VK_SUCCESS and result != raw.VK_INCOMPLETE) try core.checkSuccess(result);
    if (count > property_count_max) return error.CountOverflow;
    return count;
}

pub const MatrixLayout = enum(raw.VkCooperativeVectorMatrixLayoutNV) {
    row_major = raw.VK_COOPERATIVE_VECTOR_MATRIX_LAYOUT_ROW_MAJOR_NV,
    column_major = raw.VK_COOPERATIVE_VECTOR_MATRIX_LAYOUT_COLUMN_MAJOR_NV,
    inference_optimal = raw.VK_COOPERATIVE_VECTOR_MATRIX_LAYOUT_INFERENCING_OPTIMAL_NV,
    training_optimal = raw.VK_COOPERATIVE_VECTOR_MATRIX_LAYOUT_TRAINING_OPTIMAL_NV,
    _,
};

pub const Address = union(enum) {
    host: *anyopaque,
    device: buffers.DeviceAddress,
};

pub const ConstAddress = union(enum) {
    host: *const anyopaque,
    device: buffers.DeviceAddress,
};

pub const Conversion = struct {
    source_size: usize,
    source: ConstAddress,
    destination_size: *usize,
    destination: Address,
    source_type: ComponentType,
    destination_type: ComponentType,
    rows: u32,
    columns: u32,
    source_layout: MatrixLayout,
    source_stride: usize,
    destination_layout: MatrixLayout,
    destination_stride: usize,
};

pub const ConversionStatus = enum { complete, destination_too_small };

pub const Converter = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _host: ?CommandFunction(raw.PFN_vkConvertCooperativeVectorMatrixNV),
    _command: ?CommandFunction(raw.PFN_vkCmdConvertCooperativeVectorMatrixNV),

    pub fn convert(converter: Converter, options: Conversion) core.Error!ConversionStatus {
        const convert_fn = converter._host orelse return error.MissingCommand;
        const info = conversionInfo(options);
        const result = convert_fn(converter._device, &info);
        if (result == raw.VK_SUCCESS) return .complete;
        if (result == raw.VK_INCOMPLETE) return .destination_too_small;
        try core.checkSuccessTracked(@constCast(converter._state), result);
        unreachable;
    }

    pub fn convertOnDevice(converter: Converter, command_buffer: *commands.Buffer, conversions: []const Conversion) core.Error!void {
        if (command_buffer._device_handle != converter._device or conversions.len == 0 or conversions.len > 64) return error.InvalidOptions;
        const convert_fn = converter._command orelse return error.MissingCommand;
        var values: [64]raw.VkConvertCooperativeVectorMatrixInfoNV = undefined;
        for (conversions, values[0..conversions.len]) |item, *value| {
            if (item.source != .device or item.destination != .device) return error.InvalidOptions;
            value.* = conversionInfo(item);
        }
        try converter._state.ensureDispatchAllowed();
        convert_fn(try command_buffer.rawHandle(), @intCast(conversions.len), values[0..conversions.len].ptr);
    }
};

fn conversionInfo(options: Conversion) raw.VkConvertCooperativeVectorMatrixInfoNV {
    return .{
        .sType = raw.VK_STRUCTURE_TYPE_CONVERT_COOPERATIVE_VECTOR_MATRIX_INFO_NV,
        .srcSize = options.source_size,
        .srcData = switch (options.source) {
            .host => |pointer| .{ .hostAddress = pointer },
            .device => |address| .{ .deviceAddress = address.toRaw() },
        },
        .pDstSize = options.destination_size,
        .dstData = switch (options.destination) {
            .host => |pointer| .{ .hostAddress = pointer },
            .device => |address| .{ .deviceAddress = address.toRaw() },
        },
        .srcComponentType = @intFromEnum(options.source_type),
        .dstComponentType = @intFromEnum(options.destination_type),
        .numRows = options.rows,
        .numColumns = options.columns,
        .srcLayout = @intFromEnum(options.source_layout),
        .srcStride = options.source_stride,
        .dstLayout = @intFromEnum(options.destination_layout),
        .dstStride = options.destination_stride,
    };
}

test "cooperative component vocabulary remains typed" {
    std.testing.refAllDecls(@This());
    try std.testing.expectEqual(@as(raw.VkComponentTypeKHR, raw.VK_COMPONENT_TYPE_FLOAT16_KHR), @intFromEnum(ComponentType.float16));
    var converter: Converter = undefined;
    converter._host = null;
    var destination_size: usize = 0;
    try std.testing.expectError(error.MissingCommand, converter.convert(.{
        .source_size = 1,
        .source = .{ .host = @ptrFromInt(0x1000) },
        .destination_size = &destination_size,
        .destination = .{ .host = @ptrFromInt(0x2000) },
        .source_type = .float16,
        .destination_type = .float16,
        .rows = 1,
        .columns = 1,
        .source_layout = .row_major,
        .source_stride = 2,
        .destination_layout = .row_major,
        .destination_stride = 2,
    }));
}
