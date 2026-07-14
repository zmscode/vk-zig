const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");

const CommandFunction = command.FunctionType;
const InstanceHandle = core.NonNullHandle(raw.VkInstance);
const MessengerHandle = core.NonNullHandle(raw.VkDebugUtilsMessengerEXT);

pub const SeverityBit = enum(u32) {
    verbose = raw.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT,
    info = raw.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT,
    warning = raw.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT,
    err = raw.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
};

pub const SeverityFlags = struct {
    bits: u32 = 0,

    pub const none: SeverityFlags = .{};
    pub const warning_and_error = SeverityFlags.init(&.{ .warning, .err });
    pub const all = SeverityFlags.init(&.{ .verbose, .info, .warning, .err });

    pub fn init(comptime values: []const SeverityBit) SeverityFlags {
        var result: u32 = 0;
        inline for (values) |value| result |= @intFromEnum(value);
        return .{ .bits = result };
    }

    pub fn contains(flags: SeverityFlags, bit: SeverityBit) bool {
        return (flags.bits & @intFromEnum(bit)) != 0;
    }

    pub fn with(flags: SeverityFlags, bit: SeverityBit) SeverityFlags {
        return .{ .bits = flags.bits | @intFromEnum(bit) };
    }

    pub fn toRaw(flags: SeverityFlags) raw.VkDebugUtilsMessageSeverityFlagsEXT {
        return @intCast(flags.bits);
    }

    fn fromRaw(value: raw.VkDebugUtilsMessageSeverityFlagsEXT) SeverityFlags {
        return .{ .bits = @intCast(value) };
    }
};

pub const MessageTypeBit = enum(u32) {
    general = raw.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT,
    validation = raw.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT,
    performance = raw.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
    device_address_binding = raw.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT,
};

pub const MessageTypeFlags = struct {
    bits: u32 = 0,

    pub const none: MessageTypeFlags = .{};
    pub const standard = MessageTypeFlags.init(&.{ .general, .validation, .performance });
    pub const all = MessageTypeFlags.init(&.{
        .general,
        .validation,
        .performance,
        .device_address_binding,
    });

    pub fn init(comptime values: []const MessageTypeBit) MessageTypeFlags {
        var result: u32 = 0;
        inline for (values) |value| result |= @intFromEnum(value);
        return .{ .bits = result };
    }

    pub fn contains(flags: MessageTypeFlags, bit: MessageTypeBit) bool {
        return (flags.bits & @intFromEnum(bit)) != 0;
    }

    pub fn with(flags: MessageTypeFlags, bit: MessageTypeBit) MessageTypeFlags {
        return .{ .bits = flags.bits | @intFromEnum(bit) };
    }

    pub fn toRaw(flags: MessageTypeFlags) raw.VkDebugUtilsMessageTypeFlagsEXT {
        return @intCast(flags.bits);
    }

    fn fromRaw(value: raw.VkDebugUtilsMessageTypeFlagsEXT) MessageTypeFlags {
        return .{ .bits = @intCast(value) };
    }
};

pub const HandlerResult = enum {
    continue_,
    abort,
};

