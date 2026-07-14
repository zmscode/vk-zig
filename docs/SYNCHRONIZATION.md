# Host synchronization and GPU lifetime contracts

vk-zig does not take hidden locks. Vulkan's externally synchronized objects remain the caller's
responsibility, and methods that only query immutable driver state remain safe to call alongside
other immutable queries. Generated command descriptors expose the registry fact as
`@TypeOf(vk.command.some_command).externally_synchronized`.

The contracts below cover every currently wrapped dispatching method. A method not listed by name
inherits the contract of its object and operation category. Raw escape hatches inherit the Vulkan
registry contract for the raw command unchanged.

## Contract vocabulary

| Contract | Meaning |
| --- | --- |
| immutable query | Reads driver/object state and does not mutate the dispatch object. Concurrent immutable queries are allowed. |
| distinct children concurrent | The parent is read-only during the call. Different child objects may be created or queried concurrently, but the same output/child storage must not be shared unsafely. |
| externally synchronized | The caller serializes all host access to the named object and any registry-declared related objects. |
| retained until recording ends | Pointer/slice data is consumed during the call and need only outlive command recording. |
| retained until submission completes | The referenced Vulkan object and its bound memory remain alive until the GPU finishes every submission that uses it. |

`deinit`, reset, free, move, pool reset, swapchain replacement, mapping/unmapping, and host writes
are always externally synchronized with access to that same wrapper value. Same-value repeated
`deinit` is locally idempotent; it does not make concurrent destruction safe.

## Loader, entry, instance, and discovery

- `Loader.init`, `initFromPath`, and `entry` touch only their receiver/result. `Loader.deinit` is
  externally synchronized with `entry` and all other access to that loader.
- `Entry.apiVersion`, all instance layer/extension count/`Into`/allocating forms, `load`, and
  `require` are immutable queries. Caller-provided output storage is exclusively owned for the
  duration of an `Into` call.
- `Entry.createInstance*` reads the entry and caller options and creates a distinct child. All
  option slices and strings need only live through the call, except callback context passed to a
  debug messenger, which must live until the messenger/instance is destroyed.
- `Instance.load`, `require`, `enabledExtensions`, `supportsExtension`, physical-device discovery,
  and all `PhysicalDevice` immutable property/feature/format/memory/queue/extension/surface queries
  may run concurrently when their caller-owned output storage is distinct.
- `Instance.create*Surface`, `createDebugMessenger`, and `PhysicalDevice.createDevice*` create
  distinct children. The parent must remain alive, but unrelated child creation may be concurrent.
- `Instance.deinit` is externally synchronized and requires every surface, messenger, and device
  created from it to have been destroyed first.

## Device and resource creation

- `Device.status`, `enabledExtensions`, `supportsExtension`, `supportsFeature`, and
  `supportsCommand` are immutable queries.
- `Device.createBuffer`, `createImage`, `createImageView`, `createBufferView`, `allocateMemory`,
  sampler, shader, descriptor-layout/pool/template, pipeline-layout/pipeline, render-pass,
  framebuffer, semaphore, fence, event, command-pool, and swapchain creation are distinct-child
  concurrent operations. Caller option slices are consumed during the call.
- `Device.updateDescriptorSets` externally synchronizes every destination descriptor set and any
  descriptor pool declared externally synchronized by the registry. Referenced buffers, images,
  views, samplers, and their bound memory must remain alive through submissions that consume the
  descriptors.
- `Device.resetFences`, `waitFences`, and timeline waits externally synchronize the listed fences
  or semaphores as required by the generated command descriptor. `Device.waitIdle` serializes the
  device's execution boundary, but does not provide a host mutex for concurrent wrapper mutation.
- Every owned resource `deinit` is externally synchronized with host use of that same object and
  is permitted after confirmed device loss. Destroy children before their parent device.

## Queues, command pools, and command buffers

- Every `Queue.submit`, `submit2`, `submitRaw`, `present`, `waitIdle`, and debug-label method is
  externally synchronized on that queue. Distinct queues may be used concurrently when the Vulkan
  objects referenced by their submissions are otherwise synchronized.
- Submitted command buffers, semaphores, fences, descriptor sets, pipelines, render passes,
  framebuffers, buffers, images, views, samplers, query pools, and bound memory remain alive and
  unmodified where Vulkan requires until the submission completes.
