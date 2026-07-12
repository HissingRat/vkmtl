const std = @import("std");
const core = @import("../core.zig");
const precompiled = @import("vkmtl_precompiled_shaders");

pub const RenderShaderOptions = struct {
    vertex_entry: []const u8 = "vs_main",
    fragment_entry: []const u8 = "fs_main",
};

pub const ComputeShaderOptions = struct {
    entry: []const u8 = "cs_main",
};

pub const RayTracingShaderOptions = struct {
    ray_generation_entry: []const u8 = "raygen",
    miss_entry: []const u8 = "miss",
    closest_hit_entry: []const u8 = "closest_hit",
    any_hit_entry: []const u8 = "any_hit",
    intersection_entry: []const u8 = "intersection_main",
};

pub const RenderShaderStages = struct {
    vertex: core.ProgrammableStageDescriptor,
    fragment: core.ProgrammableStageDescriptor,
};

pub const CompiledRenderShader = struct {
    allocator: std.mem.Allocator,
    vertex_spirv: []const u8,
    fragment_spirv: []const u8,
    vertex_msl: []const u8,
    fragment_msl: []const u8,
    vertex_reflection_json: []const u8,
    fragment_reflection_json: []const u8,
    vertex_entry: []u8,
    fragment_entry: []u8,

    pub fn deinit(self: *CompiledRenderShader) void {
        const allocator = self.allocator;
        allocator.free(self.vertex_entry);
        allocator.free(self.fragment_entry);
        self.* = undefined;
    }

    pub fn vertexStageDescriptor(self: CompiledRenderShader, backend: core.Backend) core.ProgrammableStageDescriptor {
        return .{
            .module = .{ .source = self.shaderSource(backend, .vertex) },
            .stage = .vertex,
            .entry_point = self.vertex_entry,
            .reflection = .{ .json = self.vertex_reflection_json },
        };
    }

    pub fn fragmentStageDescriptor(self: CompiledRenderShader, backend: core.Backend) core.ProgrammableStageDescriptor {
        return .{
            .module = .{ .source = self.shaderSource(backend, .fragment) },
            .stage = .fragment,
            .entry_point = self.fragment_entry,
            .reflection = .{ .json = self.fragment_reflection_json },
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
            .vulkan => .{ .spirv_bytes = switch (stage) {
                .vertex => self.vertex_spirv,
                .fragment => self.fragment_spirv,
                .compute,
                .tessellation_control,
                .tessellation_evaluation,
                .mesh,
                .task,
                => unreachable,
            } },
            .metal => .{ .msl = switch (stage) {
                .vertex => self.vertex_msl,
                .fragment => self.fragment_msl,
                .compute,
                .tessellation_control,
                .tessellation_evaluation,
                .mesh,
                .task,
                => unreachable,
            } },
        };
    }
};

pub const CompiledComputeShader = struct {
    allocator: std.mem.Allocator,
    spirv: []const u8,
    msl: []const u8,
    reflection_json: []const u8,
    entry: []u8,

    pub fn deinit(self: *CompiledComputeShader) void {
        const allocator = self.allocator;
        allocator.free(self.entry);
        self.* = undefined;
    }

    pub fn stageDescriptor(self: CompiledComputeShader, backend: core.Backend) core.ProgrammableStageDescriptor {
        return .{
            .module = .{ .source = switch (backend) {
                .vulkan => .{ .spirv_bytes = self.spirv },
                .metal => .{ .msl = self.msl },
            } },
            .stage = .compute,
            .entry_point = self.entry,
            .reflection = .{ .json = self.reflection_json },
        };
    }
};

