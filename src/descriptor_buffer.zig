//! Typed `VK_EXT_descriptor_buffer` layout, encoding, binding, and capture support.

const std = @import("std");
const raw = @import("vulkan_raw");
const types = @import("vulkan_types");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const buffers = @import("buffer.zig");
const commands = @import("command_buffer.zig");
const descriptors = @import("descriptor.zig");
const images = @import("image.zig");
const pipelines = @import("pipeline.zig");
const ray_tracing = @import("ray_tracing.zig");
const samplers = @import("sampler.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const binding_count_max = 32;

pub const extension = command.DeviceExtension.ext_descriptor_buffer;
pub const Features = types.extension_features.DescriptorBufferFeaturesEXT;

pub const Properties = struct {
    offset_alignment: core.DeviceSize,
    max_bindings: u32,
    max_resource_bindings: u32,
    max_sampler_bindings: u32,
    buffer_capture_size: usize,
    image_capture_size: usize,
    image_view_capture_size: usize,
    sampler_capture_size: usize,
    acceleration_structure_capture_size: usize,
    sampler_descriptor_size: usize,
    combined_image_sampler_descriptor_size: usize,
    sampled_image_descriptor_size: usize,
    storage_image_descriptor_size: usize,
    uniform_texel_buffer_descriptor_size: usize,
    storage_texel_buffer_descriptor_size: usize,
    uniform_buffer_descriptor_size: usize,
    storage_buffer_descriptor_size: usize,
    input_attachment_descriptor_size: usize,
    acceleration_structure_descriptor_size: usize,

    pub fn fromRaw(value: raw.VkPhysicalDeviceDescriptorBufferPropertiesEXT) Properties {
        return .{
            .offset_alignment = .fromBytes(value.descriptorBufferOffsetAlignment),
            .max_bindings = value.maxDescriptorBufferBindings,
            .max_resource_bindings = value.maxResourceDescriptorBufferBindings,
            .max_sampler_bindings = value.maxSamplerDescriptorBufferBindings,
            .buffer_capture_size = value.bufferCaptureReplayDescriptorDataSize,
            .image_capture_size = value.imageCaptureReplayDescriptorDataSize,
            .image_view_capture_size = value.imageViewCaptureReplayDescriptorDataSize,
            .sampler_capture_size = value.samplerCaptureReplayDescriptorDataSize,
            .acceleration_structure_capture_size = value.accelerationStructureCaptureReplayDescriptorDataSize,
            .sampler_descriptor_size = value.samplerDescriptorSize,
            .combined_image_sampler_descriptor_size = value.combinedImageSamplerDescriptorSize,
            .sampled_image_descriptor_size = value.sampledImageDescriptorSize,
            .storage_image_descriptor_size = value.storageImageDescriptorSize,
            .uniform_texel_buffer_descriptor_size = value.uniformTexelBufferDescriptorSize,
            .storage_texel_buffer_descriptor_size = value.storageTexelBufferDescriptorSize,
            .uniform_buffer_descriptor_size = value.uniformBufferDescriptorSize,
            .storage_buffer_descriptor_size = value.storageBufferDescriptorSize,
            .input_attachment_descriptor_size = value.inputAttachmentDescriptorSize,
            .acceleration_structure_descriptor_size = value.accelerationStructureDescriptorSize,
        };
    }

    pub fn descriptorSize(properties: Properties, type_: descriptors.Type) ?usize {
        return switch (type_) {
            .sampler => properties.sampler_descriptor_size,
            .combined_image_sampler => properties.combined_image_sampler_descriptor_size,
            .sampled_image => properties.sampled_image_descriptor_size,
            .storage_image => properties.storage_image_descriptor_size,
            .uniform_texel_buffer => properties.uniform_texel_buffer_descriptor_size,
            .storage_texel_buffer => properties.storage_texel_buffer_descriptor_size,
            .uniform_buffer => properties.uniform_buffer_descriptor_size,
            .storage_buffer => properties.storage_buffer_descriptor_size,
            .input_attachment => properties.input_attachment_descriptor_size,
            .acceleration_structure => properties.acceleration_structure_descriptor_size,
            else => null,
        };
    }
};

pub const Address = struct {
    address: buffers.DeviceAddress,
    range: core.DeviceSize,
    format: ?types.Format = null,

    fn toRaw(value: Address) core.Error!raw.VkDescriptorAddressInfoEXT {
        if (value.address.toRaw() == 0 or value.range.bytes() == 0) return error.InvalidOptions;
        return .{ .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_ADDRESS_INFO_EXT, .address = value.address.toRaw(), .range = value.range.bytes(), .format = if (value.format) |format| format.toRaw() else raw.VK_FORMAT_UNDEFINED };
    }
};

pub const Image = struct {
    sampler: ?*const samplers.Sampler = null,
    view: ?*const images.View = null,
    layout: types.ImageLayout,
};

/// The tag selects the Vulkan union member and its descriptor type together.
pub const Data = union(enum) {
    sampler: *const samplers.Sampler,
    combined_image_sampler: Image,
    sampled_image: Image,
    storage_image: Image,
    input_attachment: Image,
    uniform_texel_buffer: Address,
    storage_texel_buffer: Address,
    uniform_buffer: Address,
    storage_buffer: Address,
    acceleration_structure: buffers.DeviceAddress,

    pub fn descriptorType(value: Data) descriptors.Type {
        return switch (value) {
            .sampler => .sampler,
            .combined_image_sampler => .combined_image_sampler,
            .sampled_image => .sampled_image,
            .storage_image => .storage_image,
            .input_attachment => .input_attachment,
            .uniform_texel_buffer => .uniform_texel_buffer,
            .storage_texel_buffer => .storage_texel_buffer,
            .uniform_buffer => .uniform_buffer,
            .storage_buffer => .storage_buffer,
            .acceleration_structure => .acceleration_structure,
        };
    }
};

pub const Binding = struct {
    address: buffers.DeviceAddress,
    usage: types.BufferUsageFlags,
};

pub const SetOffset = struct { buffer_index: u32, offset: core.DeviceOffset };

pub const Context = struct {
    _device: DeviceHandle,
    _state: *const core.DeviceState,
    properties: Properties,
    _layout_size: ?CommandFunction(raw.PFN_vkGetDescriptorSetLayoutSizeEXT),
    _binding_offset: ?CommandFunction(raw.PFN_vkGetDescriptorSetLayoutBindingOffsetEXT),
    _get: ?CommandFunction(raw.PFN_vkGetDescriptorEXT),
    _bind: ?CommandFunction(raw.PFN_vkCmdBindDescriptorBuffersEXT),
    _set_offsets: ?CommandFunction(raw.PFN_vkCmdSetDescriptorBufferOffsetsEXT),
    _bind_samplers: ?CommandFunction(raw.PFN_vkCmdBindDescriptorBufferEmbeddedSamplersEXT),
    _capture_buffer: ?CommandFunction(raw.PFN_vkGetBufferOpaqueCaptureDescriptorDataEXT),
    _capture_image: ?CommandFunction(raw.PFN_vkGetImageOpaqueCaptureDescriptorDataEXT),
    _capture_view: ?CommandFunction(raw.PFN_vkGetImageViewOpaqueCaptureDescriptorDataEXT),
    _capture_sampler: ?CommandFunction(raw.PFN_vkGetSamplerOpaqueCaptureDescriptorDataEXT),
    _capture_structure: ?CommandFunction(raw.PFN_vkGetAccelerationStructureOpaqueCaptureDescriptorDataEXT),

    pub fn layoutSize(context: Context, layout: *const descriptors.SetLayout) core.Error!core.DeviceSize {
        const get = context._layout_size orelse return error.MissingCommand;
        if (layout._device_handle != context._device) return error.InvalidOptions;
        var size: raw.VkDeviceSize = 0;
        get(context._device, try layout.rawHandle(), &size);
        return .fromBytes(size);
    }

    pub fn bindingOffset(context: Context, layout: *const descriptors.SetLayout, binding: u32) core.Error!core.DeviceOffset {
        const get = context._binding_offset orelse return error.MissingCommand;
        if (layout._device_handle != context._device) return error.InvalidOptions;
        var offset: raw.VkDeviceSize = 0;
        get(context._device, try layout.rawHandle(), binding, &offset);
        return .fromBytes(offset);
    }

    pub fn encode(context: Context, data: Data, destination: []u8) core.Error!void {
        const get = context._get orelse return error.MissingCommand;
        const type_ = data.descriptorType();
        const required = context.properties.descriptorSize(type_) orelse return error.UnsupportedOperation;
        if (required == 0) return error.InvalidProperties;
        if (destination.len != required) return error.InvalidOptions;
        var sampler_handle: raw.VkSampler = null;
        var image_info: raw.VkDescriptorImageInfo = .{};
        var address_info: raw.VkDescriptorAddressInfoEXT = .{};
        var raw_data: raw.VkDescriptorDataEXT = undefined;
        switch (data) {
            .sampler => |sampler| {
                if (sampler._device_handle != context._device) return error.InvalidOptions;
                sampler_handle = try sampler.rawHandle();
                raw_data = .{ .pSampler = &sampler_handle };
            },
            .combined_image_sampler, .sampled_image, .storage_image, .input_attachment => |value| {
                if (value.sampler) |sampler| {
                    if (sampler._device_handle != context._device) return error.InvalidOptions;
                    image_info.sampler = try sampler.rawHandle();
                }
                if (value.view) |view| {
                    if (view._device_handle != context._device) return error.InvalidOptions;
                    image_info.imageView = try view.rawHandle();
                }
                image_info.imageLayout = value.layout.toRaw();
                raw_data = switch (data) {
                    .combined_image_sampler => .{ .pCombinedImageSampler = &image_info },
                    .sampled_image => .{ .pSampledImage = &image_info },
                    .storage_image => .{ .pStorageImage = &image_info },
                    .input_attachment => .{ .pInputAttachmentImage = &image_info },
                    else => unreachable,
                };
            },
            .uniform_texel_buffer, .storage_texel_buffer, .uniform_buffer, .storage_buffer => |value| {
                address_info = try value.toRaw();
                raw_data = switch (data) {
                    .uniform_texel_buffer => .{ .pUniformTexelBuffer = &address_info },
                    .storage_texel_buffer => .{ .pStorageTexelBuffer = &address_info },
                    .uniform_buffer => .{ .pUniformBuffer = &address_info },
                    .storage_buffer => .{ .pStorageBuffer = &address_info },
                    else => unreachable,
                };
            },
            .acceleration_structure => |address| {
                if (address.toRaw() == 0) return error.InvalidOptions;
                raw_data = .{ .accelerationStructure = address.toRaw() };
            },
        }
        const info: raw.VkDescriptorGetInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_GET_INFO_EXT, .type = type_.toRaw(), .data = raw_data };
        get(context._device, &info, destination.len, destination.ptr);
    }

    pub fn bind(context: Context, command_buffer: *commands.Buffer, bindings: []const Binding) core.Error!void {
        const bind_command = context._bind orelse return error.MissingCommand;
        if (command_buffer._device_handle != context._device or command_buffer.state != .recording or bindings.len == 0 or bindings.len > binding_count_max or bindings.len > context.properties.max_bindings) return error.InvalidOptions;
        var raw_bindings: [binding_count_max]raw.VkDescriptorBufferBindingInfoEXT = undefined;
        for (bindings, 0..) |binding, index| {
            if (binding.address.toRaw() == 0) return error.InvalidOptions;
            raw_bindings[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_DESCRIPTOR_BUFFER_BINDING_INFO_EXT, .address = binding.address.toRaw(), .usage = binding.usage.toRaw() };
        }
        bind_command(try command_buffer.rawHandle(), @intCast(bindings.len), raw_bindings[0..bindings.len].ptr);
    }

    pub fn setOffsets(context: Context, command_buffer: *commands.Buffer, bind_point: pipelines.BindPoint, layout: *const pipelines.Layout, first_set: u32, offsets: []const SetOffset) core.Error!void {
        const set = context._set_offsets orelse return error.MissingCommand;
        if (command_buffer._device_handle != context._device or layout._device_handle != context._device or command_buffer.state != .recording or offsets.len == 0 or offsets.len > binding_count_max or context.properties.offset_alignment.bytes() == 0) return error.InvalidOptions;
        var indices: [binding_count_max]u32 = undefined;
        var raw_offsets: [binding_count_max]raw.VkDeviceSize = undefined;
        for (offsets, 0..) |offset, index| {
            if (offset.buffer_index >= context.properties.max_bindings or offset.offset.bytes() % context.properties.offset_alignment.bytes() != 0) return error.InvalidOptions;
            indices[index] = offset.buffer_index;
            raw_offsets[index] = offset.offset.bytes();
        }
        set(try command_buffer.rawHandle(), bind_point.toRaw(), try layout.rawHandle(), first_set, @intCast(offsets.len), indices[0..offsets.len].ptr, raw_offsets[0..offsets.len].ptr);
    }

    pub fn bindEmbeddedSamplers(context: Context, command_buffer: *commands.Buffer, bind_point: pipelines.BindPoint, layout: *const pipelines.Layout, set_index: u32) core.Error!void {
        const bind_command = context._bind_samplers orelse return error.MissingCommand;
        if (command_buffer._device_handle != context._device or layout._device_handle != context._device or command_buffer.state != .recording) return error.InvalidOptions;
        bind_command(try command_buffer.rawHandle(), bind_point.toRaw(), try layout.rawHandle(), set_index);
    }

    pub fn captureBuffer(context: Context, buffer: *const buffers.Buffer, destination: []u8) core.Error!void {
        const get = context._capture_buffer orelse return error.MissingCommand;
        if (buffer._device_handle != context._device or destination.len != context.properties.buffer_capture_size) return error.InvalidOptions;
        const info: raw.VkBufferCaptureDescriptorDataInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_BUFFER_CAPTURE_DESCRIPTOR_DATA_INFO_EXT, .buffer = try buffer.rawHandle() };
        try core.checkSuccess(get(context._device, &info, destination.ptr));
    }

    pub fn captureImage(context: Context, image: *const images.Image, destination: []u8) core.Error!void {
        const get = context._capture_image orelse return error.MissingCommand;
        if (image._device_handle != context._device or destination.len != context.properties.image_capture_size) return error.InvalidOptions;
        const info: raw.VkImageCaptureDescriptorDataInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_IMAGE_CAPTURE_DESCRIPTOR_DATA_INFO_EXT, .image = try image.rawHandle() };
        try core.checkSuccess(get(context._device, &info, destination.ptr));
    }

    pub fn captureView(context: Context, view: *const images.View, destination: []u8) core.Error!void {
        const get = context._capture_view orelse return error.MissingCommand;
        if (view._device_handle != context._device or destination.len != context.properties.image_view_capture_size) return error.InvalidOptions;
        const info: raw.VkImageViewCaptureDescriptorDataInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_IMAGE_VIEW_CAPTURE_DESCRIPTOR_DATA_INFO_EXT, .imageView = try view.rawHandle() };
        try core.checkSuccess(get(context._device, &info, destination.ptr));
    }

    pub fn captureSampler(context: Context, sampler: *const samplers.Sampler, destination: []u8) core.Error!void {
        const get = context._capture_sampler orelse return error.MissingCommand;
        if (sampler._device_handle != context._device or destination.len != context.properties.sampler_capture_size) return error.InvalidOptions;
        const info: raw.VkSamplerCaptureDescriptorDataInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_SAMPLER_CAPTURE_DESCRIPTOR_DATA_INFO_EXT, .sampler = try sampler.rawHandle() };
        try core.checkSuccess(get(context._device, &info, destination.ptr));
    }

    pub fn captureAccelerationStructure(context: Context, structure: *const ray_tracing.Structure, destination: []u8) core.Error!void {
        const get = context._capture_structure orelse return error.MissingCommand;
        if (structure._device != context._device or destination.len != context.properties.acceleration_structure_capture_size) return error.InvalidOptions;
        const info: raw.VkAccelerationStructureCaptureDescriptorDataInfoEXT = .{ .sType = raw.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_CAPTURE_DESCRIPTOR_DATA_INFO_EXT, .accelerationStructure = try structure.rawHandle() };
        try core.checkSuccess(get(context._device, &info, destination.ptr));
    }
};

