const std = @import("std");

pub fn displayLinearChannel(display_encoded: f32) f32 {
    if (!std.math.isFinite(display_encoded) or display_encoded <= 0.0) return 0.0;
    const value = std.math.clamp(display_encoded, 0.0, 1.0);
    if (value <= 0.04045) return value / 12.92;
    return std.math.pow(f32, (value + 0.055) / 1.055, 2.4);
}

pub fn linearToSrgb(display_linear: f32) f32 {
    const value = std.math.clamp(display_linear, 0.0, 1.0);
    if (value <= 0.0031308) return value * 12.92;
    return 1.055 * std.math.pow(f32, value, 1.0 / 2.4) - 0.055;
}

pub fn quantizedSrgb8(display_encoded: f32) u8 {
    return @intFromFloat(@round(linearToSrgb(displayLinearChannel(display_encoded)) * 255.0));
}

pub fn displayLinearColor(display_encoded: [3]f32) [3]f32 {
    for (display_encoded) |channel| {
        if (!std.math.isFinite(channel)) return .{ 0.0, 0.0, 0.0 };
    }
    return .{
        displayLinearChannel(display_encoded[0]),
        displayLinearChannel(display_encoded[1]),
        displayLinearChannel(display_encoded[2]),
    };
}

pub fn quantizedSrgb8Color(display_encoded: [3]f32) [3]u8 {
    const display_linear = displayLinearColor(display_encoded);
    return .{
        @intFromFloat(@round(linearToSrgb(display_linear[0]) * 255.0)),
        @intFromFloat(@round(linearToSrgb(display_linear[1]) * 255.0)),
        @intFromFloat(@round(linearToSrgb(display_linear[2]) * 255.0)),
    };
}

test "reference display transform decodes historical display values" {
    try std.testing.expectEqual(@as(f32, 0.0), displayLinearChannel(-1.0));
    try std.testing.expectEqual(@as(f32, 0.0), displayLinearChannel(std.math.nan(f32)));
    try std.testing.expectEqual(@as(f32, 0.0), displayLinearChannel(std.math.inf(f32)));
    try std.testing.expectApproxEqAbs(@as(f32, 0.02721178), displayLinearChannel(0.18), 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.21404114), displayLinearChannel(0.5), 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.60382734), displayLinearChannel(0.8), 0.000001);
    try std.testing.expectEqual(@as(f32, 1.0), displayLinearChannel(1.0));
    try std.testing.expectEqual(@as(f32, 1.0), displayLinearChannel(4.0));
}

test "sRGB attachment reproduces historical reference bytes" {
    try std.testing.expectEqual(@as(u8, 0), quantizedSrgb8(0.0));
    try std.testing.expectEqual(@as(u8, 46), quantizedSrgb8(0.18));
    try std.testing.expectEqual(@as(u8, 128), quantizedSrgb8(0.5));
    try std.testing.expectEqual(@as(u8, 204), quantizedSrgb8(0.8));
    try std.testing.expectEqual(@as(u8, 255), quantizedSrgb8(1.0));
    try std.testing.expectEqual(@as(u8, 255), quantizedSrgb8(4.0));
}

test "emissive reference colors remain saturated" {
    try std.testing.expectEqual([3]u8{ 255, 204, 0 }, quantizedSrgb8Color(.{ 1.0, 0.8, 0.0 }));
    try std.testing.expectEqual([3]u8{ 0, 0, 255 }, quantizedSrgb8Color(.{ 0.0, 0.0, 1.0 }));
    try std.testing.expectEqual([3]u8{ 0, 0, 0 }, quantizedSrgb8Color(.{ std.math.nan(f32), 0.5, 1.0 }));
}
