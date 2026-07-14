# vk-zig idiomatic wrapper gap audit

This document audits where an ordinary library or application using vk-zig must leave the
idiomatic wrapper and interact with `vk.raw`, a raw Vulkan function pointer, a raw Vulkan value,
or a manually assembled Vulkan structure.

The audit is based on:

- vk-zig commit `451064c`;
- Vulkan-Headers commit `8d6039a455a7ecc7d2a592ff97f62db4e59b70bf`;
- Zig 0.16.0;
- every public declaration in `src/vulkan.zig`;
- every program under `examples/`;
- all generated command and extension descriptors; and
- the Vulkan 1.0 through 1.4 core command set in the vendored `vk.xml` registry;
- Bloc's aggregate game plan and all executable phase plans from Phase 00 through Phase 20; and
- Bloc's current Phase 03 presentation implementation as a concrete consumer trace.

The goal is not to remove `vk.raw`. A complete ABI and explicit escape hatch are essential. The
goal is that normal Vulkan rendering, compute, presentation, resource management, and diagnostics
do not require it.

## Executive summary

The raw binding and command-generation layers are comprehensive. The idiomatic layer is currently
strongest at runtime loading, instance/device discovery, basic device creation, surface queries,
swapchain ownership, and debug messages. It does not yet cover a complete rendering or compute
workflow.

The current generated target contains:

- 771 Vulkan command descriptors;
- 696 extension-name descriptors; and
- 234 unique core Vulkan 1.0–1.4 commands in the registry.

`src/vulkan.zig` references 40 distinct Vulkan PFN types. Only 20 of those are core commands; the
rest are WSI, debug-utils, callback, or generic procedure types. Therefore 214 of 234 core commands
have no wrapper implementation. This is not a precise percentage of user-facing functionality,
because some referenced commands are internal loader operations, but it accurately shows the
scale of the missing wrapper layer.

A consumer currently cannot implement any of the following without raw Vulkan:

- buffer or image creation and memory binding;
- memory allocation, mapping, flushing, or invalidation;
- shader-module creation;
- descriptor layouts, pools, sets, or updates;
- pipeline layouts, graphics pipelines, or compute pipelines;
- command pools, command buffers, or command recording;
- fences, semaphores, timeline semaphores, or events;
- synchronization barriers;
- draw, dispatch, copy, clear, blit, or resolve commands;
- render passes, framebuffers, or dynamic rendering;
- queries and timestamps;
- platform surface creation; or
- any advanced extension such as ray tracing, mesh shading, video, or external-memory interop.

The practical acceptance target should be:

> A consumer can build a validated, resize-aware textured triangle and a basic compute workload
> without importing `vk.raw`, loading a command manually, constructing an `sType`/`pNext` chain,
> comparing a `VkResult`, or destroying a raw handle.

## Implementation progress

Work began after the `451064c` audit snapshot. The current working tree has completed these first
dependency-ordered slices:

1. **Generated presentation/core vocabulary:** `vulkan_types.zig` now generates target-aware,
   non-exhaustive enums and unknown-bit-preserving flag sets from `vk.xml`. The initial domains
   cover formats, device types, WSI choices, layouts, queue/memory/resource/synchronization flags,
   and the common Phase 03 command-recording values.
2. **Typed common values:** extents, offsets, rectangles, viewports, component mappings,
   subresource ranges, clear values, surface formats, and surface capabilities convert at the raw
   boundary without allocation.
3. **Migrated wrapper inputs:** instance portability, queue capability checks, memory-type
   selection, and swapchain creation no longer require raw enum/flag values.
4. **Caller-owned WSI enumeration:** surface formats and present modes provide count and `Into`
   APIs alongside allocating conveniences. `Into` never falls back to hidden allocation and
   reports `error.BufferTooSmall` when capacity is insufficient.

These changes partially address FOUND-01, FOUND-02, FOUND-03, FOUND-11, and FOUND-12. They do not
yet close those findings across the full registry. The next implementation slice is typed command
pools, command buffers, fences, semaphores, image views, recording, and submission for Bloc Phase
03.

## Audit rules

An API is classified as a wrapper gap when a normal consumer must do one or more of the following:

1. Mention a `vk.raw.Vk*` type in an application signature or field.
2. Use a `vk.raw.VK_*` constant for a common option, enum, flag, boolean, or result.
3. Call `entry.load`, `instance.load`, `device.load`, `require`, or `loadUnchecked` for a standard
   core or commonly used extension command.
4. Construct a Vulkan create-info structure and set `sType`, pointer/count pairs, or `pNext`.
5. Retain and destroy a raw Vulkan handle manually.
6. Translate `VkBool32`, `VkResult`, status values, or nullable handles manually.
7. Use casts solely to satisfy the Vulkan C ABI.

The following are intentional escape hatches, not gaps by themselves:

- the complete `vk.raw` module;
- checked `rawHandle()` methods used at a genuine FFI boundary;
- `createInstanceRaw` and `createDeviceRaw` for unsupported or provisional chains;
- generated command descriptors for provisional/vendor functionality; and
- explicitly named advanced APIs such as `loadUnchecked`.

An escape hatch becomes evidence of a gap when it is the only way to perform ordinary Vulkan
work.

## Current public raw exposure

This table lists the existing public API points that expose raw Vulkan in otherwise wrapped
workflows.

| Area | Public raw exposure | Consequence |
| --- | --- | --- |
| Portability | `Portability.instanceFlags() -> raw.VkInstanceCreateFlags` | Consumers using it directly receive an untyped flag integer. |
| Extension discovery | `Entry.instanceExtensions() -> []raw.VkExtensionProperties` | Names are wrapped by helpers, but revision and all storage remain C structs. |
| Layer discovery | `Entry.instanceLayers() -> []raw.VkLayerProperties` | Consumers must understand bounded C arrays and encoded versions. |
| Diagnostic detection | `diagnostics.detect` accepts raw layer/extension slices | The typed diagnostic API still depends on raw enumeration output. |
| Instance options | raw flags, `application_next`, `next`, allocation callbacks | Common extension configuration reintroduces manual `pNext`. |
| Surface adoption | raw `VkSurfaceKHR` and allocation callbacks | Every platform surface must first be created with raw Vulkan. |
| Swapchain options | raw format, color space, extent, usage, transform, alpha, mode, flags | Almost every swapchain choice requires raw values. |
| Image acquisition | raw semaphore and fence handles | The typed status union is surrounded by unwrapped synchronization. |
| Presentation | raw semaphore slices | A normal frame loop cannot remain in the wrapper. |
| Swapchain images | `[]raw.VkImage` | Consumers immediately need raw image-view and transition commands. |
| Device properties | raw properties/features/memory structures | Device selection and feature checks require raw fields and `VkBool32`. |
| Feature chains | mutable `?*anyopaque` plus raw feature structures | Consumers build, initialize, link, and keep `pNext` nodes alive manually. |
| Surface queries | raw capabilities, formats, and presentation modes | Choosing a valid swapchain requires raw field/constant knowledge. |
| Queue family | public raw `VkQueueFamilyProperties` field | Capabilities are partially typed, but granularity/timestamps/flags are raw. |
| Memory selection | raw physical-memory structure and property flags | Even the helper example uses `VK_MEMORY_PROPERTY_*`. |
| Device creation | raw enabled-features pointer, flags, `next`, allocation callbacks | Enabling modern Vulkan features requires a raw feature chain. |
| Debug labels | raw command-buffer handles | Queue labels are typed, command-buffer labels are not. |
| Queue submission | `[]raw.VkSubmitInfo` plus raw fence | Submission remains fully C-shaped. |
| Debug messages | raw public message fields and raw object/label slices | Simple logging is typed; structured inspection is not. |
| Object naming | raw handles for every object not already wrapped | Most Vulkan objects can only be named through raw union variants. |
| Result mapping | `checkSuccess(raw.VkResult)` | Necessary for all manually loaded commands and incomplete for all statuses. |

## Cross-cutting architecture gaps

These gaps affect almost every Vulkan feature and should be addressed before adding hundreds of
individual methods.

### FOUND-01: Generated typed enums are missing

The C translation represents most Vulkan enumerants as integer aliases plus `VK_*` constants.
Consequently consumers use raw values for formats, image layouts, descriptor types, shader stages,
present modes, color spaces, filtering, topology, culling, compare operations, attachment load/store
operations, sample counts, and many other ordinary choices.

Recommended design:

```zig
pub const Format = enum(i32) {
    undefined = raw.VK_FORMAT_UNDEFINED,
    r8g8b8a8_unorm = raw.VK_FORMAT_R8G8B8A8_UNORM,
    b8g8r8a8_srgb = raw.VK_FORMAT_B8G8R8A8_SRGB,
    _,

    pub fn fromRaw(value: raw.VkFormat) Format;
    pub fn toRaw(format: Format) raw.VkFormat;
};
```

Use non-exhaustive enums so values introduced by newer drivers remain representable. Generate the
mapping from `vk.xml`; do not hand-maintain hundreds of constants.

Acceptance criteria:

- Normal options use wrapper enums rather than raw integer aliases.
- Unknown future values round-trip without a panic.
- Raw conversion is explicit and kept at the wrapper boundary.

Priority: **P0**.

### FOUND-02: Generated typed flag sets are missing

