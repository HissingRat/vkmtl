const std = @import("std");
const atlas = @import("atlas.zig");

pub const chunk_width: i32 = 16;
pub const chunk_height: i32 = 64;
pub const chunk_depth: i32 = 16;

pub const BlockId = enum(u8) {
    air,
    grass,
    dirt,
    stone,
    sand,
    snow,
    wood,
    leaves,
    water,
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
    opaque_index_count: usize,
    water_index_count: usize,

    pub fn deinit(self: *Mesh, allocator: std.mem.Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.indices);
        self.* = .{
            .vertices = &.{},
            .indices = &.{},
            .opaque_index_count = 0,
            .water_index_count = 0,
        };
    }
};

/// A deterministic, allocation-free sampler for the reference voxel world.
/// The seed changes the broad terrain profile without changing mesh ordering.
pub const TerrainSampler = struct {
    seed: u32 = 0x564f_584c,

    pub fn columnAt(self: TerrainSampler, x: i32, z: i32) TerrainColumn {
        return terrainColumn(self.seed, x, z);
    }

    pub fn blockAt(self: TerrainSampler, x: i32, y: i32, z: i32) BlockId {
        return blockForColumn(self.columnAt(x, z), y);
    }
};

pub const TerrainColumn = struct {
    height: i32,
    surface: BlockId,
    water_level: i32 = -1,
    wood_min: i32 = -1,
    wood_max: i32 = -1,
    leaves_min: i32 = -1,
    leaves_max: i32 = -1,
};

const terrain_cache_width: usize = @intCast(chunk_width + 2);
const terrain_cache_depth: usize = @intCast(chunk_depth + 2);
const terrain_cache_count = terrain_cache_width * terrain_cache_depth;

