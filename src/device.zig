const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const physical_device = @import("physical_device.zig");
const registry = @import("registry.zig");

pub const extension_count_max = registry.name_count_max;
pub const queue_count_max = 64;
pub const group_device_count_max = raw.VK_MAX_DEVICE_GROUP_SIZE;
pub const rejection_count_max = extension_count_max + queue_count_max + 32;

/// Vulkan features commonly needed by modern applications. Core 1.0 features
/// use their unqualified names; promoted features document their core version.
pub const Feature = enum {
    robust_buffer_access,
    full_draw_index_uint32,
    image_cube_array,
    independent_blend,
    geometry_shader,
    tessellation_shader,
    sample_rate_shading,
    dual_source_blend,
    logic_op,
    multi_draw_indirect,
    draw_indirect_first_instance,
    depth_clamp,
    depth_bias_clamp,
    fill_mode_non_solid,
    depth_bounds,
    wide_lines,
    large_points,
    alpha_to_one,
    multi_viewport,
    sampler_anisotropy,
    texture_compression_etc2,
    texture_compression_astc_ldr,
    texture_compression_bc,
    occlusion_query_precise,
    pipeline_statistics_query,
    vertex_pipeline_stores_and_atomics,
    fragment_stores_and_atomics,
    shader_tessellation_and_geometry_point_size,
    shader_image_gather_extended,
    shader_storage_image_extended_formats,
    shader_storage_image_multisample,
    shader_storage_image_read_without_format,
    shader_storage_image_write_without_format,
    shader_uniform_buffer_array_dynamic_indexing,
    shader_sampled_image_array_dynamic_indexing,
    shader_storage_buffer_array_dynamic_indexing,
    shader_storage_image_array_dynamic_indexing,
    shader_clip_distance,
    shader_cull_distance,
    shader_float64,
    shader_int64,
    shader_int16,
    shader_resource_residency,
    shader_resource_min_lod,
    sparse_binding,
    sparse_residency_buffer,
    sparse_residency_image_2d,
    sparse_residency_image_3d,
    sparse_residency_2_samples,
    sparse_residency_4_samples,
    sparse_residency_8_samples,
    sparse_residency_16_samples,
    sparse_residency_aliased,
    variable_multisample_rate,
    inherited_queries,

    // Vulkan 1.1+
    protected_memory,
    sampler_ycbcr_conversion,
    multiview,
    shader_draw_parameters,
    // Vulkan 1.2+
    draw_indirect_count,
    timeline_semaphore,
    buffer_device_address,
    descriptor_indexing,
    imageless_framebuffer,
    // Vulkan 1.3+
    synchronization2,
    dynamic_rendering,
    maintenance4,
    // Vulkan 1.4+
    global_priority_query,
    host_image_copy,
    push_descriptor,
};

