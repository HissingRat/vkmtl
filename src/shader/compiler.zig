const std = @import("std");
const builtin = @import("builtin");
const core = @import("../core.zig");
const artifact_loader = @import("artifact.zig");

const CFile = opaque {};

extern fn fopen(path: [*:0]const u8, mode: [*:0]const u8) ?*CFile;
extern fn fclose(file: *CFile) c_int;
extern fn fwrite(buffer: [*]const u8, size: usize, count: usize, file: *CFile) usize;
extern fn system(command: [*:0]const u8) c_int;
extern fn readlink(path: [*:0]const u8, buffer: [*]u8, buffer_size: usize) isize;
extern fn _NSGetExecutablePath(buffer: [*]u8, buffer_size: *u32) c_int;

const max_hash_file_bytes = 1024;

pub const CompilerOptions = struct {
    slangc_path: []const u8 = "slangc",
    cache_dir: ?[]const u8 = null,
};

pub const RenderShaderOptions = struct {
    vertex_entry: []const u8 = "vs_main",
    fragment_entry: []const u8 = "fs_main",
};

pub const ComputeShaderOptions = struct {
    entry: []const u8 = "cs_main",
};

pub const RenderShaderStages = struct {
    vertex: core.ProgrammableStageDescriptor,
    fragment: core.ProgrammableStageDescriptor,
};

pub const CompiledRenderShader = struct {
    allocator: std.mem.Allocator,
    vertex_spirv_path: []u8,
    fragment_spirv_path: []u8,
    vertex_msl_path: []u8,
    fragment_msl_path: []u8,
    vertex_reflection_path: []u8,
    fragment_reflection_path: []u8,
    vertex_entry: []u8,
    fragment_entry: []u8,

    pub fn deinit(self: *CompiledRenderShader) void {
        const allocator = self.allocator;
        allocator.free(self.vertex_spirv_path);
        allocator.free(self.fragment_spirv_path);
        allocator.free(self.vertex_msl_path);
        allocator.free(self.fragment_msl_path);
        allocator.free(self.vertex_reflection_path);
        allocator.free(self.fragment_reflection_path);
        allocator.free(self.vertex_entry);
        allocator.free(self.fragment_entry);
        self.* = undefined;
    }

    pub fn vertexStageDescriptor(self: CompiledRenderShader, backend: core.Backend) core.ProgrammableStageDescriptor {
        return .{
            .module = .{ .source = self.shaderSource(backend, .vertex) },
            .stage = .vertex,
            .entry_point = self.vertex_entry,
            .reflection = .{ .artifact = .{ .path = self.vertex_reflection_path } },
        };
    }

    pub fn fragmentStageDescriptor(self: CompiledRenderShader, backend: core.Backend) core.ProgrammableStageDescriptor {
        return .{
            .module = .{ .source = self.shaderSource(backend, .fragment) },
            .stage = .fragment,
            .entry_point = self.fragment_entry,
            .reflection = .{ .artifact = .{ .path = self.fragment_reflection_path } },
        };
    }

    pub fn stageDescriptors(self: CompiledRenderShader, backend: core.Backend) RenderShaderStages {
        return .{
            .vertex = self.vertexStageDescriptor(backend),
            .fragment = self.fragmentStageDescriptor(backend),
        };
    }

    fn shaderSource(
        self: CompiledRenderShader,
        backend: core.Backend,
        stage: core.ShaderStage,
    ) core.ShaderSource {
        return switch (backend) {
            .vulkan => .{ .artifact = .{
                .path = switch (stage) {
                    .vertex => self.vertex_spirv_path,
                    .fragment => self.fragment_spirv_path,
                    .compute => unreachable,
                },
                .language = .spirv,
            } },
            .metal => .{ .artifact = .{
                .path = switch (stage) {
                    .vertex => self.vertex_msl_path,
                    .fragment => self.fragment_msl_path,
                    .compute => unreachable,
                },
                .language = .msl,
            } },
        };
    }
};

pub const CompiledComputeShader = struct {
    allocator: std.mem.Allocator,
    spirv_path: []u8,
    msl_path: []u8,
    reflection_path: []u8,
    entry: []u8,

    pub fn deinit(self: *CompiledComputeShader) void {
        const allocator = self.allocator;
        allocator.free(self.spirv_path);
        allocator.free(self.msl_path);
        allocator.free(self.reflection_path);
        allocator.free(self.entry);
        self.* = undefined;
    }

    pub fn stageDescriptor(self: CompiledComputeShader, backend: core.Backend) core.ProgrammableStageDescriptor {
        return .{
            .module = .{ .source = switch (backend) {
                .vulkan => .{ .artifact = .{ .path = self.spirv_path, .language = .spirv } },
                .metal => .{ .artifact = .{ .path = self.msl_path, .language = .msl } },
            } },
            .stage = .compute,
            .entry_point = self.entry,
            .reflection = .{ .artifact = .{ .path = self.reflection_path } },
        };
    }
};

