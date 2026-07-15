---
name: use-vk-zig
description: Use vk-zig to generate target-specific Vulkan 1.4 bindings and build or debug Zig 0.16 Vulkan applications. Trigger when an agent is adding vk-zig to build.zig/build.zig.zon, regenerating Vulkan bindings from Khronos inputs, loading commands, selecting queues or memory, creating instances/devices/surfaces/swapchains, using VK_EXT_debug_utils, handling MoltenVK portability, or diagnosing Vulkan loader discovery.
---

# Use vk-zig

Use the typed `vulkan` module for normal application code and `vulkan.raw` only where Vulkan's
exact ABI is required. Preserve explicit Vulkan ownership and destruction order.

## Start here

1. Read `README.md`, then inspect the closest file in `examples/`.
2. Confirm the project uses Zig 0.16 or newer.
3. Add the package with `zig fetch --save=vulkan git+https://github.com/zmscode/vk-zig.git`.
4. Pass the consumer's target and optimization mode to the dependency and import its `vulkan`
   module.
5. Run `zig build test` and `zig build examples` after API or generation changes.

Use a local `.path` dependency while editing vk-zig itself. Do not copy generated bindings into a
consumer unless the user explicitly needs a standalone snapshot.

## Choose the API level

- Prefer `vk.Loader`, `Entry`, `Instance`, `PhysicalDevice`, `Device`, `Queue`, `Surface`,
  `Swapchain`, and the owned frame-resource wrappers.
- Use generated wrapper enums such as `vk.Format`, `vk.PresentMode`, and `vk.ImageLayout` instead
  of raw integer constants. They are non-exhaustive and preserve driver values unknown to the
  vendored registry.
- Build domain-specific flags with `vk.ImageUsageFlags.init(&.{...})` and equivalent types. Do not
  combine raw `VK_*_BIT` constants or interchange flag domains.
- Use `vk.command.<snake_case_name>` with `entry.load`, `instance.load`, or `device.load`. The
  descriptor binds the PFN type, Vulkan name, and valid dispatch scope.
- Use `entry.require`, `instance.require`, or `device.require` when absence is an error. Use `load`
  only when probing an optional capability.
- Use `loadUnchecked(PFN, name)` only for genuinely dynamic, provisional, or vendor commands that
  are absent from the generated descriptors.
- Use `vk.CommandFunction(PFN)` when storing a Vulkan command pointer.
- Use `vk.raw` for exact structs, constants, handles, and commands not covered by a wrapper.
- Call `vk.checkSuccess` only for commands whose sole successful result is `VK_SUCCESS`. Handle
  statuses such as `VK_TIMEOUT`, `VK_INCOMPLETE`, and `VK_SUBOPTIMAL_KHR` explicitly.

Use `rawHandle()` for FFI boundaries. Do not reach into wrapper fields or dispatch through a
nullable raw handle.

## Create Vulkan objects

Create an instance with `Entry.createInstance(InstanceOptions)`. On Apple/MoltenVK set
`.enumerate_portability = vk.platform_support.metal`; this adds the matching extension and typed flag
together.

Create a logical device with `PhysicalDevice.createDevice(DeviceOptions)`. Supply one or more
`DeviceQueueOptions`, each with a non-empty priority slice. On Apple/MoltenVK set
`.enable_portability_subset = vk.platform_support.metal`. Query the exact platform additions with
`vk.Portability.instanceExtensions()`, `deviceExtensions()`, and `instanceFlags()`.

Use `createInstanceRaw` or `createDeviceRaw` for uncommon create-info chains. Keep every `pNext`
node and borrowed slice alive until the Vulkan call returns.

Build extension lists with generated `vk.extension.<vendor_name>.name` descriptors and
`vk.ExtensionSet(capacity)`. Append platform/window-system requirements, then pass `set.slice()`
to instance or device options. Do not duplicate string literals or hand-roll deduplication.

Enumerate queue families with `queueFamilies`, select them with `QueueFamily.supports`, and use
`QueueFamily.presentationSupport` when a surface is involved. Use `findMemoryTypeIndex` with
required and preferred property flags instead of manually scanning `memoryTypes`.

