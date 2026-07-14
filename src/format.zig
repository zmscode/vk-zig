const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const core = @import("core.zig");

pub const Properties = struct {
    linear_tiling_features: types.FormatFeatureFlags,
    optimal_tiling_features: types.FormatFeatureFlags,
    buffer_features: types.FormatFeatureFlags,

    pub fn fromRaw(value: raw.VkFormatProperties) Properties {
        return .{
            .linear_tiling_features = .fromRaw(value.linearTilingFeatures),
            .optimal_tiling_features = .fromRaw(value.optimalTilingFeatures),
            .buffer_features = .fromRaw(value.bufferFeatures),
        };
    }
};

pub const ImageOptions = struct {
    format: types.Format,
    image_type: types.ImageType,
    tiling: types.ImageTiling,
    usage: types.ImageUsageFlags,
    flags: types.ImageCreateFlags = .empty,
};

pub const DrmModifierQuery = struct {
    modifier: u64,
    queue_family_indices: []const core.QueueFamilyIndex = &.{},
};

pub const ImageQueryOptions = struct {
    format: types.Format,
    image_type: types.ImageType,
    tiling: types.ImageTiling,
    usage: types.ImageUsageFlags,
    flags: types.ImageCreateFlags = .empty,
    external_memory_handle_type: ?types.ExternalMemoryHandleTypeBit = null,
    drm_format_modifier: ?DrmModifierQuery = null,
};

pub const ImageProperties = struct {
    extent_max: types.Extent3D,
    mip_level_count_max: u32,
    array_layer_count_max: u32,
    sample_counts: types.SampleCountFlags,
    resource_size_max: u64,

    pub fn fromRaw(value: raw.VkImageFormatProperties) ImageProperties {
        return .{
            .extent_max = .fromRaw(value.maxExtent),
            .mip_level_count_max = value.maxMipLevels,
            .array_layer_count_max = value.maxArrayLayers,
            .sample_counts = .fromRaw(value.sampleCounts),
            .resource_size_max = value.maxResourceSize,
        };
    }
};

pub const ExternalMemoryProperties = struct {
    features: types.ExternalMemoryFeatureFlags,
    export_from_imported_handle_types: types.ExternalMemoryHandleTypeFlags,
    compatible_handle_types: types.ExternalMemoryHandleTypeFlags,

    pub fn fromRaw(value: raw.VkExternalMemoryProperties) ExternalMemoryProperties {
        return .{
            .features = .fromRaw(value.externalMemoryFeatures),
            .export_from_imported_handle_types = .fromRaw(value.exportFromImportedHandleTypes),
            .compatible_handle_types = .fromRaw(value.compatibleHandleTypes),
        };
    }
};

pub const ImageQueryResult = struct {
    properties: ImageProperties,
    external_memory: ?ExternalMemoryProperties,
};

pub const DrmModifierProperties = struct {
    modifier: u64,
    plane_count: u32,
    tiling_features: types.FormatFeatureFlags,

    pub fn fromRaw(value: raw.VkDrmFormatModifierPropertiesEXT) DrmModifierProperties {
        return .{
            .modifier = value.drmFormatModifier,
            .plane_count = value.drmFormatModifierPlaneCount,
            .tiling_features = .fromRaw(value.drmFormatModifierTilingFeatures),
        };
    }
};

pub const SparseImageOptions = struct {
    format: types.Format,
    image_type: types.ImageType,
    sample_count: types.SampleCountBit,
    usage: types.ImageUsageFlags,
    tiling: types.ImageTiling,

    pub fn toRaw(options: SparseImageOptions) raw.VkPhysicalDeviceSparseImageFormatInfo2 {
        return .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SPARSE_IMAGE_FORMAT_INFO_2,
            .format = options.format.toRaw(),
            .type = options.image_type.toRaw(),
            .samples = options.sample_count.toRaw(),
            .usage = options.usage.toRaw(),
            .tiling = options.tiling.toRaw(),
        };
    }
};

pub const SparseImageProperties = struct {
    aspect_mask: types.ImageAspectFlags,
    image_granularity: types.Extent3D,
    flags: types.SparseImageFormatFlags,

    pub fn fromRaw(value: raw.VkSparseImageFormatProperties) SparseImageProperties {
        return .{
            .aspect_mask = .fromRaw(value.aspectMask),
            .image_granularity = .fromRaw(value.imageGranularity),
            .flags = .fromRaw(value.flags),
        };
    }
};

pub const sparse_image_property_count_max = 256;
pub const drm_modifier_property_count_max = 256;
