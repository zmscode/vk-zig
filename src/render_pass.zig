const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");
const image = @import("image.zig");
const rendering = @import("rendering.zig");
const types = @import("vulkan_types");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const RenderPassHandle = core.NonNullHandle(raw.VkRenderPass);
const FramebufferHandle = core.NonNullHandle(raw.VkFramebuffer);

pub const attachment_count_max = 32;
pub const subpass_count_max = 16;
pub const reference_count_max = 128;
pub const dependency_count_max = 64;
pub const correlated_view_mask_count_max = 32;
pub const framebuffer_attachment_count_max = attachment_count_max;
pub const framebuffer_view_format_count_max = 128;

pub const Attachment = struct {
    format: types.Format,
    samples: types.SampleCountBit = ._1,
    load: rendering.LoadOperation = .load,
    store: rendering.StoreOperation = .store,
    stencil_load: rendering.LoadOperation = .discard,
    stencil_store: rendering.StoreOperation = .discard,
    initial_layout: types.ImageLayout = .undefined_,
    final_layout: types.ImageLayout,
    may_alias: bool = false,

    fn toRaw2(value: Attachment) raw.VkAttachmentDescription2 {
        return .{
            .sType = raw.VK_STRUCTURE_TYPE_ATTACHMENT_DESCRIPTION_2,
            .flags = if (value.may_alias) @intCast(raw.VK_ATTACHMENT_DESCRIPTION_MAY_ALIAS_BIT) else 0,
            .format = value.format.toRaw(),
            .samples = value.samples.toRaw(),
            .loadOp = value.load.toRaw(),
            .storeOp = value.store.toRaw(),
            .stencilLoadOp = value.stencil_load.toRaw(),
            .stencilStoreOp = value.stencil_store.toRaw(),
            .initialLayout = value.initial_layout.toRaw(),
            .finalLayout = value.final_layout.toRaw(),
        };
    }

    fn toRaw(value: Attachment) raw.VkAttachmentDescription {
        const converted = value.toRaw2();
        return .{
            .flags = converted.flags,
            .format = converted.format,
            .samples = converted.samples,
            .loadOp = converted.loadOp,
            .storeOp = converted.storeOp,
            .stencilLoadOp = converted.stencilLoadOp,
            .stencilStoreOp = converted.stencilStoreOp,
            .initialLayout = converted.initialLayout,
            .finalLayout = converted.finalLayout,
        };
    }
};

pub const AttachmentReference = union(enum) {
    unused,
    attachment: struct {
        index: u32,
        layout: types.ImageLayout,
        aspects: types.ImageAspectFlags = .empty,
    },

    fn validate(reference: AttachmentReference, attachment_count: usize) core.Error!void {
        switch (reference) {
            .unused => {},
            .attachment => |value| {
                if (value.index >= attachment_count) return error.InvalidOptions;
            },
        }
    }

    fn toRaw2(reference: AttachmentReference) raw.VkAttachmentReference2 {
        return switch (reference) {
            .unused => .{
                .sType = raw.VK_STRUCTURE_TYPE_ATTACHMENT_REFERENCE_2,
                .attachment = raw.VK_ATTACHMENT_UNUSED,
                .layout = raw.VK_IMAGE_LAYOUT_UNDEFINED,
            },
            .attachment => |value| .{
                .sType = raw.VK_STRUCTURE_TYPE_ATTACHMENT_REFERENCE_2,
                .attachment = value.index,
                .layout = value.layout.toRaw(),
                .aspectMask = value.aspects.toRaw(),
            },
        };
    }

    fn toRaw(reference: AttachmentReference) raw.VkAttachmentReference {
        const converted = reference.toRaw2();
        return .{ .attachment = converted.attachment, .layout = converted.layout };
    }
};

pub const Subpass = struct {
    input_attachments: []const AttachmentReference = &.{},
    color_attachments: []const AttachmentReference = &.{},
    resolve_attachments: []const AttachmentReference = &.{},
    depth_stencil_attachment: ?AttachmentReference = null,
    preserve_attachments: []const u32 = &.{},
    view_mask: u32 = 0,
};

pub const SubpassIndex = union(enum) {
    external,
    index: u32,

    fn toRaw(value: SubpassIndex) u32 {
        return switch (value) {
            .external => raw.VK_SUBPASS_EXTERNAL,
            .index => |index| index,
        };
    }
};

pub const Dependency = struct {
    source: SubpassIndex,
    destination: SubpassIndex,
    source_stages: types.PipelineStageFlags,
    destination_stages: types.PipelineStageFlags,
    source_access: types.AccessFlags = .empty,
    destination_access: types.AccessFlags = .empty,
    flags: types.DependencyFlags = .empty,
    view_offset: i32 = 0,
};

pub const Options = struct {
    attachments: []const Attachment = &.{},
    subpasses: []const Subpass,
    dependencies: []const Dependency = &.{},
    correlated_view_masks: []const u32 = &.{},
};

