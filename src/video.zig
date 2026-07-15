const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");
const memory = @import("memory.zig");
const buffers = @import("buffer.zig");
const images = @import("image.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const PhysicalDeviceHandle = core.NonNullHandle(raw.VkPhysicalDevice);
const SessionHandle = core.NonNullHandle(raw.VkVideoSessionKHR);
const ParametersHandle = core.NonNullHandle(raw.VkVideoSessionParametersKHR);
pub const format_count_max = 128;
pub const memory_binding_count_max = 32;

pub const ChromaSubsampling = enum(raw.VkVideoChromaSubsamplingFlagsKHR) {
    monochrome = raw.VK_VIDEO_CHROMA_SUBSAMPLING_MONOCHROME_BIT_KHR,
    yuv420 = raw.VK_VIDEO_CHROMA_SUBSAMPLING_420_BIT_KHR,
    yuv422 = raw.VK_VIDEO_CHROMA_SUBSAMPLING_422_BIT_KHR,
    yuv444 = raw.VK_VIDEO_CHROMA_SUBSAMPLING_444_BIT_KHR,
    _,
};

pub const ComponentBitDepth = enum(raw.VkVideoComponentBitDepthFlagsKHR) {
    depth_8 = raw.VK_VIDEO_COMPONENT_BIT_DEPTH_8_BIT_KHR,
    depth_10 = raw.VK_VIDEO_COMPONENT_BIT_DEPTH_10_BIT_KHR,
    depth_12 = raw.VK_VIDEO_COMPONENT_BIT_DEPTH_12_BIT_KHR,
    _,
};

pub const H264Profile = enum(raw.StdVideoH264ProfileIdc) {
    baseline = raw.STD_VIDEO_H264_PROFILE_IDC_BASELINE,
    main = raw.STD_VIDEO_H264_PROFILE_IDC_MAIN,
    high = raw.STD_VIDEO_H264_PROFILE_IDC_HIGH,
    high_444_predictive = raw.STD_VIDEO_H264_PROFILE_IDC_HIGH_444_PREDICTIVE,
    _,
};

pub const H265Profile = enum(raw.StdVideoH265ProfileIdc) {
    main = raw.STD_VIDEO_H265_PROFILE_IDC_MAIN,
    main_10 = raw.STD_VIDEO_H265_PROFILE_IDC_MAIN_10,
    main_still_picture = raw.STD_VIDEO_H265_PROFILE_IDC_MAIN_STILL_PICTURE,
    format_range_extensions = raw.STD_VIDEO_H265_PROFILE_IDC_FORMAT_RANGE_EXTENSIONS,
    screen_content_coding_extensions = raw.STD_VIDEO_H265_PROFILE_IDC_SCC_EXTENSIONS,
    _,
};

pub const Av1Profile = enum(raw.StdVideoAV1Profile) {
    main = raw.STD_VIDEO_AV1_PROFILE_MAIN,
    high = raw.STD_VIDEO_AV1_PROFILE_HIGH,
    professional = raw.STD_VIDEO_AV1_PROFILE_PROFESSIONAL,
    _,
};

pub const Vp9Profile = enum(raw.StdVideoVP9Profile) {
    profile_0 = raw.STD_VIDEO_VP9_PROFILE_0,
    profile_1 = raw.STD_VIDEO_VP9_PROFILE_1,
    profile_2 = raw.STD_VIDEO_VP9_PROFILE_2,
    profile_3 = raw.STD_VIDEO_VP9_PROFILE_3,
    _,
};

pub const H264PictureLayout = enum(raw.VkVideoDecodeH264PictureLayoutFlagBitsKHR) {
    progressive = raw.VK_VIDEO_DECODE_H264_PICTURE_LAYOUT_PROGRESSIVE_KHR,
    interlaced_interleaved_lines = raw.VK_VIDEO_DECODE_H264_PICTURE_LAYOUT_INTERLACED_INTERLEAVED_LINES_BIT_KHR,
    interlaced_separate_planes = raw.VK_VIDEO_DECODE_H264_PICTURE_LAYOUT_INTERLACED_SEPARATE_PLANES_BIT_KHR,
    _,
};

pub const Profile = struct {
    codec: Codec,
    chroma: ChromaSubsampling = .yuv420,
    luma_depth: ComponentBitDepth = .depth_8,
    chroma_depth: ComponentBitDepth = .depth_8,

    pub const Codec = union(enum) {
        decode_h264: struct { profile: H264Profile = .main, picture_layout: H264PictureLayout = .progressive },
        decode_h265: H265Profile,
        decode_av1: struct { profile: Av1Profile = .main, film_grain: bool = false },
        decode_vp9: Vp9Profile,
        encode_h264: H264Profile,
        encode_h265: H265Profile,
        encode_av1: Av1Profile,
    };

    pub fn isDecode(profile: Profile) bool {
        return switch (profile.codec) {
            .decode_h264, .decode_h265, .decode_av1, .decode_vp9 => true,
            else => false,
        };
    }
};

const ProfileStorage = struct {
    root: raw.VkVideoProfileInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_PROFILE_INFO_KHR },
    decode_h264: raw.VkVideoDecodeH264ProfileInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_H264_PROFILE_INFO_KHR },
    decode_h265: raw.VkVideoDecodeH265ProfileInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_H265_PROFILE_INFO_KHR },
    decode_av1: raw.VkVideoDecodeAV1ProfileInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_AV1_PROFILE_INFO_KHR },
    decode_vp9: raw.VkVideoDecodeVP9ProfileInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_VP9_PROFILE_INFO_KHR },
    encode_h264: raw.VkVideoEncodeH264ProfileInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_PROFILE_INFO_KHR },
    encode_h265: raw.VkVideoEncodeH265ProfileInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_PROFILE_INFO_KHR },
    encode_av1: raw.VkVideoEncodeAV1ProfileInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_AV1_PROFILE_INFO_KHR },

    fn link(storage: *ProfileStorage, profile: Profile) *const raw.VkVideoProfileInfoKHR {
        storage.root.chromaSubsampling = @intFromEnum(profile.chroma);
        storage.root.lumaBitDepth = @intFromEnum(profile.luma_depth);
        storage.root.chromaBitDepth = @intFromEnum(profile.chroma_depth);
        storage.root.pNext = switch (profile.codec) {
            .decode_h264 => |value| blk: {
                storage.root.videoCodecOperation = raw.VK_VIDEO_CODEC_OPERATION_DECODE_H264_BIT_KHR;
                storage.decode_h264.stdProfileIdc = @intFromEnum(value.profile);
                storage.decode_h264.pictureLayout = @intFromEnum(value.picture_layout);
                break :blk &storage.decode_h264;
            },
            .decode_h265 => |value| blk: {
                storage.root.videoCodecOperation = raw.VK_VIDEO_CODEC_OPERATION_DECODE_H265_BIT_KHR;
                storage.decode_h265.stdProfileIdc = @intFromEnum(value);
                break :blk &storage.decode_h265;
            },
            .decode_av1 => |value| blk: {
                storage.root.videoCodecOperation = raw.VK_VIDEO_CODEC_OPERATION_DECODE_AV1_BIT_KHR;
                storage.decode_av1.stdProfile = @intFromEnum(value.profile);
                storage.decode_av1.filmGrainSupport = if (value.film_grain) raw.VK_TRUE else raw.VK_FALSE;
                break :blk &storage.decode_av1;
            },
            .decode_vp9 => |value| blk: {
                storage.root.videoCodecOperation = raw.VK_VIDEO_CODEC_OPERATION_DECODE_VP9_BIT_KHR;
                storage.decode_vp9.stdProfile = @intFromEnum(value);
                break :blk &storage.decode_vp9;
            },
            .encode_h264 => |value| blk: {
                storage.root.videoCodecOperation = raw.VK_VIDEO_CODEC_OPERATION_ENCODE_H264_BIT_KHR;
                storage.encode_h264.stdProfileIdc = @intFromEnum(value);
                break :blk &storage.encode_h264;
            },
            .encode_h265 => |value| blk: {
                storage.root.videoCodecOperation = raw.VK_VIDEO_CODEC_OPERATION_ENCODE_H265_BIT_KHR;
                storage.encode_h265.stdProfileIdc = @intFromEnum(value);
                break :blk &storage.encode_h265;
            },
            .encode_av1 => |value| blk: {
                storage.root.videoCodecOperation = raw.VK_VIDEO_CODEC_OPERATION_ENCODE_AV1_BIT_KHR;
                storage.encode_av1.stdProfile = @intFromEnum(value);
                break :blk &storage.encode_av1;
            },
        };
        return &storage.root;
    }
};

