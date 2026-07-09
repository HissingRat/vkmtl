const std = @import("std");
const core = @import("../core.zig");
const artifact_loader = @import("artifact.zig");

const max_shader_reflection_bytes = 1024 * 1024;

pub const DerivedBindGroupLayouts = struct {
    allocator: std.mem.Allocator,
    layouts: []core.BindGroupLayoutDescriptor = &.{},

    pub fn descriptors(self: DerivedBindGroupLayouts) []const core.BindGroupLayoutDescriptor {
        return self.layouts;
    }

    pub fn deinit(self: *DerivedBindGroupLayouts) void {
        const allocator = self.allocator;
        for (self.layouts) |layout| {
            if (layout.entries.len != 0) allocator.free(layout.entries);
        }
        if (self.layouts.len != 0) allocator.free(self.layouts);
        self.* = .{ .allocator = allocator, .layouts = &.{} };
    }
};

pub const SingleBufferVertexLayoutOptions = struct {
    stride: u32,
    step_function: core.VertexStepFunction = .per_vertex,
};

pub const DerivedVertexDescriptor = struct {
    allocator: std.mem.Allocator,
    descriptor: core.VertexDescriptor = .{},

    pub fn deinit(self: *DerivedVertexDescriptor) void {
        const allocator = self.allocator;
        for (self.descriptor.buffers) |buffer| {
            if (buffer.attributes.len != 0) allocator.free(buffer.attributes);
        }
        if (self.descriptor.buffers.len != 0) allocator.free(self.descriptor.buffers);
        self.* = .{ .allocator = allocator, .descriptor = .{} };
    }
};

pub fn deriveSingleBufferVertexDescriptor(
    allocator: std.mem.Allocator,
    vertex: core.ProgrammableStageDescriptor,
    options: SingleBufferVertexLayoutOptions,
) !DerivedVertexDescriptor {
    var builder = VertexInputBuilder.init(allocator);
    defer builder.deinit();

    try builder.addVertexStage(vertex);
    return try builder.finishSingleBuffer(options);
}

pub fn deriveRenderPipelineBindGroupLayouts(
    allocator: std.mem.Allocator,
    vertex: core.ProgrammableStageDescriptor,
    fragment: ?core.ProgrammableStageDescriptor,
) !DerivedBindGroupLayouts {
    var builder = LayoutBuilder.init(allocator);
    defer builder.deinit();

    try builder.addStage(vertex, .vertex);
    if (fragment) |fragment_stage| {
        try builder.addStage(fragment_stage, .fragment);
    }

    return try builder.finish();
}

pub fn deriveComputePipelineBindGroupLayouts(
    allocator: std.mem.Allocator,
    compute: core.ProgrammableStageDescriptor,
) !DerivedBindGroupLayouts {
    var builder = LayoutBuilder.init(allocator);
    defer builder.deinit();

    try builder.addStage(compute, .compute);

    return try builder.finish();
}

pub fn validateRenderPipelineDescriptor(
    allocator: std.mem.Allocator,
    descriptor: core.RenderPipelineDescriptor,
) !void {
    try validateStage(allocator, descriptor.vertex, .vertex, descriptor.bind_group_layouts);
    if (descriptor.fragment) |fragment| {
        try validateStage(allocator, fragment, .fragment, descriptor.bind_group_layouts);
    }
}

pub fn validateComputePipelineDescriptor(
    allocator: std.mem.Allocator,
    descriptor: core.ComputePipelineDescriptor,
) !void {
    try validateStage(allocator, descriptor.compute, .compute, descriptor.bind_group_layouts);
}

fn validateStage(
    allocator: std.mem.Allocator,
    stage_descriptor: core.ProgrammableStageDescriptor,
    expected_stage: core.ShaderStage,
    bind_group_layouts: []const core.BindGroupLayoutDescriptor,
) !void {
    const source = stage_descriptor.reflection orelse return;
    switch (source) {
        .data => |reflection| try core.validateShaderStageReflection(
            stage_descriptor,
            expected_stage,
            reflection,
            bind_group_layouts,
        ),
        .json => |bytes| try validateJsonStageBytes(
            allocator,
            stage_descriptor,
            expected_stage,
            bytes,
            bind_group_layouts,
        ),
        .artifact => |artifact| try validateArtifactStage(
            allocator,
            stage_descriptor,
            expected_stage,
            artifact,
            bind_group_layouts,
        ),
    }
}

