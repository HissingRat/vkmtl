const std = @import("std");

const max_source_bytes = 4 * 1024 * 1024;

const RenderSpec = struct {
    name: []const u8,
    source_path: []const u8,
    vertex_entry: []const u8 = "vs_main",
    fragment_entry: []const u8 = "fs_main",
};

const ComputeSpec = struct {
    name: []const u8,
    source_path: []const u8,
    entry: []const u8 = "cs_main",
};

const RayTracingSpec = struct {
    name: []const u8,
    source_path: []const u8,
    ray_generation_entry: []const u8 = "raygen",
    miss_entry: []const u8 = "miss",
    closest_hit_entry: []const u8 = "closest_hit",
};

const GeneratedRender = struct {
    spec: RenderSpec,
    hash: [64]u8,
};

const GeneratedCompute = struct {
    spec: ComputeSpec,
    hash: [64]u8,
};

const GeneratedRayTracing = struct {
    spec: RayTracingSpec,
    hash: [64]u8,
};

const render_specs = [_]RenderSpec{
    .{ .name = "triangle", .source_path = "examples/triangle/shaders/triangle.slang" },
    .{ .name = "uniform_buffer", .source_path = "examples/uniform_buffer/shaders/uniform_buffer.slang" },
    .{ .name = "sampled_texture", .source_path = "examples/sampled_texture/shaders/sampled_texture.slang" },
    .{ .name = "depth_triangles", .source_path = "examples/depth_triangles/shaders/depth_triangles.slang" },
    .{ .name = "rainbow_cube", .source_path = "examples/rainbow_cube/shaders/rainbow_cube.slang" },
    .{
        .name = "msaa_triangle_msaa",
        .source_path = "examples/msaa_triangle/shaders/msaa_triangle.slang",
        .vertex_entry = "msaa_vs",
        .fragment_entry = "msaa_fs",
    },
    .{
        .name = "msaa_triangle_screen",
        .source_path = "examples/msaa_triangle/shaders/msaa_triangle.slang",
        .vertex_entry = "screen_vs",
        .fragment_entry = "screen_fs",
    },
    .{
        .name = "offscreen_texture_offscreen",
        .source_path = "examples/offscreen_texture/shaders/offscreen_texture.slang",
        .vertex_entry = "offscreen_vs",
        .fragment_entry = "offscreen_fs",
    },
    .{
        .name = "offscreen_texture_screen",
        .source_path = "examples/offscreen_texture/shaders/offscreen_texture.slang",
        .vertex_entry = "screen_vs",
        .fragment_entry = "screen_fs",
    },
};

const compute_specs = [_]ComputeSpec{
    .{ .name = "compute_readback", .source_path = "examples/compute_readback/shaders/compute_readback.slang" },
};

const ray_tracing_specs = [_]RayTracingSpec{
    .{ .name = "ray_traced_scene_rt", .source_path = "examples/ray_traced_scene/shaders/ray_traced_scene_rt.slang" },
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();
    _ = args.next();
    const output_dir = args.next() orelse {
        std.debug.print("usage: vkmtl-precompile-shaders <output-dir> <slangc>\n", .{});
        return error.InvalidArguments;
    };
    const slangc = args.next() orelse {
        std.debug.print("usage: vkmtl-precompile-shaders <output-dir> <slangc>\n", .{});
        return error.InvalidArguments;
    };
    try makeDirPath(output_dir);

    var generated_render: std.ArrayList(GeneratedRender) = .empty;
    defer generated_render.deinit(allocator);
    for (render_specs) |spec| {
        try generated_render.append(allocator, try precompileRender(allocator, io, output_dir, slangc, spec));
    }

    var generated_compute: std.ArrayList(GeneratedCompute) = .empty;
    defer generated_compute.deinit(allocator);
    for (compute_specs) |spec| {
        try generated_compute.append(allocator, try precompileCompute(allocator, io, output_dir, slangc, spec));
    }

    var generated_ray_tracing: std.ArrayList(GeneratedRayTracing) = .empty;
    defer generated_ray_tracing.deinit(allocator);
    for (ray_tracing_specs) |spec| {
        try generated_ray_tracing.append(allocator, try precompileRayTracing(allocator, io, output_dir, slangc, spec));
    }

    try writeGeneratedModule(
        allocator,
        output_dir,
        generated_render.items,
        generated_compute.items,
        generated_ray_tracing.items,
    );
}

