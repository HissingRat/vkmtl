const std = @import("std");
const scene = @import("scene.zig");

pub const shader_name = "voxel_world_sky";
pub const shader_source = @embedFile("shaders/voxel_world_sky.slang");
pub const vertex_entry = "sky_vs";
pub const fragment_entry = "sky_fs";

const default_aspect: f32 = 16.0 / 9.0;
const vertical_field_of_view = std.math.degreesToRadians(62.0);

/// Camera vectors are pre-scaled on the CPU so the fullscreen shader only
/// needs one normalize to reconstruct a world-space view ray.
pub const Uniforms = extern struct {
    camera_forward_and_time: [4]f32,
    camera_horizontal_span: [4]f32,
    camera_vertical_span: [4]f32,
    camera_position_and_cloud_time: [4]f32,
    sun_direction_and_radius: [4]f32,
    moon_direction_and_radius: [4]f32,
    cycle_blend_and_phase: [4]f32,
};

comptime {
    if (@sizeOf(Uniforms) != 112) @compileError("voxel sky uniforms must match the 112-byte shader ABI");
}

pub fn makeUniforms(
    camera: scene.Camera,
    celestial_time_seconds: f32,
    cloud_time_seconds: f32,
) Uniforms {
    return makeUniformsForAspect(
        camera,
        celestial_time_seconds,
        cloud_time_seconds,
        default_aspect,
    );
}

pub fn makeUniformsForAspect(
    camera: scene.Camera,
    celestial_time_seconds: f32,
    cloud_time_seconds: f32,
    aspect: f32,
) Uniforms {
    const safe_aspect = if (std.math.isFinite(aspect) and aspect > 0) aspect else default_aspect;
    const safe_celestial_time = if (std.math.isFinite(celestial_time_seconds)) celestial_time_seconds else 0;
    const safe_cloud_time = if (std.math.isFinite(cloud_time_seconds)) cloud_time_seconds else 0;
    const vertical_span = @tan(vertical_field_of_view * 0.5);
    const forward = camera.forward();
    const right = camera.right();
    const up = camera.up();
    const celestial = scene.celestialState(safe_celestial_time);
    return .{
        .camera_forward_and_time = .{ forward[0], forward[1], forward[2], safe_celestial_time },
        .camera_horizontal_span = .{
            right[0] * vertical_span * safe_aspect,
            right[1] * vertical_span * safe_aspect,
            right[2] * vertical_span * safe_aspect,
            0,
        },
        .camera_vertical_span = .{
            up[0] * vertical_span,
            up[1] * vertical_span,
            up[2] * vertical_span,
            0,
        },
        .camera_position_and_cloud_time = .{
            camera.position[0],
            camera.position[1],
            camera.position[2],
            safe_cloud_time,
        },
        .sun_direction_and_radius = .{
            celestial.sun_direction[0],
            celestial.sun_direction[1],
            celestial.sun_direction[2],
            scene.sun_angular_radius,
        },
        .moon_direction_and_radius = .{
            celestial.moon_direction[0],
            celestial.moon_direction[1],
            celestial.moon_direction[2],
            scene.moon_angular_radius,
        },
        .cycle_blend_and_phase = .{
            celestial.daylight,
            celestial.night,
            celestial.twilight,
            celestial.phase,
        },
    };
}

fn expectFinite(values: anytype) !void {
    for (values) |value| try std.testing.expect(std.math.isFinite(value));
}

test "sky uniform ABI remains shader compatible" {
    try std.testing.expectEqual(@as(usize, 112), @sizeOf(Uniforms));
    try std.testing.expectEqual(@as(usize, 4), @alignOf(Uniforms));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(Uniforms, "camera_forward_and_time"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(Uniforms, "camera_horizontal_span"));
    try std.testing.expectEqual(@as(usize, 32), @offsetOf(Uniforms, "camera_vertical_span"));
    try std.testing.expectEqual(@as(usize, 48), @offsetOf(Uniforms, "camera_position_and_cloud_time"));
    try std.testing.expectEqual(@as(usize, 64), @offsetOf(Uniforms, "sun_direction_and_radius"));
    try std.testing.expectEqual(@as(usize, 80), @offsetOf(Uniforms, "moon_direction_and_radius"));
    try std.testing.expectEqual(@as(usize, 96), @offsetOf(Uniforms, "cycle_blend_and_phase"));
}

test "default sky uniforms are finite" {
    const camera = scene.Camera{};
    const uniforms = makeUniforms(camera, 12.5, 37.25);
    try expectFinite(uniforms.camera_forward_and_time);
    try expectFinite(uniforms.camera_horizontal_span);
    try expectFinite(uniforms.camera_vertical_span);
    try expectFinite(uniforms.camera_position_and_cloud_time);
    try expectFinite(uniforms.sun_direction_and_radius);
    try expectFinite(uniforms.moon_direction_and_radius);
    try expectFinite(uniforms.cycle_blend_and_phase);
    try std.testing.expectEqual(@as(f32, 12.5), uniforms.camera_forward_and_time[3]);
    try std.testing.expectEqual(@as(f32, 37.25), uniforms.camera_position_and_cloud_time[3]);
    try std.testing.expectEqualSlices(
        f32,
        camera.position[0..],
        uniforms.camera_position_and_cloud_time[0..3],
    );
}

test "sky uniforms sanitize celestial and cloud time independently" {
    const uniforms = makeUniforms(.{}, std.math.inf(f32), std.math.nan(f32));
    try expectFinite(uniforms.camera_forward_and_time);
    try expectFinite(uniforms.camera_position_and_cloud_time);
    try expectFinite(uniforms.cycle_blend_and_phase);
    try std.testing.expectEqual(@as(f32, 0), uniforms.camera_forward_and_time[3]);
    try std.testing.expectEqual(@as(f32, 0), uniforms.camera_position_and_cloud_time[3]);
}

test "cloud motion time stays independent from the celestial phase" {
    const early_clouds = makeUniforms(.{}, 12.5, 4.0);
    const later_clouds = makeUniforms(.{}, 12.5, 91.0);
    try std.testing.expectEqualSlices(
        f32,
        early_clouds.cycle_blend_and_phase[0..],
        later_clouds.cycle_blend_and_phase[0..],
    );
    try std.testing.expectEqual(@as(f32, 4.0), early_clouds.camera_position_and_cloud_time[3]);
    try std.testing.expectEqual(@as(f32, 91.0), later_clouds.camera_position_and_cloud_time[3]);
}

test "default camera faces the midnight moon" {
    const camera = scene.Camera{};
    const moon_direction = scene.celestialState(0.0).moon_direction;
    try std.testing.expect(scene.dot(camera.forward(), moon_direction) > 0.5);
    try std.testing.expect(moon_direction[1] > 0);
}

test "sky uniforms carry the key cycle blends and opposing bodies" {
    const cycle = scene.day_cycle_seconds;
    const key_times = [_]f32{ 0.0, cycle * 0.25, cycle * 0.5, cycle * 0.75, cycle };
    for (key_times) |time_seconds| {
        const uniforms = makeUniforms(.{}, time_seconds, 0.0);
        try std.testing.expectApproxEqAbs(
            @as(f32, -1.0),
            scene.dot(
                uniforms.sun_direction_and_radius[0..3].*,
                uniforms.moon_direction_and_radius[0..3].*,
            ),
            0.0001,
        );
        try std.testing.expectApproxEqAbs(
            @as(f32, 1.0),
            uniforms.cycle_blend_and_phase[0] +
                uniforms.cycle_blend_and_phase[1] +
                uniforms.cycle_blend_and_phase[2],
            0.0001,
        );
    }
}
