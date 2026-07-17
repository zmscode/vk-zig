//! Typed KHR ray-tracing, acceleration-structure, and opacity-micromap support.
//!
//! Storage buffers, scratch buffers, geometry input buffers, instance targets,
//! and shader-binding-table buffers must remain alive until every submission
//! that references them completes. Host builds additionally require the host
//! addresses and destination storage to remain valid for the duration of the
//! call. Callers provide synchronization; acceleration-structure build/copy
//! writes must be made visible before tracing or later builds read them.

const std = @import("std");
const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const buffers = @import("buffer.zig");
const commands = @import("command_buffer.zig");
const debug_utils = @import("debug_utils.zig");
const pipelines = @import("pipeline.zig");
const pipeline_tools = @import("pipeline_tools.zig");
const queries = @import("query.zig");
const shaders = @import("shader.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const StructureHandle = core.NonNullHandle(raw.VkAccelerationStructureKHR);
const MicromapHandle = core.NonNullHandle(raw.VkMicromapEXT);
const geometry_count_max = 64;
const shader_stage_count_max = 32;
const shader_group_count_max = 64;
const specialization_entry_count_max = 256;

pub const AccelerationStructureFeatures = types.extension_features.AccelerationStructureFeaturesKHR;
pub const PipelineFeatures = types.extension_features.RayTracingPipelineFeaturesKHR;
pub const MicromapFeatures = types.extension_features.OpacityMicromapFeaturesEXT;

pub const StructureType = enum {
    top_level,
    bottom_level,
    generic,

    fn toRaw(value: StructureType) raw.VkAccelerationStructureTypeKHR {
        return switch (value) {
            .top_level => raw.VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR,
            .bottom_level => raw.VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR,
            .generic => raw.VK_ACCELERATION_STRUCTURE_TYPE_GENERIC_KHR,
        };
    }
};

pub const BuildTarget = enum {
    host,
    device,
    host_or_device,

    fn toRaw(value: BuildTarget) raw.VkAccelerationStructureBuildTypeKHR {
        return switch (value) {
            .host => raw.VK_ACCELERATION_STRUCTURE_BUILD_TYPE_HOST_KHR,
            .device => raw.VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
            .host_or_device => raw.VK_ACCELERATION_STRUCTURE_BUILD_TYPE_HOST_OR_DEVICE_KHR,
        };
    }
};

pub const BuildMode = enum {
    build,
    update,

    fn toRaw(value: BuildMode) raw.VkBuildAccelerationStructureModeKHR {
        return switch (value) {
            .build => raw.VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR,
            .update => raw.VK_BUILD_ACCELERATION_STRUCTURE_MODE_UPDATE_KHR,
        };
    }
};

pub const BuildFlag = enum {
    allow_update,
    allow_compaction,
    prefer_fast_trace,
    prefer_fast_build,
    low_memory,
    allow_opacity_micromap_update,
    allow_disable_opacity_micromaps,
    allow_opacity_micromap_data_update,
    micromap_lossy,
    allow_data_access,
};

pub const BuildFlags = struct {
    bits: std.EnumSet(BuildFlag) = .empty,

    pub const empty: BuildFlags = .{};

    pub fn init(values: []const BuildFlag) BuildFlags {
        var result: BuildFlags = .{};
        for (values) |value| result.bits.insert(value);
        return result;
    }

    pub fn contains(flags: BuildFlags, value: BuildFlag) bool {
        return flags.bits.contains(value);
    }

    fn toRaw(flags: BuildFlags) raw.VkBuildAccelerationStructureFlagsKHR {
        var result: raw.VkBuildAccelerationStructureFlagsKHR = 0;
        inline for (std.meta.tags(BuildFlag)) |flag| {
            if (flags.contains(flag)) result |= switch (flag) {
                .allow_update => raw.VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR,
                .allow_compaction => raw.VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_COMPACTION_BIT_KHR,
                .prefer_fast_trace => raw.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR,
                .prefer_fast_build => raw.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_BUILD_BIT_KHR,
                .low_memory => raw.VK_BUILD_ACCELERATION_STRUCTURE_LOW_MEMORY_BIT_KHR,
                .allow_opacity_micromap_update => raw.VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_OPACITY_MICROMAP_UPDATE_BIT_KHR,
                .allow_disable_opacity_micromaps => raw.VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_DISABLE_OPACITY_MICROMAPS_BIT_KHR,
                .allow_opacity_micromap_data_update => raw.VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_OPACITY_MICROMAP_DATA_UPDATE_BIT_EXT,
                .micromap_lossy => raw.VK_BUILD_ACCELERATION_STRUCTURE_MICROMAP_LOSSY_BIT_KHR,
                .allow_data_access => raw.VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_DATA_ACCESS_BIT_KHR,
            };
        }
        return result;
    }
};

pub const GeometryFlag = enum { @"opaque", no_duplicate_any_hit };
pub const GeometryFlags = struct {
    bits: std.EnumSet(GeometryFlag) = .empty,
    pub const empty: GeometryFlags = .{};

    pub fn init(values: []const GeometryFlag) GeometryFlags {
        var result: GeometryFlags = .{};
        for (values) |value| result.bits.insert(value);
        return result;
    }

    fn toRaw(flags: GeometryFlags) raw.VkGeometryFlagsKHR {
        var result: raw.VkGeometryFlagsKHR = 0;
        if (flags.bits.contains(.@"opaque")) result |= raw.VK_GEOMETRY_OPAQUE_BIT_KHR;
        if (flags.bits.contains(.no_duplicate_any_hit)) result |= raw.VK_GEOMETRY_NO_DUPLICATE_ANY_HIT_INVOCATION_BIT_KHR;
        return result;
    }
};

/// A device or host address whose variant fixes the Vulkan union member.
pub const ConstAddress = union(enum) {
    device: buffers.DeviceAddress,
    host: *const anyopaque,

    fn toRaw(value: ConstAddress) raw.VkDeviceOrHostAddressConstKHR {
        return switch (value) {
            .device => |address| .{ .deviceAddress = address.toRaw() },
            .host => |pointer| .{ .hostAddress = pointer },
        };
    }

    fn isDevice(value: ConstAddress) bool {
        return value == .device;
    }
};

pub const Address = union(enum) {
    device: buffers.DeviceAddress,
    host: *anyopaque,

    fn toRaw(value: Address) raw.VkDeviceOrHostAddressKHR {
        return switch (value) {
            .device => |address| .{ .deviceAddress = address.toRaw() },
            .host => |pointer| .{ .hostAddress = pointer },
        };
    }

    fn isDevice(value: Address) bool {
        return value == .device;
    }
};

pub const IndexType = enum {
    none,
    uint16,
    uint32,
    uint8,

    fn toRaw(value: IndexType) raw.VkIndexType {
        return switch (value) {
            .none => raw.VK_INDEX_TYPE_NONE_KHR,
            .uint16 => raw.VK_INDEX_TYPE_UINT16,
            .uint32 => raw.VK_INDEX_TYPE_UINT32,
            .uint8 => raw.VK_INDEX_TYPE_UINT8,
        };
    }
};

pub const Triangles = struct {
    vertex_format: types.Format,
    vertex_data: ConstAddress,
    vertex_stride: core.DeviceSize,
    max_vertex: u32,
    indices: union(enum) {
        none,
        uint16: ConstAddress,
        uint32: ConstAddress,
        uint8: ConstAddress,
    } = .none,
    transform: ?ConstAddress = null,
};

pub const Aabbs = struct {
    data: ConstAddress,
    stride: core.DeviceSize,
};

pub const Instances = struct {
    data: ConstAddress,
    array_of_pointers: bool = false,
};

/// Tagged geometry prevents Vulkan's triangle/AABB/instance union members from
/// being combined accidentally.
pub const Geometry = union(enum) {
    triangles: struct { data: Triangles, flags: GeometryFlags = .empty },
    aabbs: struct { data: Aabbs, flags: GeometryFlags = .empty },
    instances: struct { data: Instances, flags: GeometryFlags = .empty },
};

pub const BuildRange = struct {
    primitive_count: u32,
    primitive_offset: u32 = 0,
    first_vertex: u32 = 0,
    transform_offset: u32 = 0,

    fn toRaw(value: BuildRange) raw.VkAccelerationStructureBuildRangeInfoKHR {
        return .{
            .primitiveCount = value.primitive_count,
            .primitiveOffset = value.primitive_offset,
            .firstVertex = value.first_vertex,
            .transformOffset = value.transform_offset,
        };
    }
};

pub const BuildSizes = struct {
    structure: core.DeviceSize,
    build_scratch: core.DeviceSize,
    update_scratch: core.DeviceSize,

    fn fromRaw(value: raw.VkAccelerationStructureBuildSizesInfoKHR) BuildSizes {
        return .{
            .structure = .fromBytes(value.accelerationStructureSize),
            .build_scratch = .fromBytes(value.buildScratchSize),
            .update_scratch = .fromBytes(value.updateScratchSize),
        };
    }

    pub fn scratchFor(sizes: BuildSizes, mode: BuildMode) core.DeviceSize {
        return switch (mode) {
            .build => sizes.build_scratch,
            .update => sizes.update_scratch,
        };
    }
};

pub const Properties = struct {
    max_geometry_count: u64,
    max_instance_count: u64,
    max_primitive_count: u64,
    scratch_alignment: u32,
    shader_group_handle_size: u32,
    shader_group_capture_replay_handle_size: u32,
    shader_group_handle_alignment: u32,
    shader_group_base_alignment: u32,
    max_shader_group_stride: u32,
    max_recursion_depth: u32,
    max_dispatch_invocations: u32,

    pub fn fromRaw(
        acceleration: raw.VkPhysicalDeviceAccelerationStructurePropertiesKHR,
        pipeline: raw.VkPhysicalDeviceRayTracingPipelinePropertiesKHR,
    ) Properties {
        return .{
            .max_geometry_count = acceleration.maxGeometryCount,
            .max_instance_count = acceleration.maxInstanceCount,
            .max_primitive_count = acceleration.maxPrimitiveCount,
            .scratch_alignment = acceleration.minAccelerationStructureScratchOffsetAlignment,
            .shader_group_handle_size = pipeline.shaderGroupHandleSize,
            .shader_group_capture_replay_handle_size = pipeline.shaderGroupHandleCaptureReplaySize,
            .shader_group_handle_alignment = pipeline.shaderGroupHandleAlignment,
            .shader_group_base_alignment = pipeline.shaderGroupBaseAlignment,
            .max_shader_group_stride = pipeline.maxShaderGroupStride,
            .max_recursion_depth = pipeline.maxRayRecursionDepth,
            .max_dispatch_invocations = pipeline.maxRayDispatchInvocationCount,
        };
    }
};

pub const ContextOptions = struct {
    properties: Properties,
};

pub const StructureOptions = struct {
    type: StructureType,
    storage: *const buffers.Buffer,
    offset: core.DeviceOffset = .zero,
    size: core.DeviceSize,
    capture_replay_address: ?buffers.DeviceAddress = null,
};

pub const Structure = struct {
    _handle: ?StructureHandle,
    _owner: core.Owner,
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _storage: *const buffers.Buffer,
    type: StructureType,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _destroy: CommandFunction(raw.PFN_vkDestroyAccelerationStructureKHR),

    pub fn deinit(value: *Structure) void {
        if (!(value._owner.release(value) catch return)) return;
        const handle = value._handle orelse return;
        value._destroy(value._device, handle, value.allocation_callbacks);
        value._handle = null;
    }

    pub fn rawHandle(value: *const Structure) core.Error!raw.VkAccelerationStructureKHR {
        try value._owner.validate(value);
        try value._state.ensureDispatchAllowed();
        _ = try value._storage.rawHandle();
        return value._handle orelse error.InactiveObject;
    }

    pub fn debugObject(value: *const Structure) core.Error!debug_utils.Object {
        return .forDevice(.acceleration_structure, try value.rawHandle(), value._device);
    }
};

pub const Build = struct {
    type: StructureType,
    flags: BuildFlags = .empty,
    mode: BuildMode = .build,
    source: ?*const Structure = null,
    destination: *const Structure,
    geometries: []const Geometry,
    ranges: []const BuildRange,
    scratch: Address,
    scratch_size: core.DeviceSize,
};

pub const CopyMode = enum { clone, compact };
pub const Compatibility = enum { compatible, incompatible };
pub const HostStatus = enum { complete, deferred, not_deferred };

pub const Property = enum {
    compacted_size,
    serialization_size,
    size,

    fn toRaw(value: Property) raw.VkQueryType {
        return switch (value) {
            .compacted_size => raw.VK_QUERY_TYPE_ACCELERATION_STRUCTURE_COMPACTED_SIZE_KHR,
            .serialization_size => raw.VK_QUERY_TYPE_ACCELERATION_STRUCTURE_SERIALIZATION_SIZE_KHR,
            .size => raw.VK_QUERY_TYPE_ACCELERATION_STRUCTURE_SIZE_KHR,
        };
    }

    fn matchesQuery(value: Property, kind: queries.Kind) bool {
        return switch (value) {
            .compacted_size => kind == .acceleration_structure_compacted_size,
            .serialization_size => kind == .acceleration_structure_serialization_size,
            .size => kind == .acceleration_structure_size,
        };
    }
};

pub const ShaderGroup = union(enum) {
    general: u32,
    triangles_hit: struct { closest_hit: ?u32 = null, any_hit: ?u32 = null },
    procedural_hit: struct { intersection: u32, closest_hit: ?u32 = null, any_hit: ?u32 = null },
};

pub const PipelineOptions = struct {
    stages: []const shaders.StageOptions,
    groups: []const ShaderGroup,
    layout: *const pipelines.Layout,
    max_recursion_depth: u32 = 1,
    cache: ?*const pipeline_tools.Cache = null,
    deferred: ?*const pipeline_tools.DeferredOperation = null,
    fail_on_compile_required: bool = false,
};

pub const PipelineCreateResult = union(enum) {
    success: pipelines.Pipeline,
    compile_required,
    deferred: pipelines.Pipeline,
    not_deferred: pipelines.Pipeline,
};

pub const ShaderBindingRegion = struct {
    address: ?buffers.DeviceAddress = null,
    stride: core.DeviceSize = .zero,
    size: core.DeviceSize = .zero,

    fn toRaw(region: ShaderBindingRegion, properties: Properties, raygen: bool) core.Error!raw.VkStridedDeviceAddressRegionKHR {
        const address = if (region.address) |value| value.toRaw() else 0;
        const stride = region.stride.bytes();
        const size = region.size.bytes();
        if (address == 0) {
            if (stride != 0 or size != 0) return error.InvalidOptions;
            return .{};
        }
        if (stride == 0 or size == 0 or size % stride != 0 or stride > properties.max_shader_group_stride) return error.InvalidOptions;
        if (stride % properties.shader_group_handle_alignment != 0 or address % properties.shader_group_base_alignment != 0) return error.InvalidOptions;
        if (raygen and size != stride) return error.InvalidOptions;
        return .{ .deviceAddress = address, .stride = stride, .size = size };
    }
};

pub const ShaderBindingTables = struct {
    raygen: ShaderBindingRegion,
    miss: ShaderBindingRegion = .{},
    hit: ShaderBindingRegion = .{},
    callable: ShaderBindingRegion = .{},
};

pub const Trace = struct {
    tables: ShaderBindingTables,
    width: u32,
    height: u32 = 1,
    depth: u32 = 1,
};

pub const Context = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    properties: Properties,
    _create_structure: ?CommandFunction(raw.PFN_vkCreateAccelerationStructureKHR),
    _destroy_structure: ?CommandFunction(raw.PFN_vkDestroyAccelerationStructureKHR),
    _build_sizes: ?CommandFunction(raw.PFN_vkGetAccelerationStructureBuildSizesKHR),
    _build_host: ?CommandFunction(raw.PFN_vkBuildAccelerationStructuresKHR),
    _build_command: ?CommandFunction(raw.PFN_vkCmdBuildAccelerationStructuresKHR),
    _copy_host: ?CommandFunction(raw.PFN_vkCopyAccelerationStructureKHR),
    _copy_command: ?CommandFunction(raw.PFN_vkCmdCopyAccelerationStructureKHR),
    _serialize_host: ?CommandFunction(raw.PFN_vkCopyAccelerationStructureToMemoryKHR),
    _serialize_command: ?CommandFunction(raw.PFN_vkCmdCopyAccelerationStructureToMemoryKHR),
    _deserialize_host: ?CommandFunction(raw.PFN_vkCopyMemoryToAccelerationStructureKHR),
    _deserialize_command: ?CommandFunction(raw.PFN_vkCmdCopyMemoryToAccelerationStructureKHR),
    _address: ?CommandFunction(raw.PFN_vkGetAccelerationStructureDeviceAddressKHR),
    _compatibility: ?CommandFunction(raw.PFN_vkGetDeviceAccelerationStructureCompatibilityKHR),
    _write_properties_host: ?CommandFunction(raw.PFN_vkWriteAccelerationStructuresPropertiesKHR),
    _write_properties_command: ?CommandFunction(raw.PFN_vkCmdWriteAccelerationStructuresPropertiesKHR),
    _create_pipeline: ?CommandFunction(raw.PFN_vkCreateRayTracingPipelinesKHR),
    _destroy_pipeline: CommandFunction(raw.PFN_vkDestroyPipeline),
    _group_handles: ?CommandFunction(raw.PFN_vkGetRayTracingShaderGroupHandlesKHR),
    _capture_group_handles: ?CommandFunction(raw.PFN_vkGetRayTracingCaptureReplayShaderGroupHandlesKHR),
    _group_stack_size: ?CommandFunction(raw.PFN_vkGetRayTracingShaderGroupStackSizeKHR),
    _trace: ?CommandFunction(raw.PFN_vkCmdTraceRaysKHR),
    _trace_indirect: ?CommandFunction(raw.PFN_vkCmdTraceRaysIndirectKHR),
    _set_stack_size: ?CommandFunction(raw.PFN_vkCmdSetRayTracingPipelineStackSizeKHR),
    micromaps: MicromapContext,

    pub fn createStructure(context: Context, options: StructureOptions) core.Error!Structure {
        try context._state.ensureDispatchAllowed();
        const create = context._create_structure orelse return error.MissingCommand;
        const destroy = context._destroy_structure orelse return error.MissingCommand;
        if (options.storage._device_handle != context._device or options.size.bytes() == 0) return error.InvalidOptions;
        const offset = options.offset.bytes();
        if (offset > options.storage.size.bytes() or options.size.bytes() > options.storage.size.bytes() - offset) return error.InvalidOptions;
        const info: raw.VkAccelerationStructureCreateInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_CREATE_INFO_KHR,
            .createFlags = if (options.capture_replay_address != null) raw.VK_ACCELERATION_STRUCTURE_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT_KHR else 0,
            .buffer = try options.storage.rawHandle(),
            .offset = offset,
            .size = options.size.bytes(),
            .type = options.type.toRaw(),
            .deviceAddress = if (options.capture_replay_address) |address| address.toRaw() else 0,
        };
        var handle: raw.VkAccelerationStructureKHR = null;
        const result = create(context._device, &info, context._allocation_callbacks, &handle);
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional| destroy(context._device, provisional, context._allocation_callbacks);
            try core.checkSuccess(result);
        }
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._owner = try .init(&handle),
            ._device = context._device,
            ._state = context._state,
            ._storage = options.storage,
            .type = options.type,
            .allocation_callbacks = context._allocation_callbacks,
            ._destroy = destroy,
        };
    }

    pub fn buildSizes(context: Context, target: BuildTarget, type_: StructureType, flags: BuildFlags, geometries: []const Geometry, max_primitive_counts: []const u32) core.Error!BuildSizes {
        const get = context._build_sizes orelse return error.MissingCommand;
        if (geometries.len == 0 or geometries.len > geometry_count_max or geometries.len != max_primitive_counts.len) return error.InvalidOptions;
        if (geometries.len > context.properties.max_geometry_count) return error.InvalidOptions;
        var primitive_total: u64 = 0;
        for (geometries, max_primitive_counts) |geometry, primitive_count| {
            if (primitive_count == 0 or !geometryAllowed(type_, geometry) or !geometryMatchesTarget(geometry, target)) return error.InvalidOptions;
            primitive_total = std.math.add(u64, primitive_total, primitive_count) catch return error.SizeOverflow;
        }
        const primitive_limit = if (type_ == .top_level) context.properties.max_instance_count else context.properties.max_primitive_count;
        if (primitive_total > primitive_limit) return error.InvalidOptions;
        var raw_geometries: [geometry_count_max]raw.VkAccelerationStructureGeometryKHR = undefined;
        try convertGeometries(geometries, &raw_geometries);
        const info: raw.VkAccelerationStructureBuildGeometryInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR,
            .type = type_.toRaw(),
            .flags = flags.toRaw(),
            .geometryCount = @intCast(geometries.len),
            .pGeometries = raw_geometries[0..geometries.len].ptr,
        };
        var sizes: raw.VkAccelerationStructureBuildSizesInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_SIZES_INFO_KHR,
        };
        get(context._device, target.toRaw(), &info, max_primitive_counts.ptr, &sizes);
        return .fromRaw(sizes);
    }

    pub fn buildHost(context: Context, build: Build, deferred: ?*const pipeline_tools.DeferredOperation) core.Error!HostStatus {
        const function = context._build_host orelse return error.MissingCommand;
        var converted = try context.convertBuild(build, .host);
        converted.info.pGeometries = converted.geometries[0..build.geometries.len].ptr;
        const deferred_handle = if (deferred) |operation| try operation.rawHandle() else null;
        const ranges = [_][*c]const raw.VkAccelerationStructureBuildRangeInfoKHR{converted.ranges.ptr};
        const result = function(context._device, deferred_handle, 1, &converted.info, &ranges);
        return hostStatus(result);
    }

    pub fn buildCommand(context: Context, command_buffer: *commands.Buffer, build: Build) core.Error!void {
        const function = context._build_command orelse return error.MissingCommand;
        try validateCommand(context, command_buffer);
        var converted = try context.convertBuild(build, .device);
        converted.info.pGeometries = converted.geometries[0..build.geometries.len].ptr;
        const ranges = [_][*c]const raw.VkAccelerationStructureBuildRangeInfoKHR{converted.ranges.ptr};
        function(try command_buffer.rawHandle(), 1, &converted.info, &ranges);
    }

    pub fn copyHost(context: Context, source: *const Structure, destination: *const Structure, mode: CopyMode, deferred: ?*const pipeline_tools.DeferredOperation) core.Error!HostStatus {
        const function = context._copy_host orelse return error.MissingCommand;
        try validateStructures(context, source, destination);
        const info = copyInfo(try source.rawHandle(), try destination.rawHandle(), mode);
        return hostStatus(function(context._device, if (deferred) |value| try value.rawHandle() else null, &info));
    }

    pub fn copyCommand(context: Context, command_buffer: *commands.Buffer, source: *const Structure, destination: *const Structure, mode: CopyMode) core.Error!void {
        const function = context._copy_command orelse return error.MissingCommand;
        try validateCommand(context, command_buffer);
        try validateStructures(context, source, destination);
        const info = copyInfo(try source.rawHandle(), try destination.rawHandle(), mode);
        function(try command_buffer.rawHandle(), &info);
    }

    pub fn serializeHost(context: Context, source: *const Structure, destination: Address, deferred: ?*const pipeline_tools.DeferredOperation) core.Error!HostStatus {
        const function = context._serialize_host orelse return error.MissingCommand;
        if (source._device != context._device or destination.isDevice()) return error.InvalidOptions;
        const info: raw.VkCopyAccelerationStructureToMemoryInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_COPY_ACCELERATION_STRUCTURE_TO_MEMORY_INFO_KHR,
            .src = try source.rawHandle(),
            .dst = destination.toRaw(),
            .mode = raw.VK_COPY_ACCELERATION_STRUCTURE_MODE_SERIALIZE_KHR,
        };
        return hostStatus(function(context._device, if (deferred) |value| try value.rawHandle() else null, &info));
    }

    pub fn serializeCommand(context: Context, command_buffer: *commands.Buffer, source: *const Structure, destination: Address) core.Error!void {
        const function = context._serialize_command orelse return error.MissingCommand;
        try validateCommand(context, command_buffer);
        if (source._device != context._device or !destination.isDevice()) return error.InvalidOptions;
        const info: raw.VkCopyAccelerationStructureToMemoryInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_COPY_ACCELERATION_STRUCTURE_TO_MEMORY_INFO_KHR,
            .src = try source.rawHandle(),
            .dst = destination.toRaw(),
            .mode = raw.VK_COPY_ACCELERATION_STRUCTURE_MODE_SERIALIZE_KHR,
        };
        function(try command_buffer.rawHandle(), &info);
    }

    pub fn deserializeHost(context: Context, source: ConstAddress, destination: *const Structure, deferred: ?*const pipeline_tools.DeferredOperation) core.Error!HostStatus {
        const function = context._deserialize_host orelse return error.MissingCommand;
        if (destination._device != context._device or source.isDevice()) return error.InvalidOptions;
        const info: raw.VkCopyMemoryToAccelerationStructureInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_COPY_MEMORY_TO_ACCELERATION_STRUCTURE_INFO_KHR,
            .src = source.toRaw(),
            .dst = try destination.rawHandle(),
            .mode = raw.VK_COPY_ACCELERATION_STRUCTURE_MODE_DESERIALIZE_KHR,
        };
        return hostStatus(function(context._device, if (deferred) |value| try value.rawHandle() else null, &info));
    }

    pub fn deserializeCommand(context: Context, command_buffer: *commands.Buffer, source: ConstAddress, destination: *const Structure) core.Error!void {
        const function = context._deserialize_command orelse return error.MissingCommand;
        try validateCommand(context, command_buffer);
        if (destination._device != context._device or !source.isDevice()) return error.InvalidOptions;
        const info: raw.VkCopyMemoryToAccelerationStructureInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_COPY_MEMORY_TO_ACCELERATION_STRUCTURE_INFO_KHR,
            .src = source.toRaw(),
            .dst = try destination.rawHandle(),
            .mode = raw.VK_COPY_ACCELERATION_STRUCTURE_MODE_DESERIALIZE_KHR,
        };
        function(try command_buffer.rawHandle(), &info);
    }

    pub fn deviceAddress(context: Context, structure: *const Structure) core.Error!?buffers.DeviceAddress {
        const get = context._address orelse return error.MissingCommand;
        if (structure._device != context._device) return error.InvalidHandle;
        const info: raw.VkAccelerationStructureDeviceAddressInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_DEVICE_ADDRESS_INFO_KHR,
            .accelerationStructure = try structure.rawHandle(),
        };
        return .fromRaw(get(context._device, &info));
    }

    pub fn serializedCompatibility(context: Context, version_data: *const [2 * raw.VK_UUID_SIZE]u8) core.Error!Compatibility {
        const get = context._compatibility orelse return error.MissingCommand;
        const info: raw.VkAccelerationStructureVersionInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_VERSION_INFO_KHR,
            .pVersionData = version_data,
        };
        var result: raw.VkAccelerationStructureCompatibilityKHR = undefined;
        get(context._device, &info, &result);
        return switch (result) {
            raw.VK_ACCELERATION_STRUCTURE_COMPATIBILITY_COMPATIBLE_KHR => .compatible,
            raw.VK_ACCELERATION_STRUCTURE_COMPATIBILITY_INCOMPATIBLE_KHR => .incompatible,
            else => error.InvalidProperties,
        };
    }

    pub fn propertiesHost(context: Context, structures: []const *const Structure, kind: Property, destination: []u64) core.Error!void {
        const write = context._write_properties_host orelse return error.MissingCommand;
        if (structures.len == 0 or structures.len > geometry_count_max or destination.len < structures.len) return error.InvalidOptions;
        var handles: [geometry_count_max]raw.VkAccelerationStructureKHR = undefined;
        for (structures, 0..) |structure, index| {
            if (structure._device != context._device) return error.InvalidHandle;
            handles[index] = try structure.rawHandle();
        }
        try core.checkSuccess(write(context._device, @intCast(structures.len), handles[0..structures.len].ptr, kind.toRaw(), structures.len * @sizeOf(u64), destination.ptr, @sizeOf(u64)));
    }

    pub fn writeProperties(context: Context, command_buffer: *commands.Buffer, structures: []const *const Structure, pool: *const queries.Pool, first_query: u32, kind: Property) core.Error!void {
        const write = context._write_properties_command orelse return error.MissingCommand;
        try validateCommand(context, command_buffer);
        if (structures.len == 0 or structures.len > geometry_count_max or first_query > pool.count or structures.len > pool.count - first_query or pool._device_handle != context._device or !kind.matchesQuery(pool.kind)) return error.InvalidOptions;
        var handles: [geometry_count_max]raw.VkAccelerationStructureKHR = undefined;
        for (structures, 0..) |structure, index| {
            if (structure._device != context._device) return error.InvalidHandle;
            handles[index] = try structure.rawHandle();
        }
        write(try command_buffer.rawHandle(), @intCast(structures.len), handles[0..structures.len].ptr, kind.toRaw(), try pool.rawHandle(), first_query);
    }

    pub fn createPipeline(context: Context, options: PipelineOptions) core.Error!PipelineCreateResult {
        const create = context._create_pipeline orelse return error.MissingCommand;
        if (options.stages.len == 0 or options.stages.len > shader_stage_count_max or options.groups.len == 0 or options.groups.len > shader_group_count_max or options.max_recursion_depth == 0 or options.max_recursion_depth > context.properties.max_recursion_depth or options.layout._device_handle != context._device) return error.InvalidOptions;
        var graph: PipelineGraph = .{};
        const raw_stages = try graph.stages(options.stages, context._device);
        const raw_groups = try graph.groups(options.groups, options.stages);
        const info: raw.VkRayTracingPipelineCreateInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_RAY_TRACING_PIPELINE_CREATE_INFO_KHR,
            .flags = if (options.fail_on_compile_required) raw.VK_PIPELINE_CREATE_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT else 0,
            .stageCount = @intCast(raw_stages.len),
            .pStages = raw_stages.ptr,
            .groupCount = @intCast(raw_groups.len),
            .pGroups = raw_groups.ptr,
            .maxPipelineRayRecursionDepth = options.max_recursion_depth,
            .layout = try options.layout.rawHandle(),
        };
        var handle: raw.VkPipeline = null;
        const result = create(
            context._device,
            if (options.deferred) |value| try value.rawHandle() else null,
            if (options.cache) |value| try value.rawHandle() else null,
            1,
            &info,
            context._allocation_callbacks,
            &handle,
        );
        if (result == raw.VK_PIPELINE_COMPILE_REQUIRED) {
            if (handle) |provisional| context._destroy_pipeline(context._device, provisional, context._allocation_callbacks);
            return .compile_required;
        }
        if (result != raw.VK_SUCCESS) {
            if (result != raw.VK_OPERATION_DEFERRED_KHR and result != raw.VK_OPERATION_NOT_DEFERRED_KHR) {
                if (handle) |provisional| context._destroy_pipeline(context._device, provisional, context._allocation_callbacks);
                try core.checkSuccess(result);
            }
        }
        if (handle == null) {
            return error.InvalidHandle;
        }
        var pipeline: pipelines.Pipeline = .{
            ._handle = handle orelse return error.InvalidHandle,
            ._owner = try .init(&handle),
            ._device_handle = context._device,
            ._device_state = context._state.*,
            .bind_point = @enumFromInt(raw.VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR),
            .allocation_callbacks = context._allocation_callbacks,
            .destroy_pipeline = context._destroy_pipeline,
        };
        pipeline._dynamic_rendering = false;
        if (result == raw.VK_OPERATION_DEFERRED_KHR) return .{ .deferred = pipeline };
        if (result == raw.VK_OPERATION_NOT_DEFERRED_KHR) return .{ .not_deferred = pipeline };
        return .{ .success = pipeline };
    }

    pub fn shaderGroupHandles(context: Context, pipeline: *const pipelines.Pipeline, first_group: u32, group_count: u32, destination: []u8) core.Error!void {
        const get = context._group_handles orelse return error.MissingCommand;
        try context.getGroupHandles(get, context.properties.shader_group_handle_size, pipeline, first_group, group_count, destination);
    }

    pub fn captureReplayShaderGroupHandles(context: Context, pipeline: *const pipelines.Pipeline, first_group: u32, group_count: u32, destination: []u8) core.Error!void {
        const get = context._capture_group_handles orelse return error.MissingCommand;
        try context.getGroupHandles(get, context.properties.shader_group_capture_replay_handle_size, pipeline, first_group, group_count, destination);
    }

    pub fn shaderGroupStackSize(context: Context, pipeline: *const pipelines.Pipeline, group: u32, shader_kind: ShaderInGroup) core.Error!core.DeviceSize {
        const get = context._group_stack_size orelse return error.MissingCommand;
        if (pipeline._device_handle != context._device or pipeline.bind_point.toRaw() != raw.VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR) return error.InvalidHandle;
        return .fromBytes(get(context._device, try pipeline.rawHandle(), group, shader_kind.toRaw()));
    }

    pub fn setPipelineStackSize(context: Context, command_buffer: *commands.Buffer, size: core.DeviceSize) core.Error!void {
        const set = context._set_stack_size orelse return error.MissingCommand;
        try validateCommand(context, command_buffer);
        if (size.bytes() == 0 or size.bytes() > std.math.maxInt(u32)) return error.InvalidOptions;
        set(try command_buffer.rawHandle(), @intCast(size.bytes()));
    }

    pub fn trace(context: Context, command_buffer: *commands.Buffer, options: Trace) core.Error!void {
        const function = context._trace orelse return error.MissingCommand;
        try validateTraceCommand(context, command_buffer, options);
        const raygen = try options.tables.raygen.toRaw(context.properties, true);
        const miss = try options.tables.miss.toRaw(context.properties, false);
        const hit = try options.tables.hit.toRaw(context.properties, false);
        const callable = try options.tables.callable.toRaw(context.properties, false);
        function(try command_buffer.rawHandle(), &raygen, &miss, &hit, &callable, options.width, options.height, options.depth);
    }

    pub fn traceIndirect(context: Context, command_buffer: *commands.Buffer, tables: ShaderBindingTables, indirect: buffers.DeviceAddress) core.Error!void {
        const function = context._trace_indirect orelse return error.MissingCommand;
        try validateCommand(context, command_buffer);
        if (!command_buffer.ray_tracing_pipeline_bound) return error.InvalidOptions;
        const raygen = try tables.raygen.toRaw(context.properties, true);
        const miss = try tables.miss.toRaw(context.properties, false);
        const hit = try tables.hit.toRaw(context.properties, false);
        const callable = try tables.callable.toRaw(context.properties, false);
        function(try command_buffer.rawHandle(), &raygen, &miss, &hit, &callable, indirect.toRaw());
    }

    fn getGroupHandles(context: Context, get: anytype, handle_size: u32, pipeline: *const pipelines.Pipeline, first_group: u32, group_count: u32, destination: []u8) core.Error!void {
        if (pipeline._device_handle != context._device or pipeline.bind_point.toRaw() != raw.VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR or group_count == 0) return error.InvalidOptions;
        const needed = std.math.mul(usize, group_count, handle_size) catch return error.SizeOverflow;
        if (destination.len < needed) return error.BufferTooSmall;
        try core.checkSuccess(get(context._device, try pipeline.rawHandle(), first_group, group_count, needed, destination.ptr));
    }

    const ConvertedBuild = struct {
        info: raw.VkAccelerationStructureBuildGeometryInfoKHR,
        geometries: [geometry_count_max]raw.VkAccelerationStructureGeometryKHR,
        ranges: [geometry_count_max]raw.VkAccelerationStructureBuildRangeInfoKHR,
    };

    fn convertBuild(context: Context, build: Build, target: BuildTarget) core.Error!ConvertedBuild {
        if (build.destination._device != context._device or build.destination.type != build.type or build.geometries.len == 0 or build.geometries.len > geometry_count_max or build.ranges.len != build.geometries.len) return error.InvalidOptions;
        if (build.mode == .update and (!build.flags.contains(.allow_update) or build.source == null)) return error.InvalidOptions;
        if (build.source) |source| if (source._device != context._device or source.type != build.type) return error.InvalidHandle;
        if ((target == .device) != build.scratch.isDevice()) return error.InvalidOptions;
        var primitive_counts: [geometry_count_max]u32 = undefined;
        for (build.ranges, 0..) |range, index| primitive_counts[index] = range.primitive_count;
        const required_scratch = (try context.buildSizes(
            target,
            build.type,
            build.flags,
            build.geometries,
            primitive_counts[0..build.ranges.len],
        )).scratchFor(build.mode).bytes();
        if (build.scratch_size.bytes() < required_scratch) return error.BufferTooSmall;
        if (build.scratch == .device) {
            const address = build.scratch.device.toRaw();
            if (context.properties.scratch_alignment == 0 or address % context.properties.scratch_alignment != 0) return error.InvalidOptions;
        }
        var result: ConvertedBuild = undefined;
        try convertGeometries(build.geometries, &result.geometries);
        for (build.ranges, 0..) |range, index| {
            if (range.primitive_count == 0) return error.InvalidOptions;
            result.ranges[index] = range.toRaw();
        }
        result.info = .{
            .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR,
            .type = build.type.toRaw(),
            .flags = build.flags.toRaw(),
            .mode = build.mode.toRaw(),
            .srcAccelerationStructure = if (build.source) |source| try source.rawHandle() else null,
            .dstAccelerationStructure = try build.destination.rawHandle(),
            .geometryCount = @intCast(build.geometries.len),
            .pGeometries = result.geometries[0..build.geometries.len].ptr,
            .scratchData = build.scratch.toRaw(),
        };
        return result;
    }
};