pub const ObjectType = enum(u32) {
    unknown = raw.VK_OBJECT_TYPE_UNKNOWN,
    instance = raw.VK_OBJECT_TYPE_INSTANCE,
    physical_device = raw.VK_OBJECT_TYPE_PHYSICAL_DEVICE,
    device = raw.VK_OBJECT_TYPE_DEVICE,
    queue = raw.VK_OBJECT_TYPE_QUEUE,
    semaphore = raw.VK_OBJECT_TYPE_SEMAPHORE,
    command_buffer = raw.VK_OBJECT_TYPE_COMMAND_BUFFER,
    fence = raw.VK_OBJECT_TYPE_FENCE,
    device_memory = raw.VK_OBJECT_TYPE_DEVICE_MEMORY,
    buffer = raw.VK_OBJECT_TYPE_BUFFER,
    image = raw.VK_OBJECT_TYPE_IMAGE,
    event = raw.VK_OBJECT_TYPE_EVENT,
    query_pool = raw.VK_OBJECT_TYPE_QUERY_POOL,
    buffer_view = raw.VK_OBJECT_TYPE_BUFFER_VIEW,
    image_view = raw.VK_OBJECT_TYPE_IMAGE_VIEW,
    shader_module = raw.VK_OBJECT_TYPE_SHADER_MODULE,
    pipeline_cache = raw.VK_OBJECT_TYPE_PIPELINE_CACHE,
    pipeline_layout = raw.VK_OBJECT_TYPE_PIPELINE_LAYOUT,
    render_pass = raw.VK_OBJECT_TYPE_RENDER_PASS,
    pipeline = raw.VK_OBJECT_TYPE_PIPELINE,
    descriptor_set_layout = raw.VK_OBJECT_TYPE_DESCRIPTOR_SET_LAYOUT,
    sampler = raw.VK_OBJECT_TYPE_SAMPLER,
    descriptor_pool = raw.VK_OBJECT_TYPE_DESCRIPTOR_POOL,
    descriptor_set = raw.VK_OBJECT_TYPE_DESCRIPTOR_SET,
    descriptor_update_template = raw.VK_OBJECT_TYPE_DESCRIPTOR_UPDATE_TEMPLATE,
    framebuffer = raw.VK_OBJECT_TYPE_FRAMEBUFFER,
    command_pool = raw.VK_OBJECT_TYPE_COMMAND_POOL,
    surface = raw.VK_OBJECT_TYPE_SURFACE_KHR,
    swapchain = raw.VK_OBJECT_TYPE_SWAPCHAIN_KHR,
    debug_messenger = raw.VK_OBJECT_TYPE_DEBUG_UTILS_MESSENGER_EXT,
    sampler_ycbcr_conversion = raw.VK_OBJECT_TYPE_SAMPLER_YCBCR_CONVERSION,
    optical_flow_session = raw.VK_OBJECT_TYPE_OPTICAL_FLOW_SESSION_NV,
    _,

    fn fromRaw(value: raw.VkObjectType) ObjectType {
        return @enumFromInt(value);
    }

    pub fn toRaw(value: ObjectType) raw.VkObjectType {
        return @intCast(@intFromEnum(value));
    }
};

pub const MessageObject = struct {
    object_type: ObjectType,
    handle: u64,
    name: ?[]const u8,
};

pub const ObjectInfo = MessageObject;

/// A typed debug-name target produced by vk-zig wrapper objects.
pub const Object = struct {
    object_type: ObjectType,
    handle: u64,
    _device_handle: ?core.NonNullHandle(raw.VkDevice) = null,
    _instance_handle: ?InstanceHandle = null,

    pub fn forDevice(
        object_type: ObjectType,
        handle: anytype,
        device_handle: core.NonNullHandle(raw.VkDevice),
    ) core.Error!Object {
        return .{
            .object_type = object_type,
            .handle = try core.handleValue(handle),
            ._device_handle = device_handle,
        };
    }

    pub fn forInstance(
        object_type: ObjectType,
        handle: anytype,
        instance_handle: InstanceHandle,
    ) core.Error!Object {
        return .{
            .object_type = object_type,
            .handle = try core.handleValue(handle),
            ._instance_handle = instance_handle,
        };
    }

    pub fn validateParent(
        object: Object,
        device_handle: core.NonNullHandle(raw.VkDevice),
        instance_handle: InstanceHandle,
    ) core.Error!void {
        if (object._device_handle) |owner| {
            if (owner != device_handle) return error.InvalidHandle;
        }
        if (object._instance_handle) |owner| {
            if (owner != instance_handle) return error.InvalidHandle;
        }
    }
};

/// Converts any vk-zig wrapper with a `debugObject` method into a naming target.
/// This is the common compile-time contract used by `Device.setObjectName`.
pub fn nameTarget(value: anytype) core.Error!Object {
    const Pointer = @TypeOf(value);
    const pointer = switch (@typeInfo(Pointer)) {
        .pointer => |info| info,
        else => @compileError("a debug-name target must be passed by pointer"),
    };
    if (!@hasDecl(pointer.child, "debugObject")) {
        @compileError(@typeName(pointer.child) ++ " does not implement debugObject");
    }
    return value.debugObject();
}

pub const MessageLabel = struct {
    name: ?[]const u8,
    color: [4]f32,
};

