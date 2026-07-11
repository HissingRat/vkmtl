const std = @import("std");

pub const schema_version = 1;

pub const RenderShader = struct {
    name: []const u8,
    source: []const u8,
    vertex_entry: []const u8,
    fragment_entry: []const u8,
};

pub const ComputeShader = struct {
    name: []const u8,
    source: []const u8,
    entry: []const u8,
};

pub const RayTracingShader = struct {
    name: []const u8,
    source: []const u8,
    metal_ray_generation_source: []const u8,
    ray_generation_entry: []const u8,
    miss_entry: []const u8,
    closest_hit_entry: []const u8,
    any_hit_entry: []const u8,
    intersection_entry: []const u8,
};

pub const Manifest = struct {
    schema_version: u32,
    render_shaders: []const RenderShader = &.{},
    compute_shaders: []const ComputeShader = &.{},
    ray_tracing_shaders: []const RayTracingShader = &.{},
};

pub fn parse(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Manifest) {
    var parsed = try std.json.parseFromSlice(Manifest, allocator, bytes, .{});
    errdefer parsed.deinit();
    try validate(parsed.value);
    return parsed;
}

pub fn sourceCount(value: Manifest) usize {
    return value.render_shaders.len + value.compute_shaders.len + value.ray_tracing_shaders.len * 2;
}

fn validate(value: Manifest) !void {
    if (value.schema_version != schema_version) return error.UnsupportedShaderManifestSchema;

    var names = std.StringHashMapUnmanaged(void).empty;
    defer names.deinit(std.heap.page_allocator);

    for (value.render_shaders) |shader| {
        try validateCommon(&names, shader.name, shader.source);
        try validateEntry(shader.vertex_entry);
        try validateEntry(shader.fragment_entry);
    }
    for (value.compute_shaders) |shader| {
        try validateCommon(&names, shader.name, shader.source);
        try validateEntry(shader.entry);
    }
    for (value.ray_tracing_shaders) |shader| {
        try validateCommon(&names, shader.name, shader.source);
        try validateSource(shader.metal_ray_generation_source);
        try validateEntry(shader.ray_generation_entry);
        try validateEntry(shader.miss_entry);
        try validateEntry(shader.closest_hit_entry);
        try validateEntry(shader.any_hit_entry);
        try validateEntry(shader.intersection_entry);
    }
}

fn validateCommon(names: *std.StringHashMapUnmanaged(void), name: []const u8, source: []const u8) !void {
    try validateName(name);
    const result = try names.getOrPut(std.heap.page_allocator, name);
    if (result.found_existing) return error.DuplicateShaderName;
    try validateSource(source);
}

fn validateName(name: []const u8) !void {
    if (name.len == 0) return error.EmptyShaderName;
    if (std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..") or name[name.len - 1] == '.') {
        return error.InvalidShaderName;
    }
    for (name) |byte| {
        if (!std.ascii.isLower(byte) and !std.ascii.isDigit(byte) and byte != '_' and byte != '-' and byte != '.') {
            return error.InvalidShaderName;
        }
    }
    if (isWindowsReservedName(name)) return error.InvalidShaderName;
}

fn isWindowsReservedName(name: []const u8) bool {
    const basename = name[0 .. std.mem.indexOfScalar(u8, name, '.') orelse name.len];
    if (std.mem.eql(u8, basename, "con") or
        std.mem.eql(u8, basename, "nul") or
        std.mem.eql(u8, basename, "aux") or
        std.mem.eql(u8, basename, "prn"))
    {
        return true;
    }
    if (basename.len != 4 or basename[3] < '1' or basename[3] > '9') return false;
    return std.mem.eql(u8, basename[0..3], "com") or std.mem.eql(u8, basename[0..3], "lpt");
}

fn validateSource(source: []const u8) !void {
    if (source.len == 0) return error.EmptyShaderSource;
    if (std.fs.path.isAbsolute(source)) return error.AbsoluteShaderSource;
    for (source) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and byte != '_' and byte != '-' and byte != '.' and byte != '/') {
            return error.InvalidShaderSource;
        }
    }
}

fn validateEntry(entry: []const u8) !void {
    if (entry.len == 0) return error.EmptyShaderEntry;
    if (!std.ascii.isAlphabetic(entry[0]) and entry[0] != '_') return error.InvalidShaderEntry;
    for (entry[1..]) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and byte != '_') return error.InvalidShaderEntry;
    }
}