pub const ShaderInGroup = enum {
    general,
    closest_hit,
    any_hit,
    intersection,

    fn toRaw(value: ShaderInGroup) raw.VkShaderGroupShaderKHR {
        return switch (value) {
            .general => raw.VK_SHADER_GROUP_SHADER_GENERAL_KHR,
            .closest_hit => raw.VK_SHADER_GROUP_SHADER_CLOSEST_HIT_KHR,
            .any_hit => raw.VK_SHADER_GROUP_SHADER_ANY_HIT_KHR,
            .intersection => raw.VK_SHADER_GROUP_SHADER_INTERSECTION_KHR,
        };
    }
};

fn convertGeometries(values: []const Geometry, destination: *[geometry_count_max]raw.VkAccelerationStructureGeometryKHR) core.Error!void {
    for (values, 0..) |value, index| destination[index] = switch (value) {
        .triangles => |triangle| blk: {
            const indices: struct { kind: IndexType, data: ?ConstAddress } = switch (triangle.data.indices) {
                .none => .{ .kind = .none, .data = null },
                .uint16 => |address| .{ .kind = .uint16, .data = address },
                .uint32 => |address| .{ .kind = .uint32, .data = address },
                .uint8 => |address| .{ .kind = .uint8, .data = address },
            };
            if (triangle.data.vertex_stride.bytes() == 0 or (indices.kind == .none) != (indices.data == null)) return error.InvalidOptions;
            break :blk .{
                .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR,
                .geometryType = raw.VK_GEOMETRY_TYPE_TRIANGLES_KHR,
                .geometry = .{ .triangles = .{
                    .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_TRIANGLES_DATA_KHR,
                    .vertexFormat = triangle.data.vertex_format.toRaw(),
                    .vertexData = triangle.data.vertex_data.toRaw(),
                    .vertexStride = triangle.data.vertex_stride.bytes(),
                    .maxVertex = triangle.data.max_vertex,
                    .indexType = indices.kind.toRaw(),
                    .indexData = if (indices.data) |address| address.toRaw() else .{ .deviceAddress = 0 },
                    .transformData = if (triangle.data.transform) |address| address.toRaw() else .{ .deviceAddress = 0 },
                } },
                .flags = triangle.flags.toRaw(),
            };
        },
        .aabbs => |aabb| blk: {
            if (aabb.data.stride.bytes() < 24 or aabb.data.stride.bytes() % 8 != 0) return error.InvalidOptions;
            break :blk .{
                .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR,
                .geometryType = raw.VK_GEOMETRY_TYPE_AABBS_KHR,
                .geometry = .{ .aabbs = .{
                    .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_AABBS_DATA_KHR,
                    .data = aabb.data.data.toRaw(),
                    .stride = aabb.data.stride.bytes(),
                } },
                .flags = aabb.flags.toRaw(),
            };
        },
        .instances => |instances| .{
            .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR,
            .geometryType = raw.VK_GEOMETRY_TYPE_INSTANCES_KHR,
            .geometry = .{ .instances = .{
                .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR,
                .arrayOfPointers = if (instances.data.array_of_pointers) raw.VK_TRUE else raw.VK_FALSE,
                .data = instances.data.data.toRaw(),
            } },
            .flags = instances.flags.toRaw(),
        },
    };
}

