const std = @import("std");
const metal = @import("metal_bridge");

pub const SharedEvent = struct {
    handle: *metal.vkmtl_metal_shared_event,

    pub const Error = error{
        MetalUnsupported,
        InvalidEvent,
        WaitTimeout,
        CommandFailed,
        UnexpectedMetalStatus,
    };

    pub fn init(owner: *metal.vkmtl_metal_clear_screen, initial_value: u64) Error!SharedEvent {
        var handle: ?*metal.vkmtl_metal_shared_event = null;
        try check(metal.vkmtl_metal_shared_event_create(owner, initial_value, &handle));
        return .{ .handle = handle orelse return Error.InvalidEvent };
    }

    pub fn deinit(self: *SharedEvent) void {
        metal.vkmtl_metal_shared_event_destroy(self.handle);
    }

    pub fn currentValue(self: SharedEvent) Error!u64 {
        var value: u64 = 0;
        try check(metal.vkmtl_metal_shared_event_get_value(self.handle, &value));
        return value;
    }

    pub fn signal(self: *SharedEvent, value: u64) Error!void {
        try check(metal.vkmtl_metal_shared_event_signal(self.handle, value));
    }

    pub fn wait(self: SharedEvent, value: u64, timeout_ns: ?u64) Error!void {
        try check(metal.vkmtl_metal_shared_event_wait(
            self.handle,
            value,
            timeout_ns orelse max_timeout_ns,
        ));
    }

    const max_timeout_ns = std.math.maxInt(u64);

    fn check(status: metal.vkmtl_metal_status) Error!void {
        return switch (status) {
            metal.VKMTL_METAL_STATUS_OK => {},
            metal.VKMTL_METAL_STATUS_UNSUPPORTED => Error.MetalUnsupported,
            metal.VKMTL_METAL_STATUS_QUERY_NOT_READY => Error.WaitTimeout,
            metal.VKMTL_METAL_STATUS_INVALID_COMMAND => Error.InvalidEvent,
            metal.VKMTL_METAL_STATUS_COMMAND_FAILED => Error.CommandFailed,
            else => Error.UnexpectedMetalStatus,
        };
    }
};