pub const Dispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateRenderPass),
    create2: ?CommandFunction(raw.PFN_vkCreateRenderPass2),
    destroy: CommandFunction(raw.PFN_vkDestroyRenderPass),
    get_granularity: CommandFunction(raw.PFN_vkGetRenderAreaGranularity),
};

const AttachmentMetadata = struct {
    format: types.Format,
    samples: types.SampleCountBit,
};

const SubpassMetadata = struct {
    color_attachment_count: u32,
    samples: types.SampleCountBit,
};

pub const RenderPass = struct {
    _handle: ?RenderPassHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    _attachments: [attachment_count_max]AttachmentMetadata = undefined,
    _attachment_count: usize,
    _subpasses: [subpass_count_max]SubpassMetadata = undefined,
    _subpass_count: usize,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,

    pub fn deinit(render_pass: *RenderPass) void {
        if (!(render_pass._owner.release(render_pass) catch return)) return;
        const handle = render_pass._handle orelse return;
        render_pass.dispatch.destroy(render_pass._device_handle, handle, render_pass.allocation_callbacks);
        render_pass._handle = null;
    }

    pub fn rawHandle(render_pass: *const RenderPass) core.Error!raw.VkRenderPass {
        try render_pass._owner.validate(render_pass);
        if (render_pass._device_state) |*state| try state.ensureDispatchAllowed();
        return render_pass._handle orelse error.InactiveObject;
    }

    pub fn attachmentCount(render_pass: *const RenderPass) usize {
        return render_pass._attachment_count;
    }

    pub fn subpassCount(render_pass: *const RenderPass) usize {
        return render_pass._subpass_count;
    }

    pub fn attachmentFormat(render_pass: *const RenderPass, index: usize) ?types.Format {
        if (index >= render_pass._attachment_count) return null;
        return render_pass._attachments[index].format;
    }

    pub fn attachmentSamples(render_pass: *const RenderPass, index: usize) ?types.SampleCountBit {
        if (index >= render_pass._attachment_count) return null;
        return render_pass._attachments[index].samples;
    }

    pub fn subpassColorAttachmentCount(render_pass: *const RenderPass, index: u32) ?u32 {
        if (index >= render_pass._subpass_count) return null;
        return render_pass._subpasses[index].color_attachment_count;
    }

    pub fn subpassSamples(render_pass: *const RenderPass, index: u32) ?types.SampleCountBit {
        if (index >= render_pass._subpass_count) return null;
        return render_pass._subpasses[index].samples;
    }

    pub fn renderAreaGranularity(render_pass: *const RenderPass) core.Error!types.Extent2D {
        var extent: raw.VkExtent2D = .{};
        render_pass.dispatch.get_granularity(render_pass._device_handle, try render_pass.rawHandle(), &extent);
        return .fromRaw(extent);
    }

    pub fn debugObject(render_pass: *const RenderPass) core.Error!debug_utils.Object {
        return .forDevice(.render_pass, try render_pass.rawHandle(), render_pass._device_handle);
    }
};