fn validateArtifactStage(
    allocator: std.mem.Allocator,
    stage_descriptor: core.ProgrammableStageDescriptor,
    expected_stage: core.ShaderStage,
    artifact: core.ShaderReflectionArtifact,
    bind_group_layouts: []const core.BindGroupLayoutDescriptor,
) !void {
    const bytes = artifact_loader.readFileBytes(allocator, artifact.path, max_shader_reflection_bytes) catch {
        return core.ShaderError.ShaderReflectionReadFailed;
    };
    defer allocator.free(bytes);

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, bytes, .{}) catch {
        return core.ShaderError.InvalidShaderReflection;
    };
    defer parsed.deinit();

    try validateJsonStage(stage_descriptor, expected_stage, parsed.value, bind_group_layouts);
}

fn validateJsonStageBytes(
    allocator: std.mem.Allocator,
    stage_descriptor: core.ProgrammableStageDescriptor,
    expected_stage: core.ShaderStage,
    bytes: []const u8,
    bind_group_layouts: []const core.BindGroupLayoutDescriptor,
) !void {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, bytes, .{}) catch {
        return core.ShaderError.InvalidShaderReflection;
    };
    defer parsed.deinit();

    try validateJsonStage(stage_descriptor, expected_stage, parsed.value, bind_group_layouts);
}

fn validateJsonStage(
    stage_descriptor: core.ProgrammableStageDescriptor,
    expected_stage: core.ShaderStage,
    root: std.json.Value,
    bind_group_layouts: []const core.BindGroupLayoutDescriptor,
) !void {
    try validateSchemaVersion(root);

    const stage = try parseStage(try requiredField(root, "stage"));
    if (stage != expected_stage or stage != stage_descriptor.stage) {
        return core.ShaderError.ShaderReflectionStageMismatch;
    }

    const entry_point = try expectString(try requiredField(root, "entry_point"));
    if (!std.mem.eql(u8, entry_point, stage_descriptor.entry_point)) {
        return core.ShaderError.ShaderReflectionEntryPointMismatch;
    }

    const bind_groups_value = optionalField(root, "bind_groups") orelse return;
    const bind_groups = try expectArray(bind_groups_value);
    for (bind_groups.items) |bind_group_value| {
        try validateJsonBindGroup(bind_group_value, bind_group_layouts);
    }
}

fn validateJsonBindGroup(
    value: std.json.Value,
    bind_group_layouts: []const core.BindGroupLayoutDescriptor,
) !void {
    const index = try expectU32(try requiredField(value, "index"));
    const layout_index: usize = @intCast(index);
    if (layout_index >= bind_group_layouts.len) {
        return core.ShaderError.ShaderReflectionMissingBindGroupLayout;
    }

    const bindings = try expectArray(try requiredField(value, "bindings"));
    for (bindings.items) |binding_value| {
        const reflected_binding = core.ShaderReflectionBinding{
            .binding = try expectU32(try requiredField(binding_value, "binding")),
            .resource = try parseResourceKind(try requiredField(binding_value, "kind")),
            .visibility = try parseVisibility(try requiredField(binding_value, "visibility")),
        };
        try core.validateShaderReflectionBinding(bind_group_layouts[layout_index], reflected_binding);
    }
}