fn precompileRender(
    allocator: std.mem.Allocator,
    io: std.Io,
    output_dir: []const u8,
    slangc: []const u8,
    spec: RenderSpec,
) !GeneratedRender {
    std.debug.print("precompiling slang shader: {s}\n", .{spec.name});
    const source = try readFile(allocator, spec.source_path);
    defer allocator.free(source);
    const hash = sourceHash(source);

    const shader_dir = try std.fs.path.join(allocator, &.{ output_dir, spec.name });
    defer allocator.free(shader_dir);
    try makeDirPath(shader_dir);

    const vert_spv = try std.fs.path.join(allocator, &.{ shader_dir, "vert.spv" });
    defer allocator.free(vert_spv);
    const frag_spv = try std.fs.path.join(allocator, &.{ shader_dir, "frag.spv" });
    defer allocator.free(frag_spv);
    const vert_msl = try std.fs.path.join(allocator, &.{ shader_dir, "vert.msl" });
    defer allocator.free(vert_msl);
    const frag_msl = try std.fs.path.join(allocator, &.{ shader_dir, "frag.msl" });
    defer allocator.free(frag_msl);
    const vert_reflect = try std.fs.path.join(allocator, &.{ shader_dir, "vert.reflect.json" });
    defer allocator.free(vert_reflect);
    const frag_reflect = try std.fs.path.join(allocator, &.{ shader_dir, "frag.reflect.json" });
    defer allocator.free(frag_reflect);

    try runSlang(allocator, io, slangc, spec.source_path, .vertex, spec.vertex_entry, .spirv, vert_spv);
    try runSlang(allocator, io, slangc, spec.source_path, .fragment, spec.fragment_entry, .spirv, frag_spv);
    try runSlang(allocator, io, slangc, spec.source_path, .vertex, spec.vertex_entry, .msl, vert_msl);
    try runSlang(allocator, io, slangc, spec.source_path, .fragment, spec.fragment_entry, .msl, frag_msl);

    const vertex_json = try renderStageReflectionJson(allocator, spec.name, spec.source_path, source, .vertex, spec.vertex_entry);
    defer allocator.free(vertex_json);
    try writeFile(vert_reflect, vertex_json);
    const fragment_json = try renderStageReflectionJson(allocator, spec.name, spec.source_path, source, .fragment, spec.fragment_entry);
    defer allocator.free(fragment_json);
    try writeFile(frag_reflect, fragment_json);

    return .{ .spec = spec, .hash = hash };
}

fn precompileCompute(
    allocator: std.mem.Allocator,
    io: std.Io,
    output_dir: []const u8,
    slangc: []const u8,
    spec: ComputeSpec,
) !GeneratedCompute {
    std.debug.print("precompiling slang shader: {s}\n", .{spec.name});
    const source = try readFile(allocator, spec.source_path);
    defer allocator.free(source);
    const hash = sourceHash(source);

    const shader_dir = try std.fs.path.join(allocator, &.{ output_dir, spec.name });
    defer allocator.free(shader_dir);
    try makeDirPath(shader_dir);

    const spirv = try std.fs.path.join(allocator, &.{ shader_dir, "compute.spv" });
    defer allocator.free(spirv);
    const msl = try std.fs.path.join(allocator, &.{ shader_dir, "compute.msl" });
    defer allocator.free(msl);
    const reflect = try std.fs.path.join(allocator, &.{ shader_dir, "compute.reflect.json" });
    defer allocator.free(reflect);

    try runSlang(allocator, io, slangc, spec.source_path, .compute, spec.entry, .spirv, spirv);
    try runSlang(allocator, io, slangc, spec.source_path, .compute, spec.entry, .msl, msl);

    const reflection_json = try renderStageReflectionJson(allocator, spec.name, spec.source_path, source, .compute, spec.entry);
    defer allocator.free(reflection_json);
    try writeFile(reflect, reflection_json);

    return .{ .spec = spec, .hash = hash };
}

