const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const core = @import("core.zig");

pub const Limits = struct {
    max_image_dimension_1d: u32,
    max_image_dimension_2d: u32,
    max_image_dimension_3d: u32,
    max_image_dimension_cube: u32,
    max_image_array_layers: u32,
    max_texel_buffer_elements: u32,
    max_uniform_buffer_range: u32,
    max_storage_buffer_range: u32,
    max_memory_allocation_count: u32,
    max_sampler_allocation_count: u32,
    buffer_image_granularity: u64,
    sparse_address_space_size: u64,
    max_bound_descriptor_sets: u32,
    max_per_stage_descriptor_samplers: u32,
    max_per_stage_descriptor_uniform_buffers: u32,
    max_per_stage_descriptor_storage_buffers: u32,
    max_per_stage_descriptor_sampled_images: u32,
    max_per_stage_descriptor_storage_images: u32,
    max_per_stage_descriptor_input_attachments: u32,
    max_per_stage_resources: u32,
    max_descriptor_set_samplers: u32,
    max_descriptor_set_uniform_buffers: u32,
    max_descriptor_set_uniform_buffers_dynamic: u32,
    max_descriptor_set_storage_buffers: u32,
    max_descriptor_set_storage_buffers_dynamic: u32,
    max_descriptor_set_sampled_images: u32,
    max_descriptor_set_storage_images: u32,
    max_descriptor_set_input_attachments: u32,
    max_push_constants_size: u32,
    max_vertex_input_attributes: u32,
    max_vertex_input_bindings: u32,
    max_vertex_input_attribute_offset: u32,
    max_vertex_input_binding_stride: u32,
    max_vertex_output_components: u32,
    max_tessellation_generation_level: u32,
    max_tessellation_patch_size: u32,
    max_tessellation_control_per_vertex_input_components: u32,
    max_tessellation_control_per_vertex_output_components: u32,
    max_tessellation_control_per_patch_output_components: u32,
    max_tessellation_control_total_output_components: u32,
    max_tessellation_evaluation_input_components: u32,
    max_tessellation_evaluation_output_components: u32,
    max_geometry_shader_invocations: u32,
    max_geometry_input_components: u32,
    max_geometry_output_components: u32,
    max_geometry_output_vertices: u32,
    max_geometry_total_output_components: u32,
    max_fragment_input_components: u32,
    max_fragment_output_attachments: u32,
    max_fragment_dual_source_attachments: u32,
    max_fragment_combined_output_resources: u32,
    max_compute_shared_memory_size: u32,
    max_compute_work_group_count: [3]u32,
    max_compute_work_group_invocations: u32,
    max_compute_work_group_size: [3]u32,
    sub_pixel_precision_bits: u32,
    sub_texel_precision_bits: u32,
    mipmap_precision_bits: u32,
    max_draw_indexed_index_value: u32,
    max_draw_indirect_count: u32,
    max_sampler_lod_bias: f32,
    max_sampler_anisotropy: f32,
    max_viewports: u32,
    max_viewport_dimensions: [2]u32,
    viewport_bounds_range: [2]f32,
    viewport_sub_pixel_bits: u32,
    min_memory_map_alignment: usize,
    min_texel_buffer_offset_alignment: u64,
    min_uniform_buffer_offset_alignment: u64,
    min_storage_buffer_offset_alignment: u64,
    min_texel_offset: i32,
    max_texel_offset: u32,
    min_texel_gather_offset: i32,
    max_texel_gather_offset: u32,
    min_interpolation_offset: f32,
    max_interpolation_offset: f32,
    sub_pixel_interpolation_offset_bits: u32,
    non_coherent_atom_size: u64,
    max_framebuffer_width: u32,
    max_framebuffer_height: u32,
    max_framebuffer_layers: u32,
    framebuffer_color_sample_counts: types.SampleCountFlags,
    framebuffer_depth_sample_counts: types.SampleCountFlags,
    framebuffer_stencil_sample_counts: types.SampleCountFlags,
    framebuffer_no_attachments_sample_counts: types.SampleCountFlags,
    max_color_attachments: u32,
    sampled_image_color_sample_counts: types.SampleCountFlags,
    sampled_image_integer_sample_counts: types.SampleCountFlags,
    sampled_image_depth_sample_counts: types.SampleCountFlags,
    sampled_image_stencil_sample_counts: types.SampleCountFlags,
    storage_image_sample_counts: types.SampleCountFlags,
    max_sample_mask_words: u32,
    timestamp_compute_and_graphics: bool,
    timestamp_period_nanoseconds: f32,
    max_clip_distances: u32,
    max_cull_distances: u32,
    max_combined_clip_and_cull_distances: u32,
    discrete_queue_priorities: u32,
    point_size_range: [2]f32,
    line_width_range: [2]f32,
    point_size_granularity: f32,
    line_width_granularity: f32,
    strict_lines: bool,
    standard_sample_locations: bool,
    optimal_buffer_copy_offset_alignment: u64,
    optimal_buffer_copy_row_pitch_alignment: u64,

    pub fn fromRaw(value: *const raw.VkPhysicalDeviceLimits) Limits {
        return .{
            .max_image_dimension_1d = value.maxImageDimension1D,
            .max_image_dimension_2d = value.maxImageDimension2D,
            .max_image_dimension_3d = value.maxImageDimension3D,
            .max_image_dimension_cube = value.maxImageDimensionCube,
            .max_image_array_layers = value.maxImageArrayLayers,
            .max_texel_buffer_elements = value.maxTexelBufferElements,
            .max_uniform_buffer_range = value.maxUniformBufferRange,
            .max_storage_buffer_range = value.maxStorageBufferRange,
            .max_memory_allocation_count = value.maxMemoryAllocationCount,
            .max_sampler_allocation_count = value.maxSamplerAllocationCount,
            .buffer_image_granularity = value.bufferImageGranularity,
            .sparse_address_space_size = value.sparseAddressSpaceSize,
            .max_bound_descriptor_sets = value.maxBoundDescriptorSets,
            .max_per_stage_descriptor_samplers = value.maxPerStageDescriptorSamplers,
            .max_per_stage_descriptor_uniform_buffers = value.maxPerStageDescriptorUniformBuffers,
            .max_per_stage_descriptor_storage_buffers = value.maxPerStageDescriptorStorageBuffers,
            .max_per_stage_descriptor_sampled_images = value.maxPerStageDescriptorSampledImages,
            .max_per_stage_descriptor_storage_images = value.maxPerStageDescriptorStorageImages,
            .max_per_stage_descriptor_input_attachments = value.maxPerStageDescriptorInputAttachments,
            .max_per_stage_resources = value.maxPerStageResources,
            .max_descriptor_set_samplers = value.maxDescriptorSetSamplers,
            .max_descriptor_set_uniform_buffers = value.maxDescriptorSetUniformBuffers,
            .max_descriptor_set_uniform_buffers_dynamic = value.maxDescriptorSetUniformBuffersDynamic,
            .max_descriptor_set_storage_buffers = value.maxDescriptorSetStorageBuffers,
            .max_descriptor_set_storage_buffers_dynamic = value.maxDescriptorSetStorageBuffersDynamic,
            .max_descriptor_set_sampled_images = value.maxDescriptorSetSampledImages,
            .max_descriptor_set_storage_images = value.maxDescriptorSetStorageImages,
            .max_descriptor_set_input_attachments = value.maxDescriptorSetInputAttachments,
            .max_push_constants_size = value.maxPushConstantsSize,
            .max_vertex_input_attributes = value.maxVertexInputAttributes,
            .max_vertex_input_bindings = value.maxVertexInputBindings,
            .max_vertex_input_attribute_offset = value.maxVertexInputAttributeOffset,
            .max_vertex_input_binding_stride = value.maxVertexInputBindingStride,
            .max_vertex_output_components = value.maxVertexOutputComponents,
            .max_tessellation_generation_level = value.maxTessellationGenerationLevel,
            .max_tessellation_patch_size = value.maxTessellationPatchSize,
            .max_tessellation_control_per_vertex_input_components = value.maxTessellationControlPerVertexInputComponents,
            .max_tessellation_control_per_vertex_output_components = value.maxTessellationControlPerVertexOutputComponents,
            .max_tessellation_control_per_patch_output_components = value.maxTessellationControlPerPatchOutputComponents,
            .max_tessellation_control_total_output_components = value.maxTessellationControlTotalOutputComponents,
            .max_tessellation_evaluation_input_components = value.maxTessellationEvaluationInputComponents,
            .max_tessellation_evaluation_output_components = value.maxTessellationEvaluationOutputComponents,
            .max_geometry_shader_invocations = value.maxGeometryShaderInvocations,
            .max_geometry_input_components = value.maxGeometryInputComponents,
            .max_geometry_output_components = value.maxGeometryOutputComponents,
            .max_geometry_output_vertices = value.maxGeometryOutputVertices,
            .max_geometry_total_output_components = value.maxGeometryTotalOutputComponents,
            .max_fragment_input_components = value.maxFragmentInputComponents,
            .max_fragment_output_attachments = value.maxFragmentOutputAttachments,
            .max_fragment_dual_source_attachments = value.maxFragmentDualSrcAttachments,
            .max_fragment_combined_output_resources = value.maxFragmentCombinedOutputResources,
            .max_compute_shared_memory_size = value.maxComputeSharedMemorySize,
            .max_compute_work_group_count = value.maxComputeWorkGroupCount,
            .max_compute_work_group_invocations = value.maxComputeWorkGroupInvocations,
            .max_compute_work_group_size = value.maxComputeWorkGroupSize,
            .sub_pixel_precision_bits = value.subPixelPrecisionBits,
            .sub_texel_precision_bits = value.subTexelPrecisionBits,
            .mipmap_precision_bits = value.mipmapPrecisionBits,
            .max_draw_indexed_index_value = value.maxDrawIndexedIndexValue,
            .max_draw_indirect_count = value.maxDrawIndirectCount,
            .max_sampler_lod_bias = value.maxSamplerLodBias,
            .max_sampler_anisotropy = value.maxSamplerAnisotropy,
            .max_viewports = value.maxViewports,
            .max_viewport_dimensions = value.maxViewportDimensions,
            .viewport_bounds_range = value.viewportBoundsRange,
            .viewport_sub_pixel_bits = value.viewportSubPixelBits,
            .min_memory_map_alignment = value.minMemoryMapAlignment,
            .min_texel_buffer_offset_alignment = value.minTexelBufferOffsetAlignment,
            .min_uniform_buffer_offset_alignment = value.minUniformBufferOffsetAlignment,
            .min_storage_buffer_offset_alignment = value.minStorageBufferOffsetAlignment,
            .min_texel_offset = value.minTexelOffset,
            .max_texel_offset = value.maxTexelOffset,
            .min_texel_gather_offset = value.minTexelGatherOffset,
            .max_texel_gather_offset = value.maxTexelGatherOffset,
            .min_interpolation_offset = value.minInterpolationOffset,
            .max_interpolation_offset = value.maxInterpolationOffset,
            .sub_pixel_interpolation_offset_bits = value.subPixelInterpolationOffsetBits,
            .non_coherent_atom_size = value.nonCoherentAtomSize,
            .max_framebuffer_width = value.maxFramebufferWidth,
            .max_framebuffer_height = value.maxFramebufferHeight,
            .max_framebuffer_layers = value.maxFramebufferLayers,
            .framebuffer_color_sample_counts = .fromRaw(value.framebufferColorSampleCounts),
            .framebuffer_depth_sample_counts = .fromRaw(value.framebufferDepthSampleCounts),
            .framebuffer_stencil_sample_counts = .fromRaw(value.framebufferStencilSampleCounts),
            .framebuffer_no_attachments_sample_counts = .fromRaw(value.framebufferNoAttachmentsSampleCounts),
            .max_color_attachments = value.maxColorAttachments,
            .sampled_image_color_sample_counts = .fromRaw(value.sampledImageColorSampleCounts),
            .sampled_image_integer_sample_counts = .fromRaw(value.sampledImageIntegerSampleCounts),
            .sampled_image_depth_sample_counts = .fromRaw(value.sampledImageDepthSampleCounts),
            .sampled_image_stencil_sample_counts = .fromRaw(value.sampledImageStencilSampleCounts),
            .storage_image_sample_counts = .fromRaw(value.storageImageSampleCounts),
            .max_sample_mask_words = value.maxSampleMaskWords,
            .timestamp_compute_and_graphics = value.timestampComputeAndGraphics != raw.VK_FALSE,
            .timestamp_period_nanoseconds = value.timestampPeriod,
            .max_clip_distances = value.maxClipDistances,
            .max_cull_distances = value.maxCullDistances,
            .max_combined_clip_and_cull_distances = value.maxCombinedClipAndCullDistances,
            .discrete_queue_priorities = value.discreteQueuePriorities,
            .point_size_range = value.pointSizeRange,
            .line_width_range = value.lineWidthRange,
            .point_size_granularity = value.pointSizeGranularity,
            .line_width_granularity = value.lineWidthGranularity,
            .strict_lines = value.strictLines != raw.VK_FALSE,
            .standard_sample_locations = value.standardSampleLocations != raw.VK_FALSE,
            .optimal_buffer_copy_offset_alignment = value.optimalBufferCopyOffsetAlignment,
            .optimal_buffer_copy_row_pitch_alignment = value.optimalBufferCopyRowPitchAlignment,
        };
    }
};