pub const FeatureSet = struct {
    bits: std.EnumSet(Feature) = .initEmpty(),

    pub const empty: FeatureSet = .{};

    pub fn init(features: []const Feature) FeatureSet {
        var set: FeatureSet = .{};
        for (features) |feature| set.bits.insert(feature);
        return set;
    }

    pub fn contains(set: FeatureSet, feature: Feature) bool {
        return set.bits.contains(feature);
    }

    pub fn enable(set: *FeatureSet, feature: Feature) void {
        set.bits.insert(feature);
    }

    pub fn containsAll(set: FeatureSet, required: FeatureSet) bool {
        return set.bits.supersetOf(required.bits);
    }

    pub fn firstMissing(set: FeatureSet, required: FeatureSet) ?Feature {
        inline for (std.meta.tags(Feature)) |feature| {
            if (required.contains(feature) and !set.contains(feature)) return feature;
        }
        return null;
    }

    pub fn coreRaw(set: FeatureSet) raw.VkPhysicalDeviceFeatures {
        var value: raw.VkPhysicalDeviceFeatures = .{};
        inline for (std.meta.tags(Feature)) |feature| {
            const enabled: raw.VkBool32 = raw.VK_TRUE;
            if (set.contains(feature)) switch (feature) {
                .robust_buffer_access => value.robustBufferAccess = enabled,
                .full_draw_index_uint32 => value.fullDrawIndexUint32 = enabled,
                .image_cube_array => value.imageCubeArray = enabled,
                .independent_blend => value.independentBlend = enabled,
                .geometry_shader => value.geometryShader = enabled,
                .tessellation_shader => value.tessellationShader = enabled,
                .sample_rate_shading => value.sampleRateShading = enabled,
                .dual_source_blend => value.dualSrcBlend = enabled,
                .logic_op => value.logicOp = enabled,
                .multi_draw_indirect => value.multiDrawIndirect = enabled,
                .draw_indirect_first_instance => value.drawIndirectFirstInstance = enabled,
                .depth_clamp => value.depthClamp = enabled,
                .depth_bias_clamp => value.depthBiasClamp = enabled,
                .fill_mode_non_solid => value.fillModeNonSolid = enabled,
                .depth_bounds => value.depthBounds = enabled,
                .wide_lines => value.wideLines = enabled,
                .large_points => value.largePoints = enabled,
                .alpha_to_one => value.alphaToOne = enabled,
                .multi_viewport => value.multiViewport = enabled,
                .sampler_anisotropy => value.samplerAnisotropy = enabled,
                .texture_compression_etc2 => value.textureCompressionETC2 = enabled,
                .texture_compression_astc_ldr => value.textureCompressionASTC_LDR = enabled,
                .texture_compression_bc => value.textureCompressionBC = enabled,
                .occlusion_query_precise => value.occlusionQueryPrecise = enabled,
                .pipeline_statistics_query => value.pipelineStatisticsQuery = enabled,
                .vertex_pipeline_stores_and_atomics => value.vertexPipelineStoresAndAtomics = enabled,
                .fragment_stores_and_atomics => value.fragmentStoresAndAtomics = enabled,
                .shader_tessellation_and_geometry_point_size => value.shaderTessellationAndGeometryPointSize = enabled,
                .shader_image_gather_extended => value.shaderImageGatherExtended = enabled,
                .shader_storage_image_extended_formats => value.shaderStorageImageExtendedFormats = enabled,
                .shader_storage_image_multisample => value.shaderStorageImageMultisample = enabled,
                .shader_storage_image_read_without_format => value.shaderStorageImageReadWithoutFormat = enabled,
                .shader_storage_image_write_without_format => value.shaderStorageImageWriteWithoutFormat = enabled,
                .shader_uniform_buffer_array_dynamic_indexing => value.shaderUniformBufferArrayDynamicIndexing = enabled,
                .shader_sampled_image_array_dynamic_indexing => value.shaderSampledImageArrayDynamicIndexing = enabled,
                .shader_storage_buffer_array_dynamic_indexing => value.shaderStorageBufferArrayDynamicIndexing = enabled,
                .shader_storage_image_array_dynamic_indexing => value.shaderStorageImageArrayDynamicIndexing = enabled,
                .shader_clip_distance => value.shaderClipDistance = enabled,
                .shader_cull_distance => value.shaderCullDistance = enabled,
                .shader_float64 => value.shaderFloat64 = enabled,
                .shader_int64 => value.shaderInt64 = enabled,
                .shader_int16 => value.shaderInt16 = enabled,
                .shader_resource_residency => value.shaderResourceResidency = enabled,
                .shader_resource_min_lod => value.shaderResourceMinLod = enabled,
                .sparse_binding => value.sparseBinding = enabled,
                .sparse_residency_buffer => value.sparseResidencyBuffer = enabled,
                .sparse_residency_image_2d => value.sparseResidencyImage2D = enabled,
                .sparse_residency_image_3d => value.sparseResidencyImage3D = enabled,
                .sparse_residency_2_samples => value.sparseResidency2Samples = enabled,
                .sparse_residency_4_samples => value.sparseResidency4Samples = enabled,
                .sparse_residency_8_samples => value.sparseResidency8Samples = enabled,
                .sparse_residency_16_samples => value.sparseResidency16Samples = enabled,
                .sparse_residency_aliased => value.sparseResidencyAliased = enabled,
                .variable_multisample_rate => value.variableMultisampleRate = enabled,
                .inherited_queries => value.inheritedQueries = enabled,
                else => {},
            };
        }
        return value;
    }

    pub fn hasPromoted(set: FeatureSet) bool {
        inline for (std.meta.tags(Feature)) |feature| switch (feature) {
            .protected_memory,
            .sampler_ycbcr_conversion,
            .multiview,
            .shader_draw_parameters,
            .draw_indirect_count,
            .timeline_semaphore,
            .buffer_device_address,
            .descriptor_indexing,
            .imageless_framebuffer,
            .synchronization2,
            .dynamic_rendering,
            .maintenance4,
            .global_priority_query,
            .host_image_copy,
            .push_descriptor,
            => if (set.contains(feature)) return true,
            else => {},
        };
        return false;
    }

    pub fn fromCoreRaw(value: *const raw.VkPhysicalDeviceFeatures) FeatureSet {
        @setEvalBranchQuota(10_000);
        var set: FeatureSet = .{};
        inline for (std.meta.fields(raw.VkPhysicalDeviceFeatures)) |field| {
            const feature: Feature = comptime if (std.mem.eql(u8, field.name, "robustBufferAccess")) .robust_buffer_access else if (std.mem.eql(u8, field.name, "fullDrawIndexUint32")) .full_draw_index_uint32 else if (std.mem.eql(u8, field.name, "imageCubeArray")) .image_cube_array else if (std.mem.eql(u8, field.name, "independentBlend")) .independent_blend else if (std.mem.eql(u8, field.name, "geometryShader")) .geometry_shader else if (std.mem.eql(u8, field.name, "tessellationShader")) .tessellation_shader else if (std.mem.eql(u8, field.name, "sampleRateShading")) .sample_rate_shading else if (std.mem.eql(u8, field.name, "dualSrcBlend")) .dual_source_blend else if (std.mem.eql(u8, field.name, "logicOp")) .logic_op else if (std.mem.eql(u8, field.name, "multiDrawIndirect")) .multi_draw_indirect else if (std.mem.eql(u8, field.name, "drawIndirectFirstInstance")) .draw_indirect_first_instance else if (std.mem.eql(u8, field.name, "depthClamp")) .depth_clamp else if (std.mem.eql(u8, field.name, "depthBiasClamp")) .depth_bias_clamp else if (std.mem.eql(u8, field.name, "fillModeNonSolid")) .fill_mode_non_solid else if (std.mem.eql(u8, field.name, "depthBounds")) .depth_bounds else if (std.mem.eql(u8, field.name, "wideLines")) .wide_lines else if (std.mem.eql(u8, field.name, "largePoints")) .large_points else if (std.mem.eql(u8, field.name, "alphaToOne")) .alpha_to_one else if (std.mem.eql(u8, field.name, "multiViewport")) .multi_viewport else if (std.mem.eql(u8, field.name, "samplerAnisotropy")) .sampler_anisotropy else if (std.mem.eql(u8, field.name, "textureCompressionETC2")) .texture_compression_etc2 else if (std.mem.eql(u8, field.name, "textureCompressionASTC_LDR")) .texture_compression_astc_ldr else if (std.mem.eql(u8, field.name, "textureCompressionBC")) .texture_compression_bc else if (std.mem.eql(u8, field.name, "occlusionQueryPrecise")) .occlusion_query_precise else if (std.mem.eql(u8, field.name, "pipelineStatisticsQuery")) .pipeline_statistics_query else if (std.mem.eql(u8, field.name, "vertexPipelineStoresAndAtomics")) .vertex_pipeline_stores_and_atomics else if (std.mem.eql(u8, field.name, "fragmentStoresAndAtomics")) .fragment_stores_and_atomics else if (std.mem.eql(u8, field.name, "shaderTessellationAndGeometryPointSize")) .shader_tessellation_and_geometry_point_size else if (std.mem.eql(u8, field.name, "shaderImageGatherExtended")) .shader_image_gather_extended else if (std.mem.eql(u8, field.name, "shaderStorageImageExtendedFormats")) .shader_storage_image_extended_formats else if (std.mem.eql(u8, field.name, "shaderStorageImageMultisample")) .shader_storage_image_multisample else if (std.mem.eql(u8, field.name, "shaderStorageImageReadWithoutFormat")) .shader_storage_image_read_without_format else if (std.mem.eql(u8, field.name, "shaderStorageImageWriteWithoutFormat")) .shader_storage_image_write_without_format else if (std.mem.eql(u8, field.name, "shaderUniformBufferArrayDynamicIndexing")) .shader_uniform_buffer_array_dynamic_indexing else if (std.mem.eql(u8, field.name, "shaderSampledImageArrayDynamicIndexing")) .shader_sampled_image_array_dynamic_indexing else if (std.mem.eql(u8, field.name, "shaderStorageBufferArrayDynamicIndexing")) .shader_storage_buffer_array_dynamic_indexing else if (std.mem.eql(u8, field.name, "shaderStorageImageArrayDynamicIndexing")) .shader_storage_image_array_dynamic_indexing else if (std.mem.eql(u8, field.name, "shaderClipDistance")) .shader_clip_distance else if (std.mem.eql(u8, field.name, "shaderCullDistance")) .shader_cull_distance else if (std.mem.eql(u8, field.name, "shaderFloat64")) .shader_float64 else if (std.mem.eql(u8, field.name, "shaderInt64")) .shader_int64 else if (std.mem.eql(u8, field.name, "shaderInt16")) .shader_int16 else if (std.mem.eql(u8, field.name, "shaderResourceResidency")) .shader_resource_residency else if (std.mem.eql(u8, field.name, "shaderResourceMinLod")) .shader_resource_min_lod else if (std.mem.eql(u8, field.name, "sparseBinding")) .sparse_binding else if (std.mem.eql(u8, field.name, "sparseResidencyBuffer")) .sparse_residency_buffer else if (std.mem.eql(u8, field.name, "sparseResidencyImage2D")) .sparse_residency_image_2d else if (std.mem.eql(u8, field.name, "sparseResidencyImage3D")) .sparse_residency_image_3d else if (std.mem.eql(u8, field.name, "sparseResidency2Samples")) .sparse_residency_2_samples else if (std.mem.eql(u8, field.name, "sparseResidency4Samples")) .sparse_residency_4_samples else if (std.mem.eql(u8, field.name, "sparseResidency8Samples")) .sparse_residency_8_samples else if (std.mem.eql(u8, field.name, "sparseResidency16Samples")) .sparse_residency_16_samples else if (std.mem.eql(u8, field.name, "sparseResidencyAliased")) .sparse_residency_aliased else if (std.mem.eql(u8, field.name, "variableMultisampleRate")) .variable_multisample_rate else if (std.mem.eql(u8, field.name, "inheritedQueries")) .inherited_queries else unreachable;
            if (@field(value, field.name) != raw.VK_FALSE) set.bits.insert(feature);
        }
        return set;
    }
};

