const std = @import("std");

pub fn validateManifestPath(allocator: std.mem.Allocator, manifest_path: std.Build.LazyPath) !void {
    const sub_path = try logicalSubPath(manifest_path);
    try validateWithinLogicalRoot(allocator, &.{sub_path});
}

pub fn validateSourcePath(
    allocator: std.mem.Allocator,
    manifest_path: std.Build.LazyPath,
    source: []const u8,
) !void {
    const manifest_sub_path = try logicalSubPath(manifest_path);
    const manifest_dir = std.fs.path.dirname(manifest_sub_path) orelse "";
    try validateWithinLogicalRoot(allocator, &.{ manifest_dir, source });
}

fn logicalSubPath(path: std.Build.LazyPath) ![]const u8 {
    return switch (path) {
        .src_path => |src| src.sub_path,
        // Scalar -D paths are relative to the build runner's working directory,
        // which is their logical root for this contract.
        .cwd_relative => |sub_path| sub_path,
        .dependency => |dependency| dependency.sub_path,
        .generated => error.GeneratedShaderManifestUnsupported,
    };
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

test "manifest rejects drive-relative and backslash paths on every host" {
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