pub fn compileRenderShader(
    allocator: std.mem.Allocator,
    name: []const u8,
    source: []const u8,
    options: RenderShaderOptions,
    compiler_options: CompilerOptions,
) !CompiledRenderShader {
    try validateShaderName(name);

    const shader_dir = try shaderCacheDir(allocator, compiler_options.cache_dir, name);
    defer allocator.free(shader_dir);

    const source_path = try std.fs.path.join(allocator, &.{ shader_dir, "source.slang" });
    defer allocator.free(source_path);
    const hash_path = try std.fs.path.join(allocator, &.{ shader_dir, "hash" });
    defer allocator.free(hash_path);

    var result = CompiledRenderShader{
        .allocator = allocator,
        .vertex_spirv_path = try std.fs.path.join(allocator, &.{ shader_dir, "vert.spv" }),
        .fragment_spirv_path = try std.fs.path.join(allocator, &.{ shader_dir, "frag.spv" }),
        .vertex_msl_path = try std.fs.path.join(allocator, &.{ shader_dir, "vert.msl" }),
        .fragment_msl_path = try std.fs.path.join(allocator, &.{ shader_dir, "frag.msl" }),
        .vertex_reflection_path = try std.fs.path.join(allocator, &.{ shader_dir, "vert.reflect.json" }),
        .fragment_reflection_path = try std.fs.path.join(allocator, &.{ shader_dir, "frag.reflect.json" }),
        .vertex_entry = try allocator.dupe(u8, options.vertex_entry),
        .fragment_entry = try allocator.dupe(u8, options.fragment_entry),
    };
    errdefer result.deinit();

    const source_hash = sourceHash(source);
    if (try cacheHit(allocator, hash_path, source_hash, &.{
        result.vertex_spirv_path,
        result.fragment_spirv_path,
        result.vertex_msl_path,
        result.fragment_msl_path,
        result.vertex_reflection_path,
        result.fragment_reflection_path,
    })) {
        std.debug.print("using cached slang shader: {s}\n", .{name});
        return result;
    }

    std.debug.print("compiling slang shader: {s}\n", .{name});
    try makeDirPath(allocator, shader_dir);
    try writeFile(allocator, source_path, source);

    try runSlang(allocator, compiler_options.slangc_path, source_path, .vertex, options.vertex_entry, .spirv, result.vertex_spirv_path);
    try runSlang(allocator, compiler_options.slangc_path, source_path, .fragment, options.fragment_entry, .spirv, result.fragment_spirv_path);
    try runSlang(allocator, compiler_options.slangc_path, source_path, .vertex, options.vertex_entry, .msl, result.vertex_msl_path);
    try runSlang(allocator, compiler_options.slangc_path, source_path, .fragment, options.fragment_entry, .msl, result.fragment_msl_path);

    var reflection = try ReflectionModel.parse(allocator, source);
    defer reflection.deinit(allocator);
    const vertex_reflection_json = try reflection.renderStageJson(allocator, name, source_path, .vertex, options.vertex_entry);
    defer allocator.free(vertex_reflection_json);
    try writeFile(allocator, result.vertex_reflection_path, vertex_reflection_json);
    const fragment_reflection_json = try reflection.renderStageJson(allocator, name, source_path, .fragment, options.fragment_entry);
    defer allocator.free(fragment_reflection_json);
    try writeFile(allocator, result.fragment_reflection_path, fragment_reflection_json);

    try writeFile(allocator, hash_path, &source_hash);
    return result;
}