pub const Capabilities = struct {
    min_bitstream_offset_alignment: core.DeviceSize,
    min_bitstream_size_alignment: core.DeviceSize,
    picture_access_granularity: types.Extent2D,
    coded_extent_min: types.Extent2D,
    coded_extent_max: types.Extent2D,
    max_dpb_slots: u32,
    max_active_reference_pictures: u32,
    standard_header_name: [256:0]u8,
    standard_header_spec_version: u32,
};

pub const FormatProperties = struct {
    format: types.Format,
    components: types.ComponentMapping,
    image_create_flags: types.ImageCreateFlags,
    image_type: types.ImageType,
    tiling: types.ImageTiling,
    usage: types.ImageUsageFlags,
};

pub const RateControlMode = enum(raw.VkVideoEncodeRateControlModeFlagBitsKHR) {
    default = raw.VK_VIDEO_ENCODE_RATE_CONTROL_MODE_DEFAULT_KHR,
    disabled = raw.VK_VIDEO_ENCODE_RATE_CONTROL_MODE_DISABLED_BIT_KHR,
    constant_bitrate = raw.VK_VIDEO_ENCODE_RATE_CONTROL_MODE_CBR_BIT_KHR,
    variable_bitrate = raw.VK_VIDEO_ENCODE_RATE_CONTROL_MODE_VBR_BIT_KHR,
    _,
};

pub const QualityLevelProperties = struct {
    preferred_rate_control_mode: RateControlMode,
    preferred_rate_control_layer_count: u32,
};

