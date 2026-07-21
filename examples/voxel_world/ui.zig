const std = @import("std");

pub const Color = [4]f32;
pub const Point = [2]f32;

pub const Vertex = extern struct {
    position: Point,
    color: Color,
};

comptime {
    if (@sizeOf(Vertex) != 24) @compileError("voxel UI vertices must remain 24 bytes");
}

pub const DrawRange = struct {
    first_vertex: u32,
    vertex_count: u32,

    pub fn isEmpty(self: DrawRange) bool {
        return self.vertex_count == 0;
    }
};

pub const Error = error{
    InvalidExtent,
    InvalidGeometry,
    OutOfVertices,
};

pub const glyph_width: usize = 5;
pub const glyph_height: usize = 7;
pub const glyph_advance: usize = 6;

/// A fixed-storage UI batch. Coordinates use a top-left pixel origin.
pub const Batch = struct {
    storage: []Vertex,
    vertex_count: usize = 0,
    width: f32 = 1,
    height: f32 = 1,

    pub fn init(storage: []Vertex) Batch {
        return .{ .storage = storage };
    }

    pub fn begin(self: *Batch, width: u32, height: u32) Error!void {
        if (width == 0 or height == 0) return Error.InvalidExtent;
        self.vertex_count = 0;
        self.width = @floatFromInt(width);
        self.height = @floatFromInt(height);
    }

    pub fn vertices(self: Batch) []const Vertex {
        return self.storage[0..self.vertex_count];
    }

    pub fn addRect(
        self: *Batch,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        color: Color,
    ) Error!DrawRange {
        if (!finite(x) or !finite(y) or !finite(width) or !finite(height) or
            width < 0 or height < 0 or !finiteColor(color))
        {
            return Error.InvalidGeometry;
        }
        if (width == 0 or height == 0) return self.emptyRange();
        return self.addQuad(
            .{ x, y },
            .{ x + width, y },
            .{ x + width, y + height },
            .{ x, y + height },
            color,
        );
    }

    pub fn addQuad(
        self: *Batch,
        top_left: Point,
        top_right: Point,
        bottom_right: Point,
        bottom_left: Point,
        color: Color,
    ) Error!DrawRange {
        if (!finitePoint(top_left) or !finitePoint(top_right) or
            !finitePoint(bottom_right) or !finitePoint(bottom_left) or
            !finiteColor(color))
        {
            return Error.InvalidGeometry;
        }
        try self.reserve(6);
        const first = self.vertex_count;
        const points = [_]Point{
            top_left,
            top_right,
            bottom_right,
            top_left,
            bottom_right,
            bottom_left,
        };
        for (points) |point| self.appendUnchecked(point, color);
        return range(first, 6);
    }

    pub fn addCircle(
        self: *Batch,
        center: Point,
        radius: f32,
        segment_count: u32,
        color: Color,
    ) Error!DrawRange {
        if (!finitePoint(center) or !finite(radius) or radius < 0 or
            segment_count < 3 or !finiteColor(color))
        {
            return Error.InvalidGeometry;
        }
        if (radius == 0) return self.emptyRange();
        const required = std.math.mul(usize, @intCast(segment_count), 3) catch
            return Error.OutOfVertices;
        try self.reserve(required);

        const first = self.vertex_count;
        const step = std.math.tau / @as(f32, @floatFromInt(segment_count));
        for (0..segment_count) |index| {
            const angle_a = step * @as(f32, @floatFromInt(index));
            const angle_b = step * @as(f32, @floatFromInt(index + 1));
            self.appendUnchecked(center, color);
            self.appendUnchecked(.{
                center[0] + @cos(angle_a) * radius,
                center[1] + @sin(angle_a) * radius,
            }, color);
            self.appendUnchecked(.{
                center[0] + @cos(angle_b) * radius,
                center[1] + @sin(angle_b) * radius,
            }, color);
        }
        return range(first, required);
    }

    pub fn addText(
        self: *Batch,
        x: f32,
        y: f32,
        pixel_size: f32,
        text: []const u8,
        color: Color,
    ) Error!DrawRange {
        if (!finite(x) or !finite(y) or !finite(pixel_size) or pixel_size <= 0 or
            !finiteColor(color))
        {
            return Error.InvalidGeometry;
        }

        var lit_pixels: usize = 0;
        for (text) |character| {
            for (glyph(character)) |row| lit_pixels += @popCount(row);
        }
        const required = std.math.mul(usize, lit_pixels, 6) catch
            return Error.OutOfVertices;
        try self.reserve(required);

        const first = self.vertex_count;
        var pen_x = x;
        for (text) |character| {
            const glyph_rows = glyph(character);
            for (glyph_rows, 0..) |row, row_index| {
                for (0..glyph_width) |column_index| {
                    const shift: u3 = @intCast(glyph_width - 1 - column_index);
                    if ((row & (@as(u8, 1) << shift)) == 0) continue;
                    self.appendRectUnchecked(
                        pen_x + @as(f32, @floatFromInt(column_index)) * pixel_size,
                        y + @as(f32, @floatFromInt(row_index)) * pixel_size,
                        pixel_size,
                        pixel_size,
                        color,
                    );
                }
            }
            pen_x += @as(f32, glyph_advance) * pixel_size;
        }
        return range(first, required);
    }

    fn appendRectUnchecked(
        self: *Batch,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        color: Color,
    ) void {
        const points = [_]Point{
            .{ x, y },
            .{ x + width, y },
            .{ x + width, y + height },
            .{ x, y },
            .{ x + width, y + height },
            .{ x, y + height },
        };
        for (points) |point| self.appendUnchecked(point, color);
    }

    fn appendUnchecked(self: *Batch, point: Point, color: Color) void {
        self.storage[self.vertex_count] = .{
            .position = self.pixelToNdc(point),
            .color = color,
        };
        self.vertex_count += 1;
    }

    fn pixelToNdc(self: Batch, point: Point) Point {
        return .{
            point[0] * 2.0 / self.width - 1.0,
            1.0 - point[1] * 2.0 / self.height,
        };
    }

    fn reserve(self: Batch, additional: usize) Error!void {
        if (additional > self.storage.len - self.vertex_count) return Error.OutOfVertices;
    }

    fn emptyRange(self: Batch) DrawRange {
        return .{
            .first_vertex = @intCast(self.vertex_count),
            .vertex_count = 0,
        };
    }
};

