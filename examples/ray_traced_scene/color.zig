const std = @import("std");

pub const exposure: f32 = 1.0;

pub fn displayLinearChannel(scene_linear: f32) f32 {
    if (!std.math.isFinite(scene_linear) or scene_linear <= 0.0) return 0.0;
    const value = scene_linear * exposure;
    const numerator = value * (2.51 * value + 0.03);
    const denominator = value * (2.43 * value + 0.59) + 0.14;
    return std.math.clamp(numerator / denominator, 0.0, 1.0);
}

pub fn linearToSrgb(display_linear: f32) f32 {
    const value = std.math.clamp(display_linear, 0.0, 1.0);
    if (value <= 0.0031308) return value * 12.92;
    return 1.055 * std.math.pow(f32, value, 1.0 / 2.4) - 0.055;
}

pub fn quantizedSrgb8(scene_linear: f32) u8 {
    return @intFromFloat(@round(linearToSrgb(displayLinearChannel(scene_linear)) * 255.0));
}

test "ACES display transform has stable reference points" {
    try std.testing.expectEqual(@as(f32, 0.0), displayLinearChannel(-1.0));
    try std.testing.expectEqual(@as(f32, 0.0), displayLinearChannel(std.math.nan(f32)));
    try std.testing.expectEqual(@as(f32, 0.0), displayLinearChannel(std.math.inf(f32)));
    try std.testing.expectApproxEqAbs(@as(f32, 0.26689893), displayLinearChannel(0.18), 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6163069), displayLinearChannel(0.5), 0.000001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8037974), displayLinearChannel(1.0), 0.000001);
    try std.testing.expect(displayLinearChannel(4.0) > displayLinearChannel(1.0));
    try std.testing.expect(displayLinearChannel(65504.0) <= 1.0);
}

test "sRGB attachment reference bytes include tone mapping exactly once" {
    try std.testing.expectEqual(@as(u8, 0), quantizedSrgb8(0.0));
    try std.testing.expectEqual(@as(u8, 141), quantizedSrgb8(0.18));
    try std.testing.expectEqual(@as(u8, 206), quantizedSrgb8(0.5));
    try std.testing.expectEqual(@as(u8, 232), quantizedSrgb8(1.0));
}
