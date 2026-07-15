const std = @import("std");

pub const zero_extent_timeout_seconds: f64 = 5.0;

pub const FrameLimitError = error{
    InvalidRayTracingFrameLimit,
    ZeroRayTracingFrameLimit,
};

pub fn parseFrameLimit(value: ?[]const u8) FrameLimitError!?u64 {
    const text = value orelse return null;
    const limit = std.fmt.parseInt(u64, text, 10) catch {
        return FrameLimitError.InvalidRayTracingFrameLimit;
    };
    if (limit == 0) return FrameLimitError.ZeroRayTracingFrameLimit;
    return limit;
}

pub fn reachedFrameLimit(limit: ?u64, rendered_frames: u64) bool {
    return if (limit) |value| rendered_frames >= value else false;
}

pub const ZeroExtentWatchdog = struct {
    started_at_seconds: ?f64 = null,

    pub fn observe(self: *ZeroExtentWatchdog, now_seconds: f64) bool {
        const started_at = self.started_at_seconds orelse {
            self.started_at_seconds = now_seconds;
            return false;
        };
        if (now_seconds < started_at) {
            self.started_at_seconds = now_seconds;
            return false;
        }
        return now_seconds - started_at >= zero_extent_timeout_seconds;
    }

    pub fn reset(self: *ZeroExtentWatchdog) void {
        self.started_at_seconds = null;
    }
};

test "finite frame limit parsing is strict" {
    try std.testing.expectEqual(@as(?u64, null), try parseFrameLimit(null));
    try std.testing.expectEqual(@as(?u64, 3), try parseFrameLimit("3"));
    try std.testing.expectError(FrameLimitError.InvalidRayTracingFrameLimit, parseFrameLimit(""));
    try std.testing.expectError(FrameLimitError.InvalidRayTracingFrameLimit, parseFrameLimit("three"));
    try std.testing.expectError(FrameLimitError.InvalidRayTracingFrameLimit, parseFrameLimit("-1"));
    try std.testing.expectError(FrameLimitError.ZeroRayTracingFrameLimit, parseFrameLimit("0"));
}

test "finite run completion requires the requested rendered frame count" {
    try std.testing.expect(!reachedFrameLimit(null, 100));
    try std.testing.expect(!reachedFrameLimit(3, 2));
    try std.testing.expect(reachedFrameLimit(3, 3));
    try std.testing.expect(reachedFrameLimit(3, 4));
}

test "zero extent watchdog times out and resets" {
    var watchdog = ZeroExtentWatchdog{};
    try std.testing.expect(!watchdog.observe(10.0));
    try std.testing.expect(!watchdog.observe(10.0 + zero_extent_timeout_seconds - 0.001));
    try std.testing.expect(watchdog.observe(10.0 + zero_extent_timeout_seconds));

    watchdog.reset();
    try std.testing.expect(!watchdog.observe(30.0));
    try std.testing.expect(!watchdog.observe(29.0));
    try std.testing.expect(!watchdog.observe(29.0 + zero_extent_timeout_seconds - 0.001));
    try std.testing.expect(watchdog.observe(29.0 + zero_extent_timeout_seconds));
}