pub const GlobalPriority = enum {
    low,
    medium,
    high,
    realtime,

    pub fn toRaw(priority: GlobalPriority) raw.VkQueueGlobalPriority {
        return switch (priority) {
            .low => raw.VK_QUEUE_GLOBAL_PRIORITY_LOW,
            .medium => raw.VK_QUEUE_GLOBAL_PRIORITY_MEDIUM,
            .high => raw.VK_QUEUE_GLOBAL_PRIORITY_HIGH,
            .realtime => raw.VK_QUEUE_GLOBAL_PRIORITY_REALTIME,
        };
    }
};

pub const QueueOptions = struct {
    family_index: core.QueueFamilyIndex,
    priorities: []const f32,
    protected: bool = false,
    global_priority: ?GlobalPriority = null,
};

/// A typed, non-owning member of a Vulkan physical-device group. Values are
/// obtained from `PhysicalDevice.groupMember`; applications never handle the
/// underlying Vulkan handle.
pub const GroupMember = struct {
    _handle: core.NonNullHandle(raw.VkPhysicalDevice),
    _instance_handle: core.NonNullHandle(raw.VkInstance),
};

pub const Requirements = struct {
    queues: []const QueueOptions,
    extensions: []const command.Extension = &.{},
    features: FeatureSet = .empty,
    enabled_instance_extensions: []const [:0]const u8 = &.{},
    device_group: []const GroupMember = &.{},
    enable_portability_subset: bool = false,

    pub fn validate(requirements: Requirements) core.Error!void {
        if (requirements.queues.len == 0) return error.InvalidOptions;
        if (requirements.queues.len > queue_count_max) return error.CountOverflow;
        if (requirements.extensions.len > extension_count_max) return error.CountOverflow;
        if (requirements.device_group.len > group_device_count_max) return error.CountOverflow;
        for (requirements.device_group, 0..) |member, index| {
            for (requirements.device_group[0..index]) |previous| {
                if (member._handle == previous._handle) return error.InvalidOptions;
            }
        }
        for (requirements.queues, 0..) |queue, queue_index| {
            if (queue.priorities.len == 0) return error.InvalidOptions;
            for (queue.priorities) |priority| {
                if (!std.math.isFinite(priority) or priority < 0 or priority > 1) {
                    return error.InvalidOptions;
                }
            }
            for (requirements.queues[0..queue_index]) |previous| {
                if (previous.family_index == queue.family_index) return error.InvalidOptions;
            }
        }
    }
};