const LayoutBuilder = struct {
    allocator: std.mem.Allocator,
    groups: std.ArrayList(Group) = .empty,

    const Group = struct {
        index: u32,
        entries: std.ArrayList(core.BindGroupLayoutEntry) = .empty,

        fn deinit(self: *Group, allocator: std.mem.Allocator) void {
            self.entries.deinit(allocator);
        }
    };

    fn init(allocator: std.mem.Allocator) LayoutBuilder {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *LayoutBuilder) void {
        for (self.groups.items) |*group| {
            group.deinit(self.allocator);
        }
        self.groups.deinit(self.allocator);
    }

    fn addStage(
        self: *LayoutBuilder,
        stage_descriptor: core.ProgrammableStageDescriptor,
        expected_stage: core.ShaderStage,
    ) !void {
        try stage_descriptor.validate(expected_stage);

        const source = stage_descriptor.reflection orelse return;
        switch (source) {
            .data => |reflection| try self.addStageReflection(stage_descriptor, expected_stage, reflection),
            .json => |bytes| try self.addJsonStageBytes(stage_descriptor, expected_stage, bytes),
            .artifact => |artifact| try self.addArtifactStage(stage_descriptor, expected_stage, artifact),
        }
    }

    fn addStageReflection(
        self: *LayoutBuilder,
        stage_descriptor: core.ProgrammableStageDescriptor,
        expected_stage: core.ShaderStage,
        reflection: core.ShaderStageReflection,
    ) !void {
        if (reflection.stage != expected_stage or reflection.stage != stage_descriptor.stage) {
            return core.ShaderError.ShaderReflectionStageMismatch;
        }
        if (!std.mem.eql(u8, reflection.entry_point, stage_descriptor.entry_point)) {
            return core.ShaderError.ShaderReflectionEntryPointMismatch;
        }

        for (reflection.bind_groups) |bind_group| {
            for (bind_group.bindings) |binding| {
                try self.addBinding(bind_group.index, binding);
            }
        }
    }

    fn addArtifactStage(
        self: *LayoutBuilder,
        stage_descriptor: core.ProgrammableStageDescriptor,
        expected_stage: core.ShaderStage,
        artifact: core.ShaderReflectionArtifact,
    ) !void {
        const bytes = artifact_loader.readFileBytes(self.allocator, artifact.path, max_shader_reflection_bytes) catch {
            return core.ShaderError.ShaderReflectionReadFailed;
        };
        defer self.allocator.free(bytes);

        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, bytes, .{}) catch {
            return core.ShaderError.InvalidShaderReflection;
        };
        defer parsed.deinit();

        try self.addJsonStage(stage_descriptor, expected_stage, parsed.value);
    }

    fn addJsonStageBytes(
        self: *LayoutBuilder,
        stage_descriptor: core.ProgrammableStageDescriptor,
        expected_stage: core.ShaderStage,
        bytes: []const u8,
    ) !void {
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, bytes, .{}) catch {
            return core.ShaderError.InvalidShaderReflection;
        };
        defer parsed.deinit();

        try self.addJsonStage(stage_descriptor, expected_stage, parsed.value);
    }

    fn addJsonStage(
        self: *LayoutBuilder,
        stage_descriptor: core.ProgrammableStageDescriptor,
        expected_stage: core.ShaderStage,
        root: std.json.Value,
    ) !void {
        try validateSchemaVersion(root);

        const stage = try parseStage(try requiredField(root, "stage"));
        if (stage != expected_stage or stage != stage_descriptor.stage) {
            return core.ShaderError.ShaderReflectionStageMismatch;
        }

        const entry_point = try expectString(try requiredField(root, "entry_point"));
        if (!std.mem.eql(u8, entry_point, stage_descriptor.entry_point)) {
            return core.ShaderError.ShaderReflectionEntryPointMismatch;
        }

        const bind_groups_value = optionalField(root, "bind_groups") orelse return;
        const bind_groups = try expectArray(bind_groups_value);
        for (bind_groups.items) |bind_group_value| {
            try self.addJsonBindGroup(bind_group_value);
        }
    }

    fn addJsonBindGroup(
        self: *LayoutBuilder,
        value: std.json.Value,
    ) !void {
        const index = try expectU32(try requiredField(value, "index"));
        const bindings = try expectArray(try requiredField(value, "bindings"));
        for (bindings.items) |binding_value| {
            try self.addBinding(index, .{
                .binding = try expectU32(try requiredField(binding_value, "binding")),
                .resource = try parseResourceKind(try requiredField(binding_value, "kind")),
                .visibility = try parseVisibility(try requiredField(binding_value, "visibility")),
            });
        }
    }

    fn addBinding(
        self: *LayoutBuilder,
        group_index: u32,
        binding: core.ShaderReflectionBinding,
    ) !void {
        if (binding.visibility.isEmpty()) return core.ShaderError.InvalidShaderReflection;

        const group = try self.groupForIndex(group_index);
        for (group.entries.items) |*entry| {
            if (entry.binding == binding.binding) {
                if (entry.resource != binding.resource) {
                    return core.ShaderError.ShaderReflectionBindingKindMismatch;
                }
                entry.visibility = mergeVisibility(entry.visibility, binding.visibility);
                return;
            }
        }

        try group.entries.append(self.allocator, .{
            .binding = binding.binding,
            .resource = binding.resource,
            .visibility = binding.visibility,
        });
    }

    fn groupForIndex(self: *LayoutBuilder, index: u32) !*Group {
        for (self.groups.items) |*group| {
            if (group.index == index) return group;
        }

        try self.groups.append(self.allocator, .{ .index = index });
        return &self.groups.items[self.groups.items.len - 1];
    }

    fn finish(self: *LayoutBuilder) !DerivedBindGroupLayouts {
        sortGroupsAndEntries(self.groups.items);

        if (self.groups.items.len == 0) {
            return .{ .allocator = self.allocator, .layouts = &.{} };
        }

        for (self.groups.items, 0..) |group, expected_index| {
            if (group.index != @as(u32, @intCast(expected_index)) or group.entries.items.len == 0) {
                return core.ShaderError.InvalidShaderReflection;
            }
        }

        const layouts = try self.allocator.alloc(core.BindGroupLayoutDescriptor, self.groups.items.len);
        var written_count: usize = 0;
        errdefer {
            for (layouts[0..written_count]) |layout| {
                if (layout.entries.len != 0) self.allocator.free(layout.entries);
            }
            self.allocator.free(layouts);
        }

        for (self.groups.items, 0..) |group, index| {
            layouts[index] = .{
                .entries = try self.allocator.dupe(core.BindGroupLayoutEntry, group.entries.items),
            };
            written_count += 1;
            try layouts[index].validate();
        }

        return .{ .allocator = self.allocator, .layouts = layouts };
    }
};

