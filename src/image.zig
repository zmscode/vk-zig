const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const types = @import("vulkan_types");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const SwapchainHandle = core.NonNullHandle(raw.VkSwapchainKHR);
const ImageHandle = core.NonNullHandle(raw.VkImage);
const ImageViewHandle = core.NonNullHandle(raw.VkImageView);

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
    image: *const SwapchainImage,
    format: types.Format,
    view_type: types.ImageViewType = ._2d,
    components: types.ComponentMapping = .{},
    subresource_range: types.ImageSubresourceRange,
};

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
    if (options.image._device_handle != device_handle) return error.InvalidHandle;
    const create_info: raw.VkImageViewCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = options.image._handle,
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
