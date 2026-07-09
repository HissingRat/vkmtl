const std = @import("std");
const core = @import("../core.zig");

const CFile = opaque {};

extern fn fopen(path: [*:0]const u8, mode: [*:0]const u8) ?*CFile;
extern fn fclose(file: *CFile) c_int;
extern fn fseek(file: *CFile, offset: c_long, origin: c_int) c_int;
extern fn ftell(file: *CFile) c_long;
extern fn fread(buffer: [*]u8, size: usize, count: usize, file: *CFile) usize;

const seek_set: c_int = 0;
const seek_end: c_int = 2;
const max_shader_artifact_bytes: usize = 64 * 1024 * 1024;

pub const LoadError = std.mem.Allocator.Error || error{
    UnsupportedShaderArtifactLanguage,
    ShaderArtifactReadFailed,
    ShaderArtifactTooLarge,
    InvalidSpirvArtifact,
};

pub fn readFileBytes(
    allocator: std.mem.Allocator,
    file_path: []const u8,
    max_bytes: usize,
) LoadError![]u8 {
    const path = try allocator.dupeZ(u8, file_path);
    defer allocator.free(path);

    const file = fopen(path.ptr, "rb") orelse return error.ShaderArtifactReadFailed;
    defer _ = fclose(file);

    if (fseek(file, 0, seek_end) != 0) return error.ShaderArtifactReadFailed;
    const end = ftell(file);
    if (end < 0) return error.ShaderArtifactReadFailed;

    const len: usize = @intCast(end);
    if (len > max_bytes) return error.ShaderArtifactTooLarge;
    if (fseek(file, 0, seek_set) != 0) return error.ShaderArtifactReadFailed;

    const bytes = try allocator.alloc(u8, len);
    errdefer allocator.free(bytes);

    if (len != 0 and fread(bytes.ptr, 1, bytes.len, file) != bytes.len) {
        return error.ShaderArtifactReadFailed;
    }
    return bytes;
}

pub fn readBytes(
    allocator: std.mem.Allocator,
    artifact: core.ShaderArtifact,
    expected_language: core.ShaderSourceLanguage,
) LoadError![]u8 {
    if (artifact.language != expected_language) return error.UnsupportedShaderArtifactLanguage;
    return try readFileBytes(allocator, artifact.path, max_shader_artifact_bytes);
}

pub fn readSpirvWords(
    allocator: std.mem.Allocator,
    artifact: core.ShaderArtifact,
) LoadError![]u32 {
    const bytes = try readBytes(allocator, artifact, .spirv);
    defer allocator.free(bytes);

    return try spirvBytesToWords(allocator, bytes);
}

pub fn spirvBytesToWords(
    allocator: std.mem.Allocator,
    bytes: []const u8,
) LoadError![]u32 {
    if (bytes.len == 0 or bytes.len % @sizeOf(u32) != 0) return error.InvalidSpirvArtifact;

    const words = try allocator.alloc(u32, bytes.len / @sizeOf(u32));
    errdefer allocator.free(words);
    @memcpy(std.mem.sliceAsBytes(words), bytes);
    return words;
}

test "shader artifact rejects mismatched language before file IO" {
    try std.testing.expectError(
        error.UnsupportedShaderArtifactLanguage,
        readBytes(std.testing.allocator, .{
            .path = "missing.shader",
            .language = .msl,
        }, .spirv),
    );
}
