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
};

pub const Image = struct {
    _handle: ?ImageHandle,
    _device_handle: DeviceHandle,
    format: types.Format,
    extent: types.Extent3D,
    mip_levels: u32,
    array_layers: u32,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,
    bound_memory: ?memory.Binding = null,

    pub fn deinit(image: *Image) void {
        const handle = image._handle orelse return;
        image.dispatch.destroy_image(image._device_handle, handle, image.allocation_callbacks);
        image._handle = null;
    }

    pub fn rawHandle(image: *const Image) core.Error!raw.VkImage {
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
        const allocation_handle = allocation._handle orelse return error.InactiveObject;
        const image_handle = try image.rawHandle();
        if (image.dispatch.bind_image_memory2) |bind2| {
            const info: raw.VkBindImageMemoryInfo = .{
                .sType = raw.VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_INFO,
                .image = image_handle,
                .memory = allocation_handle,
                .memoryOffset = offset_bytes,
            };
            try core.checkSuccess(bind2(image._device_handle, 1, &info));
        } else {
            try core.checkSuccess(image.dispatch.bind_image_memory(
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
            .owned => |image| image._handle orelse error.InactiveObject,
            .swapchain => |image| image._handle,
        };
    }

    pub fn deviceHandle(reference: Reference) DeviceHandle {
        return switch (reference) {
            .owned => |image| image._device_handle,
            .swapchain => |image| image._device_handle,
        };
    }
};

/// A non-owning image whose lifetime is controlled by a swapchain.
pub const SwapchainImage = struct {
    _handle: ImageHandle,
    _device_handle: DeviceHandle,
    _swapchain_handle: SwapchainHandle,
    index: core.SwapchainImageIndex,

    pub fn rawHandle(image: SwapchainImage) raw.VkImage {
        return image._handle;
    }

    pub fn debugObject(image: SwapchainImage) core.Error!debug_utils.Object {
        return .forDevice(.image, image._handle, image._device_handle);
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
        ._device_handle = device_handle,
        .format = options.format,
        .extent = options.extent,
        .mip_levels = options.mip_levels,
        .array_layers = options.array_layers,
        .allocation_callbacks = allocation_callbacks,
        .dispatch = dispatch,
    };
}

pub const View = struct {
    _handle: ?ImageViewHandle,
    _device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_image_view: CommandFunction(raw.PFN_vkDestroyImageView),

    pub fn deinit(view: *View) void {
        const handle = view._handle orelse return;
        view.destroy_image_view(view._device_handle, handle, view.allocation_callbacks);
        view._handle = null;
    }

    pub fn rawHandle(view: *const View) core.Error!raw.VkImageView {
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
        ._device_handle = device_handle,
        .allocation_callbacks = allocation_callbacks,
        .destroy_image_view = destroy_image_view,
    };
}

test "all image declarations compile" {
    @import("std").testing.refAllDecls(@This());
}
