const std = @import("std");
const voxel = @import("voxel.zig");
const settings = @import("settings.zig");

pub const Vec3 = [3]f32;
pub const Mat4 = [4][4]f32;

pub const day_cycle_seconds: f32 = 300.0;
pub const water_cycle_seconds: f64 = 64.0;
pub const sun_angular_radius: f32 = 0.045;
pub const moon_angular_radius: f32 = 0.055;

pub const CelestialState = struct {
    /// Normalized cycle position: midnight=0, sunrise=0.25, noon=0.5,
    /// sunset=0.75.
    phase: f32,
    sun_direction: Vec3,
    moon_direction: Vec3,
    daylight: f32,
    night: f32,
    twilight: f32,
    light_direction: Vec3,
    light_angular_radius: f32,
    light_color: Vec3,
    ambient: f32,
    strength: f32,
};

/// Returns the world-space celestial and lighting state for the example's
/// five-minute day/night cycle. Directions point from the world toward the
/// light source, matching the raster and hybrid RT lighting convention.
pub fn celestialState(time_seconds: f32) CelestialState {
    const safe_time = if (std.math.isFinite(time_seconds)) time_seconds else 0.0;
    const phase = safe_time / day_cycle_seconds - @floor(safe_time / day_cycle_seconds);
    const angle = phase * std.math.tau;

    // The orbit's midnight apex remains in front of the default camera while
    // retaining enough altitude for a clearly visible moonlit scene.
    const midnight_moon = normalize(Vec3{ 0.26, 0.50, -0.826559 });
    const horizon_axis = normalize(Vec3{ -midnight_moon[2], 0.0, midnight_moon[0] });
    const sun_direction = normalize(add(
        scale(midnight_moon, -@cos(angle)),
        scale(horizon_axis, @sin(angle)),
    ));
    const moon_direction = scale(sun_direction, -1.0);

    const sun_elevation = sun_direction[1];
    const daylight = smoothStep(-0.06, 0.10, sun_elevation);
    const night = 1.0 - smoothStep(-0.18, -0.04, sun_elevation);
    const twilight = @max(0.0, 1.0 - daylight - night);

    const twilight_color = Vec3{ 1.0, 0.48, 0.24 };
    const sun_color = Vec3{ 1.0, 0.94, 0.82 };
    const moon_color = Vec3{ 0.48, 0.62, 1.0 };
    const light_color = add(
        scale(moon_color, night),
        add(scale(twilight_color, twilight), scale(sun_color, daylight)),
    );
    const sun_direct = smoothStep(0.0, 0.18, sun_elevation);
    const moon_direct = smoothStep(0.0, 0.18, -sun_elevation);

    // The direction change happens while directional strength is lowest. The
    // two physical body directions themselves remain continuous and should be
    // preferred by effects that can represent two directional lights.
    const light_direction = if (sun_elevation >= 0.0) sun_direction else moon_direction;
    const light_angular_radius = if (sun_elevation >= 0.0) sun_angular_radius else moon_angular_radius;
    return .{
        .phase = phase,
        .sun_direction = sun_direction,
        .moon_direction = moon_direction,
        .daylight = daylight,
        .night = night,
        .twilight = twilight,
        .light_direction = light_direction,
        .light_angular_radius = light_angular_radius,
        .light_color = light_color,
        .ambient = night * 0.22 + twilight * 0.30 + daylight * 0.44,
        .strength = moon_direct * 0.72 + sun_direct * 1.20,
    };
}

/// A frame-rate-independent phase for world-space water shading. It is kept
/// separate from the validation override that can freeze the celestial clock.
pub fn waterPhase(elapsed_seconds: f64) f32 {
    const safe_elapsed = if (std.math.isFinite(elapsed_seconds))
        @max(elapsed_seconds, 0.0)
    else
        0.0;
    const wrapped = safe_elapsed -
        @floor(safe_elapsed / water_cycle_seconds) * water_cycle_seconds;
    return @floatCast(wrapped / water_cycle_seconds);
}

