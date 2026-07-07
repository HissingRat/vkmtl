const std = @import("std");
const core = @import("core.zig");

pub const DevelopmentMatrixError = error{
    EmptyName,
    EmptyPath,
    EmptyRunStep,
    EmptyExpectation,
    EmptyValidationGoal,
    MissingDeterministicOutput,
    MissingFeatureGate,
    DuplicateName,
};

pub const FeatureGate = enum {
    multi_surface,
    native_handles,
    external_texture_interop,
    native_command_insertion,

    pub fn enabled(self: FeatureGate, features: core.DeviceFeatures) bool {
        return switch (self) {
            .multi_surface => features.multi_surface,
            .native_handles => features.native_handles,
            .external_texture_interop => features.external_textures,
            .native_command_insertion => false,
        };
    }
};

pub const ExampleKind = enum {
    presentation,
    render,
    transfer,
    compute,
};

pub const ExampleStatus = enum {
    implemented,
    planned,
};

pub const ExampleEntry = struct {
    name: []const u8,
    path: []const u8,
    run_step: []const u8,
    kind: ExampleKind,
    status: ExampleStatus = .implemented,
    requires_window: bool = true,
    deterministic_output: ?[]const u8 = null,
    backend_expectation: []const u8,

    pub fn validate(self: ExampleEntry) DevelopmentMatrixError!void {
        if (self.name.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.path.len == 0) return DevelopmentMatrixError.EmptyPath;
        if (self.status == .implemented and self.run_step.len == 0) return DevelopmentMatrixError.EmptyRunStep;
        if (self.backend_expectation.len == 0) return DevelopmentMatrixError.EmptyExpectation;
        if ((self.kind == .transfer or self.kind == .compute) and self.status == .implemented and self.deterministic_output == null) {
            return DevelopmentMatrixError.MissingDeterministicOutput;
        }
    }
};

pub const examples = [_]ExampleEntry{
    .{
        .name = "clear_screen",
        .path = "examples/clear_screen",
        .run_step = "run-clear-screen",
        .kind = .presentation,
        .backend_expectation = "auto selects Metal on Apple and Vulkan where configured",
    },
    .{
        .name = "triangle",
        .path = "examples/triangle",
        .run_step = "run-triangle",
        .kind = .render,
        .backend_expectation = "portable Vulkan or Metal rendering through public APIs",
    },
    .{
        .name = "uniform_buffer",
        .path = "examples/uniform_buffer",
        .run_step = "run-uniform-buffer",
        .kind = .render,
        .backend_expectation = "uniform-buffer binding through reflection-derived layout",
    },
    .{
        .name = "sampled_texture",
        .path = "examples/sampled_texture",
        .run_step = "run-sampled-texture",
        .kind = .render,
        .backend_expectation = "sampled texture and sampler binding through public APIs",
    },
    .{
        .name = "depth_triangles",
        .path = "examples/depth_triangles",
        .run_step = "run-depth-triangles",
        .kind = .render,
        .backend_expectation = "depth attachment and depth pipeline state",
    },
    .{
        .name = "offscreen_texture",
        .path = "examples/offscreen_texture",
        .run_step = "run-offscreen-texture",
        .kind = .render,
        .backend_expectation = "offscreen color target sampled into current drawable",
    },
    .{
        .name = "msaa_triangle",
        .path = "examples/msaa_triangle",
        .run_step = "run-msaa-triangle",
        .kind = .render,
        .backend_expectation = "MSAA render target resolved into a sampled texture",
    },
    .{
        .name = "rainbow_cube",
        .path = "examples/rainbow_cube",
        .run_step = "run-rainbow-cube",
        .kind = .render,
        .backend_expectation = "integrated 3D cube with depth, texture, uniforms, and indexed draw",
    },
    .{
        .name = "transfer_readback",
        .path = "examples/transfer_readback",
        .run_step = "run-transfer-readback",
        .kind = .transfer,
        .requires_window = false,
        .deterministic_output = "transfer readback ok",
        .backend_expectation = "deterministic buffer/texture transfer readback",
    },
    .{
        .name = "compute_readback",
        .path = "examples/compute_readback",
        .run_step = "run-compute-readback",
        .kind = .compute,
        .requires_window = false,
        .deterministic_output = "compute readback ok",
        .backend_expectation = "deterministic storage buffer and storage texture compute readback",
    },
    .{
        .name = "capability_dump",
        .path = "examples/capability_dump",
        .run_step = "run-capability-dump",
        .kind = .presentation,
        .backend_expectation = "prints selected backend capability report through public APIs",
    },
    .{
        .name = "bindless_textures",
        .path = "examples/bindless_textures",
        .run_step = "run-bindless-textures",
        .kind = .render,
        .backend_expectation = "advanced binding feature gate and bindless texture layout contract",
    },
    .{
        .name = "multi_window",
        .path = "examples/multi_window",
        .run_step = "run-multi-window",
        .kind = .presentation,
        .backend_expectation = "multi-surface registry and native multi-window feature gate",
    },
    .{
        .name = "external_texture",
        .path = "examples/external_texture",
        .run_step = "run-external-texture",
        .kind = .render,
        .backend_expectation = "external texture descriptor validation and wrapper feature gate",
    },
};