pub const LabelInfo = MessageLabel;

/// A safe borrowed view over callback data. It is valid only during the callback.
pub const Message = struct {
    severity: SeverityFlags,
    message_types: MessageTypeFlags,
    _data: *const raw.VkDebugUtilsMessengerCallbackDataEXT,

    fn fromRawCallback(
        severity: raw.VkDebugUtilsMessageSeverityFlagBitsEXT,
        message_types: raw.VkDebugUtilsMessageTypeFlagsEXT,
        data: [*c]const raw.VkDebugUtilsMessengerCallbackDataEXT,
    ) ?Message {
        if (data == null) return null;
        return .{
            .severity = .fromRaw(@intCast(severity)),
            .message_types = .fromRaw(message_types),
            ._data = @ptrCast(data),
        };
    }

    pub fn text(message: Message) ?[]const u8 {
        return optionalCString(message._data.pMessage);
    }

    pub fn idName(message: Message) ?[]const u8 {
        return optionalCString(message._data.pMessageIdName);
    }

    pub fn idNumber(message: Message) i32 {
        return message._data.messageIdNumber;
    }

    pub fn isError(message: Message) bool {
        return message.severity.contains(.err);
    }

    pub fn isWarning(message: Message) bool {
        return message.severity.contains(.warning);
    }

    pub fn isInfo(message: Message) bool {
        return message.severity.contains(.info);
    }

    pub fn isVerbose(message: Message) bool {
        return message.severity.contains(.verbose);
    }

    pub fn isGeneral(message: Message) bool {
        return message.message_types.contains(.general);
    }

    pub fn isValidation(message: Message) bool {
        return message.message_types.contains(.validation);
    }

    pub fn isPerformance(message: Message) bool {
        return message.message_types.contains(.performance);
    }

    pub fn isDeviceAddressBinding(message: Message) bool {
        return message.message_types.contains(.device_address_binding);
    }

    pub fn objectCount(message: Message) usize {
        return message._data.objectCount;
    }

    pub fn object(message: Message, index: usize) ?ObjectInfo {
        if (index >= message.objectCount() or message._data.pObjects == null) return null;
        const value = message._data.pObjects[index];
        return .{
            .object_type = .fromRaw(value.objectType),
            .handle = value.objectHandle,
            .name = optionalCString(value.pObjectName),
        };
    }

    pub fn queueLabelCount(message: Message) usize {
        return message._data.queueLabelCount;
    }

    pub fn queueLabel(message: Message, index: usize) ?LabelInfo {
        if (index >= message.queueLabelCount() or message._data.pQueueLabels == null) return null;
        return labelInfo(message._data.pQueueLabels[index]);
    }

    pub fn commandBufferLabelCount(message: Message) usize {
        return message._data.cmdBufLabelCount;
    }

    pub fn commandBufferLabel(message: Message, index: usize) ?LabelInfo {
        if (index >= message.commandBufferLabelCount() or
            message._data.pCmdBufLabels == null) return null;
        return labelInfo(message._data.pCmdBufLabels[index]);
    }
};

pub const ConfigOptions = struct {
    severity: SeverityFlags = .warning_and_error,
    message_types: MessageTypeFlags = .standard,
};

pub const MessengerConfigOptions = ConfigOptions;