pub fn compileComputeShader(
    allocator: std.mem.Allocator,
    name: []const u8,
    source: []const u8,
    options: ComputeShaderOptions,
    compiler_options: CompilerOptions,
) !CompiledComputeShader {
    try validateShaderName(name);

    const shader_dir = try shaderCacheDir(allocator, compiler_options.cache_dir, name);
    defer allocator.free(shader_dir);

    const source_path = try std.fs.path.join(allocator, &.{ shader_dir, "source.slang" });
    defer allocator.free(source_path);
    const hash_path = try std.fs.path.join(allocator, &.{ shader_dir, "hash" });
    defer allocator.free(hash_path);

    var result = CompiledComputeShader{
        .allocator = allocator,
        .spirv_path = try std.fs.path.join(allocator, &.{ shader_dir, "compute.spv" }),
        .msl_path = try std.fs.path.join(allocator, &.{ shader_dir, "compute.msl" }),
        .reflection_path = try std.fs.path.join(allocator, &.{ shader_dir, "compute.reflect.json" }),
        .entry = try allocator.dupe(u8, options.entry),
    };
    errdefer result.deinit();

    const source_hash = sourceHash(source);
    if (try cacheHit(allocator, hash_path, source_hash, &.{
        result.spirv_path,
        result.msl_path,
        result.reflection_path,
    })) {
        std.debug.print("using cached slang shader: {s}\n", .{name});
        return result;
    }

    std.debug.print("compiling slang shader: {s}\n", .{name});
    try makeDirPath(allocator, shader_dir);
    try writeFile(allocator, source_path, source);

    try runSlang(allocator, compiler_options.slangc_path, source_path, .compute, options.entry, .spirv, result.spirv_path);
    try runSlang(allocator, compiler_options.slangc_path, source_path, .compute, options.entry, .msl, result.msl_path);

    var reflection = try ReflectionModel.parse(allocator, source);
    defer reflection.deinit(allocator);
    const reflection_json = try reflection.renderStageJson(allocator, name, source_path, .compute, options.entry);
    defer allocator.free(reflection_json);
    try writeFile(allocator, result.reflection_path, reflection_json);

    try writeFile(allocator, hash_path, &source_hash);
    return result;
}

fn runSlang(
    allocator: std.mem.Allocator,
    slangc_path: []const u8,
    source_path: []const u8,
    stage: core.ShaderStage,
    entry: []const u8,
    target: core.ShaderSourceLanguage,
    output_path: []const u8,
) !void {
    const profile = switch (stage) {
        .vertex => "vs_6_0",
        .fragment => "ps_6_0",
        .compute => "cs_6_0",
    };
    const target_name = switch (target) {
        .spirv => "spirv",
        .msl => "metal",
        .slang => unreachable,
    };
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);
    try argv.appendSlice(allocator, &.{
        slangc_path,
        source_path,
        "-target",
        target_name,
        "-profile",
        profile,
        "-entry",
        entry,
    });
    if (target == .spirv) try argv.append(allocator, "-fvk-use-entrypoint-name");
    try argv.appendSlice(allocator, &.{ "-o", output_path });

    const command = try shellJoin(allocator, argv.items);
    defer allocator.free(command);

    const command_z = try allocator.dupeZ(u8, command);
    defer allocator.free(command_z);
    if (system(command_z.ptr) != 0) return error.SlangCompileFailed;
}

fn shellJoin(allocator: std.mem.Allocator, argv: []const []const u8) ![]u8 {
    var command: std.ArrayList(u8) = .empty;
    errdefer command.deinit(allocator);

    for (argv) |arg| {
        if (arg.len == 0) continue;
        if (command.items.len != 0) try command.append(allocator, ' ');
        try shellQuoteAppend(allocator, &command, arg);
    }

    return try command.toOwnedSlice(allocator);
}

fn shellQuoteAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    arg: []const u8,
) !void {
    try out.append(allocator, '\'');
    for (arg) |byte| {
        if (byte == '\'') {
            try out.appendSlice(allocator, "'\\''");
        } else {
            try out.append(allocator, byte);
        }
    }
    try out.append(allocator, '\'');
}

fn makeDirPath(allocator: std.mem.Allocator, path: []const u8) !void {
    const command = try shellJoin(allocator, &.{ "mkdir", "-p", path });
    defer allocator.free(command);
    const command_z = try allocator.dupeZ(u8, command);
    defer allocator.free(command_z);
    if (system(command_z.ptr) != 0) return error.CacheDirectoryCreateFailed;
}

fn writeFile(allocator: std.mem.Allocator, path: []const u8, bytes: []const u8) !void {
    const path_z = try allocator.dupeZ(u8, path);
    defer allocator.free(path_z);

    const file = fopen(path_z.ptr, "wb") orelse return error.CacheFileWriteFailed;
    defer _ = fclose(file);

    if (bytes.len != 0 and fwrite(bytes.ptr, 1, bytes.len, file) != bytes.len) {
        return error.CacheFileWriteFailed;
    }
}

fn cacheHit(
    allocator: std.mem.Allocator,
    hash_path: []const u8,
    expected_hash: [64]u8,
    artifact_paths: []const []const u8,
) !bool {
    const hash_bytes = artifact_loader.readFileBytes(allocator, hash_path, max_hash_file_bytes) catch return false;
    defer allocator.free(hash_bytes);
    if (hash_bytes.len < expected_hash.len) return false;
    if (!std.mem.eql(u8, hash_bytes[0..expected_hash.len], expected_hash[0..])) return false;

    for (artifact_paths) |path| {
        if (!fileExists(allocator, path)) return false;
    }
    return true;
}

