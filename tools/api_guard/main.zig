const std = @import("std");

const vkmtl_source = @embedFile("src/vkmtl.zig");
const runtime_source = @embedFile("src/runtime/window_context.zig");

const max_names = 256;
const max_fields = 64;

const facade_names = [_][]const u8{
    "resource",
    "transfer",
    "render",
    "sync",
    "presentation",
    "diagnostics",
    "command",
    "shader",
    "binding",
    "compute",
    "ray_tracing",
    "interop",
    "native",
};

const core_names = [_][]const u8{
    "BackendPreference",
    "Backend",
    "AdapterDeviceType",
    "AdapterPowerPreference",
    "AdapterInfo",
    "AdapterSelectionDescriptor",
    "AdapterList",
    "BackendAvailability",
    "BackendSelectionOptions",
    "BackendSelectionError",
    "Extent2D",
    "selectBackend",
    "enumerateAdapters",
    "WindowContext",
    "WindowContextOptions",
    "Buffer",
    "MappedBufferRange",
    "Texture",
    "TextureView",
    "SamplerState",
    "ShaderModule",
    "RenderPipelineState",
    "ComputePipelineState",
    "Device",
    "Queue",
    "Surface",
    "Swapchain",
};

const root_alias_names = [_][]const u8{
    "DeviceFeatures",
    "DeviceLimits",
    "SurfaceProvider",
    "SurfaceSource",
    "SurfaceDescriptor",
    "PresentMode",
    "PresentationDescriptor",
    "FormatCapabilities",
    "TextureFormat",
    "BufferUsage",
    "ResourceStorageMode",
    "TextureUsage",
    "BufferDescriptor",
    "TextureDescriptor",
    "TextureViewDescriptor",
    "SamplerDescriptor",
    "ShaderModuleDescriptor",
    "ProgrammableStageDescriptor",
    "VertexDescriptor",
    "RenderPipelineColorAttachmentDescriptor",
    "RenderPipelineDescriptor",
    "RenderPassDescriptor",
    "ClearColor",
    "ComputePipelineDescriptor",
    "BindGroupLayoutDescriptor",
    "BindGroupDescriptor",
    "BindGroupEntry",
    "CommandBufferDescriptor",
};

const expected_root_names = facade_names ++ core_names ++ root_alias_names;

const expected_device_methods = [_][]const u8{
    "selectedBackend",
    "adapterInfo",
    "features",
    "nativeFeatures",
    "limits",
    "capabilityReport",
    "makeAccelerationStructure",
    "makeRayTracingPipelineState",
    "makeShaderBindingTable",
    "getFormatCaps",
    "makeFence",
    "makeEvent",
    "makeQuerySet",
    "makeHeap",
    "queue",
    "queueWithDescriptor",
    "compileRenderShader",
    "compileComputeShader",
    "compileRayTracingShader",
    "makeBuffer",
    "makeShaderModule",
    "makeRenderPipelineState",
    "makeComputePipelineState",
    "makeBindGroupLayout",
    "makeAdvancedBindGroupLayout",
    "makeResourceTable",
    "makeBindGroup",
    "makeTexture",
    "makeExternalMemory",
    "makeExternalBuffer",
    "makeExternalSemaphore",
    "makeExternalEvent",
    "makeExternalTexture",
    "makeSamplerState",
};

const expected_window_context_methods = [_][]const u8{
    "init",
    "deinit",
    "selectedBackend",
    "adapterInfo",
    "nativeHandles",
    "nativeHandleView",
    "device",
    "queue",
    "surface",
    "swapchain",
};

// Complete root/facade-reachable runtime handle set. The source scan below
// makes additions and removals intentional instead of silently widening it.
const expected_runtime_handle_names = [_][]const u8{
    "WindowContext",
    "Device",
    "Queue",
    "Surface",
    "Swapchain",
    "Buffer",
    "MappedBufferRange",
    "Texture",
    "TextureView",
    "SamplerState",
    "ShaderModule",
    "RenderPipelineState",
    "ComputePipelineState",
    "BindGroupLayout",
    "AdvancedBindGroupLayout",
    "ResourceTable",
    "BindGroup",
    "ExternalMemory",
    "ExternalBuffer",
    "ExternalSemaphore",
    "ExternalEvent",
    "ExternalTexture",
    "Fence",
    "Event",
    "Heap",
    "QuerySet",
    "AccelerationStructure",
    "RayTracingPipelineState",
    "ShaderBindingTable",
    "MetalRayTracingExecutionMapping",
    "CommandBuffer",
    "BlitCommandEncoder",
    "ComputeCommandEncoder",
    "RenderCommandEncoder",
    "CaptureScope",
};