pub const SparseProperties = struct {
    standard_2d_block_shape: bool,
    standard_2d_multisample_block_shape: bool,
    standard_3d_block_shape: bool,
    aligned_mip_size: bool,
    non_resident_strict: bool,

    pub fn fromRaw(value: *const raw.VkPhysicalDeviceSparseProperties) SparseProperties {
        return .{
            .standard_2d_block_shape = value.residencyStandard2DBlockShape != raw.VK_FALSE,
            .standard_2d_multisample_block_shape = value.residencyStandard2DMultisampleBlockShape != raw.VK_FALSE,
            .standard_3d_block_shape = value.residencyStandard3DBlockShape != raw.VK_FALSE,
            .aligned_mip_size = value.residencyAlignedMipSize != raw.VK_FALSE,
            .non_resident_strict = value.residencyNonResidentStrict != raw.VK_FALSE,
        };
    }
};

pub const DriverId = enum(raw.VkDriverId) {
    amd_proprietary = @intCast(raw.VK_DRIVER_ID_AMD_PROPRIETARY),
    amd_open_source = @intCast(raw.VK_DRIVER_ID_AMD_OPEN_SOURCE),
    mesa_radv = @intCast(raw.VK_DRIVER_ID_MESA_RADV),
    nvidia_proprietary = @intCast(raw.VK_DRIVER_ID_NVIDIA_PROPRIETARY),
    intel_proprietary_windows = @intCast(raw.VK_DRIVER_ID_INTEL_PROPRIETARY_WINDOWS),
    intel_open_source_mesa = @intCast(raw.VK_DRIVER_ID_INTEL_OPEN_SOURCE_MESA),
    imagination_proprietary = @intCast(raw.VK_DRIVER_ID_IMAGINATION_PROPRIETARY),
    qualcomm_proprietary = @intCast(raw.VK_DRIVER_ID_QUALCOMM_PROPRIETARY),
    arm_proprietary = @intCast(raw.VK_DRIVER_ID_ARM_PROPRIETARY),
    google_swiftshader = @intCast(raw.VK_DRIVER_ID_GOOGLE_SWIFTSHADER),
    ggp_proprietary = @intCast(raw.VK_DRIVER_ID_GGP_PROPRIETARY),
    broadcom_proprietary = @intCast(raw.VK_DRIVER_ID_BROADCOM_PROPRIETARY),
    mesa_llvmpipe = @intCast(raw.VK_DRIVER_ID_MESA_LLVMPIPE),
    moltenvk = @intCast(raw.VK_DRIVER_ID_MOLTENVK),
    coreavi_proprietary = @intCast(raw.VK_DRIVER_ID_COREAVI_PROPRIETARY),
    juice_proprietary = @intCast(raw.VK_DRIVER_ID_JUICE_PROPRIETARY),
    verisilicon_proprietary = @intCast(raw.VK_DRIVER_ID_VERISILICON_PROPRIETARY),
    mesa_turnip = @intCast(raw.VK_DRIVER_ID_MESA_TURNIP),
    mesa_v3dv = @intCast(raw.VK_DRIVER_ID_MESA_V3DV),
    mesa_panvk = @intCast(raw.VK_DRIVER_ID_MESA_PANVK),
    samsung_proprietary = @intCast(raw.VK_DRIVER_ID_SAMSUNG_PROPRIETARY),
    mesa_venus = @intCast(raw.VK_DRIVER_ID_MESA_VENUS),
    mesa_dozen = @intCast(raw.VK_DRIVER_ID_MESA_DOZEN),
    mesa_nvk = @intCast(raw.VK_DRIVER_ID_MESA_NVK),
    imagination_open_source_mesa = @intCast(raw.VK_DRIVER_ID_IMAGINATION_OPEN_SOURCE_MESA),
    mesa_honeykrisp = @intCast(raw.VK_DRIVER_ID_MESA_HONEYKRISP),
    vulkan_sc_emulation = @intCast(raw.VK_DRIVER_ID_VULKAN_SC_EMULATION_ON_VULKAN),
    mesa_kosmickrisp = @intCast(raw.VK_DRIVER_ID_MESA_KOSMICKRISP),
    mesa_gfxstream = @intCast(raw.VK_DRIVER_ID_MESA_GFXSTREAM),
    ape_soft = @intCast(raw.VK_DRIVER_ID_APE_SOFT),
    _,

    pub fn fromRaw(value: raw.VkDriverId) DriverId {
        return @enumFromInt(value);
    }

    pub fn toRaw(value: DriverId) raw.VkDriverId {
        return @intFromEnum(value);
    }
};