pub fn validateExamples(entries: []const ExampleEntry) DevelopmentMatrixError!void {
    for (entries, 0..) |entry, i| {
        try entry.validate();
        for (entries[i + 1 ..]) |other| {
            if (std.mem.eql(u8, entry.name, other.name)) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub fn implementedExampleCount(entries: []const ExampleEntry) usize {
    var count: usize = 0;
    for (entries) |entry| {
        if (entry.status == .implemented) count += 1;
    }
    return count;
}

pub const GalleryCaseStatus = enum {
    implemented,
    planned,
};

pub const ComputeGalleryKind = enum {
    image_filter,
    particle_simulation,
    prefix_sum,
    readback,
    storage_texture,
};

pub const ComputeGalleryCase = struct {
    name: []const u8,
    kind: ComputeGalleryKind,
    status: GalleryCaseStatus,
    path: []const u8 = "",
    run_step: []const u8 = "",
    deterministic_output: ?[]const u8 = null,
    validation_goal: []const u8,

    pub fn validate(self: ComputeGalleryCase) DevelopmentMatrixError!void {
        if (self.name.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.validation_goal.len == 0) return DevelopmentMatrixError.EmptyValidationGoal;
        if (self.status == .implemented) {
            if (self.path.len == 0) return DevelopmentMatrixError.EmptyPath;
            if (self.run_step.len == 0) return DevelopmentMatrixError.EmptyRunStep;
            if (self.deterministic_output == null) return DevelopmentMatrixError.MissingDeterministicOutput;
        }
    }
};

pub const compute_gallery = [_]ComputeGalleryCase{
    .{
        .name = "compute_readback",
        .kind = .readback,
        .status = .implemented,
        .path = "examples/compute_readback",
        .run_step = "run-compute-readback",
        .deterministic_output = "compute readback ok",
        .validation_goal = "storage buffer and storage texture writes with deterministic readback",
    },
    .{
        .name = "image_filter",
        .kind = .image_filter,
        .status = .planned,
        .validation_goal = "sample an input texture, write a storage texture, and validate pixels",
    },
    .{
        .name = "particle_simulation",
        .kind = .particle_simulation,
        .status = .planned,
        .validation_goal = "update particle state in storage buffers and render or read back a deterministic subset",
    },
    .{
        .name = "prefix_sum",
        .kind = .prefix_sum,
        .status = .planned,
        .validation_goal = "exercise multi-dispatch compute dependencies and deterministic buffer readback",
    },
    .{
        .name = "storage_texture",
        .kind = .storage_texture,
        .status = .planned,
        .validation_goal = "visualize compute-written texture data through a render pass",
    },
};

pub fn validateComputeGallery(cases: []const ComputeGalleryCase) DevelopmentMatrixError!void {
    for (cases, 0..) |case, i| {
        try case.validate();
        for (cases[i + 1 ..]) |other| {
            if (std.mem.eql(u8, case.name, other.name)) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub fn implementedComputeGalleryCount(cases: []const ComputeGalleryCase) usize {
    var count: usize = 0;
    for (cases) |case| {
        if (case.status == .implemented) count += 1;
    }
    return count;
}

pub const MultiWindowExampleKind = enum {
    single_device_multiple_surfaces,
    multiple_swapchains,
    resize_handling,
    surface_lost,
};

pub const MultiWindowExampleCase = struct {
    name: []const u8,
    kind: MultiWindowExampleKind,
    status: GalleryCaseStatus = .planned,
    required_feature: ?FeatureGate = .multi_surface,
    validation_goal: []const u8,

    pub fn validate(self: MultiWindowExampleCase) DevelopmentMatrixError!void {
        if (self.name.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.validation_goal.len == 0) return DevelopmentMatrixError.EmptyValidationGoal;
        if (self.required_feature == null) return DevelopmentMatrixError.MissingFeatureGate;
    }
};

pub const multi_window_gallery = [_]MultiWindowExampleCase{
    .{
        .name = "single_device_multiple_surfaces",
        .kind = .single_device_multiple_surfaces,
        .validation_goal = "one selected device owns more than one public Surface view",
    },
    .{
        .name = "multiple_swapchains",
        .kind = .multiple_swapchains,
        .validation_goal = "one selected backend presents to more than one swapchain",
    },
    .{
        .name = "multi_window_resize",
        .kind = .resize_handling,
        .validation_goal = "resize one surface without invalidating the other",
    },
    .{
        .name = "surface_lost_recovery",
        .kind = .surface_lost,
        .validation_goal = "surface-lost handling reports typed errors and allows recreation",
    },
};

pub fn validateMultiWindowGallery(cases: []const MultiWindowExampleCase) DevelopmentMatrixError!void {
    for (cases, 0..) |case, i| {
        try case.validate();
        for (cases[i + 1 ..]) |other| {
            if (std.mem.eql(u8, case.name, other.name)) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub const NativeInteropKind = enum {
    vulkan_native_handle,
    metal_native_handle,
    external_texture,
    native_command_insertion,
};

pub const NativeInteropExampleCase = struct {
    name: []const u8,
    kind: NativeInteropKind,
    status: GalleryCaseStatus = .planned,
    required_feature: FeatureGate,
    validation_goal: []const u8,

    pub fn validate(self: NativeInteropExampleCase) DevelopmentMatrixError!void {
        if (self.name.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.validation_goal.len == 0) return DevelopmentMatrixError.EmptyValidationGoal;
    }
};

pub const native_interop_gallery = [_]NativeInteropExampleCase{
    .{
        .name = "vulkan_native_handles",
        .kind = .vulkan_native_handle,
        .required_feature = .native_handles,
        .validation_goal = "borrow Vulkan handles through explicit native handle escape hatch",
    },
    .{
        .name = "metal_native_handles",
        .kind = .metal_native_handle,
        .required_feature = .native_handles,
        .validation_goal = "borrow Metal handles through explicit native handle escape hatch",
    },
    .{
        .name = "external_texture_import",
        .kind = .external_texture,
        .required_feature = .external_texture_interop,
        .validation_goal = "import an external texture handle through an explicit backend-gated path",
    },
    .{
        .name = "native_command_insertion",
        .kind = .native_command_insertion,
        .required_feature = .native_command_insertion,
        .validation_goal = "insert user native commands without weakening portable command ordering",
    },
};

pub fn validateNativeInteropGallery(cases: []const NativeInteropExampleCase) DevelopmentMatrixError!void {
    for (cases, 0..) |case, i| {
        try case.validate();
        for (cases[i + 1 ..]) |other| {
            if (std.mem.eql(u8, case.name, other.name)) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub const MatrixHost = enum {
    macos,
    linux,
    windows,
    ios,
    headless,
};

pub const BackendMatrixEntry = struct {
    name: []const u8,
    host: MatrixHost,
    backend: ?core.Backend,
    required: bool,
    command: []const u8,
    requires_runtime_configuration: bool = false,
    expectation: []const u8,

    pub fn validate(self: BackendMatrixEntry) DevelopmentMatrixError!void {
        if (self.name.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.command.len == 0) return DevelopmentMatrixError.EmptyRunStep;
        if (self.expectation.len == 0) return DevelopmentMatrixError.EmptyExpectation;
    }
};

pub const backend_test_matrix = [_]BackendMatrixEntry{
    .{
        .name = "macos_metal_default",
        .host = .macos,
        .backend = .metal,
        .required = true,
        .command = "zig build test && zig build",
        .expectation = "default Apple path builds tests and examples through Metal-capable runtime",
    },
    .{
        .name = "macos_moltenvk_forced",
        .host = .macos,
        .backend = .vulkan,
        .required = false,
        .command = "zig build -Dvulkan -Dvulkan-loader-dir=/path/to/vulkan/lib -Dvulkan-icd=/path/to/MoltenVK_icd.json",
        .requires_runtime_configuration = true,
        .expectation = "forced Vulkan path builds when loader and ICD are explicitly configured",
    },
    .{
        .name = "linux_vulkan",
        .host = .linux,
        .backend = .vulkan,
        .required = true,
        .command = "zig build test && zig build -Dvulkan",
        .expectation = "Linux Vulkan builds tests and examples with a system Vulkan loader",
    },
    .{
        .name = "windows_vulkan",
        .host = .windows,
        .backend = .vulkan,
        .required = true,
        .command = "zig build test && zig build -Dvulkan",
        .expectation = "Windows Vulkan builds tests and examples with a system Vulkan loader",
    },
    .{
        .name = "ios_metal_optional",
        .host = .ios,
        .backend = .metal,
        .required = false,
        .command = "zig build -Dtarget=aarch64-ios",
        .expectation = "optional future Metal target once iOS surface packaging is designed",
    },
    .{
        .name = "headless_deterministic",
        .host = .headless,
        .backend = null,
        .required = true,
        .command = "zig build run-transfer-readback && zig build run-compute-readback",
        .expectation = "deterministic transfer and compute readback examples complete without visual inspection",
    },
};

pub fn validateBackendTestMatrix(entries: []const BackendMatrixEntry) DevelopmentMatrixError!void {
    for (entries, 0..) |entry, i| {
        try entry.validate();
        for (entries[i + 1 ..]) |other| {
            if (std.mem.eql(u8, entry.name, other.name)) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub const ValidationCaseKind = enum {
    invalid_bind_group,
    invalid_texture_format,
    invalid_barrier,
    resource_destroyed_while_in_use,
    unsupported_feature,
    shader_reflection_mismatch,
};

pub const ValidationCase = struct {
    name: []const u8,
    kind: ValidationCaseKind,
    test_location: []const u8,
    integration_gap: bool = false,
    expectation: []const u8,

    pub fn validate(self: ValidationCase) DevelopmentMatrixError!void {
        if (self.name.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.test_location.len == 0) return DevelopmentMatrixError.EmptyPath;
        if (self.expectation.len == 0) return DevelopmentMatrixError.EmptyExpectation;
    }
};

pub const validation_cases = [_]ValidationCase{
    .{
        .name = "invalid_bind_group",
        .kind = .invalid_bind_group,
        .test_location = "src/core.zig bind group descriptor validates entries against layout",
        .expectation = "missing, extra, duplicate, and kind-mismatched bind group entries return typed validation errors",
    },
    .{
        .name = "invalid_texture_format",
        .kind = .invalid_texture_format,
        .test_location = "src/core.zig texture descriptor rejects missing extent and automatic format",
        .expectation = "automatic or unsupported texture formats fail before backend creation",
    },
    .{
        .name = "invalid_barrier",
        .kind = .invalid_barrier,
        .test_location = "src/core.zig resource usage tracks hazards and explicit barriers",
        .expectation = "redundant or mismatched barriers return command encoding errors",
    },
    .{
        .name = "resource_destroyed_while_in_use",
        .kind = .resource_destroyed_while_in_use,
        .test_location = "src/runtime/window_context.zig resource tracker defers retirements until submitted work completes",
        .integration_gap = true,
        .expectation = "debug tracker retains pending retirements until submitted work completes",
    },
    .{
        .name = "unsupported_feature",
        .kind = .unsupported_feature,
        .test_location = "src/runtime/window_context.zig runtime render pipeline rejects unsupported advanced state",
        .expectation = "feature-gated APIs return typed unsupported errors instead of silently lowering incorrectly",
    },
    .{
        .name = "shader_reflection_mismatch",
        .kind = .shader_reflection_mismatch,
        .test_location = "src/shader/reflection.zig reflection artifact validates bind group layout",
        .expectation = "shader reflection layout, kind, visibility, and stage mismatch are reported before pipeline creation",
    },
};

pub fn validateValidationCases(cases: []const ValidationCase) DevelopmentMatrixError!void {
    for (cases, 0..) |case, i| {
        try case.validate();
        for (cases[i + 1 ..]) |other| {
            if (std.mem.eql(u8, case.name, other.name)) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub const DocumentationStatus = enum {
    present,
    planned,
};

pub const DocumentationTopic = struct {
    name: []const u8,
    path: []const u8,
    status: DocumentationStatus = .present,
    expectation: []const u8,

    pub fn validate(self: DocumentationTopic) DevelopmentMatrixError!void {
        if (self.name.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.path.len == 0) return DevelopmentMatrixError.EmptyPath;
        if (self.expectation.len == 0) return DevelopmentMatrixError.EmptyExpectation;
    }
};

pub const documentation_topics = [_]DocumentationTopic{
    .{
        .name = "getting_started",
        .path = "docs/usage/en_us/quick-start.md",
        .expectation = "first runnable app path and runtime shader compile flow",
    },
    .{
        .name = "configuration",
        .path = "docs/usage/en_us/configuration.md",
        .expectation = "backend selection, Slang tool, Vulkan runtime, and shader cache configuration",
    },
    .{
        .name = "examples",
        .path = "docs/usage/en_us/examples.md",
        .expectation = "current example gallery and planned gallery rows",
    },
    .{
        .name = "core_api",
        .path = "docs/api/en_us/core.md",
        .expectation = "Device, Surface, Queue, resources, bindings, commands, capabilities, and diagnostics",
    },
    .{
        .name = "shader_authoring",
        .path = "docs/api/en_us/shaders.md",
        .expectation = "Slang-only shader authoring and reflection expectations",
    },
    .{
        .name = "resource_lifetime",
        .path = "docs/api/en_us/resource-lifetime.md",
        .expectation = "ownership, destruction order, and deferred retirement rules",
    },
    .{
        .name = "backend_test_matrix",
        .path = "docs/develop/backend-test-matrix.md",
        .expectation = "backend and host validation rows",
    },
    .{
        .name = "validation_matrix",
        .path = "docs/develop/validation-matrix.md",
        .expectation = "validation case inventory and integration gaps",
    },
    .{
        .name = "performance_guide",
        .path = "docs/usage/en_us/performance.md",
        .expectation = "cache, resource lifetime, shader compile, and command recording guidance",
    },
    .{
        .name = "compatibility_table",
        .path = "docs/usage/en_us/compatibility.md",
        .expectation = "current platform/backend capability expectations",
    },
};

pub fn validateDocumentationTopics(topics: []const DocumentationTopic) DevelopmentMatrixError!void {
    for (topics, 0..) |topic, i| {
        try topic.validate();
        for (topics[i + 1 ..]) |other| {
            if (std.mem.eql(u8, topic.name, other.name)) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

test "example gallery metadata is valid" {
    try validateExamples(examples[0..]);
    try std.testing.expectEqual(@as(usize, 14), implementedExampleCount(examples[0..]));
}

test "deterministic examples declare output markers" {
    for (examples) |entry| {
        if (!entry.requires_window) {
            try std.testing.expect(entry.deterministic_output != null);
        }
    }
}

test "compute gallery metadata is valid" {
    try validateComputeGallery(compute_gallery[0..]);
    try std.testing.expectEqual(@as(usize, 1), implementedComputeGalleryCount(compute_gallery[0..]));
}

test "multi-window gallery is gated by multi-surface feature" {
    try validateMultiWindowGallery(multi_window_gallery[0..]);
    for (multi_window_gallery) |case| {
        try std.testing.expectEqual(FeatureGate.multi_surface, case.required_feature.?);
        try std.testing.expect(!case.required_feature.?.enabled(core.DeviceFeatures{}));
        try std.testing.expect(case.required_feature.?.enabled(.{ .multi_surface = true }));
    }
}

test "native interop gallery keeps explicit feature gates" {
    try validateNativeInteropGallery(native_interop_gallery[0..]);
    var native_handle_cases: usize = 0;
    for (native_interop_gallery) |case| {
        if (case.required_feature == .native_handles) native_handle_cases += 1;
        try std.testing.expect(case.required_feature.enabled(.{ .native_handles = true }) == (case.required_feature == .native_handles));
    }
    try std.testing.expectEqual(@as(usize, 2), native_handle_cases);
}

test "backend test matrix metadata is valid" {
    try validateBackendTestMatrix(backend_test_matrix[0..]);
    var configured_optional: usize = 0;
    for (backend_test_matrix) |entry| {
        if (entry.requires_runtime_configuration and !entry.required) configured_optional += 1;
    }
    try std.testing.expect(configured_optional >= 1);
}

test "validation case inventory is valid" {
    try validateValidationCases(validation_cases[0..]);
    var gap_count: usize = 0;
    for (validation_cases) |case| {
        if (case.integration_gap) gap_count += 1;
    }
    try std.testing.expect(gap_count >= 1);
}

test "documentation topic inventory is valid" {
    try validateDocumentationTopics(documentation_topics[0..]);
    for (documentation_topics) |topic| {
        try std.testing.expectEqual(DocumentationStatus.present, topic.status);
    }
}