fn precompileRayTracing(
    allocator: std.mem.Allocator,
    io: std.Io,
    output_dir: []const u8,
    slangc: []const u8,
    spec: RayTracingSpec,
) !GeneratedRayTracing {
    std.debug.print("precompiling slang shader: {s}\n", .{spec.name});
    const source = try readFile(allocator, spec.source_path);
    defer allocator.free(source);
    const hash = sourceHash(source);

    const shader_dir = try std.fs.path.join(allocator, &.{ output_dir, spec.name });
    defer allocator.free(shader_dir);
    try makeDirPath(shader_dir);

    const raygen_spv = try std.fs.path.join(allocator, &.{ shader_dir, "raygen.spv" });
    defer allocator.free(raygen_spv);
    const miss_spv = try std.fs.path.join(allocator, &.{ shader_dir, "miss.spv" });
    defer allocator.free(miss_spv);
    const closest_hit_spv = try std.fs.path.join(allocator, &.{ shader_dir, "closest_hit.spv" });
    defer allocator.free(closest_hit_spv);
    const raygen_reflect = try std.fs.path.join(allocator, &.{ shader_dir, "raygen.reflect.json" });
    defer allocator.free(raygen_reflect);
    const miss_reflect = try std.fs.path.join(allocator, &.{ shader_dir, "miss.reflect.json" });
    defer allocator.free(miss_reflect);
    const closest_hit_reflect = try std.fs.path.join(allocator, &.{ shader_dir, "closest_hit.reflect.json" });
    defer allocator.free(closest_hit_reflect);

    try runRayTracingSlang(allocator, io, slangc, spec.source_path, spec.ray_generation_entry, raygen_spv);
    try runRayTracingSlang(allocator, io, slangc, spec.source_path, spec.miss_entry, miss_spv);
    try runRayTracingSlang(allocator, io, slangc, spec.source_path, spec.closest_hit_entry, closest_hit_spv);

    const raygen_json = try renderRayTracingReflectionJson(allocator, spec.name, spec.source_path, source, "ray_generation", spec.ray_generation_entry);
    defer allocator.free(raygen_json);
    try writeFile(raygen_reflect, raygen_json);
    const miss_json = try renderRayTracingReflectionJson(allocator, spec.name, spec.source_path, source, "miss", spec.miss_entry);
    defer allocator.free(miss_json);
    try writeFile(miss_reflect, miss_json);
    const closest_hit_json = try renderRayTracingReflectionJson(allocator, spec.name, spec.source_path, source, "closest_hit", spec.closest_hit_entry);
    defer allocator.free(closest_hit_json);
    try writeFile(closest_hit_reflect, closest_hit_json);

    return .{ .spec = spec, .hash = hash };
}

const Stage = enum {
    vertex,
    fragment,
    compute,
};

const Target = enum {
    spirv,
    msl,
};