const VertexInputBuilder = struct {
    allocator: std.mem.Allocator,
    attributes: std.ArrayList(core.VertexAttributeDescriptor) = .empty,

    fn init(allocator: std.mem.Allocator) VertexInputBuilder {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *VertexInputBuilder) void {
        self.attributes.deinit(self.allocator);
    }

    fn addVertexStage(
        self: *VertexInputBuilder,
        stage_descriptor: core.ProgrammableStageDescriptor,
    ) !void {
        try stage_descriptor.validate(.vertex);

        const source = stage_descriptor.reflection orelse return;
        switch (source) {
            .data => |reflection| try self.addVertexStageReflection(stage_descriptor, reflection),
            .json => |bytes| try self.addJsonVertexStageBytes(stage_descriptor, bytes),
            .artifact => |artifact| try self.addArtifactVertexStage(stage_descriptor, artifact),
        }
    }

    fn addVertexStageReflection(
        self: *VertexInputBuilder,
        stage_descriptor: core.ProgrammableStageDescriptor,
        reflection: core.ShaderStageReflection,
    ) !void {
        if (reflection.stage != .vertex or reflection.stage != stage_descriptor.stage) {
            return core.ShaderError.ShaderReflectionStageMismatch;
        }
        if (!std.mem.eql(u8, reflection.entry_point, stage_descriptor.entry_point)) {
            return core.ShaderError.ShaderReflectionEntryPointMismatch;
        }

        for (reflection.vertex_inputs) |input| {
            try self.addVertexInput(input);
        }
    }

    fn addArtifactVertexStage(
        self: *VertexInputBuilder,
        stage_descriptor: core.ProgrammableStageDescriptor,
        artifact: core.ShaderReflectionArtifact,
    ) !void {
        const bytes = artifact_loader.readFileBytes(self.allocator, artifact.path, max_shader_reflection_bytes) catch {
            return core.ShaderError.ShaderReflectionReadFailed;
        };
        defer self.allocator.free(bytes);

        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, bytes, .{}) catch {
            return core.ShaderError.InvalidShaderReflection;
        };
        defer parsed.deinit();

        try self.addJsonVertexStage(stage_descriptor, parsed.value);
    }

    fn addJsonVertexStageBytes(
        self: *VertexInputBuilder,
        stage_descriptor: core.ProgrammableStageDescriptor,
        bytes: []const u8,
    ) !void {
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, bytes, .{}) catch {
            return core.ShaderError.InvalidShaderReflection;
        };
        defer parsed.deinit();

        try self.addJsonVertexStage(stage_descriptor, parsed.value);
    }

    fn addJsonVertexStage(
        self: *VertexInputBuilder,
        stage_descriptor: core.ProgrammableStageDescriptor,
        root: std.json.Value,
    ) !void {
        try validateSchemaVersion(root);

        const stage = try parseStage(try requiredField(root, "stage"));
        if (stage != .vertex or stage != stage_descriptor.stage) {
            return core.ShaderError.ShaderReflectionStageMismatch;
        }

        const entry_point = try expectString(try requiredField(root, "entry_point"));
        if (!std.mem.eql(u8, entry_point, stage_descriptor.entry_point)) {
            return core.ShaderError.ShaderReflectionEntryPointMismatch;
        }

        const vertex_inputs_value = optionalField(root, "vertex_inputs") orelse return;
        const vertex_inputs = try expectArray(vertex_inputs_value);
        for (vertex_inputs.items) |vertex_input_value| {
            try self.addJsonVertexInput(vertex_input_value);
        }
    }

    fn addJsonVertexInput(
        self: *VertexInputBuilder,
        value: std.json.Value,
    ) !void {
        try self.addVertexInput(.{
            .location = try expectU32(try requiredField(value, "location")),
            .format = try parseVertexFormat(try requiredField(value, "format")),
            .offset = try expectU32(try requiredField(value, "offset")),
        });
    }

    fn addVertexInput(
        self: *VertexInputBuilder,
        input: core.ShaderReflectionVertexInput,
    ) !void {
        try self.attributes.append(self.allocator, .{
            .location = input.location,
            .format = input.format,
            .offset = input.offset,
        });
    }

    fn finishSingleBuffer(
        self: *VertexInputBuilder,
        options: SingleBufferVertexLayoutOptions,
    ) !DerivedVertexDescriptor {
        std.sort.block(core.VertexAttributeDescriptor, self.attributes.items, {}, vertexAttributeLessThan);

        for (self.attributes.items[0..], 0..) |attribute, index| {
            if (index != 0 and attribute.location == self.attributes.items[index - 1].location) {
                return core.ShaderError.InvalidShaderReflection;
            }
        }

        if (self.attributes.items.len == 0) {
            return .{ .allocator = self.allocator, .descriptor = .{} };
        }

        const attributes = try self.allocator.dupe(core.VertexAttributeDescriptor, self.attributes.items);
        errdefer self.allocator.free(attributes);

        const buffers = try self.allocator.alloc(core.VertexBufferLayoutDescriptor, 1);
        errdefer self.allocator.free(buffers);

        buffers[0] = .{
            .stride = options.stride,
            .step_function = options.step_function,
            .attributes = attributes,
        };

        const descriptor = core.VertexDescriptor{ .buffers = buffers };
        try descriptor.validate();

        return .{
            .allocator = self.allocator,
            .descriptor = descriptor,
        };
    }
};

