const std = @import("std");

pub const chunk_width: i32 = 16;
pub const chunk_height: i32 = 64;
pub const chunk_depth: i32 = 16;

pub const BlockId = enum(u8) {
    air,
    grass,
    dirt,
    stone,
};

pub const Vertex = extern struct {
    position: [3]f32,
    uv: [2]f32,
    normal: [3]f32,
};

comptime {
    if (@sizeOf(Vertex) != 32) @compileError("voxel vertices must remain 32 bytes");
}

pub const ChunkCoord = struct {
    x: i32,
    z: i32,
};

pub const Mesh = struct {
    vertices: []Vertex,
    indices: []u32,

    pub fn deinit(self: *Mesh, allocator: std.mem.Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.indices);
        self.* = .{
            .vertices = &.{},
            .indices = &.{},
        };
    }
};

/// A deterministic, allocation-free sampler for the reference voxel world.
/// The seed changes the broad terrain profile without changing mesh ordering.
pub const TerrainSampler = struct {
    seed: u32 = 0x564f_584c,

    pub fn blockAt(self: TerrainSampler, x: i32, y: i32, z: i32) BlockId {
        if (y < 0) return .stone;

        const height = terrainHeight(self.seed, x, z);
        if (y > height) return .air;
        if (y == height) return .grass;
        if (y >= height - 3) return .dirt;
        return .stone;
    }
};

/// Meshes one 16x64x16 chunk. `sampler.blockAt(x, y, z)` is deliberately
/// queried in world coordinates, including coordinates outside this chunk, so
/// faces shared with resident neighbor chunks are not emitted.
pub fn meshChunk(
    allocator: std.mem.Allocator,
    coord: ChunkCoord,
    sampler: anytype,
) !Mesh {
    var vertices: std.ArrayList(Vertex) = .empty;
    defer vertices.deinit(allocator);

    var indices: std.ArrayList(u32) = .empty;
    defer indices.deinit(allocator);

    const base_x = coord.x * chunk_width;
    const base_z = coord.z * chunk_depth;

    var local_y: i32 = 0;
    while (local_y < chunk_height) : (local_y += 1) {
        var local_z: i32 = 0;
        while (local_z < chunk_depth) : (local_z += 1) {
            var local_x: i32 = 0;
            while (local_x < chunk_width) : (local_x += 1) {
                const world_x = base_x + local_x;
                const world_z = base_z + local_z;
                const block = sampler.blockAt(world_x, local_y, world_z);
                if (block == .air) continue;

                for (faces) |face| {
                    if (sampler.blockAt(
                        world_x + face.direction[0],
                        local_y + face.direction[1],
                        world_z + face.direction[2],
                    ) != .air) continue;

                    try appendFace(
                        allocator,
                        &vertices,
                        &indices,
                        world_x,
                        local_y,
                        world_z,
                        block,
                        face,
                    );
                }
            }
        }
    }

    const owned_vertices = try vertices.toOwnedSlice(allocator);
    errdefer allocator.free(owned_vertices);
    const owned_indices = try indices.toOwnedSlice(allocator);

    return .{
        .vertices = owned_vertices,
        .indices = owned_indices,
    };
}

pub fn meshTerrainChunk(allocator: std.mem.Allocator, coord: ChunkCoord, seed: u32) !Mesh {
    return meshChunk(allocator, coord, TerrainSampler{ .seed = seed });
}

fn terrainHeight(seed: u32, x: i32, z: i32) i32 {
    const broad_x = triangleWave(x +% @as(i32, @bitCast(seed)), 32);
    const broad_z = triangleWave(z +% @as(i32, @bitCast(std.math.rotl(u32, seed, 11))), 24);
    const detail = @as(i32, @intCast(hash2(seed, @divFloor(x, 4), @divFloor(z, 4)) % 4));
    return 12 + @divFloor(broad_x, 2) + @divFloor(broad_z, 3) + detail;
}