pub const CompiledRayTracingShader = struct {
    allocator: std.mem.Allocator,
    ray_generation_spirv: []const u8,
    miss_spirv: []const u8,
    closest_hit_spirv: []const u8,
    any_hit_spirv: []const u8,
    intersection_spirv: []const u8,
    ray_generation_msl: []const u8,
    ray_generation_reflection_json: []const u8,
    miss_reflection_json: []const u8,
    closest_hit_reflection_json: []const u8,
    any_hit_reflection_json: []const u8,
    intersection_reflection_json: []const u8,
    ray_generation_entry: []u8,
    miss_entry: []u8,
    closest_hit_entry: []u8,
    any_hit_entry: []u8,
    intersection_entry: []u8,

    pub fn deinit(self: *CompiledRayTracingShader) void {
        const allocator = self.allocator;
        allocator.free(self.ray_generation_entry);
        allocator.free(self.miss_entry);
        allocator.free(self.closest_hit_entry);
        allocator.free(self.any_hit_entry);
        allocator.free(self.intersection_entry);
        self.* = undefined;
    }

    pub fn rayGenerationModuleDescriptor(self: CompiledRayTracingShader) core.ShaderModuleDescriptor {
        return self.rayGenerationModuleDescriptorForBackend(.vulkan);
    }

    pub fn rayGenerationStageDescriptor(self: CompiledRayTracingShader) core.RayTracingShaderStageDescriptor {
        return self.rayGenerationStageDescriptorForBackend(.vulkan);
    }

    pub fn rayGenerationModuleDescriptorForBackend(self: CompiledRayTracingShader, backend: core.Backend) core.ShaderModuleDescriptor {
        return switch (backend) {
            .vulkan => self.moduleDescriptor(self.ray_generation_spirv, .spirv),
            .metal => self.moduleDescriptor(self.ray_generation_msl, .msl),
        };
    }

    pub fn rayGenerationStageDescriptorForBackend(self: CompiledRayTracingShader, backend: core.Backend) core.RayTracingShaderStageDescriptor {
        return .{
            .module = self.rayGenerationModuleDescriptorForBackend(backend),
            .entry_point = self.ray_generation_entry,
        };
    }

    pub fn missModuleDescriptor(self: CompiledRayTracingShader) core.ShaderModuleDescriptor {
        return self.moduleDescriptor(self.miss_spirv, .spirv);
    }

    pub fn missStageDescriptor(self: CompiledRayTracingShader) core.RayTracingShaderStageDescriptor {
        return .{
            .module = self.missModuleDescriptor(),
            .entry_point = self.miss_entry,
        };
    }

    pub fn closestHitModuleDescriptor(self: CompiledRayTracingShader) core.ShaderModuleDescriptor {
        return self.moduleDescriptor(self.closest_hit_spirv, .spirv);
    }

    pub fn closestHitStageDescriptor(self: CompiledRayTracingShader) core.RayTracingShaderStageDescriptor {
        return .{
            .module = self.closestHitModuleDescriptor(),
            .entry_point = self.closest_hit_entry,
        };
    }

    pub fn anyHitModuleDescriptor(self: CompiledRayTracingShader) core.ShaderModuleDescriptor {
        return self.moduleDescriptor(self.any_hit_spirv, .spirv);
    }

    pub fn anyHitStageDescriptor(self: CompiledRayTracingShader) core.RayTracingShaderStageDescriptor {
        return .{
            .module = self.anyHitModuleDescriptor(),
            .entry_point = self.any_hit_entry,
        };
    }

    pub fn intersectionModuleDescriptor(self: CompiledRayTracingShader) core.ShaderModuleDescriptor {
        return self.moduleDescriptor(self.intersection_spirv, .spirv);
    }

    pub fn intersectionStageDescriptor(self: CompiledRayTracingShader) core.RayTracingShaderStageDescriptor {
        return .{
            .module = self.intersectionModuleDescriptor(),
            .entry_point = self.intersection_entry,
        };
    }

    pub fn applyToPipelineDescriptor(
        self: CompiledRayTracingShader,
        backend: core.Backend,
        descriptor: *core.RayTracingPipelineDescriptor,
    ) void {
        descriptor.ray_generation = self.rayGenerationStageDescriptorForBackend(backend);
        switch (backend) {
            .vulkan => {
                descriptor.miss = self.missStageDescriptor();
                descriptor.closest_hit = self.closestHitStageDescriptor();
                descriptor.any_hit = self.anyHitStageDescriptor();
                descriptor.intersection = self.intersectionStageDescriptor();
            },
            .metal => {
                descriptor.miss = null;
                descriptor.closest_hit = null;
                descriptor.any_hit = null;
                descriptor.intersection = null;
            },
        }
    }

    fn moduleDescriptor(
        _: CompiledRayTracingShader,
        bytes: []const u8,
        language: core.ShaderSourceLanguage,
    ) core.ShaderModuleDescriptor {
        return .{ .source = switch (language) {
            .spirv => .{ .spirv_bytes = bytes },
            .msl => .{ .msl = bytes },
            .slang => unreachable,
        } };
    }
};