pub const ConformanceVersion = struct {
    major: u8,
    minor: u8,
    subminor: u8,
    patch: u8,

    pub fn fromRaw(value: raw.VkConformanceVersion) ConformanceVersion {
        return .{ .major = value.major, .minor = value.minor, .subminor = value.subminor, .patch = value.patch };
    }
};

pub const Identification = struct {
    device_uuid: [raw.VK_UUID_SIZE]u8,
    driver_uuid: [raw.VK_UUID_SIZE]u8,
    device_luid: ?[raw.VK_LUID_SIZE]u8,
    device_node_mask: u32,

    pub fn fromRaw(value: *const raw.VkPhysicalDeviceIDProperties) Identification {
        return .{
            .device_uuid = value.deviceUUID,
            .driver_uuid = value.driverUUID,
            .device_luid = if (value.deviceLUIDValid != raw.VK_FALSE) value.deviceLUID else null,
            .device_node_mask = value.deviceNodeMask,
        };
    }
};

pub const DriverProperties = struct {
    id: DriverId,
    _name: [raw.VK_MAX_DRIVER_NAME_SIZE]u8,
    _info: [raw.VK_MAX_DRIVER_INFO_SIZE]u8,
    conformance: ConformanceVersion,

    pub fn fromRaw(value: *const raw.VkPhysicalDeviceDriverProperties) DriverProperties {
        return .{
            .id = .fromRaw(value.driverID),
            ._name = value.driverName,
            ._info = value.driverInfo,
            .conformance = .fromRaw(value.conformanceVersion),
        };
    }

    pub fn name(properties: *const DriverProperties) []const u8 {
        return boundedString(&properties._name);
    }

    pub fn info(properties: *const DriverProperties) []const u8 {
        return boundedString(&properties._info);
    }
};