Query `memoryProperties` for an owned typed snapshot. Iterate `types()` and `heaps()`, use typed
flags and indices, and call `deviceLocalBytes()` rather than reinterpreting raw heap flags.
Use `memoryPropertiesInto` for stable caller-owned storage and `memoryPropertiesRaw` only for
advanced diagnostics or interop.

Keep `QueueFamilyIndex`, `QueueIndex`, and `SwapchainImageIndex` distinct. Use
`vk.QueueIndex.first` for the common first queue; do not cast one index domain into another.

Surface capabilities, formats, and present modes are typed. `extent_current == null` means the
surface extent is selected by the application, and `image_count_max == null` means Vulkan reports
no maximum. Use the allocating `surfaceFormats`
and `presentModes` conveniences during startup, or pair `surfaceFormatCount`/`presentModeCount`
with `surfaceFormatsInto`/`presentModesInto` when the consumer owns fixed storage. Treat
`error.BufferTooSmall` as a bounded retry or an application capacity error; vk-zig will not hide a
fallback allocation in an `Into` call.

Select texture and depth formats with `PhysicalDevice.formatProperties2` and
`imageFormatProperties2`. Check `FormatFeatureFlags` with `contains`; an unsupported image
combination is `null`, not a raw Vulkan result. Use `sparseImageFormatPropertyCount` plus
`sparseImageFormatPropertiesInto`, or its allocating convenience, for sparse capabilities.
External-memory and DRM-modifier image queries belong in `ImageFormatQueryOptions` through
`.external_memory_handle_type` and `.drm_format_modifier`; do not construct input or output
`pNext` chains in application code. Enumerate DRM modifiers with the typed count/`Into`/allocating
methods and preserve unknown feature bits by retaining the returned flag sets.

Deinitialize children before parents: swapchains, then devices, surfaces, instances, and finally
the loader. An instance configured with a typed debug messenger owns and destroys that messenger
before destroying itself. Queues and swapchain images are non-owning and need no deinit.
Wrapper `deinit` methods are idempotent, but using an inactive owner returns
`error.InactiveObject`.

For a frame, create `ImageView`, `CommandPool`, `Semaphore`, and `Fence` through `Device`.
Allocate a borrowed `CommandBuffer` from its pool, enumerate borrowed images with
`swapchain.images` or `imagesInto`, and record transitions with `imageBarrier` and
`clearColorImage`. Use `Fence.wait(Timeout)` and handle `.success`/`.timeout`, then call
`Queue.submit(SubmitOptions)` and `Queue.present(PresentOptions)`. After the associated fence,
timeline semaphore, or queue wait completes, call `CommandBuffer.markComplete`; one call is
required for each outstanding `.simultaneous_use` submission. Command pools are externally
synchronized and must not move while children live. Use `CommandPool.reset` for a whole-pool
reset, `CommandBuffer.reset` for individually resettable pools, and `CommandBuffer.deinit` or
`CommandPool.freeCommandBuffer` before destroying the pool. Keep resources alive until GPU work
is complete. Follow `examples/frame_resources.zig` for a complete raw-free clear frame.

Prefer dynamic rendering for new graphics paths. For compatibility paths, create an owned
`RenderPass` and `Framebuffer`, then record with `CommandBuffer.beginRenderPass`; use the returned
scope's `next` and `end` methods. Describe graphics pipeline compatibility with the tagged
`GraphicsPipelineOptions.compatibility` union: `.dynamic_rendering` takes attachment formats,
while `.render_pass` takes a render-pass pointer and subpass index. Do not pass raw render-pass or
framebuffer handles. Use `.imageless` framebuffer attachments only when the device feature is
enabled, and supply the live image views in `RenderPassBeginOptions.imageless_attachments`.

Create timeline semaphores with `device.createSemaphore(.{ .kind = .timeline,
.initial_value = value })`. Use `counterValue`, `signal`, `wait`, or
`Device.waitTimelineSemaphores`; do not pass a timeline semaphore to legacy `Queue.submit`, image
acquisition, or presentation, which require binary semaphores. Use `Queue.submit2` when GPU waits
or signals need timeline values, synchronization2 stage masks, protected submission, performance
query pass chaining, or device-group indices and masks.