fn runSlang(
    allocator: std.mem.Allocator,
    io: std.Io,
    slangc: []const u8,
    source_path: []const u8,
    stage: Stage,
    entry: []const u8,
    target: Target,
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
    };
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);
    try argv.appendSlice(allocator, &.{
        slangc,
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
    try runProcess(allocator, io, argv.items, source_path);
}

fn runRayTracingSlang(
    allocator: std.mem.Allocator,
    io: std.Io,
    slangc: []const u8,
    source_path: []const u8,
    entry: []const u8,
    output_path: []const u8,
) !void {
    try runProcess(allocator, io, &.{
        slangc,
        source_path,
        "-target",
        "spirv",
        "-profile",
        "lib_6_3",
        "-entry",
        entry,
        "-fvk-use-entrypoint-name",
        "-o",
        output_path,
    }, source_path);
}

fn runProcess(
    allocator: std.mem.Allocator,
    io: std.Io,
    argv: []const []const u8,
    source_path: []const u8,
) !void {
    const result = std.process.run(allocator, io, .{
        .argv = argv,
        .stderr_limit = .limited(64 * 1024),
        .stdout_limit = .limited(64 * 1024),
    }) catch |err| {
        std.debug.print("failed to launch build-time shader compiler at {s}: {t}\n", .{ argv[0], err });
        return error.ShaderPrecompileFailed;
    };
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    switch (result.term) {
        .exited => |code| if (code == 0) return,
        else => {},
    }

    if (result.stdout.len != 0) {
        std.debug.print("shader compiler stdout:\n{s}\n", .{result.stdout});
    }
    if (result.stderr.len != 0) {
        std.debug.print("shader compiler stderr:\n{s}\n", .{result.stderr});
    }
    std.debug.print("shader precompile failed for {s}\n", .{source_path});
    return error.ShaderPrecompileFailed;
}

fn writeGeneratedModule(
    allocator: std.mem.Allocator,
    output_dir: []const u8,
    render_items: []const GeneratedRender,
    compute_items: []const GeneratedCompute,
    ray_tracing_items: []const GeneratedRayTracing,
) !void {
    var zig: std.ArrayList(u8) = .empty;
    defer zig.deinit(allocator);

    try zig.appendSlice(allocator,
        \\pub const RenderShaderBlob = struct {
        \\    name: []const u8,
        \\    source_hash: []const u8,
        \\    vertex_entry: []const u8,
        \\    fragment_entry: []const u8,
        \\    vertex_spirv: []const u8,
        \\    fragment_spirv: []const u8,
        \\    vertex_msl: []const u8,
        \\    fragment_msl: []const u8,
        \\    vertex_reflection: []const u8,
        \\    fragment_reflection: []const u8,
        \\};
        \\
        \\pub const ComputeShaderBlob = struct {
        \\    name: []const u8,
        \\    source_hash: []const u8,
        \\    entry: []const u8,
        \\    spirv: []const u8,
        \\    msl: []const u8,
        \\    reflection: []const u8,
        \\};
        \\
        \\pub const RayTracingShaderBlob = struct {
        \\    name: []const u8,
        \\    source_hash: []const u8,
        \\    ray_generation_entry: []const u8,
        \\    miss_entry: []const u8,
        \\    closest_hit_entry: []const u8,
        \\    ray_generation_spirv: []const u8,
        \\    miss_spirv: []const u8,
        \\    closest_hit_spirv: []const u8,
        \\    ray_generation_reflection: []const u8,
        \\    miss_reflection: []const u8,
        \\    closest_hit_reflection: []const u8,
        \\};
        \\
        \\pub const render_shaders = [_]RenderShaderBlob{
        \\
    );

    for (render_items) |item| {
        try zig.print(
            allocator,
            "    .{{ .name = \"{s}\", .source_hash = \"{s}\", .vertex_entry = \"{s}\", .fragment_entry = \"{s}\", .vertex_spirv = @embedFile(\"{s}/vert.spv\"), .fragment_spirv = @embedFile(\"{s}/frag.spv\"), .vertex_msl = @embedFile(\"{s}/vert.msl\"), .fragment_msl = @embedFile(\"{s}/frag.msl\"), .vertex_reflection = @embedFile(\"{s}/vert.reflect.json\"), .fragment_reflection = @embedFile(\"{s}/frag.reflect.json\") }},\n",
            .{
                item.spec.name,
                item.hash,
                item.spec.vertex_entry,
                item.spec.fragment_entry,
                item.spec.name,
                item.spec.name,
                item.spec.name,
                item.spec.name,
                item.spec.name,
                item.spec.name,
            },
        );
    }
    try zig.appendSlice(allocator,
        \\};
        \\
        \\pub const compute_shaders = [_]ComputeShaderBlob{
        \\
    );
    for (compute_items) |item| {
        try zig.print(
            allocator,
            "    .{{ .name = \"{s}\", .source_hash = \"{s}\", .entry = \"{s}\", .spirv = @embedFile(\"{s}/compute.spv\"), .msl = @embedFile(\"{s}/compute.msl\"), .reflection = @embedFile(\"{s}/compute.reflect.json\") }},\n",
            .{
                item.spec.name,
                item.hash,
                item.spec.entry,
                item.spec.name,
                item.spec.name,
                item.spec.name,
            },
        );
    }
    try zig.appendSlice(allocator,
        \\};
        \\
        \\pub const ray_tracing_shaders = [_]RayTracingShaderBlob{
        \\
    );
    for (ray_tracing_items) |item| {
        try zig.print(
            allocator,
            "    .{{ .name = \"{s}\", .source_hash = \"{s}\", .ray_generation_entry = \"{s}\", .miss_entry = \"{s}\", .closest_hit_entry = \"{s}\", .ray_generation_spirv = @embedFile(\"{s}/raygen.spv\"), .miss_spirv = @embedFile(\"{s}/miss.spv\"), .closest_hit_spirv = @embedFile(\"{s}/closest_hit.spv\"), .ray_generation_reflection = @embedFile(\"{s}/raygen.reflect.json\"), .miss_reflection = @embedFile(\"{s}/miss.reflect.json\"), .closest_hit_reflection = @embedFile(\"{s}/closest_hit.reflect.json\") }},\n",
            .{
                item.spec.name,
                item.hash,
                item.spec.ray_generation_entry,
                item.spec.miss_entry,
                item.spec.closest_hit_entry,
                item.spec.name,
                item.spec.name,
                item.spec.name,
                item.spec.name,
                item.spec.name,
                item.spec.name,
            },
        );
    }
    try zig.appendSlice(allocator,
        \\};
        \\
    );

    const generated_path = try std.fs.path.join(allocator, &.{ output_dir, "precompiled_shaders.zig" });
    defer allocator.free(generated_path);
    try writeFile(generated_path, zig.items);
}

fn renderStageReflectionJson(
    allocator: std.mem.Allocator,
    shader_name: []const u8,
    source_path: []const u8,
    source: []const u8,
    stage: Stage,
    entry: []const u8,
) ![]const u8 {
    var json: std.ArrayList(u8) = .empty;
    errdefer json.deinit(allocator);

    try json.print(
        allocator,
        "{{\n  \"schema_version\": 1,\n  \"name\": \"{s}\",\n  \"source\": \"{s}\",\n  \"source_language\": \"slang\",\n  \"stage\": \"{s}\",\n  \"entry_point\": \"{s}\",\n",
        .{ shader_name, source_path, stageName(stage), entry },
    );

    if (stage == .compute) {
        if (parseThreadgroupSize(source)) |size| {
            try json.print(allocator, "  \"threadgroup_size\": [{}, {}, {}],\n", .{ size[0], size[1], size[2] });
        }
    }

    try writeVertexInputsJson(allocator, &json, source, stage, entry);
    try writeBindGroupsJson(allocator, &json, source, stageName(stage), entry);
    try json.appendSlice(allocator, "\n}\n");
    return try json.toOwnedSlice(allocator);
}

fn renderRayTracingReflectionJson(
    allocator: std.mem.Allocator,
    shader_name: []const u8,
    source_path: []const u8,
    source: []const u8,
    stage_name: []const u8,
    entry: []const u8,
) ![]const u8 {
    var json: std.ArrayList(u8) = .empty;
    errdefer json.deinit(allocator);
    try json.print(
        allocator,
        "{{\n  \"schema_version\": 1,\n  \"name\": \"{s}\",\n  \"source\": \"{s}\",\n  \"source_language\": \"slang\",\n  \"stage\": \"{s}\",\n  \"entry_point\": \"{s}\",\n",
        .{ shader_name, source_path, stage_name, entry },
    );
    try json.appendSlice(allocator, "  \"vertex_inputs\": [],\n");
    try writeBindGroupsJson(allocator, &json, source, stage_name, entry);
    try json.appendSlice(allocator, "\n}\n");
    return try json.toOwnedSlice(allocator);
}

fn writeVertexInputsJson(
    allocator: std.mem.Allocator,
    json: *std.ArrayList(u8),
    source: []const u8,
    stage: Stage,
    entry: []const u8,
) !void {
    try json.appendSlice(allocator, "  \"vertex_inputs\": [");
    if (stage == .vertex) {
        if (entryInputStruct(source, entry)) |input_struct| {
            var offset: u32 = 0;
            var index: u32 = 0;
            var lines = std.mem.splitScalar(u8, input_struct.body, '\n');
            while (lines.next()) |raw_line| {
                const line = std.mem.trim(u8, raw_line, " \t\r\n");
                const field = parseVertexField(line, offset) orelse continue;
                if (index == 0) try json.append(allocator, '\n') else try json.appendSlice(allocator, ",\n");
                try json.print(
                    allocator,
                    "    {{\n      \"location\": {},\n      \"semantic\": \"{s}\",\n      \"format\": \"{s}\",\n      \"offset\": {}\n    }}",
                    .{ index, field.semantic, field.format_name, offset },
                );
                offset += field.size;
                index += 1;
            }
            if (index != 0) try json.appendSlice(allocator, "\n  ");
        }
    }
    try json.appendSlice(allocator, "],\n");
}

fn writeBindGroupsJson(
    allocator: std.mem.Allocator,
    json: *std.ArrayList(u8),
    source: []const u8,
    visibility_name: []const u8,
    entry: []const u8,
) !void {
    const body = entryBody(source, entry) orelse "";
    var reflected: std.ArrayList(ResourceInfo) = .empty;
    defer reflected.deinit(allocator);
    try parseResources(allocator, source, body, &reflected);

    try json.appendSlice(allocator, "  \"bind_groups\": [");
    if (reflected.items.len != 0) {
        std.sort.block(ResourceInfo, reflected.items, {}, resourceLessThan);
        var current_group: ?u32 = null;
        var first_group = true;
        for (reflected.items) |resource| {
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
            try json.print(
                allocator,
                "\n        {{\n          \"binding\": {},\n          \"kind\": \"{s}\",\n          \"visibility\": \"{s}\"\n        }}",
                .{ resource.binding, resource.kind_name, visibility_name },
            );
        }
        try json.appendSlice(allocator, "\n      ]\n    }\n  ");
    }
    try json.append(allocator, ']');
}

const InputStruct = struct {
    name: []const u8,
    body: []const u8,
};

const VertexField = struct {
    semantic: []const u8,
    format_name: []const u8,
    size: u32,
};

const ResourceInfo = struct {
    binding: u32,
    group: u32,
    kind_name: []const u8,
};

fn entryInputStruct(source: []const u8, entry: []const u8) ?InputStruct {
    const signature = entrySignature(source, entry) orelse return null;
    const open_paren = std.mem.indexOfScalar(u8, signature, '(') orelse return null;
    const close_paren = std.mem.lastIndexOfScalar(u8, signature, ')') orelse return null;
    const params = std.mem.trim(u8, signature[open_paren + 1 .. close_paren], " \t\r\n");
    if (params.len == 0) return null;
    const struct_name = firstToken(params) orelse return null;
    return structBody(source, struct_name);
}

fn structBody(source: []const u8, struct_name: []const u8) ?InputStruct {
    var search_start: usize = 0;
    while (std.mem.indexOfPos(u8, source, search_start, "struct ")) |struct_pos| {
        const name_start = struct_pos + "struct ".len;
        const name_end = skipIdentifier(source, name_start);
        const name = std.mem.trim(u8, source[name_start..name_end], " \t\r\n");
        const open_brace = std.mem.indexOfScalarPos(u8, source, name_end, '{') orelse break;
        const close_brace = matchingBrace(source, open_brace) orelse break;
        if (std.mem.eql(u8, name, struct_name)) {
            return .{ .name = name, .body = source[open_brace + 1 .. close_brace] };
        }
        search_start = close_brace + 1;
    }
    return null;
}

fn parseVertexField(line: []const u8, current_offset: u32) ?VertexField {
    _ = current_offset;
    if (line.len == 0 or std.mem.indexOfScalar(u8, line, ':') == null) return null;
    const semicolon = std.mem.indexOfScalar(u8, line, ';') orelse return null;
    const colon = std.mem.indexOfScalar(u8, line, ':') orelse return null;
    const before_colon = std.mem.trim(u8, line[0..colon], " \t\r\n");
    const semantic = std.mem.trim(u8, line[colon + 1 .. semicolon], " \t\r\n");
    if (std.mem.eql(u8, semantic, "SV_Position") or std.mem.startsWith(u8, semantic, "SV_")) return null;

    const field_type = firstToken(before_colon) orelse return null;
    if (std.mem.eql(u8, field_type, "float")) return .{ .semantic = semantic, .format_name = "float32", .size = 4 };
    if (std.mem.eql(u8, field_type, "float2")) return .{ .semantic = semantic, .format_name = "float32x2", .size = 8 };
    if (std.mem.eql(u8, field_type, "float3")) return .{ .semantic = semantic, .format_name = "float32x3", .size = 12 };
    if (std.mem.eql(u8, field_type, "float4")) return .{ .semantic = semantic, .format_name = "float32x4", .size = 16 };
    return null;
}

fn parseResources(
    allocator: std.mem.Allocator,
    source: []const u8,
    body: []const u8,
    out: *std.ArrayList(ResourceInfo),
) !void {
    var pending_binding: ?[2]u32 = null;
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");
        if (std.mem.indexOf(u8, line, "vk::binding(")) |binding_pos| {
            pending_binding = parseBindingAnnotation(line[binding_pos..]);
            continue;
        }
        if (pending_binding) |binding| {
            if (parseResourceLine(line)) |parsed| {
                if (std.mem.indexOf(u8, body, parsed.name) != null) {
                    try out.append(allocator, .{
                        .binding = binding[0],
                        .group = binding[1],
                        .kind_name = parsed.kind_name,
                    });
                }
                pending_binding = null;
            }
        }
    }
}