const Graph = struct {
    attachments2: [attachment_count_max]raw.VkAttachmentDescription2 = undefined,
    attachments: [attachment_count_max]raw.VkAttachmentDescription = undefined,
    subpasses2: [subpass_count_max]raw.VkSubpassDescription2 = undefined,
    subpasses: [subpass_count_max]raw.VkSubpassDescription = undefined,
    references2: [reference_count_max]raw.VkAttachmentReference2 = undefined,
    references: [reference_count_max]raw.VkAttachmentReference = undefined,
    depth_references2: [subpass_count_max]raw.VkAttachmentReference2 = undefined,
    depth_references: [subpass_count_max]raw.VkAttachmentReference = undefined,
    preserve: [reference_count_max]u32 = undefined,
    dependencies2: [dependency_count_max]raw.VkSubpassDependency2 = undefined,
    dependencies: [dependency_count_max]raw.VkSubpassDependency = undefined,
    view_masks: [subpass_count_max]u32 = undefined,
    view_offsets: [dependency_count_max]i32 = undefined,
    input_aspects: [reference_count_max]raw.VkInputAttachmentAspectReference = undefined,
    reference_count: usize = 0,
    preserve_count: usize = 0,
    input_aspect_count: usize = 0,
    subpass_samples: [subpass_count_max]types.SampleCountBit = undefined,

    fn appendReferences(graph: *Graph, references: []const AttachmentReference, attachment_count: usize) core.Error!usize {
        if (references.len > reference_count_max - graph.reference_count) return error.CountOverflow;
        const start = graph.reference_count;
        for (references) |reference| {
            try reference.validate(attachment_count);
            graph.references2[graph.reference_count] = reference.toRaw2();
            graph.references[graph.reference_count] = reference.toRaw();
            graph.reference_count += 1;
        }
        return start;
    }

    fn init(graph: *Graph, options: Options) core.Error!void {
        if (options.attachments.len > attachment_count_max or options.subpasses.len > subpass_count_max or
            options.dependencies.len > dependency_count_max or options.correlated_view_masks.len > correlated_view_mask_count_max)
        {
            return error.CountOverflow;
        }
        if (options.subpasses.len == 0) return error.InvalidOptions;
        for (options.attachments, 0..) |attachment, index| {
            if (attachment.format == .undefined_) return error.InvalidOptions;
            graph.attachments2[index] = attachment.toRaw2();
            graph.attachments[index] = attachment.toRaw();
        }
        for (options.subpasses, 0..) |subpass, index| {
            if (subpass.resolve_attachments.len != 0 and subpass.resolve_attachments.len != subpass.color_attachments.len) return error.InvalidOptions;
            const input_start = try graph.appendReferences(subpass.input_attachments, options.attachments.len);
            for (subpass.input_attachments, 0..) |reference, input_index| {
                switch (reference) {
                    .unused => {},
                    .attachment => |value| {
                        if (value.aspects.toRaw() == 0) continue;
                        if (graph.input_aspect_count == reference_count_max) return error.CountOverflow;
                        graph.input_aspects[graph.input_aspect_count] = .{
                            .subpass = @intCast(index),
                            .inputAttachmentIndex = @intCast(input_index),
                            .aspectMask = value.aspects.toRaw(),
                        };
                        graph.input_aspect_count += 1;
                    },
                }
            }
            const color_start = try graph.appendReferences(subpass.color_attachments, options.attachments.len);
            const resolve_start = try graph.appendReferences(subpass.resolve_attachments, options.attachments.len);
            var depth2: [*c]const raw.VkAttachmentReference2 = null;
            var depth: [*c]const raw.VkAttachmentReference = null;
            if (subpass.depth_stencil_attachment) |reference| {
                try reference.validate(options.attachments.len);
                graph.depth_references2[index] = reference.toRaw2();
                graph.depth_references[index] = reference.toRaw();
                depth2 = &graph.depth_references2[index];
                depth = &graph.depth_references[index];
            }
            if (subpass.preserve_attachments.len > reference_count_max - graph.preserve_count) return error.CountOverflow;
            const preserve_start = graph.preserve_count;
            for (subpass.preserve_attachments, 0..) |attachment_index, preserve_index| {
                if (attachment_index >= options.attachments.len) return error.InvalidOptions;
                for (subpass.preserve_attachments[0..preserve_index]) |previous| {
                    if (previous == attachment_index) return error.InvalidOptions;
                }
                graph.preserve[graph.preserve_count] = attachment_index;
                graph.preserve_count += 1;
            }
            graph.subpasses2[index] = .{
                .sType = raw.VK_STRUCTURE_TYPE_SUBPASS_DESCRIPTION_2,
                .pipelineBindPoint = raw.VK_PIPELINE_BIND_POINT_GRAPHICS,
                .viewMask = subpass.view_mask,
                .inputAttachmentCount = @intCast(subpass.input_attachments.len),
                .pInputAttachments = if (subpass.input_attachments.len == 0) null else graph.references2[input_start..][0..subpass.input_attachments.len].ptr,
                .colorAttachmentCount = @intCast(subpass.color_attachments.len),
                .pColorAttachments = if (subpass.color_attachments.len == 0) null else graph.references2[color_start..][0..subpass.color_attachments.len].ptr,
                .pResolveAttachments = if (subpass.resolve_attachments.len == 0) null else graph.references2[resolve_start..][0..subpass.resolve_attachments.len].ptr,
                .pDepthStencilAttachment = depth2,
                .preserveAttachmentCount = @intCast(subpass.preserve_attachments.len),
                .pPreserveAttachments = if (subpass.preserve_attachments.len == 0) null else graph.preserve[preserve_start..][0..subpass.preserve_attachments.len].ptr,
            };
            graph.subpasses[index] = .{
                .pipelineBindPoint = raw.VK_PIPELINE_BIND_POINT_GRAPHICS,
                .inputAttachmentCount = @intCast(subpass.input_attachments.len),
                .pInputAttachments = if (subpass.input_attachments.len == 0) null else graph.references[input_start..][0..subpass.input_attachments.len].ptr,
                .colorAttachmentCount = @intCast(subpass.color_attachments.len),
                .pColorAttachments = if (subpass.color_attachments.len == 0) null else graph.references[color_start..][0..subpass.color_attachments.len].ptr,
                .pResolveAttachments = if (subpass.resolve_attachments.len == 0) null else graph.references[resolve_start..][0..subpass.resolve_attachments.len].ptr,
                .pDepthStencilAttachment = depth,
                .preserveAttachmentCount = @intCast(subpass.preserve_attachments.len),
                .pPreserveAttachments = if (subpass.preserve_attachments.len == 0) null else graph.preserve[preserve_start..][0..subpass.preserve_attachments.len].ptr,
            };
            graph.view_masks[index] = subpass.view_mask;
            graph.subpass_samples[index] = try subpassSampleCount(subpass, options.attachments);
        }
        for (options.dependencies, 0..) |dependency, index| {
            try validateSubpassIndex(dependency.source, options.subpasses.len);
            try validateSubpassIndex(dependency.destination, options.subpasses.len);
            if (dependency.view_offset != 0 and !dependency.flags.contains(.view_local)) return error.InvalidOptions;
            graph.dependencies2[index] = .{
                .sType = raw.VK_STRUCTURE_TYPE_SUBPASS_DEPENDENCY_2,
                .srcSubpass = dependency.source.toRaw(),
                .dstSubpass = dependency.destination.toRaw(),
                .srcStageMask = dependency.source_stages.toRaw(),
                .dstStageMask = dependency.destination_stages.toRaw(),
                .srcAccessMask = dependency.source_access.toRaw(),
                .dstAccessMask = dependency.destination_access.toRaw(),
                .dependencyFlags = dependency.flags.toRaw(),
                .viewOffset = dependency.view_offset,
            };
            graph.dependencies[index] = .{
                .srcSubpass = dependency.source.toRaw(),
                .dstSubpass = dependency.destination.toRaw(),
                .srcStageMask = dependency.source_stages.toRaw(),
                .dstStageMask = dependency.destination_stages.toRaw(),
                .srcAccessMask = dependency.source_access.toRaw(),
                .dstAccessMask = dependency.destination_access.toRaw(),
                .dependencyFlags = dependency.flags.toRaw(),
            };
            graph.view_offsets[index] = dependency.view_offset;
        }
        for (options.correlated_view_masks, 0..) |mask, index| {
            if (mask == 0) return error.InvalidOptions;
            for (options.correlated_view_masks[0..index]) |previous| {
                if (previous & mask != 0) return error.InvalidOptions;
            }
        }
    }
};

