const std = @import("std");

pub const MaterialTile = enum(u8) {
    grass_top,
    grass_side,
    dirt,
    stone,
    sand,
    snow_top,
    snow_side,
    wood_top,
    wood_side,
    leaves,
    water,
};

pub const tiles = [_]MaterialTile{
    .grass_top,
    .grass_side,
    .dirt,
    .stone,
    .sand,
    .snow_top,
    .snow_side,
    .wood_top,
    .wood_side,
    .leaves,
    .water,
};

pub const content_size: usize = 64;
pub const padding: usize = 2;
pub const cell_size: usize = content_size + padding * 2;
pub const tile_count: usize = tiles.len;
pub const width: usize = cell_size * tile_count;
pub const height: usize = cell_size;
pub const channel_count: usize = 4;
pub const byte_len: usize = width * height * channel_count;

pub const FillError = error{InvalidBufferLength};

pub const UvBounds = struct {
    u_min: f32,
    u_max: f32,
    v_min: f32,
    v_max: f32,
};

/// Returns texel-center UVs for the unpadded material content. The duplicated
/// border remains outside these bounds so filtering cannot immediately sample
/// a neighboring material.
pub fn uvBounds(tile: MaterialTile) UvBounds {
    const tile_index: usize = @intFromEnum(tile);
    const x: f32 = @floatFromInt(tile_index * cell_size + padding);
    const y: f32 = @floatFromInt(padding);
    const atlas_width: f32 = @floatFromInt(width);
    const atlas_height: f32 = @floatFromInt(height);
    const last_content_texel: f32 = @floatFromInt(content_size - 1);
    return .{
        .u_min = (x + 0.5) / atlas_width,
        .u_max = (x + last_content_texel + 0.5) / atlas_width,
        .v_min = (y + 0.5) / atlas_height,
        .v_max = (y + last_content_texel + 0.5) / atlas_height,
    };
}

/// Generates deterministic sRGB albedo bytes in RGB and a material height in
/// alpha. Every tile owns a two-texel border copied from its nearest content
/// edge, including the four corners.
pub fn fill(out: []u8) FillError!void {
    if (out.len != byte_len) return FillError.InvalidBufferLength;

    for (tiles) |tile| {
        const tile_index: usize = @intFromEnum(tile);
        const content_x = tile_index * cell_size + padding;
        for (0..content_size) |y| {
            for (0..content_size) |x| {
                const sample = materialPixel(tile, @intCast(x), @intCast(y));
                writePixel(out, content_x + x, padding + y, sample);
            }
        }
        copyPadding(out, tile_index);
    }
}

const Pixel = struct {
    rgb: [3]u8,
    height_value: u8,
};

fn materialPixel(tile: MaterialTile, x: u32, y: u32) Pixel {
    const fine = centeredNoise(hash(tile, x, y, 0x6f25_31a7), 25);
    const coarse = centeredNoise(hash(tile, x / 5, y / 5, 0x93d7_4c11), 31);
    return switch (tile) {
        .grass_top => grassTopPixel(tile, x, y, fine, coarse),
        .grass_side => grassSidePixel(tile, x, y, fine, coarse),
        .dirt => dirtPixel(tile, x, y, fine, coarse),
        .stone => stonePixel(tile, x, y, fine, coarse),
        .sand => sandPixel(tile, x, y, fine, coarse),
        .snow_top => snowTopPixel(tile, x, y, fine, coarse),
        .snow_side => snowSidePixel(tile, x, y, fine, coarse),
        .wood_top => woodTopPixel(tile, x, y, fine, coarse),
        .wood_side => woodSidePixel(tile, x, y, fine, coarse),
        .leaves => leavesPixel(tile, x, y, fine, coarse),
        .water => waterPixel(tile, x, y, fine, coarse),
    };
}

