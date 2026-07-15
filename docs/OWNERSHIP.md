# Ownership and borrowed handles

vk-zig keeps Vulkan's explicit lifetime model, while making ordinary Zig struct copies safe.

## Owning wrappers

Every wrapper that destroys a Vulkan handle carries a process-local ownership token. A bitwise
copy shares that token; exactly one copy can claim cleanup. Destroying either copy invalidates all
other copies, whose later `deinit` calls are no-ops. A checked `rawHandle()` on an invalidated copy
returns `error.CopiedOwner` or `error.InactiveObject` instead of exposing a dead handle.

This applies to the loader, instance, device, presentation objects, resources, allocation objects,
pipelines, descriptor and command pools, synchronization objects, query pools, and diagnostic
objects. Composite helpers delegate cleanup to those tokenized owners.

Prefer normal final-storage initialization and a single `defer object.deinit()`:

```zig
var buffer = try device.createBuffer(.{
    .size = .fromBytes(4096),
    .usage = .init(&.{ .vertex_buffer, .transfer_dst }),
});
defer buffer.deinit();
```

Moving or returning that value remains safe. Copying it is still discouraged because only one
copy remains the live owner after cleanup, but it cannot silently destroy the Vulkan object twice.

## Borrowed wrappers

Objects allocated from or exposed by another wrapper retain a generation or ownership borrow:

- command buffers validate their command pool;
- descriptor sets validate their descriptor pool and reset generation;
- swapchain images and their views validate the swapchain generation;
- image views created from owned images validate the image owner;
- framebuffers validate their render pass;
- surfaces validate their instance.

After parent destruction or recreation, checked operations return `error.StaleBorrow`. Descriptor
pool reset invalidates its sets. Command-pool reset keeps command-buffer handles valid but restores
their tracked recording state, matching Vulkan's reset semantics.

Parent objects must still outlive children in valid Vulkan programs. The checks make violations
deterministic; they do not extend the native Vulkan lifetime.

## Scope tokens and allocated results

Begin/end helpers and other one-shot owners use the same claim-once rule. Copies of a rendering,
render-pass, query, or debug-label scope cannot issue the matching end command twice. Profiling
locks release once, and copied query-result values free their backing allocation once.

## Threading

The token claim is atomic, but it is not a substitute for Vulkan host synchronization. Sharing or
mutating wrapper values across threads still requires the synchronization described in
[SYNCHRONIZATION.md](SYNCHRONIZATION.md).

## Advanced interop

Use `rawHandle()` only at a real FFI boundary and propagate its error. Never retain a returned raw
handle beyond the wrapper's lifetime. Constructors that adopt foreign handles document whether
they take ownership; once adopted, the same copy-safe cleanup rules apply.
