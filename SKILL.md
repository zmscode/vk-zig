---
name: use-vk-zig
description: Use vk-zig to generate target-specific Vulkan 1.4 bindings and build or debug Zig 0.16 Vulkan applications. Trigger when an agent is adding vk-zig to build.zig/build.zig.zon, regenerating Vulkan bindings from Khronos inputs, loading core or extension commands, creating instances/devices/queues, using surfaces or VK_EXT_debug_utils, handling MoltenVK portability, or diagnosing Vulkan loader discovery.
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

- Prefer `vk.Loader`, `Entry`, `Instance`, `PhysicalDevice`, `Device`, `Queue`, and `Surface`.
- Use `vk.command.<snake_case_name>` with `entry.load`, `instance.load`, or `device.load`. The
  descriptor binds the PFN type, Vulkan name, and valid dispatch scope.
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
`.enumerate_portability = vk.platform == .metal`; this adds the matching extension and typed flag
together.

Create a logical device with `PhysicalDevice.createDevice(DeviceOptions)`. Supply one or more
`DeviceQueueOptions`, each with a non-empty priority slice. On Apple/MoltenVK set
`.enable_portability_subset = vk.platform == .metal`. Query the exact platform additions with
`vk.Portability.instanceExtensions()`, `deviceExtensions()`, and `instanceFlags()`.

Use `createInstanceRaw` or `createDeviceRaw` for uncommon create-info chains. Keep every `pNext`
node and borrowed slice alive until the Vulkan call returns.

Deinitialize children before parents: queues need no deinit, then devices, surfaces/debug
messengers, instances, and finally the loader. Wrapper `deinit` methods are idempotent, but using
an inactive owner returns `error.InactiveObject`.

## Use common extensions

- Transfer ownership of a created `VkSurfaceKHR` with `instance.adoptSurface(...)`, then query
  presentation support with `physical_device.surfaceSupport(&surface, family_index)`.
- Create an owned debug messenger with `vk.ext.debug_utils.Messenger.init(&instance, options)`.
- Name wrapper objects with `device.setObjectName(.{ .device = &device }, "name")` or the `.queue`
  variant. Do not convert wrapper pointers with `@intFromPtr` in consumer code.

Enable `VK_KHR_surface`, the platform surface extension, or `VK_EXT_debug_utils` in
`InstanceOptions.extensions` before calling their commands.

## Read properties safely

Keep raw enumeration results alive while using `vk.extensionName`, `layerName`,
`layerDescription`, or `physicalDeviceName`; these return borrowed bounded views. Use
`supportsExtension` and `supportsLayer` to scan an existing enumeration without allocating.

## Generate and update bindings

- Run `zig build bindings` to generate the selected target's raw ABI and command descriptors in
  `zig-out/bindings/` from vendored inputs. This is offline and deterministic.
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