pub const FpsCounter = struct {
    refresh_interval: f64 = 0.25,
    elapsed_seconds: f64 = 0,
    frame_count: u32 = 0,
    display_fps: f64 = 0,

    pub fn recordFrame(self: *FpsCounter, delta_seconds: f64) void {
        if (!std.math.isFinite(delta_seconds) or delta_seconds < 0) return;
        self.elapsed_seconds += delta_seconds;
        self.frame_count +|= 1;
        if (self.elapsed_seconds < self.refresh_interval or self.elapsed_seconds <= 0) return;
        self.display_fps = @as(f64, @floatFromInt(self.frame_count)) / self.elapsed_seconds;
        self.elapsed_seconds = 0;
        self.frame_count = 0;
    }

    pub fn writeLabel(self: FpsCounter, buffer: []u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "FPS {d:.0}", .{self.display_fps});
    }
};

pub fn textWidth(text: []const u8, pixel_size: f32) f32 {
    if (text.len == 0 or pixel_size <= 0 or !finite(pixel_size)) return 0;
    return @as(f32, @floatFromInt(text.len * glyph_advance - 1)) * pixel_size;
}

pub fn textHeight(pixel_size: f32) f32 {
    if (pixel_size <= 0 or !finite(pixel_size)) return 0;
    return @as(f32, glyph_height) * pixel_size;
}