The largest source of `vk.raw.VK_*_BIT` use is bitmask construction. Examples already require raw
memory-property and image-usage bits. Rendering would add access masks, pipeline stages, shader
stages, buffer/image usage, aspect masks, color write masks, command-pool flags, fence flags, and
dozens more.

Recommended design:

```zig
pub const MemoryProperty = enum(u32) {
    device_local = raw.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
    host_visible = raw.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
    host_coherent = raw.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    host_cached = raw.VK_MEMORY_PROPERTY_HOST_CACHED_BIT,
    _,
};

pub const MemoryProperties = Flags(MemoryProperty);

const wanted = MemoryProperties.init(&.{ .host_visible, .host_coherent });
```

`Flags(Bit)` should store the integer privately and provide `init`, `with`, `without`, `contains`,
`containsAll`, `isEmpty`, `fromRaw`, and `toRaw`. It must preserve unknown bits. Named common sets
such as `.color_attachment`, `.host_upload`, and `.all_graphics` can improve common call sites
without hiding Vulkan semantics.

Acceptance criteria:

- A basic renderer uses no raw bitwise OR or `@intCast` for Vulkan flags.
- Unknown extension bits survive conversion.
- Flag types are not interchangeable across domains.

Priority: **P0**.

### FOUND-03: `VkBool32` leaks into queries and features

Core feature structures and several property structures expose `VkBool32`. The example library has
to define its own `boolName(raw.VkBool32)` helper. Consumers should receive Zig `bool` values.

Recommended design:

- Generate typed feature/property views with `bool` fields or boolean accessors.
- Convert to `VkBool32` only when building raw create infos.
- Keep a `raw()` accessor for extensions the wrapper does not know.

Priority: **P0**.

### FOUND-04: `pNext` remains an untyped lifetime puzzle

`InstanceOptions`, `DeviceQueueOptions`, `DeviceOptions`, `SwapchainOptions`, `PresentOptions`, and
debug label options expose `?*const anyopaque`. `PhysicalDevice.features2` accepts mutable
`?*anyopaque`. This forces consumers to set `sType`, link nodes in the correct direction, ensure
mutability, avoid duplicate structure types, and preserve every node's address.

Recommended design:

1. Generate metadata for every extensible input/output structure: its `sType`, direction, valid
   parent structures, and whether duplicates are legal.
2. Provide a caller-owned `Chain` or `FeatureChain` that initializes and links nodes.
3. Separate input chains from output chains at the type level.
4. Let common option structs accept typed extension configuration directly.
5. Keep `.next_raw` only in explicitly advanced option types.

Illustrative API:

```zig
var supported = vk.FeatureChain(.{
    vk.features.Vulkan12,
    vk.features.Vulkan13,
    vk.features.DescriptorIndexing,
}).init();
try physical_device.queryFeatures(&supported);

if (supported.get(.Vulkan13).dynamic_rendering) {
    supported.getPtr(.Vulkan13).synchronization2 = true;
}

var device = try physical_device.createDevice(.{
    .queues = &queues,
    .features = supported.enabled(),
});
```

Priority: **P0** for feature chains and common extension chains; **P2** for arbitrary registry
chains.

### FOUND-05: Extension metadata stops at the name

Generated `Extension` values contain only a sentinel-terminated name. Consumers must separately
know whether an extension is instance/device scoped, its dependencies, promotion version,
required feature structures, and command aliases.

Recommended generated metadata:

```zig
pub const khr_swapchain: Extension = .{
    .name = "VK_KHR_swapchain",
    .scope = .device,
    .requires = &.{extension.khr_surface},
    .commands = &.{ ... },
};
```

Add typed extension sets for instance and device scopes so an instance extension cannot be passed
to `DeviceOptions`. Provide optional dependency expansion, but never silently enable features.

Priority: **P1**.

### FOUND-06: Promoted command aliases are resolved inconsistently

`features2` explicitly falls back from `vkGetPhysicalDeviceFeatures2` to its KHR alias. The general
command descriptor contains one name and no alias/promotion metadata. A consumer targeting an older
core version plus an extension may have to know and load the extension spelling manually.

Generate descriptors with all aliases and promotion information, then let internal loading try the
valid spellings in a deterministic order.

Priority: **P1**.

### FOUND-07: Result and status mapping is incomplete

`checkSuccess` is useful for a small set of common errors, while `AcquireResult` and
`PresentStatus` correctly model command-specific statuses. Most unwrapped commands return statuses
that must not be fed to `checkSuccess`.

Missing families include:

- fence and event readiness;
- query availability;
- pipeline compile-required/deferred-operation statuses;
- descriptor-pool exhaustion and fragmentation;
- external-handle and opaque-capture errors;
- full-screen-exclusive loss;
- video-profile and video-picture errors;
- compression exhaustion;
- thread idle/done and operation deferred/not-deferred statuses; and
- extension-specific success/status codes.

Each wrapper method should return a command-specific tagged union or Zig error set. Expand the
shared error mapping for genuinely common fatal errors, but do not create one giant result enum.

Priority: **P0** for core synchronization/submission; **P1** for full core; **P2** for extensions.

### FOUND-08: Owning wrapper values are freely copyable

`Instance`, `Device`, `Surface`, `Swapchain`, and `Messenger` are returned by value and contain their
own live handle. `deinit` is idempotent for one value, but copying the struct produces two values
that can each destroy the same object. The underscore-prefixed fields are a convention, not an
enforced privacy boundary in a public Zig struct.

Recommended direction:

- Document all owning values as non-copyable immediately.
- Prefer initialization into final storage when an object retains pointers into caller state.
- Consider a shared device/instance dispatch owner with small typed handle values whose destruction
  is mediated through one owner.
- Add debug-only generation tokens or ownership state where practical.
- Keep borrowed handles visibly distinct from owned resources.

This is broader than raw-API leakage, but it directly affects whether the idiomatic wrapper is safe
to use.

Priority: **P1**.

### FOUND-09: Allocation callbacks appear in normal option structs

`VkAllocationCallbacks` is an advanced C callback ABI. It is rarely used and makes nearly every
owning option type expose raw Vulkan.

Recommended design:

- Remove it from ordinary option structs.
- Put it in `AdvancedOptions`, `RawOptions`, or a typed `AllocationCallbacks` adapter.
- If a typed adapter is added, own the private C trampolines just as debug-utils now does.

Priority: **P2**.

### FOUND-10: The handwritten wrapper does not scale to the registry

The raw ABI and descriptors regenerate automatically, but typed enums, flags, object wrappers, and
extension-chain metadata are handwritten. Exhaustive coverage of 234 core commands and hundreds of
extensions will drift unless more of the idiomatic layer is generated.

Recommended architecture:

1. Keep `vulkan_raw.zig` as the exact target ABI.
2. Keep `vulkan_commands.zig` for PFN/name/scope metadata.
3. Generate a new `vulkan_types.zig` containing typed enums, flag sets, result metadata, extension
   metadata, handle categories, structure-chain metadata, and aliases.
4. Handwrite ownership, validation, error mapping, and ergonomic workflows in `vulkan.zig`.
5. Generate compile-time conformance tests between typed values and raw constants.

Priority: **P0**, because it reduces the cost and inconsistency of every later phase.

### FOUND-11: Common Vulkan value structures remain C-shaped

Even after enums and flags are typed, ordinary code will still encounter `VkExtent2D/3D`,
`VkOffset2D/3D`, `VkRect2D`, `VkViewport`, `VkClearValue`, component mappings, subresource layers
and ranges, buffer/image copy regions, memory requirements, and specialization-map entries.

Recommended design:

- define small plain Zig value types with `snake_case` fields and sensible defaults;
- add explicit internal `toRaw`/`fromRaw` conversion;
- use tagged unions for values such as color versus depth/stencil clears;
- use slices for region lists; and
- retain raw accessors for zero-copy FFI integration.

These types should be trivially copyable and allocation-free. They form the shared vocabulary for
resources, command recording, synchronization, and presentation.

Priority: **P0**.

### FOUND-12: Enumeration APIs require allocation

The convenience enumeration methods allocate their result through a caller-provided allocator.
That is appropriate during startup, but it is the only wrapped path for instance extensions,
layers, physical devices, device extensions, queue families, surface formats, present modes, and
swapchain images. A consumer with fixed storage or an allocation-free control path must either
allocate anyway or call the raw count/data commands.

Provide both forms:

```zig
const count = try physical_device.surfaceFormatCount(surface);
var storage: [surface_format_count_max]vk.SurfaceFormat = undefined;
const formats = try physical_device.surfaceFormatsInto(surface, &storage);

// Retain the existing allocating convenience.
const owned = try physical_device.surfaceFormatsAlloc(allocator, surface);
```

The `Into` methods should:

- use the same bounded retry policy as the allocating helpers;
- return `error.BufferTooSmall` with the required count, or use a result union carrying it;
- initialize only the returned prefix;
- distinguish a driver-reported count from the caller's capacity;
- avoid hidden fallback allocation; and
- support a fixed-capacity collection without requiring a temporary raw structure slice.

This is needed by Bloc's fixed-capacity renderer policies and is also a general systems-library
requirement.

Priority: **P1** for core/WSI enumeration; **P2** for specialty extensions.

### FOUND-13: Device requirements and enabled capabilities are not one typed contract

vk-zig can enumerate properties and create a device, but a consumer must independently coordinate
API version, extensions, feature bits, queue requirements, command availability, promotion rules,
and platform-specific requirements. Bloc implements its own explicit rejection record and then
stores a separate immutable capability structure. That policy is good, but the Vulkan mechanics
are repeated by every renderer.