fn validateSubpassIndex(value: SubpassIndex, subpass_count: usize) core.Error!void {
    switch (value) {
        .external => {},
        .index => |index| if (index >= subpass_count) return error.InvalidOptions,
    }
}

fn sampleForReference(reference: AttachmentReference, attachments: []const Attachment) ?types.SampleCountBit {
    return switch (reference) {
        .unused => null,
        .attachment => |value| attachments[value.index].samples,
    };
}

fn subpassSampleCount(subpass: Subpass, attachments: []const Attachment) core.Error!types.SampleCountBit {
    var result: ?types.SampleCountBit = null;
    for (subpass.color_attachments) |reference| {
        const samples = sampleForReference(reference, attachments) orelse continue;
        if (result) |previous| {
            if (previous != samples) return error.InvalidOptions;
        } else result = samples;
    }
    if (subpass.depth_stencil_attachment) |reference| {
        if (sampleForReference(reference, attachments)) |samples| {
            if (result) |previous| {
                if (previous != samples) return error.InvalidOptions;
            } else result = samples;
        }
    }
    return result orelse ._1;
}

pub fn create(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: Dispatch,
    options: Options,
) core.Error!RenderPass {
    var graph: Graph = .{};
    try graph.init(options);
    var handle: raw.VkRenderPass = null;
    const result = if (dispatch.create2) |create2| blk: {
        const info: raw.VkRenderPassCreateInfo2 = .{
            .sType = raw.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO_2,
            .attachmentCount = @intCast(options.attachments.len),
            .pAttachments = if (options.attachments.len == 0) null else graph.attachments2[0..options.attachments.len].ptr,
            .subpassCount = @intCast(options.subpasses.len),
            .pSubpasses = graph.subpasses2[0..options.subpasses.len].ptr,
            .dependencyCount = @intCast(options.dependencies.len),
            .pDependencies = if (options.dependencies.len == 0) null else graph.dependencies2[0..options.dependencies.len].ptr,
            .correlatedViewMaskCount = @intCast(options.correlated_view_masks.len),
            .pCorrelatedViewMasks = if (options.correlated_view_masks.len == 0) null else options.correlated_view_masks.ptr,
        };
        break :blk create2(device_handle, &info, allocation_callbacks, &handle);
    } else blk: {
        var input_aspects: raw.VkRenderPassInputAttachmentAspectCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_RENDER_PASS_INPUT_ATTACHMENT_ASPECT_CREATE_INFO,
            .aspectReferenceCount = @intCast(graph.input_aspect_count),
            .pAspectReferences = if (graph.input_aspect_count == 0) null else graph.input_aspects[0..graph.input_aspect_count].ptr,
        };
        var multiview: raw.VkRenderPassMultiviewCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_RENDER_PASS_MULTIVIEW_CREATE_INFO,
            .pNext = if (graph.input_aspect_count == 0) null else &input_aspects,
            .subpassCount = @intCast(options.subpasses.len),
            .pViewMasks = graph.view_masks[0..options.subpasses.len].ptr,
            .dependencyCount = @intCast(options.dependencies.len),
            .pViewOffsets = if (options.dependencies.len == 0) null else graph.view_offsets[0..options.dependencies.len].ptr,
            .correlationMaskCount = @intCast(options.correlated_view_masks.len),
            .pCorrelationMasks = if (options.correlated_view_masks.len == 0) null else options.correlated_view_masks.ptr,
        };
        const uses_multiview = options.correlated_view_masks.len != 0 or for (options.subpasses) |subpass| {
            if (subpass.view_mask != 0) break true;
        } else for (options.dependencies) |dependency| {
            if (dependency.view_offset != 0) break true;
        } else false;
        const info: raw.VkRenderPassCreateInfo = .{
            .sType = raw.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            .pNext = if (uses_multiview) &multiview else if (graph.input_aspect_count != 0) &input_aspects else null,
            .attachmentCount = @intCast(options.attachments.len),
            .pAttachments = if (options.attachments.len == 0) null else graph.attachments[0..options.attachments.len].ptr,
            .subpassCount = @intCast(options.subpasses.len),
            .pSubpasses = graph.subpasses[0..options.subpasses.len].ptr,
            .dependencyCount = @intCast(options.dependencies.len),
            .pDependencies = if (options.dependencies.len == 0) null else graph.dependencies[0..options.dependencies.len].ptr,
        };
        break :blk dispatch.create(device_handle, &info, allocation_callbacks, &handle);
    };
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccess(result);
        unreachable;
    }
    var render_pass: RenderPass = .{
        ._handle = handle orelse return error.InvalidHandle,
        ._owner = try .init(&handle),
        ._device_handle = device_handle,
        ._attachment_count = options.attachments.len,
        ._subpass_count = options.subpasses.len,
        .allocation_callbacks = allocation_callbacks,
        .dispatch = dispatch,
    };
    for (options.attachments, 0..) |attachment, index| render_pass._attachments[index] = .{ .format = attachment.format, .samples = attachment.samples };
    for (options.subpasses, 0..) |subpass, index| render_pass._subpasses[index] = .{
        .color_attachment_count = @intCast(subpass.color_attachments.len),
        .samples = graph.subpass_samples[index],
    };
    return render_pass;
}