fn geometryAllowed(type_: StructureType, geometry: Geometry) bool {
    return switch (type_) {
        .top_level => geometry == .instances,
        .bottom_level => geometry != .instances,
        .generic => true,
    };
}

fn addressMatchesTarget(address: anytype, target: BuildTarget) bool {
    return switch (target) {
        .host => !address.isDevice(),
        .device => address.isDevice(),
        .host_or_device => true,
    };
}

fn geometryMatchesTarget(geometry: Geometry, target: BuildTarget) bool {
    return switch (geometry) {
        .triangles => |value| blk: {
            if (!addressMatchesTarget(value.data.vertex_data, target)) break :blk false;
            switch (value.data.indices) {
                .none => {},
                .uint16, .uint32, .uint8 => |address| if (!addressMatchesTarget(address, target)) break :blk false,
            }
            if (value.data.transform) |address| if (!addressMatchesTarget(address, target)) break :blk false;
            break :blk true;
        },
        .aabbs => |value| addressMatchesTarget(value.data.data, target),
        .instances => |value| addressMatchesTarget(value.data.data, target),
    };
}

fn copyInfo(source: raw.VkAccelerationStructureKHR, destination: raw.VkAccelerationStructureKHR, mode: CopyMode) raw.VkCopyAccelerationStructureInfoKHR {
    return .{
        .sType = raw.VK_STRUCTURE_TYPE_COPY_ACCELERATION_STRUCTURE_INFO_KHR,
        .src = source,
        .dst = destination,
        .mode = switch (mode) {
            .clone => raw.VK_COPY_ACCELERATION_STRUCTURE_MODE_CLONE_KHR,
            .compact => raw.VK_COPY_ACCELERATION_STRUCTURE_MODE_COMPACT_KHR,
        },
    };
}