pub const Rejection = union(enum) {
    invalid_options,
    instance_extension_used_as_device_extension: [:0]const u8,
    missing_extension: [:0]const u8,
    unsatisfied_extension_dependency: [:0]const u8,
    missing_feature: Feature,
    missing_queue_family: core.QueueFamilyIndex,
    insufficient_queue_count: core.QueueFamilyIndex,
    queue_capability_missing: core.QueueFamilyIndex,
};

pub const Evaluation = struct {
    rejections: [rejection_count_max]Rejection = undefined,
    rejection_count: usize = 0,

    pub fn supported(evaluation: *const Evaluation) bool {
        return evaluation.rejection_count == 0;
    }

    pub fn reasons(evaluation: *const Evaluation) []const Rejection {
        return evaluation.rejections[0..evaluation.rejection_count];
    }

    fn reject(evaluation: *Evaluation, reason: Rejection) void {
        if (evaluation.rejection_count == evaluation.rejections.len) return;
        evaluation.rejections[evaluation.rejection_count] = reason;
        evaluation.rejection_count += 1;
    }
};

pub const Availability = struct {
    api_version: core.Version,
    extensions: []const raw.VkExtensionProperties,
    features: FeatureSet,
    queue_families: []const physical_device.QueueFamily,
};

pub fn evaluate(requirements: Requirements, available: Availability) Evaluation {
    var result: Evaluation = .{};
    if (requirements.queues.len == 0 or requirements.queues.len > queue_count_max) {
        result.reject(.invalid_options);
    }
    if (requirements.extensions.len > extension_count_max) result.reject(.invalid_options);
    if (requirements.device_group.len > group_device_count_max) result.reject(.invalid_options);
    for (requirements.device_group, 0..) |member, index| {
        for (requirements.device_group[0..index]) |previous| {
            if (member._handle == previous._handle) result.reject(.invalid_options);
        }
    }

    for (requirements.extensions) |requested| {
        if (requested.scope != .device) {
            result.reject(.{ .instance_extension_used_as_device_extension = requested.name });
            continue;
        }
        if (!extensionSupported(requested, available.api_version, available.extensions)) {
            result.reject(.{ .missing_extension = requested.name });
            continue;
        }
        if (requested.depends) |depends| {
            if (!dependencyExpressionSatisfied(
                depends,
                requirements.extensions,
                requirements.enabled_instance_extensions,
                available.api_version,
            )) result.reject(.{ .unsatisfied_extension_dependency = requested.name });
        }
    }
    if (available.features.firstMissing(requirements.features)) |missing| {
        result.reject(.{ .missing_feature = missing });
    }
    for (requirements.queues, 0..) |queue, index| {
        if (queue.priorities.len == 0) result.reject(.invalid_options);
        for (queue.priorities) |priority| {
            if (!std.math.isFinite(priority) or priority < 0 or priority > 1) {
                result.reject(.invalid_options);
                break;
            }
        }
        for (requirements.queues[0..index]) |previous| {
            if (previous.family_index == queue.family_index) result.reject(.invalid_options);
        }
        const family = findQueueFamily(available.queue_families, queue.family_index) orelse {
            result.reject(.{ .missing_queue_family = queue.family_index });
            continue;
        };
        if (queue.priorities.len > family.queue_count) {
            result.reject(.{ .insufficient_queue_count = queue.family_index });
        }
        if (queue.protected and !family.supports(.protected)) {
            result.reject(.{ .queue_capability_missing = queue.family_index });
        }
        if (queue.protected and !requirements.features.contains(.protected_memory)) {
            result.reject(.invalid_options);
        }
        if (queue.global_priority != null and !available.api_version.atLeast(.v1_4)) {
            var enabled = false;
            for (requirements.extensions) |item| {
                if (std.mem.eql(u8, item.name, command.extension.khr_global_priority.name)) enabled = true;
            }
            if (!enabled) result.reject(.{ .missing_extension = command.extension.khr_global_priority.name });
        }
    }
    return result;
}