pub const ImagelessAttachment = struct {
    flags: types.ImageCreateFlags = .empty,
    usage: types.ImageUsageFlags,
    width: u32,
    height: u32,
    layer_count: u32 = 1,
    view_formats: []const types.Format,
};

pub const FramebufferAttachments = union(enum) {
    views: []const *const image.View,
    imageless: []const ImagelessAttachment,
};

pub const FramebufferOptions = struct {
    render_pass: *const RenderPass,
    width: u32,
    height: u32,
    layers: u32 = 1,
    attachments: FramebufferAttachments,
};

pub const FramebufferDispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateFramebuffer),
    destroy: CommandFunction(raw.PFN_vkDestroyFramebuffer),
};

pub const Framebuffer = struct {
    _handle: ?FramebufferHandle,
    _owner: core.Owner,
    _render_pass_owner: core.Owner.Borrow,
    _device_handle: DeviceHandle,
    _device_state: ?core.DeviceState = null,
    _render_pass_handle: RenderPassHandle,
    width: u32,
    height: u32,
    layers: u32,
    attachment_count: usize,
    imageless: bool,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_framebuffer: CommandFunction(raw.PFN_vkDestroyFramebuffer),

    pub fn deinit(framebuffer: *Framebuffer) void {
        if (!(framebuffer._owner.release(framebuffer) catch return)) return;
        const handle = framebuffer._handle orelse return;
        framebuffer.destroy_framebuffer(framebuffer._device_handle, handle, framebuffer.allocation_callbacks);
        framebuffer._handle = null;
    }

    pub fn rawHandle(framebuffer: *const Framebuffer) core.Error!raw.VkFramebuffer {
        try framebuffer._owner.validate(framebuffer);
        if (framebuffer._device_state) |*state| try state.ensureDispatchAllowed();
        try framebuffer._render_pass_owner.validate();
        return framebuffer._handle orelse error.InactiveObject;
    }

    pub fn debugObject(framebuffer: *const Framebuffer) core.Error!debug_utils.Object {
        return .forDevice(.framebuffer, try framebuffer.rawHandle(), framebuffer._device_handle);
    }
};