fn hostStatus(result: raw.VkResult) core.Error!HostStatus {
    if (result == raw.VK_SUCCESS) return .complete;
    if (result == raw.VK_OPERATION_DEFERRED_KHR) return .deferred;
    if (result == raw.VK_OPERATION_NOT_DEFERRED_KHR) return .not_deferred;
    try core.checkSuccess(result);
    unreachable;
}

fn validateCommand(context: Context, buffer: *commands.Buffer) core.Error!void {
    if (buffer._device_handle != context._device) return error.InvalidHandle;
    if (buffer.state != .recording or buffer.rendering_active or buffer.render_pass_active or buffer.video_coding_active) return error.InvalidOptions;
}

fn validateStructures(context: Context, source: *const Structure, destination: *const Structure) core.Error!void {
    if (source._device != context._device or destination._device != context._device or source.type != destination.type) return error.InvalidHandle;
}

fn validateTraceCommand(context: Context, buffer: *commands.Buffer, options: Trace) core.Error!void {
    try validateCommand(context, buffer);
    if (!buffer.ray_tracing_pipeline_bound or options.width == 0 or options.height == 0 or options.depth == 0) return error.InvalidOptions;
    const invocations = std.math.mul(u64, options.width, options.height) catch return error.SizeOverflow;
    const total = std.math.mul(u64, invocations, options.depth) catch return error.SizeOverflow;
    if (total > context.properties.max_dispatch_invocations) return error.InvalidOptions;
}