/// Type-erased configuration whose C ABI trampoline remains private to vk-zig.
pub const Config = struct {
    _callback: CommandFunction(raw.PFN_vkDebugUtilsMessengerCallbackEXT),
    _handler: *const fn (?*anyopaque, Message) HandlerResult,
    _user_data: ?*anyopaque,
    severity: SeverityFlags,
    message_types: MessageTypeFlags,

    pub fn fromHandler(comptime handler: anytype, options: ConfigOptions) Config {
        validateHandler(@TypeOf(handler), null);
        const Adapter = HandlerAdapter(handler);
        return .{
            ._callback = Adapter.callback,
            ._handler = Adapter.handle,
            ._user_data = null,
            .severity = options.severity,
            .message_types = options.message_types,
        };
    }

    pub fn fromHandlerWithContext(
        context: anytype,
        options: ConfigOptions,
        comptime handler: anytype,
    ) Config {
        const ContextPointer = @TypeOf(context);
        const pointer_info = switch (@typeInfo(ContextPointer)) {
            .pointer => |pointer| pointer,
            else => @compileError("debug messenger context must be a pointer"),
        };
        if (pointer_info.size != .one or pointer_info.is_allowzero) {
            @compileError("debug messenger context must be a non-allowzero single-item pointer");
        }
        validateHandler(@TypeOf(handler), ContextPointer);
        const Adapter = ContextHandlerAdapter(ContextPointer, handler);
        const user_data: *anyopaque = if (pointer_info.is_const)
            @ptrCast(@constCast(context))
        else
            @ptrCast(context);
        return .{
            ._callback = Adapter.callback,
            ._handler = Adapter.handle,
            ._user_data = user_data,
            .severity = options.severity,
            .message_types = options.message_types,
        };
    }

    pub fn dispatch(config: Config, message: Message) HandlerResult {
        return config._handler(config._user_data, message);
    }

    fn createInfoRaw(
        config: Config,
        next: ?*const anyopaque,
    ) raw.VkDebugUtilsMessengerCreateInfoEXT {
        return .{
            .sType = raw.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .pNext = next,
            .messageSeverity = config.severity.toRaw(),
            .messageType = config.message_types.toRaw(),
            .pfnUserCallback = config._callback,
            .pUserData = config._user_data,
        };
    }
};

/// Explicit raw-ABI escape hatches. Normal diagnostics code should only use `Config` and
/// `Message` through `InstanceOptions.debug_messenger` and typed handlers.
pub const advanced = struct {
    pub fn messengerCreateInfo(
        config: Config,
        next: ?*const anyopaque,
    ) raw.VkDebugUtilsMessengerCreateInfoEXT {
        return config.createInfoRaw(next);
    }

    pub fn messageFromRawCallback(
        severity: raw.VkDebugUtilsMessageSeverityFlagBitsEXT,
        message_types: raw.VkDebugUtilsMessageTypeFlagsEXT,
        data: [*c]const raw.VkDebugUtilsMessengerCallbackDataEXT,
    ) ?Message {
        return .fromRawCallback(severity, message_types, data);
    }

    pub fn callbackData(message: Message) *const raw.VkDebugUtilsMessengerCallbackDataEXT {
        return message._data;
    }
};

pub const MessengerConfig = Config;

pub const LabelOptions = struct {
    name: [:0]const u8,
    color: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },

    pub fn toRaw(options: LabelOptions) raw.VkDebugUtilsLabelEXT {
        return .{
            .sType = raw.VK_STRUCTURE_TYPE_DEBUG_UTILS_LABEL_EXT,
            .pLabelName = options.name.ptr,
            .color = options.color,
        };
    }
};

pub const Messenger = struct {
    _handle: ?MessengerHandle,
    _instance_handle: InstanceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy_messenger: CommandFunction(raw.PFN_vkDestroyDebugUtilsMessengerEXT),

    pub fn deinit(messenger: *Messenger) void {
        const handle = messenger._handle orelse return;
        messenger.destroy_messenger(
            messenger._instance_handle,
            handle,
            messenger.allocation_callbacks,
        );
        messenger._handle = null;
    }

    pub fn rawHandle(messenger: *const Messenger) core.Error!raw.VkDebugUtilsMessengerEXT {
        return messenger._handle orelse error.InactiveObject;
    }

    pub fn debugObject(messenger: *const Messenger) core.Error!Object {
        return .forInstance(.debug_messenger, try messenger.rawHandle(), messenger._instance_handle);
    }
};

pub const MessengerDispatch = struct {
    create: CommandFunction(raw.PFN_vkCreateDebugUtilsMessengerEXT),
    destroy: CommandFunction(raw.PFN_vkDestroyDebugUtilsMessengerEXT),
};

pub fn createMessenger(
    instance_handle: InstanceHandle,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    dispatch: MessengerDispatch,
    config: Config,
) core.Error!Messenger {
    const create_info = advanced.messengerCreateInfo(config, null);
    var handle: raw.VkDebugUtilsMessengerEXT = null;
    const result = dispatch.create(instance_handle, &create_info, allocation_callbacks, &handle);
    if (result != raw.VK_SUCCESS) {
        if (handle) |provisional_handle| {
            dispatch.destroy(instance_handle, provisional_handle, allocation_callbacks);
        }
        try core.checkSuccess(result);
        unreachable;
    }
    return .{
        ._handle = handle orelse return error.InvalidHandle,
        ._instance_handle = instance_handle,
        .allocation_callbacks = allocation_callbacks,
        .destroy_messenger = dispatch.destroy,
    };
}

