const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");
const memory = @import("memory.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const SwapchainHandle = core.NonNullHandle(raw.VkSwapchainKHR);
const ImageHandle = core.NonNullHandle(raw.VkImage);
const ImageViewHandle = core.NonNullHandle(raw.VkImageView);
const queue_family_count_max = 64;
pub const sparse_requirement_count_max = 64;
pub const host_copy_region_count_max = 64;

pub const Subresource = struct {
    aspect: types.ImageAspectBit,
    mip_level: u32 = 0,
    array_layer: u32 = 0,

    fn toRaw(value: Subresource) raw.VkImageSubresource {
        return .{ .aspectMask = @intCast(value.aspect.toRaw()), .mipLevel = value.mip_level, .arrayLayer = value.array_layer };
    }
};

pub const SubresourceLayers = struct {
    aspects: types.ImageAspectFlags,
    mip_level: u32 = 0,
    base_array_layer: u32 = 0,
    layer_count: u32 = 1,

    pub fn toRaw(value: SubresourceLayers) raw.VkImageSubresourceLayers {
        return .{ .aspectMask = value.aspects.toRaw(), .mipLevel = value.mip_level, .baseArrayLayer = value.base_array_layer, .layerCount = value.layer_count };
    }
};

pub const SubresourceLayout = struct {
    offset: core.DeviceOffset,
    size: core.DeviceSize,
    row_pitch: core.DeviceSize,
    array_pitch: core.DeviceSize,
    depth_pitch: core.DeviceSize,

    fn fromRaw(value: raw.VkSubresourceLayout) SubresourceLayout {
        return .{ .offset = .fromBytes(value.offset), .size = .fromBytes(value.size), .row_pitch = .fromBytes(value.rowPitch), .array_pitch = .fromBytes(value.arrayPitch), .depth_pitch = .fromBytes(value.depthPitch) };
    }
};

pub const SparseMemoryRequirements = struct {
    aspects: types.ImageAspectFlags,
    granularity: types.Extent3D,
    flags: types.SparseImageFormatFlags,
    mip_tail_first_lod: u32,
    mip_tail_size: core.DeviceSize,
    mip_tail_offset: core.DeviceOffset,
    mip_tail_stride: core.DeviceSize,

    fn fromRaw(value: raw.VkSparseImageMemoryRequirements) SparseMemoryRequirements {
        return .{
            .aspects = .fromRaw(value.formatProperties.aspectMask),
            .granularity = .fromRaw(value.formatProperties.imageGranularity),
            .flags = .fromRaw(value.formatProperties.flags),
            .mip_tail_first_lod = value.imageMipTailFirstLod,
            .mip_tail_size = .fromBytes(value.imageMipTailSize),
            .mip_tail_offset = .fromBytes(value.imageMipTailOffset),
            .mip_tail_stride = .fromBytes(value.imageMipTailStride),
        };
    }
};

pub const HostMemoryRegion = struct {
    bytes: []const u8,
    row_length: u32 = 0,
    image_height: u32 = 0,
    subresource: SubresourceLayers,
    offset: types.Offset3D = .{ .x = 0, .y = 0, .z = 0 },
    extent: types.Extent3D,
};

pub const HostReadRegion = struct {
    bytes: []u8,
    row_length: u32 = 0,
    image_height: u32 = 0,
    subresource: SubresourceLayers,
    offset: types.Offset3D = .{ .x = 0, .y = 0, .z = 0 },
    extent: types.Extent3D,
};

pub const HostImageCopyRegion = struct {
    source_subresource: SubresourceLayers,
    source_offset: types.Offset3D = .{ .x = 0, .y = 0, .z = 0 },
    destination_subresource: SubresourceLayers,
    destination_offset: types.Offset3D = .{ .x = 0, .y = 0, .z = 0 },
    extent: types.Extent3D,
};

pub const Options = struct {
    image_type: types.ImageType = ._2d,
    format: types.Format,
    extent: types.Extent3D,
    mip_levels: u32 = 1,
    array_layers: u32 = 1,
    samples: types.SampleCountBit = ._1,
    tiling: types.ImageTiling = .optimal,
    usage: types.ImageUsageFlags,
    flags: types.ImageCreateFlags = .empty,
    initial_layout: types.ImageLayout = .undefined_,
    queue_family_indices: []const core.QueueFamilyIndex = &.{},
};

pub const MemoryRequirements = memory.Requirements;

pub const Dispatch = struct {
    create_image: CommandFunction(raw.PFN_vkCreateImage),
    destroy_image: CommandFunction(raw.PFN_vkDestroyImage),
    get_image_memory_requirements: CommandFunction(raw.PFN_vkGetImageMemoryRequirements),
    get_image_memory_requirements2: ?CommandFunction(raw.PFN_vkGetImageMemoryRequirements2),
    bind_image_memory: CommandFunction(raw.PFN_vkBindImageMemory),
    bind_image_memory2: ?CommandFunction(raw.PFN_vkBindImageMemory2),
    get_subresource_layout: CommandFunction(raw.PFN_vkGetImageSubresourceLayout),
    get_sparse_requirements: CommandFunction(raw.PFN_vkGetImageSparseMemoryRequirements),
    get_sparse_requirements2: ?CommandFunction(raw.PFN_vkGetImageSparseMemoryRequirements2),
    copy_memory_to_image: ?CommandFunction(raw.PFN_vkCopyMemoryToImage),
    copy_image_to_memory: ?CommandFunction(raw.PFN_vkCopyImageToMemory),
    copy_image_to_image: ?CommandFunction(raw.PFN_vkCopyImageToImage),
    transition_layout: ?CommandFunction(raw.PFN_vkTransitionImageLayout),
};

pub const Image = struct {
    _handle: ?ImageHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    format: types.Format,
    extent: types.Extent3D,
    samples: types.SampleCountBit,
    mip_levels: u32,
    array_layers: u32,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,
    bound_memory: ?memory.Binding = null,

    pub fn deinit(image: *Image) void {
        if (!(image._owner.release(image) catch return)) return;
        const handle = image._handle orelse return;
        image.dispatch.destroy_image(image._device_handle, handle, image.allocation_callbacks);
        image._handle = null;
    }

    pub fn rawHandle(image: *const Image) core.Error!raw.VkImage {
        try image._owner.validate(image);
        if (image._device_state) |*state| try state.ensureDispatchAllowed();
        return image._handle orelse error.InactiveObject;
    }

    pub fn memoryRequirements(image: *const Image) core.Error!MemoryRequirements {
        const handle = try image.rawHandle();
        if (image.dispatch.get_image_memory_requirements2) |get_requirements| {
            const info: raw.VkImageMemoryRequirementsInfo2 = .{
                .sType = raw.VK_STRUCTURE_TYPE_IMAGE_MEMORY_REQUIREMENTS_INFO_2,
                .image = handle,
            };
            var output: raw.VkMemoryRequirements2 = .{
                .sType = raw.VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2,
            };
            var dedicated: raw.VkMemoryDedicatedRequirements = .{
                .sType = raw.VK_STRUCTURE_TYPE_MEMORY_DEDICATED_REQUIREMENTS,
            };
            output.pNext = &dedicated;
            get_requirements(image._device_handle, &info, &output);
            var requirements = MemoryRequirements.fromRaw(output.memoryRequirements);
            requirements.prefers_dedicated_allocation = dedicated.prefersDedicatedAllocation != raw.VK_FALSE;
            requirements.requires_dedicated_allocation = dedicated.requiresDedicatedAllocation != raw.VK_FALSE;
            return requirements;
        }
        var output: raw.VkMemoryRequirements = .{};
        image.dispatch.get_image_memory_requirements(image._device_handle, handle, &output);
        return .fromRaw(output);
    }

    pub fn subresourceLayout(image: *const Image, subresource: Subresource) core.Error!SubresourceLayout {
        if (subresource.mip_level >= image.mip_levels or subresource.array_layer >= image.array_layers) return error.InvalidOptions;
        var layout: raw.VkSubresourceLayout = .{};
        const raw_subresource = subresource.toRaw();
        image.dispatch.get_subresource_layout(image._device_handle, try image.rawHandle(), &raw_subresource, &layout);
        return .fromRaw(layout);
    }

    pub fn sparseMemoryRequirements(image: *const Image, storage: []SparseMemoryRequirements) core.Error![]SparseMemoryRequirements {
        const handle = try image.rawHandle();
        var count: u32 = 0;
        if (image.dispatch.get_sparse_requirements2) |get_requirements| {
            const info: raw.VkImageSparseMemoryRequirementsInfo2 = .{ .sType = raw.VK_STRUCTURE_TYPE_IMAGE_SPARSE_MEMORY_REQUIREMENTS_INFO_2, .image = handle };
            get_requirements(image._device_handle, &info, &count, null);
            if (count > sparse_requirement_count_max or count > storage.len) return error.BufferTooSmall;
            var values: [sparse_requirement_count_max]raw.VkSparseImageMemoryRequirements2 = undefined;
            for (values[0..count]) |*value| value.* = .{ .sType = raw.VK_STRUCTURE_TYPE_SPARSE_IMAGE_MEMORY_REQUIREMENTS_2 };
            get_requirements(image._device_handle, &info, &count, values[0..count].ptr);
            if (count > storage.len or count > values.len) return error.EnumerationUnstable;
            for (values[0..count], 0..) |value, index| storage[index] = .fromRaw(value.memoryRequirements);
            return storage[0..count];
        }
        image.dispatch.get_sparse_requirements(image._device_handle, handle, &count, null);
        if (count > sparse_requirement_count_max or count > storage.len) return error.BufferTooSmall;
        var values: [sparse_requirement_count_max]raw.VkSparseImageMemoryRequirements = undefined;
        image.dispatch.get_sparse_requirements(image._device_handle, handle, &count, values[0..count].ptr);
        if (count > storage.len or count > values.len) return error.EnumerationUnstable;
        for (values[0..count], 0..) |value, index| storage[index] = .fromRaw(value);
        return storage[0..count];
    }

    pub fn copyFromHost(image: *const Image, layout: types.ImageLayout, regions: []const HostMemoryRegion) core.Error!void {
        const copy = image.dispatch.copy_memory_to_image orelse return error.MissingCommand;
        if (regions.len == 0 or regions.len > host_copy_region_count_max) return error.InvalidOptions;
        var raw_regions: [host_copy_region_count_max]raw.VkMemoryToImageCopy = undefined;
        for (regions, 0..) |region, index| {
            if (region.bytes.len == 0 or region.extent.width == 0 or region.extent.height == 0 or region.extent.depth == 0) return error.InvalidOptions;
            raw_regions[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_MEMORY_TO_IMAGE_COPY, .pHostPointer = region.bytes.ptr, .memoryRowLength = region.row_length, .memoryImageHeight = region.image_height, .imageSubresource = region.subresource.toRaw(), .imageOffset = region.offset.toRaw(), .imageExtent = region.extent.toRaw() };
        }
        const info: raw.VkCopyMemoryToImageInfo = .{ .sType = raw.VK_STRUCTURE_TYPE_COPY_MEMORY_TO_IMAGE_INFO, .dstImage = try image.rawHandle(), .dstImageLayout = layout.toRaw(), .regionCount = @intCast(regions.len), .pRegions = raw_regions[0..regions.len].ptr };
        try core.checkSuccessOptional(if (image._device_state) |*state| state else null, copy(image._device_handle, &info));
    }

    pub fn copyToHost(image: *const Image, layout: types.ImageLayout, regions: []const HostReadRegion) core.Error!void {
        const copy = image.dispatch.copy_image_to_memory orelse return error.MissingCommand;
        if (regions.len == 0 or regions.len > host_copy_region_count_max) return error.InvalidOptions;
        var raw_regions: [host_copy_region_count_max]raw.VkImageToMemoryCopy = undefined;
        for (regions, 0..) |region, index| {
            if (region.bytes.len == 0 or region.extent.width == 0 or region.extent.height == 0 or region.extent.depth == 0) return error.InvalidOptions;
            raw_regions[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_IMAGE_TO_MEMORY_COPY, .pHostPointer = region.bytes.ptr, .memoryRowLength = region.row_length, .memoryImageHeight = region.image_height, .imageSubresource = region.subresource.toRaw(), .imageOffset = region.offset.toRaw(), .imageExtent = region.extent.toRaw() };
        }
        const info: raw.VkCopyImageToMemoryInfo = .{ .sType = raw.VK_STRUCTURE_TYPE_COPY_IMAGE_TO_MEMORY_INFO, .srcImage = try image.rawHandle(), .srcImageLayout = layout.toRaw(), .regionCount = @intCast(regions.len), .pRegions = raw_regions[0..regions.len].ptr };
        try core.checkSuccessOptional(if (image._device_state) |*state| state else null, copy(image._device_handle, &info));
    }

    pub fn copyHostToImage(image: *const Image, destination: *const Image, source_layout: types.ImageLayout, destination_layout: types.ImageLayout, regions: []const HostImageCopyRegion) core.Error!void {
        const copy = image.dispatch.copy_image_to_image orelse return error.MissingCommand;
        if (destination._device_handle != image._device_handle) return error.InvalidHandle;
        if (regions.len == 0 or regions.len > host_copy_region_count_max) return error.InvalidOptions;
        var raw_regions: [host_copy_region_count_max]raw.VkImageCopy2 = undefined;
        for (regions, 0..) |region, index| raw_regions[index] = .{ .sType = raw.VK_STRUCTURE_TYPE_IMAGE_COPY_2, .srcSubresource = region.source_subresource.toRaw(), .srcOffset = region.source_offset.toRaw(), .dstSubresource = region.destination_subresource.toRaw(), .dstOffset = region.destination_offset.toRaw(), .extent = region.extent.toRaw() };
        const info: raw.VkCopyImageToImageInfo = .{ .sType = raw.VK_STRUCTURE_TYPE_COPY_IMAGE_TO_IMAGE_INFO, .srcImage = try image.rawHandle(), .srcImageLayout = source_layout.toRaw(), .dstImage = try destination.rawHandle(), .dstImageLayout = destination_layout.toRaw(), .regionCount = @intCast(regions.len), .pRegions = raw_regions[0..regions.len].ptr };
        try core.checkSuccessOptional(if (image._device_state) |*state| state else null, copy(image._device_handle, &info));
    }

    pub fn transitionHostLayout(image: *const Image, old_layout: types.ImageLayout, new_layout: types.ImageLayout, range: types.ImageSubresourceRange) core.Error!void {
        const transition = image.dispatch.transition_layout orelse return error.MissingCommand;
        const info: raw.VkHostImageLayoutTransitionInfo = .{ .sType = raw.VK_STRUCTURE_TYPE_HOST_IMAGE_LAYOUT_TRANSITION_INFO, .image = try image.rawHandle(), .oldLayout = old_layout.toRaw(), .newLayout = new_layout.toRaw(), .subresourceRange = range.toRaw() };
        try core.checkSuccessOptional(if (image._device_state) |*state| state else null, transition(image._device_handle, 1, &info));
    }

    pub fn bindMemory(
        image: *Image,
        allocation: *const memory.Allocation,
        offset: core.DeviceOffset,
    ) core.Error!void {
        if (image.bound_memory != null) return error.InvalidOptions;
        if (allocation._device_handle != image._device_handle) return error.InvalidHandle;
        const requirements = try image.memoryRequirements();
        if (!requirements.supportsMemoryType(allocation.memory_type_index)) return error.InvalidOptions;
        const offset_bytes = offset.bytes();
        if (requirements.alignment.bytes() != 0 and offset_bytes % requirements.alignment.bytes() != 0) {
            return error.InvalidOptions;
        }
        if (offset_bytes > allocation.size.bytes() or
            requirements.size.bytes() > allocation.size.bytes() - offset_bytes)
        {
            return error.InvalidOptions;
        }
        const allocation_handle = (try allocation.rawHandle()) orelse return error.InvalidHandle;
        const image_handle = try image.rawHandle();
        if (image.dispatch.bind_image_memory2) |bind2| {
            const info: raw.VkBindImageMemoryInfo = .{
                .sType = raw.VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_INFO,
                .image = image_handle,
                .memory = allocation_handle,
                .memoryOffset = offset_bytes,
            };
            try core.checkSuccessOptional(if (image._device_state) |*state| state else null, bind2(image._device_handle, 1, &info));
        } else {
            try core.checkSuccessOptional(if (image._device_state) |*state| state else null, image.dispatch.bind_image_memory(
                image._device_handle,
                image_handle,
                allocation_handle,
                offset_bytes,
            ));
        }
        image.bound_memory = .{ .allocation = allocation_handle, .offset = offset };
    }

    pub fn debugObject(image: *const Image) core.Error!debug_utils.Object {
        return .forDevice(.image, try image.rawHandle(), image._device_handle);
    }
};

pub const Reference = union(enum) {
    owned: *const Image,
    swapchain: *const SwapchainImage,

    pub fn handle(reference: Reference) core.Error!ImageHandle {
        return switch (reference) {
            .owned => |image| (try image.rawHandle()) orelse error.InvalidHandle,
            .swapchain => |image| try image.rawHandle(),
        };
    }

    pub fn deviceHandle(reference: Reference) DeviceHandle {
        return switch (reference) {
            .owned => |image| image._device_handle,
            .swapchain => |image| image._device_handle,
        };
    }

    pub fn knownFormat(reference: Reference) ?types.Format {
        return switch (reference) {
            .owned => |value| value.format,
            .swapchain => null,
        };
    }

    pub fn knownExtentAtMip(reference: Reference, mip_level: u32) ?types.Extent3D {
        return switch (reference) {
            .swapchain => null,
            .owned => |value| if (mip_level >= value.mip_levels) null else .{
                .width = @max(1, value.extent.width >> @intCast(@min(mip_level, 31))),
                .height = @max(1, value.extent.height >> @intCast(@min(mip_level, 31))),
                .depth = @max(1, value.extent.depth >> @intCast(@min(mip_level, 31))),
            },
        };
    }

    pub fn knownArrayLayers(reference: Reference) ?u32 {
        return switch (reference) {
            .owned => |value| value.array_layers,
            .swapchain => null,
        };
    }
};

/// A non-owning image whose lifetime is controlled by a swapchain.
pub const SwapchainImage = struct {
    _handle: ImageHandle,
    _device_handle: DeviceHandle,
    _swapchain_handle: SwapchainHandle,
    _swapchain_borrow: ?core.Generation.Borrow = null,
    index: core.SwapchainImageIndex,

    pub fn rawHandle(image: SwapchainImage) core.Error!ImageHandle {
        if (image._swapchain_borrow) |borrow| try borrow.validate();
        return image._handle;
    }

    pub fn debugObject(image: SwapchainImage) core.Error!debug_utils.Object {
        return .forDevice(.image, try image.rawHandle(), image._device_handle);
    }
};

pub const ViewOptions = struct {
    image: Reference,
    format: types.Format,
    view_type: types.ImageViewType = ._2d,
    components: types.ComponentMapping = .{},
    subresource_range: types.ImageSubresourceRange,
};

pub fn create(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,
    options: Options,
) core.Error!Image {
    if (options.extent.width == 0 or options.extent.height == 0 or options.extent.depth == 0 or
        options.mip_levels == 0 or options.array_layers == 0 or options.usage.toRaw() == 0)
    {
        return error.InvalidOptions;
    }
    if (options.queue_family_indices.len > queue_family_count_max) return error.CountOverflow;
    if (options.queue_family_indices.len == 1) return error.InvalidOptions;
    var queue_indices: [queue_family_count_max]u32 = undefined;
    for (options.queue_family_indices, 0..) |family, index| {
        for (options.queue_family_indices[0..index]) |previous| {
            if (family == previous) return error.InvalidOptions;
        }
        queue_indices[index] = family.toRaw();
    }
    const info: raw.VkImageCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .flags = options.flags.toRaw(),
        .imageType = options.image_type.toRaw(),
        .format = options.format.toRaw(),
        .extent = options.extent.toRaw(),
        .mipLevels = options.mip_levels,
        .arrayLayers = options.array_layers,
        .samples = options.samples.toRaw(),
        .tiling = options.tiling.toRaw(),
        .usage = options.usage.toRaw(),
        .sharingMode = if (options.queue_family_indices.len == 0) raw.VK_SHARING_MODE_EXCLUSIVE else raw.VK_SHARING_MODE_CONCURRENT,
        .queueFamilyIndexCount = @intCast(options.queue_family_indices.len),
        .pQueueFamilyIndices = if (options.queue_family_indices.len == 0) null else queue_indices[0..options.queue_family_indices.len].ptr,
        .initialLayout = options.initial_layout.toRaw(),
    };
    var handle: raw.VkImage = null;
    const result = dispatch.create_image(device_handle, &info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy_image(device_handle, provisional, allocation_callbacks);
        try core.checkSuccess(result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._owner = try .init(&handle),
        ._device_handle = device_handle,
        .format = options.format,
        .extent = options.extent,
        .samples = options.samples,
        .mip_levels = options.mip_levels,
        .array_layers = options.array_layers,
        .allocation_callbacks = allocation_callbacks,
        .dispatch = dispatch,
    };
}

pub const View = struct {
    _handle: ?ImageViewHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    format: types.Format,
    samples: ?types.SampleCountBit,
    extent: ?types.Extent3D,
    layer_count: ?u32,
    _image_borrow: ?core.Generation.Borrow = null,
    _image_owner: ?core.Owner.Borrow = null,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_image_view: CommandFunction(raw.PFN_vkDestroyImageView),

    pub fn deinit(view: *View) void {
        if (!(view._owner.release(view) catch return)) return;
        const handle = view._handle orelse return;
        view.destroy_image_view(view._device_handle, handle, view.allocation_callbacks);
        view._handle = null;
    }

    pub fn rawHandle(view: *const View) core.Error!raw.VkImageView {
        try view._owner.validate(view);
        if (view._device_state) |*state| try state.ensureDispatchAllowed();
        if (view._image_borrow) |borrow| try borrow.validate();
        if (view._image_owner) |owner| try owner.validate();
        return view._handle orelse error.InactiveObject;
    }

    pub fn debugObject(view: *const View) core.Error!debug_utils.Object {
        return .forDevice(.image_view, try view.rawHandle(), view._device_handle);
    }
};

pub fn createView(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    create_image_view: CommandFunction(raw.PFN_vkCreateImageView),
    destroy_image_view: CommandFunction(raw.PFN_vkDestroyImageView),
    options: ViewOptions,
) core.Error!View {
    if (options.image.deviceHandle() != device_handle) return error.InvalidHandle;
    const create_info: raw.VkImageViewCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = try options.image.handle(),
        .viewType = options.view_type.toRaw(),
        .format = options.format.toRaw(),
        .components = options.components.toRaw(),
        .subresourceRange = options.subresource_range.toRaw(),
    };
    var handle: raw.VkImageView = null;
    const result = create_image_view(
        device_handle,
        &create_info,
        allocation_callbacks,
        &handle,
    );
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional_handle| {
            destroy_image_view(device_handle, provisional_handle, allocation_callbacks);
        }
        try core.checkSuccess(result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._owner = try .init(&handle),
        ._device_handle = device_handle,
        .format = options.format,
        .samples = switch (options.image) {
            .owned => |value| value.samples,
            .swapchain => ._1,
        },
        .extent = options.image.knownExtentAtMip(options.subresource_range.base_mip_level),
        .layer_count = switch (options.subresource_range.layer_count) {
            .count => |count| count,
            .remaining => if (options.image.knownArrayLayers()) |count|
                count -| options.subresource_range.base_array_layer
            else
                null,
        },
        ._image_borrow = switch (options.image) {
            .owned => null,
            .swapchain => |value| value._swapchain_borrow,
        },
        ._image_owner = switch (options.image) {
            .owned => |value| value._owner.borrow(),
            .swapchain => null,
        },
        .allocation_callbacks = allocation_callbacks,
        .destroy_image_view = destroy_image_view,
    };
}

