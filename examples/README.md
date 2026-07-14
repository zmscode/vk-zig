# Examples

Every example is a standalone Zig program importing the public `vulkan` module. Build the complete
suite with:

```sh
zig build examples
```

Each example also has a named run step:

| Example | Run command | What it exercises |
| --- | --- | --- |
| `info.zig` | `zig build run-info` | Runtime loader and Vulkan API version |
| `instance_extensions.zig` | `zig build run-instance-extensions` | Allocator-aware extension enumeration |
| `instance_layers.zig` | `zig build run-instance-layers` | Layer enumeration and bounded names |
| `physical_devices.zig` | `zig build run-physical-devices` | Instance ownership and physical-device discovery |
| `queue_families.zig` | `zig build run-queue-families` | Typed queue-family capability enumeration |
| `memory_properties.zig` | `zig build run-memory-properties` | Memory heaps, types, and preferred type selection |
| `device_features.zig` | `zig build run-device-features` | Core and chained physical-device feature queries |
| `device_extensions.zig` | `zig build run-device-extensions` | Per-device extension enumeration and generated names |
| `logical_device.zig` | `zig build run-logical-device` | Logical-device and queue creation/teardown |
| `raw_create_info.zig` | `zig build run-raw-create-info` | Raw generated structs with wrapped ownership |
| `platform.zig` | `zig build run-platform` | Target-specific declaration generation |
| `capabilities.zig` | `zig build run-capabilities` | Allocation-free extension/layer support checks |
| `debug_utils.zig` | `zig build run-debug-utils` | Typed, instance-owned `VK_EXT_debug_utils` messenger |
| `frame_resources.zig` | `zig build run-frame-resources` | Raw-free image-view, command, synchronization, acquire, submit, and present flow |

Except for `platform.zig`, running these programs requires a discoverable Vulkan loader and, for
device examples, a working Vulkan implementation. On macOS, install MoltenVK or the Vulkan SDK.
The creation examples enable the Khronos portability extensions automatically on Metal targets.

The examples use `std.process.Init.gpa` for allocations, immediately pair owned Vulkan objects with
`defer ...deinit()`, and keep direct raw API access visible where it teaches an important Vulkan
pattern.