pub const QueryContext = struct {
    _physical_device: PhysicalDeviceHandle,
    _capabilities: ?CommandFunction(raw.PFN_vkGetPhysicalDeviceVideoCapabilitiesKHR),
    _formats: ?CommandFunction(raw.PFN_vkGetPhysicalDeviceVideoFormatPropertiesKHR),
    _quality: ?CommandFunction(raw.PFN_vkGetPhysicalDeviceVideoEncodeQualityLevelPropertiesKHR),

    pub fn capabilities(context: QueryContext, profile: Profile) core.Error!Capabilities {
        const get = context._capabilities orelse return error.MissingCommand;
        var profile_storage: ProfileStorage = .{};
        var value: raw.VkVideoCapabilitiesKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_CAPABILITIES_KHR };
        try core.checkSuccess(get(context._physical_device, profile_storage.link(profile), &value));
        var name: [256:0]u8 = [_:0]u8{0} ** 256;
        @memcpy(name[0..256], value.stdHeaderVersion.extensionName[0..256]);
        return .{
            .min_bitstream_offset_alignment = .fromBytes(value.minBitstreamBufferOffsetAlignment),
            .min_bitstream_size_alignment = .fromBytes(value.minBitstreamBufferSizeAlignment),
            .picture_access_granularity = .fromRaw(value.pictureAccessGranularity),
            .coded_extent_min = .fromRaw(value.minCodedExtent),
            .coded_extent_max = .fromRaw(value.maxCodedExtent),
            .max_dpb_slots = value.maxDpbSlots,
            .max_active_reference_pictures = value.maxActiveReferencePictures,
            .standard_header_name = name,
            .standard_header_spec_version = value.stdHeaderVersion.specVersion,
        };
    }

    pub fn formatCount(context: QueryContext, profile: Profile, usage: types.ImageUsageFlags) core.Error!u32 {
        const enumerate = context._formats orelse return error.MissingCommand;
        var storage: ProfileStorage = .{};
        const profile_info = storage.link(profile);
        const list: raw.VkVideoProfileListInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_VIDEO_PROFILE_LIST_INFO_KHR,
            .profileCount = 1,
            .pProfiles = profile_info,
        };
        const info: raw.VkPhysicalDeviceVideoFormatInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VIDEO_FORMAT_INFO_KHR,
            .pNext = &list,
            .imageUsage = usage.toRaw(),
        };
        var count: u32 = 0;
        const result = enumerate(context._physical_device, &info, &count, null);
        if (result != raw.VK_SUCCESS and result != raw.VK_INCOMPLETE) try core.checkSuccess(result);
        if (count > format_count_max) return error.CountOverflow;
        return count;
    }

    pub fn formatsInto(context: QueryContext, profile: Profile, usage: types.ImageUsageFlags, output: []FormatProperties) core.Error![]FormatProperties {
        if (output.len > format_count_max) return error.CountOverflow;
        const enumerate = context._formats orelse return error.MissingCommand;
        var storage: ProfileStorage = .{};
        const profile_info = storage.link(profile);
        const list: raw.VkVideoProfileListInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_VIDEO_PROFILE_LIST_INFO_KHR,
            .profileCount = 1,
            .pProfiles = profile_info,
        };
        const info: raw.VkPhysicalDeviceVideoFormatInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VIDEO_FORMAT_INFO_KHR,
            .pNext = &list,
            .imageUsage = usage.toRaw(),
        };
        var values: [format_count_max]raw.VkVideoFormatPropertiesKHR = undefined;
        for (values[0..output.len]) |*value| value.* = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_FORMAT_PROPERTIES_KHR };
        var count: u32 = @intCast(output.len);
        const result = enumerate(context._physical_device, &info, &count, if (output.len == 0) null else &values);
        if (result == raw.VK_INCOMPLETE or count > output.len) return error.BufferTooSmall;
        try core.checkSuccess(result);
        for (output[0..count], values[0..count]) |*item, value| item.* = .{
            .format = .fromRaw(value.format),
            .components = .fromRaw(value.componentMapping),
            .image_create_flags = .fromRaw(value.imageCreateFlags),
            .image_type = .fromRaw(value.imageType),
            .tiling = .fromRaw(value.imageTiling),
            .usage = .fromRaw(value.imageUsageFlags),
        };
        return output[0..count];
    }

    pub fn formats(context: QueryContext, gpa: std.mem.Allocator, profile: Profile, usage: types.ImageUsageFlags) (core.Error || std.mem.Allocator.Error)![]FormatProperties {
        var output = try gpa.alloc(FormatProperties, try context.formatCount(profile, usage));
        errdefer gpa.free(output);
        for (0..4) |_| {
            const written = context.formatsInto(profile, usage, output) catch |err| switch (err) {
                error.BufferTooSmall => {
                    const required = try context.formatCount(profile, usage);
                    const next = if (required > output.len) required else @min(output.len * 2, format_count_max);
                    if (next <= output.len) return error.EnumerationUnstable;
                    output = try gpa.realloc(output, next);
                    continue;
                },
                else => return err,
            };
            return gpa.realloc(output, written.len);
        }
        return error.EnumerationUnstable;
    }

    pub fn qualityLevel(context: QueryContext, profile: Profile, quality_level: u32) core.Error!QualityLevelProperties {
        if (profile.isDecode()) return error.UnsupportedCodec;
        const get = context._quality orelse return error.MissingCommand;
        var storage: ProfileStorage = .{};
        const info: raw.VkPhysicalDeviceVideoEncodeQualityLevelInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VIDEO_ENCODE_QUALITY_LEVEL_INFO_KHR,
            .pVideoProfile = storage.link(profile),
            .qualityLevel = quality_level,
        };
        var value: raw.VkVideoEncodeQualityLevelPropertiesKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_QUALITY_LEVEL_PROPERTIES_KHR,
        };
        try core.checkSuccess(get(context._physical_device, &info, &value));
        return .{
            .preferred_rate_control_mode = @enumFromInt(value.preferredRateControlMode),
            .preferred_rate_control_layer_count = value.preferredRateControlLayerCount,
        };
    }
};

pub const SessionOptions = struct {
    queue_family: core.QueueFamilyIndex,
    profile: Profile = .{ .codec = .{ .decode_h264 = .{} } },
    picture_format: types.Format,
    coded_extent_max: types.Extent2D,
    reference_picture_format: types.Format,
    max_dpb_slots: u32,
    max_active_reference_pictures: u32,
    standard_header_name: [:0]const u8,
    standard_header_spec_version: u32,
};

pub const MemoryRequirement = struct {
    binding_index: u32,
    size: core.DeviceSize,
    alignment: core.DeviceSize,
    memory_type_bits: u32,
};

pub const MemoryBinding = struct {
    binding_index: u32,
    allocation: *const memory.Allocation,
    offset: core.DeviceOffset = .zero,
    size: core.DeviceSize,
};

