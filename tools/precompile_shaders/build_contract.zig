const std = @import("std");

pub fn validateManifestPath(allocator: std.mem.Allocator, manifest_path: std.Build.LazyPath) !void {
    const sub_path = try logicalSubPath(allocator, manifest_path);
    defer allocator.free(sub_path);
    try validateWithinLogicalRoot(allocator, &.{sub_path});
}

pub fn validateSourcePath(
    allocator: std.mem.Allocator,
    manifest_path: std.Build.LazyPath,
    source: []const u8,
) !void {
    const manifest_sub_path = try logicalSubPath(allocator, manifest_path);
    defer allocator.free(manifest_sub_path);
    const manifest_dir = std.fs.path.dirname(manifest_sub_path) orelse "";
    try validateWithinLogicalRoot(allocator, &.{ manifest_dir, source });
}

const LogicalSubPath = struct {
    bytes: []const u8,
    allow_native_separators: bool,
};

fn logicalSubPath(allocator: std.mem.Allocator, path: std.Build.LazyPath) ![]u8 {
    const logical: LogicalSubPath = switch (path) {
        .src_path => |src| .{
            .bytes = src.sub_path,
            .allow_native_separators = true,
        },
        // Scalar -D paths are relative to the build runner's working directory,
        // which is their logical root for this contract.
        .cwd_relative => |sub_path| .{
            .bytes = sub_path,
            .allow_native_separators = false,
        },
        // Zig may translate a consumer-owned LazyPath to the dependency host's
        // native separator while preserving its dependency-root provenance.
        .dependency => |dependency| .{
            .bytes = dependency.sub_path,
            .allow_native_separators = true,
        },
        .generated => return error.GeneratedShaderManifestUnsupported,
    };

    if (std.fs.path.getWin32PathType(u8, logical.bytes) != .relative or
        std.fs.path.isAbsolutePosix(logical.bytes) or
        (!logical.allow_native_separators and std.mem.indexOfScalar(u8, logical.bytes, '\\') != null))
    {
        return error.ShaderPathOutsideLogicalRoot;
    }

    const normalized = try allocator.dupe(u8, logical.bytes);
    if (logical.allow_native_separators) {
        std.mem.replaceScalar(u8, normalized, '\\', '/');
    }
    return normalized;
}

fn validateWithinLogicalRoot(allocator: std.mem.Allocator, paths: []const []const u8) !void {
    for (paths) |path| try validatePortableRelativePath(path);

    const resolved = try std.fs.path.resolve(allocator, paths);
    defer allocator.free(resolved);

    if (resolved.len == 0 or std.fs.path.isAbsolute(resolved) or escapesLogicalRoot(resolved)) {
        return error.ShaderPathOutsideLogicalRoot;
    }
}

fn validatePortableRelativePath(path: []const u8) !void {
    if (std.fs.path.getWin32PathType(u8, path) != .relative or
        std.fs.path.isAbsolutePosix(path) or
        std.mem.indexOfScalar(u8, path, '\\') != null)
    {
        return error.ShaderPathOutsideLogicalRoot;
    }
}

fn escapesLogicalRoot(path: []const u8) bool {
    if (std.mem.eql(u8, path, "..")) return true;
    return std.mem.startsWith(u8, path, "../") or std.mem.startsWith(u8, path, "..\\");
}

test "repository manifest and parent-relative sources remain inside their owner root" {
    const path: std.Build.LazyPath = .{ .cwd_relative = "shaders/manifest.json" };
    try validateManifestPath(std.testing.allocator, path);
    try validateSourcePath(std.testing.allocator, path, "../examples/triangle/shaders/triangle.slang");
}

test "manifest cannot escape its lazy path logical root" {
    const path: std.Build.LazyPath = .{ .cwd_relative = "../manifest.json" };
    try std.testing.expectError(
        error.ShaderPathOutsideLogicalRoot,
        validateManifestPath(std.testing.allocator, path),
    );
}

test "scalar manifest rejects drive-relative and backslash paths on every host" {
    const drive_relative: std.Build.LazyPath = .{ .cwd_relative = "C:manifest.json" };
    try std.testing.expectError(
        error.ShaderPathOutsideLogicalRoot,
        validateManifestPath(std.testing.allocator, drive_relative),
    );

    const backslash_relative: std.Build.LazyPath = .{ .cwd_relative = "shaders\\manifest.json" };
    try std.testing.expectError(
        error.ShaderPathOutsideLogicalRoot,
        validateManifestPath(std.testing.allocator, backslash_relative),
    );
}

test "root-owned manifest accepts Zig-normalized native separators" {
    const path: std.Build.LazyPath = .{ .src_path = .{
        .owner = undefined,
        .sub_path = "shaders\\manifest.json",
    } };
    try validateManifestPath(std.testing.allocator, path);

    const escaping_path: std.Build.LazyPath = .{ .src_path = .{
        .owner = undefined,
        .sub_path = "..\\manifest.json",
    } };
    try std.testing.expectError(
        error.ShaderPathOutsideLogicalRoot,
        validateManifestPath(std.testing.allocator, escaping_path),
    );
}

test "dependency manifest accepts Zig-normalized native separators" {
    const path: std.Build.LazyPath = .{ .dependency = .{
        .dependency = undefined,
        .sub_path = "shaders\\manifest.json",
    } };
    try validateManifestPath(std.testing.allocator, path);
    try validateSourcePath(std.testing.allocator, path, "simple_render.slang");
}

test "dependency manifest native separators cannot escape its logical root" {
    const escaping_manifest: std.Build.LazyPath = .{ .dependency = .{
        .dependency = undefined,
        .sub_path = "..\\manifest.json",
    } };
    try std.testing.expectError(
        error.ShaderPathOutsideLogicalRoot,
        validateManifestPath(std.testing.allocator, escaping_manifest),
    );

    const path: std.Build.LazyPath = .{ .dependency = .{
        .dependency = undefined,
        .sub_path = "shaders\\manifest.json",
    } };
    try std.testing.expectError(
        error.ShaderPathOutsideLogicalRoot,
        validateSourcePath(std.testing.allocator, path, "nested\\shader.slang"),
    );
}

test "manifest source can normalize parents while remaining inside the root" {
    const path: std.Build.LazyPath = .{ .cwd_relative = "a/b/manifest.json" };
    try validateSourcePath(std.testing.allocator, path, "../../shader.slang");
}

test "manifest source cannot escape its lazy path logical root" {
    const path: std.Build.LazyPath = .{ .cwd_relative = "shaders/manifest.json" };
    try std.testing.expectError(
        error.ShaderPathOutsideLogicalRoot,
        validateSourcePath(std.testing.allocator, path, "../../outside.slang"),
    );
}

test "generated manifests are rejected before path resolution" {
    const path: std.Build.LazyPath = .{ .generated = .{ .file = undefined } };
    try std.testing.expectError(
        error.GeneratedShaderManifestUnsupported,
        validateManifestPath(std.testing.allocator, path),
    );
}