const CachedTerrainSampler = struct {
    base_x: i32,
    base_z: i32,
    columns: *const [terrain_cache_count]TerrainColumn,

    pub fn blockAt(self: CachedTerrainSampler, x: i32, y: i32, z: i32) BlockId {
        const local_x = x - self.base_x;
        const local_z = z - self.base_z;
        std.debug.assert(local_x >= 0 and local_x < @as(i32, @intCast(terrain_cache_width)));
        std.debug.assert(local_z >= 0 and local_z < @as(i32, @intCast(terrain_cache_depth)));
        const index = @as(usize, @intCast(local_z)) * terrain_cache_width +
            @as(usize, @intCast(local_x));
        return blockForColumn(self.columns[index], y);
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

    var opaque_indices: std.ArrayList(u32) = .empty;
    defer opaque_indices.deinit(allocator);
    var water_indices: std.ArrayList(u32) = .empty;
    defer water_indices.deinit(allocator);

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
                    const neighbor = sampler.blockAt(
                        world_x + face.direction[0],
                        local_y + face.direction[1],
                        world_z + face.direction[2],
                    );
                    if (!faceVisible(block, neighbor)) continue;

                    try appendFace(
                        allocator,
                        &vertices,
                        if (block == .water) &water_indices else &opaque_indices,
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

    const opaque_index_count = opaque_indices.items.len;
    const water_index_count = water_indices.items.len;
    try opaque_indices.appendSlice(allocator, water_indices.items);

    const owned_vertices = try vertices.toOwnedSlice(allocator);
    errdefer allocator.free(owned_vertices);
    const owned_indices = try opaque_indices.toOwnedSlice(allocator);

    return .{
        .vertices = owned_vertices,
        .indices = owned_indices,
        .opaque_index_count = opaque_index_count,
        .water_index_count = water_index_count,
    };
}

/// Opaque terrain bordering water keeps its interface face so the lake bottom
/// and banks remain visible through the transparent water pass. Water emits
/// only its air boundary, preventing duplicate coplanar solid/water faces and
/// retaining water-water culling across chunk boundaries.
fn faceVisible(block: BlockId, neighbor: BlockId) bool {
    return if (block == .water)
        neighbor == .air
    else
        neighbor == .air or neighbor == .water;
}

pub fn meshTerrainChunk(allocator: std.mem.Allocator, coord: ChunkCoord, seed: u32) !Mesh {
    const base_x = coord.x * chunk_width - 1;
    const base_z = coord.z * chunk_depth - 1;
    var columns = terrainColumnCache(coord, seed);

    return meshChunk(allocator, coord, CachedTerrainSampler{
        .base_x = base_x,
        .base_z = base_z,
        .columns = &columns,
    });
}

fn terrainColumnCache(coord: ChunkCoord, seed: u32) [terrain_cache_count]TerrainColumn {
    const base_x = coord.x * chunk_width - 1;
    const base_z = coord.z * chunk_depth - 1;
    var columns: [terrain_cache_count]TerrainColumn = undefined;
    for (0..terrain_cache_depth) |local_z| {
        for (0..terrain_cache_width) |local_x| {
            columns[local_z * terrain_cache_width + local_x] = terrainColumn(
                seed,
                base_x + @as(i32, @intCast(local_x)),
                base_z + @as(i32, @intCast(local_z)),
            );
        }
    }
    return columns;
}

fn blockForColumn(column: TerrainColumn, y: i32) BlockId {
    if (y < 0) return .stone;
    if (y <= column.height) {
        if (y == column.height) return column.surface;
        if (column.surface == .sand and y >= column.height - 3) return .sand;
        if (y >= column.height - 3) return .dirt;
        return .stone;
    }
    if (withinSpan(y, column.wood_min, column.wood_max)) return .wood;
    if (withinSpan(y, column.leaves_min, column.leaves_max)) return .leaves;
    if (column.water_level >= 0 and y <= column.water_level) return .water;
    return .air;
}

const noise_one: i32 = 4096;
pub const lake_water_level: i32 = 12;
pub const tree_canopy_radius: i32 = 2;
const tree_cell_size: i32 = 8;

const TreeAnchor = struct {
    ground_height: i32,
    trunk_height: i32,
};

fn terrainColumn(seed: u32, x: i32, z: i32) TerrainColumn {
    var column = baseTerrainColumn(seed, x, z);
    column.water_level = waterLevelForColumn(seed, x, z, column);

    var anchor_z = z - tree_canopy_radius;
    while (anchor_z <= z + tree_canopy_radius) : (anchor_z += 1) {
        var anchor_x = x - tree_canopy_radius;
        while (anchor_x <= x + tree_canopy_radius) : (anchor_x += 1) {
            const anchor = treeAnchor(seed, anchor_x, anchor_z) orelse continue;
            const dx = x - anchor_x;
            const dz = z - anchor_z;
            const tree_top = anchor.ground_height + anchor.trunk_height;
            if (dx == 0 and dz == 0) {
                column.wood_min = anchor.ground_height + 1;
                column.wood_max = tree_top;
            }
            var leaf_y = tree_top - 2;
            while (leaf_y <= tree_top + 1) : (leaf_y += 1) {
                if (!treeHasLeafAt(dx, leaf_y - tree_top, dz)) continue;
                if (column.leaves_min < 0) column.leaves_min = leaf_y;
                column.leaves_max = leaf_y;
            }
        }
    }
    return column;
}

fn baseTerrainColumn(seed: u32, x: i32, z: i32) TerrainColumn {
    const continentalness = valueNoise2(seed ^ 0x2a65_39b7, x, z, 128);
    const erosion = valueNoise2(seed ^ 0x91e1_0da5, x, z, 48);
    const ridge_source = valueNoise2(seed ^ 0x4cf5_ad43, x, z, 32);
    const detail = valueNoise2(seed ^ 0xd1b5_4a35, x, z, 12);
    const temperature = valueNoise2(seed ^ 0x7f4a_7c15, x, z, 128);
    const moisture = valueNoise2(seed ^ 0x1656_67b1, x, z, 96);

    const land_gate = @divFloor(continentalness + noise_one, 2);
    const erosion_gate = @divFloor(noise_one * 3, 10) +
        @divFloor((noise_one - erosion) * 7, 20);
    const ridge = noise_one - @as(i32, @intCast(@abs(ridge_source)));
    const sharp_ridge = scaleNoise(ridge, ridge);
    const ridge_relief = scaleNoise(scaleNoise(sharp_ridge, land_gate), erosion_gate);

    const continental_height = @divFloor(continentalness * 7, noise_one);
    const ridge_height = @divFloor(ridge_relief * 18, noise_one);
    const detail_height = @divFloor(detail * 2, noise_one);
    const height = std.math.clamp(19 + continental_height + ridge_height + detail_height, 6, 48);

    const surface: BlockId = if (height <= 11)
        .sand
    else if (height >= 31 or (temperature < -@divFloor(noise_one, 3) and height >= 21))
        .snow
    else if (temperature > @divFloor(noise_one, 5) and
        moisture < -@divFloor(noise_one, 5) and
        height <= 25)
        .sand
    else
        .grass;
    return .{ .height = height, .surface = surface };
}

fn waterLevelForColumn(seed: u32, x: i32, z: i32, column: TerrainColumn) i32 {
    if (column.surface != .sand or column.height >= lake_water_level) return -1;
    const lake_mask = valueNoise2(seed ^ 0xc32d_71e5, x, z, 96);
    return if (lake_mask > -@divFloor(noise_one, 5)) lake_water_level else -1;
}

fn treeAnchor(seed: u32, x: i32, z: i32) ?TreeAnchor {
    const cell_x = @divFloor(x, tree_cell_size);
    const cell_z = @divFloor(z, tree_cell_size);
    const placement = hash2(seed ^ 0x6a09_e667, cell_x, cell_z);
    const candidate_x = cell_x * tree_cell_size + 2 + @as(i32, @intCast(placement & 3));
    const candidate_z = cell_z * tree_cell_size + 2 + @as(i32, @intCast((placement >> 2) & 3));
    if (x != candidate_x or z != candidate_z) return null;
    if ((placement >> 8) % 100 >= 55) return null;

    const center = baseTerrainColumn(seed, x, z);
    if (center.surface != .grass or center.height + 7 >= chunk_height) return null;
    if (waterLevelForColumn(seed, x, z, center) >= 0) return null;

    var footprint_z = z - tree_canopy_radius;
    while (footprint_z <= z + tree_canopy_radius) : (footprint_z += 1) {
        var footprint_x = x - tree_canopy_radius;
        while (footprint_x <= x + tree_canopy_radius) : (footprint_x += 1) {
            const footprint = baseTerrainColumn(seed, footprint_x, footprint_z);
            if (footprint.surface != .grass or @abs(footprint.height - center.height) > 1) return null;
            if (waterLevelForColumn(seed, footprint_x, footprint_z, footprint) >= 0) return null;
        }
    }

    return .{
        .ground_height = center.height,
        .trunk_height = 4 + @as(i32, @intCast((placement >> 16) & 1)),
    };
}

fn treeHasLeafAt(dx: i32, level_from_top: i32, dz: i32) bool {
    const absolute_x = @abs(dx);
    const absolute_z = @abs(dz);
    return switch (level_from_top) {
        -2, -1, 0 => absolute_x <= 2 and absolute_z <= 2 and absolute_x + absolute_z <= 3,
        1 => absolute_x <= 1 and absolute_z <= 1 and absolute_x + absolute_z <= 1,
        else => false,
    };
}

fn withinSpan(y: i32, minimum: i32, maximum: i32) bool {
    return minimum >= 0 and y >= minimum and y <= maximum;
}

fn scaleNoise(a: i32, b: i32) i32 {
    return @intCast(@divFloor(@as(i64, a) * @as(i64, b), noise_one));
}

/// Smooth fixed-point value noise in [-noise_one, noise_one). All lattice and
/// interpolation math is integer so terrain snapshots stay platform-stable.
fn valueNoise2(seed: u32, x: i32, z: i32, scale: i32) i32 {
    const cell_x = @divFloor(x, scale);
    const cell_z = @divFloor(z, scale);
    const local_x = @mod(x, scale);
    const local_z = @mod(z, scale);
    const tx = smoothNoiseCoordinate(local_x, scale);
    const tz = smoothNoiseCoordinate(local_z, scale);

    const north = lerpNoise(
        latticeNoise(seed, cell_x, cell_z),
        latticeNoise(seed, cell_x + 1, cell_z),
        tx,
    );
    const south = lerpNoise(
        latticeNoise(seed, cell_x, cell_z + 1),
        latticeNoise(seed, cell_x + 1, cell_z + 1),
        tx,
    );
    return lerpNoise(north, south, tz);
}

fn latticeNoise(seed: u32, x: i32, z: i32) i32 {
    return @as(i32, @intCast(hash2(seed, x, z) & 0x1fff)) - noise_one;
}

fn smoothNoiseCoordinate(value: i32, scale: i32) i32 {
    const t = @divFloor(@as(i64, value) * noise_one, scale);
    const t_squared = t * t;
    return @intCast(@divFloor(t_squared * (3 * noise_one - 2 * t), @as(i64, noise_one) * noise_one));
}

fn lerpNoise(a: i32, b: i32, t: i32) i32 {
    return a + @as(i32, @intCast(@divFloor(
        @as(i64, b - a) * t,
        noise_one,
    )));
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
    const uv_bounds = atlas.uvBounds(materialForFace(block, face.direction));

    for (face.corners, face_uvs) |corner, uv| {
        try vertices.append(allocator, .{
            .position = .{
                @as(f32, @floatFromInt(world_x)) + corner[0],
                @as(f32, @floatFromInt(world_y)) + corner[1],
                @as(f32, @floatFromInt(world_z)) + corner[2],
            },
            .uv = .{
                if (uv[0] == 0) uv_bounds.u_min else uv_bounds.u_max,
                if (uv[1] == 0) uv_bounds.v_min else uv_bounds.v_max,
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

pub fn materialForFace(block: BlockId, direction: [3]i32) atlas.MaterialTile {
    return switch (block) {
        .air => unreachable,
        .grass => if (direction[1] > 0)
            .grass_top
        else if (direction[1] < 0)
            .dirt
        else
            .grass_side,
        .dirt => .dirt,
        .stone => .stone,
        .sand => .sand,
        .snow => if (direction[1] > 0)
            .snow_top
        else if (direction[1] < 0)
            .dirt
        else
            .snow_side,
        .wood => if (direction[1] == 0) .wood_side else .wood_top,
        .leaves => .leaves,
        .water => .water,
    };
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

const WaterInterfaceSampler = struct {
    pub fn blockAt(_: WaterInterfaceSampler, x: i32, y: i32, z: i32) BlockId {
        if (x != 1 or z != 1) return .air;
        return switch (y) {
            1 => .sand,
            2 => .water,
            else => .air,
        };
    }
};

const BoundaryWaterSampler = struct {
    pub fn blockAt(_: BoundaryWaterSampler, x: i32, y: i32, z: i32) BlockId {
        if (y != 1 or z != 0) return .air;
        return if (x == chunk_width - 1 or x == chunk_width) .water else .air;
    }
};

test "voxel ABI and empty chunk" {
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(Vertex));

    var mesh = try meshChunk(std.testing.allocator, .{ .x = 0, .z = 0 }, EmptySampler{});
    defer mesh.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 0), mesh.indices.len);
    try std.testing.expectEqual(@as(usize, 0), mesh.opaque_index_count);
    try std.testing.expectEqual(@as(usize, 0), mesh.water_index_count);
}

test "single block emits six indexed faces" {
    var mesh = try meshChunk(std.testing.allocator, .{ .x = 0, .z = 0 }, SingleBlockSampler{});
    defer mesh.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 24), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 36), mesh.indices.len);
    try std.testing.expectEqual(@as(usize, 36), mesh.opaque_index_count);
    try std.testing.expectEqual(@as(usize, 0), mesh.water_index_count);
}

test "face-specific block materials preserve top side and bottom identity" {
    try std.testing.expectEqual(atlas.MaterialTile.grass_top, materialForFace(.grass, .{ 0, 1, 0 }));
    try std.testing.expectEqual(atlas.MaterialTile.grass_side, materialForFace(.grass, .{ 1, 0, 0 }));
    try std.testing.expectEqual(atlas.MaterialTile.dirt, materialForFace(.grass, .{ 0, -1, 0 }));
    try std.testing.expectEqual(atlas.MaterialTile.snow_top, materialForFace(.snow, .{ 0, 1, 0 }));
    try std.testing.expectEqual(atlas.MaterialTile.snow_side, materialForFace(.snow, .{ 0, 0, -1 }));
    try std.testing.expectEqual(atlas.MaterialTile.sand, materialForFace(.sand, .{ 0, 1, 0 }));
    try std.testing.expectEqual(atlas.MaterialTile.wood_top, materialForFace(.wood, .{ 0, 1, 0 }));
    try std.testing.expectEqual(atlas.MaterialTile.wood_side, materialForFace(.wood, .{ 1, 0, 0 }));
    try std.testing.expectEqual(atlas.MaterialTile.leaves, materialForFace(.leaves, .{ 0, 1, 0 }));
    try std.testing.expectEqual(atlas.MaterialTile.water, materialForFace(.water, .{ 0, 1, 0 }));
}

test "adjacent blocks omit their shared face" {
    var mesh = try meshChunk(std.testing.allocator, .{ .x = 0, .z = 0 }, AdjacentBlockSampler{});
    defer mesh.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 40), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 60), mesh.indices.len);
}