fn fileExists(allocator: std.mem.Allocator, path: []const u8) bool {
    const path_z = allocator.dupeZ(u8, path) catch return false;
    defer allocator.free(path_z);
    const file = fopen(path_z.ptr, "rb") orelse return false;
    _ = fclose(file);
    return true;
}

fn shaderCacheDir(
    allocator: std.mem.Allocator,
    configured_cache_dir: ?[]const u8,
    shader_name: []const u8,
) ![]u8 {
    if (configured_cache_dir) |cache_dir| {
        return try std.fs.path.join(allocator, &.{ cache_dir, shader_name });
    }

    const exe_dir = try executableDir(allocator);
    defer allocator.free(exe_dir);
    return try std.fs.path.join(allocator, &.{ exe_dir, "vkmtl-cache", shader_name });
}

fn executableDir(allocator: std.mem.Allocator) ![]u8 {
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const path_len: usize = switch (builtin.os.tag) {
        .macos => blk: {
            var size: u32 = @intCast(buffer.len);
            if (_NSGetExecutablePath(buffer[0..].ptr, &size) != 0) return error.ExecutablePathTooLong;
            break :blk std.mem.indexOfScalar(u8, buffer[0..], 0) orelse @as(usize, @intCast(size));
        },
        .linux => blk: {
            const len = readlink("/proc/self/exe", buffer[0..].ptr, buffer.len);
            if (len < 0) return error.ExecutablePathReadFailed;
            break :blk @intCast(len);
        },
        else => return try allocator.dupe(u8, "."),
    };
    return try allocator.dupe(u8, std.fs.path.dirname(buffer[0..path_len]) orelse ".");
}

fn sourceHash(source: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &digest, .{});

    var out: [64]u8 = undefined;
    const alphabet = "0123456789abcdef";
    for (digest, 0..) |byte, index| {
        out[index * 2] = alphabet[byte >> 4];
        out[index * 2 + 1] = alphabet[byte & 0x0f];
    }
    return out;
}

fn validateShaderName(name: []const u8) !void {
    if (name.len == 0) return error.InvalidShaderName;
    for (name) |byte| {
        switch (byte) {
            'a'...'z', 'A'...'Z', '0'...'9', '_', '-', '.' => {},
            else => return error.InvalidShaderName,
        }
    }
}