fn findQueueFamily(
    families: []const physical_device.QueueFamily,
    index: core.QueueFamilyIndex,
) ?physical_device.QueueFamily {
    for (families) |family| if (family.index == index) return family;
    return null;
}

pub fn extensionSupported(
    requested: command.Extension,
    api_version: core.Version,
    available: []const raw.VkExtensionProperties,
) bool {
    if (registry.supportsExtension(available, requested.name)) return true;
    const promoted = requested.promoted_to orelse return false;
    return versionTokenSatisfied(promoted, api_version);
}

fn versionTokenSatisfied(token: []const u8, version: core.Version) bool {
    if (!std.mem.startsWith(u8, token, "VK_VERSION_")) return false;
    const rest = token["VK_VERSION_".len..];
    const separator = std.mem.indexOfScalar(u8, rest, '_') orelse return false;
    const major = std.fmt.parseInt(u7, rest[0..separator], 10) catch return false;
    const minor = std.fmt.parseInt(u10, rest[separator + 1 ..], 10) catch return false;
    return version.atLeast(.{ .major = major, .minor = minor, .patch = 0 });
}

fn dependencyExpressionSatisfied(
    expression: []const u8,
    device_extensions: []const command.Extension,
    instance_extensions: []const [:0]const u8,
    api_version: core.Version,
) bool {
    // Registry dependency expressions use ',' for alternatives and '+' for
    // conjunction. Parenthesized expressions are handled recursively.
    var depth: usize = 0;
    var start: usize = 0;
    for (expression, 0..) |character, index| switch (character) {
        '(' => depth += 1,
        ')' => depth -|= 1,
        ',' => if (depth == 0) {
            if (dependencyExpressionSatisfied(expression[start..index], device_extensions, instance_extensions, api_version)) return true;
            start = index + 1;
        },
        else => {},
    };
    if (start != 0) return dependencyExpressionSatisfied(expression[start..], device_extensions, instance_extensions, api_version);

    depth = 0;
    start = 0;
    for (expression, 0..) |character, index| switch (character) {
        '(' => depth += 1,
        ')' => depth -|= 1,
        '+' => if (depth == 0) {
            if (!dependencyExpressionSatisfied(expression[start..index], device_extensions, instance_extensions, api_version)) return false;
            start = index + 1;
        },
        else => {},
    };
    if (start != 0) return dependencyExpressionSatisfied(expression[start..], device_extensions, instance_extensions, api_version);

    var token = std.mem.trim(u8, expression, " \t\r\n");
    while (token.len >= 2 and token[0] == '(' and token[token.len - 1] == ')') {
        token = std.mem.trim(u8, token[1 .. token.len - 1], " \t\r\n");
    }
    if (versionTokenSatisfied(token, api_version)) return true;
    for (device_extensions) |enabled| if (std.mem.eql(u8, enabled.name, token)) return true;
    return registry.containsName(instance_extensions, token);
}