pub const Properties = struct {
    api_version: core.Version,
    driver_version_raw: u32,
    vendor_id: u32,
    device_id: u32,
    device_type: types.PhysicalDeviceType,
    device_name: [raw.VK_MAX_PHYSICAL_DEVICE_NAME_SIZE]u8,
    pipeline_cache_uuid: [raw.VK_UUID_SIZE]u8,
    limits: Limits,
    sparse: SparseProperties,
    identification: ?Identification = null,
    driver: ?DriverProperties = null,

    pub fn fromRaw(value: *const raw.VkPhysicalDeviceProperties) Properties {
        return .{
            .api_version = .decode(value.apiVersion),
            .driver_version_raw = value.driverVersion,
            .vendor_id = value.vendorID,
            .device_id = value.deviceID,
            .device_type = .fromRaw(value.deviceType),
            .device_name = value.deviceName,
            .pipeline_cache_uuid = value.pipelineCacheUUID,
            .limits = .fromRaw(&value.limits),
            .sparse = .fromRaw(&value.sparseProperties),
        };
    }

    pub fn fromRaw2(
        value: *const raw.VkPhysicalDeviceProperties,
        identification: ?*const raw.VkPhysicalDeviceIDProperties,
        driver: ?*const raw.VkPhysicalDeviceDriverProperties,
    ) Properties {
        var properties = Properties.fromRaw(value);
        if (identification) |identity| properties.identification = .fromRaw(identity);
        if (driver) |driver_properties| properties.driver = .fromRaw(driver_properties);
        return properties;
    }

    pub fn name(properties: *const Properties) []const u8 {
        return boundedString(&properties.device_name);
    }

    pub fn isDiscrete(properties: Properties) bool {
        return properties.device_type == .discrete_gpu;
    }

    pub fn supportsApiVersion(properties: Properties, minimum: core.Version) bool {
        return properties.api_version.atLeast(minimum);
    }
};