pub fn createFramebuffer(
    device_handle: DeviceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: FramebufferDispatch,
    options: FramebufferOptions,
) core.Error!Framebuffer {
    if (options.render_pass._device_handle != device_handle or options.width == 0 or options.height == 0 or options.layers == 0) return error.InvalidOptions;
    const render_pass_handle = try options.render_pass.rawHandle();
    const live_render_pass_handle = render_pass_handle orelse return error.InactiveObject;
    var views: [framebuffer_attachment_count_max]raw.VkImageView = undefined;
    var image_infos: [framebuffer_attachment_count_max]raw.VkFramebufferAttachmentImageInfo = undefined;
    var formats: [framebuffer_view_format_count_max]raw.VkFormat = undefined;
    var format_count: usize = 0;
    var attachments_info: raw.VkFramebufferAttachmentsCreateInfo = .{ .sType = raw.VK_STRUCTURE_TYPE_FRAMEBUFFER_ATTACHMENTS_CREATE_INFO };
    var flags: raw.VkFramebufferCreateFlags = 0;
    var attachment_count: usize = 0;
    switch (options.attachments) {
        .views => |items| {
            if (items.len > framebuffer_attachment_count_max) return error.CountOverflow;
            if (items.len != options.render_pass.attachmentCount()) return error.InvalidOptions;
            attachment_count = items.len;
            for (items, 0..) |view, index| {
                if (view._device_handle != device_handle or view.format != options.render_pass.attachmentFormat(index).?) return error.InvalidHandle;
                if (view.samples) |samples| if (samples != options.render_pass.attachmentSamples(index).?) return error.InvalidOptions;
                if (view.extent) |extent| if (options.width > extent.width or options.height > extent.height) return error.InvalidOptions;
                if (view.layer_count) |layers| if (options.layers > layers) return error.InvalidOptions;
                views[index] = try view.rawHandle();
            }
        },
        .imageless => |items| {
            if (items.len > framebuffer_attachment_count_max) return error.CountOverflow;
            if (items.len != options.render_pass.attachmentCount()) return error.InvalidOptions;
            attachment_count = items.len;
            flags = @intCast(raw.VK_FRAMEBUFFER_CREATE_IMAGELESS_BIT);
            for (items, 0..) |item, index| {
                if (item.width == 0 or item.height == 0 or item.layer_count == 0 or item.view_formats.len == 0 or
                    item.width < options.width or item.height < options.height or item.layer_count < options.layers)
                {
                    return error.InvalidOptions;
                }
                if (item.view_formats.len > framebuffer_view_format_count_max - format_count) return error.CountOverflow;
                var compatible = false;
                const start = format_count;
                for (item.view_formats) |format| {
                    if (format == options.render_pass.attachmentFormat(index).?) compatible = true;
                    formats[format_count] = format.toRaw();
                    format_count += 1;
                }
                if (!compatible) return error.InvalidOptions;
                image_infos[index] = .{
                    .sType = raw.VK_STRUCTURE_TYPE_FRAMEBUFFER_ATTACHMENT_IMAGE_INFO,
                    .flags = item.flags.toRaw(),
                    .usage = item.usage.toRaw(),
                    .width = item.width,
                    .height = item.height,
                    .layerCount = item.layer_count,
                    .viewFormatCount = @intCast(item.view_formats.len),
                    .pViewFormats = formats[start..format_count].ptr,
                };
            }
            attachments_info.attachmentImageInfoCount = @intCast(items.len);
            attachments_info.pAttachmentImageInfos = if (items.len == 0) null else image_infos[0..items.len].ptr;
        },
    }
    const info: raw.VkFramebufferCreateInfo = .{
        .sType = raw.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
        .pNext = if (options.attachments == .imageless) &attachments_info else null,
        .flags = flags,
        .renderPass = render_pass_handle,
        .attachmentCount = @intCast(attachment_count),
        .pAttachments = if (options.attachments == .views and attachment_count != 0) views[0..attachment_count].ptr else null,
        .width = options.width,
        .height = options.height,
        .layers = options.layers,
    };
    var handle: raw.VkFramebuffer = null;
    const result = dispatch.create(device_handle, &info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional| dispatch.destroy(device_handle, provisional, allocation_callbacks);
        try core.checkSuccess(result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._owner = try .init(&handle),
        ._render_pass_owner = options.render_pass._owner.borrow(),
        ._device_handle = device_handle,
        ._render_pass_handle = live_render_pass_handle,
        .width = options.width,
        .height = options.height,
        .layers = options.layers,
        .attachment_count = attachment_count,
        .imageless = options.attachments == .imageless,
        .allocation_callbacks = allocation_callbacks,
        .destroy_framebuffer = dispatch.destroy,
    };
}

pub const Contents = enum(raw.VkSubpassContents) {
    inline_commands = raw.VK_SUBPASS_CONTENTS_INLINE,
    secondary_command_buffers = raw.VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS,
    _,

    pub fn fromRaw(value: raw.VkSubpassContents) Contents {
        return @enumFromInt(value);
    }

    pub fn toRaw(value: Contents) raw.VkSubpassContents {
        return @intFromEnum(value);
    }
};

pub const BeginOptions = struct {
    render_pass: *const RenderPass,
    framebuffer: *const Framebuffer,
    render_area: types.Rect2D,
    clear_values: []const types.ClearValue = &.{},
    imageless_attachments: []const *const image.View = &.{},
    contents: Contents = .inline_commands,
};

pub const Inheritance = struct {
    render_pass: *const RenderPass,
    subpass: u32 = 0,
    framebuffer: ?*const Framebuffer = null,
};

test "all render-pass declarations compile" {
    std.testing.refAllDecls(@This());
}

var test_result: raw.VkResult = raw.VK_SUCCESS;
var test_destroy_render_pass_count: usize = 0;
var test_destroy_framebuffer_count: usize = 0;
var test_create2_subpass_count: u32 = 0;
var test_legacy_has_multiview = false;
var test_legacy_has_input_aspects = false;
var test_framebuffer_imageless = false;

fn testCreateRenderPass(
    _: raw.VkDevice,
    info: [*c]const raw.VkRenderPassCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkRenderPass,
) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x2000);
    test_legacy_has_multiview = info.*.pNext != null;
    if (info.*.pNext) |next| {
        const multiview: *const raw.VkRenderPassMultiviewCreateInfo = @ptrCast(@alignCast(next));
        test_legacy_has_input_aspects = multiview.pNext != null;
    }
    return test_result;
}