fn sortGroupsAndEntries(groups: []LayoutBuilder.Group) void {
    std.sort.block(LayoutBuilder.Group, groups, {}, groupLessThan);
    for (groups) |*group| {
        std.sort.block(core.BindGroupLayoutEntry, group.entries.items, {}, layoutEntryLessThan);
    }
}

fn groupLessThan(_: void, lhs: LayoutBuilder.Group, rhs: LayoutBuilder.Group) bool {
    return lhs.index < rhs.index;
}

fn layoutEntryLessThan(_: void, lhs: core.BindGroupLayoutEntry, rhs: core.BindGroupLayoutEntry) bool {
    return lhs.binding < rhs.binding;
}

fn vertexAttributeLessThan(_: void, lhs: core.VertexAttributeDescriptor, rhs: core.VertexAttributeDescriptor) bool {
    return lhs.location < rhs.location;
}

fn requiredField(value: std.json.Value, name: []const u8) !std.json.Value {
    const object = switch (value) {
        .object => |object| object,
        else => return core.ShaderError.InvalidShaderReflection,
    };
    return object.get(name) orelse return core.ShaderError.InvalidShaderReflection;
}

fn optionalField(value: std.json.Value, name: []const u8) ?std.json.Value {
    const object = switch (value) {
        .object => |object| object,
        else => return null,
    };
    return object.get(name);
}

fn expectString(value: std.json.Value) ![]const u8 {
    return switch (value) {
        .string => |string| string,
        else => core.ShaderError.InvalidShaderReflection,
    };
}

fn expectArray(value: std.json.Value) !std.json.Array {
    return switch (value) {
        .array => |array| array,
        else => core.ShaderError.InvalidShaderReflection,
    };
}

fn expectU32(value: std.json.Value) !u32 {
    return switch (value) {
        .integer => |integer| blk: {
            if (integer < 0 or integer > std.math.maxInt(u32)) {
                return core.ShaderError.InvalidShaderReflection;
            }
            break :blk @intCast(integer);
        },
        else => core.ShaderError.InvalidShaderReflection,
    };
}