Prefer `beginLabel` on command buffers and `beginLabelScope` on queues when labels are enabled.
Call the returned scope's `deinit`; its end operation is idempotent. Use `submitRaw` and the
device's raw command-label methods only for advanced interop paths that cannot use typed wrappers.

## Use common extensions

- Transfer ownership of a created `VkSurfaceKHR` with `instance.adoptSurface(...)`, then query
  presentation support, capabilities, formats, and present modes through `PhysicalDevice`.
- Enumerate `deviceExtensions`, enable `vk.extension.khr_swapchain.name`, then use
  `device.createSwapchain`. Handle every `AcquireResult` and `PresentStatus` tag; `.out_of_date`
  and `.suboptimal` are normal control flow for recreation, not generic errors.
- Define a handler accepting `vk.ext.debug_utils.Message`, construct it with
  `MessengerConfig.fromHandler`, and pass it as `InstanceOptions.debug_messenger`. This path owns
  the C trampoline, automatically enables `VK_EXT_debug_utils`, chains the creation callback, and
  destroys the persistent messenger with the instance.
- Use `MessengerConfig.fromHandlerWithContext` when the handler needs state. The context pointer
  must remain valid until instance deinitialization, and mutable state must be safe for concurrent
  Vulkan callbacks. Handlers return `void` normally or `HandlerResult` to control abort behavior.
- Resolve validation, messenger, and GPU-label requests with `vk.diagnostics.detect`; use
  `vk.layer.khronos_validation.name` and `vk.extension.ext_debug_utils.name` rather than repeating
  string literals. Treat the returned booleans as availability, leaving fatal/fallback policy to
  the application.
- Use `debug_utils.severity_flags` and `message_type_flags` instead of casting raw Vulkan bits.
- Treat `MessengerOptions`, `Messenger.init`, `MessengerOptions.createInfo`, and
  `Message.fromCallback` as advanced raw-ABI escape hatches. Do not use them in ordinary consumer
  diagnostics code.
- Name wrapper and raw Vulkan objects with `device.setObjectName`; use queue and command-buffer
  label methods for GPU captures. Do not convert handles with `@intFromPtr` in consumer code.

Enable `VK_KHR_surface` and the platform surface extension in `InstanceOptions.extensions` before
calling their commands. `InstanceOptions.debug_messenger` automatically enables
`VK_EXT_debug_utils`; add it explicitly only when using debug-utils features without a messenger,
such as GPU labels.

## Read properties safely

Keep raw enumeration results alive while using `vk.extensionName`, `layerName`,
`layerDescription`, or `physicalDeviceName`; these return borrowed bounded views. Use
`supportsExtension` and `supportsLayer` to scan an existing enumeration without allocating.

## Generate and update bindings

- Run `zig build bindings` to generate the selected target's raw ABI, command descriptors, and
  typed vocabulary in `zig-out/bindings/` from vendored inputs. This is offline and deterministic.
- Select a target with `-Dtarget=...` and a window-system declaration set with
  `-Dplatform=none|metal|win32|xlib|xcb|wayland`.
- Run `zig build update` only when intentionally updating the vendored Khronos revision. It uses
  the network, validates translation and command generation before installation, and records the
  exact commit in `vendor/VULKAN_HEADERS_COMMIT`.
- Use `-Dvulkan-ref=<tag-or-branch>` to pin an update.

Never edit generated files in `zig-out/bindings/`. Change the generator, wrapper, or vendored
Khronos inputs, then regenerate.

## Diagnose loader errors

`error.VulkanLoaderNotFound` means no loadable runtime library was found, not that the headers are
missing. Check the runtime installation and architecture. On macOS, install a Vulkan SDK or
MoltenVK and use `Loader.initFromPath` for a nonstandard SDK location. On Linux, confirm
`libvulkan.so.1`; on Windows, confirm `vulkan-1.dll`.

For a final verification, run native tests/examples, generate Windows and Linux bindings, and run
the runtime examples only where a Vulkan loader and driver are available.