pub fn compileRenderShader(
    allocator: std.mem.Allocator,
    name: []const u8,
    source: []const u8,
    options: RenderShaderOptions,
) !CompiledRenderShader {
    try validateShaderName(name);

    const source_hash = sourceHash(source);
    if (try loadPrecompiledRenderShader(
        allocator,
        name,
        source_hash,
        options,
    )) |result| {
        std.debug.print("using precompiled slang shader: {s}\n", .{name});
        return result;
    }

    std.debug.print("missing precompiled shader: {s}\n", .{name});
    return error.PrecompiledShaderMissing;
}

pub fn compileComputeShader(
    allocator: std.mem.Allocator,
    name: []const u8,
    source: []const u8,
    options: ComputeShaderOptions,
) !CompiledComputeShader {
    try validateShaderName(name);

    const source_hash = sourceHash(source);
    if (try loadPrecompiledComputeShader(
        allocator,
        name,
        source_hash,
        options,
    )) |result| {
        std.debug.print("using precompiled slang shader: {s}\n", .{name});
        return result;
    }

    std.debug.print("missing precompiled shader: {s}\n", .{name});
    return error.PrecompiledShaderMissing;
}

pub fn compileRayTracingShader(
    allocator: std.mem.Allocator,
    name: []const u8,
    source: []const u8,
    options: RayTracingShaderOptions,
) !CompiledRayTracingShader {
    try validateShaderName(name);

    const source_hash = sourceHash(source);
    if (try loadPrecompiledRayTracingShader(
        allocator,
        name,
        source_hash,
        options,
    )) |result| {
        std.debug.print("using precompiled slang shader: {s}\n", .{name});
        return result;
    }

    std.debug.print("missing precompiled shader: {s}\n", .{name});
    return error.PrecompiledShaderMissing;
}

const RayTracingCompileStage = enum {
    ray_generation,
    miss,
    closest_hit,
    any_hit,
    intersection,
};

fn loadPrecompiledRenderShader(
    allocator: std.mem.Allocator,
    name: []const u8,
    source_hash: [64]u8,
    options: RenderShaderOptions,
) !?CompiledRenderShader {
    for (precompiled.render_shaders) |blob| {
        if (!std.mem.eql(u8, blob.name, name)) continue;
        if (!std.mem.eql(u8, blob.vertex_entry, options.vertex_entry)) continue;
        if (!std.mem.eql(u8, blob.fragment_entry, options.fragment_entry)) continue;
        if (!std.mem.eql(u8, blob.source_hash, source_hash[0..])) continue;

        return .{
            .allocator = allocator,
            .vertex_spirv = blob.vertex_spirv,
            .fragment_spirv = blob.fragment_spirv,
            .vertex_msl = blob.vertex_msl,
            .fragment_msl = blob.fragment_msl,
            .vertex_reflection_json = blob.vertex_reflection,
            .fragment_reflection_json = blob.fragment_reflection,
            .vertex_entry = try allocator.dupe(u8, options.vertex_entry),
            .fragment_entry = try allocator.dupe(u8, options.fragment_entry),
        };
    }

    return null;
}

fn loadPrecompiledComputeShader(
    allocator: std.mem.Allocator,
    name: []const u8,
    source_hash: [64]u8,
    options: ComputeShaderOptions,
) !?CompiledComputeShader {
    for (precompiled.compute_shaders) |blob| {
        if (!std.mem.eql(u8, blob.name, name)) continue;
        if (!std.mem.eql(u8, blob.entry, options.entry)) continue;
        if (!std.mem.eql(u8, blob.source_hash, source_hash[0..])) continue;

        return .{
            .allocator = allocator,
            .spirv = blob.spirv,
            .msl = blob.msl,
            .reflection_json = blob.reflection,
            .entry = try allocator.dupe(u8, options.entry),
        };
    }

    return null;
}