pub const WorkloadProfile = enum {
    smoke,
    default,
    stress,

    pub fn radius(self: WorkloadProfile) i32 {
        return switch (self) {
            .smoke => 1,
            .default => 6,
            .stress => 8,
        };
    }

    pub fn maximumResidentChunks(self: WorkloadProfile) usize {
        const diameter: usize = @intCast(self.radius() * 2 + 1);
        return diameter * diameter;
    }
};

pub const Camera = struct {
    position: Vec3 = .{ 8, 26, 40 },
    yaw: f32 = 0,
    pitch: f32 = -0.20,

    pub fn forward(self: Camera) Vec3 {
        const cos_pitch = @cos(self.pitch);
        return normalize(.{
            @sin(self.yaw) * cos_pitch,
            @sin(self.pitch),
            -@cos(self.yaw) * cos_pitch,
        });
    }

    pub fn right(self: Camera) Vec3 {
        return normalize(cross(self.forward(), .{ 0, 1, 0 }));
    }

    pub fn up(self: Camera) Vec3 {
        return normalize(cross(self.right(), self.forward()));
    }

    pub fn move(self: *Camera, forward_distance: f32, right_distance: f32, vertical_distance: f32) void {
        const horizontal_forward = normalizeOrZero(.{ @sin(self.yaw), 0, -@cos(self.yaw) });
        const horizontal_right = normalizeOrZero(cross(horizontal_forward, .{ 0, 1, 0 }));
        self.position = add(
            self.position,
            add(
                scale(horizontal_forward, forward_distance),
                add(scale(horizontal_right, right_distance), .{ 0, vertical_distance, 0 }),
            ),
        );
    }

    pub fn viewProjection(self: Camera, aspect: f32) Mat4 {
        const projection = perspectiveRhZo(std.math.degreesToRadians(62.0), aspect, 0.1, 640.0);
        const view = lookAtRh(self.position, add(self.position, self.forward()), .{ 0, 1, 0 });
        return matMul(projection, view);
    }

    pub fn chunkCoord(self: Camera) voxel.ChunkCoord {
        return .{
            .x = @intFromFloat(@floor(self.position[0] / @as(f32, @floatFromInt(voxel.chunk_width)))),
            .z = @intFromFloat(@floor(self.position[2] / @as(f32, @floatFromInt(voxel.chunk_depth)))),
        };
    }

    /// Conservative chunk-sphere frustum test. False positives are acceptable;
    /// visible chunks must not be dropped by the CPU pressure-test culler.
    pub fn chunkVisible(self: Camera, aspect: f32, coord: voxel.ChunkCoord) bool {
        const center = Vec3{
            @as(f32, @floatFromInt(coord.x * voxel.chunk_width)) + @as(f32, @floatFromInt(voxel.chunk_width)) * 0.5,
            @as(f32, @floatFromInt(voxel.chunk_height)) * 0.5,
            @as(f32, @floatFromInt(coord.z * voxel.chunk_depth)) + @as(f32, @floatFromInt(voxel.chunk_depth)) * 0.5,
        };
        const half = Vec3{
            @as(f32, @floatFromInt(voxel.chunk_width)) * 0.5,
            @as(f32, @floatFromInt(voxel.chunk_height)) * 0.5,
            @as(f32, @floatFromInt(voxel.chunk_depth)) * 0.5,
        };
        const radius = length(half);
        const to_center = sub(center, self.position);
        const forward_axis = self.forward();
        const right_axis = self.right();
        const up_axis = self.up();
        const depth = dot(to_center, forward_axis);
        if (depth < -radius or depth > 640.0 + radius) return false;

        const projected_depth = @max(depth, 0.0);
        const half_vertical = projected_depth * @tan(std.math.degreesToRadians(62.0) * 0.5);
        const half_horizontal = half_vertical * aspect;
        return @abs(dot(to_center, right_axis)) <= half_horizontal + radius and
            @abs(dot(to_center, up_axis)) <= half_vertical + radius;
    }
};