test "transparent water preserves the solid interface and owns a contiguous range" {
    var mesh = try meshChunk(std.testing.allocator, .{ .x = 0, .z = 0 }, WaterInterfaceSampler{});
    defer mesh.deinit(std.testing.allocator);

    // The solid keeps all six faces, including its top face below the water.
    // Water omits its bottom interface and emits the remaining five faces.
    try std.testing.expectEqual(@as(usize, 44), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 66), mesh.indices.len);
    try std.testing.expectEqual(@as(usize, 36), mesh.opaque_index_count);
    try std.testing.expectEqual(@as(usize, 30), mesh.water_index_count);
    try std.testing.expectEqual(mesh.indices.len, mesh.opaque_index_count + mesh.water_index_count);
}

test "water culls its shared face across chunk boundaries" {
    var left = try meshChunk(std.testing.allocator, .{ .x = 0, .z = 0 }, BoundaryWaterSampler{});
    defer left.deinit(std.testing.allocator);
    var right = try meshChunk(std.testing.allocator, .{ .x = 1, .z = 0 }, BoundaryWaterSampler{});
    defer right.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), left.opaque_index_count);
    try std.testing.expectEqual(@as(usize, 30), left.water_index_count);
    try std.testing.expectEqual(@as(usize, 0), right.opaque_index_count);
    try std.testing.expectEqual(@as(usize, 30), right.water_index_count);
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
    try std.testing.expectEqual(first.opaque_index_count, second.opaque_index_count);
    try std.testing.expectEqual(first.water_index_count, second.water_index_count);
}