fn boundedString(bytes: []const u8) []const u8 {
    const end = for (bytes, 0..) |byte, index| {
        if (byte == 0) break index;
    } else bytes.len;
    return bytes[0..end];
}

pub const QueueCapability = enum {
    graphics,
    compute,
    transfer,
    sparse_binding,
    protected,
    video_decode,
    video_encode,
    optical_flow,
};

pub const VideoCodecOperationBit = enum(raw.VkVideoCodecOperationFlagsKHR) {
    decode_h264 = @intCast(raw.VK_VIDEO_CODEC_OPERATION_DECODE_H264_BIT_KHR),
    decode_h265 = @intCast(raw.VK_VIDEO_CODEC_OPERATION_DECODE_H265_BIT_KHR),
    decode_av1 = @intCast(raw.VK_VIDEO_CODEC_OPERATION_DECODE_AV1_BIT_KHR),
    decode_vp9 = @intCast(raw.VK_VIDEO_CODEC_OPERATION_DECODE_VP9_BIT_KHR),
    encode_h264 = @intCast(raw.VK_VIDEO_CODEC_OPERATION_ENCODE_H264_BIT_KHR),
    encode_h265 = @intCast(raw.VK_VIDEO_CODEC_OPERATION_ENCODE_H265_BIT_KHR),
    encode_av1 = @intCast(raw.VK_VIDEO_CODEC_OPERATION_ENCODE_AV1_BIT_KHR),
    _,
};