fn grassTopPixel(tile: MaterialTile, x: u32, y: u32, fine: i32, coarse: i32) Pixel {
    var red: i32 = 72 + @divTrunc(coarse, 2) + @divTrunc(fine, 3);
    var green: i32 = 139 + coarse + fine;
    var blue: i32 = 58 + @divTrunc(coarse, 3) + @divTrunc(fine, 4);
    var height_value: i32 = 148 + coarse + fine * 2;

    const tuft = hash(tile, x / 3, y / 4, 0x1b87_c9e3);
    if (tuft % 11 == 0 and (x + y + (tuft >> 8)) % 5 <= 1) {
        red -= 18;
        green += 34;
        blue -= 10;
        height_value += 54;
    } else if (isSpeckle(tile, x, y, 6, 5, 0xa013_57bd)) {
        red += 16;
        green += 22;
        blue += 8;
        height_value += 25;
    }
    return pixel(red, green, blue, height_value);
}

fn grassSidePixel(tile: MaterialTile, x: u32, y: u32, fine: i32, coarse: i32) Pixel {
    const edge_hash = hash(tile, x / 3, 0, 0x32f8_95c7);
    const grass_depth: u32 = 13 + edge_hash % 9;
    if (y < grass_depth) {
        var result = grassTopPixel(tile, x, y, fine, coarse);
        if (y + 3 >= grass_depth) {
            result.rgb[0] = clampByte(@as(i32, result.rgb[0]) - 12);
            result.rgb[1] = clampByte(@as(i32, result.rgb[1]) - 24);
            result.height_value = clampByte(@as(i32, result.height_value) - 18);
        }
        return result;
    }

    var result = dirtPixel(tile, x, y, fine, coarse);
    if (y < grass_depth + 8 and hash(tile, x, y, 0xf15d_2a09) % 7 < 2) {
        result.rgb[0] = clampByte(@as(i32, result.rgb[0]) - 20);
        result.rgb[1] = clampByte(@as(i32, result.rgb[1]) + 30);
        result.rgb[2] = clampByte(@as(i32, result.rgb[2]) - 12);
        result.height_value = clampByte(@as(i32, result.height_value) + 38);
    }
    return result;
}

fn dirtPixel(tile: MaterialTile, x: u32, y: u32, fine: i32, coarse: i32) Pixel {
    var red: i32 = 126 + coarse + fine;
    var green: i32 = 82 + @divTrunc(coarse, 2) + @divTrunc(fine, 2);
    var blue: i32 = 46 + @divTrunc(coarse, 3) + @divTrunc(fine, 3);
    var height_value: i32 = 108 + coarse + fine * 2;
    if (isSpeckle(tile, x, y, 7, 4, 0x4d31_a2f9)) {
        red += 24;
        green += 17;
        blue += 10;
        height_value += 44;
    } else if (isSpeckle(tile, x, y, 5, 6, 0x873b_6ce1)) {
        red -= 27;
        green -= 19;
        blue -= 11;
        height_value -= 35;
    }
    return pixel(red, green, blue, height_value);
}

fn stonePixel(tile: MaterialTile, x: u32, y: u32, fine: i32, coarse: i32) Pixel {
    var value: i32 = 128 + coarse + fine;
    var height_value: i32 = 132 + coarse + fine * 2;
    const crack_offset = hash(tile, y / 7, y / 13, 0x29b6_f047) % 17;
    const crack = (x + y * 2 + crack_offset) % 31 <= 1 and
        hash(tile, x / 8, y / 8, 0xd4a1_730d) % 4 != 0;
    if (crack) {
        value -= 51;
        height_value -= 70;
    } else if (isSpeckle(tile, x, y, 8, 5, 0x62cb_19e5)) {
        value += 31;
        height_value += 27;
    }
    return pixel(value, value + 4, value + 9, height_value);
}

fn sandPixel(tile: MaterialTile, x: u32, y: u32, fine: i32, coarse: i32) Pixel {
    const ripple: i32 = @intCast((x + y * 2 + (hash(tile, 0, y / 8, 0xb376_20df) % 9)) % 12);
    const ridge: i32 = 6 - @as(i32, @intCast(@abs(ripple - 6)));
    var red: i32 = 207 + @divTrunc(coarse, 2) + @divTrunc(fine, 3) + ridge;
    var green: i32 = 188 + @divTrunc(coarse, 2) + @divTrunc(fine, 3) + ridge;
    var blue: i32 = 128 + @divTrunc(coarse, 3) + @divTrunc(fine, 4) + @divTrunc(ridge, 2);
    var height_value: i32 = 143 + coarse + ridge * 5;
    if (isSpeckle(tile, x, y, 5, 7, 0xc075_9b31)) {
        red -= 28;
        green -= 24;
        blue -= 18;
        height_value -= 24;
    }
    return pixel(red, green, blue, height_value);
}