pub const Session = struct {
    _handle: ?SessionHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: core.DeviceState,
    profile: Profile = .{ .codec = .{ .decode_h264 = .{} } },
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy: CommandFunction(raw.PFN_vkDestroyVideoSessionKHR),
    get_memory_requirements: ?CommandFunction(raw.PFN_vkGetVideoSessionMemoryRequirementsKHR) = null,
    bind_memory: ?CommandFunction(raw.PFN_vkBindVideoSessionMemoryKHR) = null,

    pub fn deinit(session: *Session) void {
        if (!(session._owner.release(session) catch return)) return;
        const handle = session._handle orelse return;
        session.destroy(session._device_handle, handle, session.allocation_callbacks);
        session._handle = null;
    }

    pub fn rawHandle(session: *const Session) core.Error!raw.VkVideoSessionKHR {
        try session._owner.validate(session);
        try session._device_state.ensureDispatchAllowed();
        return session._handle orelse error.InactiveObject;
    }

    pub fn debugObject(session: *const Session) core.Error!debug_utils.Object {
        return .forDevice(.video_session, try session.rawHandle(), session._device_handle);
    }

    pub fn memoryRequirementCount(session: *const Session) core.Error!u32 {
        const get = session.get_memory_requirements orelse return error.MissingCommand;
        var count: u32 = 0;
        const result = get(session._device_handle, try session.rawHandle(), &count, null);
        if (result != raw.VK_SUCCESS and result != raw.VK_INCOMPLETE) try core.checkSuccessOptional(@constCast(&session._device_state), result);
        if (count > memory_binding_count_max) return error.CountOverflow;
        return count;
    }

    pub fn memoryRequirementsInto(session: *const Session, output: []MemoryRequirement) core.Error![]MemoryRequirement {
        const get = session.get_memory_requirements orelse return error.MissingCommand;
        if (output.len > memory_binding_count_max) return error.CountOverflow;
        var values: [memory_binding_count_max]raw.VkVideoSessionMemoryRequirementsKHR = undefined;
        for (values[0..output.len]) |*value| value.* = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_SESSION_MEMORY_REQUIREMENTS_KHR };
        var count: u32 = @intCast(output.len);
        const result = get(session._device_handle, try session.rawHandle(), &count, if (output.len == 0) null else &values);
        if (result == raw.VK_INCOMPLETE or count > output.len) return error.BufferTooSmall;
        try core.checkSuccessOptional(@constCast(&session._device_state), result);
        for (output[0..count], values[0..count]) |*item, value| item.* = .{
            .binding_index = value.memoryBindIndex,
            .size = .fromBytes(value.memoryRequirements.size),
            .alignment = .fromBytes(value.memoryRequirements.alignment),
            .memory_type_bits = value.memoryRequirements.memoryTypeBits,
        };
        return output[0..count];
    }

    pub fn memoryRequirements(session: *const Session, gpa: std.mem.Allocator) (core.Error || std.mem.Allocator.Error)![]MemoryRequirement {
        var output = try gpa.alloc(MemoryRequirement, try session.memoryRequirementCount());
        errdefer gpa.free(output);
        for (0..4) |_| {
            const written = session.memoryRequirementsInto(output) catch |err| switch (err) {
                error.BufferTooSmall => {
                    const required = try session.memoryRequirementCount();
                    const next = if (required > output.len) required else @min(output.len * 2, memory_binding_count_max);
                    if (next <= output.len) return error.EnumerationUnstable;
                    output = try gpa.realloc(output, next);
                    continue;
                },
                else => return err,
            };
            return gpa.realloc(output, written.len);
        }
        return error.EnumerationUnstable;
    }

    pub fn bindMemory(session: *const Session, bindings: []const MemoryBinding) core.Error!void {
        const bind = session.bind_memory orelse return error.MissingCommand;
        if (bindings.len == 0 or bindings.len > memory_binding_count_max) return error.InvalidOptions;
        var values: [memory_binding_count_max]raw.VkBindVideoSessionMemoryInfoKHR = undefined;
        for (bindings, values[0..bindings.len]) |binding, *value| {
            if (binding.allocation._device_handle != session._device_handle or binding.size.bytes() == 0) return error.InvalidHandle;
            if (binding.offset.bytes() > binding.allocation.size.bytes() or binding.size.bytes() > binding.allocation.size.bytes() - binding.offset.bytes()) return error.InvalidOptions;
            value.* = .{
                .sType = raw.VK_STRUCTURE_TYPE_BIND_VIDEO_SESSION_MEMORY_INFO_KHR,
                .memoryBindIndex = binding.binding_index,
                .memory = try binding.allocation.rawHandle(),
                .memoryOffset = binding.offset.bytes(),
                .memorySize = binding.size.bytes(),
            };
        }
        try core.checkSuccessOptional(@constCast(&session._device_state), bind(session._device_handle, try session.rawHandle(), @intCast(bindings.len), &values));
    }
};

pub const ParameterLimits = union(enum) {
    decode_h264: struct { max_sps: u32, max_pps: u32 },
    decode_h265: struct { max_vps: u32, max_sps: u32, max_pps: u32 },
    encode_h264: struct { max_sps: u32, max_pps: u32 },
    encode_h265: struct { max_vps: u32, max_sps: u32, max_pps: u32 },
};

pub const H264SequenceParameterSet = raw.StdVideoH264SequenceParameterSet;
pub const H264PictureParameterSet = raw.StdVideoH264PictureParameterSet;
pub const H265VideoParameterSet = raw.StdVideoH265VideoParameterSet;
pub const H265SequenceParameterSet = raw.StdVideoH265SequenceParameterSet;
pub const H265PictureParameterSet = raw.StdVideoH265PictureParameterSet;

pub const H264ParameterUpdate = struct {
    sequence_parameter_sets: ?*const H264SequenceParameterSet = null,
    sequence_parameter_set_count: u32 = 0,
    picture_parameter_sets: ?*const H264PictureParameterSet = null,
    picture_parameter_set_count: u32 = 0,
};

pub const H265ParameterUpdate = struct {
    video_parameter_sets: ?*const H265VideoParameterSet = null,
    video_parameter_set_count: u32 = 0,
    sequence_parameter_sets: ?*const H265SequenceParameterSet = null,
    sequence_parameter_set_count: u32 = 0,
    picture_parameter_sets: ?*const H265PictureParameterSet = null,
    picture_parameter_set_count: u32 = 0,
};

pub const ParameterUpdate = union(enum) {
    h264: H264ParameterUpdate,
    h265: H265ParameterUpdate,
};

pub const ParametersOptions = struct {
    session: *const Session,
    template: ?*const Parameters = null,
    limits: ParameterLimits,
};