Add a neutral, non-scoring requirements layer:

```zig
const requirements: vk.DeviceRequirements = .{
    .minimum_api_version = .v1_1,
    .extensions = .{ .required = &.{vk.extension.khr_swapchain} },
    .queues = &.{ .graphics, .present_to(surface) },
    .features = feature_request,
    .commands = &.{ .queue_submit, .queue_present_khr },
};

const evaluation = try physical_device.evaluate(requirements);
if (!evaluation.suitable()) logEvaluation(evaluation);
const device = try physical_device.createDeviceFromEvaluation(evaluation, .{});
const enabled = device.capabilities();
```

The wrapper should own dependency/promotion validation and produce structured rejection reasons.
It should not choose scoring weights, prefer one GPU class, or decide whether unified queues are
better; those remain application policy. The created `Device` should retain a read-only record of
what the wrapper actually enabled so later code does not confuse support with enablement.

Priority: **P1**.

### FOUND-14: External synchronization and thread-use contracts are undocumented

Vulkan places external-synchronization requirements on queues, command pools, descriptor pools,
pipeline caches, and many object mutations. A Zig wrapper method looks like an ordinary safe
method, but its type does not communicate whether concurrent calls are valid. Bloc deliberately
allows workers to generate CPU data while keeping Vulkan submission and uploads on the main
thread; users need enough wrapper documentation to enforce such a boundary correctly.

For every object and method, generate or document:

- whether the object or a parent must be externally synchronized;
- whether different child objects may be used concurrently;
- whether the method only reads immutable driver state;
- which handles must remain alive until GPU completion; and
- which host access requires a flush/invalidate or host/GPU ordering operation.

Do not add hidden mutexes. Optional debug ownership/thread tokens may detect obvious misuse, but
the release API should preserve Vulkan's explicit threading model.

Priority: **P1** for core objects and queues; **P2** for extensions.

### FOUND-15: Device-loss and runtime-failure behavior is not a coherent object policy

`error.DeviceLost` exists, but most resource and command methods do not exist yet, and there is no
documented rule for the state of wrappers after loss. Bloc's robustness plan injects failures
during uploads, submission, resize, minimize, and shutdown. Merely mapping `VK_ERROR_DEVICE_LOST`
is not enough for that consumer.

Required behavior:

- every relevant method maps device loss consistently;
- `Device` exposes an observable lost state after the first confirmed loss;
- cleanup remains locally safe and idempotent even when driver calls cannot make progress;
- waits distinguish timeout, not-ready, device-lost, and success;
- submission/presentation statuses preserve the operation that failed;
- diagnostic extensions such as device fault can be queried through a typed optional path; and
- the wrapper documents that recreating the logical device and resources is application policy.

The wrapper should not promise transparent recovery. It should make failure classification and
teardown predictable.

Priority: **P1**.

### FOUND-16: Consumers build private dispatch tables for ordinary commands

The generated command descriptors make manual loading safer, but ordinary consumers still create
private structs of PFNs and call `device.require` command by command. Bloc's current first-clear
work loads 16 device commands this way before it can create synchronization, allocate a command
buffer, create image views, record barriers, and clear an image.

Wrapper methods should be backed by a generated internal dispatch surface that understands:

- command scope;
- core version versus extension availability;
- promoted aliases;
- optional versus mandatory commands; and
- the feature/extension contract recorded on the instance or device.

This does not require eagerly resolving every extension command. Dispatch may be grouped or lazy,
but a consumer using a supported wrapper method should never manipulate a PFN type or maintain a
parallel command table.

Priority: **P0** for core/WSI methods; **P1** for common extensions.

## Functionality-by-functionality audit

### 0. Build integration and platform declaration selection

Current state:

- the package forwards target and optimization mode correctly;
- bindings regenerate deterministically from vendored inputs;
- platform-specific declarations are selected through a dependency option; and
- normal package setup does not require `vk.raw`.

Remaining friction:

- selecting Xlib/XCB/Wayland also requires external C development headers;
- the configured platform controls declarations but provides no corresponding typed surface
  constructor; and
- applications that support more than one Linux window backend in one binary cannot request a
  combined declaration set.

Recommended additions:

- allow a set of platform declaration groups instead of exactly one where headers are available;
- expose a generated capability such as `vk.platform_support.xcb`; and
- connect enabled declaration groups to typed surface constructors.

Raw use required: **No** during package setup, but **Yes** when the selected declarations are used
to create a surface.

Priority: **P2** for multi-backend declarations; surface constructors remain **P0**.

### 1. Loader discovery and library lifetime

Current state:

- `Loader.init`, `initFromPath`, `entry`, and `deinit` are idiomatic.
- Loader errors are meaningful Zig errors.
- Applications do not need to link the loader directly.

Remaining gaps:

- No API reports attempted paths or the successfully selected runtime.
- `VulkanLoaderNotFound` has no diagnostic payload, which makes deployment failures harder to
  explain.

Suggested additions:

- `Loader.initWithDiagnostics(*LoaderDiagnostics)`.
- `Loader.path()` or a stable runtime description when available.

Raw use required: **No** for ordinary loading.

Priority: **P2**.

### 2. Command discovery and dispatch

Current state:

- Generated descriptors prevent PFN/name mismatches and wrong dispatch scope.
- `load` and `require` are safer than hand-written procedure-name strings.

Raw boundary:

- Every unwrapped command returns its raw PFN signature.
- The consumer constructs raw inputs, passes raw handles, and maps raw results.
- Core commands are not loaded as a complete typed dispatch surface.

Recommended design:

- Wrapper methods for all core functionality.
- Generated alias-aware loading used internally.
- Keep `load` and `require` for advanced extensions and FFI only.

Priority: **P0**.

### 3. API versions

Current state:

- `Version` is a good typed representation.
- Loader API-version enumeration is wrapped.

Gaps:

- Device property APIs return encoded raw version fields, requiring consumers to call
  `Version.decode` manually.
- No named constants such as `Version.v1_0` through `Version.v1_4`.
- No comparison/order helpers.

Recommended additions:

- `Version.v1_0`, `.v1_1`, `.v1_2`, `.v1_3`, `.v1_4`.
- `atLeast`, `lessThan`, and a Zig 0.16 `format` method.
- Typed physical-device properties should expose decoded versions.

Priority: **P2**.

### 4. Instance extensions and layers

Current state:

- Enumeration retries and allocation ownership are handled correctly.
- Names have bounded borrowed helpers.
- Common validation/debug requests are resolved independently.

Raw boundary:

- Enumeration returns `VkExtensionProperties` and `VkLayerProperties`.
- Consumers access raw `specVersion`, `implementationVersion`, and encoded fields.
- `supportsExtension` and `supportsLayer` only accept raw slices.

Recommended types:

```zig
pub const ExtensionProperty = struct {
    name: []const u8,
    revision: u32,
};

pub const LayerProperty = struct {
    name: []const u8,
    description: []const u8,
    spec_version: Version,
    implementation_version: u32,
};
```

Because names are embedded in raw structs, either return owned typed records with fixed bounded
arrays or expose typed borrowed views tied to an owning enumeration object.

Priority: **P1**.

### 5. Instance creation

Current state:

- Application and engine strings/versions are idiomatic.
- Layer and extension names are slices.
- portability and typed debug messenger configuration are automated.

Raw boundary:

- flags, `application_next`, `next`, and allocation callbacks are raw.
- all instance extensions other than debug utils require manual chain construction.
- validation features, validation flags, layer settings, portability subsets, and other common
  instance configuration have no typed options.

Recommended design:

- Keep the current simple options.
- Add typed fields for validation features and layer settings.
- Replace generic `.next` with a generated input chain.
- Move `.next_raw` and allocation callbacks into advanced options.

Priority: **P1**.

### 6. Physical-device enumeration and selection

Current state:

- Physical-device handles are wrapped and tied to an instance dispatch.
- Enumeration allocation and unstable counts are handled.

Raw boundary:

- Device selection uses raw properties, limits, UUIDs, IDs, and device-type constants.
- The example defines its own conversion from `VkPhysicalDeviceType` to text.
- There is no reusable suitability/scoring API.

Recommended design:

- `PhysicalDevice.properties() -> PhysicalDeviceProperties` with typed `DeviceType`, `Version`,
  UUID/LUID wrappers, driver information, limits, and sparse properties.
- Convenience predicates such as `isDiscrete`, `supportsApiVersion`, and `name`.
- Keep `propertiesRaw` for unsupported extension fields.

Priority: **P0**.

### 7. Format and image-format capability queries

Current state: no wrapper.

Consumers must manually load and call:

- `vkGetPhysicalDeviceFormatProperties` and `...Properties2`;
- `vkGetPhysicalDeviceImageFormatProperties` and `...Properties2`;
- sparse image-format property queries; and
- DRM/modifier or external-image format extension queries.

Recommended design:

- typed `Format`, `FormatFeatures`, `ImageTiling`, `ImageType`, `ImageUsage`, and sample counts;
- `physical_device.formatProperties(format)`;
- `physical_device.imageFormatProperties(options) -> ?ImageFormatProperties`, where unsupported
  combinations are a normal optional/status rather than a generic error; and
- typed extension chains for external memory and DRM modifiers.

Priority: **P0** for core format queries; **P2** for platform modifiers.

### 8. Features and properties chains

Current state:

- Core `features()` and a raw `features2(next)` call exist.
- The wrapper initializes the root `VkPhysicalDeviceFeatures2` structure.

Raw boundary:

- All returned booleans are `VkBool32`.
- Every Vulkan 1.1–1.4 or extension feature requires raw structs, `sType`, `pNext`, and mutable
  storage.
- Enabling queried features in `DeviceOptions` requires another raw chain.

Recommended design:

- generated typed feature structs using Zig booleans;
- a chain that can be queried, filtered, and reused for device creation;
- explicit validation that requested features were reported as supported; and
- helpers for common profiles such as Vulkan 1.3 dynamic rendering + synchronization2.

Priority: **P0**.

### 9. Queue-family discovery

Current state:

- Queue family indices and common capabilities are partly typed.
- Presentation support returns Zig `bool`.

Raw boundary:

- `QueueFamily.properties` is raw.
- Timestamp validity, transfer granularity, video capabilities, optical-flow capabilities, and
  global priorities require raw access.
- `family_index` remains a plain `u32`, so it is easy to mix with queue indices or image indices.

Recommended design:

- distinct `QueueFamilyIndex` and `QueueIndex` non-exhaustive integer enums;
- typed `QueueCapabilities` flags;
- direct accessors for timestamp bits and minimum transfer granularity;
- a generated property-chain query for extended queue properties; and
- a queue-selection helper that accepts required/preferred capabilities and presentation needs.

Priority: **P0**.

### 10. Logical-device and queue creation

Current state:

- Queue priorities are slices and validated.
- Duplicate queue families are rejected.
- MoltenVK portability-subset enabling is automated.

Raw boundary:

- queue flags, device flags, feature pointers, `pNext`, and allocation callbacks are raw.
- protected queues, global priorities, device groups, and queue creation extensions require raw
  chains.
- enabled extensions are strings without dependency/feature validation.

Recommended design:

- typed queue-family/index types and queue-create flags;
- typed feature chain;
- typed device-extension set with scope/dependency validation;
- typed device-group and global-priority options; and
- expose the negotiated enabled-feature/extension set from `Device`.

Priority: **P0**.

### 11. Memory properties and memory-type selection

Current state:

- A useful memory-type scoring helper exists.
- Missing memory types become a Zig error.

Raw boundary:

- physical memory properties, heap flags, type flags, and memory requirements are raw.
- examples use `VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT` and `...HOST_COHERENT_BIT`.
- memory budgets, priorities, dedicated allocation requirements, and external-memory properties
  are not wrapped.

Recommended design:

- typed `MemoryProperties`, `MemoryHeapFlags`, `MemoryType`, and `MemoryHeap` views;
- `MemoryRequirements` wrapper returned by buffers/images;
- `MemoryPreference` presets such as `.device_local`, `.upload`, and `.readback`;
- optional budget/priority extension support; and
- distinct `MemoryTypeIndex`.

Priority: **P0**.

### 12. Device memory allocation and mapping

Current state: no wrapper.

Raw operations required:

- allocate/free memory;
- bind buffer/image memory, including `*Memory2` variants;
- map/unmap memory, including Vulkan 1.4 variants;
- flush/invalidate mapped ranges;
- query commitment and opaque capture addresses; and
- import/export external memory.

Recommended ownership model:

```zig
var memory = try device.allocateMemory(.{
    .size = requirements.size,
    .memory_type = memory_type,
});
defer memory.deinit();

var mapped = try memory.map(u8, .{ .offset = 0, .length = .whole });
defer mapped.unmap();
try mapped.flush();
```

`MappedMemory(T)` should provide a bounded slice, track the mapped range, and handle non-coherent
atom-size alignment. Binding should verify parent device and size/alignment requirements.

Do not silently implement a full GPU allocator in the core wrapper. A thin allocator can be a
separate higher-level module later.

Priority: **P0**.

### 13. Buffers and buffer views

Current state: no wrapper. The README's raw-binding example starts with `VkBufferCreateInfo`, which
is the exact point where ordinary rendering leaves the idiomatic API.

Raw operations required:

- create/destroy buffer;
- query memory requirements;
- bind memory;
- create/destroy buffer views;
- retrieve device addresses; and
- use capture-replay or external-memory chains.

Recommended API:

```zig
var buffer = try device.createBuffer(.{
    .size = byte_count,
    .usage = .init(&.{ .vertex, .transfer_dst }),
    .sharing = .exclusive,
});
defer buffer.deinit();

const requirements = try buffer.memoryRequirements();
try buffer.bindMemory(&memory, 0);
```

Add an optional convenience `createBufferWithMemory` in a separate allocation helper, while
preserving explicit memory ownership in the base API.

Priority: **P0**.

### 14. Images, image views, and subresource layouts

Current state:

- Swapchain images are enumerated, but returned as raw `VkImage` handles.
- No owned image or image-view wrapper exists.

Raw operations required:

- image creation/destruction;
- memory requirements and binding;
- image-view creation/destruction;
- subresource layout queries;
- sparse image requirements; and
- host image copy/transition functionality in Vulkan 1.4.

Recommended design:

- `Image` for owned images and `BorrowedImage` for swapchain images;
- typed extent, format, image type, tiling, usage, samples, layouts, aspects, and subresource
  ranges;
- `ImageView` tied to its parent device/image provenance;
- swapchain `images()` returns typed borrowed images; and
- command-buffer transition/copy APIs accept both owned and borrowed images.

Priority: **P0**.

### 15. Samplers and YCbCr conversion

Current state: no wrapper.

Raw operations required for sampler creation, filtering, addressing, anisotropy, compare mode,
border colors, reduction modes, custom border colors, and YCbCr conversion.

Recommended design:

- typed `SamplerOptions` with Zig enums and booleans;
- owned `Sampler` and `SamplerYcbcrConversion`;
- validation against enabled features and physical-device limits where possible; and
- typed extension configuration for custom border/reduction modes.

Priority: **P1** for normal samplers; **P2** for YCbCr/extensions.

### 16. Shader modules and shader objects

Current state: no wrapper.

Raw operations required for SPIR-V module creation, module identifiers, shader-object creation, and
shader binaries.

Recommended design:

```zig
var shader = try device.createShaderModule(.{ .spirv = words });
defer shader.deinit();
```

Validate byte length/alignment, accept `[]align(4) const u8` or `[]const u32`, and own only the
Vulkan module—not the source slice. Add `ShaderStage` and typed specialization constants.

Priority: **P0** for shader modules; **P2** for shader objects/identifiers.

### 17. Descriptor set layouts, pools, sets, and updates

Current state: no wrapper.

Raw operations required:

- descriptor set layout creation/support queries;
- descriptor pool creation/reset/destruction;
- descriptor allocation/free;
- descriptor writes/copies;
- update templates and push descriptors; and
- descriptor-buffer extension functionality.

Recommended design:

- owned `DescriptorSetLayout` and `DescriptorPool`;
- borrowed `DescriptorSet` whose validity is tied to its pool generation;
- typed binding declarations with `ShaderStages` and `DescriptorType`;
- update methods using tagged unions for buffer/image/texel/acceleration-structure descriptors;
- pool-reset generation tracking to detect stale sets in Debug builds; and
- slice-based batch updates that build pointer/count arrays internally.

Priority: **P0** for layouts/pools/sets/updates; **P1** for templates/push descriptors; **P2** for
descriptor buffer.

### 18. Pipeline layouts and push constants

Current state: no wrapper.

Raw operations required for layout creation/destruction and command-buffer push constants.

Recommended design:

- owned `PipelineLayout` built from typed descriptor layouts and push-constant ranges;
- typed shader-stage flags;
- `command_buffer.pushConstants(layout, stages, offset, bytes)` with alignment/range validation;
- generic `pushConstantsValue(T, ...)` for extern/packed-compatible data only.

Priority: **P0**.

### 19. Graphics and compute pipelines

Current state: no wrapper.

Raw operations required for every pipeline state structure, shader stage, specialization info,
pipeline creation result, cache, executable properties, and pipeline binaries.

Recommended design:

- `GraphicsPipelineOptions` and `ComputePipelineOptions` composed from typed state structs;
- slices instead of pointer/count pairs;
- explicit dynamic-state list;
- owned `Pipeline` and `PipelineCache`;
- batch creation returning per-pipeline results without leaking partially created handles;
- typed pipeline compile-required/deferred statuses; and
- optional builders only where they prevent invalid pointer lifetimes—plain option structs should
  remain the default.

Priority: **P0** for basic graphics/compute pipelines; **P1** for cache/binaries/executable info;
**P2** for extension pipeline families.

### 20. Render passes and framebuffers

Current state: no wrapper.

Raw operations required for legacy render passes, render pass 2, subpasses, dependencies,
framebuffers, imageless framebuffers, and render-area granularity.

Recommended design:

- owned `RenderPass` and `Framebuffer`;
- typed attachment descriptions/references and subpass dependencies;
- internal pointer graph construction from caller slices;
- command-buffer begin/next/end methods; and
- preserve this path for compatibility even if dynamic rendering is the preferred modern API.

Priority: **P1** after dynamic rendering.

### 21. Dynamic rendering

Current state: no wrapper despite promotion to Vulkan 1.3.

Raw operations required for rendering attachments, load/store operations, clear values, render
areas, view masks, attachment locations, and input attachment indices.

Recommended API:

```zig
try command_buffer.beginRendering(.{
    .render_area = .{ .extent = swapchain.extent() },
    .color_attachments = &.{.{
        .view = &swapchain_view,
        .layout = .color_attachment_optimal,
        .load = .clear(.{ 0.1, 0.1, 0.1, 1.0 }),
        .store = .store,
    }},
});
defer command_buffer.endRendering() catch {};
```

Priority: **P0**.

### 22. Command pools and command buffers

Current state:

- Only debug labels accept command buffers, and those parameters are raw handles.
- No allocation, recording-state, reset, or ownership wrapper exists.

Raw operations required for pool creation/reset/destruction, command-buffer allocation/free,
begin/end/reset, primary/secondary inheritance, and every recording command.

Recommended ownership/state model:

- owned `CommandPool` tied to a `QueueFamilyIndex`;
- `CommandBuffer` tied to its pool generation;
- explicit `.initial`, `.recording`, `.executable`, and `.pending` state checks in Debug builds;
- pool reset invalidates or resets child state;
- typed begin options and secondary inheritance; and
- debug-label methods live directly on `CommandBuffer`.

Priority: **P0**.

### 23. Draw and compute command recording

Current state: no wrapper.

Raw operations required for pipeline/descriptors/vertex/index binding, viewport/scissor and dynamic
state, draw variants, indirect/count variants, dispatch variants, and secondary execution.

Recommended design:

- methods on `CommandBuffer` using typed wrapper objects;
- Zig slices for vertex buffers, offsets, viewports, scissors, and descriptor sets;
- named option structs where multiple same-typed integer parameters are easy to swap;
- distinct byte offsets and index/count types where useful; and
- keep direct methods thin and Vulkan-shaped rather than inventing a render graph.

Priority: **P0**.

### 24. Transfer, clear, blit, and resolve commands

Current state: no wrapper.

Raw operations required for all legacy and `*2` copy variants, buffer updates/fills, image clears,
blits, resolves, host image copies, and image-layout transitions.

Recommended design:

- prefer Vulkan 1.3 `copy*2` and synchronization2-shaped APIs internally, with fallback aliases;
- typed region structures with slices;
- methods accepting typed buffers/images and layouts;
- convenience single-region overloads; and
- validate parent device and bounds where wrapper metadata is available.

Priority: **P0**.

### 25. Synchronization barriers and events

Current state: no wrapper.

Raw operations required for pipeline stages, access masks, dependency flags, memory/buffer/image
barriers, events, and both legacy and synchronization2 commands.

Recommended design:

- typed `PipelineStages2`, `Accesses2`, `DependencyFlags`, and image layouts;
- `DependencyInfo` with slices of typed barriers;
- `command_buffer.pipelineBarrier(options)` backed by synchronization2 when available;
- explicit compatibility layer for legacy barriers; and
- barrier constructors such as buffer ownership transfer and image layout transition that still
  expose source/destination stages and accesses.

Do not infer synchronization silently. The wrapper should remove C boilerplate, not hide hazards.

Priority: **P0**.

### 26. Fences, binary semaphores, and timeline semaphores

Current state:

- acquisition, presentation, and submission accept raw handles.
- no synchronization object is owned by the wrapper.

Raw operations required for create/destroy, status, reset, wait, signal, counter values, timeline
submission, and external semaphore/fence handles.

Recommended design:

- owned `Fence` and `Semaphore` wrappers;
- `Semaphore` tagged as binary or timeline at creation;
- `Fence.status() -> enum { signaled, unsignaled }`;
- `wait` methods returning `.success` or `.timeout`;
- batch fence waits/resets using slices of wrapper pointers/values; and
- timeline wait/signal methods using `u64` values.

Priority: **P0**.

### 27. Queue submission

Current state:

- Queue lifetime and wait-idle are wrapped.
- `Queue.submit` accepts raw `VkSubmitInfo` and raw fence.

Raw boundary:

- semaphore wait stages, command-buffer arrays, timeline values, device masks, and `pNext` are all
  manual.
- `vkQueueSubmit2`, the modern API, is not wrapped.

Recommended design:

```zig
try queue.submit(.{
    .wait = &.{.{
        .semaphore = &image_available,
        .stage = .color_attachment_output,
    }},
    .command_buffers = &.{&command_buffer},
    .signal = &.{.{ .semaphore = &render_finished }},
    .fence = &frame_fence,
});
```

Use synchronization2 internally where supported and provide a deliberate legacy fallback. Validate
that every submitted object belongs to the queue's device.

Priority: **P0**.

### 28. Surface creation and ownership

Current state:

- Once a raw surface exists, `adoptSurface` provides ownership and destruction.
- Surface support/capability queries are partly wrapped.

Raw boundary:

- every Metal, Win32, Xlib, XCB, Wayland, Android, display, DirectFB, QNX, Fuchsia, GGP, VI,
  headless, or other surface must be created manually.
- the consumer loads a raw command, initializes a platform create-info structure, checks the result,
  and then transfers the handle.

Recommended design:

- platform-conditional methods such as `createMetalSurface`, `createWin32Surface`,
  `createXcbSurface`, `createWaylandSurface`, and `createHeadlessSurface`;
- typed option structs that accept native window handles and hide the Vulkan structure;
- a small adapter protocol for window libraries that already create a Vulkan surface; and
- retain `adoptSurface` for RGFW/GLFW/SDL and foreign integrations.

Priority: **P0** for configured build platforms and headless; **P2** for specialty platforms.

### 29. Surface capabilities and swapchain choice

Current state:

- surface support, capabilities, formats, and present modes are queried safely.

Raw boundary:

- returned values are raw structures and constants.
- consumers manually clamp extents/counts and choose formats, transforms, alpha, usage, and mode.

Recommended design:

- typed `SurfaceCapabilities`, `SurfaceFormat`, `PresentMode`, `SurfaceTransform`, and
  `CompositeAlpha`;
- helpers for supported usage/transforms/alpha;
- `chooseSurfaceFormat`, `choosePresentMode`, `clampExtent`, and `chooseImageCount` with explicit
  preferences; and
- preserve all available raw values for custom policy.

Priority: **P0**.

### 30. Swapchain creation, images, acquisition, and presentation

Current state:

- swapchain ownership, rollback, status unions, and old-swapchain validation are good foundations.

Raw boundary:

- most creation fields are raw;
- images are raw handles;
- acquisition uses raw fence/semaphore handles;
- presentation waits on raw semaphore handles; and
- no wrapper creates the image views normally required for rendering.

Recommended design:

- typed swapchain options and defaults derived from queried capabilities;
- typed borrowed swapchain images;
- optional helper to create one image view per image with rollback;
- typed fence/semaphore parameters;
- expose extent, format, color space, and image count on `Swapchain`; and
- support present IDs, present waits, display timing, maintenance1 image release, full-screen
  exclusive, HDR metadata, and incremental present through typed extension options later.

Priority: **P0** for the base path; **P2** for presentation extensions.

### 31. Debug messenger and messages

Current state:

- The normal callback no longer exposes the C ABI.
- Instance creation chaining, extension enabling, lifetime, and destruction are automated.
- Severity checks and message text are typed.

Remaining raw boundary:

- severity and message-type configuration fields are raw flag aliases, though wrapper constants
  avoid raw call sites;
- `Message` publicly stores raw fields/data;
- `objects`, `queueLabels`, and `commandBufferLabels` return raw structures;
- object type, name, label color, object handles, and message types lack typed views; and
- the advanced raw messenger API remains mixed into the same namespace.

Recommended additions:

- typed severity/type flag wrappers;
- `Message.isGeneral`, `isValidation`, `isPerformance`, and `isDeviceAddressBinding`;
- typed borrowed `MessageObject` and `MessageLabel` views;
- hide raw callback data behind `raw()`;
- move raw messenger construction into an `advanced` or `raw_api` namespace.

Priority: **P1**.

### 32. Object names and debug labels

Current state:

- Wrapper objects can be named without manual object-type/handle conversion.
- Queue labels are idiomatic.

Raw boundary:

- almost every nameable object uses a raw handle because its object wrapper is missing.
- command-buffer labels accept raw command-buffer handles.

Recommended design:

- every wrapper object implements a private/common `debugObject()` conversion;
- `device.setObjectName(&object, name)` accepts wrapper objects through a comptime interface or
  generated tagged union;
- command-buffer label methods move to `CommandBuffer`.

Priority: automatically resolved as resource wrappers are added; explicit cleanup is **P1**.

### 33. Query pools, timestamps, and performance counters

Current state: no wrapper.

Raw operations required for query-pool ownership, begin/end/reset, timestamp writes, result flags,
availability, stride/data layout, calibrated timestamps, performance counters, and profiling lock.

Recommended design:

- owned `QueryPool` parameterized/tagged by query kind;
- typed timestamp/query result status;
- safe result buffer sizing and stride calculation;
- `CommandBuffer` query/timestamp methods; and
- extension modules for calibrated timestamps and performance queries.

Priority: **P1** for core queries/timestamps; **P2** for performance extensions.

### 34. Sparse resources and sparse binding

Current state:

- queue capability detection includes sparse binding.
- all sparse property, requirement, and binding operations are raw.

Recommended design:

- typed sparse image properties and memory requirements;
- typed sparse buffer/image bind batches;
- queue `bindSparse` with typed semaphore/fence wrappers; and
- explicit residency/aliasing flags.

Priority: **P2**.

### 35. Device groups and multi-GPU