comptime {
    if (facade_names.len != 13) @compileError("API guard facade allowlist must contain 13 names");
    if (core_names.len != 27) @compileError("API guard core allowlist must contain 27 names");
    if (root_alias_names.len != 28) @compileError("API guard root alias allowlist must contain 28 names");
    if (expected_root_names.len != 68) @compileError("API guard root allowlist must contain 68 names");
    if (expected_device_methods.len != 34) @compileError("API guard Device allowlist must contain 34 names");
    if (expected_window_context_methods.len != 10) @compileError("API guard WindowContext allowlist must contain 10 names");
    if (expected_runtime_handle_names.len != 35) @compileError("API guard runtime handle allowlist must contain 35 names");
}

const ParseError = error{
    DuplicateRegion,
    MalformedDeclaration,
    MissingRegion,
    TooManyNames,
    UnterminatedRegion,
};

const NameList = struct {
    items: [max_names][]const u8 = undefined,
    len: usize = 0,

    fn append(self: *NameList, name: []const u8) ParseError!void {
        if (self.len == self.items.len) return ParseError.TooManyNames;
        self.items[self.len] = name;
        self.len += 1;
    }

    fn slice(self: *const NameList) []const []const u8 {
        return self.items[0..self.len];
    }
};

const StructField = struct {
    name: []const u8,
    type_expression: []const u8,
};

const StructFieldList = struct {
    items: [max_fields]StructField = undefined,
    len: usize = 0,

    fn append(self: *StructFieldList, field: StructField) ParseError!void {
        if (self.len == self.items.len) return ParseError.TooManyNames;
        self.items[self.len] = field;
        self.len += 1;
    }

    fn slice(self: *const StructFieldList) []const StructField {
        return self.items[0..self.len];
    }
};

const HandleLayoutIssue = enum {
    forbidden_representation,
    expected_single_state_field,
    expected_state_field_name,
    invalid_state_storage,
};

const HandleLayoutSummary = struct {
    issue: ?HandleLayoutIssue = null,
    field_index: ?usize = null,
    field_count: usize,

    fn passed(self: HandleLayoutSummary) bool {
        return self.issue == null;
    }
};

const ValidationSummary = struct {
    count_mismatch: bool,
    duplicates: usize,
    unknown: usize,
    missing: usize,

    fn passed(self: ValidationSummary) bool {
        return !self.count_mismatch and self.duplicates == 0 and self.unknown == 0 and self.missing == 0;
    }
};

pub fn main(_: std.process.Init) !void {
    const root_names = parseRootPubConstNames(vkmtl_source) catch |err| {
        std.debug.print("api guard: could not parse src/vkmtl.zig: {s}\n", .{@errorName(err)});
        return error.ApiGuardFailed;
    };
    const device_methods = parseStructPublicMethods(runtime_source, "Device") catch |err| {
        std.debug.print("api guard: could not parse Device in src/runtime/window_context.zig: {s}\n", .{@errorName(err)});
        return error.ApiGuardFailed;
    };
    const window_context_methods = parseStructPublicMethods(runtime_source, "WindowContext") catch |err| {
        std.debug.print("api guard: could not parse WindowContext in src/runtime/window_context.zig: {s}\n", .{@errorName(err)});
        return error.ApiGuardFailed;
    };
    const runtime_handle_names = parseOpaqueRuntimeHandleNames(runtime_source) catch |err| {
        std.debug.print("api guard: could not discover opaque runtime handles in src/runtime/window_context.zig: {s}\n", .{@errorName(err)});
        return error.ApiGuardFailed;
    };

    const root_ok = reportNameSet("root pub const", root_names.slice(), expected_root_names[0..]);
    const device_ok = reportNameSet("Device public method", device_methods.slice(), expected_device_methods[0..]);
    const window_context_ok = reportNameSet(
        "WindowContext public method",
        window_context_methods.slice(),
        expected_window_context_methods[0..],
    );
    var runtime_handles_ok = reportNameSet(
        "opaque runtime handle",
        runtime_handle_names.slice(),
        expected_runtime_handle_names[0..],
    );
    for (expected_runtime_handle_names) |handle_name| {
        const fields = parseStructFields(runtime_source, handle_name) catch |err| {
            std.debug.print(
                "api guard: could not parse runtime handle {s} in src/runtime/window_context.zig: {s}\n",
                .{ handle_name, @errorName(err) },
            );
            runtime_handles_ok = false;
            continue;
        };
        runtime_handles_ok = reportRuntimeHandleLayout(handle_name, fields.slice()) and runtime_handles_ok;
    }
    if (!root_ok or !device_ok or !window_context_ok or !runtime_handles_ok) return error.ApiGuardFailed;

    std.debug.print(
        "API guard passed: root=68 (facades=13 core=27 aliases=28), Device methods=34, WindowContext methods=10, runtime handles=35\n",
        .{},
    );
}