fn snowTopPixel(tile: MaterialTile, x: u32, y: u32, fine: i32, coarse: i32) Pixel {
    var red: i32 = 225 + @divTrunc(coarse, 4) + @divTrunc(fine, 5);
    var green: i32 = 234 + @divTrunc(coarse, 4) + @divTrunc(fine, 5);
    var blue: i32 = 239 + @divTrunc(coarse, 3) + @divTrunc(fine, 4);
    var height_value: i32 = 210 + @divTrunc(coarse, 2) + fine;
    if (isSpeckle(tile, x, y, 7, 7, 0x17ce_a495)) {
        red += 24;
        green += 21;
        blue += 16;
        height_value += 31;
    } else if ((x + y * 3 + hash(tile, x / 9, y / 9, 0x5e20_d7b3)) % 29 == 0) {
        red -= 23;
        green -= 14;
        blue -= 4;
        height_value -= 35;
    }
    return pixel(red, green, blue, height_value);
}

fn snowSidePixel(tile: MaterialTile, x: u32, y: u32, fine: i32, coarse: i32) Pixel {
    const edge_hash = hash(tile, x / 4, 0, 0xe1a4_6c29);
    const snow_depth: u32 = 11 + edge_hash % 8;
    if (y < snow_depth) {
        var result = snowTopPixel(tile, x, y, fine, coarse);
        if (y + 2 >= snow_depth) {
            result.rgb[2] = clampByte(@as(i32, result.rgb[2]) + 8);
            result.height_value = clampByte(@as(i32, result.height_value) - 20);
        }
        return result;
    }

    var result = dirtPixel(tile, x, y, fine, coarse);
    result.rgb[0] = clampByte(@as(i32, result.rgb[0]) - 15);
    result.rgb[1] = clampByte(@as(i32, result.rgb[1]) - 10);
    result.rgb[2] = clampByte(@as(i32, result.rgb[2]) + 8);
    return result;
}

fn woodTopPixel(tile: MaterialTile, x: u32, y: u32, fine: i32, coarse: i32) Pixel {
    const dx = @as(i32, @intCast(x)) - @as(i32, @intCast(content_size / 2));
    const dy = @as(i32, @intCast(y)) - @as(i32, @intCast(content_size / 2));
    const radius = @as(u32, @intCast(@max(@abs(dx), @abs(dy))));
    const warped_ring = (radius + hash(tile, x / 5, y / 5, 0x8a31_1d67) % 5) % 11;
    const ring: i32 = if (warped_ring <= 1) -24 else if (warped_ring >= 9) 13 else 0;
    return pixel(
        156 + @divTrunc(coarse, 2) + @divTrunc(fine, 3) + ring,
        111 + @divTrunc(coarse, 3) + @divTrunc(fine, 4) + ring,
        61 + @divTrunc(coarse, 4) + @divTrunc(fine, 5) + @divTrunc(ring, 2),
        137 + coarse + fine + ring * 2,
    );
}

fn woodSidePixel(tile: MaterialTile, x: u32, y: u32, fine: i32, coarse: i32) Pixel {
    const grain = @as(i32, @intCast((x + hash(tile, x / 7, y / 11, 0xd9c4_2e51) % 7) % 13));
    const stripe: i32 = if (grain <= 1) -28 else if (grain >= 11) 12 else 0;
    const knot_hash = hash(tile, x / 9, y / 9, 0x49b8_76a3);
    const knot: i32 = if (knot_hash % 23 == 0 and (x + y + (knot_hash >> 8)) % 7 <= 2) -34 else 0;
    return pixel(
        142 + @divTrunc(coarse, 2) + @divTrunc(fine, 3) + stripe + knot,
        92 + @divTrunc(coarse, 3) + @divTrunc(fine, 4) + stripe + knot,
        47 + @divTrunc(coarse, 4) + @divTrunc(fine, 5) + @divTrunc(stripe + knot, 2),
        128 + coarse + fine * 2 + stripe * 2 + knot,
    );
}

