const std = @import("std");

pub const RayTracingMode = enum {
    automatic,
    disabled,
    required,
};

pub const ParseError = error{InvalidRayTracingMode};

pub fn parseRayTracingMode(value: ?[]const u8) ParseError!RayTracingMode {
    const text = value orelse return .automatic;
    if (std.ascii.eqlIgnoreCase(text, "auto")) return .automatic;
    if (std.ascii.eqlIgnoreCase(text, "off") or
        std.ascii.eqlIgnoreCase(text, "0") or
        std.ascii.eqlIgnoreCase(text, "false"))
    {
        return .disabled;
    }
    if (std.ascii.eqlIgnoreCase(text, "required") or
        std.ascii.eqlIgnoreCase(text, "on") or
        std.ascii.eqlIgnoreCase(text, "1") or
        std.ascii.eqlIgnoreCase(text, "true"))
    {
        return .required;
    }
    return ParseError.InvalidRayTracingMode;
}

test "ray tracing mode parsing is explicit" {
    try std.testing.expectEqual(RayTracingMode.automatic, try parseRayTracingMode(null));
    try std.testing.expectEqual(RayTracingMode.automatic, try parseRayTracingMode("AUTO"));
    try std.testing.expectEqual(RayTracingMode.disabled, try parseRayTracingMode("off"));
    try std.testing.expectEqual(RayTracingMode.disabled, try parseRayTracingMode("0"));
    try std.testing.expectEqual(RayTracingMode.required, try parseRayTracingMode("on"));
    try std.testing.expectEqual(RayTracingMode.required, try parseRayTracingMode("required"));
    try std.testing.expectError(ParseError.InvalidRayTracingMode, parseRayTracingMode("maybe"));
}