pub fn add(a: Vec3, b: Vec3) Vec3 {
    return .{ a[0] + b[0], a[1] + b[1], a[2] + b[2] };
}

pub fn sub(a: Vec3, b: Vec3) Vec3 {
    return .{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
}

pub fn scale(value: Vec3, amount: f32) Vec3 {
    return .{ value[0] * amount, value[1] * amount, value[2] * amount };
}

pub fn dot(a: Vec3, b: Vec3) f32 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

pub fn cross(a: Vec3, b: Vec3) Vec3 {
    return .{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

pub fn length(value: Vec3) f32 {
    return @sqrt(dot(value, value));
}

pub fn normalize(value: Vec3) Vec3 {
    const magnitude = length(value);
    std.debug.assert(magnitude > 0);
    return scale(value, 1.0 / magnitude);
}

fn normalizeOrZero(value: Vec3) Vec3 {
    const magnitude = length(value);
    return if (magnitude > 0.00001) scale(value, 1.0 / magnitude) else .{ 0, 0, 0 };
}

fn smoothStep(edge0: f32, edge1: f32, value: f32) f32 {
    const amount = std.math.clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0);
    return amount * amount * (3.0 - 2.0 * amount);
}

fn lookAtRh(eye: Vec3, center: Vec3, world_up: Vec3) Mat4 {
    const forward_axis = normalize(sub(center, eye));
    const right_axis = normalize(cross(forward_axis, world_up));
    const up_axis = cross(right_axis, forward_axis);
    return .{
        .{ right_axis[0], right_axis[1], right_axis[2], -dot(right_axis, eye) },
        .{ up_axis[0], up_axis[1], up_axis[2], -dot(up_axis, eye) },
        .{ -forward_axis[0], -forward_axis[1], -forward_axis[2], dot(forward_axis, eye) },
        .{ 0, 0, 0, 1 },
    };
}

fn perspectiveRhZo(fovy_radians: f32, aspect: f32, near: f32, far: f32) Mat4 {
    const f = 1.0 / @tan(fovy_radians * 0.5);
    return .{
        .{ f / aspect, 0, 0, 0 },
        .{ 0, f, 0, 0 },
        .{ 0, 0, far / (near - far), (far * near) / (near - far) },
        .{ 0, 0, -1, 0 },
    };
}

fn matMul(a: Mat4, b: Mat4) Mat4 {
    var result: Mat4 = undefined;
    for (0..4) |row| {
        for (0..4) |column| {
            var sum: f32 = 0;
            for (0..4) |index| sum += a[row][index] * b[index][column];
            result[row][column] = sum;
        }
    }
    return result;
}

test "workload profiles remain bounded" {
    _ = settings;
    try std.testing.expectEqual(@as(usize, 9), WorkloadProfile.smoke.maximumResidentChunks());
    try std.testing.expectEqual(@as(usize, 169), WorkloadProfile.default.maximumResidentChunks());
    try std.testing.expectEqual(@as(usize, 289), WorkloadProfile.stress.maximumResidentChunks());
}

test "negative positions use floor chunk coordinates" {
    const camera = Camera{ .position = .{ -0.1, 10, -16.1 } };
    try std.testing.expectEqual(voxel.ChunkCoord{ .x = -1, .z = -2 }, camera.chunkCoord());
}

test "camera culling keeps front chunks and rejects chunks behind" {
    const camera = Camera{};
    try std.testing.expect(camera.chunkVisible(16.0 / 9.0, .{ .x = 0, .z = 0 }));
    try std.testing.expect(!camera.chunkVisible(16.0 / 9.0, .{ .x = 0, .z = 8 }));
}

test "camera movement is horizontal plus explicit vertical motion" {
    var camera = Camera{ .position = .{ 0, 0, 0 }, .yaw = 0 };
    camera.move(4, 2, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 2), camera.position[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3), camera.position[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, -4), camera.position[2], 0.0001);
}

test "celestial cycle key points remain midnight sunrise noon sunset" {
    const quarter_cycle = day_cycle_seconds * 0.25;
    const half_cycle = day_cycle_seconds * 0.5;
    const three_quarter_cycle = day_cycle_seconds * 0.75;
    const midnight = celestialState(0.0);
    const sunrise = celestialState(quarter_cycle);
    const noon = celestialState(half_cycle);
    const sunset = celestialState(three_quarter_cycle);
    const wrapped_midnight = celestialState(day_cycle_seconds);

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), midnight.phase, 0.0001);
    try std.testing.expect(midnight.night > 0.99);
    try std.testing.expect(midnight.moon_direction[1] > 0.45);
    try std.testing.expect(midnight.sun_direction[1] < -0.45);
    try std.testing.expectEqual(moon_angular_radius, midnight.light_angular_radius);

    try std.testing.expectApproxEqAbs(@as(f32, 0.25), sunrise.phase, 0.0001);
    try std.testing.expect(@abs(sunrise.sun_direction[1]) < 0.0001);
    try std.testing.expect(sunrise.twilight > 0.60);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), sunrise.strength, 0.0001);

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), noon.phase, 0.0001);
    try std.testing.expect(noon.daylight > 0.99);
    try std.testing.expect(noon.sun_direction[1] > 0.45);
    try std.testing.expect(noon.moon_direction[1] < -0.45);
    try std.testing.expectEqual(sun_angular_radius, noon.light_angular_radius);

    try std.testing.expectApproxEqAbs(@as(f32, 0.75), sunset.phase, 0.0001);
    try std.testing.expect(@abs(sunset.sun_direction[1]) < 0.0001);
    try std.testing.expect(sunset.twilight > 0.60);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), sunset.strength, 0.0001);

    try std.testing.expectApproxEqAbs(midnight.phase, wrapped_midnight.phase, 0.0001);
    for (midnight.moon_direction, wrapped_midnight.moon_direction) |expected, actual| {
        try std.testing.expectApproxEqAbs(expected, actual, 0.0001);
    }
}