/// Immutable, allocation-free record retained by an owned logical device.
pub const EnabledCapabilities = struct {
    _extensions: [extension_count_max][:0]const u8 = undefined,
    extension_count: usize = 0,
    features: FeatureSet = .empty,
    api_version: core.Version = .v1_0,

    pub fn init(items: []const command.Extension, features: FeatureSet, api_version: core.Version) EnabledCapabilities {
        var enabled: EnabledCapabilities = .{ .features = features, .api_version = api_version };
        for (items) |item| {
            if (enabled.extension_count == enabled._extensions.len) break;
            enabled._extensions[enabled.extension_count] = item.name;
            enabled.extension_count += 1;
        }
        return enabled;
    }

    pub fn extensions(enabled: *const EnabledCapabilities) []const [:0]const u8 {
        return enabled._extensions[0..enabled.extension_count];
    }

    pub fn supportsExtension(enabled: *const EnabledCapabilities, item: command.Extension) bool {
        if (registry.containsName(enabled.extensions(), item.name)) return true;
        const promoted = item.promoted_to orelse return false;
        return versionTokenSatisfied(promoted, enabled.api_version);
    }

    pub fn supportsFeature(enabled: *const EnabledCapabilities, feature: Feature) bool {
        return enabled.features.contains(feature);
    }

    pub fn supportsCommand(enabled: *const EnabledCapabilities, comptime descriptor: anytype) bool {
        if (@TypeOf(descriptor).scope != .device) return false;
        if (@TypeOf(descriptor).core_version) |version| {
            if (enabled.api_version.atLeast(.{ .major = version.major, .minor = version.minor, .patch = 0 })) return true;
        }
        inline for (@TypeOf(descriptor).extensions) |required| {
            if (registry.containsName(enabled.extensions(), required)) return true;
        }
        return false;
    }
};

