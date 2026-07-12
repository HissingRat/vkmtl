const std = @import("std");
const core = @import("../../core.zig");
const metal = @import("metal_bridge");

pub fn translate(
    allocator: std.mem.Allocator,
    descriptor: core.ShaderSpecializationDescriptor,
) ![]metal.vkmtl_metal_function_constant {
    try descriptor.validateShape();
    const constants = try allocator.alloc(metal.vkmtl_metal_function_constant, descriptor.constants.len);
    for (descriptor.constants, constants) |constant, *out| {
        out.* = .{
            .id = constant.id,
            .kind = switch (constant.value) {
                .bool => metal.VKMTL_METAL_FUNCTION_CONSTANT_BOOL,
                .i32 => metal.VKMTL_METAL_FUNCTION_CONSTANT_I32,
                .u32 => metal.VKMTL_METAL_FUNCTION_CONSTANT_U32,
                .f32 => metal.VKMTL_METAL_FUNCTION_CONSTANT_F32,
            },
            .value_bits = switch (constant.value) {
                .bool => |value| @intFromBool(value),
                .i32 => |value| @bitCast(value),
                .u32 => |value| value,
                .f32 => |value| @bitCast(value),
            },
        };
    }
    return constants;
}

test "Metal specialization translation preserves ids types and bits" {
    const source = [_]core.ShaderSpecializationConstant{
        .{ .id = 1, .name = "enabled", .value = .{ .bool = true } },
        .{ .id = 2, .value = .{ .i32 = -7 } },
        .{ .id = 3, .value = .{ .u32 = 19 } },
        .{ .id = 4, .value = .{ .f32 = 1.5 } },
    };
    const translated = try translate(std.testing.allocator, .{ .constants = source[0..] });
    defer std.testing.allocator.free(translated);

    try std.testing.expectEqual(@as(usize, 4), translated.len);
    try std.testing.expectEqual(@as(u32, 1), translated[0].id);
    try std.testing.expectEqual(@as(c_uint, @intCast(metal.VKMTL_METAL_FUNCTION_CONSTANT_BOOL)), translated[0].kind);
    try std.testing.expectEqual(@as(u32, 1), translated[0].value_bits);
    try std.testing.expectEqual(@as(c_uint, @intCast(metal.VKMTL_METAL_FUNCTION_CONSTANT_I32)), translated[1].kind);
    try std.testing.expectEqual(@as(u32, @bitCast(@as(i32, -7))), translated[1].value_bits);
    try std.testing.expectEqual(@as(c_uint, @intCast(metal.VKMTL_METAL_FUNCTION_CONSTANT_U32)), translated[2].kind);
    try std.testing.expectEqual(@as(u32, 19), translated[2].value_bits);
    try std.testing.expectEqual(@as(c_uint, @intCast(metal.VKMTL_METAL_FUNCTION_CONSTANT_F32)), translated[3].kind);
    try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, 1.5))), translated[3].value_bits);
}