const ReflectionModel = struct {
    source: []const u8,
    structs: std.ArrayList(StructInfo) = .empty,
    resources: std.ArrayList(ResourceInfo) = .empty,
    threadgroup_size: ?[3]u32 = null,

    fn parse(allocator: std.mem.Allocator, source: []const u8) !ReflectionModel {
        var model = ReflectionModel{ .source = source };
        errdefer model.deinit(allocator);

        try model.parseStructs(allocator);
        try model.parseResources(allocator);
        model.threadgroup_size = parseThreadgroupSize(source);
        return model;
    }

    fn deinit(self: *ReflectionModel, allocator: std.mem.Allocator) void {
        for (self.structs.items) |*item| item.deinit(allocator);
        self.structs.deinit(allocator);
        for (self.resources.items) |*item| item.deinit(allocator);
        self.resources.deinit(allocator);
    }

    fn renderStageJson(
        self: ReflectionModel,
        allocator: std.mem.Allocator,
        shader_name: []const u8,
        source_path: []const u8,
        stage: core.ShaderStage,
        entry: []const u8,
    ) ![]const u8 {
        var json: std.ArrayList(u8) = .empty;
        errdefer json.deinit(allocator);
        try json.print(
            allocator,
            "{{\n  \"schema_version\": {},\n  \"name\": \"{s}\",\n  \"source\": \"{s}\",\n  \"source_language\": \"slang\",\n  \"stage\": \"{s}\",\n  \"entry_point\": \"{s}\",\n",
            .{ core.shader_reflection_schema_version, shader_name, source_path, stageName(stage), entry },
        );

        if (stage == .compute) {
            if (self.threadgroup_size) |size| {
                try json.print(allocator, "  \"threadgroup_size\": [{}, {}, {}],\n", .{ size[0], size[1], size[2] });
            }
        }

        try self.writeVertexInputsJson(allocator, &json, stage, entry);
        try self.writeBindGroupsJson(allocator, &json, stage, entry);
        try json.appendSlice(allocator, "\n}\n");
        return try json.toOwnedSlice(allocator);
    }

    fn writeVertexInputsJson(
        self: ReflectionModel,
        allocator: std.mem.Allocator,
        json: *std.ArrayList(u8),
        stage: core.ShaderStage,
        entry: []const u8,
    ) !void {
        try json.appendSlice(allocator, "  \"vertex_inputs\": [");
        if (stage == .vertex) {
            if (self.entryInputStruct(entry)) |input_struct| {
                for (input_struct.fields.items, 0..) |field, index| {
                    if (index == 0) try json.append(allocator, '\n') else try json.appendSlice(allocator, ",\n");
                    try json.print(
                        allocator,
                        "    {{\n      \"location\": {},\n      \"semantic\": \"{s}\",\n      \"format\": \"{s}\",\n      \"offset\": {}\n    }}",
                        .{ index, field.semantic, vertexFormatName(field.format), field.offset },
                    );
                }
                if (input_struct.fields.items.len != 0) try json.appendSlice(allocator, "\n  ");
            }
        }
        try json.appendSlice(allocator, "],\n");
    }

    fn writeBindGroupsJson(
        self: ReflectionModel,
        allocator: std.mem.Allocator,
        json: *std.ArrayList(u8),
        stage: core.ShaderStage,
        entry: []const u8,
    ) !void {
        var reflected: std.ArrayList(ResourceInfo) = .empty;
        defer reflected.deinit(allocator);

        const body = self.entryBody(entry) orelse "";
        for (self.resources.items) |resource| {
            if (std.mem.indexOf(u8, body, resource.name) != null) {
                try reflected.append(allocator, resource);
            }
        }

        try json.appendSlice(allocator, "  \"bind_groups\": [");
        if (reflected.items.len != 0) {
            std.sort.block(ResourceInfo, reflected.items, {}, resourceLessThan);
            var current_group: ?u32 = null;
            var first_group = true;
            for (reflected.items, 0..) |resource, index| {
                if (current_group == null or current_group.? != resource.group) {
                    if (!first_group) try json.appendSlice(allocator, "\n      ]\n    },");
                    first_group = false;
                    current_group = resource.group;
                    try json.print(
                        allocator,
                        "\n    {{\n      \"index\": {},\n      \"bindings\": [",
                        .{resource.group},
                    );
                } else {
                    try json.append(allocator, ',');
                }
                _ = index;
                try json.print(
                    allocator,
                    "\n        {{\n          \"binding\": {},\n          \"kind\": \"{s}\",\n          \"visibility\": \"{s}\"\n        }}",
                    .{ resource.binding, bindingKindName(resource.kind), stageName(stage) },
                );
            }
            try json.appendSlice(allocator, "\n      ]\n    }\n  ");
        }
        try json.append(allocator, ']');
    }

    fn entryInputStruct(self: ReflectionModel, entry: []const u8) ?StructInfo {
        const signature = self.entrySignature(entry) orelse return null;
        const open_paren = std.mem.indexOfScalar(u8, signature, '(') orelse return null;
        const close_paren = std.mem.lastIndexOfScalar(u8, signature, ')') orelse return null;
        const params = std.mem.trim(u8, signature[open_paren + 1 .. close_paren], " \t\r\n");
        if (params.len == 0) return null;
        const struct_name = firstToken(params) orelse return null;
        for (self.structs.items) |item| {
            if (std.mem.eql(u8, item.name, struct_name)) return item;
        }
        return null;
    }

    fn entryBody(self: ReflectionModel, entry: []const u8) ?[]const u8 {
        const signature_start = self.entrySignatureStart(entry) orelse return null;
        const open_brace = std.mem.indexOfScalarPos(u8, self.source, signature_start, '{') orelse return null;
        var depth: usize = 0;
        var index = open_brace;
        while (index < self.source.len) : (index += 1) {
            switch (self.source[index]) {
                '{' => depth += 1,
                '}' => {
                    depth -= 1;
                    if (depth == 0) return self.source[open_brace + 1 .. index];
                },
                else => {},
            }
        }
        return null;
    }

    fn entrySignature(self: ReflectionModel, entry: []const u8) ?[]const u8 {
        const start = self.entrySignatureStart(entry) orelse return null;
        const open_brace = std.mem.indexOfScalarPos(u8, self.source, start, '{') orelse return null;
        return self.source[start..open_brace];
    }

    fn entrySignatureStart(self: ReflectionModel, entry: []const u8) ?usize {
        const entry_index = std.mem.indexOf(u8, self.source, entry) orelse return null;
        return lineStart(self.source, entry_index);
    }

    fn parseStructs(self: *ReflectionModel, allocator: std.mem.Allocator) !void {
        var search_start: usize = 0;
        while (std.mem.indexOfPos(u8, self.source, search_start, "struct ")) |struct_pos| {
            const name_start = struct_pos + "struct ".len;
            const name_end = skipIdentifier(self.source, name_start);
            const name = std.mem.trim(u8, self.source[name_start..name_end], " \t\r\n");
            const open_brace = std.mem.indexOfScalarPos(u8, self.source, name_end, '{') orelse break;
            const close_brace = matchingBrace(self.source, open_brace) orelse break;

            var info = StructInfo{ .name = try allocator.dupe(u8, name) };
            errdefer info.deinit(allocator);
            try parseStructFields(allocator, self.source[open_brace + 1 .. close_brace], &info);
            try self.structs.append(allocator, info);
            search_start = close_brace + 1;
        }
    }

    fn parseResources(self: *ReflectionModel, allocator: std.mem.Allocator) !void {
        var pending_binding: ?[2]u32 = null;
        var lines = std.mem.splitScalar(u8, self.source, '\n');
        while (lines.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, " \t\r\n");
            if (std.mem.indexOf(u8, line, "vk::binding(")) |binding_pos| {
                pending_binding = parseBindingAnnotation(line[binding_pos..]);
                continue;
            }
            if (pending_binding) |binding| {
                if (parseResourceLine(line)) |parsed| {
                    try self.resources.append(allocator, .{
                        .name = try allocator.dupe(u8, parsed.name),
                        .binding = binding[0],
                        .group = binding[1],
                        .kind = parsed.kind,
                    });
                    pending_binding = null;
                }
            }
        }
    }
};