test "sun and moon stay opposite while their orbit remains continuous" {
    const sunrise_time = day_cycle_seconds * 0.25;
    const key_times = [_]f32{
        0.0,
        sunrise_time,
        day_cycle_seconds * 0.5,
        day_cycle_seconds * 0.75,
        day_cycle_seconds - 0.01,
    };
    for (key_times) |time_seconds| {
        const state = celestialState(time_seconds);
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), dot(state.sun_direction, state.moon_direction), 0.0001);
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), state.daylight + state.night + state.twilight, 0.0001);
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), length(state.sun_direction), 0.0001);
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), length(state.moon_direction), 0.0001);
    }

    const before = celestialState(sunrise_time - 0.01);
    const after = celestialState(sunrise_time + 0.01);
    try std.testing.expect(dot(before.sun_direction, after.sun_direction) > 0.999);
    try std.testing.expect(dot(before.moon_direction, after.moon_direction) > 0.999);
}

test "celestial time wraps for negative and non-finite inputs" {
    const negative = celestialState(-day_cycle_seconds * 0.25);
    const sunset = celestialState(day_cycle_seconds * 0.75);
    try std.testing.expectApproxEqAbs(sunset.phase, negative.phase, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), celestialState(std.math.inf(f32)).phase, 0.0001);
}

test "water phase is frame rate independent and separate from the day cycle" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), waterPhase(0.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), waterPhase(16.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), waterPhase(64.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), waterPhase(80.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), waterPhase(-1.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), waterPhase(std.math.inf(f64)), 0.0001);
}