fn leavesPixel(tile: MaterialTile, x: u32, y: u32, fine: i32, coarse: i32) Pixel {
    const cluster = hash(tile, x / 4, y / 4, 0x763a_b91d);
    const light_patch: i32 = if (cluster % 9 <= 1) 27 else 0;
    const deep_patch: i32 = if ((cluster >> 8) % 13 == 0) -25 else 0;
    return pixel(
        40 + @divTrunc(coarse, 3) + @divTrunc(fine, 3) + @divTrunc(light_patch, 3),
        112 + coarse + fine + light_patch + deep_patch,
        43 + @divTrunc(coarse, 3) + @divTrunc(fine, 3) + @divTrunc(light_patch, 4),
        165 + coarse + fine * 2 + light_patch + deep_patch,
    );
}

fn waterPixel(tile: MaterialTile, x: u32, y: u32, fine: i32, coarse: i32) Pixel {
    const wave = @as(i32, @intCast((x * 2 + y + hash(tile, 0, y / 6, 0xa251_6ec9) % 11) % 17));
    const crest: i32 = if (wave <= 1) 24 else if (wave >= 15) -10 else 0;
    return pixel(
        25 + @divTrunc(coarse, 4) + @divTrunc(fine, 5) + @divTrunc(crest, 4),
        91 + @divTrunc(coarse, 3) + @divTrunc(fine, 4) + @divTrunc(crest, 2),
        153 + @divTrunc(coarse, 2) + @divTrunc(fine, 3) + crest,
        118 + coarse + fine + crest * 2,
    );
}

fn isSpeckle(
    tile: MaterialTile,
    x: u32,
    y: u32,
    cell: u32,
    chance_divisor: u32,
    salt: u32,
) bool {
    const cell_x = x / cell;
    const cell_y = y / cell;
    const value = hash(tile, cell_x, cell_y, salt);
    if (value % chance_divisor != 0) return false;
    const center_x = cell_x * cell + (value >> 8) % cell;
    const center_y = cell_y * cell + (value >> 16) % cell;
    const dx = @as(i32, @intCast(x)) - @as(i32, @intCast(center_x));
    const dy = @as(i32, @intCast(y)) - @as(i32, @intCast(center_y));
    return dx * dx + dy * dy <= 2;
}

fn centeredNoise(value: u32, span: u32) i32 {
    return @as(i32, @intCast(value % span)) - @as(i32, @intCast(span / 2));
}

fn hash(tile: MaterialTile, x: u32, y: u32, salt: u32) u32 {
    var value = salt ^ (@as(u32, @intFromEnum(tile)) +% 1) *% 0x9e37_79b9;
    value ^= x *% 0x85eb_ca6b;
    value ^= y *% 0xc2b2_ae35;
    value ^= value >> 16;
    value *%= 0x7feb_352d;
    value ^= value >> 15;
    value *%= 0x846c_a68b;
    value ^= value >> 16;
    return value;
}

fn pixel(red: i32, green: i32, blue: i32, height_value: i32) Pixel {
    return .{
        .rgb = .{ clampByte(red), clampByte(green), clampByte(blue) },
        .height_value = clampByte(height_value),
    };
}

fn clampByte(value: i32) u8 {
    return @intCast(std.math.clamp(value, 0, 255));
}

fn writePixel(out: []u8, x: usize, y: usize, value: Pixel) void {
    const offset = pixelOffset(x, y);
    out[offset] = value.rgb[0];
    out[offset + 1] = value.rgb[1];
    out[offset + 2] = value.rgb[2];
    out[offset + 3] = value.height_value;
}