fn loadPrecompiledRayTracingShader(
    allocator: std.mem.Allocator,
    name: []const u8,
    source_hash: [64]u8,
    options: RayTracingShaderOptions,
) !?CompiledRayTracingShader {
    for (precompiled.ray_tracing_shaders) |blob| {
        if (!std.mem.eql(u8, blob.name, name)) continue;
        if (!std.mem.eql(u8, blob.ray_generation_entry, options.ray_generation_entry)) continue;
        if (!std.mem.eql(u8, blob.miss_entry, options.miss_entry)) continue;
        if (!std.mem.eql(u8, blob.closest_hit_entry, options.closest_hit_entry)) continue;
        if (!std.mem.eql(u8, blob.any_hit_entry, options.any_hit_entry)) continue;
        if (!std.mem.eql(u8, blob.intersection_entry, options.intersection_entry)) continue;
        if (!std.mem.eql(u8, blob.source_hash, source_hash[0..])) continue;

        return .{
            .allocator = allocator,
            .ray_generation_spirv = blob.ray_generation_spirv,
            .miss_spirv = blob.miss_spirv,
            .closest_hit_spirv = blob.closest_hit_spirv,
            .any_hit_spirv = blob.any_hit_spirv,
            .intersection_spirv = blob.intersection_spirv,
            .ray_generation_msl = blob.ray_generation_msl,
            .ray_generation_reflection_json = blob.ray_generation_reflection,
            .miss_reflection_json = blob.miss_reflection,
            .closest_hit_reflection_json = blob.closest_hit_reflection,
            .any_hit_reflection_json = blob.any_hit_reflection,
            .intersection_reflection_json = blob.intersection_reflection,
            .ray_generation_entry = try allocator.dupe(u8, options.ray_generation_entry),
            .miss_entry = try allocator.dupe(u8, options.miss_entry),
            .closest_hit_entry = try allocator.dupe(u8, options.closest_hit_entry),
            .any_hit_entry = try allocator.dupe(u8, options.any_hit_entry),
            .intersection_entry = try allocator.dupe(u8, options.intersection_entry),
        };
    }

    return null;
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
        try self.writeBindGroupsJson(allocator, &json, stageName(stage), entry);
        try json.appendSlice(allocator, "\n}\n");
        return try json.toOwnedSlice(allocator);
    }

    fn renderRayTracingStageJson(
        self: ReflectionModel,
        allocator: std.mem.Allocator,
        shader_name: []const u8,
        source_path: []const u8,
        stage: RayTracingCompileStage,
        entry: []const u8,
    ) ![]const u8 {
        var json: std.ArrayList(u8) = .empty;
        errdefer json.deinit(allocator);
        try json.print(
            allocator,
            "{{\n  \"schema_version\": {},\n  \"name\": \"{s}\",\n  \"source\": \"{s}\",\n  \"source_language\": \"slang\",\n  \"stage\": \"{s}\",\n  \"entry_point\": \"{s}\",\n",
            .{ core.shader_reflection_schema_version, shader_name, source_path, rayTracingStageName(stage), entry },
        );

        try json.appendSlice(allocator, "  \"vertex_inputs\": [],\n");
        try self.writeBindGroupsJson(allocator, &json, rayTracingStageName(stage), entry);
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
        visibility_name: []const u8,
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
                    .{ resource.binding, bindingKindName(resource.kind), visibility_name },
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
    if (std.mem.eql(u8, name, "half2")) return .float16x2;
    if (std.mem.eql(u8, name, "half4")) return .float16x4;
    if (std.mem.eql(u8, name, "float")) return .float32;
    if (std.mem.eql(u8, name, "float2")) return .float32x2;
    if (std.mem.eql(u8, name, "float3")) return .float32x3;
    if (std.mem.eql(u8, name, "float4")) return .float32x4;
    if (std.mem.eql(u8, name, "uint")) return .uint32;
    if (std.mem.eql(u8, name, "uint2")) return .uint32x2;
    if (std.mem.eql(u8, name, "uint3")) return .uint32x3;
    if (std.mem.eql(u8, name, "uint4")) return .uint32x4;
    if (std.mem.eql(u8, name, "int")) return .sint32;
    if (std.mem.eql(u8, name, "int2")) return .sint32x2;
    if (std.mem.eql(u8, name, "int3")) return .sint32x3;
    if (std.mem.eql(u8, name, "int4")) return .sint32x4;
    return null;
}

fn vertexFormatSize(format: core.VertexFormat) u32 {
    return switch (format) {
        .float16x2 => 4,
        .float16x4 => 8,
        .float32 => 4,
        .float32x2 => 8,
        .float32x3 => 12,
        .float32x4 => 16,
        .unorm8x2, .snorm8x2 => 2,
        .unorm8x4, .snorm8x4 => 4,
        .uint32, .sint32 => 4,
        .uint32x2, .sint32x2 => 8,
        .uint32x3, .sint32x3 => 12,
        .uint32x4, .sint32x4 => 16,
    };
}