pub const Parameters = struct {
    _handle: ?ParametersHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: core.DeviceState,
    profile: Profile = .{ .codec = .{ .decode_h264 = .{} } },
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy: CommandFunction(raw.PFN_vkDestroyVideoSessionParametersKHR),
    update_parameters: ?CommandFunction(raw.PFN_vkUpdateVideoSessionParametersKHR) = null,

    pub fn deinit(parameters: *Parameters) void {
        if (!(parameters._owner.release(parameters) catch return)) return;
        const handle = parameters._handle orelse return;
        parameters.destroy(parameters._device_handle, handle, parameters.allocation_callbacks);
        parameters._handle = null;
    }

    pub fn rawHandle(parameters: *const Parameters) core.Error!raw.VkVideoSessionParametersKHR {
        try parameters._owner.validate(parameters);
        try parameters._device_state.ensureDispatchAllowed();
        return parameters._handle orelse error.InactiveObject;
    }

    pub fn debugObject(parameters: *const Parameters) core.Error!debug_utils.Object {
        return .forDevice(.video_session_parameters, try parameters.rawHandle(), parameters._device_handle);
    }

    pub fn update(parameters: *const Parameters, sequence: u32, data: ParameterUpdate) core.Error!void {
        const update_fn = parameters.update_parameters orelse return error.MissingCommand;
        if (!parameterUpdateMatches(parameters.profile, data)) return error.UnsupportedCodec;
        var h264_decode: raw.VkVideoDecodeH264SessionParametersAddInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_H264_SESSION_PARAMETERS_ADD_INFO_KHR };
        var h264_encode: raw.VkVideoEncodeH264SessionParametersAddInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_SESSION_PARAMETERS_ADD_INFO_KHR };
        var h265_decode: raw.VkVideoDecodeH265SessionParametersAddInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_H265_SESSION_PARAMETERS_ADD_INFO_KHR };
        var h265_encode: raw.VkVideoEncodeH265SessionParametersAddInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_SESSION_PARAMETERS_ADD_INFO_KHR };
        const next: *const anyopaque = switch (data) {
            .h264 => |value| switch (parameters.profile.codec) {
                .decode_h264 => blk: {
                    fillH264Add(&h264_decode, value);
                    break :blk &h264_decode;
                },
                .encode_h264 => blk: {
                    fillH264Add(&h264_encode, value);
                    break :blk &h264_encode;
                },
                else => unreachable,
            },
            .h265 => |value| switch (parameters.profile.codec) {
                .decode_h265 => blk: {
                    fillH265Add(&h265_decode, value);
                    break :blk &h265_decode;
                },
                .encode_h265 => blk: {
                    fillH265Add(&h265_encode, value);
                    break :blk &h265_encode;
                },
                else => unreachable,
            },
        };
        const info: raw.VkVideoSessionParametersUpdateInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_VIDEO_SESSION_PARAMETERS_UPDATE_INFO_KHR,
            .pNext = next,
            .updateSequenceCount = sequence,
        };
        try core.checkSuccessOptional(@constCast(&parameters._device_state), update_fn(parameters._device_handle, try parameters.rawHandle(), &info));
    }
};