fn validateHandler(comptime Handler: type, comptime ContextPointer: ?type) void {
    const function_info = switch (@typeInfo(Handler)) {
        .@"fn" => |function| function,
        else => @compileError("debug message handler must be a function"),
    };
    const parameter_count: usize = if (ContextPointer == null) 1 else 2;
    if (function_info.params.len != parameter_count) {
        @compileError("debug message handler has the wrong parameter count");
    }
    if (ContextPointer) |ExpectedContext| {
        const actual_context = function_info.params[0].type orelse {
            @compileError("debug message handler context type must be explicit");
        };
        if (actual_context != ExpectedContext) {
            @compileError("debug message handler context type does not match its pointer");
        }
    }
    const message_index: usize = if (ContextPointer == null) 0 else 1;
    const actual_message = function_info.params[message_index].type orelse {
        @compileError("debug message handler message type must be explicit");
    };
    if (actual_message != Message) {
        @compileError("debug message handler must accept debug_utils.Message");
    }
    const Return = function_info.return_type orelse {
        @compileError("debug message handler must have an explicit return type");
    };
    if (Return != void and Return != HandlerResult) {
        @compileError("debug message handler must return void or HandlerResult");
    }
}

fn invokeHandler(comptime handler: anytype, arguments: anytype) HandlerResult {
    const Return = @typeInfo(@TypeOf(handler)).@"fn".return_type.?;
    if (Return == void) {
        @call(.auto, handler, arguments);
        return .continue_;
    }
    return @call(.auto, handler, arguments);
}

fn rawHandlerResult(result: HandlerResult) raw.VkBool32 {
    return if (result == .abort) raw.VK_TRUE else raw.VK_FALSE;
}

fn HandlerAdapter(comptime handler: anytype) type {
    return struct {
        fn handle(_: ?*anyopaque, message: Message) HandlerResult {
            return invokeHandler(handler, .{message});
        }

        fn callback(
            severity: raw.VkDebugUtilsMessageSeverityFlagBitsEXT,
            message_types: raw.VkDebugUtilsMessageTypeFlagsEXT,
            callback_data: [*c]const raw.VkDebugUtilsMessengerCallbackDataEXT,
            _: ?*anyopaque,
        ) callconv(.c) raw.VkBool32 {
            const message = Message.fromRawCallback(
                severity,
                message_types,
                callback_data,
            ) orelse return raw.VK_FALSE;
            return rawHandlerResult(handle(null, message));
        }
    };
}

fn ContextHandlerAdapter(comptime ContextPointer: type, comptime handler: anytype) type {
    return struct {
        fn handle(user_data: ?*anyopaque, message: Message) HandlerResult {
            const opaque_context = user_data orelse return .continue_;
            const context: ContextPointer = @ptrCast(@alignCast(opaque_context));
            return invokeHandler(handler, .{ context, message });
        }

        fn callback(
            severity: raw.VkDebugUtilsMessageSeverityFlagBitsEXT,
            message_types: raw.VkDebugUtilsMessageTypeFlagsEXT,
            callback_data: [*c]const raw.VkDebugUtilsMessengerCallbackDataEXT,
            user_data: ?*anyopaque,
        ) callconv(.c) raw.VkBool32 {
            const message = Message.fromRawCallback(
                severity,
                message_types,
                callback_data,
            ) orelse return raw.VK_FALSE;
            return rawHandlerResult(handle(user_data, message));
        }
    };
}

fn optionalCString(pointer: [*c]const u8) ?[]const u8 {
    if (pointer == null) return null;
    const sentinel: [*:0]const u8 = @ptrCast(pointer);
    return std.mem.span(sentinel);
}

fn labelInfo(value: raw.VkDebugUtilsLabelEXT) LabelInfo {
    return .{ .name = optionalCString(value.pLabelName), .color = value.color };
}