fn testCreateRenderPass2(
    _: raw.VkDevice,
    info: [*c]const raw.VkRenderPassCreateInfo2,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkRenderPass,
) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x2000);
    test_create2_subpass_count = info.*.subpassCount;
    return test_result;
}

fn testDestroyRenderPass(
    _: raw.VkDevice,
    _: raw.VkRenderPass,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_render_pass_count += 1;
}

fn testGranularity(_: raw.VkDevice, _: raw.VkRenderPass, output: [*c]raw.VkExtent2D) callconv(.c) void {
    output.* = .{ .width = 4, .height = 2 };
}

fn testCreateFramebuffer(
    _: raw.VkDevice,
    info: [*c]const raw.VkFramebufferCreateInfo,
    _: [*c]const raw.VkAllocationCallbacks,
    output: [*c]raw.VkFramebuffer,
) callconv(.c) raw.VkResult {
    output.* = @ptrFromInt(0x3000);
    test_framebuffer_imageless = (info.*.flags & raw.VK_FRAMEBUFFER_CREATE_IMAGELESS_BIT) != 0 and info.*.pNext != null;
    return test_result;
}

fn testDestroyFramebuffer(
    _: raw.VkDevice,
    _: raw.VkFramebuffer,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {
    test_destroy_framebuffer_count += 1;
}

fn testDestroyImageView(
    _: raw.VkDevice,
    _: raw.VkImageView,
    _: [*c]const raw.VkAllocationCallbacks,
) callconv(.c) void {}

test "multi-subpass render passes validate graphs and support renderpass2 and legacy multiview" {
    const device_handle: DeviceHandle = @ptrFromInt(0x1000);
    const attachments = [_]Attachment{
        .{ .format = .r8g8b8a8_unorm, .final_layout = .color_attachment_optimal },
        .{ .format = .d32_sfloat, .final_layout = .depth_stencil_attachment_optimal },
    };
    const subpasses = [_]Subpass{
        .{
            .color_attachments = &.{.{ .attachment = .{ .index = 0, .layout = .color_attachment_optimal } }},
            .depth_stencil_attachment = .{ .attachment = .{ .index = 1, .layout = .depth_stencil_attachment_optimal } },
            .view_mask = 1,
        },
        .{
            .input_attachments = &.{.{ .attachment = .{ .index = 0, .layout = .shader_read_only_optimal, .aspects = .init(&.{.color}) } }},
            .color_attachments = &.{.{ .attachment = .{ .index = 0, .layout = .color_attachment_optimal } }},
            .preserve_attachments = &.{1},
            .view_mask = 1,
        },
    };
    const dependencies = [_]Dependency{.{
        .source = .{ .index = 0 },
        .destination = .{ .index = 1 },
        .source_stages = .init(&.{.color_attachment_output}),
        .destination_stages = .init(&.{.fragment_shader}),
        .source_access = .init(&.{.color_attachment_write}),
        .destination_access = .init(&.{.input_attachment_read}),
        .flags = .init(&.{ .by_region, .view_local }),
    }};
    const options: Options = .{
        .attachments = &attachments,
        .subpasses = &subpasses,
        .dependencies = &dependencies,
        .correlated_view_masks = &.{1},
    };
    const base_dispatch: Dispatch = .{
        .create = testCreateRenderPass,
        .create2 = testCreateRenderPass2,
        .destroy = testDestroyRenderPass,
        .get_granularity = testGranularity,
    };

    test_result = raw.VK_SUCCESS;
    test_create2_subpass_count = 0;
    test_destroy_render_pass_count = 0;
    var render_pass = try create(device_handle, null, base_dispatch, options);
    try std.testing.expectEqual(@as(u32, 2), test_create2_subpass_count);
    try std.testing.expectEqual(@as(usize, 2), render_pass.subpassCount());
    try std.testing.expectEqual(@as(u32, 1), render_pass.subpassColorAttachmentCount(1).?);
    try std.testing.expectEqual(types.Extent2D{ .width = 4, .height = 2 }, try render_pass.renderAreaGranularity());
    render_pass.deinit();
    render_pass.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_render_pass_count);

    var legacy_dispatch = base_dispatch;
    legacy_dispatch.create2 = null;
    test_legacy_has_multiview = false;
    test_legacy_has_input_aspects = false;
    var legacy = try create(device_handle, null, legacy_dispatch, options);
    defer legacy.deinit();
    try std.testing.expect(test_legacy_has_multiview);
    try std.testing.expect(test_legacy_has_input_aspects);

    var invalid_subpasses = subpasses;
    invalid_subpasses[0].color_attachments = &.{.{ .attachment = .{ .index = 2, .layout = .color_attachment_optimal } }};
    try std.testing.expectError(error.InvalidOptions, create(device_handle, null, base_dispatch, .{
        .attachments = &attachments,
        .subpasses = &invalid_subpasses,
    }));

    test_result = raw.VK_ERROR_OUT_OF_DEVICE_MEMORY;
    test_destroy_render_pass_count = 0;
    try std.testing.expectError(error.OutOfDeviceMemory, create(device_handle, null, base_dispatch, options));
    try std.testing.expectEqual(@as(usize, 1), test_destroy_render_pass_count);
    test_result = raw.VK_SUCCESS;
}