pub const VideoCodecOperations = types.Flags(raw.VkVideoCodecOperationFlagsKHR, VideoCodecOperationBit);

pub const QueueGlobalPriority = enum(raw.VkQueueGlobalPriority) {
    low = @intCast(raw.VK_QUEUE_GLOBAL_PRIORITY_LOW),
    medium = @intCast(raw.VK_QUEUE_GLOBAL_PRIORITY_MEDIUM),
    high = @intCast(raw.VK_QUEUE_GLOBAL_PRIORITY_HIGH),
    realtime = @intCast(raw.VK_QUEUE_GLOBAL_PRIORITY_REALTIME),
    _,

    pub fn fromRaw(value: raw.VkQueueGlobalPriority) QueueGlobalPriority {
        return @enumFromInt(value);
    }

    pub fn toRaw(value: QueueGlobalPriority) raw.VkQueueGlobalPriority {
        return @intFromEnum(value);
    }
};

pub const GlobalPriorityProperties = struct {
    _values: [raw.VK_MAX_GLOBAL_PRIORITY_SIZE]QueueGlobalPriority = undefined,
    count: usize = 0,

    pub fn values(properties: *const GlobalPriorityProperties) []const QueueGlobalPriority {
        return properties._values[0..properties.count];
    }
};

pub const QueueFamily = struct {
    index: core.QueueFamilyIndex,
    flags: types.QueueFlags,
    queue_count: u32,
    timestamp_valid_bits: u32,
    minimum_image_transfer_granularity: types.Extent3D,
    video_codec_operations: VideoCodecOperations = .empty,
    query_result_status_support: bool = false,
    global_priorities: GlobalPriorityProperties = .{},

    pub fn queueCount(family: QueueFamily) u32 {
        return family.queue_count;
    }

    pub fn supports(family: QueueFamily, capability: QueueCapability) bool {
        if (family.queue_count == 0) return false;
        const bit: types.QueueBit = switch (capability) {
            .graphics => .graphics,
            .compute => .compute,
            .transfer => .transfer,
            .sparse_binding => .sparse_binding,
            .protected => .protected,
            .video_decode => .video_decode_khr,
            .video_encode => .video_encode_khr,
            .optical_flow => .optical_flow_nv,
        };
        return family.flags.contains(bit);
    }

    pub fn presentationSupport(
        family: QueueFamily,
        device: anytype,
        surface: anytype,
    ) core.Error!bool {
        return device.surfaceSupport(surface, family.index);
    }
};