test "cached terrain mesh matches direct world sampling" {
    const coord = ChunkCoord{ .x = -1, .z = 1 };
    const seed = 42;
    var cached = try meshTerrainChunk(std.testing.allocator, coord, seed);
    defer cached.deinit(std.testing.allocator);
    var direct = try meshChunk(std.testing.allocator, coord, TerrainSampler{ .seed = seed });
    defer direct.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(Vertex, direct.vertices, cached.vertices);
    try std.testing.expectEqualSlices(u32, direct.indices, cached.indices);
    try std.testing.expectEqual(direct.opaque_index_count, cached.opaque_index_count);
    try std.testing.expectEqual(direct.water_index_count, cached.water_index_count);
}

test "terrain fixed coordinate snapshot" {
    const snapshots = [_]struct {
        x: i32,
        z: i32,
        column: TerrainColumn,
    }{
        .{ .x = 0, .z = 0, .column = .{ .height = 12, .surface = .grass } },
        .{ .x = -16, .z = 31, .column = .{ .height = 11, .surface = .sand } },
        .{ .x = 64, .z = 0, .column = .{ .height = 18, .surface = .grass } },
        .{ .x = 127, .z = -129, .column = .{ .height = 14, .surface = .sand } },
    };
    for (snapshots) |snapshot| {
        const actual = terrainColumn(0x564f_584c, snapshot.x, snapshot.z);
        try std.testing.expectEqual(snapshot.column.height, actual.height);
        try std.testing.expectEqual(snapshot.column.surface, actual.surface);
    }
}