test "feature sets round trip core features without raw consumer values" {
    const requested = FeatureSet.init(&.{ .geometry_shader, .sampler_anisotropy, .shader_int64 });
    const encoded = requested.coreRaw();
    const decoded = FeatureSet.fromCoreRaw(&encoded);
    try std.testing.expect(decoded.containsAll(requested));
    try std.testing.expect(!decoded.contains(.dynamic_rendering));
}

test "device requirement evaluation reports extensions features and queues independently" {
    var extension_property: raw.VkExtensionProperties = .{};
    @memcpy(extension_property.extensionName[0..command.extension.khr_swapchain.name.len], command.extension.khr_swapchain.name);
    const families = [_]physical_device.QueueFamily{.{
        .index = .fromRaw(0),
        .flags = .init(&.{ .graphics, .protected }),
        .queue_count = 2,
        .timestamp_valid_bits = 64,
        .minimum_image_transfer_granularity = .{ .width = 1, .height = 1, .depth = 1 },
    }};
    const features = FeatureSet.init(&.{ .geometry_shader, .protected_memory });
    const requirements: Requirements = .{
        .queues = &.{.{
            .family_index = .fromRaw(0),
            .priorities = &.{ 1, 0.5 },
            .protected = true,
        }},
        .extensions = &.{command.extension.khr_swapchain},
        .features = features,
        .enabled_instance_extensions = &.{command.extension.khr_surface.name},
    };
    const supported = evaluate(requirements, .{
        .api_version = .v1_3,
        .extensions = &.{extension_property},
        .features = features,
        .queue_families = &families,
    });
    try std.testing.expect(supported.supported());

    const rejected = evaluate(.{
        .queues = requirements.queues,
        .extensions = &.{command.extension.ext_mesh_shader},
        .features = .init(&.{.dynamic_rendering}),
    }, .{
        .api_version = .v1_2,
        .extensions = &.{extension_property},
        .features = .empty,
        .queue_families = &families,
    });
    try std.testing.expect(!rejected.supported());
    try std.testing.expect(rejected.reasons().len >= 2);
}

test "device groups and enabled capabilities remain typed and queryable" {
    const member: GroupMember = .{
        ._handle = @ptrFromInt(0x1000),
        ._instance_handle = @ptrFromInt(0x2000),
    };
    try std.testing.expectError(error.InvalidOptions, (Requirements{
        .queues = &.{.{ .family_index = .fromRaw(0), .priorities = &.{1} }},
        .device_group = &.{ member, member },
    }).validate());

    const enabled = EnabledCapabilities.init(
        &.{command.extension.khr_swapchain},
        .init(&.{.dynamic_rendering}),
        .v1_3,
    );
    try std.testing.expect(enabled.supportsExtension(command.extension.khr_swapchain));
    try std.testing.expect(enabled.supportsExtension(command.extension.khr_dynamic_rendering));
    try std.testing.expect(enabled.supportsFeature(.dynamic_rendering));
    try std.testing.expect(enabled.supportsCommand(command.cmd_begin_rendering));
    try std.testing.expect(!enabled.supportsCommand(command.cmd_encode_video_khr));
}
