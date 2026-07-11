const std = @import("std");

const DepTokenizer = std.Build.Cache.DepTokenizer;

pub fn appendPrerequisites(
    allocator: std.mem.Allocator,
    raw_depfile: []const u8,
    cwd: []const u8,
    output: *std.ArrayList(u8),
) !void {
    var resolved: std.ArrayList(u8) = .empty;
    defer resolved.deinit(allocator);

    var tokenizer: DepTokenizer = .{ .bytes = raw_depfile };
    while (tokenizer.next()) |token| {
        const prerequisite = switch (token) {
            .target, .target_must_resolve => continue,
            .prereq => |path| path,
            .prereq_must_resolve => path: {
                resolved.clearRetainingCapacity();
                try token.resolve(allocator, &resolved);
                break :path resolved.items;
            },
            else => return error.InvalidSlangDepfile,
        };
        try appendPrerequisite(allocator, cwd, prerequisite, output);
    }
}

fn appendPrerequisite(
    allocator: std.mem.Allocator,
    cwd: []const u8,
    path: []const u8,
    output: *std.ArrayList(u8),
) !void {
    if (path.len == 0) return error.InvalidSlangDependencyPath;
    const relative = try relativeToCwd(allocator, cwd, path);
    defer allocator.free(relative);

    try output.append(allocator, ' ');
    for (relative) |byte| {
        switch (byte) {
            '\\' => try output.append(allocator, '/'),
            ' ', '#' => {
                try output.append(allocator, '\\');
                try output.append(allocator, byte);
            },
            '$' => try output.appendSlice(allocator, "$$"),
            '\t', '\r', '\n', '"' => return error.InvalidSlangDependencyPath,
            else => try output.append(allocator, byte),
        }
    }
}

fn relativeToCwd(allocator: std.mem.Allocator, cwd: []const u8, path: []const u8) ![]u8 {
    return switch (std.fs.path.getWin32PathType(u8, path)) {
        .relative => if (std.fs.path.isAbsolutePosix(path))
            std.fs.path.relativePosix(allocator, cwd, cwd, path)
        else
            allocator.dupe(u8, path),
        else => std.fs.path.relativeWindows(allocator, cwd, null, cwd, path),
    };
}

test "Slang depfile prerequisites become relative portable paths" {
    const raw =
        \\D:\project\out.spv: D:\project\shaders\main.slang D:\project\shaders\include.slang
    ;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);

    try appendPrerequisites(std.testing.allocator, raw, "D:\\project", &output);
    try std.testing.expectEqualStrings(
        " shaders/main.slang shaders/include.slang",
        output.items,
    );
}

test "Slang depfile prerequisite escaping survives Zig depfile parsing" {
    const raw =
        \\C:\out.spv: "C:\My Project\shader #1$$.slang"
    ;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);

    try appendPrerequisites(std.testing.allocator, raw, "C:\\", &output);
    try std.testing.expectEqualStrings(
        " My\\ Project/shader\\ \\#1$$$$.slang",
        output.items,
    );

    const merged = try std.fmt.allocPrint(
        std.testing.allocator,
        "vkmtl-precompiled-shaders:{s}\n",
        .{output.items},
    );
    defer std.testing.allocator.free(merged);

    var tokenizer: DepTokenizer = .{ .bytes = merged };
    var prerequisites: usize = 0;
    while (tokenizer.next()) |token| switch (token) {
        .target, .target_must_resolve => {},
        .prereq, .prereq_must_resolve => prerequisites += 1,
        else => return error.InvalidMergedDepfile,
    };
    try std.testing.expectEqual(@as(usize, 1), prerequisites);
}

test "POSIX Slang depfile prerequisites are relative to the build cwd" {
    const raw =
        \\/work/cache/out.spv: /work/project/shaders/main.slang /work/project/shaders/include.slang
    ;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);

    try appendPrerequisites(std.testing.allocator, raw, "/work/project", &output);
    try std.testing.expectEqualStrings(
        " shaders/main.slang shaders/include.slang",
        output.items,
    );
}