const StructInfo = struct {
    name: []u8,
    fields: std.ArrayList(VertexField) = .empty,

    fn deinit(self: *StructInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.fields.items) |field| allocator.free(field.semantic);
        self.fields.deinit(allocator);
    }
};

const VertexField = struct {
    format: core.VertexFormat,
    semantic: []u8,
    offset: u32,
};

const ResourceInfo = struct {
    name: []u8,
    binding: u32,
    group: u32,
    kind: core.BindingResourceKind,

    fn deinit(self: *ResourceInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

fn parseStructFields(
    allocator: std.mem.Allocator,
    body: []const u8,
    info: *StructInfo,
) !void {
    var offset: u32 = 0;
    var lines = std.mem.splitScalar(u8, body, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");
        if (line.len == 0 or std.mem.indexOfScalar(u8, line, ':') == null) continue;
        const semicolon = std.mem.indexOfScalar(u8, line, ';') orelse continue;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const before_colon = std.mem.trim(u8, line[0..colon], " \t\r\n");
        const semantic = std.mem.trim(u8, line[colon + 1 .. semicolon], " \t\r\n");
        if (std.mem.eql(u8, semantic, "SV_Position") or std.mem.startsWith(u8, semantic, "SV_")) continue;

        const field_type = firstToken(before_colon) orelse continue;
        const format = parseFieldFormat(field_type) orelse continue;
        try info.fields.append(allocator, .{
            .format = format,
            .semantic = try allocator.dupe(u8, semantic),
            .offset = offset,
        });
        offset += vertexFormatSize(format);
    }
}

fn parseResourceLine(line: []const u8) ?struct { name: []const u8, kind: core.BindingResourceKind } {
    const kind: core.BindingResourceKind = if (std.mem.startsWith(u8, line, "ConstantBuffer"))
        .uniform_buffer
    else if (std.mem.startsWith(u8, line, "Texture2D"))
        .sampled_texture
    else if (std.mem.startsWith(u8, line, "SamplerState"))
        .sampler
    else if (std.mem.startsWith(u8, line, "RWTexture2D"))
        .storage_texture
    else if (std.mem.startsWith(u8, line, "RWStructuredBuffer"))
        .storage_buffer
    else
        return null;

    const before_register = if (std.mem.indexOfScalar(u8, line, ':')) |colon| line[0..colon] else line;
    const name = lastToken(before_register) orelse return null;
    return .{ .name = name, .kind = kind };
}

fn parseBindingAnnotation(text: []const u8) ?[2]u32 {
    const open = std.mem.indexOfScalar(u8, text, '(') orelse return null;
    const close = std.mem.indexOfScalarPos(u8, text, open, ')') orelse return null;
    const inside = text[open + 1 .. close];
    const comma = std.mem.indexOfScalar(u8, inside, ',') orelse return null;
    return .{
        std.fmt.parseInt(u32, std.mem.trim(u8, inside[0..comma], " \t\r\n"), 10) catch return null,
        std.fmt.parseInt(u32, std.mem.trim(u8, inside[comma + 1 ..], " \t\r\n"), 10) catch return null,
    };
}

fn parseThreadgroupSize(source: []const u8) ?[3]u32 {
    const marker = "[numthreads(";
    const start = std.mem.indexOf(u8, source, marker) orelse return null;
    const values_start = start + marker.len;
    const close = std.mem.indexOfScalarPos(u8, source, values_start, ')') orelse return null;
    const values = source[values_start..close];
    var iter = std.mem.splitScalar(u8, values, ',');
    return .{
        std.fmt.parseInt(u32, std.mem.trim(u8, iter.next() orelse return null, " \t\r\n"), 10) catch return null,
        std.fmt.parseInt(u32, std.mem.trim(u8, iter.next() orelse return null, " \t\r\n"), 10) catch return null,
        std.fmt.parseInt(u32, std.mem.trim(u8, iter.next() orelse return null, " \t\r\n"), 10) catch return null,
    };
}

fn resourceLessThan(_: void, lhs: ResourceInfo, rhs: ResourceInfo) bool {
    if (lhs.group != rhs.group) return lhs.group < rhs.group;
    return lhs.binding < rhs.binding;
}

fn lineStart(source: []const u8, index: usize) usize {
    var current = index;
    while (current != 0 and source[current - 1] != '\n') current -= 1;
    return current;
}

fn matchingBrace(source: []const u8, open_brace: usize) ?usize {
    var depth: usize = 0;
    var index = open_brace;
    while (index < source.len) : (index += 1) {
        switch (source[index]) {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if (depth == 0) return index;
            },
            else => {},
        }
    }
    return null;
}

fn skipIdentifier(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len) : (index += 1) {
        switch (source[index]) {
            'a'...'z', 'A'...'Z', '0'...'9', '_' => {},
            else => break,
        }
    }
    return index;
}

