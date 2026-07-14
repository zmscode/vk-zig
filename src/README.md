# Source layout

`vulkan.zig` is the public facade and owns loader, instance, physical-device, and
logical-device orchestration. Vulkan functionality is implemented in focused
modules so changes do not accumulate in one file:

- `core.zig`: errors, versions, indices, timeouts, handles, and result handling.
- `configuration.zig`: layers, portability defaults, and diagnostics discovery.
- `registry.zig`: extension/layer name sets and bounded C-string views.
- `capabilities.zig`: pure surface and swapchain capability selection policy.
- `physical_device.zig`: typed properties, limits, and queue-family selection.
- `format.zig`: format, image-format, external-memory, DRM, and sparse queries.
- `memory.zig`: memory properties, memory-type selection, and owned allocations.
- `buffer.zig`: buffers, buffer views, requirements, and device addresses.
- `image.zig`: image and image-view ownership and creation.
- `synchronization.zig`: semaphores, timelines, fences, and waits.
- `command_buffer.zig`: command pools, command buffers, recording, and labels.
- `queue.zig`: submission, synchronization handoff, presentation, and labels.
- `presentation.zig`: surfaces, swapchains, image acquisition, and presentation data.
- `debug_utils.zig`: typed validation messages, callbacks, labels, and messengers.

Generated raw declarations and typed Vulkan vocabulary remain separate build
modules (`vulkan_raw`, `vulkan_commands`, and `vulkan_types`). Normal application
code should use the facade and the domain modules; `raw` is reserved for explicit
FFI and unsupported-extension escape hatches.

The dependency direction is domain modules -> `core.zig`/generated vocabulary,
with `vulkan.zig` composing them. Domain modules must not import `vulkan.zig`.