fn copyPadding(out: []u8, tile_index: usize) void {
    const cell_x = tile_index * cell_size;
    for (0..cell_size) |local_y| {
        const source_y = padding + std.math.clamp(local_y, padding, padding + content_size - 1) - padding;
        for (0..cell_size) |local_x| {
            if (local_x >= padding and local_x < padding + content_size and
                local_y >= padding and local_y < padding + content_size)
            {
                continue;
            }
            const source_x = cell_x + padding + std.math.clamp(local_x, padding, padding + content_size - 1) - padding;
            const source_offset = pixelOffset(source_x, source_y);
            const destination_offset = pixelOffset(cell_x + local_x, local_y);
            @memcpy(out[destination_offset .. destination_offset + channel_count], out[source_offset .. source_offset + channel_count]);
        }
    }
}

fn pixelOffset(x: usize, y: usize) usize {
    return (y * width + x) * channel_count;
}

fn expectPixelEqual(pixels: []const u8, a_x: usize, a_y: usize, b_x: usize, b_y: usize) !void {
    const a = pixelOffset(a_x, a_y);
    const b = pixelOffset(b_x, b_y);
    try std.testing.expectEqualSlices(u8, pixels[a .. a + channel_count], pixels[b .. b + channel_count]);
}

fn contentChecksum(pixels: []const u8, tile: MaterialTile) u64 {
    var checksum: u64 = 0xcbf2_9ce4_8422_2325;
    const content_x = @as(usize, @intFromEnum(tile)) * cell_size + padding;
    for (0..content_size) |y| {
        const row_start = pixelOffset(content_x, padding + y);
        const row = pixels[row_start .. row_start + content_size * channel_count];
        for (row) |byte| {
            checksum ^= byte;
            checksum *%= 0x0000_0100_0000_01b3;
        }
    }
    return checksum;
}

test "atlas buffer length is exact" {
    const pixels = try std.testing.allocator.alloc(u8, byte_len);
    defer std.testing.allocator.free(pixels);
    try fill(pixels);
    try std.testing.expectEqual(width * height * channel_count, pixels.len);
    try std.testing.expectError(FillError.InvalidBufferLength, fill(pixels[0 .. pixels.len - 1]));
}

test "atlas generation is deterministic" {
    const first = try std.testing.allocator.alloc(u8, byte_len);
    defer std.testing.allocator.free(first);
    const second = try std.testing.allocator.alloc(u8, byte_len);
    defer std.testing.allocator.free(second);
    try fill(first);
    try fill(second);
    try std.testing.expectEqualSlices(u8, first, second);
}

test "atlas padding copies edges and material tiles differ" {
    const pixels = try std.testing.allocator.alloc(u8, byte_len);
    defer std.testing.allocator.free(pixels);
    try fill(pixels);

    for (tiles) |tile| {
        const cell_x = @as(usize, @intFromEnum(tile)) * cell_size;
        const first_x = cell_x + padding;
        const last_x = first_x + content_size - 1;
        const first_y = padding;
        const last_y = first_y + content_size - 1;
        for (0..content_size) |offset| {
            for (0..padding) |border| {
                try expectPixelEqual(pixels, cell_x + border, first_y + offset, first_x, first_y + offset);
                try expectPixelEqual(pixels, last_x + 1 + border, first_y + offset, last_x, first_y + offset);
                try expectPixelEqual(pixels, first_x + offset, border, first_x + offset, first_y);
                try expectPixelEqual(pixels, first_x + offset, last_y + 1 + border, first_x + offset, last_y);
            }
        }
        try expectPixelEqual(pixels, cell_x, 0, first_x, first_y);
        try expectPixelEqual(pixels, cell_x + cell_size - 1, 0, last_x, first_y);
        try expectPixelEqual(pixels, cell_x, cell_size - 1, first_x, last_y);
        try expectPixelEqual(pixels, cell_x + cell_size - 1, cell_size - 1, last_x, last_y);
    }

    for (tiles, 0..) |tile, tile_index| {
        const checksum = contentChecksum(pixels, tile);
        for (tiles[0..tile_index]) |previous| {
            try std.testing.expect(checksum != contentChecksum(pixels, previous));
        }
    }
}