fn parseRootPubConstNames(source: []const u8) ParseError!NameList {
    var names = NameList{};
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        if (!std.mem.startsWith(u8, line, "pub const ")) continue;
        try names.append(try parseDeclarationName(line, "pub const ", '='));
    }
    return names;
}

fn parseStructPublicMethods(source: []const u8, struct_name: []const u8) ParseError!NameList {
    var marker_buffer: [128]u8 = undefined;
    const marker = std.fmt.bufPrint(&marker_buffer, "pub const {s} = struct {{", .{struct_name}) catch {
        return ParseError.MalformedDeclaration;
    };
    var names = NameList{};
    var found = false;
    var inside = false;
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        if (std.mem.eql(u8, line, marker)) {
            if (found) return ParseError.DuplicateRegion;
            found = true;
            inside = true;
            continue;
        }
        if (!inside) continue;
        if (std.mem.eql(u8, line, "};")) {
            inside = false;
            continue;
        }
        if (!std.mem.startsWith(u8, line, "    pub fn ")) continue;
        try names.append(try parseDeclarationName(line, "    pub fn ", '('));
    }
    if (!found) return ParseError.MissingRegion;
    if (inside) return ParseError.UnterminatedRegion;
    return names;
}

fn parseStructFields(source: []const u8, struct_name: []const u8) ParseError!StructFieldList {
    var marker_buffer: [128]u8 = undefined;
    const marker = std.fmt.bufPrint(&marker_buffer, "pub const {s} = struct {{", .{struct_name}) catch {
        return ParseError.MalformedDeclaration;
    };
    var fields = StructFieldList{};
    var found = false;
    var inside = false;
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        if (std.mem.eql(u8, line, marker)) {
            if (found) return ParseError.DuplicateRegion;
            found = true;
            inside = true;
            continue;
        }
        if (!inside) continue;
        if (std.mem.eql(u8, line, "};")) {
            inside = false;
            continue;
        }
        if (try parseTopLevelStructField(line)) |field| try fields.append(field);
    }
    if (!found) return ParseError.MissingRegion;
    if (inside) return ParseError.UnterminatedRegion;
    return fields;
}

fn parseOpaqueRuntimeHandleNames(source: []const u8) ParseError!NameList {
    var names = NameList{};
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        const struct_name = parseTopLevelStructName(line) orelse continue;
        const fields = try parseStructFields(source, struct_name);
        for (fields.slice()) |field| {
            if (std.mem.eql(u8, field.name, "_state")) {
                try names.append(struct_name);
                break;
            }
        }
    }
    return names;
}

fn parseTopLevelStructName(line: []const u8) ?[]const u8 {
    const prefix = "pub const ";
    const suffix = " = struct {";
    if (!std.mem.startsWith(u8, line, prefix) or !std.mem.endsWith(u8, line, suffix)) return null;
    const name = line[prefix.len .. line.len - suffix.len];
    return if (isIdentifier(name)) name else null;
}

fn parseTopLevelStructField(line: []const u8) ParseError!?StructField {
    if (!std.mem.startsWith(u8, line, "    ") or std.mem.startsWith(u8, line, "        ")) return null;
    const declaration = std.mem.trim(u8, line[4..], " \t");
    const colon_index = std.mem.indexOfScalar(u8, declaration, ':') orelse return null;
    const name = std.mem.trim(u8, declaration[0..colon_index], " \t");
    if (!isIdentifier(name)) return null;

    var type_expression = std.mem.trim(u8, declaration[colon_index + 1 ..], " \t");
    if (!std.mem.endsWith(u8, type_expression, ",")) return ParseError.MalformedDeclaration;
    type_expression = std.mem.trim(u8, type_expression[0 .. type_expression.len - 1], " \t");
    if (type_expression.len == 0) return ParseError.MalformedDeclaration;
    return .{ .name = name, .type_expression = type_expression };
}