pub const QueueSelectionOptions = struct {
    required: types.QueueFlags,
    preferred: types.QueueFlags = .empty,
};

pub const QueueSelectionFailure = struct {
    family_count: usize,
    empty_family_count: usize,
    missing_required_count: usize,
    missing_presentation_count: usize = 0,
};

pub const QueueSelection = union(enum) {
    selected: core.QueueFamilyIndex,
    unavailable: QueueSelectionFailure,
};

pub fn selectQueueFamilyDetailed(
    families: []const QueueFamily,
    options: QueueSelectionOptions,
) QueueSelection {
    var failure: QueueSelectionFailure = .{
        .family_count = families.len,
        .empty_family_count = 0,
        .missing_required_count = 0,
    };
    var selected: ?core.QueueFamilyIndex = null;
    var selected_score: u32 = 0;
    for (families) |family| {
        if (family.queue_count == 0) {
            failure.empty_family_count += 1;
            continue;
        }
        if (!family.flags.containsAll(options.required)) {
            failure.missing_required_count += 1;
            continue;
        }
        const score: u32 = @intCast(@popCount(family.flags.toRaw() & options.preferred.toRaw()));
        if (selected == null or score > selected_score) {
            selected = family.index;
            selected_score = score;
        }
    }
    return if (selected) |index| .{ .selected = index } else .{ .unavailable = failure };
}

pub fn selectQueueFamily(
    families: []const QueueFamily,
    options: QueueSelectionOptions,
) core.Error!core.QueueFamilyIndex {
    return switch (selectQueueFamilyDetailed(families, options)) {
        .selected => |index| index,
        .unavailable => error.QueueFamilyNotFound,
    };
}

