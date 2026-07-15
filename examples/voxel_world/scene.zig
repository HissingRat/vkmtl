const std = @import("std");
const voxel = @import("voxel.zig");

pub const Vec3 = [3]f32;
pub const Mat4 = [4][4]f32;

pub const WorkloadProfile = enum {
    smoke,
    default,
    stress,

    pub fn radius(self: WorkloadProfile) i32 {
        return switch (self) {
            .smoke => 1,
            .default => 4,
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
    try std.testing.expectEqual(@as(usize, 9), WorkloadProfile.smoke.maximumResidentChunks());
    try std.testing.expectEqual(@as(usize, 81), WorkloadProfile.default.maximumResidentChunks());
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