test "all image declarations compile" {
    @import("std").testing.refAllDecls(@This());
}

fn testSubresourceLayout(_: raw.VkDevice, _: raw.VkImage, _: [*c]const raw.VkImageSubresource, output: [*c]raw.VkSubresourceLayout) callconv(.c) void {
    output.* = .{ .offset = 4, .size = 64, .rowPitch = 16, .arrayPitch = 64, .depthPitch = 64 };
}

fn testSparseRequirements(_: raw.VkDevice, _: raw.VkImage, count: [*c]u32, output: [*c]raw.VkSparseImageMemoryRequirements) callconv(.c) void {
    if (output == null) {
        count.* = 1;
        return;
    }
    output[0] = .{ .formatProperties = .{ .aspectMask = raw.VK_IMAGE_ASPECT_COLOR_BIT, .imageGranularity = .{ .width = 4, .height = 4, .depth = 1 }, .flags = raw.VK_SPARSE_IMAGE_FORMAT_SINGLE_MIPTAIL_BIT }, .imageMipTailFirstLod = 3, .imageMipTailSize = 128 };
    count.* = 1;
}

test "owned images expose typed layouts, sparse requirements, and host-copy availability" {
    var value: Image = .{
        ._handle = @ptrFromInt(0x1000),
        ._owner = core.Owner.init({}) catch unreachable,
        ._device_handle = @ptrFromInt(0x2000),
        .format = .r8g8b8a8_unorm,
        .extent = .{ .width = 16, .height = 16, .depth = 1 },
        .samples = ._1,
        .mip_levels = 4,
        .array_layers = 1,
        .allocation_callbacks = null,
        .dispatch = .{
            .create_image = undefined,
            .destroy_image = undefined,
            .get_image_memory_requirements = undefined,
            .get_image_memory_requirements2 = null,
            .bind_image_memory = undefined,
            .bind_image_memory2 = null,
            .get_subresource_layout = testSubresourceLayout,
            .get_sparse_requirements = testSparseRequirements,
            .get_sparse_requirements2 = null,
            .copy_memory_to_image = null,
            .copy_image_to_memory = null,
            .copy_image_to_image = null,
            .transition_layout = null,
        },
    };
    const layout = try value.subresourceLayout(.{ .aspect = .color, .mip_level = 1 });
    try @import("std").testing.expectEqual(@as(u64, 64), layout.size.bytes());
    try @import("std").testing.expectError(error.InvalidOptions, value.subresourceLayout(.{ .aspect = .color, .mip_level = 4 }));
    var sparse_storage: [2]SparseMemoryRequirements = undefined;
    const sparse = try value.sparseMemoryRequirements(&sparse_storage);
    try @import("std").testing.expectEqual(@as(usize, 1), sparse.len);
    try @import("std").testing.expect(sparse[0].flags.contains(.single_miptail));
    try @import("std").testing.expectError(error.MissingCommand, value.copyFromHost(.general, &.{.{ .bytes = "abcd", .subresource = .{ .aspects = .init(&.{.color}) }, .extent = .{ .width = 1, .height = 1, .depth = 1 } }}));
}