/// Returns seven rows whose low five bits form a 5x7 bitmap.
pub fn glyph(character: u8) [glyph_height]u8 {
    return switch (character) {
        ' ' => rows(0, 0, 0, 0, 0, 0, 0),
        'A' => rows(14, 17, 17, 31, 17, 17, 17),
        'B' => rows(30, 17, 17, 30, 17, 17, 30),
        'C' => rows(14, 17, 16, 16, 16, 17, 14),
        'D' => rows(30, 17, 17, 17, 17, 17, 30),
        'E' => rows(31, 16, 16, 30, 16, 16, 31),
        'F' => rows(31, 16, 16, 30, 16, 16, 16),
        'G' => rows(14, 17, 16, 23, 17, 17, 14),
        'H' => rows(17, 17, 17, 31, 17, 17, 17),
        'I' => rows(31, 4, 4, 4, 4, 4, 31),
        'J' => rows(7, 2, 2, 2, 18, 18, 12),
        'K' => rows(17, 18, 20, 24, 20, 18, 17),
        'L' => rows(16, 16, 16, 16, 16, 16, 31),
        'M' => rows(17, 27, 21, 21, 17, 17, 17),
        'N' => rows(17, 25, 21, 19, 17, 17, 17),
        'O' => rows(14, 17, 17, 17, 17, 17, 14),
        'P' => rows(30, 17, 17, 30, 16, 16, 16),
        'Q' => rows(14, 17, 17, 17, 21, 18, 13),
        'R' => rows(30, 17, 17, 30, 20, 18, 17),
        'S' => rows(15, 16, 16, 14, 1, 1, 30),
        'T' => rows(31, 4, 4, 4, 4, 4, 4),
        'U' => rows(17, 17, 17, 17, 17, 17, 14),
        'V' => rows(17, 17, 17, 17, 17, 10, 4),
        'W' => rows(17, 17, 17, 21, 21, 21, 10),
        'X' => rows(17, 17, 10, 4, 10, 17, 17),
        'Y' => rows(17, 17, 10, 4, 4, 4, 4),
        'Z' => rows(31, 1, 2, 4, 8, 16, 31),
        'a' => rows(0, 0, 14, 1, 15, 17, 15),
        'b' => rows(16, 16, 30, 17, 17, 17, 30),
        'c' => rows(0, 0, 14, 16, 16, 17, 14),
        'd' => rows(1, 1, 15, 17, 17, 17, 15),
        'e' => rows(0, 0, 14, 17, 31, 16, 14),
        'f' => rows(6, 9, 8, 28, 8, 8, 8),
        'g' => rows(0, 0, 15, 17, 15, 1, 14),
        'h' => rows(16, 16, 30, 17, 17, 17, 17),
        'i' => rows(4, 0, 12, 4, 4, 4, 14),
        'j' => rows(2, 0, 6, 2, 2, 18, 12),
        'k' => rows(16, 16, 18, 20, 24, 20, 18),
        'l' => rows(12, 4, 4, 4, 4, 4, 14),
        'm' => rows(0, 0, 26, 21, 21, 21, 21),
        'n' => rows(0, 0, 30, 17, 17, 17, 17),
        'o' => rows(0, 0, 14, 17, 17, 17, 14),
        'p' => rows(0, 0, 30, 17, 30, 16, 16),
        'q' => rows(0, 0, 15, 17, 15, 1, 1),
        'r' => rows(0, 0, 22, 25, 16, 16, 16),
        's' => rows(0, 0, 15, 16, 14, 1, 30),
        't' => rows(8, 8, 28, 8, 8, 9, 6),
        'u' => rows(0, 0, 17, 17, 17, 19, 13),
        'v' => rows(0, 0, 17, 17, 17, 10, 4),
        'w' => rows(0, 0, 17, 17, 21, 21, 10),
        'x' => rows(0, 0, 17, 10, 4, 10, 17),
        'y' => rows(0, 0, 17, 17, 15, 1, 14),
        'z' => rows(0, 0, 31, 2, 4, 8, 31),
        '0' => rows(14, 17, 19, 21, 25, 17, 14),
        '1' => rows(4, 12, 4, 4, 4, 4, 14),
        '2' => rows(14, 17, 1, 2, 4, 8, 31),
        '3' => rows(30, 1, 1, 14, 1, 1, 30),
        '4' => rows(2, 6, 10, 18, 31, 2, 2),
        '5' => rows(31, 16, 16, 30, 1, 1, 30),
        '6' => rows(14, 16, 16, 30, 17, 17, 14),
        '7' => rows(31, 1, 2, 4, 8, 8, 8),
        '8' => rows(14, 17, 17, 14, 17, 17, 14),
        '9' => rows(14, 17, 17, 15, 1, 1, 14),
        ':' => rows(0, 4, 4, 0, 4, 4, 0),
        '.' => rows(0, 0, 0, 0, 0, 4, 4),
        '-' => rows(0, 0, 0, 31, 0, 0, 0),
        '?' => fallback_glyph,
        else => fallback_glyph,
    };
}