fn firstToken(text: []const u8) ?[]const u8 {
    var iter = std.mem.tokenizeAny(u8, text, " \t\r\n");
    return iter.next();
}

fn lastToken(text: []const u8) ?[]const u8 {
    var result: ?[]const u8 = null;
    var iter = std.mem.tokenizeAny(u8, text, " \t\r\n");
    while (iter.next()) |token| result = token;
    return result;
}

fn parseFieldFormat(name: []const u8) ?core.VertexFormat {
    if (std.mem.eql(u8, name, "float")) return .float32;
    if (std.mem.eql(u8, name, "float2")) return .float32x2;
    if (std.mem.eql(u8, name, "float3")) return .float32x3;
    if (std.mem.eql(u8, name, "float4")) return .float32x4;
    return null;
}

fn vertexFormatSize(format: core.VertexFormat) u32 {
    return switch (format) {
        .float32 => 4,
        .float32x2 => 8,
        .float32x3 => 12,
        .float32x4 => 16,
    };
}

fn vertexFormatName(format: core.VertexFormat) []const u8 {
    return switch (format) {
        .float32 => "float32",
        .float32x2 => "float32x2",
        .float32x3 => "float32x3",
        .float32x4 => "float32x4",
    };
}

fn stageName(stage: core.ShaderStage) []const u8 {
    return switch (stage) {
        .vertex => "vertex",
        .fragment => "fragment",
        .compute => "compute",
    };
}

fn bindingKindName(kind: core.BindingResourceKind) []const u8 {
    return switch (kind) {
        .uniform_buffer => "uniform_buffer",
        .storage_buffer => "storage_buffer",
        .storage_texture => "storage_texture",
        .sampled_texture => "sampled_texture",
        .sampler => "sampler",
    };
}

test "runtime reflection parser reads rainbow cube shader shape" {
    const source = @embedFile("../../examples/rainbow_cube/shaders/rainbow_cube.slang");
    var model = try ReflectionModel.parse(std.testing.allocator, source);
    defer model.deinit(std.testing.allocator);

    const input_struct = model.entryInputStruct("vs_main") orelse return error.MissingVertexInputReflection;
    try std.testing.expectEqual(@as(usize, 3), input_struct.fields.items.len);
    try expectVertexField(input_struct.fields.items[0], .float32x3, "POSITION0", 0);
    try expectVertexField(input_struct.fields.items[1], .float32x2, "TEXCOORD0", 12);
    try expectVertexField(input_struct.fields.items[2], .float32x3, "COLOR0", 20);

    const vertex_json = try model.renderStageJson(std.testing.allocator, "rainbow_cube", "rainbow_cube.slang", .vertex, "vs_main");
    defer std.testing.allocator.free(vertex_json);
    try expectContains(vertex_json, "\"kind\": \"uniform_buffer\"");
    try expectContains(vertex_json, "\"visibility\": \"vertex\"");

    const fragment_json = try model.renderStageJson(std.testing.allocator, "rainbow_cube", "rainbow_cube.slang", .fragment, "fs_main");
    defer std.testing.allocator.free(fragment_json);
    try expectContains(fragment_json, "\"kind\": \"sampled_texture\"");
    try expectContains(fragment_json, "\"kind\": \"sampler\"");
    try expectContains(fragment_json, "\"visibility\": \"fragment\"");
}