fn triangleWave(value: i32, period: i32) i32 {
    const phase = @mod(value, period);
    return if (phase <= @divFloor(period, 2)) phase else period - phase;
}

fn hash2(seed: u32, x: i32, z: i32) u32 {
    var value = seed ^ @as(u32, @bitCast(x)) *% 0x9e37_79b9;
    value ^= @as(u32, @bitCast(z)) *% 0x85eb_ca6b;
    value ^= value >> 16;
    value *%= 0x7feb_352d;
    value ^= value >> 15;
    value *%= 0x846c_a68b;
    value ^= value >> 16;
    return value;
}

const Face = struct {
    direction: [3]i32,
    normal: [3]f32,
    corners: [4][3]f32,
};

const faces = [_]Face{
    .{
        .direction = .{ 1, 0, 0 },
        .normal = .{ 1, 0, 0 },
        .corners = .{ .{ 1, 0, 1 }, .{ 1, 0, 0 }, .{ 1, 1, 0 }, .{ 1, 1, 1 } },
    },
    .{
        .direction = .{ -1, 0, 0 },
        .normal = .{ -1, 0, 0 },
        .corners = .{ .{ 0, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 0 } },
    },
    .{
        .direction = .{ 0, 1, 0 },
        .normal = .{ 0, 1, 0 },
        .corners = .{ .{ 0, 1, 1 }, .{ 1, 1, 1 }, .{ 1, 1, 0 }, .{ 0, 1, 0 } },
    },
    .{
        .direction = .{ 0, -1, 0 },
        .normal = .{ 0, -1, 0 },
        .corners = .{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 1, 0, 1 }, .{ 0, 0, 1 } },
    },
    .{
        .direction = .{ 0, 0, 1 },
        .normal = .{ 0, 0, 1 },
        .corners = .{ .{ 0, 0, 1 }, .{ 1, 0, 1 }, .{ 1, 1, 1 }, .{ 0, 1, 1 } },
    },
    .{
        .direction = .{ 0, 0, -1 },
        .normal = .{ 0, 0, -1 },
        .corners = .{ .{ 1, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 1, 0 }, .{ 1, 1, 0 } },
    },
};

const face_uvs = [_][2]f32{
    .{ 0, 1 },
    .{ 1, 1 },
    .{ 1, 0 },
    .{ 0, 0 },
};

fn appendFace(
    allocator: std.mem.Allocator,
    vertices: *std.ArrayList(Vertex),
    indices: *std.ArrayList(u32),
    world_x: i32,
    world_y: i32,
    world_z: i32,
    block: BlockId,
    face: Face,
) !void {
    const first_vertex: u32 = @intCast(vertices.items.len);
    const tile = @as(f32, @floatFromInt(@intFromEnum(block) - 1));
    const atlas_width: f32 = 48.0;
    const atlas_height: f32 = 16.0;
    const tile_pixels: f32 = 16.0;
    const u_min = (tile * tile_pixels + 0.5) / atlas_width;
    const u_max = ((tile + 1.0) * tile_pixels - 0.5) / atlas_width;
    const v_min = 0.5 / atlas_height;
    const v_max = (atlas_height - 0.5) / atlas_height;

    for (face.corners, face_uvs) |corner, uv| {
        try vertices.append(allocator, .{
            .position = .{
                @as(f32, @floatFromInt(world_x)) + corner[0],
                @as(f32, @floatFromInt(world_y)) + corner[1],
                @as(f32, @floatFromInt(world_z)) + corner[2],
            },
            .uv = .{
                if (uv[0] == 0) u_min else u_max,
                if (uv[1] == 0) v_min else v_max,
            },
            .normal = face.normal,
        });
    }

    try indices.appendSlice(allocator, &.{
        first_vertex,
        first_vertex + 1,
        first_vertex + 2,
        first_vertex,
        first_vertex + 2,
        first_vertex + 3,
    });
}

