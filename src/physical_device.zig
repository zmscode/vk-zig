const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const core = @import("core.zig");

pub const Limits = struct {
    max_image_dimension_2d: u32,
    max_image_dimension_3d: u32,
    max_image_dimension_cube: u32,
    max_memory_allocation_count: u32,
    max_sampler_allocation_count: u32,
    buffer_image_granularity: u64,
    sparse_address_space_size: u64,
    max_bound_descriptor_sets: u32,
    max_push_constants_size: u32,
    max_compute_shared_memory_size: u32,
    max_compute_work_group_count: [3]u32,
    max_compute_work_group_invocations: u32,
    max_compute_work_group_size: [3]u32,
    max_sampler_anisotropy: f32,
    max_viewports: u32,
    max_viewport_dimensions: [2]u32,
    viewport_bounds_range: [2]f32,
    min_uniform_buffer_offset_alignment: u64,
    min_storage_buffer_offset_alignment: u64,
    non_coherent_atom_size: u64,
    max_framebuffer_width: u32,
    max_framebuffer_height: u32,
    max_framebuffer_layers: u32,
    max_color_attachments: u32,
    timestamp_period_nanoseconds: f32,

    pub fn fromRaw(value: *const raw.VkPhysicalDeviceLimits) Limits {
        return .{
            .max_image_dimension_2d = value.maxImageDimension2D,
            .max_image_dimension_3d = value.maxImageDimension3D,
            .max_image_dimension_cube = value.maxImageDimensionCube,
            .max_memory_allocation_count = value.maxMemoryAllocationCount,
            .max_sampler_allocation_count = value.maxSamplerAllocationCount,
            .buffer_image_granularity = value.bufferImageGranularity,
            .sparse_address_space_size = value.sparseAddressSpaceSize,
            .max_bound_descriptor_sets = value.maxBoundDescriptorSets,
            .max_push_constants_size = value.maxPushConstantsSize,
            .max_compute_shared_memory_size = value.maxComputeSharedMemorySize,
            .max_compute_work_group_count = value.maxComputeWorkGroupCount,
            .max_compute_work_group_invocations = value.maxComputeWorkGroupInvocations,
            .max_compute_work_group_size = value.maxComputeWorkGroupSize,
            .max_sampler_anisotropy = value.maxSamplerAnisotropy,
            .max_viewports = value.maxViewports,
            .max_viewport_dimensions = value.maxViewportDimensions,
            .viewport_bounds_range = value.viewportBoundsRange,
            .min_uniform_buffer_offset_alignment = value.minUniformBufferOffsetAlignment,
            .min_storage_buffer_offset_alignment = value.minStorageBufferOffsetAlignment,
            .non_coherent_atom_size = value.nonCoherentAtomSize,
            .max_framebuffer_width = value.maxFramebufferWidth,
            .max_framebuffer_height = value.maxFramebufferHeight,
            .max_framebuffer_layers = value.maxFramebufferLayers,
            .max_color_attachments = value.maxColorAttachments,
            .timestamp_period_nanoseconds = value.timestampPeriod,
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

    pub fn name(properties: *const Properties) []const u8 {
        const end = for (properties.device_name, 0..) |byte, index| {
            if (byte == 0) break index;
        } else properties.device_name.len;
        return properties.device_name[0..end];
    }

    pub fn isDiscrete(properties: Properties) bool {
        return properties.device_type == .discrete_gpu;
    }

    pub fn supportsApiVersion(properties: Properties, minimum: core.Version) bool {
        return properties.api_version.atLeast(minimum);
    }
};

pub const QueueCapability = enum {
    graphics,
    compute,
    transfer,
    sparse_binding,
    protected,
};

pub const QueueFamily = struct {
    index: core.QueueFamilyIndex,
    flags: types.QueueFlags,
    queue_count: u32,
    timestamp_valid_bits: u32,
    minimum_image_transfer_granularity: types.Extent3D,

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

pub fn selectQueueFamily(
    families: []const QueueFamily,
    options: QueueSelectionOptions,
) core.Error!core.QueueFamilyIndex {
    var selected: ?core.QueueFamilyIndex = null;
    var selected_score: u32 = 0;
    for (families) |family| {
        if (family.queue_count == 0) continue;
        if (!family.flags.containsAll(options.required)) continue;
        const score: u32 = @intCast(@popCount(
            family.flags.toRaw() & options.preferred.toRaw(),
        ));
        if (selected == null or score > selected_score) {
            selected = family.index;
            selected_score = score;
        }
    }
    return selected orelse error.QueueFamilyNotFound;
}

pub fn selectQueueFamilyForSurface(
    device: anytype,
    families: []const QueueFamily,
    surface: anytype,
    options: QueueSelectionOptions,
) core.Error!core.QueueFamilyIndex {
    var selected: ?core.QueueFamilyIndex = null;
    var selected_score: u32 = 0;
    for (families) |family| {
        if (family.queue_count == 0) continue;
        if (!family.flags.containsAll(options.required)) continue;
        if (!try family.presentationSupport(device, surface)) continue;
        const score: u32 = @intCast(@popCount(
            family.flags.toRaw() & options.preferred.toRaw(),
        ));
        if (selected == null or score > selected_score) {
            selected = family.index;
            selected_score = score;
        }
    }
    return selected orelse error.QueueFamilyNotFound;
}