test "manifest schema v1 accepts all shader kinds" {
    const bytes =
        \\{
        \\  "schema_version": 1,
        \\  "render_shaders": [{
        \\    "name": "render",
        \\    "source": "render.slang",
        \\    "vertex_entry": "vs_main",
        \\    "fragment_entry": "fs_main"
        \\  }],
        \\  "compute_shaders": [{
        \\    "name": "compute",
        \\    "source": "compute.slang",
        \\    "entry": "cs_main"
        \\  }],
        \\  "ray_tracing_shaders": [{
        \\    "name": "ray",
        \\    "source": "ray.slang",
        \\    "metal_ray_generation_source": "ray.msl",
        \\    "ray_generation_entry": "raygen",
        \\    "miss_entry": "miss",
        \\    "closest_hit_entry": "closest_hit",
        \\    "any_hit_entry": "any_hit",
        \\    "intersection_entry": "intersection"
        \\  }]
        \\}
    ;
    var parsed = try parse(std.testing.allocator, bytes);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 4), sourceCount(parsed.value));
    try std.testing.expectEqualStrings("vs_main", parsed.value.render_shaders[0].vertex_entry);
    try std.testing.expectEqualStrings("cs_main", parsed.value.compute_shaders[0].entry);
    try std.testing.expectEqualStrings("ray.msl", parsed.value.ray_tracing_shaders[0].metal_ray_generation_source);
}

test "manifest permits empty shader lists" {
    var parsed = try parse(std.testing.allocator,
        \\{
        \\  "schema_version": 1,
        \\  "render_shaders": [],
        \\  "compute_shaders": [],
        \\  "ray_tracing_shaders": []
        \\}
    );
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 0), sourceCount(parsed.value));
}

test "manifest rejects unsupported schemas" {
    try std.testing.expectError(error.UnsupportedShaderManifestSchema, parse(std.testing.allocator,
        \\{"schema_version": 2}
    ));
}

test "manifest rejects absolute sources" {
    try std.testing.expectError(error.AbsoluteShaderSource, parse(std.testing.allocator,
        \\{
        \\  "schema_version": 1,
        \\  "compute_shaders": [{
        \\    "name": "compute",
        \\    "source": "/tmp/compute.slang",
        \\    "entry": "cs_main"
        \\  }]
        \\}
    ));
}

test "manifest rejects duplicate names across shader kinds" {
    try std.testing.expectError(error.DuplicateShaderName, parse(std.testing.allocator,
        \\{
        \\  "schema_version": 1,
        \\  "render_shaders": [{
        \\    "name": "shared",
        \\    "source": "render.slang",
        \\    "vertex_entry": "vs_main",
        \\    "fragment_entry": "fs_main"
        \\  }],
        \\  "compute_shaders": [{
        \\    "name": "shared",
        \\    "source": "compute.slang",
        \\    "entry": "cs_main"
        \\  }]
        \\}
    ));
}

test "manifest rejects names that cannot be embedded safely" {
    try std.testing.expectError(error.InvalidShaderName, parse(std.testing.allocator,
        \\{
        \\  "schema_version": 1,
        \\  "compute_shaders": [{
        \\    "name": "../escape",
        \\    "source": "compute.slang",
        \\    "entry": "cs_main"
        \\  }]
        \\}
    ));
}

test "manifest requires lowercase names for portable artifact paths" {
    try std.testing.expectError(error.InvalidShaderName, parse(std.testing.allocator,
        \\{
        \\  "schema_version": 1,
        \\  "compute_shaders": [{
        \\    "name": "Compute",
        \\    "source": "compute.slang",
        \\    "entry": "cs_main"
        \\  }]
        \\}
    ));
}

test "manifest rejects Windows reserved artifact basenames" {
    const reserved = [_][]const u8{
        "con",  "con.json", "nul",  "aux.spv",  "prn",
        "com1", "com9.msl", "lpt1", "lpt9.log", "safe.",
    };
    for (reserved) |name| {
        try std.testing.expectError(error.InvalidShaderName, validateName(name));
    }

    try validateName("console");
    try validateName("com0");
    try validateName("com10");
    try validateName("safe.name");
}

test "manifest rejects non-identifier entries" {
    try std.testing.expectError(error.InvalidShaderEntry, parse(std.testing.allocator,
        \\{
        \\  "schema_version": 1,
        \\  "compute_shaders": [{
        \\    "name": "compute",
        \\    "source": "compute.slang",
        \\    "entry": "cs-main"
        \\  }]
        \\}
    ));
}

test "manifest rejects non-portable source paths" {
    try std.testing.expectError(error.InvalidShaderSource, parse(std.testing.allocator,
        \\{
        \\  "schema_version": 1,
        \\  "compute_shaders": [{
        \\    "name": "compute",
        \\    "source": "shader dir\\\\compute.slang",
        \\    "entry": "cs_main"
        \\  }]
        \\}
    ));
}