const PipelineGraph = struct {
    raw_stages: [shader_stage_count_max]raw.VkPipelineShaderStageCreateInfo = undefined,
    specializations: [shader_stage_count_max]raw.VkSpecializationInfo = undefined,
    entries: [specialization_entry_count_max]raw.VkSpecializationMapEntry = undefined,
    raw_groups: [shader_group_count_max]raw.VkRayTracingShaderGroupCreateInfoKHR = undefined,
    entry_count: usize = 0,

    fn stages(graph: *PipelineGraph, values: []const shaders.StageOptions, device: DeviceHandle) core.Error![]const raw.VkPipelineShaderStageCreateInfo {
        for (values, 0..) |value, index| {
            if (value.module._device_handle != device or !isRayStage(value.stage)) return error.InvalidOptions;
            var specialization_pointer: ?*const raw.VkSpecializationInfo = null;
            if (value.specialization) |specialization| {
                try specialization.validate();
                if (graph.entry_count + specialization.entries.len > graph.entries.len) return error.CountOverflow;
                const start = graph.entry_count;
                for (specialization.entries, 0..) |entry, entry_index| graph.entries[start + entry_index] = .{
                    .constantID = entry.constant_id,
                    .offset = @intCast(entry.offset),
                    .size = entry.size,
                };
                graph.entry_count += specialization.entries.len;
                graph.specializations[index] = .{
                    .mapEntryCount = @intCast(specialization.entries.len),
                    .pMapEntries = graph.entries[start..graph.entry_count].ptr,
                    .dataSize = specialization.data.len,
                    .pData = specialization.data.ptr,
                };
                specialization_pointer = &graph.specializations[index];
            }
            graph.raw_stages[index] = .{
                .sType = raw.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = value.stage.toRaw(),
                .module = try value.module.rawHandle(),
                .pName = value.entry_point.ptr,
                .pSpecializationInfo = specialization_pointer,
            };
        }
        return graph.raw_stages[0..values.len];
    }

    fn groups(graph: *PipelineGraph, values: []const ShaderGroup, stages_: []const shaders.StageOptions) core.Error![]const raw.VkRayTracingShaderGroupCreateInfoKHR {
        const unused = raw.VK_SHADER_UNUSED_KHR;
        for (values, 0..) |value, index| graph.raw_groups[index] = switch (value) {
            .general => |stage| blk: {
                try validateStageIndex(stages_, stage, &.{ .ray_generation, .miss, .callable });
                break :blk .{ .sType = raw.VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR, .type = raw.VK_RAY_TRACING_SHADER_GROUP_TYPE_GENERAL_KHR, .generalShader = stage, .closestHitShader = unused, .anyHitShader = unused, .intersectionShader = unused };
            },
            .triangles_hit => |hit| blk: {
                if (hit.closest_hit == null and hit.any_hit == null) return error.InvalidOptions;
                if (hit.closest_hit) |stage| try validateStageIndex(stages_, stage, &.{.closest_hit});
                if (hit.any_hit) |stage| try validateStageIndex(stages_, stage, &.{.any_hit});
                break :blk .{ .sType = raw.VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR, .type = raw.VK_RAY_TRACING_SHADER_GROUP_TYPE_TRIANGLES_HIT_GROUP_KHR, .generalShader = unused, .closestHitShader = hit.closest_hit orelse unused, .anyHitShader = hit.any_hit orelse unused, .intersectionShader = unused };
            },
            .procedural_hit => |hit| blk: {
                try validateStageIndex(stages_, hit.intersection, &.{.intersection});
                if (hit.closest_hit) |stage| try validateStageIndex(stages_, stage, &.{.closest_hit});
                if (hit.any_hit) |stage| try validateStageIndex(stages_, stage, &.{.any_hit});
                break :blk .{ .sType = raw.VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR, .type = raw.VK_RAY_TRACING_SHADER_GROUP_TYPE_PROCEDURAL_HIT_GROUP_KHR, .generalShader = unused, .closestHitShader = hit.closest_hit orelse unused, .anyHitShader = hit.any_hit orelse unused, .intersectionShader = hit.intersection };
            },
        };
        return graph.raw_groups[0..values.len];
    }
};

fn isRayStage(stage: shaders.Stage) bool {
    return switch (stage) {
        .ray_generation, .any_hit, .closest_hit, .miss, .intersection, .callable => true,
        else => false,
    };
}

fn validateStageIndex(stages: []const shaders.StageOptions, index: u32, allowed: []const shaders.Stage) core.Error!void {
    if (index >= stages.len) return error.InvalidOptions;
    for (allowed) |stage| if (stages[index].stage == stage) return;
    return error.InvalidOptions;
}

