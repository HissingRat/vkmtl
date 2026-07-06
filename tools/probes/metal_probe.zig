const std = @import("std");
const metal = @import("metal_bridge");

const ProbeError = error{
    MetalUnsupported,
    NoMetalDevice,
    DeviceNameBufferTooSmall,
    UnexpectedMetalStatus,
};

pub fn main() !void {
    const probe = Probe.init() catch |err| switch (err) {
        ProbeError.MetalUnsupported => {
            std.debug.print("Metal unsupported on this target\n", .{});
            return;
        },
        else => |narrow| return narrow,
    };
    defer probe.deinit();

    var name_buffer: [256]u8 = undefined;
    const name = try probe.deviceName(&name_buffer);
    std.debug.print("Metal device: {s}\n", .{name});
}

const Probe = struct {
    handle: *metal.vkmtl_metal_probe,

    fn init() !Probe {
        var handle: ?*metal.vkmtl_metal_probe = null;
        try check(metal.vkmtl_metal_probe_create(&handle));
        return .{ .handle = handle orelse return ProbeError.NoMetalDevice };
    }

    fn deinit(self: Probe) void {
        metal.vkmtl_metal_probe_destroy(self.handle);
    }

    fn deviceName(self: Probe, buffer: []u8) ![]const u8 {
        try check(metal.vkmtl_metal_probe_copy_device_name(
            self.handle,
            buffer.ptr,
            buffer.len,
        ));
        return std.mem.sliceTo(buffer, 0);
    }
};

fn check(status: metal.vkmtl_metal_status) ProbeError!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => ProbeError.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_NO_DEVICE => ProbeError.NoMetalDevice,
        metal.VKMTL_METAL_STATUS_NAME_BUFFER_TOO_SMALL => ProbeError.DeviceNameBufferTooSmall,
        else => ProbeError.UnexpectedMetalStatus,
    };
}