test "trees occupy grass footprints and lakes retain their ground" {
    const seed = 0x564f_584c;
    const sampler = TerrainSampler{ .seed = seed };
    var tree_columns: usize = 0;
    var lake_columns: usize = 0;
    var z: i32 = -192;
    while (z <= 192) : (z += 1) {
        var x: i32 = -192;
        while (x <= 192) : (x += 1) {
            const column = terrainColumn(seed, x, z);
            if (column.wood_min >= 0 or column.leaves_min >= 0) {
                tree_columns += 1;
                try std.testing.expectEqual(BlockId.grass, column.surface);
                try std.testing.expectEqual(@as(i32, -1), column.water_level);
                try std.testing.expect(column.wood_max < chunk_height);
                try std.testing.expect(column.leaves_max < chunk_height);
                if (column.wood_min >= 0) {
                    try std.testing.expectEqual(BlockId.wood, sampler.blockAt(x, column.wood_min, z));
                }
                if (column.leaves_min >= 0 and !withinSpan(column.leaves_min, column.wood_min, column.wood_max)) {
                    try std.testing.expectEqual(BlockId.leaves, sampler.blockAt(x, column.leaves_min, z));
                }
            }
            if (column.water_level >= 0) {
                lake_columns += 1;
                try std.testing.expectEqual(BlockId.sand, column.surface);
                try std.testing.expect(column.height < column.water_level);
                try std.testing.expectEqual(BlockId.water, sampler.blockAt(x, column.water_level, z));
                try std.testing.expectEqual(BlockId.air, sampler.blockAt(x, column.water_level + 1, z));
                try std.testing.expectEqual(BlockId.sand, sampler.blockAt(x, column.height, z));
            }
            if (column.surface == .snow) {
                try std.testing.expectEqual(@as(i32, -1), column.wood_min);
                try std.testing.expectEqual(@as(i32, -1), column.leaves_min);
            }
        }
    }
    try std.testing.expect(tree_columns > 0);
    try std.testing.expect(lake_columns > 0);
}