pub const Context = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    _allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    _create_session: ?CommandFunction(raw.PFN_vkCreateVideoSessionKHR),
    _destroy_session: ?CommandFunction(raw.PFN_vkDestroyVideoSessionKHR),
    _get_memory_requirements: ?CommandFunction(raw.PFN_vkGetVideoSessionMemoryRequirementsKHR),
    _bind_memory: ?CommandFunction(raw.PFN_vkBindVideoSessionMemoryKHR),
    _create_parameters: ?CommandFunction(raw.PFN_vkCreateVideoSessionParametersKHR),
    _update_parameters: ?CommandFunction(raw.PFN_vkUpdateVideoSessionParametersKHR),
    _destroy_parameters: ?CommandFunction(raw.PFN_vkDestroyVideoSessionParametersKHR),

    pub fn createSession(context: Context, options: SessionOptions) core.Error!Session {
        if (options.coded_extent_max.width == 0 or options.coded_extent_max.height == 0 or options.standard_header_name.len >= 256) return error.InvalidOptions;
        const create = context._create_session orelse return error.MissingCommand;
        const destroy = context._destroy_session orelse return error.MissingCommand;
        const get_memory = context._get_memory_requirements orelse return error.MissingCommand;
        const bind_memory = context._bind_memory orelse return error.MissingCommand;
        var profile_storage: ProfileStorage = .{};
        var header: raw.VkExtensionProperties = .{ .specVersion = options.standard_header_spec_version };
        @memcpy(header.extensionName[0..options.standard_header_name.len], options.standard_header_name);
        const info: raw.VkVideoSessionCreateInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_VIDEO_SESSION_CREATE_INFO_KHR,
            .queueFamilyIndex = options.queue_family.toRaw(),
            .pVideoProfile = profile_storage.link(options.profile),
            .pictureFormat = options.picture_format.toRaw(),
            .maxCodedExtent = options.coded_extent_max.toRaw(),
            .referencePictureFormat = options.reference_picture_format.toRaw(),
            .maxDpbSlots = options.max_dpb_slots,
            .maxActiveReferencePictures = options.max_active_reference_pictures,
            .pStdHeaderVersion = &header,
        };
        var handle: raw.VkVideoSessionKHR = null;
        const result = create(context._device, &info, context._allocation_callbacks, &handle);
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional| destroy(context._device, provisional, context._allocation_callbacks);
            try core.checkSuccessTracked(@constCast(context._state), result);
            unreachable;
        }
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._owner = try .init(&handle),
            ._device_handle = context._device,
            ._device_state = context._state.*,
            .profile = options.profile,
            .allocation_callbacks = context._allocation_callbacks,
            .destroy = destroy,
            .get_memory_requirements = get_memory,
            .bind_memory = bind_memory,
        };
    }

    pub fn createParameters(context: Context, options: ParametersOptions) core.Error!Parameters {
        if (options.session._device_handle != context._device) return error.InvalidHandle;
        if (!parameterLimitsMatch(options.session.profile, options.limits)) return error.UnsupportedCodec;
        const create = context._create_parameters orelse return error.MissingCommand;
        const destroy = context._destroy_parameters orelse return error.MissingCommand;
        var h264_decode: raw.VkVideoDecodeH264SessionParametersCreateInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_H264_SESSION_PARAMETERS_CREATE_INFO_KHR };
        var h265_decode: raw.VkVideoDecodeH265SessionParametersCreateInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_H265_SESSION_PARAMETERS_CREATE_INFO_KHR };
        var h264_encode: raw.VkVideoEncodeH264SessionParametersCreateInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_SESSION_PARAMETERS_CREATE_INFO_KHR };
        var h265_encode: raw.VkVideoEncodeH265SessionParametersCreateInfoKHR = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_SESSION_PARAMETERS_CREATE_INFO_KHR };
        const next: *const anyopaque = switch (options.limits) {
            .decode_h264 => |value| blk: {
                h264_decode.maxStdSPSCount = value.max_sps;
                h264_decode.maxStdPPSCount = value.max_pps;
                break :blk &h264_decode;
            },
            .decode_h265 => |value| blk: {
                h265_decode.maxStdVPSCount = value.max_vps;
                h265_decode.maxStdSPSCount = value.max_sps;
                h265_decode.maxStdPPSCount = value.max_pps;
                break :blk &h265_decode;
            },
            .encode_h264 => |value| blk: {
                h264_encode.maxStdSPSCount = value.max_sps;
                h264_encode.maxStdPPSCount = value.max_pps;
                break :blk &h264_encode;
            },
            .encode_h265 => |value| blk: {
                h265_encode.maxStdVPSCount = value.max_vps;
                h265_encode.maxStdSPSCount = value.max_sps;
                h265_encode.maxStdPPSCount = value.max_pps;
                break :blk &h265_encode;
            },
        };
        const template_handle = if (options.template) |template| blk: {
            if (template._device_handle != context._device) return error.InvalidHandle;
            break :blk try template.rawHandle();
        } else null;
        const info: raw.VkVideoSessionParametersCreateInfoKHR = .{
            .sType = raw.VK_STRUCTURE_TYPE_VIDEO_SESSION_PARAMETERS_CREATE_INFO_KHR,
            .pNext = next,
            .videoSessionParametersTemplate = template_handle,
            .videoSession = try options.session.rawHandle(),
        };
        var handle: raw.VkVideoSessionParametersKHR = null;
        const result = create(context._device, &info, context._allocation_callbacks, &handle);
        if (result != raw.VK_SUCCESS) {
            if (handle) |provisional| destroy(context._device, provisional, context._allocation_callbacks);
            try core.checkSuccessTracked(@constCast(context._state), result);
            unreachable;
        }
        return .{
            ._handle = handle orelse return error.InvalidHandle,
            ._owner = try .init(&handle),
            ._device_handle = context._device,
            ._device_state = context._state.*,
            .profile = options.session.profile,
            .allocation_callbacks = context._allocation_callbacks,
            .destroy = destroy,
            .update_parameters = context._update_parameters,
        };
    }
};

pub const CodingOptions = struct {
    session: *const Session,
    parameters: ?*const Parameters = null,
    references: []const ReferenceSlot = &.{},
};

/// Standard-codec payloads are re-exported here so normal callers never need
/// to import `vk.raw`; Vulkan Video deliberately uses the Khronos StdVideo ABI.
pub const H264DecodePictureInfo = raw.StdVideoDecodeH264PictureInfo;
pub const H265DecodePictureInfo = raw.StdVideoDecodeH265PictureInfo;
pub const H264EncodePictureInfo = raw.StdVideoEncodeH264PictureInfo;
pub const H265EncodePictureInfo = raw.StdVideoEncodeH265PictureInfo;
pub const H264EncodeSlice = raw.VkVideoEncodeH264NaluSliceInfoKHR;
pub const H265EncodeSlice = raw.VkVideoEncodeH265NaluSliceSegmentInfoKHR;
pub const H264DecodeReferenceInfo = raw.StdVideoDecodeH264ReferenceInfo;
pub const H265DecodeReferenceInfo = raw.StdVideoDecodeH265ReferenceInfo;
pub const H264EncodeReferenceInfo = raw.StdVideoEncodeH264ReferenceInfo;
pub const H265EncodeReferenceInfo = raw.StdVideoEncodeH265ReferenceInfo;

pub const PictureResource = struct {
    view: *const images.View,
    coded_offset: types.Offset2D = .{ .x = 0, .y = 0 },
    coded_extent: types.Extent2D,
    base_array_layer: u32 = 0,

    pub fn toRaw(picture: PictureResource, device: DeviceHandle) core.Error!raw.VkVideoPictureResourceInfoKHR {
        if (picture.view._device_handle != device or picture.coded_extent.width == 0 or picture.coded_extent.height == 0) return error.InvalidHandle;
        return .{
            .sType = raw.VK_STRUCTURE_TYPE_VIDEO_PICTURE_RESOURCE_INFO_KHR,
            .codedOffset = picture.coded_offset.toRaw(),
            .codedExtent = picture.coded_extent.toRaw(),
            .baseArrayLayer = picture.base_array_layer,
            .imageViewBinding = try picture.view.rawHandle(),
        };
    }
};

pub const ReferenceCodec = union(enum) {
    h264_decode: *const H264DecodeReferenceInfo,
    h265_decode: *const H265DecodeReferenceInfo,
    h264_encode: *const H264EncodeReferenceInfo,
    h265_encode: *const H265EncodeReferenceInfo,
};

pub const ReferenceSlot = struct {
    index: i32,
    picture: ?PictureResource = null,
    codec: ReferenceCodec,
};

pub const reference_count_max = 32;