test "descriptor data tag fixes its descriptor type" {
    const data: Data = .{ .acceleration_structure = @enumFromInt(0x1000) };
    try std.testing.expectEqual(descriptors.Type.acceleration_structure, data.descriptorType());
    try std.testing.expect(extension == command.DeviceExtension.ext_descriptor_buffer);
}

fn testCaptureBuffer(_: raw.VkDevice, _: [*c]const raw.VkBufferCaptureDescriptorDataInfoEXT, destination: ?*anyopaque) callconv(.c) raw.VkResult {
    const bytes: *[4]u8 = @ptrCast(@alignCast(destination.?));
    bytes.* = .{ 1, 2, 3, 4 };
    return raw.VK_SUCCESS;
}

test "opaque descriptor capture validates the property-sized destination" {
    const device: DeviceHandle = @ptrFromInt(0x1000);
    var handle: raw.VkBuffer = @ptrFromInt(0x2000);
    var buffer: buffers.Buffer = .{ ._handle = handle, ._owner = try .init(&handle), ._device_handle = device, .size = .fromBytes(64), .allocation_callbacks = null, .dispatch = undefined };
    defer _ = buffer._owner.release(&buffer) catch false;
    var context: Context = undefined;
    context._device = device;
    context.properties = std.mem.zeroes(Properties);
    context.properties.buffer_capture_size = 4;
    context._capture_buffer = testCaptureBuffer;
    var destination: [4]u8 = undefined;
    try context.captureBuffer(&buffer, &destination);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, &destination);
    try std.testing.expectError(error.InvalidOptions, context.captureBuffer(&buffer, destination[0..3]));
}

