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
        const encoded_prerequisite = switch (token) {
            .target, .target_must_resolve => continue,
            .prereq, .prereq_must_resolve => |path| path,
            else => return error.InvalidSlangDepfile,
        };
        resolved.clearRetainingCapacity();
        try resolveSlangPrerequisite(allocator, encoded_prerequisite, &resolved);
        try appendPrerequisite(allocator, cwd, resolved.items, output);
    }
}

fn resolveSlangPrerequisite(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    output: *std.ArrayList(u8),
) !void {
    // Slang's Make depfiles escape drive colons and every Windows separator.
    var index: usize = 0;
    while (index < encoded.len) {
        const byte = encoded[index];
        if (byte == '$' and index + 1 < encoded.len and encoded[index + 1] == '$') {
            try output.append(allocator, '$');
            index += 2;
            continue;
        }
        if (byte != '\\' or index + 1 == encoded.len) {
            try output.append(allocator, byte);
            index += 1;
            continue;
        }

        const escaped = encoded[index + 1];
        switch (escaped) {
            ':', '\\', ' ', '#', '[', ']' => {
                try output.append(allocator, escaped);
                index += 2;
            },
            else => {
                // A single backslash is also a normal Windows path separator.
                try output.append(allocator, '\\');
                index += 1;
            },
        }
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

    // Zig's depfile parser returns quoted prerequisites without another escape pass.
    try output.appendSlice(allocator, " \"");
    for (relative) |byte| {
        switch (byte) {
            '\\' => try output.append(allocator, '/'),
            '\t', '\r', '\n', '"' => return error.InvalidSlangDependencyPath,
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
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
        \\.\\.zig-cache\\tmp\\shader\\vert.spv: D\:\\a\\vkmtl\\vkmtl\\examples\\triangle\\shaders\\triangle.slang D\:\\a\\vkmtl\\vkmtl\\examples\\triangle\\shaders\\common.slang
    ;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);

    try appendPrerequisites(std.testing.allocator, raw, "D:\\a\\vkmtl\\vkmtl", &output);
    try std.testing.expectEqualStrings(
        " \"examples/triangle/shaders/triangle.slang\" \"examples/triangle/shaders/common.slang\"",
        output.items,
    );
}

test "Slang depfile prerequisite escaping survives Zig depfile parsing" {
    const raw =
        \\out.spv: C\:\\My\ Project\\shader\ \#1\[debug\]$$.slang
    ;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);

    try appendPrerequisites(std.testing.allocator, raw, "C:\\", &output);
    try std.testing.expectEqualStrings(
        " \"My Project/shader #1[debug]$.slang\"",
        output.items,
    );

    const merged = try std.fmt.allocPrint(
        std.testing.allocator,
        "vkmtl-precompiled-shaders:{s}\n",
        .{output.items},
    );
    defer std.testing.allocator.free(merged);

    var tokenizer: DepTokenizer = .{ .bytes = merged };
    var prerequisite: ?[]const u8 = null;
    while (tokenizer.next()) |token| switch (token) {
        .target, .target_must_resolve => {},
        .prereq => |path| {
            try std.testing.expect(prerequisite == null);
            prerequisite = path;
        },
        .prereq_must_resolve => return error.UnexpectedEscapedMergedPrerequisite,
        else => return error.InvalidMergedDepfile,
    };
    try std.testing.expectEqualStrings(
        "My Project/shader #1[debug]$.slang",
        prerequisite orelse return error.MissingMergedPrerequisite,
    );
}

test "Slang Make escaping decodes Windows prerequisite paths" {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);

    try resolveSlangPrerequisite(
        std.testing.allocator,
        "D\\:\\\\a\\\\vkmtl\\\\shader\\ source\\#1\\[debug\\]$$.slang",
        &output,
    );
    try std.testing.expectEqualStrings(
        "D:\\a\\vkmtl\\shader source#1[debug]$.slang",
        output.items,
    );

    output.clearRetainingCapacity();
    try resolveSlangPrerequisite(
        std.testing.allocator,
        "D:\\a\\vkmtl\\$cache\\ordinary.slang",
        &output,
    );
    try std.testing.expectEqualStrings(
        "D:\\a\\vkmtl\\$cache\\ordinary.slang",
        output.items,
    );
}

test "POSIX Slang depfile prerequisites are relative to the build cwd" {
    const raw =
        \\/work/cache/out.spv: /work/project/shaders/main.slang /work/project/shaders/include.slang
    ;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);

    try appendPrerequisites(std.testing.allocator, raw, "/work/project", &output);
    try std.testing.expectEqualStrings(
        " \"shaders/main.slang\" \"shaders/include.slang\"",
        output.items,
    );
}