fn validateSchemaVersion(root: std.json.Value) !void {
    const value = optionalField(root, "schema_version") orelse return;
    const version = try expectU32(value);
    if (version != core.shader_reflection_schema_version) {
        return core.ShaderError.UnsupportedShaderReflectionSchema;
    }
}

fn parseStage(value: std.json.Value) !core.ShaderStage {
    const stage = try expectString(value);
    if (std.mem.eql(u8, stage, "vertex")) return .vertex;
    if (std.mem.eql(u8, stage, "fragment")) return .fragment;
    if (std.mem.eql(u8, stage, "compute")) return .compute;
    return core.ShaderError.InvalidShaderReflection;
}

fn parseResourceKind(value: std.json.Value) !core.BindingResourceKind {
    const kind = try expectString(value);
    if (std.mem.eql(u8, kind, "uniform_buffer")) return .uniform_buffer;
    if (std.mem.eql(u8, kind, "storage_buffer")) return .storage_buffer;
    if (std.mem.eql(u8, kind, "storage_texture")) return .storage_texture;
    if (std.mem.eql(u8, kind, "sampled_texture")) return .sampled_texture;
    if (std.mem.eql(u8, kind, "sampler")) return .sampler;
    if (std.mem.eql(u8, kind, "compare_sampler")) return .compare_sampler;
    return core.ShaderError.InvalidShaderReflection;
}

fn parseVertexFormat(value: std.json.Value) !core.VertexFormat {
    const format = try expectString(value);
    if (std.mem.eql(u8, format, "float32")) return .float32;
    if (std.mem.eql(u8, format, "float32x2")) return .float32x2;
    if (std.mem.eql(u8, format, "float32x3")) return .float32x3;
    if (std.mem.eql(u8, format, "float32x4")) return .float32x4;
    return core.ShaderError.InvalidShaderReflection;
}

fn parseVisibility(value: std.json.Value) !core.ShaderVisibility {
    return switch (value) {
        .string => |stage| try visibilityFromString(stage),
        .array => |stages| blk: {
            var visibility = core.ShaderVisibility{};
            for (stages.items) |stage_value| {
                visibility = mergeVisibility(visibility, try visibilityFromString(try expectString(stage_value)));
            }
            if (visibility.isEmpty()) return core.ShaderError.InvalidShaderReflection;
            break :blk visibility;
        },
        else => core.ShaderError.InvalidShaderReflection,
    };
}

fn visibilityFromString(stage: []const u8) !core.ShaderVisibility {
    if (std.mem.eql(u8, stage, "vertex")) return .{ .vertex = true };
    if (std.mem.eql(u8, stage, "fragment")) return .{ .fragment = true };
    if (std.mem.eql(u8, stage, "compute")) return .{ .compute = true };
    return core.ShaderError.InvalidShaderReflection;
}

fn mergeVisibility(a: core.ShaderVisibility, b: core.ShaderVisibility) core.ShaderVisibility {
    return .{
        .vertex = a.vertex or b.vertex,
        .fragment = a.fragment or b.fragment,
        .compute = a.compute or b.compute,
    };
}

test "reflection artifact validates bind group layout" {
    const json =
        \\{
        \\  "schema_version": 1,
        \\  "stage": "compute",
        \\  "entry_point": "cs_main",
        \\  "bind_groups": [
        \\    {
        \\      "index": 0,
        \\      "bindings": [
        \\        {
        \\          "binding": 0,
        \\          "kind": "storage_buffer",
        \\          "visibility": "compute"
        \\        }
        \\      ]
        \\    }
        \\  ]
        \\}
    ;
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    const bind_group_layouts = [_]core.BindGroupLayoutDescriptor{
        .{ .entries = &.{.{
            .binding = 0,
            .resource = .storage_buffer,
            .visibility = .{ .compute = true },
        }} },
    };
    const stage_descriptor = core.ProgrammableStageDescriptor{
        .module = .{ .source = .{ .slang = "[shader(\"compute\")] [numthreads(1, 1, 1)] void cs_main() {}" } },
        .stage = .compute,
        .entry_point = "cs_main",
    };
    try validateJsonStage(stage_descriptor, .compute, parsed.value, bind_group_layouts[0..]);

    const legacy_json =
        \\{
        \\  "stage": "compute",
        \\  "entry_point": "cs_main",
        \\  "bind_groups": []
        \\}
    ;
    var legacy = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, legacy_json, .{});
    defer legacy.deinit();
    try validateJsonStage(stage_descriptor, .compute, legacy.value, bind_group_layouts[0..]);

    const future_json =
        \\{
        \\  "schema_version": 999,
        \\  "stage": "compute",
        \\  "entry_point": "cs_main",
        \\  "bind_groups": []
        \\}
    ;
    var future = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, future_json, .{});
    defer future.deinit();
    try std.testing.expectError(core.ShaderError.UnsupportedShaderReflectionSchema, validateJsonStage(stage_descriptor, .compute, future.value, bind_group_layouts[0..]));
}