const fallback_glyph = rows(14, 17, 1, 2, 4, 0, 4);

fn rows(a: u8, b: u8, c: u8, d: u8, e: u8, f: u8, g: u8) [glyph_height]u8 {
    return .{ a, b, c, d, e, f, g };
}

fn range(first: usize, count: usize) DrawRange {
    return .{
        .first_vertex = @intCast(first),
        .vertex_count = @intCast(count),
    };
}

fn finite(value: f32) bool {
    return std.math.isFinite(value);
}

fn finitePoint(point: Point) bool {
    return finite(point[0]) and finite(point[1]);
}

fn finiteColor(color: Color) bool {
    for (color) |channel| {
        if (!finite(channel)) return false;
    }
    return true;
}

test "glyphs preserve lowercase and fall back predictably" {
    try std.testing.expectEqual(rows(0, 0, 14, 1, 15, 17, 15), glyph('a'));
    try std.testing.expectEqual(glyph('?'), glyph('@'));
    try std.testing.expectEqual(rows(0, 0, 0, 0, 0, 0, 0), glyph(' '));
}

test "text width uses fixed glyph advance without trailing spacing" {
    try std.testing.expectEqual(@as(f32, 0), textWidth("", 3));
    try std.testing.expectEqual(@as(f32, 15), textWidth("A", 3));
    try std.testing.expectEqual(@as(f32, 33), textWidth("AB", 3));
    try std.testing.expectEqual(@as(f32, 21), textHeight(3));
}

test "draw ranges are contiguous and capacity failures are atomic" {
    var storage: [12]Vertex = undefined;
    var batch = Batch.init(storage[0..]);
    try batch.begin(100, 50);

    const first = try batch.addRect(0, 0, 10, 10, .{ 1, 0, 0, 1 });
    try std.testing.expectEqual(DrawRange{ .first_vertex = 0, .vertex_count = 6 }, first);
    const second = try batch.addQuad(.{ 10, 0 }, .{ 20, 0 }, .{ 20, 10 }, .{ 10, 10 }, .{ 0, 1, 0, 1 });
    try std.testing.expectEqual(DrawRange{ .first_vertex = 6, .vertex_count = 6 }, second);
    try std.testing.expectEqual(@as(usize, 12), batch.vertices().len);

    try std.testing.expectError(
        Error.OutOfVertices,
        batch.addRect(20, 0, 10, 10, .{ 0, 0, 1, 1 }),
    );
    try std.testing.expectEqual(@as(usize, 12), batch.vertices().len);
}

test "pixel coordinates map to top-left-oriented clip space" {
    var storage: [6]Vertex = undefined;
    var batch = Batch.init(storage[0..]);
    try batch.begin(100, 50);
    _ = try batch.addRect(0, 0, 100, 50, .{ 1, 1, 1, 1 });
    try std.testing.expectEqual(Point{ -1, 1 }, storage[0].position);
    try std.testing.expectEqual(Point{ 1, -1 }, storage[2].position);
}

test "fps counter updates at its refresh interval" {
    var counter = FpsCounter{ .refresh_interval = 0.25 };
    for (0..31) |_| counter.recordFrame(1.0 / 120.0);
    try std.testing.expectApproxEqAbs(@as(f64, 120), counter.display_fps, 0.001);

    var label_buffer: [32]u8 = undefined;
    try std.testing.expectEqualStrings("FPS 120", try counter.writeLabel(label_buffer[0..]));
}