fn vertexFormatName(format: core.VertexFormat) []const u8 {
    return switch (format) {
        .float16x2 => "float16x2",
        .float16x4 => "float16x4",
        .float32 => "float32",
        .float32x2 => "float32x2",
        .float32x3 => "float32x3",
        .float32x4 => "float32x4",
        .unorm8x2 => "unorm8x2",
        .unorm8x4 => "unorm8x4",
        .snorm8x2 => "snorm8x2",
        .snorm8x4 => "snorm8x4",
        .uint32 => "uint32",
        .uint32x2 => "uint32x2",
        .uint32x3 => "uint32x3",
        .uint32x4 => "uint32x4",
        .sint32 => "sint32",
        .sint32x2 => "sint32x2",
        .sint32x3 => "sint32x3",
        .sint32x4 => "sint32x4",
    };
}

fn stageName(stage: core.ShaderStage) []const u8 {
    return switch (stage) {
        .vertex => "vertex",
        .fragment => "fragment",
        .compute => "compute",
        .tessellation_control => "tessellation_control",
        .tessellation_evaluation => "tessellation_evaluation",
        .mesh => "mesh",
        .task => "task",
    };
}

fn rayTracingStageName(stage: RayTracingCompileStage) []const u8 {
    return switch (stage) {
        .ray_generation => "ray_generation",
        .miss => "miss",
        .closest_hit => "closest_hit",
        .any_hit => "any_hit",
        .intersection => "intersection",
    };
}

fn bindingKindName(kind: core.BindingResourceKind) []const u8 {
    return switch (kind) {
        .uniform_buffer => "uniform_buffer",
        .storage_buffer => "storage_buffer",
        .storage_texture => "storage_texture",
        .sampled_texture => "sampled_texture",
        .sampler => "sampler",
        .compare_sampler => "compare_sampler",
    };
}

test "runtime reflection parser reads rainbow cube shader shape" {
    const source =
        \\struct VertexInput
        \\{
        \\    float3 position : POSITION0;
        \\    float2 uv : TEXCOORD0;
        \\    float3 color : COLOR0;
        \\};
        \\
        \\struct VertexOutput
        \\{
        \\    float4 position : SV_Position;
        \\    float2 uv : TEXCOORD0;
        \\    float3 color : COLOR0;
        \\};
        \\
        \\struct Uniforms
        \\{
        \\    float4 transform_row0;
        \\};
        \\
        \\[[vk::binding(0, 0)]]
        \\ConstantBuffer<Uniforms> uniforms : register(b0, space0);
        \\
        \\[[vk::binding(1, 0)]]
        \\Texture2D<float4> sampled_texture : register(t1, space0);
        \\
        \\[[vk::binding(2, 0)]]
        \\SamplerState linear_sampler : register(s2, space0);
        \\
        \\[shader("vertex")]
        \\VertexOutput vs_main(VertexInput input)
        \\{
        \\    VertexOutput output;
        \\    output.position = float4(input.position, 1.0);
        \\    output.uv = input.uv;
        \\    output.color = input.color;
        \\    return output;
        \\}
        \\
        \\[shader("fragment")]
        \\float4 fs_main(VertexOutput input) : SV_Target0
        \\{
        \\    return sampled_texture.Sample(linear_sampler, input.uv) * float4(input.color, 1.0);
        \\}
    ;
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
    const source =
        \\[[vk::binding(0, 0)]]
        \\[[vk::image_format("rgba8")]]
        \\RWTexture2D<float4> output_texture : register(u0, space0);
        \\
        \\[[vk::binding(1, 0)]]
        \\RWStructuredBuffer<uint> output_values : register(u1, space0);
        \\
        \\[shader("compute")]
        \\[numthreads(4, 1, 1)]
        \\void cs_main(uint3 dispatch_id: SV_DispatchThreadID)
        \\{
        \\    output_values[dispatch_id.x] = dispatch_id.x;
        \\    output_texture[dispatch_id.xy] = float4(1.0, 0.0, 0.0, 1.0);
        \\}
    ;
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
        .vertex_spirv = "vertex-spv",
        .fragment_spirv = "fragment-spv",
        .vertex_msl = "vertex-msl",
        .fragment_msl = "fragment-msl",
        .vertex_reflection_json = "vertex-reflection",
        .fragment_reflection_json = "fragment-reflection",
        .vertex_entry = try allocator.dupe(u8, "vs_main"),
        .fragment_entry = try allocator.dupe(u8, "fs_main"),
    };
    defer shader.deinit();

    const stages = shader.stageDescriptors(.metal);
    try std.testing.expectEqual(core.ShaderStage.vertex, stages.vertex.stage);
    try std.testing.expectEqual(core.ShaderStage.fragment, stages.fragment.stage);
    try expectShaderSourceBytes(stages.vertex.module.source, .msl, "vertex-msl");
    try expectShaderSourceBytes(stages.fragment.module.source, .msl, "fragment-msl");
    try expectReflectionJson(stages.vertex.reflection, "vertex-reflection");
    try expectReflectionJson(stages.fragment.reflection, "fragment-reflection");
}