// Opacity micromaps use their own namespace so EXT/KHR evolution does not leak
// into the base acceleration-structure API.
pub const MicromapContext = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _create: ?CommandFunction(raw.PFN_vkCreateMicromapEXT),
    _destroy: ?CommandFunction(raw.PFN_vkDestroyMicromapEXT),
    _sizes: ?CommandFunction(raw.PFN_vkGetMicromapBuildSizesEXT),
    _build_host: ?CommandFunction(raw.PFN_vkBuildMicromapsEXT),
    _build_command: ?CommandFunction(raw.PFN_vkCmdBuildMicromapsEXT),
    _copy_host: ?CommandFunction(raw.PFN_vkCopyMicromapEXT),
    _copy_command: ?CommandFunction(raw.PFN_vkCmdCopyMicromapEXT),
    _serialize_host: ?CommandFunction(raw.PFN_vkCopyMicromapToMemoryEXT),
    _serialize_command: ?CommandFunction(raw.PFN_vkCmdCopyMicromapToMemoryEXT),
    _deserialize_host: ?CommandFunction(raw.PFN_vkCopyMemoryToMicromapEXT),
    _deserialize_command: ?CommandFunction(raw.PFN_vkCmdCopyMemoryToMicromapEXT),
    _compatibility: ?CommandFunction(raw.PFN_vkGetDeviceMicromapCompatibilityEXT),
    _write_properties_host: ?CommandFunction(raw.PFN_vkWriteMicromapsPropertiesEXT),
    _write_properties_command: ?CommandFunction(raw.PFN_vkCmdWriteMicromapsPropertiesEXT),

    pub const Usage = struct { count: u32, subdivision_level: u32, format: enum { two_state, four_state } };
    pub const Options = struct { storage: *const buffers.Buffer, offset: core.DeviceOffset = .zero, size: core.DeviceSize, capture_replay_address: ?buffers.DeviceAddress = null };
    pub const Sizes = struct { micromap: core.DeviceSize, build_scratch: core.DeviceSize, discardable: bool };
    pub const Property = enum {
        compacted_size,
        serialization_size,

        fn toRaw(value: @This()) raw.VkQueryType {
            return switch (value) {
                .compacted_size => raw.VK_QUERY_TYPE_MICROMAP_COMPACTED_SIZE_EXT,
                .serialization_size => raw.VK_QUERY_TYPE_MICROMAP_SERIALIZATION_SIZE_EXT,
            };
        }

        fn matchesQuery(value: @This(), kind: queries.Kind) bool {
            return switch (value) {
                .compacted_size => kind == .micromap_compacted_size,
                .serialization_size => kind == .micromap_serialization_size,
            };
        }
    };
    pub const BuildFlags = packed struct(u3) {
        prefer_fast_trace: bool = false,
        prefer_fast_build: bool = false,
        allow_compaction: bool = false,

        fn toRaw(flags: @This()) raw.VkBuildMicromapFlagsEXT {
            var result: raw.VkBuildMicromapFlagsEXT = 0;
            if (flags.prefer_fast_trace) result |= raw.VK_BUILD_MICROMAP_PREFER_FAST_TRACE_BIT_EXT;
            if (flags.prefer_fast_build) result |= raw.VK_BUILD_MICROMAP_PREFER_FAST_BUILD_BIT_EXT;
            if (flags.allow_compaction) result |= raw.VK_BUILD_MICROMAP_ALLOW_COMPACTION_BIT_EXT;
            return result;
        }
    };
    pub const Build = struct {
        destination: *const Micromap,
        usages: []const Usage,
        data: ConstAddress,
        scratch: Address,
        scratch_size: core.DeviceSize,
        triangle_array: ConstAddress,
        triangle_stride: core.DeviceSize,
        flags: MicromapContext.BuildFlags = .{},
    };

    pub const Micromap = struct {
        _handle: ?MicromapHandle,
        _owner: core.Owner,
        _device: DeviceHandle,
        _state: *const core.DeviceState,
        _storage: *const buffers.Buffer,
        _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
        _destroy: CommandFunction(raw.PFN_vkDestroyMicromapEXT),

        pub fn deinit(value: *Micromap) void {
            if (!(value._owner.release(value) catch return)) return;
            if (value._handle) |handle| value._destroy(value._device, handle, value._allocation_callbacks);
            value._handle = null;
        }
        pub fn rawHandle(value: *const Micromap) core.Error!raw.VkMicromapEXT {
            try value._owner.validate(value);
            try value._state.ensureDispatchAllowed();
            _ = try value._storage.rawHandle();
            return value._handle orelse error.InactiveObject;
        }
        pub fn debugObject(value: *const Micromap) core.Error!debug_utils.Object {
            return .forDevice(.micromap, try value.rawHandle(), value._device);
        }
    };

    pub fn create(context: MicromapContext, options: Options) core.Error!Micromap {
        const create_fn = context._create orelse return error.MissingCommand;
        const destroy = context._destroy orelse return error.MissingCommand;
        if (options.storage._device_handle != context._device or options.size.bytes() == 0 or options.offset.bytes() > options.storage.size.bytes() or options.size.bytes() > options.storage.size.bytes() - options.offset.bytes()) return error.InvalidOptions;
        const info: raw.VkMicromapCreateInfoEXT = .{
            .sType = raw.VK_STRUCTURE_TYPE_MICROMAP_CREATE_INFO_EXT,
            .createFlags = if (options.capture_replay_address != null) raw.VK_MICROMAP_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT_EXT else 0,
            .buffer = try options.storage.rawHandle(),
            .offset = options.offset.bytes(),
            .size = options.size.bytes(),
            .type = raw.VK_MICROMAP_TYPE_OPACITY_MICROMAP_EXT,
            .deviceAddress = if (options.capture_replay_address) |address| address.toRaw() else 0,
        };
        var handle: raw.VkMicromapEXT = null;
        const result = create_fn(context._device, &info, context._allocation_callbacks, &handle);
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional| destroy(context._device, provisional, context._allocation_callbacks);
            try core.checkSuccess(result);
        }
        return .{ ._handle = handle orelse return error.InvalidHandle, ._owner = try .init(&handle), ._device = context._device, ._state = context._state, ._storage = options.storage, ._allocation_callbacks = context._allocation_callbacks, ._destroy = destroy };
    }

    pub fn buildSizes(context: MicromapContext, target: BuildTarget, usages: []const Usage) core.Error!Sizes {
        const get = context._sizes orelse return error.MissingCommand;
        if (usages.len == 0 or usages.len > geometry_count_max) return error.InvalidOptions;
        var raw_usages: [geometry_count_max]raw.VkMicromapUsageEXT = undefined;
        for (usages, 0..) |usage, index| raw_usages[index] = usageRaw(usage);
        const info: raw.VkMicromapBuildInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_MICROMAP_BUILD_INFO_EXT, .type = raw.VK_MICROMAP_TYPE_OPACITY_MICROMAP_EXT, .mode = raw.VK_BUILD_MICROMAP_MODE_BUILD_EXT, .usageCountsCount = @intCast(usages.len), .pUsageCounts = raw_usages[0..usages.len].ptr };
        var sizes: raw.VkMicromapBuildSizesInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_MICROMAP_BUILD_SIZES_INFO_EXT };
        get(context._device, target.toRaw(), &info, &sizes);
        return .{ .micromap = .fromBytes(sizes.micromapSize), .build_scratch = .fromBytes(sizes.buildScratchSize), .discardable = sizes.discardable != raw.VK_FALSE };
    }

    pub fn buildHost(context: MicromapContext, build: MicromapContext.Build, deferred: ?*const pipeline_tools.DeferredOperation) core.Error!HostStatus {
        const function = context._build_host orelse return error.MissingCommand;
        if (build.data.isDevice() or build.scratch.isDevice() or build.triangle_array.isDevice()) return error.InvalidOptions;
        var raw_usages: [geometry_count_max]raw.VkMicromapUsageEXT = undefined;
        const info = try context.buildInfo(build, .host, &raw_usages);
        return hostStatus(function(context._device, if (deferred) |value| try value.rawHandle() else null, 1, &info));
    }

    pub fn buildCommand(context: MicromapContext, command_buffer: *commands.Buffer, build: MicromapContext.Build) core.Error!void {
        const function = context._build_command orelse return error.MissingCommand;
        try validateMicromapCommand(context, command_buffer);
        if (!build.data.isDevice() or !build.scratch.isDevice() or !build.triangle_array.isDevice()) return error.InvalidOptions;
        var raw_usages: [geometry_count_max]raw.VkMicromapUsageEXT = undefined;
        const info = try context.buildInfo(build, .device, &raw_usages);
        function(try command_buffer.rawHandle(), 1, &info);
    }

    pub fn copyHost(context: MicromapContext, source: *const Micromap, destination: *const Micromap, mode: CopyMode, deferred: ?*const pipeline_tools.DeferredOperation) core.Error!HostStatus {
        const function = context._copy_host orelse return error.MissingCommand;
        try validateMicromaps(context, source, destination);
        const info = micromapCopyInfo(try source.rawHandle(), try destination.rawHandle(), mode);
        return hostStatus(function(context._device, if (deferred) |value| try value.rawHandle() else null, &info));
    }

    pub fn copyCommand(context: MicromapContext, command_buffer: *commands.Buffer, source: *const Micromap, destination: *const Micromap, mode: CopyMode) core.Error!void {
        const function = context._copy_command orelse return error.MissingCommand;
        try validateMicromapCommand(context, command_buffer);
        try validateMicromaps(context, source, destination);
        const info = micromapCopyInfo(try source.rawHandle(), try destination.rawHandle(), mode);
        function(try command_buffer.rawHandle(), &info);
    }

    pub fn serializeHost(context: MicromapContext, source: *const Micromap, destination: Address, deferred: ?*const pipeline_tools.DeferredOperation) core.Error!HostStatus {
        const function = context._serialize_host orelse return error.MissingCommand;
        if (source._device != context._device or destination.isDevice()) return error.InvalidOptions;
        const info: raw.VkCopyMicromapToMemoryInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_COPY_MICROMAP_TO_MEMORY_INFO_EXT, .src = try source.rawHandle(), .dst = destination.toRaw(), .mode = raw.VK_COPY_MICROMAP_MODE_SERIALIZE_EXT };
        return hostStatus(function(context._device, if (deferred) |value| try value.rawHandle() else null, &info));
    }

    pub fn serializeCommand(context: MicromapContext, command_buffer: *commands.Buffer, source: *const Micromap, destination: Address) core.Error!void {
        const function = context._serialize_command orelse return error.MissingCommand;
        try validateMicromapCommand(context, command_buffer);
        if (source._device != context._device or !destination.isDevice()) return error.InvalidOptions;
        const info: raw.VkCopyMicromapToMemoryInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_COPY_MICROMAP_TO_MEMORY_INFO_EXT, .src = try source.rawHandle(), .dst = destination.toRaw(), .mode = raw.VK_COPY_MICROMAP_MODE_SERIALIZE_EXT };
        function(try command_buffer.rawHandle(), &info);
    }

    pub fn deserializeHost(context: MicromapContext, source: ConstAddress, destination: *const Micromap, deferred: ?*const pipeline_tools.DeferredOperation) core.Error!HostStatus {
        const function = context._deserialize_host orelse return error.MissingCommand;
        if (destination._device != context._device or source.isDevice()) return error.InvalidOptions;
        const info: raw.VkCopyMemoryToMicromapInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_COPY_MEMORY_TO_MICROMAP_INFO_EXT, .src = source.toRaw(), .dst = try destination.rawHandle(), .mode = raw.VK_COPY_MICROMAP_MODE_DESERIALIZE_EXT };
        return hostStatus(function(context._device, if (deferred) |value| try value.rawHandle() else null, &info));
    }

    pub fn deserializeCommand(context: MicromapContext, command_buffer: *commands.Buffer, source: ConstAddress, destination: *const Micromap) core.Error!void {
        const function = context._deserialize_command orelse return error.MissingCommand;
        try validateMicromapCommand(context, command_buffer);
        if (destination._device != context._device or !source.isDevice()) return error.InvalidOptions;
        const info: raw.VkCopyMemoryToMicromapInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_COPY_MEMORY_TO_MICROMAP_INFO_EXT, .src = source.toRaw(), .dst = try destination.rawHandle(), .mode = raw.VK_COPY_MICROMAP_MODE_DESERIALIZE_EXT };
        function(try command_buffer.rawHandle(), &info);
    }

    pub fn serializedCompatibility(context: MicromapContext, version_data: *const [2 * raw.VK_UUID_SIZE]u8) core.Error!Compatibility {
        const get = context._compatibility orelse return error.MissingCommand;
        const info: raw.VkMicromapVersionInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_MICROMAP_VERSION_INFO_EXT, .pVersionData = version_data };
        var result: raw.VkAccelerationStructureCompatibilityKHR = undefined;
        get(context._device, &info, &result);
        return switch (result) {
            raw.VK_ACCELERATION_STRUCTURE_COMPATIBILITY_COMPATIBLE_KHR => .compatible,
            raw.VK_ACCELERATION_STRUCTURE_COMPATIBILITY_INCOMPATIBLE_KHR => .incompatible,
            else => error.InvalidProperties,
        };
    }

    pub fn propertiesHost(context: MicromapContext, micromaps: []const *const Micromap, kind: MicromapContext.Property, destination: []u64) core.Error!void {
        const write = context._write_properties_host orelse return error.MissingCommand;
        if (micromaps.len == 0 or micromaps.len > geometry_count_max or destination.len < micromaps.len) return error.InvalidOptions;
        var handles: [geometry_count_max]raw.VkMicromapEXT = undefined;
        for (micromaps, 0..) |micromap, index| {
            if (micromap._device != context._device) return error.InvalidHandle;
            handles[index] = try micromap.rawHandle();
        }
        try core.checkSuccess(write(context._device, @intCast(micromaps.len), handles[0..micromaps.len].ptr, kind.toRaw(), micromaps.len * @sizeOf(u64), destination.ptr, @sizeOf(u64)));
    }

    pub fn writeProperties(context: MicromapContext, command_buffer: *commands.Buffer, micromaps: []const *const Micromap, pool: *const queries.Pool, first_query: u32, kind: MicromapContext.Property) core.Error!void {
        const write = context._write_properties_command orelse return error.MissingCommand;
        try validateMicromapCommand(context, command_buffer);
        if (micromaps.len == 0 or micromaps.len > geometry_count_max or first_query > pool.count or micromaps.len > pool.count - first_query or pool._device_handle != context._device or !kind.matchesQuery(pool.kind)) return error.InvalidOptions;
        var handles: [geometry_count_max]raw.VkMicromapEXT = undefined;
        for (micromaps, 0..) |micromap, index| {
            if (micromap._device != context._device) return error.InvalidHandle;
            handles[index] = try micromap.rawHandle();
        }
        write(try command_buffer.rawHandle(), @intCast(micromaps.len), handles[0..micromaps.len].ptr, kind.toRaw(), try pool.rawHandle(), first_query);
    }

    fn buildInfo(context: MicromapContext, build: MicromapContext.Build, target: BuildTarget, raw_usages: *[geometry_count_max]raw.VkMicromapUsageEXT) core.Error!raw.VkMicromapBuildInfoEXT {
        if (build.destination._device != context._device or build.usages.len == 0 or build.usages.len > geometry_count_max or build.triangle_stride.bytes() == 0) return error.InvalidOptions;
        for (build.usages, 0..) |usage, index| {
            if (usage.count == 0) return error.InvalidOptions;
            raw_usages[index] = usageRaw(usage);
        }
        const sizes = try context.buildSizes(target, build.usages);
        if (build.scratch_size.bytes() < sizes.build_scratch.bytes()) return error.BufferTooSmall;
        return .{
            .sType = raw.VK_STRUCTURE_TYPE_MICROMAP_BUILD_INFO_EXT,
            .type = raw.VK_MICROMAP_TYPE_OPACITY_MICROMAP_EXT,
            .flags = build.flags.toRaw(),
            .mode = raw.VK_BUILD_MICROMAP_MODE_BUILD_EXT,
            .dstMicromap = try build.destination.rawHandle(),
            .usageCountsCount = @intCast(build.usages.len),
            .pUsageCounts = raw_usages[0..build.usages.len].ptr,
            .data = build.data.toRaw(),
            .scratchData = build.scratch.toRaw(),
            .triangleArray = build.triangle_array.toRaw(),
            .triangleArrayStride = build.triangle_stride.bytes(),
        };
    }
};