pub const ReferenceStorage = struct {
    pictures: [reference_count_max]raw.VkVideoPictureResourceInfoKHR = undefined,
    slots: [reference_count_max]raw.VkVideoReferenceSlotInfoKHR = undefined,
    h264_decode: [reference_count_max]raw.VkVideoDecodeH264DpbSlotInfoKHR = undefined,
    h265_decode: [reference_count_max]raw.VkVideoDecodeH265DpbSlotInfoKHR = undefined,
    h264_encode: [reference_count_max]raw.VkVideoEncodeH264DpbSlotInfoKHR = undefined,
    h265_encode: [reference_count_max]raw.VkVideoEncodeH265DpbSlotInfoKHR = undefined,

    pub fn build(storage: *ReferenceStorage, device: DeviceHandle, references: []const ReferenceSlot) core.Error![]const raw.VkVideoReferenceSlotInfoKHR {
        if (references.len > reference_count_max) return error.CountOverflow;
        for (references, 0..) |reference, index| {
            const picture_pointer: ?*const raw.VkVideoPictureResourceInfoKHR = if (reference.picture) |picture| blk: {
                storage.pictures[index] = try picture.toRaw(device);
                break :blk &storage.pictures[index];
            } else null;
            const codec_pointer: *const anyopaque = switch (reference.codec) {
                .h264_decode => |value| blk: {
                    storage.h264_decode[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_H264_DPB_SLOT_INFO_KHR, .pStdReferenceInfo = value };
                    break :blk &storage.h264_decode[index];
                },
                .h265_decode => |value| blk: {
                    storage.h265_decode[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_DECODE_H265_DPB_SLOT_INFO_KHR, .pStdReferenceInfo = value };
                    break :blk &storage.h265_decode[index];
                },
                .h264_encode => |value| blk: {
                    storage.h264_encode[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_H264_DPB_SLOT_INFO_KHR, .pStdReferenceInfo = value };
                    break :blk &storage.h264_encode[index];
                },
                .h265_encode => |value| blk: {
                    storage.h265_encode[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_VIDEO_ENCODE_H265_DPB_SLOT_INFO_KHR, .pStdReferenceInfo = value };
                    break :blk &storage.h265_encode[index];
                },
            };
            storage.slots[index] = .{
                .sType = raw.VK_STRUCTURE_TYPE_VIDEO_REFERENCE_SLOT_INFO_KHR,
                .pNext = codec_pointer,
                .slotIndex = reference.index,
                .pPictureResource = picture_pointer,
            };
        }
        return storage.slots[0..references.len];
    }
};

pub const Control = struct {
    reset: bool = false,
    encode_rate_control: bool = false,
    encode_quality_level: bool = false,

    pub fn flags(value: Control) raw.VkVideoCodingControlFlagsKHR {
        var result: raw.VkVideoCodingControlFlagsKHR = 0;
        if (value.reset) result |= raw.VK_VIDEO_CODING_CONTROL_RESET_BIT_KHR;
        if (value.encode_rate_control) result |= raw.VK_VIDEO_CODING_CONTROL_ENCODE_RATE_CONTROL_BIT_KHR;
        if (value.encode_quality_level) result |= raw.VK_VIDEO_CODING_CONTROL_ENCODE_QUALITY_LEVEL_BIT_KHR;
        return result;
    }
};

pub const DecodeCodec = union(enum) {
    h264: struct {
        picture: *const H264DecodePictureInfo,
        slice_offsets: []const u32,
    },
    h265: struct {
        picture: *const H265DecodePictureInfo,
        slice_segment_offsets: []const u32,
    },
};

pub const DecodeOptions = struct {
    bitstream: *const buffers.Buffer,
    offset: core.DeviceOffset = .zero,
    range: core.DeviceSize,
    destination: PictureResource,
    setup_reference: ?ReferenceSlot = null,
    references: []const ReferenceSlot = &.{},
    codec: DecodeCodec,
};

pub const EncodeCodec = union(enum) {
    h264: struct {
        picture: *const H264EncodePictureInfo,
        slices: []const H264EncodeSlice,
        generate_prefix_nalu: bool = false,
    },
    h265: struct {
        picture: *const H265EncodePictureInfo,
        slices: []const H265EncodeSlice,
    },
};

pub const EncodeOptions = struct {
    bitstream: *const buffers.Buffer,
    offset: core.DeviceOffset = .zero,
    range: core.DeviceSize,
    source: PictureResource,
    setup_reference: ?ReferenceSlot = null,
    references: []const ReferenceSlot = &.{},
    preceding_externally_encoded_bytes: u32 = 0,
    codec: EncodeCodec,
};

pub fn referencesMatch(profile: Profile, references: []const ReferenceSlot) bool {
    for (references) |reference| {
        const matches = switch (profile.codec) {
            .decode_h264 => reference.codec == .h264_decode,
            .decode_h265 => reference.codec == .h265_decode,
            .encode_h264 => reference.codec == .h264_encode,
            .encode_h265 => reference.codec == .h265_encode,
            .decode_av1, .decode_vp9, .encode_av1 => false,
        };
        if (!matches) return false;
    }
    return true;
}

pub fn decodeMatches(profile: Profile, codec: DecodeCodec) bool {
    return switch (profile.codec) {
        .decode_h264 => codec == .h264,
        .decode_h265 => codec == .h265,
        else => false,
    };
}

pub fn encodeMatches(profile: Profile, codec: EncodeCodec) bool {
    return switch (profile.codec) {
        .encode_h264 => codec == .h264,
        .encode_h265 => codec == .h265,
        else => false,
    };
}

fn parameterLimitsMatch(profile: Profile, limits: ParameterLimits) bool {
    return switch (profile.codec) {
        .decode_h264 => limits == .decode_h264,
        .decode_h265 => limits == .decode_h265,
        .encode_h264 => limits == .encode_h264,
        .encode_h265 => limits == .encode_h265,
        .decode_av1, .decode_vp9, .encode_av1 => false,
    };
}