pub fn selectQueueFamilyForSurfaceDetailed(
    device: anytype,
    families: []const QueueFamily,
    surface: anytype,
    options: QueueSelectionOptions,
) core.Error!QueueSelection {
    var failure: QueueSelectionFailure = .{
        .family_count = families.len,
        .empty_family_count = 0,
        .missing_required_count = 0,
    };
    var selected: ?core.QueueFamilyIndex = null;
    var selected_score: u32 = 0;
    for (families) |family| {
        if (family.queue_count == 0) {
            failure.empty_family_count += 1;
            continue;
        }
        if (!family.flags.containsAll(options.required)) {
            failure.missing_required_count += 1;
            continue;
        }
        if (!try family.presentationSupport(device, surface)) {
            failure.missing_presentation_count += 1;
            continue;
        }
        const score: u32 = @intCast(@popCount(family.flags.toRaw() & options.preferred.toRaw()));
        if (selected == null or score > selected_score) {
            selected = family.index;
            selected_score = score;
        }
    }
    return if (selected) |index| .{ .selected = index } else .{ .unavailable = failure };
}

pub fn selectQueueFamilyForSurface(
    device: anytype,
    families: []const QueueFamily,
    surface: anytype,
    options: QueueSelectionOptions,
) core.Error!core.QueueFamilyIndex {
    return switch (try selectQueueFamilyForSurfaceDetailed(device, families, surface, options)) {
        .selected => |index| index,
        .unavailable => error.QueueFamilyNotFound,
    };
}

test "physical device properties bound malformed names and convert booleans" {
    const std = @import("std");
    var raw_properties: raw.VkPhysicalDeviceProperties = .{};
    raw_properties.apiVersion = raw.VK_API_VERSION_1_3;
    raw_properties.deviceType = 0x7fff;
    @memset(&raw_properties.deviceName, 'x');
    raw_properties.limits.timestampComputeAndGraphics = raw.VK_TRUE;
    raw_properties.sparseProperties.residencyNonResidentStrict = raw.VK_TRUE;
    const properties = Properties.fromRaw(&raw_properties);
    try std.testing.expectEqual(raw_properties.deviceName.len, properties.name().len);
    try std.testing.expectEqual(@as(raw.VkPhysicalDeviceType, 0x7fff), properties.device_type.toRaw());
    try std.testing.expect(properties.limits.timestamp_compute_and_graphics);
    try std.testing.expect(properties.sparse.non_resident_strict);
    try std.testing.expect(properties.supportsApiVersion(.v1_2));
}

test "queue selection prefers unified capabilities and diagnoses failures" {
    const std = @import("std");
    const families = [_]QueueFamily{
        .{ .index = .fromRaw(0), .flags = .init(&.{.transfer}), .queue_count = 1, .timestamp_valid_bits = 0, .minimum_image_transfer_granularity = .{ .width = 1, .height = 1, .depth = 1 } },
        .{ .index = .fromRaw(1), .flags = .init(&.{ .graphics, .compute, .transfer }), .queue_count = 2, .timestamp_valid_bits = 64, .minimum_image_transfer_granularity = .{ .width = 1, .height = 1, .depth = 1 } },
        .{ .index = .fromRaw(2), .flags = .init(&.{ .graphics, .compute }), .queue_count = 0, .timestamp_valid_bits = 0, .minimum_image_transfer_granularity = .{ .width = 1, .height = 1, .depth = 1 } },
    };
    const selected = selectQueueFamilyDetailed(&families, .{
        .required = .init(&.{.graphics}),
        .preferred = .init(&.{ .compute, .transfer }),
    });
    try std.testing.expectEqual(@as(u32, 1), selected.selected.toRaw());

    const missing = selectQueueFamilyDetailed(&families, .{ .required = .init(&.{.protected}) });
    try std.testing.expectEqual(@as(usize, 3), missing.unavailable.family_count);
    try std.testing.expectEqual(@as(usize, 1), missing.unavailable.empty_family_count);
    try std.testing.expectEqual(@as(usize, 2), missing.unavailable.missing_required_count);

    const none = selectQueueFamilyDetailed(&.{}, .{ .required = .init(&.{.graphics}) });
    try std.testing.expectEqual(@as(usize, 0), none.unavailable.family_count);
}