const EmptySampler = struct {
    pub fn blockAt(_: EmptySampler, _: i32, _: i32, _: i32) BlockId {
        return .air;
    }
};

const SingleBlockSampler = struct {
    pub fn blockAt(_: SingleBlockSampler, x: i32, y: i32, z: i32) BlockId {
        return if (x == 1 and y == 2 and z == 3) .grass else .air;
    }
};

const AdjacentBlockSampler = struct {
    pub fn blockAt(_: AdjacentBlockSampler, x: i32, y: i32, z: i32) BlockId {
        if (y != 2 or z != 3) return .air;
        return if (x == 1 or x == 2) .stone else .air;
    }
};

const FiniteSolidChunkSampler = struct {
    pub fn blockAt(_: FiniteSolidChunkSampler, x: i32, y: i32, z: i32) BlockId {
        if (x < 0 or x >= chunk_width) return .air;
        if (y < 0 or y >= chunk_height) return .air;
        if (z < 0 or z >= chunk_depth) return .air;
        return .stone;
    }
};

const BoundaryPairSampler = struct {
    pub fn blockAt(_: BoundaryPairSampler, x: i32, y: i32, z: i32) BlockId {
        if (y != 1 or z != 0) return .air;
        return if (x == chunk_width - 1 or x == chunk_width) .dirt else .air;
    }
};

test "voxel ABI and empty chunk" {
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(Vertex));

    var mesh = try meshChunk(std.testing.allocator, .{ .x = 0, .z = 0 }, EmptySampler{});
    defer mesh.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 0), mesh.indices.len);
}

test "single block emits six indexed faces" {
    var mesh = try meshChunk(std.testing.allocator, .{ .x = 0, .z = 0 }, SingleBlockSampler{});
    defer mesh.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 24), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 36), mesh.indices.len);
}

test "adjacent blocks omit their shared face" {
    var mesh = try meshChunk(std.testing.allocator, .{ .x = 0, .z = 0 }, AdjacentBlockSampler{});
    defer mesh.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 40), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 60), mesh.indices.len);
}

test "finite solid chunk emits only its shell" {
    var mesh = try meshChunk(std.testing.allocator, .{ .x = 0, .z = 0 }, FiniteSolidChunkSampler{});
    defer mesh.deinit(std.testing.allocator);

    const face_count = 2 * (chunk_width * chunk_height + chunk_width * chunk_depth + chunk_height * chunk_depth);
    try std.testing.expectEqual(@as(usize, @intCast(face_count * 4)), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, @intCast(face_count * 6)), mesh.indices.len);
}

test "terrain meshing is deterministic and nonempty" {
    var first = try meshTerrainChunk(std.testing.allocator, .{ .x = -2, .z = 3 }, 42);
    defer first.deinit(std.testing.allocator);
    var second = try meshTerrainChunk(std.testing.allocator, .{ .x = -2, .z = 3 }, 42);
    defer second.deinit(std.testing.allocator);

    try std.testing.expect(first.vertices.len > 0);
    try std.testing.expect(first.indices.len > 0);
    try std.testing.expectEqualSlices(Vertex, first.vertices, second.vertices);
    try std.testing.expectEqualSlices(u32, first.indices, second.indices);
}

test "world sampler culls faces across chunk boundaries" {
    var left = try meshChunk(std.testing.allocator, .{ .x = 0, .z = 0 }, BoundaryPairSampler{});
    defer left.deinit(std.testing.allocator);
    var right = try meshChunk(std.testing.allocator, .{ .x = 1, .z = 0 }, BoundaryPairSampler{});
    defer right.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 20), left.vertices.len);
    try std.testing.expectEqual(@as(usize, 30), left.indices.len);
    try std.testing.expectEqual(@as(usize, 20), right.vertices.len);
    try std.testing.expectEqual(@as(usize, 30), right.indices.len);
}
