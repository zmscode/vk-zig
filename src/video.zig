const std = @import("std");
const raw = @import("vulkan_raw");
const command = @import("vulkan_commands");
const core = @import("core.zig");
const debug_utils = @import("debug_utils.zig");

const CommandFunction = command.FunctionType;
const DeviceHandle = core.NonNullHandle(raw.VkDevice);
const SessionHandle = core.NonNullHandle(raw.VkVideoSessionKHR);
const ParametersHandle = core.NonNullHandle(raw.VkVideoSessionParametersKHR);

pub const Session = struct {
    _handle: ?SessionHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: core.DeviceState,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy: CommandFunction(raw.PFN_vkDestroyVideoSessionKHR),

    pub fn deinit(session: *Session) void {
        if (!(session._owner.release(session) catch return)) return;
        const handle = session._handle orelse return;
        session.destroy(session._device_handle, handle, session.allocation_callbacks);
        session._handle = null;
    }

    pub fn rawHandle(session: *const Session) core.Error!raw.VkVideoSessionKHR {
        try session._owner.validate(session);
        try session._device_state.ensureDispatchAllowed();
        return session._handle orelse error.InactiveObject;
    }

    pub fn debugObject(session: *const Session) core.Error!debug_utils.Object {
        return .forDevice(.video_session, try session.rawHandle(), session._device_handle);
    }
};

pub const Parameters = struct {
    _handle: ?ParametersHandle,
    _owner: core.Owner,
    _device_handle: DeviceHandle,
    _device_state: core.DeviceState,
    allocation_callbacks: ?*const raw.VkAllocationCallbacks,
    destroy: CommandFunction(raw.PFN_vkDestroyVideoSessionParametersKHR),

    pub fn deinit(parameters: *Parameters) void {
        if (!(parameters._owner.release(parameters) catch return)) return;
        const handle = parameters._handle orelse return;
        parameters.destroy(parameters._device_handle, handle, parameters.allocation_callbacks);
        parameters._handle = null;
    }

    pub fn rawHandle(parameters: *const Parameters) core.Error!raw.VkVideoSessionParametersKHR {
        try parameters._owner.validate(parameters);
        try parameters._device_state.ensureDispatchAllowed();
        return parameters._handle orelse error.InactiveObject;
    }

    pub fn debugObject(parameters: *const Parameters) core.Error!debug_utils.Object {
        return .forDevice(.video_session_parameters, try parameters.rawHandle(), parameters._device_handle);
    }
};

pub const CodingOptions = struct {
    session: *const Session,
    parameters: ?*const Parameters = null,
};

test "all base video declarations compile" {
    std.testing.refAllDecls(@This());
}