fn validateMicromapCommand(context: MicromapContext, buffer: *commands.Buffer) core.Error!void {
    if (buffer._device_handle != context._device) return error.InvalidHandle;
    if (buffer.state != .recording or buffer.rendering_active or buffer.render_pass_active or buffer.video_coding_active) return error.InvalidOptions;
}

fn validateMicromaps(context: MicromapContext, source: *const MicromapContext.Micromap, destination: *const MicromapContext.Micromap) core.Error!void {
    if (source._device != context._device or destination._device != context._device) return error.InvalidHandle;
}

fn micromapCopyInfo(source: raw.VkMicromapEXT, destination: raw.VkMicromapEXT, mode: CopyMode) raw.VkCopyMicromapInfoEXT {
    return .{ .sType = raw.VK_STRUCTURE_TYPE_COPY_MICROMAP_INFO_EXT, .src = source, .dst = destination, .mode = switch (mode) {
        .clone => raw.VK_COPY_MICROMAP_MODE_CLONE_EXT,
        .compact => raw.VK_COPY_MICROMAP_MODE_COMPACT_EXT,
    } };
}

fn usageRaw(value: MicromapContext.Usage) raw.VkMicromapUsageEXT {
    return .{ .count = value.count, .subdivisionLevel = value.subdivision_level, .format = switch (value.format) {
        .two_state => raw.VK_OPACITY_MICROMAP_FORMAT_2_STATE_EXT,
        .four_state => raw.VK_OPACITY_MICROMAP_FORMAT_4_STATE_EXT,
    } };
}

/// The legacy NV extension is intentionally isolated. Its object memory model
/// differs from KHR; consumers must opt into raw interop rather than mixing it
/// with KHR `Structure` values.
pub const nv = struct {
    pub const extension = command.DeviceExtension.nv_ray_tracing;
};

test "geometry unions and shader groups stay typed" {
    const address: buffers.DeviceAddress = @enumFromInt(0x1000);
    const geometry: Geometry = .{ .instances = .{ .data = .{ .data = .{ .device = address } } } };
    try std.testing.expect(geometry == .instances);
    const group: ShaderGroup = .{ .procedural_hit = .{ .intersection = 0 } };
    try std.testing.expect(group == .procedural_hit);
}

test "host and device geometry addresses cannot be mixed" {
    var host_instances: [1]u64 = .{0};
    const host: Geometry = .{ .instances = .{ .data = .{ .data = .{ .host = &host_instances } } } };
    const device: Geometry = .{ .instances = .{ .data = .{ .data = .{ .device = @enumFromInt(0x1000) } } } };
    try std.testing.expect(geometryMatchesTarget(host, .host));
    try std.testing.expect(!geometryMatchesTarget(host, .device));
    try std.testing.expect(geometryMatchesTarget(device, .device));
    try std.testing.expect(!geometryMatchesTarget(device, .host));
    try std.testing.expect(geometryAllowed(.top_level, host));
    try std.testing.expect(!geometryAllowed(.bottom_level, host));
}

test "host build statuses and copy modes remain explicit" {
    try std.testing.expectEqual(HostStatus.complete, try hostStatus(raw.VK_SUCCESS));
    try std.testing.expectEqual(HostStatus.deferred, try hostStatus(raw.VK_OPERATION_DEFERRED_KHR));
    try std.testing.expectEqual(HostStatus.not_deferred, try hostStatus(raw.VK_OPERATION_NOT_DEFERRED_KHR));
    try std.testing.expectEqual(raw.VK_COPY_ACCELERATION_STRUCTURE_MODE_COMPACT_KHR, copyInfo(null, null, .compact).mode);
    try std.testing.expectEqual(raw.VK_COPY_MICROMAP_MODE_CLONE_EXT, micromapCopyInfo(null, null, .clone).mode);
}

test "unavailable extension commands fail locally" {
    var context: Context = undefined;
    context._build_sizes = null;
    const address: buffers.DeviceAddress = @enumFromInt(0x1000);
    const geometry = [_]Geometry{.{ .instances = .{ .data = .{ .data = .{ .device = address } } } }};
    const counts = [_]u32{1};
    try std.testing.expectError(error.MissingCommand, context.buildSizes(.device, .top_level, .empty, &geometry, &counts));

    var micromap_context: MicromapContext = undefined;
    micromap_context._sizes = null;
    const usage = [_]MicromapContext.Usage{.{ .count = 1, .subdivision_level = 0, .format = .two_state }};
    try std.testing.expectError(error.MissingCommand, micromap_context.buildSizes(.device, &usage));
}