fn isIdentifier(value: []const u8) bool {
    if (value.len == 0 or !(std.ascii.isAlphabetic(value[0]) or value[0] == '_')) return false;
    for (value[1..]) |character| {
        if (!(std.ascii.isAlphanumeric(character) or character == '_')) return false;
    }
    return true;
}

fn analyzeRuntimeHandleLayout(fields: []const StructField) HandleLayoutSummary {
    for (fields, 0..) |field, index| {
        if (isForbiddenHandleRepresentation(field)) {
            return .{
                .issue = .forbidden_representation,
                .field_index = index,
                .field_count = fields.len,
            };
        }
    }
    if (fields.len != 1) {
        return .{ .issue = .expected_single_state_field, .field_count = fields.len };
    }
    if (!std.mem.eql(u8, fields[0].name, "_state")) {
        return .{
            .issue = .expected_state_field_name,
            .field_index = 0,
            .field_count = fields.len,
        };
    }
    if (!isAllowedOpaqueStateStorage(fields[0].type_expression)) {
        return .{
            .issue = .invalid_state_storage,
            .field_index = 0,
            .field_count = fields.len,
        };
    }
    return .{ .field_count = fields.len };
}

fn isForbiddenHandleRepresentation(field: StructField) bool {
    if (std.mem.eql(u8, field.name, "_state") and isAllowedOpaqueStateStorage(field.type_expression)) return false;

    const forbidden_type_fragments = [_][]const u8{
        "Impl",
        "BackendRuntime",
        "BackendPrivate",
        "ResourceTracker",
        "Allocator",
    };
    for (forbidden_type_fragments) |fragment| {
        if (std.mem.indexOf(u8, field.type_expression, fragment) != null) return true;
    }

    if (std.mem.eql(u8, field.name, "_state")) return false;
    const forbidden_field_names = [_][]const u8{
        "backend",
        "impl",
        "runtime_impl",
        "tracker",
        "resource_tracker",
        "allocator",
        "alive",
        "debug",
        "label_value",
        "features_value",
        "limits_value",
        "queue_kind_value",
        "native_handle_view",
    };
    return containsName(forbidden_field_names[0..], field.name) or
        std.mem.indexOf(u8, field.name, "allocator") != null or
        std.mem.indexOf(u8, field.name, "tracker") != null or
        std.mem.indexOf(u8, field.name, "impl") != null or
        std.mem.endsWith(u8, field.name, "_value");
}

fn isAllowedOpaqueStateStorage(type_expression: []const u8) bool {
    if (std.mem.eql(u8, type_expression, "*anyopaque")) return true;

    const prefix = "[@sizeOf(";
    const separator = ")]u8 align(@alignOf(";
    if (!std.mem.startsWith(u8, type_expression, prefix) or !std.mem.endsWith(u8, type_expression, "))")) return false;
    const separator_index = std.mem.indexOf(u8, type_expression, separator) orelse return false;
    const size_type = type_expression[prefix.len..separator_index];
    const align_type_start = separator_index + separator.len;
    const align_type = type_expression[align_type_start .. type_expression.len - 2];
    return size_type.len != 0 and std.mem.eql(u8, size_type, align_type);
}

fn reportRuntimeHandleLayout(handle_name: []const u8, fields: []const StructField) bool {
    const summary = analyzeRuntimeHandleLayout(fields);
    const issue = summary.issue orelse return true;
    switch (issue) {
        .forbidden_representation => {
            const field = fields[summary.field_index.?];
            std.debug.print(
                "api guard: runtime handle {s} exposes forbidden representation field '{s}: {s}'; keep backend and bookkeeping state private\n",
                .{ handle_name, field.name, field.type_expression },
            );
        },
        .expected_single_state_field => std.debug.print(
            "api guard: runtime handle {s} must expose exactly one representation field named _state; found {} fields\n",
            .{ handle_name, summary.field_count },
        ),
        .expected_state_field_name => {
            const field = fields[summary.field_index.?];
            std.debug.print(
                "api guard: runtime handle {s} representation field must be named _state; found '{s}'\n",
                .{ handle_name, field.name },
            );
        },
        .invalid_state_storage => {
            const field = fields[summary.field_index.?];
            std.debug.print(
                "api guard: runtime handle {s} _state must use *anyopaque or matched @sizeOf/@alignOf byte storage; found '{s}'\n",
                .{ handle_name, field.type_expression },
            );
        },
    }
    return false;
}