test "derived render bind group layouts merge stage visibility" {
    const vertex_bindings = [_]core.ShaderReflectionBinding{
        .{
            .binding = 0,
            .resource = .uniform_buffer,
            .visibility = .{ .vertex = true },
        },
    };
    const vertex_groups = [_]core.ShaderReflectionBindGroup{
        .{ .index = 0, .bindings = vertex_bindings[0..] },
    };
    const fragment_bindings = [_]core.ShaderReflectionBinding{
        .{
            .binding = 0,
            .resource = .uniform_buffer,
            .visibility = .{ .fragment = true },
        },
    };
    const fragment_groups = [_]core.ShaderReflectionBindGroup{
        .{ .index = 0, .bindings = fragment_bindings[0..] },
    };

    var layouts = try deriveRenderPipelineBindGroupLayouts(
        std.testing.allocator,
        .{
            .module = .{ .source = .{ .slang = "vertex stage" } },
            .stage = .vertex,
            .entry_point = "vs_main",
            .reflection = .{ .data = .{
                .stage = .vertex,
                .entry_point = "vs_main",
                .bind_groups = vertex_groups[0..],
            } },
        },
        .{
            .module = .{ .source = .{ .slang = "fragment stage" } },
            .stage = .fragment,
            .entry_point = "fs_main",
            .reflection = .{ .data = .{
                .stage = .fragment,
                .entry_point = "fs_main",
                .bind_groups = fragment_groups[0..],
            } },
        },
    );
    defer layouts.deinit();

    try std.testing.expectEqual(@as(usize, 1), layouts.descriptors().len);
    const entries = layouts.descriptors()[0].entries;
    try std.testing.expectEqual(@as(usize, 1), entries.len);
    try std.testing.expectEqual(@as(u32, 0), entries[0].binding);
    try std.testing.expectEqual(core.BindingResourceKind.uniform_buffer, entries[0].resource);
    try std.testing.expect(entries[0].visibility.vertex);
    try std.testing.expect(entries[0].visibility.fragment);
    try std.testing.expect(!entries[0].visibility.compute);
}

test "derived single-buffer vertex descriptor uses reflected vertex inputs" {
    const vertex_inputs = [_]core.ShaderReflectionVertexInput{
        .{ .location = 1, .format = .float32x3, .offset = 8 },
        .{ .location = 0, .format = .float32x2, .offset = 0 },
    };

    var vertex_descriptor = try deriveSingleBufferVertexDescriptor(
        std.testing.allocator,
        .{
            .module = .{ .source = .{ .slang = "vertex stage" } },
            .stage = .vertex,
            .entry_point = "vs_main",
            .reflection = .{ .data = .{
                .stage = .vertex,
                .entry_point = "vs_main",
                .vertex_inputs = vertex_inputs[0..],
            } },
        },
        .{ .stride = 20 },
    );
    defer vertex_descriptor.deinit();

    try std.testing.expectEqual(@as(usize, 1), vertex_descriptor.descriptor.buffers.len);
    const buffer = vertex_descriptor.descriptor.buffers[0];
    try std.testing.expectEqual(@as(u32, 20), buffer.stride);
    try std.testing.expectEqual(core.VertexStepFunction.per_vertex, buffer.step_function);
    try std.testing.expectEqual(@as(usize, 2), buffer.attributes.len);
    try std.testing.expectEqual(@as(u32, 0), buffer.attributes[0].location);
    try std.testing.expectEqual(core.VertexFormat.float32x2, buffer.attributes[0].format);
    try std.testing.expectEqual(@as(u32, 0), buffer.attributes[0].offset);
    try std.testing.expectEqual(@as(u32, 1), buffer.attributes[1].location);
    try std.testing.expectEqual(core.VertexFormat.float32x3, buffer.attributes[1].format);
    try std.testing.expectEqual(@as(u32, 8), buffer.attributes[1].offset);
}