var test_pipeline_destroy_count: usize = 0;
var test_host_build_count: usize = 0;
var test_device_build_count: usize = 0;
var test_host_copy_count: usize = 0;
var test_host_serialize_count: usize = 0;

fn testGetBuildSizes(
    _: raw.VkDevice,
    _: raw.VkAccelerationStructureBuildTypeKHR,
    _: [*c]const raw.VkAccelerationStructureBuildGeometryInfoKHR,
    _: [*c]const u32,
    output: [*c]raw.VkAccelerationStructureBuildSizesInfoKHR,
) callconv(.c) void {
    output.*.accelerationStructureSize = 1024;
    output.*.buildScratchSize = 256;
    output.*.updateScratchSize = 128;
}

fn testBuildHost(
    _: raw.VkDevice,
    _: raw.VkDeferredOperationKHR,
    _: u32,
    _: [*c]const raw.VkAccelerationStructureBuildGeometryInfoKHR,
    _: [*c]const [*c]const raw.VkAccelerationStructureBuildRangeInfoKHR,
) callconv(.c) raw.VkResult {
    test_host_build_count += 1;
    return raw.VK_SUCCESS;
}

fn testBuildCommand(
    _: raw.VkCommandBuffer,
    _: u32,
    _: [*c]const raw.VkAccelerationStructureBuildGeometryInfoKHR,
    _: [*c]const [*c]const raw.VkAccelerationStructureBuildRangeInfoKHR,
) callconv(.c) void {
    test_device_build_count += 1;
}

fn testCopyHost(_: raw.VkDevice, _: raw.VkDeferredOperationKHR, _: [*c]const raw.VkCopyAccelerationStructureInfoKHR) callconv(.c) raw.VkResult {
    test_host_copy_count += 1;
    return raw.VK_SUCCESS;
}

fn testSerializeHost(_: raw.VkDevice, _: raw.VkDeferredOperationKHR, _: [*c]const raw.VkCopyAccelerationStructureToMemoryInfoKHR) callconv(.c) raw.VkResult {
    test_host_serialize_count += 1;
    return raw.VK_SUCCESS;
}

fn testCreateRayTracingPipelines(
    _: raw.VkDevice,
    _: raw.VkDeferredOperationKHR,
    _: raw.VkPipelineCache,
    _: u32,
    _: [*c]const raw.VkRayTracingPipelineCreateInfoKHR,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkPipeline,
) callconv(.c) raw.VkResult {
    output[0] = @ptrFromInt(0x4444);
    return raw.VK_PIPELINE_COMPILE_REQUIRED;
}

fn testDestroyPipeline(_: raw.VkDevice, _: raw.VkPipeline, _: [*c]const raw.VkAllocationCallbacks) callconv(.c) void {
    test_pipeline_destroy_count += 1;
}

test "compile-required pipeline creation cleans provisional handles" {
    var state = try core.DeviceState.init();
    defer state.markDestroyed();
    const device: DeviceHandle = @ptrFromInt(0x1111);
    var module_handle: raw.VkShaderModule = @ptrFromInt(0x2222);
    var module: shaders.Module = .{
        ._handle = module_handle,
        ._owner = try .init(&module_handle),
        ._device_handle = device,
        ._device_state = state,
        .allocation_callbacks = null,
        .dispatch = undefined,
    };
    defer _ = module._owner.release(&module) catch false;
    var layout_handle: raw.VkPipelineLayout = @ptrFromInt(0x3333);
    var layout: pipelines.Layout = .{
        ._handle = layout_handle,
        ._owner = try .init(&layout_handle),
        ._device_handle = device,
        ._device_state = state,
        .allocation_callbacks = null,
        .destroy_layout = undefined,
    };
    defer _ = layout._owner.release(&layout) catch false;
    var context: Context = undefined;
    context._device = device;
    context._state = &state;
    context._allocation_callbacks = null;
    context.properties = testProperties();
    context._create_pipeline = testCreateRayTracingPipelines;
    context._destroy_pipeline = testDestroyPipeline;
    test_pipeline_destroy_count = 0;
    const stages = [_]shaders.StageOptions{.{ .stage = .ray_generation, .module = &module }};
    const groups = [_]ShaderGroup{.{ .general = 0 }};
    const result = try context.createPipeline(.{ .stages = &stages, .groups = &groups, .layout = &layout, .fail_on_compile_required = true });
    try std.testing.expect(result == .compile_required);
    try std.testing.expectEqual(@as(usize, 1), test_pipeline_destroy_count);
}

test "host update, device build, copy, and serialization use typed paths" {
    var state = try core.DeviceState.init();
    defer state.markDestroyed();
    const device: DeviceHandle = @ptrFromInt(0x5111);

    var storage_handle: raw.VkBuffer = @ptrFromInt(0x5222);
    var storage: buffers.Buffer = .{
        ._handle = storage_handle,
        ._owner = try .init(&storage_handle),
        ._device_handle = device,
        .size = .fromBytes(4096),
        .allocation_callbacks = null,
        .dispatch = undefined,
    };
    defer _ = storage._owner.release(&storage) catch false;

    var source_handle: raw.VkAccelerationStructureKHR = @ptrFromInt(0x5333);
    var source: Structure = .{
        ._handle = source_handle,
        ._owner = try .init(&source_handle),
        ._device = device,
        ._state = &state,
        ._storage = &storage,
        .type = .top_level,
        .allocation_callbacks = null,
        ._destroy = undefined,
    };
    defer _ = source._owner.release(&source) catch false;
    var destination_handle: raw.VkAccelerationStructureKHR = @ptrFromInt(0x5444);
    var destination: Structure = .{
        ._handle = destination_handle,
        ._owner = try .init(&destination_handle),
        ._device = device,
        ._state = &state,
        ._storage = &storage,
        .type = .top_level,
        .allocation_callbacks = null,
        ._destroy = undefined,
    };
    defer _ = destination._owner.release(&destination) catch false;

    var context: Context = undefined;
    context._device = device;
    context._state = &state;
    context.properties = testProperties();
    context._build_sizes = testGetBuildSizes;
    context._build_host = testBuildHost;
    context._build_command = testBuildCommand;
    context._copy_host = testCopyHost;
    context._serialize_host = testSerializeHost;

    var host_instances: [8]u8 = @splat(0);
    var host_scratch: [256]u8 = @splat(0);
    const host_geometries = [_]Geometry{.{ .instances = .{ .data = .{ .data = .{ .host = &host_instances } } } }};
    const ranges = [_]BuildRange{.{ .primitive_count = 1 }};
    test_host_build_count = 0;
    const host_result = try context.buildHost(.{
        .type = .top_level,
        .flags = .init(&.{.allow_update}),
        .mode = .update,
        .source = &source,
        .destination = &destination,
        .geometries = &host_geometries,
        .ranges = &ranges,
        .scratch = .{ .host = &host_scratch },
        .scratch_size = .fromBytes(host_scratch.len),
    }, null);
    try std.testing.expectEqual(HostStatus.complete, host_result);
    try std.testing.expectEqual(@as(usize, 1), test_host_build_count);

    var pool_handle: raw.VkCommandPool = @ptrFromInt(0x5555);
    var pool: commands.Pool = undefined;
    pool._handle = pool_handle;
    pool._owner = try .init(&pool_handle);
    pool._device_handle = device;
    pool._device_state = state;
    pool.generation = 0;
    defer _ = pool._owner.release(&pool) catch false;
    const command_handle: raw.VkCommandBuffer = @ptrFromInt(0x5666);
    var command_buffer: commands.Buffer = undefined;
    command_buffer._handle = command_handle;
    command_buffer._device_handle = device;
    command_buffer._pool = &pool;
    command_buffer._pool_owner = pool._owner.borrow();
    command_buffer._pool_generation = pool.generation;
    command_buffer.state = .recording;
    command_buffer.rendering_active = false;
    command_buffer.render_pass_active = false;
    command_buffer.video_coding_active = false;
    const device_geometries = [_]Geometry{.{ .instances = .{ .data = .{ .data = .{ .device = @enumFromInt(0x6000) } } } }};
    test_device_build_count = 0;
    try context.buildCommand(&command_buffer, .{
        .type = .top_level,
        .destination = &destination,
        .geometries = &device_geometries,
        .ranges = &ranges,
        .scratch = .{ .device = @enumFromInt(0x7000) },
        .scratch_size = .fromBytes(256),
    });
    try std.testing.expectEqual(@as(usize, 1), test_device_build_count);

    test_host_copy_count = 0;
    try std.testing.expectEqual(HostStatus.complete, try context.copyHost(&source, &destination, .clone, null));
    try std.testing.expectEqual(@as(usize, 1), test_host_copy_count);
    var serialized: [64]u8 = undefined;
    test_host_serialize_count = 0;
    try std.testing.expectEqual(HostStatus.complete, try context.serializeHost(&source, .{ .host = &serialized }, null));
    try std.testing.expectEqual(@as(usize, 1), test_host_serialize_count);
}

test "shader binding table validation checks alignment" {
    const properties = testProperties();
    const valid: ShaderBindingRegion = .{ .address = @enumFromInt(0x1000), .stride = .fromBytes(32), .size = .fromBytes(32) };
    _ = try valid.toRaw(properties, true);
    const invalid: ShaderBindingRegion = .{ .address = @enumFromInt(0x1010), .stride = .fromBytes(32), .size = .fromBytes(32) };
    try std.testing.expectError(error.InvalidOptions, invalid.toRaw(properties, true));
}

fn testProperties() Properties {
    return .{ .max_geometry_count = 1, .max_instance_count = 1, .max_primitive_count = 1, .scratch_alignment = 256, .shader_group_handle_size = 32, .shader_group_capture_replay_handle_size = 48, .shader_group_handle_alignment = 32, .shader_group_base_alignment = 64, .max_shader_group_stride = 4096, .max_recursion_depth = 1, .max_dispatch_invocations = 1024 };
}

test "all ray tracing declarations compile" {
    std.testing.refAllDecls(@This());
}