fn parseDeclarationName(line: []const u8, prefix: []const u8, delimiter: u8) ParseError![]const u8 {
    if (!std.mem.startsWith(u8, line, prefix)) return ParseError.MalformedDeclaration;
    const remainder = line[prefix.len..];
    const delimiter_index = std.mem.indexOfScalar(u8, remainder, delimiter) orelse return ParseError.MalformedDeclaration;
    const name = std.mem.trim(u8, remainder[0..delimiter_index], " \t");
    if (name.len == 0 or std.mem.indexOfAny(u8, name, " \t") != null) return ParseError.MalformedDeclaration;
    return name;
}

fn reportNameSet(label: []const u8, actual: []const []const u8, expected: []const []const u8) bool {
    const summary = analyzeNames(actual, expected);
    if (summary.count_mismatch) {
        std.debug.print("api guard: {s} count mismatch: expected {}, found {}\n", .{ label, expected.len, actual.len });
    }
    for (actual, 0..) |name, index| {
        if (containsName(actual[0..index], name)) {
            std.debug.print("api guard: duplicate {s} '{s}'; remove the duplicate declaration\n", .{ label, name });
        }
        if (!containsName(expected, name)) {
            std.debug.print("api guard: unexpected {s} '{s}'; classify it and update the documented allowlist intentionally\n", .{ label, name });
        }
    }
    for (expected) |name| {
        if (!containsName(actual, name)) {
            std.debug.print("api guard: missing {s} '{s}'; restore it or update the migration decision intentionally\n", .{ label, name });
        }
    }
    return summary.passed();
}

fn analyzeNames(actual: []const []const u8, expected: []const []const u8) ValidationSummary {
    var summary = ValidationSummary{
        .count_mismatch = actual.len != expected.len,
        .duplicates = 0,
        .unknown = 0,
        .missing = 0,
    };
    for (actual, 0..) |name, index| {
        if (containsName(actual[0..index], name)) summary.duplicates += 1;
        if (!containsName(expected, name)) summary.unknown += 1;
    }
    for (expected) |name| {
        if (!containsName(actual, name)) summary.missing += 1;
    }
    return summary;
}

fn containsName(names: []const []const u8, needle: []const u8) bool {
    for (names) |name| {
        if (std.mem.eql(u8, name, needle)) return true;
    }
    return false;
}

test "name validation reports duplicate unknown and missing entries" {
    const actual = [_][]const u8{ "alpha", "alpha", "gamma" };
    const expected = [_][]const u8{ "alpha", "beta" };
    const summary = analyzeNames(actual[0..], expected[0..]);
    try std.testing.expect(summary.count_mismatch);
    try std.testing.expectEqual(@as(usize, 1), summary.duplicates);
    try std.testing.expectEqual(@as(usize, 1), summary.unknown);
    try std.testing.expectEqual(@as(usize, 1), summary.missing);
    try std.testing.expect(!summary.passed());
}

test "struct parser stays inside the requested top-level region" {
    const source =
        \\pub const Other = struct {
        \\    pub fn ignored(self: Other) void { _ = self; }
        \\};
        \\pub const Device = struct {
        \\    pub fn first(self: Device) void { _ = self; }
        \\    fn private(self: Device) void { _ = self; }
        \\    pub fn second(
        \\        self: Device,
        \\    ) void { _ = self; }
        \\};
        \\pub const Tail = struct {
        \\    pub fn ignored(self: Tail) void { _ = self; }
        \\};
    ;
    const methods = try parseStructPublicMethods(source, "Device");
    try std.testing.expectEqual(@as(usize, 2), methods.len);
    try std.testing.expectEqualStrings("first", methods.items[0]);
    try std.testing.expectEqualStrings("second", methods.items[1]);
}