test "terrain remains bounded and contains climate biomes" {
    var grass: usize = 0;
    var sand: usize = 0;
    var snow: usize = 0;
    var z: i32 = -256;
    while (z <= 256) : (z += 8) {
        var x: i32 = -256;
        while (x <= 256) : (x += 8) {
            const column = terrainColumn(0x564f_584c, x, z);
            try std.testing.expect(column.height >= 6);
            try std.testing.expect(column.height <= 48);
            switch (column.surface) {
                .grass => grass += 1,
                .sand => sand += 1,
                .snow => snow += 1,
                else => unreachable,
            }
        }
    }
    try std.testing.expect(grass > 0);
    try std.testing.expect(sand > 0);
    try std.testing.expect(snow > 0);
}

test "terrain halo cache matches world sampling across negative boundaries" {
    const coord = ChunkCoord{ .x = -1, .z = -2 };
    const seed = 0x564f_584c;
    const base_x = coord.x * chunk_width - 1;
    const base_z = coord.z * chunk_depth - 1;
    var columns = terrainColumnCache(coord, seed);
    const cached = CachedTerrainSampler{
        .base_x = base_x,
        .base_z = base_z,
        .columns = &columns,
    };
    const direct = TerrainSampler{ .seed = seed };

    for (0..terrain_cache_depth) |local_z| {
        for (0..terrain_cache_width) |local_x| {
            const world_x = base_x + @as(i32, @intCast(local_x));
            const world_z = base_z + @as(i32, @intCast(local_z));
            const height = terrainColumn(seed, world_x, world_z).height;
            for ([_]i32{ -1, 0, height - 4, height - 1, height, height + 1 }) |y| {
                try std.testing.expectEqual(
                    direct.blockAt(world_x, y, world_z),
                    cached.blockAt(world_x, y, world_z),
                );
            }
        }
    }
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