Current state: no wrapper.

Raw operations required for physical-device-group enumeration, device-group creation, peer memory,
device masks, split-instance binding, present capabilities/modes, and group surface modes.

Recommended design:

- `PhysicalDeviceGroup` enumeration;
- typed device-group options on device creation;
- command-buffer device masks and group submission options; and
- typed group-present queries.

Priority: **P2**.

### 36. External memory, semaphores, fences, and platform handles

Current state: no wrapper.

All capability queries, import/export chains, file descriptors, Win32 handles, Zircon handles,
Android hardware buffers, DMA-BUF/DRM modifiers, Metal objects, and host pointers are raw.

Recommended design:

- typed external-handle enums/flags;
- platform-conditional import/export option structs;
- ownership-transfer semantics for OS handles stated in each method;
- command-specific result/error mapping; and
- a dedicated `external` namespace rather than bloating base resource options.

Priority: **P2**.

### 37. Pipeline caches, binaries, and deferred operations

Current state: no wrapper.

Raw operations required for cache creation/data/merge, pipeline binaries, deferred operations, and
compile-required statuses.

Recommended design:

- owned `PipelineCache`, `PipelineBinary`, and `DeferredOperation`;
- allocator-aware cache-data retrieval;
- typed asynchronous/deferred join status; and
- partial pipeline creation rollback.

Priority: **P1** for caches; **P2** for binaries/deferred operations.

### 38. Ray tracing and acceleration structures

Current state: generated ABI/descriptors only.

Raw operations required for acceleration-structure ownership/build/copy/serialization, build-size
queries, device addresses, ray-tracing pipelines, shader-group handles, stack sizes, trace commands,
micromaps, and NV/KHR variants.

Recommended design:

- a separate `ext.ray_tracing` module built on typed buffers, memory, command buffers, barriers,
  descriptors, and pipelines;
- owned acceleration structures/micromaps;
- typed geometry tagged unions; and
- explicit scratch/storage lifetime rules.

Priority: **P3** until the core resource/command model is stable, then **P2**.

### 39. Mesh/task shading and fragment shading rate

Current state: generated ABI/descriptors only.

Raw operations required for feature/property chains, mesh draw commands, shading-rate images,
fragment-shading-rate attachments, combiners, and vendor variants.

Recommended design: focused extension modules sharing generated typed features, command buffers,
images/views, and pipeline-state types.

Priority: **P2**.

### 40. Vulkan Video

Current state:

- video headers and commands are generated.
- no typed video wrapper exists.

Raw operations required for video profiles/capabilities/formats, session/session-parameter ownership,
memory binding, coding scopes, decode/encode operations, quality levels, and codec-specific chains.

Recommended design:

- a separate `video` namespace;
- typed session ownership and bound memory;
- codec/profile tagged unions backed by generated video registry data; and
- command-buffer coding/decode/encode methods.

Priority: **P3**.

### 41. Device-generated commands, shader objects, descriptor buffer, and execution graphs

Current state: generated ABI/descriptors only.

These modern alternatives change pipeline/descriptor/dispatch models substantially. They should
not be forced into base pipeline APIs prematurely.

Recommended design:

- separate extension modules;
- share typed shader stages, buffers, device addresses, command buffers, and synchronization;
- represent indirect layouts and execution sets as owned objects; and
- preserve feature/extension requirements in generated metadata.

Priority: **P3**.

### 42. Optical flow, tensors, cooperative matrices/vectors, and ARM data graphs

Current state: generated ABI/descriptors only.

The current registry contains these specialized command families, including object ownership,
memory requirements, binding, format/property enumeration, and execution commands. Every operation
requires raw Vulkan.

Recommended design: independent extension modules only after the foundational typed generator,
resource ownership, memory binding, and command-buffer APIs exist.

Priority: **P3**.

### 43. Display, full-screen, HDR, latency, and presentation extensions

Current state:

- only KHR surface/swapchain fundamentals are partly wrapped.
- direct display, display modes/planes, display power, full-screen exclusive, HDR metadata,
  present wait/ID, display timing, low latency, anti-lag, and out-of-band queue notification are raw.

Recommended design:

- typed submodules grouped by extension rather than one enormous swapchain type;
- extension options attached to surface/swapchain/present operations through typed chains; and
- explicit status unions for timing, latency, and full-screen loss.

Priority: **P2**.

### 44. Tooling, private data, fault reporting, checkpoints, and diagnostics extensions

Current state:

- debug utils is partly wrapped.
- tooling properties, private data slots, device faults, checkpoints, validation cache, debug report,
  shader instrumentation, and performance markers are raw.

Recommended design:

- typed `ToolProperty` enumeration and `DeviceFault` report retrieval;
- owned `PrivateDataSlot` and validation cache;
- leave deprecated debug-report/debug-marker APIs raw unless compatibility demand exists; and
- focused vendor diagnostic modules.

Priority: **P1** for device fault/tool properties; **P3** for deprecated/vendor diagnostics.

### 45. Allocation callbacks

Current state: raw callback structures appear in instance, device, surface, swapchain, and messenger
ownership APIs.

Consumer burden:

- define exact C callbacks;
- manage user data and thread safety;
- return correct allocation scopes/types; and
- keep callback state alive for every child object.

Recommended design: either keep this exclusively in advanced raw APIs or provide a typed callback
adapter with private C trampolines. It should not make every normal options struct raw.

Priority: **P2**.

## Specialty extension coverage checklist

The generated ABI includes far more extension functionality than can reasonably live in one base
namespace. The following registry families were checked explicitly. All currently require raw
Vulkan except the partial debug-utils and KHR surface/swapchain paths described above.

| Extension family | Current wrapper status | Recommended home |
| --- | --- | --- |
| Platform surfaces: Metal, Win32, Xlib, XCB, Wayland, Android, Fuchsia, QNX, DirectFB, GGP, VI, headless | Raw creation, then `adoptSurface` | `surface` plus platform-conditional constructors |
| Direct display, display modes/planes, display control, DRM display, acquire-Xlib-display | Raw | `ext.display` |
| Swapchain maintenance, image release, present ID/wait, incremental present, display timing | Raw | `ext.presentation` |
| Full-screen exclusive, HDR metadata, local dimming, low latency, anti-lag | Raw | `ext.presentation` and vendor submodules |
| External memory/semaphore/fence capability queries | Raw | `external` |
| FD, Win32, Zircon, Android hardware buffer, DMA-BUF/DRM, Metal, QNX/NvSci import/export | Raw | platform-conditional `external.*` modules |
| Memory budget, memory priority, pageable memory, dedicated allocation, host pointer | Raw | `ext.memory` |
| Memory decompression and host image copy/transition | Raw | `ext.transfer` / core 1.4 wrappers |
| Descriptor indexing, push descriptors, update templates, mutable descriptors | Raw | base descriptors plus `ext.descriptor` |
| Descriptor buffer and embedded immutable samplers | Raw | `ext.descriptor_buffer` |
| Shader modules, module identifiers, shader objects, binary import | Raw | base shader module plus `ext.shader` |
| Graphics pipeline libraries, pipeline properties/executables, pipeline binaries | Raw | base pipeline plus `ext.pipeline` |
| Dynamic rendering, local read, attachment locations, unused attachments | Raw | base dynamic rendering plus extension options |
| Extended dynamic state families and vertex-input dynamic state | Raw | command-buffer dynamic-state methods |
| Transform feedback and conditional rendering | Raw | `ext.transform_feedback` / `ext.conditional_rendering` |
| Fragment shading rate, shading-rate image, fragment density map | Raw | `ext.fragment_shading_rate` |
| Sample locations, coverage modulation/reduction, representative fragment test | Raw | focused rasterization extension modules |
| Mesh/task shaders | Raw | `ext.mesh_shader` |
| Ray tracing pipelines and acceleration structures | Raw | `ext.ray_tracing` |
| Opacity micromaps, cluster/partitioned acceleration structures | Raw | ray-tracing vendor submodules |
| Vulkan Video queue, sessions, decode/encode, codec parameter families | Raw | `video` |
| Performance query, INTEL performance API, calibrated timestamps, profiling lock | Raw | `profiling` |
| Checkpoints, device fault, tooling properties, shader info/instrumentation | Raw | `diagnostics` and vendor submodules |
| Validation cache, debug report, debug marker | Raw; debug utils supersedes part of this | `advanced` compatibility modules |
| Private data slots | Raw | base utility wrapper or `ext.private_data` |
| Device groups, peer memory, group present/device masks | Raw | `device_group` |
| Sparse binding and sparse residency | Raw | base sparse-resource module |
| Device-generated commands, indirect execution sets, execution graphs | Raw | `ext.device_generated_commands` |
| CUDA modules/functions and NV binary import | Raw | `interop.cuda` |
| External compute queues | Raw | vendor interop module |
| Cooperative matrices/vectors | Raw | `ext.cooperative` |
| Optical-flow sessions | Raw | `ext.optical_flow` |
| Tensor objects/views and tensor memory | Raw | `ext.tensor` |
| ARM data-graph pipelines/sessions | Raw | `ext.data_graph` |
| QCOM tile memory, tile properties, render-pass transforms, invocation masks | Raw | vendor rendering modules |
| Fuchsia buffer collections | Raw | `external.fuchsia` |
| Remote memory addresses and generated memory requirements | Raw | corresponding external/generated-command modules |