test "runtime reflection parser reads compute shader shape" {
    const source = @embedFile("../../examples/compute_readback/shaders/compute_readback.slang");
    var model = try ReflectionModel.parse(std.testing.allocator, source);
    defer model.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?[3]u32, .{ 4, 1, 1 }), model.threadgroup_size);
    try std.testing.expectEqual(@as(usize, 2), model.resources.items.len);
    try expectResource(model.resources.items[0], "output_texture", 0, 0, .storage_texture);
    try expectResource(model.resources.items[1], "output_values", 1, 0, .storage_buffer);

    const compute_json = try model.renderStageJson(std.testing.allocator, "compute_readback", "compute_readback.slang", .compute, "cs_main");
    defer std.testing.allocator.free(compute_json);
    try expectContains(compute_json, "\"threadgroup_size\": [4, 1, 1]");
    try expectContains(compute_json, "\"kind\": \"storage_texture\"");
    try expectContains(compute_json, "\"kind\": \"storage_buffer\"");
    try expectContains(compute_json, "\"visibility\": \"compute\"");
}

test "compiled render shader exposes paired stage descriptors" {
    const allocator = std.testing.allocator;
    var shader = CompiledRenderShader{
        .allocator = allocator,
        .vertex_spirv_path = try allocator.dupe(u8, "cache/demo/vert.spv"),
        .fragment_spirv_path = try allocator.dupe(u8, "cache/demo/frag.spv"),
        .vertex_msl_path = try allocator.dupe(u8, "cache/demo/vert.msl"),
        .fragment_msl_path = try allocator.dupe(u8, "cache/demo/frag.msl"),
        .vertex_reflection_path = try allocator.dupe(u8, "cache/demo/vert.reflect.json"),
        .fragment_reflection_path = try allocator.dupe(u8, "cache/demo/frag.reflect.json"),
        .vertex_entry = try allocator.dupe(u8, "vs_main"),
        .fragment_entry = try allocator.dupe(u8, "fs_main"),
    };
    defer shader.deinit();

    const stages = shader.stageDescriptors(.metal);
    try std.testing.expectEqual(core.ShaderStage.vertex, stages.vertex.stage);
    try std.testing.expectEqual(core.ShaderStage.fragment, stages.fragment.stage);
    try expectArtifact(stages.vertex.module.source, .msl, "cache/demo/vert.msl");
    try expectArtifact(stages.fragment.module.source, .msl, "cache/demo/frag.msl");
    try expectReflectionArtifact(stages.vertex.reflection, "cache/demo/vert.reflect.json");
    try expectReflectionArtifact(stages.fragment.reflection, "cache/demo/frag.reflect.json");
}

fn expectVertexField(
    actual: VertexField,
    expected_format: core.VertexFormat,
    expected_semantic: []const u8,
    expected_offset: u32,
) !void {
    try std.testing.expectEqual(expected_format, actual.format);
    try std.testing.expectEqualStrings(expected_semantic, actual.semantic);
    try std.testing.expectEqual(expected_offset, actual.offset);
}

fn expectResource(
    actual: ResourceInfo,
    expected_name: []const u8,
    expected_binding: u32,
    expected_group: u32,
    expected_kind: core.BindingResourceKind,
) !void {
    try std.testing.expectEqualStrings(expected_name, actual.name);
    try std.testing.expectEqual(expected_binding, actual.binding);
    try std.testing.expectEqual(expected_group, actual.group);
    try std.testing.expectEqual(expected_kind, actual.kind);
}

fn expectArtifact(
    source: core.ShaderSource,
    language: core.ShaderSourceLanguage,
    path: []const u8,
) !void {
    switch (source) {
        .artifact => |artifact| {
            try std.testing.expectEqual(language, artifact.language);
            try std.testing.expectEqualStrings(path, artifact.path);
        },
        else => return error.UnexpectedShaderSource,
    }
}

fn expectReflectionArtifact(
    source: core.ShaderReflectionSource,
    path: []const u8,
) !void {
    switch (source) {
        .artifact => |artifact| try std.testing.expectEqualStrings(path, artifact.path),
        else => return error.UnexpectedShaderReflectionSource,
    }
}

fn expectContains(haystack: []const u8, needle: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, haystack, needle) != null);
}