test "framebuffers validate attachment compatibility imageless chains and rollback" {
    const device_handle: DeviceHandle = @ptrFromInt(0x1000);
    var render_pass = try create(device_handle, null, .{
        .create = testCreateRenderPass,
        .create2 = testCreateRenderPass2,
        .destroy = testDestroyRenderPass,
        .get_granularity = testGranularity,
    }, .{
        .attachments = &.{.{ .format = .r8g8b8a8_unorm, .final_layout = .color_attachment_optimal }},
        .subpasses = &.{.{ .color_attachments = &.{.{ .attachment = .{ .index = 0, .layout = .color_attachment_optimal } }} }},
    });
    defer render_pass.deinit();
    const view: image.View = .{
        ._handle = @ptrFromInt(0x4000),
        ._owner = core.Owner.init({}) catch unreachable,
        ._device_handle = device_handle,
        .format = .r8g8b8a8_unorm,
        .samples = ._1,
        .extent = .{ .width = 128, .height = 64, .depth = 1 },
        .layer_count = 1,
        .allocation_callbacks = null,
        .destroy_image_view = testDestroyImageView,
    };
    const dispatch: FramebufferDispatch = .{ .create = testCreateFramebuffer, .destroy = testDestroyFramebuffer };
    test_framebuffer_imageless = false;
    test_destroy_framebuffer_count = 0;
    var framebuffer = try createFramebuffer(device_handle, null, dispatch, .{
        .render_pass = &render_pass,
        .width = 128,
        .height = 64,
        .attachments = .{ .views = &.{&view} },
    });
    framebuffer.deinit();
    framebuffer.deinit();
    try std.testing.expectEqual(@as(usize, 1), test_destroy_framebuffer_count);

    var imageless = try createFramebuffer(device_handle, null, dispatch, .{
        .render_pass = &render_pass,
        .width = 128,
        .height = 64,
        .attachments = .{ .imageless = &.{.{
            .usage = .init(&.{.color_attachment}),
            .width = 128,
            .height = 64,
            .view_formats = &.{.r8g8b8a8_unorm},
        }} },
    });
    defer imageless.deinit();
    try std.testing.expect(test_framebuffer_imageless);

    try std.testing.expectError(error.InvalidOptions, createFramebuffer(device_handle, null, dispatch, .{
        .render_pass = &render_pass,
        .width = 128,
        .height = 64,
        .attachments = .{ .imageless = &.{.{
            .usage = .init(&.{.color_attachment}),
            .width = 128,
            .height = 64,
            .view_formats = &.{.b8g8r8a8_unorm},
        }} },
    }));

    test_result = raw.VK_ERROR_OUT_OF_HOST_MEMORY;
    test_destroy_framebuffer_count = 0;
    try std.testing.expectError(error.OutOfHostMemory, createFramebuffer(device_handle, null, dispatch, .{
        .render_pass = &render_pass,
        .width = 128,
        .height = 64,
        .attachments = .{ .views = &.{&view} },
    }));
    try std.testing.expectEqual(@as(usize, 1), test_destroy_framebuffer_count);
    test_result = raw.VK_SUCCESS;
}