This table is a coverage inventory, not a recommendation to handwrite every extension immediately.
The generated vocabulary and chain system should make extension modules possible without requiring
base consumers to learn their raw ABI.

## Recommended wrapper architecture

### Layer 1: exact ABI

Keep the existing generated `vk.raw` module unchanged in purpose. It is the authoritative FFI and
must remain usable independently.

### Layer 2: generated Vulkan vocabulary

Generate:

- non-exhaustive enums;
- domain-specific flag wrappers;
- result/status metadata;
- extension scope/dependency/promotion metadata;
- command aliases;
- handle categories and object types;
- structure `sType` and chain compatibility metadata; and
- feature/property field conversions.

This layer should contain no allocation and almost no runtime logic.

### Layer 3: thin object and command wrappers

Handwrite or generate thin wrappers for:

- ownership and `deinit`;
- parent-device/instance validation;
- slices replacing pointer/count pairs;
- Zig booleans and option structs;
- command-specific status unions;
- rollback of partial creation; and
- borrowed versus owned object distinctions.

The methods should remain recognizably Vulkan. Do not hide synchronization, queue ownership, memory
types, or resource transitions.

### Layer 4: optional conveniences

Keep higher-level policies separate:

- memory suballocation;
- upload staging;
- swapchain selection/recreation;
- descriptor allocation strategies;
- pipeline/shader caching; and
- render graphs.

These can build on the thin wrapper without forcing one engine architecture on all consumers.

## Proposed core object model

The following wrapper types are required for a raw-free core renderer:

| Ownership | Types |
| --- | --- |
| Instance-owned | `Surface`, `DebugMessenger` |
| Device-owned | `DeviceMemory`, `Buffer`, `BufferView`, `Image`, `ImageView`, `Sampler`, `ShaderModule`, `DescriptorSetLayout`, `DescriptorPool`, `PipelineLayout`, `PipelineCache`, `Pipeline`, `RenderPass`, `Framebuffer`, `CommandPool`, `Fence`, `Semaphore`, `Event`, `QueryPool`, `Swapchain` |
| Pool-owned/borrowed | `DescriptorSet`, `CommandBuffer` |
| Externally owned/borrowed | `Queue`, `PhysicalDevice`, `SwapchainImage`/`BorrowedImage` |

Every object should provide:

- a checked `rawHandle()` escape hatch;
- idempotent `deinit` for the same value;
- parent provenance validation;
- clear owned/borrowed documentation;
- debug object naming without a raw union variant; and
- partial-construction rollback.

## Bloc phase-plan cross-check

Bloc is a useful real consumer because its plans describe an incremental renderer from instance
creation through presentation, resource uploads, textured rendering, streaming, profiling, and
cross-platform release. The review included `GAME_PLAN.md`, every `phase/*/PLAN.md`, and the Vulkan
foundation note.

### Evidence from the current Phase 03 implementation

At the review snapshot, `src/render/Presentation.zig` contains 94 `vk.raw` references and a private
dispatch table that manually requires 16 device commands. It has to implement all of the following
outside vk-zig:

- raw `VkDevice`, `VkCommandPool`, `VkCommandBuffer`, `VkSemaphore`, and `VkFence` storage;
- raw creation and destruction for command pools, image views, semaphores, and fences;
- raw command-buffer allocation, begin, reset, end, barriers, and clears;
- raw image, image-view, format, layout, access, stage, usage, aspect, transform, alpha, and present
  values;
- manual `VkSubmitInfo` pointer/count assembly;
- manual timeout and result interpretation;
- raw swapchain-image storage and owned image-view rollback;
- allocation-backed surface and swapchain-image enumeration followed by copying into fixed arrays;
  and
- raw handles for debug naming and command-buffer labels.

This is not a case of Bloc choosing an unusually low-level architecture. It is the minimum work
required by its Phase 03 clear-and-present milestone. The implementation is a concrete
confirmation of Sections 13, 14, and 22 through 32 of this audit.

The Phase 02 context also still needs raw types for the RGFW surface type boundary, feature
booleans, physical memory heaps, memory flags, and physical-device type. The surface handle is a
legitimate FFI boundary; the other uses should be removed by typed vk-zig views.

### Phase-to-feature requirement matrix

| Bloc phase | Vulkan work required | vk-zig support required for a raw-free consumer | Ownership of higher policy |
| --- | --- | --- | --- |
| 00–02: context | loader, instance, diagnostics, surface, device inspection, queues, logical device | typed diagnostics already work; add typed properties/features/memory, device types, extension contracts, queue indices, and a requirements evaluation | Bloc owns device scoring and its immutable renderer capability projection |
| 03: swapchain | surface selection, swapchain, borrowed images, owned views, first command buffer, barriers, clear, submit, present, recreation | typed WSI values, image views, command pool/buffer, fence/semaphore, recording, barriers/clear, submission, statuses, no-allocation enumeration, complete internal dispatch | Bloc owns resize coalescing, minimized-window state, recreate timing, and its preferred fallback policy |
| 04: frame loop | two frames, per-image fence association, reset/wait, deferred destruction | robust fence/semaphore/command-buffer APIs and explicit GPU-lifetime documentation; optional bounded retirement primitive | Bloc owns frame indices, two-frame scheduling, per-image ownership, frame arenas, telemetry, and queue capacities |
| 05: first geometry | shader modules, layouts, graphics pipeline, buffers, memory, staging, copies, depth, push constants, indexed draw | typed resources, memory selection/allocation/map/flush, pipeline descriptions, transfer and draw recording, depth-format query, naming | Bloc owns shader source/build tooling, camera math, upload batch limits, pipeline policy, and CPU/GPU layout contracts |
| 06: materials | texture image, mip upload, view, sampler, descriptors, sampling | image/memory/view/sampler wrappers, descriptor objects and writes, layout transitions, copy/blit support, format-feature queries | Bloc owns atlas packing, decode limits, material registry, mip policy, and descriptor sharing strategy |
| 08–09: chunks | repeated immutable vertex/index uploads, replacement, draw lists, labels | buffer resources, copy/upload commands, indexed draw methods, typed label scopes; optional upload batch and retirement helpers | Bloc owns mesh revisions, stale-result rejection, render registry, culling, batching, and last-use fence selection |
| 10: debug draw | selection outline and development primitives | the same pipeline/resource/command APIs; typed line/triangle draw recording | Bloc owns DDA, geometry generation, and debug-draw capacity |
| 13: streaming | asynchronous CPU work crossing one main-thread upload boundary | no worker-facing Vulkan abstraction is required; resource methods must document external synchronization | Bloc owns jobs, upload publication, state transitions, backpressure, and eviction |
| 15: UI | alpha-blended UI pipeline, per-frame vertex/index batches, font texture, scissor | pipeline blending/dynamic state, buffers, descriptors, image sampling, typed viewport/scissor | Bloc owns layout, text batching, capacities, settings, and pass ordering |
| 17: measurement | timestamps around upload/world/UI passes, availability, reset/readback, labels | typed query pools, timestamp commands/results, `timestampPeriod`, queue-family valid bits, calibrated timestamp extension where used | Bloc owns frame correlation, histograms, reporting, capture workflow, and sampling cadence |
| 18: optimization | secondary command buffers, indirect draws, tighter barriers, pipeline cache if measured | secondary allocation/inheritance, indirect command methods and count variants, synchronization2, pipeline cache serialization | Bloc decides whether measurements justify each feature and owns cache persistence policy |
| 19: robustness | validation, resource failure injection, device errors, platform surfaces, capture | consistent command errors/device-loss behavior, typed platform surface adapters, device-fault/tooling extensions, explicit lifetime/thread contracts | Bloc owns recovery state, platform window integration, fault scenarios, soak tests, and player-facing errors |
| 20: packaging | loader/runtime discovery and portable artifacts | documented loader resolution and platform runtime requirements; optional diagnostics for discovery failure | Bloc owns packaging, assets, MoltenVK distribution guidance, and crash-symbol policy |

Phases 07, 11, 12, 14, and 16 are primarily world, job, persistence, and architecture work. They do
not add Vulkan API surface, although Phase 16 will audit the ownership guarantees of every wrapper
object introduced earlier.

### Requirements the initial audit underemphasized

The phase-plan review found these additional general requirements. They are now represented by
FOUND-12 through FOUND-16:

1. **Caller-provided enumeration storage.** Bloc permits temporary allocation during startup but
   deliberately uses fixed-capacity state for frame and renderer paths. Both allocating and `Into`
   enumeration APIs are necessary; neither should be forced on all consumers.
2. **Requirements versus enablement.** Device support, requested features, enabled features,
   extension dependencies, command availability, and the application capability record are
   distinct. vk-zig should make the first five coherent without taking over application scoring.
3. **External synchronization documentation.** Bloc's “workers never call Vulkan” rule is a sound
   response to Vulkan's threading contract, but users should not have to rediscover that contract
   from the C specification for every wrapper method.
4. **Consistent device-loss semantics.** Bloc explicitly tests submission, upload, resize, and
   shutdown failures. The wrapper needs a predictable lost-device and cleanup policy, not only an
   error enum member.
5. **Generated internal dispatch coverage.** The need for a 16-command private table in the first
   presentation milestone proves that command descriptors alone are not an ergonomic dispatch
   layer.

The plans also sharpen several already-recorded requirements:

- queue-family indices, swapchain-image indices, counts, byte sizes, and frame indices must not be
  interchangeable integers;