test "compiled ray tracing shader exposes backend-specific ray generation stage" {
    const allocator = std.testing.allocator;
    var shader = CompiledRayTracingShader{
        .allocator = allocator,
        .ray_generation_spirv = "raygen-spv",
        .miss_spirv = "miss-spv",
        .closest_hit_spirv = "closest-hit-spv",
        .any_hit_spirv = "any-hit-spv",
        .intersection_spirv = "intersection-spv",
        .ray_generation_msl = "raygen-msl",
        .ray_generation_reflection_json = "raygen-reflection",
        .miss_reflection_json = "miss-reflection",
        .closest_hit_reflection_json = "closest-hit-reflection",
        .any_hit_reflection_json = "any-hit-reflection",
        .intersection_reflection_json = "intersection-reflection",
        .ray_generation_entry = try allocator.dupe(u8, "raygen"),
        .miss_entry = try allocator.dupe(u8, "miss"),
        .closest_hit_entry = try allocator.dupe(u8, "closest_hit"),
        .any_hit_entry = try allocator.dupe(u8, "any_hit"),
        .intersection_entry = try allocator.dupe(u8, "intersection_main"),
    };
    defer shader.deinit();

    var metal_pipeline = core.RayTracingPipelineDescriptor{};
    shader.applyToPipelineDescriptor(.metal, &metal_pipeline);
    try std.testing.expect(metal_pipeline.ray_generation != null);
    try std.testing.expect(metal_pipeline.miss == null);
    try std.testing.expect(metal_pipeline.closest_hit == null);
    try std.testing.expect(metal_pipeline.any_hit == null);
    try expectShaderSourceBytes(metal_pipeline.ray_generation.?.module.source, .msl, "raygen-msl");

    var vulkan_pipeline = core.RayTracingPipelineDescriptor{};
    shader.applyToPipelineDescriptor(.vulkan, &vulkan_pipeline);
    try expectShaderSourceBytes(vulkan_pipeline.ray_generation.?.module.source, .spirv, "raygen-spv");
    try expectShaderSourceBytes(vulkan_pipeline.miss.?.module.source, .spirv, "miss-spv");
    try expectShaderSourceBytes(vulkan_pipeline.closest_hit.?.module.source, .spirv, "closest-hit-spv");
    try expectShaderSourceBytes(vulkan_pipeline.any_hit.?.module.source, .spirv, "any-hit-spv");
    try expectShaderSourceBytes(vulkan_pipeline.intersection.?.module.source, .spirv, "intersection-spv");
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

fn expectShaderSourceBytes(
    source: core.ShaderSource,
    language: core.ShaderSourceLanguage,
    bytes: []const u8,
) !void {
    switch (source) {
        .spirv_bytes => |actual| if (language == .spirv)
            try std.testing.expectEqualStrings(bytes, actual)
        else
            return error.UnexpectedShaderSource,
        .msl => |actual| if (language == .msl)
            try std.testing.expectEqualStrings(bytes, actual)
        else
            return error.UnexpectedShaderSource,
        else => return error.UnexpectedShaderSource,
    }
}

fn expectReflectionJson(
    source: ?core.ShaderReflectionSource,
    bytes: []const u8,
) !void {
    switch (source orelse return error.UnexpectedShaderReflectionSource) {
        .json => |actual| try std.testing.expectEqualStrings(bytes, actual),
        else => return error.UnexpectedShaderReflectionSource,
    }
}

fn expectContains(haystack: []const u8, needle: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, haystack, needle) != null);
}

test "vertex reflection names cover half and integer inputs" {
    try std.testing.expectEqual(core.VertexFormat.float16x2, parseFieldFormat("half2").?);
    try std.testing.expectEqual(core.VertexFormat.uint32x3, parseFieldFormat("uint3").?);
    try std.testing.expectEqual(core.VertexFormat.sint32x4, parseFieldFormat("int4").?);
    try std.testing.expectEqual(@as(u32, 8), vertexFormatSize(.float16x4));
    try std.testing.expectEqualStrings("unorm8x4", vertexFormatName(.unorm8x4));
}