test "struct parser rejects duplicate target regions" {
    const source =
        \\pub const Device = struct {
        \\};
        \\pub const Device = struct {
        \\};
    ;
    try std.testing.expectError(ParseError.DuplicateRegion, parseStructPublicMethods(source, "Device"));
}

test "runtime handle layout accepts only opaque pointer or inline byte state" {
    const source =
        \\pub const Borrowed = struct {
        \\    _state: *anyopaque,
        \\};
        \\pub const Inline = struct {
        \\    _state: [@sizeOf(PrivateState)]u8 align(@alignOf(PrivateState)),
        \\};
    ;

    const borrowed_fields = try parseStructFields(source, "Borrowed");
    const inline_fields = try parseStructFields(source, "Inline");
    try std.testing.expect(analyzeRuntimeHandleLayout(borrowed_fields.slice()).passed());
    try std.testing.expect(analyzeRuntimeHandleLayout(inline_fields.slice()).passed());
}

test "opaque runtime handle discovery locks the complete state-bearing set" {
    const source =
        \\pub const Descriptor = struct {
        \\    label: ?[]const u8,
        \\};
        \\pub const Borrowed = struct {
        \\    _state: *anyopaque,
        \\};
        \\pub const Inline = struct {
        \\    _state: [@sizeOf(State)]u8 align(@alignOf(State)),
        \\};
    ;

    const names = try parseOpaqueRuntimeHandleNames(source);
    try std.testing.expectEqual(@as(usize, 2), names.len);
    try std.testing.expectEqualStrings("Borrowed", names.items[0]);
    try std.testing.expectEqualStrings("Inline", names.items[1]);
}

test "runtime handle layout rejects backend and bookkeeping representation fields" {
    const source =
        \\pub const RawImpl = struct {
        \\    impl: Impl,
        \\};
        \\pub const RuntimeOwner = struct {
        \\    runtime: *BackendRuntime,
        \\};
        \\pub const BackendPrivateOwner = struct {
        \\    private: *BackendPrivateQueue,
        \\};
        \\pub const TrackerOwner = struct {
        \\    tracker: *ResourceTracker,
        \\};
        \\pub const AllocatorOwner = struct {
        \\    allocator: std.mem.Allocator,
        \\};
    ;
    const handle_names = [_][]const u8{
        "RawImpl",
        "RuntimeOwner",
        "BackendPrivateOwner",
        "TrackerOwner",
        "AllocatorOwner",
    };
    for (handle_names) |handle_name| {
        const fields = try parseStructFields(source, handle_name);
        const summary = analyzeRuntimeHandleLayout(fields.slice());
        try std.testing.expectEqual(HandleLayoutIssue.forbidden_representation, summary.issue.?);
    }
}

test "runtime handle layout rejects extra public representation fields" {
    const source =
        \\pub const Leaky = struct {
        \\    _state: *anyopaque,
        \\    label: ?[]const u8,
        \\};
    ;
    const fields = try parseStructFields(source, "Leaky");
    const summary = analyzeRuntimeHandleLayout(fields.slice());
    try std.testing.expectEqual(HandleLayoutIssue.expected_single_state_field, summary.issue.?);
    try std.testing.expectEqual(@as(usize, 2), summary.field_count);
}

test "runtime handle layout rejects renamed typed and mismatched state storage" {
    const source =
        \\pub const Renamed = struct {
        \\    state: *anyopaque,
        \\};
        \\pub const Typed = struct {
        \\    _state: *RuntimeState,
        \\};
        \\pub const Mismatched = struct {
        \\    _state: [@sizeOf(State)]u8 align(@alignOf(OtherState)),
        \\};
    ;

    const renamed_fields = try parseStructFields(source, "Renamed");
    const typed_fields = try parseStructFields(source, "Typed");
    const mismatched_fields = try parseStructFields(source, "Mismatched");
    try std.testing.expectEqual(
        HandleLayoutIssue.expected_state_field_name,
        analyzeRuntimeHandleLayout(renamed_fields.slice()).issue.?,
    );
    try std.testing.expectEqual(
        HandleLayoutIssue.invalid_state_storage,
        analyzeRuntimeHandleLayout(typed_fields.slice()).issue.?,
    );
    try std.testing.expectEqual(
        HandleLayoutIssue.invalid_state_storage,
        analyzeRuntimeHandleLayout(mismatched_fields.slice()).issue.?,
    );
}