- borrowed swapchain images and owned image views need visibly different types;
- `Fence.wait` must distinguish timeout from device loss and support a bounded timeout;
- query timestamps need availability, delayed readback, reset/wrap behavior, `timestampPeriod`, and
  per-family `timestampValidBits`, not only query-pool creation;
- secondary command buffers need typed inheritance information;
- indirect drawing needs typed `DrawIndirectCommand`/`DrawIndexedIndirectCommand` slices and count
  variants where available;
- depth-format selection must expose format-feature support rather than embed a preferred list;
- pipeline options should be hashable/serializable enough for application-owned caching without
  exposing raw create-info pointers; and
- platform surface integration needs a checked adapter point so RGFW remains the only cross-package
  handle-conversion boundary.

### What belongs in vk-zig

These are general Vulkan mechanics and should be in the base wrapper:

- generated enums, flags, values, chains, command aliases, and results;
- typed object ownership and borrowed handles;
- instance/device dispatch and command availability;
- resource creation/destruction and memory operations;
- command allocation, recording, reset, and submission;
- synchronization primitives and status mapping;
- surface/swapchain queries, objects, acquisition, and presentation;
- typed debug naming/labels for every wrapped object;
- allocation-backed and caller-storage enumeration variants;
- neutral requirement evaluation and an enabled-capability record;
- query/timestamp functionality; and
- explicit external-synchronization and GPU-lifetime documentation.

### What may be an optional vk-zig convenience

These patterns recur across renderers but encode some policy. Keep them in separate modules layered
over the thin wrapper:

- `SwapchainSelector` for common format, extent, image-count, alpha, and present-mode preferences;
- `UploadBatch` for a caller-bounded staging/copy list and completion token;
- `RetirementQueue(T, capacity)` for releasing caller-supplied destruction records after a fence or
  timeline value;
- `MemoryTypeSelector` with named common requirements and explicit fallback reporting;
- scoped command-buffer debug labels;
- a one-time command helper that still makes the queue wait/completion policy explicit; and
- pipeline-cache load/store helpers that operate on caller-owned bytes or streams.

None of these conveniences should allocate secretly, choose unbounded capacities, call
`deviceWaitIdle` silently, or obscure queue-family ownership and layout transitions.

### What should remain in Bloc

The following are renderer/game policy and would make vk-zig less generally useful if baked into
the base library:

- discrete/integrated device scoring weights and command-line device override;
- exactly two frames in flight;
- swapchain recreation state, resize coalescing, minimize pacing, and fullscreen/vsync settings;
- per-swapchain-image fence association;
- frame arenas, timing histograms, telemetry names, and log rate limits;
- resource revision numbers, stale upload rejection, and chunk render handles;
- which fence/timeline value represents the last use of a resource;
- fixed upload/destruction capacities and overflow policy;
- atlas, descriptor-sharing, pass ordering, batching, and pipeline policy;
- world/UI render registries and draw sorting; and
- device-loss recovery into menu, shutdown, or full renderer reconstruction.

### Bloc-critical implementation order

To unblock Bloc without implementing all of Vulkan at once, use this order:

1. Generate the enum/flag/value vocabulary used by WSI, resources, command recording, and
   synchronization.
2. Add `CommandPool`, borrowed `CommandBuffer`, `Fence`, `Semaphore`, `ImageView`, and borrowed
   `SwapchainImage` types.
3. Add typed command-buffer begin/end/reset, image barriers, clear-color image, and debug-label
   scopes.
4. Replace `Queue.submit([]raw.VkSubmitInfo, raw.VkFence)` with typed submission descriptions and
   wrapper objects; keep legacy submit and add submit2 without conflating their stage-mask models.
5. Make acquire/present accept typed synchronization objects and preserve timeout, not-ready,
   suboptimal, out-of-date, surface-lost, full-screen-exclusive-lost, and device-lost outcomes.
6. Add caller-storage forms for surface formats, present modes, and swapchain images.
7. Add typed swapchain configuration and image-view creation so the Phase 03 module contains no
   `vk.raw` after its checked RGFW surface boundary.
8. Add memory, buffers, images, shaders, descriptors, pipelines, transfers, and draw commands for
   Phases 05–06.
9. Add query/timestamp and secondary/indirect command support before Phases 17–18.
10. Add optional upload and retirement conveniences only after the thin APIs are proven by Bloc's
    own bounded implementations.

The concrete Phase 03 acceptance test is stronger than a synthetic unit test:

> Bloc can implement its current resize-aware clear-and-present path without `vk.raw`, manual PFN
> loading, `sType`, pointer/count assembly, `@intCast` for Vulkan values, or manual raw-handle
> destruction. The only handle conversion is RGFW's checked surface creation boundary.

## Implementation roadmap

### Phase 0: scalable foundations

1. Generate typed non-exhaustive enums.
2. Generate domain-specific flag wrappers.
3. Generate extension metadata and command aliases.
4. Generate structure-chain metadata.
5. Expand command-specific result/status mapping infrastructure.
6. Add compile-time equivalence tests against raw constants.

Exit condition: common options can be defined without raw constants, and later wrappers do not
need hand-written enum/flag conversions.

### Phase 1: raw-free compute

1. Typed physical properties/features and device creation.
2. Memory properties, allocation, mapping, and binding.
3. Buffers and shader modules.
4. Descriptor layouts/pools/sets/updates.
5. Pipeline layouts and compute pipelines.
6. Command pools/buffers and dispatch.
7. Fences, semaphores, synchronization2, and submit2.

Exit condition: a compute shader can upload input, dispatch, wait, invalidate/read back output, and
clean up without `vk.raw`.

### Phase 2: raw-free presentation and basic graphics

1. Platform surface constructors.
2. Typed surface queries and swapchain selection/options.
3. Typed swapchain images and image views.
4. Images, samplers, and image memory.
5. Graphics pipelines and dynamic rendering.
6. Draw/bind/dynamic-state commands.
7. Transfer commands and image transitions.
8. Typed acquire/submit/present frame loop.

Exit condition: a validated resize-aware textured triangle contains no `vk.raw` references.

### Phase 3: complete core Vulkan 1.0–1.4

1. Legacy render passes/framebuffers.
2. Queries, timestamps, and events.
3. Sparse resources.
4. Device groups and external capability queries.
5. Descriptor templates/push descriptors.
6. Pipeline caches/binaries and private data.
7. Host image copy and remaining Vulkan 1.4 commands.
8. Full core command coverage matrix generated from `vk.xml`.

Exit condition: every one of the 234 registry core commands is either wrapped or explicitly
documented as an advanced raw-only operation with justification.

### Phase 4: common extensions

Prioritize debug utils completion, swapchain maintenance/present wait/ID, memory budget/priority,
calibrated timestamps, device fault, descriptor indexing/buffer, shader objects, mesh shading, and
ray tracing based on real consumer demand.

### Phase 5: specialty extension modules

Add Vulkan Video, optical flow, tensors, data graphs, device-generated commands, platform external
handles, and vendor-specific functionality as independent modules. Generated vocabulary and chain
metadata should make these additions incremental rather than bespoke.

## Required conformance examples

The examples directory should eventually contain programs that enforce the wrapper boundary. Add a
build-time source scan or compile rule that rejects `vk.raw` in examples explicitly marked
idiomatic.

Required examples:

1. `compute_buffer.zig`: upload, dispatch, wait, read back.
2. `triangle.zig`: surface, swapchain, shaders, pipeline, commands, synchronization, present.
3. `textured_triangle.zig`: staging, image upload, view, sampler, descriptors, transitions.
4. `swapchain_recreation.zig`: resize, out-of-date/suboptimal handling, old swapchain.
5. `timeline_semaphore.zig`: timeline wait/signal and submit2.
6. `dynamic_rendering.zig`: Vulkan 1.3 rendering without a render pass.
7. `query_timestamps.zig`: query reset/write/read with availability.
8. `feature_chain.zig`: query and enable Vulkan 1.2/1.3 features without `pNext`.
9. `platform_surface.zig`: configured native platform constructor.
10. `raw_escape_hatch.zig`: the only example intentionally using `vk.raw`.

## Definition of done for an idiomatic feature

A feature is not complete merely because a command has a generated descriptor. It is complete when:

- ordinary inputs are Zig enums, flag wrappers, booleans, slices, option structs, and wrapper
  objects;
- output counts and memory are managed safely;
- owning handles have rollback and `deinit`;
- borrowed handles have explicit lifetime documentation;
- command statuses are exhaustively represented;
- parent ownership is validated;
- extension/core aliases resolve internally;
- common use does not require `sType`, `pNext`, casts, raw booleans, or raw results;
- a checked raw escape hatch remains available; and
- tests cover success, missing command/extension, invalid parent, inactive object, partial creation,
  idempotent cleanup, and non-success statuses.

## Final assessment

vk-zig has a strong raw foundation and several good wrapper patterns: allocator-aware enumeration,
bounded retry loops, non-null live handles, idempotent cleanup, partial-creation rollback, typed
acquire/present statuses, generated command descriptors, and the new typed debug callback. These
patterns should be reused.

The principal gap is breadth and generated typed vocabulary. Today, the wrapper gets a consumer to
a logical device and partially through swapchain setup; almost every operation after that requires
raw Vulkan. Building the enum/flags/chain metadata generator first, then implementing the Phase 1
and Phase 2 object workflows, will produce the largest improvement without turning vk-zig into a
graphics engine.