test "unavailable descriptor command reports MissingCommand" {
    var context: Context = undefined;
    context._get = null;
    try std.testing.expectError(error.MissingCommand, context.encode(undefined, &.{}));
    context._layout_size = null;
    try std.testing.expectError(error.MissingCommand, context.layoutSize(undefined));
    context._binding_offset = null;
    try std.testing.expectError(error.MissingCommand, context.bindingOffset(undefined, 0));
    context._bind = null;
    try std.testing.expectError(error.MissingCommand, context.bind(undefined, &.{}));
    context._set_offsets = null;
    try std.testing.expectError(error.MissingCommand, context.setOffsets(undefined, .compute, undefined, 0, &.{}));
    context._bind_samplers = null;
    try std.testing.expectError(error.MissingCommand, context.bindEmbeddedSamplers(undefined, .compute, undefined, 0));
    context._capture_image = null;
    try std.testing.expectError(error.MissingCommand, context.captureImage(undefined, &.{}));
    context._capture_view = null;
    try std.testing.expectError(error.MissingCommand, context.captureView(undefined, &.{}));
    context._capture_sampler = null;
    try std.testing.expectError(error.MissingCommand, context.captureSampler(undefined, &.{}));
    context._capture_structure = null;
    try std.testing.expectError(error.MissingCommand, context.captureAccelerationStructure(undefined, &.{}));
}