fn parameterUpdateMatches(profile: Profile, update: ParameterUpdate) bool {
    return switch (profile.codec) {
        .decode_h264, .encode_h264 => update == .h264,
        .decode_h265, .encode_h265 => update == .h265,
        .decode_av1, .decode_vp9, .encode_av1 => false,
    };
}

fn fillH264Add(target: anytype, value: H264ParameterUpdate) void {
    target.stdSPSCount = value.sequence_parameter_set_count;
    target.pStdSPSs = value.sequence_parameter_sets;
    target.stdPPSCount = value.picture_parameter_set_count;
    target.pStdPPSs = value.picture_parameter_sets;
}

fn fillH265Add(target: anytype, value: H265ParameterUpdate) void {
    target.stdVPSCount = value.video_parameter_set_count;
    target.pStdVPSs = value.video_parameter_sets;
    target.stdSPSCount = value.sequence_parameter_set_count;
    target.pStdSPSs = value.sequence_parameter_sets;
    target.stdPPSCount = value.picture_parameter_set_count;
    target.pStdPPSs = value.picture_parameter_sets;
}

var test_profile_operation: raw.VkVideoCodecOperationFlagBitsKHR = 0;
var test_memory_binding_count: u32 = 0;

fn testCapabilities(
    _: raw.VkPhysicalDevice,
    profile: [*c]const raw.VkVideoProfileInfoKHR,
    output: [*c]raw.VkVideoCapabilitiesKHR,
) callconv(.c) raw.VkResult {
    test_profile_operation = profile[0].videoCodecOperation;
    output[0].minBitstreamBufferOffsetAlignment = 256;
    output[0].minBitstreamBufferSizeAlignment = 4096;
    output[0].pictureAccessGranularity = .{ .width = 16, .height = 16 };
    output[0].minCodedExtent = .{ .width = 64, .height = 64 };
    output[0].maxCodedExtent = .{ .width = 4096, .height = 2160 };
    output[0].maxDpbSlots = 8;
    output[0].maxActiveReferencePictures = 4;
    output[0].stdHeaderVersion.extensionName[0] = 'v';
    output[0].stdHeaderVersion.specVersion = 7;
    return raw.VK_SUCCESS;
}

fn testBindMemory(
    _: raw.VkDevice,
    _: raw.VkVideoSessionKHR,
    count: u32,
    values: [*c]const raw.VkBindVideoSessionMemoryInfoKHR,
) callconv(.c) raw.VkResult {
    test_memory_binding_count = count;
    if (count != 1 or values[0].memoryBindIndex != 3 or values[0].memoryOffset != 128 or values[0].memorySize != 512) return raw.VK_ERROR_UNKNOWN;
    return raw.VK_SUCCESS;
}

fn testUpdateParameters(
    _: raw.VkDevice,
    _: raw.VkVideoSessionParametersKHR,
    _: [*c]const raw.VkVideoSessionParametersUpdateInfoKHR,
) callconv(.c) raw.VkResult {
    return raw.VK_SUCCESS;
}

test "codec-specific parameter limits reject incompatible profiles" {
    std.testing.refAllDecls(@This());
    const profile: Profile = .{ .codec = .{ .decode_h264 = .{} } };
    try std.testing.expect(parameterLimitsMatch(profile, .{ .decode_h264 = .{ .max_sps = 4, .max_pps = 8 } }));
    try std.testing.expect(!parameterLimitsMatch(profile, .{ .encode_h264 = .{ .max_sps = 4, .max_pps = 8 } }));
    const unsupported: Profile = .{ .codec = .{ .decode_av1 = .{} } };
    try std.testing.expect(!parameterLimitsMatch(unsupported, .{ .decode_h264 = .{ .max_sps = 1, .max_pps = 1 } }));
}

test "capability queries build the codec profile chain" {
    test_profile_operation = 0;
    const context: QueryContext = .{
        ._physical_device = @ptrFromInt(0x1000),
        ._capabilities = testCapabilities,
        ._formats = null,
        ._quality = null,
    };
    const capabilities_value = try context.capabilities(.{ .codec = .{ .decode_h265 = .main_10 } });
    try std.testing.expectEqual(@as(raw.VkVideoCodecOperationFlagBitsKHR, raw.VK_VIDEO_CODEC_OPERATION_DECODE_H265_BIT_KHR), test_profile_operation);
    try std.testing.expectEqual(@as(u64, 4096), capabilities_value.min_bitstream_size_alignment.bytes());
    try std.testing.expectEqual(@as(u32, 8), capabilities_value.max_dpb_slots);
    try std.testing.expectEqual(@as(u32, 7), capabilities_value.standard_header_spec_version);
}

test "session memory binding validates and forwards owned allocations" {
    const device_handle: DeviceHandle = @ptrFromInt(0x1000);
    var session_raw: raw.VkVideoSessionKHR = @ptrFromInt(0x2000);
    var memory_raw: raw.VkDeviceMemory = @ptrFromInt(0x3000);
    var session: Session = undefined;
    session._handle = session_raw.?;
    session._owner = try .init(&session_raw);
    session._device_handle = device_handle;
    session._device_state = try .init();
    session.bind_memory = testBindMemory;
    var allocation: memory.Allocation = undefined;
    allocation._handle = memory_raw.?;
    allocation._owner = try .init(&memory_raw);
    allocation._device_handle = device_handle;
    allocation._device_state = null;
    allocation.size = .fromBytes(1024);
    test_memory_binding_count = 0;
    try session.bindMemory(&.{.{
        .binding_index = 3,
        .allocation = &allocation,
        .offset = .fromBytes(128),
        .size = .fromBytes(512),
    }});
    try std.testing.expectEqual(@as(u32, 1), test_memory_binding_count);
}

test "parameter updates reject codecs without a compatible typed payload" {
    var parameters: Parameters = undefined;
    parameters.profile = .{ .codec = .{ .decode_av1 = .{} } };
    parameters.update_parameters = testUpdateParameters;
    try std.testing.expectError(error.UnsupportedCodec, parameters.update(1, .{ .h264 = .{} }));
}