fn parseResourceLine(line: []const u8) ?struct { name: []const u8, kind_name: []const u8 } {
    const kind_name: []const u8 = if (std.mem.startsWith(u8, line, "ConstantBuffer"))
        "uniform_buffer"
    else if (std.mem.startsWith(u8, line, "Texture2D"))
        "sampled_texture"
    else if (std.mem.startsWith(u8, line, "SamplerState"))
        "sampler"
    else if (std.mem.startsWith(u8, line, "RWTexture2D"))
        "storage_texture"
    else if (std.mem.startsWith(u8, line, "RWStructuredBuffer"))
        "storage_buffer"
    else
        return null;

    const before_register = if (std.mem.indexOfScalar(u8, line, ':')) |colon| line[0..colon] else line;
    const name = lastToken(before_register) orelse return null;
    return .{ .name = name, .kind_name = kind_name };
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

fn entryBody(source: []const u8, entry: []const u8) ?[]const u8 {
    const signature_start = entrySignatureStart(source, entry) orelse return null;
    const open_brace = std.mem.indexOfScalarPos(u8, source, signature_start, '{') orelse return null;
    return bodyAfterOpenBrace(source, open_brace);
}

fn entrySignature(source: []const u8, entry: []const u8) ?[]const u8 {
    const start = entrySignatureStart(source, entry) orelse return null;
    const open_brace = std.mem.indexOfScalarPos(u8, source, start, '{') orelse return null;
    return source[start..open_brace];
}

fn entrySignatureStart(source: []const u8, entry: []const u8) ?usize {
    var search_start: usize = 0;
    while (std.mem.indexOfPos(u8, source, search_start, entry)) |entry_index| {
        const before_ok = entry_index == 0 or !isIdentifierByte(source[entry_index - 1]);
        const after_index = entry_index + entry.len;
        const after_ok = after_index >= source.len or !isIdentifierByte(source[after_index]);
        if (before_ok and after_ok) return lineStart(source, entry_index);
        search_start = after_index;
    }
    return null;
}

fn bodyAfterOpenBrace(source: []const u8, open_brace: usize) ?[]const u8 {
    const close = matchingBrace(source, open_brace) orelse return null;
    return source[open_brace + 1 .. close];
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

fn lineStart(source: []const u8, index: usize) usize {
    var current = index;
    while (current != 0 and source[current - 1] != '\n') current -= 1;
    return current;
}

fn skipIdentifier(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len) : (index += 1) {
        if (!isIdentifierByte(source[index])) break;
    }
    return index;
}

fn isIdentifierByte(byte: u8) bool {
    return switch (byte) {
        'a'...'z', 'A'...'Z', '0'...'9', '_' => true,
        else => false,
    };
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

fn resourceLessThan(_: void, lhs: ResourceInfo, rhs: ResourceInfo) bool {
    if (lhs.group != rhs.group) return lhs.group < rhs.group;
    return lhs.binding < rhs.binding;
}

fn stageName(stage: Stage) []const u8 {
    return switch (stage) {
        .vertex => "vertex",
        .fragment => "fragment",
        .compute => "compute",
    };
}

fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return try std.Io.Dir.cwd().readFileAlloc(
        std.Options.debug_io,
        path,
        allocator,
        .limited(max_source_bytes),
    );
}

fn makeDirPath(path: []const u8) !void {
    std.Io.Dir.createDirPath(.cwd(), std.Options.debug_io, path) catch return error.OutputDirectoryCreateFailed;
}

fn writeFile(path: []const u8, bytes: []const u8) !void {
    std.Io.Dir.writeFile(.cwd(), std.Options.debug_io, .{
        .sub_path = path,
        .data = bytes,
    }) catch return error.OutputFileWriteFailed;
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