- `CommandPool.allocateCommandBuffer`, `freeCommandBuffer`, `reset`, and `deinit` are externally
  synchronized on the pool. Distinct pools may be used concurrently. Pool reset/free invalidates
  the affected borrowed command-buffer generations.
- `CommandBuffer.begin`, `end`, `reset`, `deinit`, every `set*`, bind, barrier, event, rendering,
  render-pass, clear, copy, blit, resolve, draw, dispatch, execute-secondary, push-constant, and
  label method is externally synchronized on that command buffer.
- Data passed to `updateBuffer` and push-constant methods is copied during recording. Vulkan
  objects referenced by recorded commands must remain alive through execution, not merely until
  recording ends. Secondary command buffers passed to `executeSecondary` remain valid through the
  primary command buffer's execution.

## Memory, buffers, and images

- `MemoryAllocation.map`, `unmap`, `flush`, `invalidate`, opaque-address queries, and `deinit` are
  externally synchronized on the allocation. Only one active `MappedRange` generation exists per
  allocation; remap/unmap invalidates the old borrow.
- Host writes become available to the device only according to Vulkan's host/GPU ordering rules.
  For non-coherent memory, flush written ranges before GPU access and invalidate ranges after GPU
  writes complete and before host reads. Flush/invalidate alignment must obey
  `nonCoherentAtomSize`; vk-zig validates range arithmetic but does not insert queue dependencies.
- `Buffer.bindMemory`, device/capture-address queries, and `Image.bindMemory`, host-copy,
  transition, subresource-layout, sparse-requirement methods are externally synchronized where
  their generated raw command says so. The allocation outlives the bound resource and all GPU use.
- Buffer/image views outlive descriptor sets, framebuffers, or recorded commands that reference
  them. Swapchain images are borrowed: they are invalid after swapchain destruction/recreation.

## Descriptors, pipelines, render passes, and synchronization objects

- Descriptor-pool `reset`, allocation/free, and `deinit` are externally synchronized on the pool.
  Pool reset/destruction invalidates every borrowed descriptor-set generation. Updates to distinct
  descriptor sets may be concurrent only when the descriptor binding/update rules allow it.
- Pipeline and shader creation consumes create-info storage during the call. Shader modules may be
  destroyed after pipeline creation completes. Pipeline/layout/render-pass/framebuffer destruction
  waits until no in-flight submission uses the object.
- Event `set`/`reset`, semaphore `signal`/`wait`, fence `reset`/`wait`, status queries, and destroy
  operations inherit the generated command descriptor. Status queries are immutable unless the
  registry marks a participating object externally synchronized.

## Presentation and debug utilities

- Swapchain image count/`Into`/allocating queries are immutable with respect to host state, while
  `acquireNextImage` externally synchronizes the swapchain and supplied semaphore/fence as declared
  by Vulkan. `Queue.present` is externally synchronized on the queue and presented swapchains.
- Recreate a swapchain only after coordinating all work using its images. Keep the old swapchain
  alive through the replacement call, then retire its image views and frame resources only after
  their GPU completion point.
- Debug messenger callbacks may arrive concurrently on arbitrary Vulkan-calling threads. Callback
  context remains alive until messenger destruction and application logging state must be
  synchronized by the application. Debug label scopes are externally synchronized on their queue
  or command buffer.

## Main-thread Vulkan boundary

A simple safe architecture lets workers produce ordinary CPU data while one render thread owns
queues, pools, command buffers, descriptors, and presentation:

```zig
// Worker: no Vulkan wrapper access.
fn buildVertices(job: *Job) void {
    job.vertex_count = generateVertices(job.cpu_storage);
    job.ready.store(true, .release);
}

// Render thread: owns Vulkan host synchronization.
if (job.ready.load(.acquire)) {
    const mapped = try upload_memory.map(.{ .offset = .zero, .size = upload_size });
    defer mapped.deinit();
    @memcpy(mapped.bytes()[0..job.byte_len], job.cpu_storage[0..job.byte_len]);
    try mapped.flush(); // required for non-coherent memory
    try command_buffer.copyBuffer(&upload_buffer, &device_buffer, &regions);
    try queue.submit(.{ .command_buffers = &.{command_buffer} });
    // Retire/reuse CPU-visible and GPU objects only after the fence/timeline value completes.
}
```

This boundary is a policy, not a hidden library lock: applications may use multiple Vulkan host
threads by assigning distinct externally synchronized objects to each thread and explicitly
coordinating shared objects.
