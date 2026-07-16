const std = @import("std");
const core = @import("vkmtl_core");

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
            .native_command_insertion => features.native_command_insertion,
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
        .name = "offscreen_texture",
        .path = "examples/offscreen_texture",
        .run_step = "run-offscreen-texture",
        .kind = .render,
        .backend_expectation = "asymmetric back-culled raster top/bottom readback plus top-left texture composition",
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
        .name = "voxel_world",
        .path = "examples/voxel_world",
        .run_step = "run-voxel-world",
        .kind = .render,
        .deterministic_output = "voxel_world_pressure_test=ok",
        .backend_expectation = "bounded visible-face chunk rendering, atlas binding, camera culling, streaming, and metrics on Vulkan or Metal",
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
        .backend_expectation = "65-slot native table, compatible pipeline layout, reusable indirect draw, and persistent driver cache",
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
        .backend_expectation = "external texture capability matrix, descriptor validation, and wrapper feature gate",
    },
    .{
        .name = "external_import",
        .path = "examples/external_import",
        .run_step = "run-external-import",
        .kind = .transfer,
        .requires_window = false,
        .deterministic_output = "external import ok",
        .backend_expectation = "Metal raw-buffer and IOSurface imports execute deterministic GPU readback; other backends are unavailable",
    },
    .{
        .name = "streaming_texture",
        .path = "examples/streaming_texture",
        .run_step = "run-streaming-texture",
        .kind = .render,
        .backend_expectation = "sparse/tiled texture descriptor and residency feature gate",
    },
    .{
        .name = "tessellation",
        .path = "examples/tessellation",
        .run_step = "run-tessellation",
        .kind = .render,
        .backend_expectation = "tessellation patch draw planning and backend lowering feature gate",
    },
    .{
        .name = "mesh_shader",
        .path = "examples/mesh_shader",
        .run_step = "run-mesh-shader",
        .kind = .render,
        .backend_expectation = "mesh/task dispatch planning and backend lowering feature gate",
    },
    .{
        .name = "ray_traced_scene",
        .path = "examples/ray_traced_scene",
        .run_step = "run-ray-traced-scene",
        .kind = .render,
        .backend_expectation = "native RT writes a caller-owned texture; the default application-owned composition path and optional legacy raw-copy probe present behind capability gates",
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
        .status = .implemented,
        .required_feature = .external_texture_interop,
        .validation_goal = "import Metal raw buffers/textures and IOSurfaces through an explicit backend-gated path",
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
        .command = "zig fmt --check build.zig src examples tools tests/package_consumer && zig build run-api-guard && zig build test --summary all && zig build && zig build run-validation-plan && scripts/ci/run_package_smoke.sh",
        .expectation = "hosted Apple path compiles Metal-capable code and the external package consumer without claiming physical GPU execution",
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
        .command = "zig fmt --check build.zig src examples tools tests/package_consumer && zig build run-api-guard && zig build test --summary all && zig build -Dvulkan && zig build run-validation-plan && scripts/ci/run_package_smoke.sh",
        .expectation = "hosted Linux path compiles Vulkan code and the external package consumer without claiming a physical GPU smoke run",
    },
    .{
        .name = "windows_vulkan",
        .host = .windows,
        .backend = .vulkan,
        .required = true,
        .command = "zig fmt --check build.zig src examples tools tests/package_consumer && zig build run-api-guard && zig build test --summary all && zig build -Dvulkan && zig build run-validation-plan && scripts/ci/run_package_smoke.sh",
        .expectation = "hosted Windows path compiles Vulkan code and the external package consumer without claiming a physical GPU smoke run",
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
    .{
        .name = "voxel_world_pressure_test",
        .host = .macos,
        .backend = .metal,
        .required = false,
        .command = "MTL_DEBUG_LAYER=1 VKMTL_VOXEL_PROFILE=smoke VKMTL_VOXEL_FRAME_LIMIT=24 VKMTL_VOXEL_AUTOPILOT=1 VKMTL_BACKEND=metal zig build run-voxel-world && MTL_DEBUG_LAYER=1 VKMTL_VOXEL_PROFILE=default VKMTL_VOXEL_FRAME_LIMIT=48 VKMTL_BACKEND=metal zig build run-voxel-world && MTL_DEBUG_LAYER=1 VKMTL_VOXEL_PROFILE=stress VKMTL_VOXEL_FRAME_LIMIT=160 VKMTL_BACKEND=metal zig build run-voxel-world",
        .requires_runtime_configuration = true,
        .expectation = "bounded smoke, default, and stress chunk workloads complete under Metal API Validation and print voxel_world_pressure_test=ok",
    },
    .{
        .name = "ray_tracing_metal_color_path",
        .host = .macos,
        .backend = .metal,
        .required = false,
        .command = "MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 zig build run-ray-traced-scene && MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 VKMTL_RT_LEGACY_DRAWABLE=1 VKMTL_PRESENTATION_FORMAT=srgb zig build run-ray-traced-scene && MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 VKMTL_RT_LEGACY_DRAWABLE=1 VKMTL_PRESENTATION_FORMAT=linear zig build run-ray-traced-scene",
        .requires_runtime_configuration = true,
        .expectation = "the application-owned composition path and both admitted legacy raw-copy presentation formats complete three Metal RT frames under API Validation",
    },
    .{
        .name = "ray_tracing_vulkan_color_path",
        .host = .windows,
        .backend = .vulkan,
        .required = false,
        .command = "VKMTL_BACKEND=vulkan VKMTL_RT_FRAME_LIMIT=3 zig build run-ray-traced-scene -Dvulkan",
        .requires_runtime_configuration = true,
        .expectation = "a Vulkan RT device renders through the application-owned composition path and the legacy raw-copy probe; both have accepted physical orientation evidence",
    },
    .{
        .name = "binding_variant_regression",
        .host = .headless,
        .backend = null,
        .required = true,
        .command = "zig build test",
        .expectation = "dynamic buffer array offsets, native resource tables, pipeline-layout compatibility, reusable indirect ranges, driver-cache identity, root constants, and shader specialization regressions pass",
    },
    .{
        .name = "sync_query_regression",
        .host = .headless,
        .backend = null,
        .required = true,
        .command = "zig build test",
        .expectation = "explicit barriers, fences/events, synchronization descriptors, logical queue plans, ownership transfers, and query validation regressions pass",
    },
    .{
        .name = "debug_marker_regression",
        .host = .headless,
        .backend = null,
        .required = true,
        .command = "zig build test && zig build run-profiling-plan",
        .expectation = "borrowed labels, native/validation-only marker capabilities, capture gates, profiling fallback, and issue-report regressions pass",
    },
    .{
        .name = "resource_utility_regression",
        .host = .headless,
        .backend = null,
        .required = true,
        .command = "zig build test",
        .expectation = "mipmaps, fill fallback, copy alignment and subresources, aspect copies, blit gates, MSAA semantics, subresource state, sampler borders, and heap planning regressions pass",
    },
    .{
        .name = "platform_interop_regression",
        .host = .headless,
        .backend = null,
        .required = true,
        .command = "zig build test",
        .expectation = "surface registries, present-mode diagnostics, external wrappers, external sync validation, and native insertion gates pass",
    },
    .{
        .name = "production_hardening_regression",
        .host = .headless,
        .backend = null,
        .required = true,
        .command = "zig build test && zig build run-stability-plan -- --iterations 120",
        .expectation = "object-cache diagnostics, runtime cache planning, pipeline artifact compatibility, runtime diagnostics, and stability planning stay deterministic",
    },
    .{
        .name = "advanced_resource_geometry_regression",
        .host = .headless,
        .backend = null,
        .required = true,
        .command = "zig build test",
        .expectation = "sparse/tiled planning, residency commit/churn plans, tessellation draw planning, and mesh/task dispatch planning regressions pass",
    },
    .{
        .name = "advanced_geometry_feature_gates",
        .host = .headless,
        .backend = null,
        .required = true,
        .command = "zig build run-tessellation && zig build run-mesh-shader",
        .expectation = "windowed advanced geometry examples use public patch draw and mesh dispatch planning APIs",
    },
    .{
        .name = "ray_tracing_native_parity_regression",
        .host = .headless,
        .backend = null,
        .required = true,
        .command = "zig build test",
        .expectation = "ray tracing planning, native mappings, caller-owned texture dispatch, deterministic presentation selection, legacy raw-copy validation, per-dispatch Vulkan resources, finite-run, and color-reference regressions pass",
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

pub const ValidationExecutionClass = enum {
    hosted_build,
    self_hosted_gpu,
    local_gpu,
    manual_visual,
};

pub const ValidationDeviceClass = enum {
    none,
    integrated_gpu,
    discrete_gpu,
    software_adapter,
    unknown_gpu,
};

pub const ValidationExpectedOutcome = enum {
    pass,
    build_only,
    typed_unsupported,
    manual_evidence,
};

pub const ValidationEvidenceState = enum {
    configured_automated,
    configured,
    documented,
    missing,
};

pub const ValidationJob = struct {
    name: []const u8,
    host_os: MatrixHost,
    target_os: MatrixHost,
    architecture: []const u8,
    backend: ?core.Backend,
    device_class: ValidationDeviceClass,
    execution: ValidationExecutionClass,
    expected_outcome: ValidationExpectedOutcome,
    evidence: ValidationEvidenceState,
    required_for_release: bool,
    attach_capability_dump: bool = false,
    command: []const u8,

    pub fn validate(self: ValidationJob) DevelopmentMatrixError!void {
        if (self.name.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.architecture.len == 0) return DevelopmentMatrixError.EmptyExpectation;
        if (self.command.len == 0) return DevelopmentMatrixError.EmptyRunStep;
        const gpu_execution = self.execution == .self_hosted_gpu or
            self.execution == .local_gpu or
            self.execution == .manual_visual;
        if (gpu_execution and (self.backend == null or self.device_class == .none)) {
            return DevelopmentMatrixError.MissingFeatureGate;
        }
        if (self.execution == .hosted_build and self.device_class != .none) {
            return DevelopmentMatrixError.MissingDeterministicOutput;
        }
        if ((self.execution == .self_hosted_gpu or self.execution == .local_gpu) and
            !self.attach_capability_dump)
        {
            return DevelopmentMatrixError.MissingDeterministicOutput;
        }
    }
};

pub const validation_jobs = [_]ValidationJob{
    .{
        .name = "hosted_macos_build",
        .host_os = .macos,
        .target_os = .macos,
        .architecture = "aarch64",
        .backend = .metal,
        .device_class = .none,
        .execution = .hosted_build,
        .expected_outcome = .build_only,
        .evidence = .configured_automated,
        .required_for_release = true,
        .command = "zig fmt --check build.zig src examples tools tests/package_consumer && zig build run-api-guard && zig build test --summary all && zig build && zig build run-validation-plan && scripts/ci/run_package_smoke.sh",
    },
    .{
        .name = "hosted_linux_build",
        .host_os = .linux,
        .target_os = .linux,
        .architecture = "x86_64",
        .backend = .vulkan,
        .device_class = .none,
        .execution = .hosted_build,
        .expected_outcome = .build_only,
        .evidence = .configured_automated,
        .required_for_release = true,
        .command = "zig fmt --check build.zig src examples tools tests/package_consumer && zig build run-api-guard && zig build test --summary all && zig build -Dvulkan && zig build run-validation-plan && scripts/ci/run_package_smoke.sh",
    },
    .{
        .name = "hosted_windows_build",
        .host_os = .windows,
        .target_os = .windows,
        .architecture = "x86_64",
        .backend = .vulkan,
        .device_class = .none,
        .execution = .hosted_build,
        .expected_outcome = .build_only,
        .evidence = .configured_automated,
        .required_for_release = true,
        .command = "zig fmt --check build.zig src examples tools tests/package_consumer && zig build run-api-guard && zig build test --summary all && zig build -Dvulkan && zig build run-validation-plan && scripts/ci/run_package_smoke.sh",
    },
    .{
        .name = "self_hosted_metal_smoke",
        .host_os = .macos,
        .target_os = .macos,
        .architecture = "aarch64",
        .backend = .metal,
        .device_class = .integrated_gpu,
        .execution = .self_hosted_gpu,
        .expected_outcome = .pass,
        .evidence = .configured,
        .required_for_release = true,
        .attach_capability_dump = true,
        .command = "scripts/ci/run_gpu_smoke.sh metal artifacts/metal-smoke",
    },
    .{
        .name = "self_hosted_vulkan_smoke",
        .host_os = .linux,
        .target_os = .linux,
        .architecture = "x86_64",
        .backend = .vulkan,
        .device_class = .discrete_gpu,
        .execution = .self_hosted_gpu,
        .expected_outcome = .pass,
        .evidence = .configured,
        .required_for_release = true,
        .attach_capability_dump = true,
        .command = "scripts/ci/run_gpu_smoke.sh vulkan artifacts/vulkan-smoke",
    },
    .{
        .name = "local_metal_pixel_regression",
        .host_os = .macos,
        .target_os = .macos,
        .architecture = "aarch64",
        .backend = .metal,
        .device_class = .integrated_gpu,
        .execution = .local_gpu,
        .expected_outcome = .pass,
        .evidence = .configured,
        .required_for_release = true,
        .attach_capability_dump = true,
        .command = "VKMTL_BACKEND=metal zig build run-pixel-regression",
    },
    .{
        .name = "local_vulkan_pixel_regression",
        .host_os = .linux,
        .target_os = .linux,
        .architecture = "x86_64",
        .backend = .vulkan,
        .device_class = .discrete_gpu,
        .execution = .local_gpu,
        .expected_outcome = .pass,
        .evidence = .configured,
        .required_for_release = true,
        .attach_capability_dump = true,
        .command = "VKMTL_BACKEND=vulkan zig build run-pixel-regression -Dvulkan",
    },
    .{
        .name = "self_hosted_metal_soak",
        .host_os = .macos,
        .target_os = .macos,
        .architecture = "aarch64",
        .backend = .metal,
        .device_class = .integrated_gpu,
        .execution = .self_hosted_gpu,
        .expected_outcome = .pass,
        .evidence = .configured,
        .required_for_release = true,
        .attach_capability_dump = true,
        .command = "scripts/ci/run_gpu_soak.sh metal 120 artifacts/metal-soak",
    },
    .{
        .name = "self_hosted_vulkan_soak",
        .host_os = .linux,
        .target_os = .linux,
        .architecture = "x86_64",
        .backend = .vulkan,
        .device_class = .discrete_gpu,
        .execution = .self_hosted_gpu,
        .expected_outcome = .pass,
        .evidence = .configured,
        .required_for_release = true,
        .attach_capability_dump = true,
        .command = "scripts/ci/run_gpu_soak.sh vulkan 120 artifacts/vulkan-soak",
    },
    .{
        .name = "manual_ray_traced_scene_visual",
        .host_os = .macos,
        .target_os = .macos,
        .architecture = "aarch64",
        .backend = .metal,
        .device_class = .integrated_gpu,
        .execution = .manual_visual,
        .expected_outcome = .manual_evidence,
        .evidence = .documented,
        .required_for_release = false,
        .attach_capability_dump = true,
        .command = "zig build run-ray-traced-scene",
    },
};

pub fn validateValidationJobs(entries: []const ValidationJob) DevelopmentMatrixError!void {
    for (entries, 0..) |entry, i| {
        try entry.validate();
        for (entries[i + 1 ..]) |other| {
            if (std.mem.eql(u8, entry.name, other.name)) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub const BackendEvidenceExpectation = enum {
    executable,
    capability_gated,
    typed_unsupported,
    validation_only,
    planning_only,
    native_escape_hatch,
};

pub const BackendFeatureExpectation = struct {
    name: []const u8,
    vulkan: BackendEvidenceExpectation,
    metal: BackendEvidenceExpectation,
    evidence: []const u8,

    pub fn validate(self: BackendFeatureExpectation) DevelopmentMatrixError!void {
        if (self.name.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.evidence.len == 0) return DevelopmentMatrixError.EmptyExpectation;
    }
};

pub const backend_feature_expectations = [_]BackendFeatureExpectation{
    .{ .name = "object_and_encoder_debug_markers", .vulkan = .capability_gated, .metal = .executable, .evidence = "capability dump and native capture/debug tool" },
    .{ .name = "command_buffer_debug_markers", .vulkan = .validation_only, .metal = .executable, .evidence = "DebugMarkerCapabilities" },
    .{ .name = "native_gpu_timestamps", .vulkan = .capability_gated, .metal = .capability_gated, .evidence = "native query regression plus QuerySet.resultSource" },
    .{ .name = "boolean_occlusion_visibility", .vulkan = .capability_gated, .metal = .executable, .evidence = "offscreen native query readback/resolve and reset/reuse regression" },
    .{ .name = "scaled_texture_blit", .vulkan = .capability_gated, .metal = .typed_unsupported, .evidence = "format capability dump and UnsupportedTextureBlit" },
    .{ .name = "pipeline_statistics_queries", .vulkan = .typed_unsupported, .metal = .typed_unsupported, .evidence = "QuerySet creation gate" },
    .{ .name = "native_heap_backing", .vulkan = .executable, .metal = .executable, .evidence = "native placement resources and validated heap offsets" },
    .{ .name = "native_sparse_page_binding", .vulkan = .typed_unsupported, .metal = .typed_unsupported, .evidence = "resource-bound sparse mapping contract is absent" },
    .{ .name = "external_resource_import", .vulkan = .typed_unsupported, .metal = .executable, .evidence = "Metal borrowed-resource readback; Vulkan import contract is incomplete" },
    .{ .name = "queue_selection_with_graphics_fallback", .vulkan = .executable, .metal = .executable, .evidence = "physical queue selection when available with exact graphics fallback" },
    .{ .name = "ray_query", .vulkan = .typed_unsupported, .metal = .typed_unsupported, .evidence = "ordinary-stage acceleration-structure binding contract is absent" },
    .{ .name = "native_handle_escape_hatch", .vulkan = .native_escape_hatch, .metal = .native_escape_hatch, .evidence = "NativeHandles tagged union lifetime contract" },
};

pub fn validateBackendFeatureExpectations(entries: []const BackendFeatureExpectation) DevelopmentMatrixError!void {
    for (entries, 0..) |entry, i| {
        try entry.validate();
        for (entries[i + 1 ..]) |other| {
            if (std.mem.eql(u8, entry.name, other.name)) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub const BackendFeatureStatus = enum {
    native_lowering,
    backend_private_runtime,
    portable_runtime,
    portable_fallback,
    validation_noop,
    capability_gated,
    deferred_native_lowering,
};

pub const SyncQueryFeature = enum {
    explicit_resource_barriers,
    binary_fences,
    timeline_fences,
    events,
    shared_events,
    command_buffer_synchronization,
    logical_compute_queue,
    logical_transfer_queue,
    queue_ownership_transfer,
    timestamp_queries,
    occlusion_queries,
    occlusion_counting_queries,
    pipeline_statistics_queries,
};

pub const SyncQueryMatrixEntry = struct {
    feature: SyncQueryFeature,
    public_api: []const u8,
    portable_default: bool,
    escape_hatch: bool,
    vulkan_status: BackendFeatureStatus,
    metal_status: BackendFeatureStatus,
    validation: []const u8,

    pub fn validate(self: SyncQueryMatrixEntry) DevelopmentMatrixError!void {
        if (self.public_api.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.validation.len == 0) return DevelopmentMatrixError.EmptyValidationGoal;
    }
};

pub const sync_query_matrix = [_]SyncQueryMatrixEntry{
    .{
        .feature = .explicit_resource_barriers,
        .public_api = "BlitCommandEncoder.bufferBarrier/textureBarrier and ComputeCommandEncoder buffer/texture barriers",
        .portable_default = false,
        .escape_hatch = true,
        .vulkan_status = .native_lowering,
        .metal_status = .validation_noop,
        .validation = "runtime explicit barriers update resource usage state and Vulkan lowers to backend barriers",
    },
    .{
        .feature = .binary_fences,
        .public_api = "Device.makeFence with vkmtl.sync.FenceKind.binary",
        .portable_default = true,
        .escape_hatch = true,
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "runtime fences signal, wait, reset, and report timeout errors deterministically",
    },
    .{
        .feature = .timeline_fences,
        .public_api = "Device.makeFence with vkmtl.sync.FenceKind.timeline",
        .portable_default = false,
        .escape_hatch = true,
        .vulkan_status = .capability_gated,
        .metal_status = .capability_gated,
        .validation = "timeline fences reject creation until the feature gate is enabled",
    },
    .{
        .feature = .events,
        .public_api = "Device.makeEvent",
        .portable_default = true,
        .escape_hatch = true,
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "runtime events signal, wait, reset, and report timeout errors deterministically",
    },
    .{
        .feature = .shared_events,
        .public_api = "Device.makeEvent with shared=true",
        .portable_default = false,
        .escape_hatch = true,
        .vulkan_status = .capability_gated,
        .metal_status = .capability_gated,
        .validation = "shared events reject creation until the feature gate is enabled",
    },
    .{
        .feature = .command_buffer_synchronization,
        .public_api = "CommandBuffer.commitWithSynchronization",
        .portable_default = true,
        .escape_hatch = true,
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "synchronization descriptors validate object lifetimes and backend identity, wait before commit, and signal after commit",
    },
    .{
        .feature = .logical_compute_queue,
        .public_api = "vkmtl.command.planQueue(device, descriptor) and Device.queueWithDescriptor(.{ .kind = .compute })",
        .portable_default = true,
        .escape_hatch = false,
        .vulkan_status = .portable_fallback,
        .metal_status = .portable_fallback,
        .validation = "compute queue plans report requested, resolved, and fallback state before queue creation",
    },
    .{
        .feature = .logical_transfer_queue,
        .public_api = "vkmtl.command.planQueue(device, descriptor) and Device.queueWithDescriptor(.{ .kind = .transfer })",
        .portable_default = true,
        .escape_hatch = false,
        .vulkan_status = .portable_fallback,
        .metal_status = .portable_fallback,
        .validation = "transfer queue plans report requested, resolved, and fallback state before queue creation",
    },
    .{
        .feature = .queue_ownership_transfer,
        .public_api = "bufferOwnershipTransfer and textureOwnershipTransfer",
        .portable_default = false,
        .escape_hatch = true,
        .vulkan_status = .deferred_native_lowering,
        .metal_status = .validation_noop,
        .validation = "resource owner state rejects access from the wrong logical queue",
    },
    .{
        .feature = .timestamp_queries,
        .public_api = "vkmtl.diagnostics.QuerySet timestamp writes, resultSource, and readback/resolve",
        .portable_default = true,
        .escape_hatch = false,
        .vulkan_status = .native_lowering,
        .metal_status = .native_lowering,
        .validation = "timestamp queries select raw native GPU ticks only behind backend device gates, otherwise use logical sequence values; neither path claims calibrated duration",
    },
    .{
        .feature = .occlusion_queries,
        .public_api = "vkmtl.diagnostics.QuerySet occlusion begin/end and readback/resolve",
        .portable_default = false,
        .escape_hatch = false,
        .vulkan_status = .native_lowering,
        .metal_status = .native_lowering,
        .validation = "pass-bound query sets produce zero/nonzero native visibility, reject repeated slots until reset, and keep readback/resolve consistent",
    },
    .{
        .feature = .occlusion_counting_queries,
        .public_api = "vkmtl.diagnostics.QuerySet with OcclusionQueryMode.counting",
        .portable_default = false,
        .escape_hatch = false,
        .vulkan_status = .native_lowering,
        .metal_status = .native_lowering,
        .validation = "Metal counting visibility and queried/enabled Vulkan precise occlusion return exact u64 sample counts through existing readback and resolve paths",
    },
    .{
        .feature = .pipeline_statistics_queries,
        .public_api = "vkmtl.diagnostics.QuerySet with pipeline_statistics",
        .portable_default = false,
        .escape_hatch = true,
        .vulkan_status = .capability_gated,
        .metal_status = .capability_gated,
        .validation = "pipeline statistics remain typed unsupported because the scalar query contract cannot represent variable typed counters, availability, overflow, and calibration",
    },
};

pub fn validateSyncQueryMatrix(entries: []const SyncQueryMatrixEntry) DevelopmentMatrixError!void {
    for (entries, 0..) |entry, i| {
        try entry.validate();
        for (entries[i + 1 ..]) |other| {
            if (entry.feature == other.feature) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub const ResourceUtilityFeature = enum {
    full_texture_mipmap_generation,
    partial_mipmap_generation,
    unaligned_fill_buffer,
    texture_copy_array_layers,
    texture_copy_compatible_color_formats,
    depth_stencil_msaa_copies,
    fixed_sampler_border_colors,
    custom_sampler_border_colors,
    heap_planning,
    heap_aliasing_planning,
    native_heap_backed_resources,
    transient_allocation_diagnostics,
    memory_budget_pressure_reporting,
};

pub const ResourceUtilityMatrixEntry = struct {
    feature: ResourceUtilityFeature,
    public_api: []const u8,
    vulkan_status: BackendFeatureStatus,
    metal_status: BackendFeatureStatus,
    deferred_to: ?[]const u8 = null,
    validation: []const u8,

    pub fn validate(self: ResourceUtilityMatrixEntry) DevelopmentMatrixError!void {
        if (self.public_api.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.validation.len == 0) return DevelopmentMatrixError.EmptyValidationGoal;
        const deferred = self.vulkan_status == .deferred_native_lowering or self.metal_status == .deferred_native_lowering;
        if (deferred and self.deferred_to == null) return DevelopmentMatrixError.EmptyExpectation;
    }
};

pub const resource_utility_matrix = [_]ResourceUtilityMatrixEntry{
    .{
        .feature = .full_texture_mipmap_generation,
        .public_api = "BlitCommandEncoder.generateMipmaps",
        .vulkan_status = .native_lowering,
        .metal_status = .native_lowering,
        .validation = "full texture mipmap generation validates usage, format, and range before backend lowering",
    },
    .{
        .feature = .partial_mipmap_generation,
        .public_api = "vkmtl.transfer.GenerateMipmapsDescriptor partial mip/layer ranges",
        .vulkan_status = .deferred_native_lowering,
        .metal_status = .deferred_native_lowering,
        .deferred_to = "future backend extension; Period 44 parity report keeps the typed-unsupported lane explicit",
        .validation = "partial ranges remain typed unsupported at runtime",
    },
    .{
        .feature = .unaligned_fill_buffer,
        .public_api = "BlitCommandEncoder.fillBuffer",
        .vulkan_status = .portable_fallback,
        .metal_status = .native_lowering,
        .validation = "Vulkan aligned fills stay native and unaligned fills select staging fallback",
    },
    .{
        .feature = .texture_copy_array_layers,
        .public_api = "vkmtl.transfer.CopyTextureToTextureDescriptor.slice_count",
        .vulkan_status = .native_lowering,
        .metal_status = .portable_fallback,
        .validation = "array-layer texture copies validate slice ranges and lower to Vulkan layer_count or Metal per-slice calls",
    },
    .{
        .feature = .texture_copy_compatible_color_formats,
        .public_api = "vkmtl.command.BlitCommandEncoder.copyTextureToTexture with vkmtl.transfer.CopyTextureToTextureDescriptor",
        .vulkan_status = .native_lowering,
        .metal_status = .native_lowering,
        .validation = "copy-compatible color classes allow unorm/sRGB pairs while rejecting channel-order changes",
    },
    .{
        .feature = .depth_stencil_msaa_copies,
        .public_api = "vkmtl.transfer.CopyTextureToTextureDescriptor",
        .vulkan_status = .deferred_native_lowering,
        .metal_status = .deferred_native_lowering,
        .deferred_to = "future backend extension; Period 44 parity report keeps the typed-unsupported lane explicit",
        .validation = "depth/stencil and MSAA texture copies remain typed unsupported",
    },
    .{
        .feature = .fixed_sampler_border_colors,
        .public_api = "vkmtl.resource.SamplerAddressMode.clamp_to_border and vkmtl.resource.SamplerBorderColor",
        .vulkan_status = .native_lowering,
        .metal_status = .native_lowering,
        .validation = "fixed border colors are feature-gated and lower to native sampler state",
    },
    .{
        .feature = .custom_sampler_border_colors,
        .public_api = "vkmtl.resource.SamplerBorderColor",
        .vulkan_status = .deferred_native_lowering,
        .metal_status = .deferred_native_lowering,
        .deferred_to = "native-extension-only; Period 44 parity report keeps it outside portable support",
        .validation = "custom border colors are intentionally absent from the portable enum",
    },
    .{
        .feature = .heap_planning,
        .public_api = "Device.makeHeap and Heap.reserve",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "heap planning validates feature gates, capacity, alignment, and reservation offsets",
    },
    .{
        .feature = .heap_aliasing_planning,
        .public_api = "vkmtl.resource.HeapAliasingDescriptor and Heap.aliasingPlan",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "heap aliasing plans validate allocation ranges, lifetimes, and reusable overlap",
    },
    .{
        .feature = .native_heap_backed_resources,
        .public_api = "Heap",
        .vulkan_status = .deferred_native_lowering,
        .metal_status = .deferred_native_lowering,
        .deferred_to = "Period 32+ driver parity plan",
        .validation = "native heap-backed resources remain capability-gated",
    },
    .{
        .feature = .transient_allocation_diagnostics,
        .public_api = "vkmtl.resource.TransientAllocationDiagnostics and vkmtl.resource.transientAllocationDiagnostics(device, resources)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "transient diagnostics count resources, requested units, aliasable pairs, peak live units, and aliasing savings",
    },
    .{
        .feature = .memory_budget_pressure_reporting,
        .public_api = "vkmtl.diagnostics.MemoryBudgetDescriptor and vkmtl.diagnostics.memoryBudgetReport(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "memory budget reports classify nominal/warning/critical/over-budget pressure with native/fallback source metadata",
    },
};

pub fn validateResourceUtilityMatrix(entries: []const ResourceUtilityMatrixEntry) DevelopmentMatrixError!void {
    for (entries, 0..) |entry, i| {
        try entry.validate();
        for (entries[i + 1 ..]) |other| {
            if (entry.feature == other.feature) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub const PlatformInteropFeature = enum {
    surface_registry,
    native_multi_surface,
    present_mode_resolution,
    native_present_mode_query,
    external_interop_capability_matrix,
    external_memory_and_buffer_wrappers,
    native_external_memory_import,
    external_texture_wrapper,
    native_external_texture_import,
    external_sync_wrappers,
    native_external_sync_lowering,
    native_command_insertion_api,
    native_command_handle_lowering,
};

pub const PlatformInteropMatrixEntry = struct {
    feature: PlatformInteropFeature,
    public_api: []const u8,
    vulkan_status: BackendFeatureStatus,
    metal_status: BackendFeatureStatus,
    deferred_to: ?[]const u8 = null,
    validation: []const u8,

    pub fn validate(self: PlatformInteropMatrixEntry) DevelopmentMatrixError!void {
        if (self.public_api.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.validation.len == 0) return DevelopmentMatrixError.EmptyValidationGoal;
        const deferred = self.vulkan_status == .deferred_native_lowering or self.metal_status == .deferred_native_lowering;
        if (deferred and self.deferred_to == null) return DevelopmentMatrixError.EmptyExpectation;
    }
};

pub const platform_interop_matrix = [_]PlatformInteropMatrixEntry{
    .{
        .feature = .surface_registry,
        .public_api = "vkmtl.presentation.makeSurfaceCollection(device) and vkmtl.presentation.SurfaceCollection",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "surface registries track independent descriptors, resize state, frame state, and generation handles",
    },
    .{
        .feature = .native_multi_surface,
        .public_api = "DeviceFeatures.multi_surface",
        .vulkan_status = .deferred_native_lowering,
        .metal_status = .deferred_native_lowering,
        .deferred_to = "Period 32+ driver parity plan",
        .validation = "native multiple-swapchain and multiple-layer presentation remains feature-gated",
    },
    .{
        .feature = .present_mode_resolution,
        .public_api = "vkmtl.presentation.PresentModeSupport and vkmtl.presentation.FramePacingDiagnostics",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "present-mode fallback and frame pacing counters are deterministic runtime state",
    },
    .{
        .feature = .native_present_mode_query,
        .public_api = "vkmtl.presentation.presentModeSupport(device)",
        .vulkan_status = .deferred_native_lowering,
        .metal_status = .deferred_native_lowering,
        .deferred_to = "Period 32+ driver parity plan",
        .validation = "surface-specific native present-mode/display-sync support remains conservative",
    },
    .{
        .feature = .external_interop_capability_matrix,
        .public_api = "vkmtl.interop.ExternalInteropCapabilityMatrix and vkmtl.interop.externalInteropCapabilityMatrix(device)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "external handle support is classified by backend, platform, resource, handle kind, and interop lane",
    },
    .{
        .feature = .external_memory_and_buffer_wrappers,
        .public_api = "vkmtl.interop.ExternalMemory, ExternalBuffer, and ExternalInteropImportPlan",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "external memory and buffer wrappers validate handles, ownership, backend, lifetime, and import lane plans",
    },
    .{
        .feature = .native_external_memory_import,
        .public_api = "vkmtl.interop.ExternalMemory.importedBuffer and ExternalBuffer.importedBuffer",
        .vulkan_status = .capability_gated,
        .metal_status = .native_lowering,
        .validation = "Metal imports a validated same-device MTLBuffer; Vulkan rejects until exact allocation metadata exists",
    },
    .{
        .feature = .external_texture_wrapper,
        .public_api = "vkmtl.interop.ExternalTexture and vkmtl.interop.ExternalTextureUsagePlan",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "external texture wrappers validate texture shape, usage intent, backend handle kind, ownership, and lifetime",
    },
    .{
        .feature = .native_external_texture_import,
        .public_api = "vkmtl.interop.ExternalTexture.importedTexture",
        .vulkan_status = .capability_gated,
        .metal_status = .native_lowering,
        .validation = "Metal imports validated same-device MTLTexture or single-plane IOSurface resources; Vulkan rejects incomplete image metadata",
    },
    .{
        .feature = .external_sync_wrappers,
        .public_api = "vkmtl.interop external semaphore, event, and synchronization contracts",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "external synchronization wrappers validate backend ownership, wait/signal counts, and native interop requirements before commit",
    },
    .{
        .feature = .native_external_sync_lowering,
        .public_api = "CommandBuffer.commitWithExternalSynchronization and vkmtl.interop.diagnoseExternalInteropImport(device, descriptor)",
        .vulkan_status = .capability_gated,
        .metal_status = .capability_gated,
        .validation = "external submit synchronization stays closed because wait/signal payload and import-ownership rules are absent",
    },
    .{
        .feature = .native_command_insertion_api,
        .public_api = "Render/Compute/BlitCommandEncoder.insertNativeCommands",
        .vulkan_status = .capability_gated,
        .metal_status = .capability_gated,
        .validation = "native insertion validates feature gate, callback presence, and encoder kind",
    },
    .{
        .feature = .native_command_handle_lowering,
        .public_api = "vkmtl.native.CommandInsertionDescriptor",
        .vulkan_status = .capability_gated,
        .metal_status = .capability_gated,
        .validation = "context handles cannot substitute for an active command-buffer/encoder handle, so insertion remains closed",
    },
};

pub fn validatePlatformInteropMatrix(entries: []const PlatformInteropMatrixEntry) DevelopmentMatrixError!void {
    for (entries, 0..) |entry, i| {
        try entry.validate();
        for (entries[i + 1 ..]) |other| {
            if (entry.feature == other.feature) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub const ProductionHardeningFeature = enum {
    object_cache_lookup_diagnostics,
    native_object_handle_pooling,
    driver_cache_planning,
    native_driver_cache_lowering,
    runtime_cache_manifest_planning,
    pipeline_artifact_compatibility_planning,
    runtime_cache_manifest_io,
    runtime_diagnostics_snapshot,
    capture_name_helpers,
    stability_run_planning,
    gpu_backed_soak_loops,
};

pub const ProductionHardeningMatrixEntry = struct {
    feature: ProductionHardeningFeature,
    public_api: []const u8,
    vulkan_status: BackendFeatureStatus,
    metal_status: BackendFeatureStatus,
    deferred_to: ?[]const u8 = null,
    validation: []const u8,

    pub fn validate(self: ProductionHardeningMatrixEntry) DevelopmentMatrixError!void {
        if (self.public_api.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.validation.len == 0) return DevelopmentMatrixError.EmptyValidationGoal;
        const deferred = self.vulkan_status == .deferred_native_lowering or self.metal_status == .deferred_native_lowering;
        if (deferred and self.deferred_to == null) return DevelopmentMatrixError.EmptyExpectation;
    }
};

pub const production_hardening_matrix = [_]ProductionHardeningMatrixEntry{
    .{
        .feature = .object_cache_lookup_diagnostics,
        .public_api = "cache_policy fields and vkmtl.diagnostics.objectCacheDiagnostics(device)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "cacheable descriptors record hits, misses, equivalent recreations, and policy opt-outs",
    },
    .{
        .feature = .native_object_handle_pooling,
        .public_api = "ObjectCachePolicy reuse mode",
        .vulkan_status = .deferred_native_lowering,
        .metal_status = .deferred_native_lowering,
        .deferred_to = "Period 32+ driver parity plan",
        .validation = "lookup diagnostics do not claim native handle reuse until lifetime-safe pools exist",
    },
    .{
        .feature = .driver_cache_planning,
        .public_api = "vkmtl.diagnostics.planDriverPipelineCache(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "driver pipeline cache descriptors validate identity and native feature reports",
    },
    .{
        .feature = .native_driver_cache_lowering,
        .public_api = "RenderPipelineDescriptor.driver_cache and ComputePipelineDescriptor.driver_cache",
        .vulkan_status = .native_lowering,
        .metal_status = .native_lowering,
        .validation = "VkPipelineCache and MTLBinaryArchive consume, populate, persist, recover stale identity, and honor read-only mode",
    },
    .{
        .feature = .runtime_cache_manifest_planning,
        .public_api = "vkmtl.diagnostics.RuntimeCachePlanDescriptor and vkmtl.diagnostics.planRuntimeCache(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "runtime cache manifests classify missing, stale, backend, source, and toolchain mismatches",
    },
    .{
        .feature = .pipeline_artifact_compatibility_planning,
        .public_api = "vkmtl.diagnostics.PipelineArtifactCachePlanDescriptor and vkmtl.diagnostics.planPipelineArtifactCache(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "pipeline artifact manifests classify stale schema, backend, shader, entry point, reflection, format, and toolchain mismatches",
    },
    .{
        .feature = .runtime_cache_manifest_io,
        .public_api = "vkmtl.diagnostics.RuntimeCachePlan",
        .vulkan_status = .deferred_native_lowering,
        .metal_status = .deferred_native_lowering,
        .deferred_to = "Period 32+ driver parity plan",
        .validation = "automatic manifest read/write is deferred until native cache ownership lands",
    },
    .{
        .feature = .runtime_diagnostics_snapshot,
        .public_api = "vkmtl.diagnostics.runtimeDiagnostics(device)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "runtime diagnostics expose live resources, pending retirements, work serials, and object-cache counters",
    },
    .{
        .feature = .capture_name_helpers,
        .public_api = "vkmtl.diagnostics.CaptureNameDescriptor and vkmtl.diagnostics.writeCaptureName(device, descriptor, buffer)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "capture names format scope, backend, and frame metadata deterministically",
    },
    .{
        .feature = .stability_run_planning,
        .public_api = "vkmtl.diagnostics.StabilityRunDescriptor, StabilityRunPlan, and StabilityRunDiagnostics",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "stability plans count resize, churn, shader-cache, upload, and unaligned-fill fallback checks",
    },
    .{
        .feature = .gpu_backed_soak_loops,
        .public_api = "run-gpu-soak repository tool",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "windowed presentation, resource, upload/readback, shader-resolution, and portable residency churn runs through real backend commands",
    },
};

pub fn validateProductionHardeningMatrix(entries: []const ProductionHardeningMatrixEntry) DevelopmentMatrixError!void {
    for (entries, 0..) |entry, i| {
        try entry.validate();
        for (entries[i + 1 ..]) |other| {
            if (entry.feature == other.feature) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub const AdvancedResourceGeometryFeature = enum {
    sparse_buffer_planning,
    sparse_texture_planning,
    sparse_mapping_commit_planning,
    sparse_residency_churn_planning,
    native_sparse_page_binding,
    tessellation_lowering_planning,
    native_tessellation_pipeline,
    mesh_task_lowering_planning,
    native_mesh_task_pipeline,
    advanced_geometry_examples,
};

pub const AdvancedResourceGeometryMatrixEntry = struct {
    feature: AdvancedResourceGeometryFeature,
    public_api: []const u8,
    vulkan_status: BackendFeatureStatus,
    metal_status: BackendFeatureStatus,
    deferred_to: ?[]const u8 = null,
    validation: []const u8,

    pub fn validate(self: AdvancedResourceGeometryMatrixEntry) DevelopmentMatrixError!void {
        if (self.public_api.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.validation.len == 0) return DevelopmentMatrixError.EmptyValidationGoal;
        const deferred = self.vulkan_status == .deferred_native_lowering or self.metal_status == .deferred_native_lowering;
        if (deferred and self.deferred_to == null) return DevelopmentMatrixError.EmptyExpectation;
    }
};

pub const advanced_resource_geometry_matrix = [_]AdvancedResourceGeometryMatrixEntry{
    .{
        .feature = .sparse_buffer_planning,
        .public_api = "vkmtl.resource.SparseBufferDescriptor and vkmtl.native.planSparseBufferLowering(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "sparse buffer page size and page count are planned from native feature reports",
    },
    .{
        .feature = .sparse_texture_planning,
        .public_api = "vkmtl.resource.SparseTextureDescriptor and vkmtl.native.planSparseTextureLowering(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "sparse/tiled texture page grids and lowering modes are planned from native feature reports",
    },
    .{
        .feature = .sparse_mapping_commit_planning,
        .public_api = "vkmtl.resource.SparseMappingCommitDescriptor and vkmtl.resource.planSparseMappingCommit(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "commit plans summarize commit/evict counts, buffer bytes, and texture pages",
    },
    .{
        .feature = .sparse_residency_churn_planning,
        .public_api = "vkmtl.resource.SparseResidencyChurnDescriptor, SparseResidencyMap.runChurn, and vkmtl.resource.planSparseResidencyChurn(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "residency churn plans summarize repeated commit/evict cycles and deterministic peak resident pressure",
    },
    .{
        .feature = .native_sparse_page_binding,
        .public_api = "vkmtl.resource sparse mapping contracts; backend lowering is internal",
        .vulkan_status = .deferred_native_lowering,
        .metal_status = .deferred_native_lowering,
        .deferred_to = "Period 32+ driver parity plan",
        .validation = "native sparse/tiled resource objects and page binding remain explicit backend work",
    },
    .{
        .feature = .tessellation_lowering_planning,
        .public_api = "vkmtl.render.TessellationDescriptor, TessellationPatchDrawDescriptor, and vkmtl.render.planTessellationPatchDraw(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "tessellation draw plans expose patch metadata, Vulkan draw metadata, and Metal factor-buffer requirements",
    },
    .{
        .feature = .native_tessellation_pipeline,
        .public_api = "vkmtl.native.vulkan.planTessellationPatchDraw(device, descriptor) and vkmtl.native.metal.planTessellationPatchDraw(device, descriptor)",
        .vulkan_status = .deferred_native_lowering,
        .metal_status = .deferred_native_lowering,
        .deferred_to = "native tessellation pipeline hooks plus future physical-device pixel evidence",
        .validation = "native tessellation pipeline creation and executable draw commands remain explicit backend work",
    },
    .{
        .feature = .mesh_task_lowering_planning,
        .public_api = "vkmtl.render.MeshPipelineDescriptor, MeshDispatchDescriptor, and vkmtl.render.planMeshDispatch(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "mesh/task dispatch plans expose Vulkan task/mesh and Metal object/mesh metadata",
    },
    .{
        .feature = .native_mesh_task_pipeline,
        .public_api = "vkmtl.native.vulkan.planMeshDispatch(device, descriptor) and vkmtl.native.metal.planMeshDispatch(device, descriptor)",
        .vulkan_status = .deferred_native_lowering,
        .metal_status = .deferred_native_lowering,
        .deferred_to = "native mesh/task pipeline hooks plus future physical-device pixel evidence",
        .validation = "native mesh/task pipeline creation and executable draw commands remain explicit backend work",
    },
    .{
        .feature = .advanced_geometry_examples,
        .public_api = "examples/tessellation and examples/mesh_shader",
        .vulkan_status = .capability_gated,
        .metal_status = .capability_gated,
        .validation = "windowed examples exercise public patch draw and mesh dispatch planning APIs without importing backend-private modules",
    },
};

pub fn validateAdvancedResourceGeometryMatrix(entries: []const AdvancedResourceGeometryMatrixEntry) DevelopmentMatrixError!void {
    for (entries, 0..) |entry, i| {
        try entry.validate();
        for (entries[i + 1 ..]) |other| {
            if (entry.feature == other.feature) return DevelopmentMatrixError.DuplicateName;
        }
    }
}

pub const RayTracingNativeParityFeature = enum {
    acceleration_structure_build_planning,
    acceleration_structure_maintenance_planning,
    native_acceleration_structure_builds,
    tlas_instance_layout_planning,
    ray_tracing_pipeline_planning,
    native_ray_tracing_pipelines,
    shader_binding_table_dispatch_planning,
    complex_shader_binding_table_planning,
    native_ray_dispatch_commands,
    texture_dispatch_and_color_presentation,
    ray_query_planning,
    metal_ray_tracing_mapping_planning,
    native_metal_ray_tracing_execution,
    ray_tracing_stress_planning,
    native_advanced_closure_inventory,
    native_advanced_backend_execution,
    parity_semantics_and_soak,
    advanced_native_examples,
};

pub const RayTracingNativeParityMatrixEntry = struct {
    feature: RayTracingNativeParityFeature,
    public_api: []const u8,
    vulkan_status: BackendFeatureStatus,
    metal_status: BackendFeatureStatus,
    deferred_to: ?[]const u8 = null,
    validation: []const u8,

    pub fn validate(self: RayTracingNativeParityMatrixEntry) DevelopmentMatrixError!void {
        if (self.public_api.len == 0) return DevelopmentMatrixError.EmptyName;
        if (self.validation.len == 0) return DevelopmentMatrixError.EmptyValidationGoal;
        const deferred = self.vulkan_status == .deferred_native_lowering or self.metal_status == .deferred_native_lowering;
        if (deferred and self.deferred_to == null) return DevelopmentMatrixError.EmptyExpectation;
    }
};

pub const ray_tracing_native_parity_matrix = [_]RayTracingNativeParityMatrixEntry{
    .{
        .feature = .acceleration_structure_build_planning,
        .public_api = "vkmtl.ray_tracing.AccelerationStructureBuildDescriptor and vkmtl.ray_tracing.planAccelerationStructureBuild(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "build/update plans expose geometry count, result size, scratch size, and compaction intent",
    },
    .{
        .feature = .acceleration_structure_maintenance_planning,
        .public_api = "vkmtl.ray_tracing.AccelerationStructureMaintenanceDescriptor and vkmtl.ray_tracing.planAccelerationStructureMaintenance(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "update, refit, and compaction plans validate feature gates, scratch needs, and destination AS requirements",
    },
    .{
        .feature = .native_acceleration_structure_builds,
        .public_api = "vkmtl.ray_tracing.AccelerationStructureBuildPlan",
        .vulkan_status = .backend_private_runtime,
        .metal_status = .backend_private_runtime,
        .deferred_to = "Period 32+ driver parity plan",
        .validation = "runtime acceleration structures own backend-private handle state and build command records",
    },
    .{
        .feature = .tlas_instance_layout_planning,
        .public_api = "vkmtl.ray_tracing.TopLevelAccelerationStructureLayoutDescriptor and vkmtl.ray_tracing.planTopLevelAccelerationStructureLayout(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "many-instance TLAS metadata validates transforms, masks, custom indices, material indices, mixed triangle/procedural ranges, and SBT offsets",
    },
    .{
        .feature = .ray_tracing_pipeline_planning,
        .public_api = "internal ray-tracing pipeline lowering inventory (not public API)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "pipeline plans expose shader-group counts and Metal function-table metadata",
    },
    .{
        .feature = .native_ray_tracing_pipelines,
        .public_api = "vkmtl.ray_tracing.RayTracingPipelineState",
        .vulkan_status = .backend_private_runtime,
        .metal_status = .backend_private_runtime,
        .deferred_to = "Period 32+ driver parity plan",
        .validation = "runtime ray tracing pipeline states own backend-private shader-group and function-table metadata",
    },
    .{
        .feature = .shader_binding_table_dispatch_planning,
        .public_api = "vkmtl.ray_tracing.RayDispatchPlan and vkmtl.ray_tracing.planRayDispatch(device, sbt, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "dispatch plans combine SBT layout, dimensions, and total ray counts",
    },
    .{
        .feature = .complex_shader_binding_table_planning,
        .public_api = "vkmtl.ray_tracing.ComplexShaderBindingTableDescriptor and vkmtl.ray_tracing.planComplexShaderBindingTable(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "complex SBT plans validate miss/hit/callable record counts, procedural hit ranges, alignment, and total record limits",
    },
    .{
        .feature = .native_ray_dispatch_commands,
        .public_api = "vkmtl.ray_tracing.RayDispatchPlan",
        .vulkan_status = .backend_private_runtime,
        .metal_status = .backend_private_runtime,
        .deferred_to = "Period 32+ driver parity plan",
        .validation = "runtime SBT objects own backend-private records and dispatch command metadata",
    },
    .{
        .feature = .texture_dispatch_and_color_presentation,
        .public_api = "vkmtl.CommandBuffer.dispatchRaysToTexture and vkmtl.ray_tracing.RayTracingTextureResources",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "both backends write a caller-owned texture and preserve per-dispatch state; applications own display composition, while the legacy drawable route performs only a validated raw BGRA8 copy",
    },
    .{
        .feature = .ray_query_planning,
        .public_api = "vkmtl.ray_tracing.RayQueryDescriptor and vkmtl.ray_tracing.planRayQuery(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .validation_noop,
        .validation = "Vulkan ray query plans validate shader stage, traversal depth, procedural requirements, and Metal unsupported behavior",
    },
    .{
        .feature = .metal_ray_tracing_mapping_planning,
        .public_api = "vkmtl.native.metal.RayTracingMappingPlan and vkmtl.native.metal.planRayTracingMapping(device, descriptor)",
        .vulkan_status = .validation_noop,
        .metal_status = .portable_runtime,
        .validation = "Metal mapping plans expose function-table and intersection-function requirements",
    },
    .{
        .feature = .native_metal_ray_tracing_execution,
        .public_api = "vkmtl.native.metal.RayTracingMappingPlan",
        .vulkan_status = .validation_noop,
        .metal_status = .backend_private_runtime,
        .deferred_to = "Period 31 Phase 4 and Phase 5",
        .validation = "Metal execution mappings own backend-private function-table and acceleration-slot metadata",
    },
    .{
        .feature = .ray_tracing_stress_planning,
        .public_api = "vkmtl.ray_tracing.RayTracingStressDescriptor and vkmtl.ray_tracing.planRayTracingStress(device, descriptor)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "stress plans combine AS maintenance, TLAS metadata, complex SBT, optional ray query, dispatch size, and iteration counts",
    },
    .{
        .feature = .native_advanced_closure_inventory,
        .public_api = "internal native-advanced planning inventory (not public API)",
        .vulkan_status = .portable_runtime,
        .metal_status = .portable_runtime,
        .validation = "internal native-advanced planning inventory stays explicit without becoming public API",
    },
    .{
        .feature = .native_advanced_backend_execution,
        .public_api = "internal native-advanced backend inventory (not public API)",
        .vulkan_status = .backend_private_runtime,
        .metal_status = .backend_private_runtime,
        .deferred_to = "Period 31 first-triangle Metal driver work, Period 32 first-triangle Vulkan driver work, and Period 32+ parity plan",
        .validation = "internal native-advanced inventory keeps backend execution work split by backend and scope",
    },
    .{
        .feature = .parity_semantics_and_soak,
        .public_api = "backend parity matrix",
        .vulkan_status = .backend_private_runtime,
        .metal_status = .backend_private_runtime,
        .deferred_to = "Period 44 parity report tracks remaining advanced-native evidence",
        .validation = "common GPU soak is executable while advanced native pressure lanes remain explicit missing evidence",
    },
    .{
        .feature = .advanced_native_examples,
        .public_api = "examples/ray_traced_scene and future native advanced examples",
        .vulkan_status = .backend_private_runtime,
        .metal_status = .backend_private_runtime,
        .deferred_to = "Period 31 Phase 5 and Period 32 Phase 5",
        .validation = "ray_traced_scene verifies backend-private runtime records until Period31 makes Metal pixel-producing and Period32 makes Vulkan pixel-producing",
    },
};

pub fn validateRayTracingNativeParityMatrix(entries: []const RayTracingNativeParityMatrixEntry) DevelopmentMatrixError!void {
    for (entries, 0..) |entry, i| {
        try entry.validate();
        for (entries[i + 1 ..]) |other| {
            if (entry.feature == other.feature) return DevelopmentMatrixError.DuplicateName;
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
    runtime_sync_objects,
    logical_queue_ownership,
    query_readback,
    debug_marker_contract,
    resource_utilities,
    platform_interop,
    production_hardening,
    advanced_resource_geometry,
    ray_tracing_native_parity,
    period44_device_evidence,
    voxel_world_pressure_test,
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
    .{
        .name = "runtime_sync_objects",
        .kind = .runtime_sync_objects,
        .test_location = "src/runtime/window_context.zig runtime command buffer synchronization waits before submit and signals after submit",
        .expectation = "fences, events, and synchronization descriptors expose deterministic signal, wait, reset, timeout, and unsupported-gate behavior",
    },
    .{
        .name = "logical_queue_ownership",
        .kind = .logical_queue_ownership,
        .test_location = "src/runtime/window_context.zig runtime queue ownership transfers gate cross queue resource use",
        .expectation = "queue planning, queue views, and ownership transfers reject cross-queue use without explicit transfer",
    },
    .{
        .name = "query_readback",
        .kind = .query_readback,
        .test_location = "src/runtime/window_context.zig runtime query sets support encoder writes and readback",
        .expectation = "query sets validate bound-pass identity, Boolean/counting gates, availability, one-write-per-reset slots, copy usage, type/range gates, native readback/resolve agreement, and truthful timestamp sources",
    },
    .{
        .name = "debug_marker_contract",
        .kind = .debug_marker_contract,
        .test_location = "src/core.zig, src/runtime/window_context.zig, backend debug bridges, tools/profiling_plan/main.zig, and examples/capability_dump/main.zig Period 43 tests",
        .expectation = "invalid markers fail before native calls; capabilities, capture gates, query sources, profiling fallback, and issue snapshots remain truthful",
    },
    .{
        .name = "resource_utilities",
        .kind = .resource_utilities,
        .test_location = "src/core.zig, src/runtime/window_context.zig, and backend command/capability modules Period 24 and Period 42 resource utility tests",
        .expectation = "mipmaps, fills, copy alignment and subresources, depth/stencil aspects, blit gates, MSAA semantics, subresource state, sampler borders, heaps, and transient diagnostics keep typed validation",
    },
    .{
        .name = "platform_interop",
        .kind = .platform_interop,
        .test_location = "src/core.zig and src/runtime/window_context.zig Period 25 platform interop tests",
        .expectation = "surface registries, present diagnostics, external wrappers, external sync, and native insertion gates keep typed validation",
    },
    .{
        .name = "production_hardening",
        .kind = .production_hardening,
        .test_location = "src/core.zig, src/runtime/window_context.zig, src/backend/vulkan/command.zig, and tools/stability_plan/main.zig Period 26 tests",
        .expectation = "cache planning, runtime diagnostics, capture names, stability plans, and Vulkan fallback diagnostics stay deterministic",
    },
    .{
        .name = "advanced_resource_geometry",
        .kind = .advanced_resource_geometry,
        .test_location = "src/core.zig and src/runtime/window_context.zig Period 27 tests",
        .expectation = "sparse/tiled resource planning, residency commit/churn plans, tessellation draw planning, and mesh/task dispatch planning stay capability-gated",
    },
    .{
        .name = "ray_tracing_native_parity",
        .kind = .ray_tracing_native_parity,
        .test_location = "src/core.zig, src/runtime/window_context.zig, Vulkan dispatch invariants, and examples/ray_traced_scene focused tests",
        .expectation = "ray tracing planning and advanced gaps stay explicit while Period 55 caller-owned dispatch and Period 56 request/selection, exact drawable validation, legacy raw copy, finite-run, and color references remain deterministic",
    },
    .{
        .name = "period44_device_evidence",
        .kind = .period44_device_evidence,
        .test_location = "tools/development_matrix.zig, examples/offscreen_texture/main.zig, tools/gpu_soak/main.zig, and Period 44 workflows/scripts",
        .expectation = "hosted builds, physical smoke, pixel readback, soak, and release gates stay distinct; all nine explicit gates are observed",
    },
    .{
        .name = "voxel_world_pressure_test",
        .kind = .voxel_world_pressure_test,
        .test_location = "examples/voxel_world mesher/camera tests, finite profile runs, and Period 19 physical Metal evidence",
        .expectation = "smoke/default/stress stay within 9/81/289 resident bounds, expose streaming and frame metrics, and end with voxel_world_pressure_test=ok",
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
        .expectation = "backend selection, Slang tool, Vulkan runtime, and shader artifact configuration",
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
        .path = "docs/develop/validation.md",
        .expectation = "backend and host validation rows",
    },
    .{
        .name = "validation_matrix",
        .path = "docs/develop/validation.md",
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
    .{
        .name = "period44_parity_report",
        .path = "docs/develop/validation.md",
        .expectation = "observed Metal, Vulkan, and hosted evidence, known unsupported lanes, and release decision",
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
    try std.testing.expectEqual(@as(usize, 17), implementedExampleCount(examples[0..]));
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
    var hosted_package_smokes: usize = 0;
    var has_sync_query_regression = false;
    var has_resource_utility_regression = false;
    var has_platform_interop_regression = false;
    var has_production_hardening_regression = false;
    var has_advanced_resource_geometry_regression = false;
    var has_advanced_geometry_feature_gates = false;
    var has_ray_tracing_native_parity_regression = false;
    var has_ray_tracing_metal_color_path = false;
    var has_ray_tracing_vulkan_color_path = false;
    for (backend_test_matrix) |entry| {
        if (entry.requires_runtime_configuration and !entry.required) configured_optional += 1;
        if ((entry.host == .macos or entry.host == .linux or entry.host == .windows) and
            entry.required and
            std.mem.indexOf(u8, entry.command, "scripts/ci/run_package_smoke.sh") != null)
        {
            hosted_package_smokes += 1;
        }
        if (std.mem.eql(u8, entry.name, "sync_query_regression")) has_sync_query_regression = true;
        if (std.mem.eql(u8, entry.name, "resource_utility_regression")) has_resource_utility_regression = true;
        if (std.mem.eql(u8, entry.name, "platform_interop_regression")) has_platform_interop_regression = true;
        if (std.mem.eql(u8, entry.name, "production_hardening_regression")) has_production_hardening_regression = true;
        if (std.mem.eql(u8, entry.name, "advanced_resource_geometry_regression")) has_advanced_resource_geometry_regression = true;
        if (std.mem.eql(u8, entry.name, "advanced_geometry_feature_gates")) has_advanced_geometry_feature_gates = true;
        if (std.mem.eql(u8, entry.name, "ray_tracing_native_parity_regression")) has_ray_tracing_native_parity_regression = true;
        if (std.mem.eql(u8, entry.name, "ray_tracing_metal_color_path")) has_ray_tracing_metal_color_path = true;
        if (std.mem.eql(u8, entry.name, "ray_tracing_vulkan_color_path")) has_ray_tracing_vulkan_color_path = true;
    }
    try std.testing.expect(configured_optional >= 1);
    try std.testing.expectEqual(@as(usize, 3), hosted_package_smokes);
    try std.testing.expect(has_sync_query_regression);
    try std.testing.expect(has_resource_utility_regression);
    try std.testing.expect(has_platform_interop_regression);
    try std.testing.expect(has_production_hardening_regression);
    try std.testing.expect(has_advanced_resource_geometry_regression);
    try std.testing.expect(has_advanced_geometry_feature_gates);
    try std.testing.expect(has_ray_tracing_native_parity_regression);
    try std.testing.expect(has_ray_tracing_metal_color_path);
    try std.testing.expect(has_ray_tracing_vulkan_color_path);
}

test "validation jobs separate hosted builds from physical GPU evidence" {
    try validateValidationJobs(validation_jobs[0..]);

    var hosted_jobs: usize = 0;
    var hosted_package_smokes: usize = 0;
    var physical_metal = false;
    var physical_vulkan = false;
    var release_gpu_jobs: usize = 0;
    for (validation_jobs) |entry| {
        if (entry.execution == .hosted_build) {
            hosted_jobs += 1;
            try std.testing.expectEqual(ValidationDeviceClass.none, entry.device_class);
            try std.testing.expectEqual(ValidationExpectedOutcome.build_only, entry.expected_outcome);
            if (std.mem.indexOf(u8, entry.command, "scripts/ci/run_package_smoke.sh") != null) {
                hosted_package_smokes += 1;
            }
        }
        if (entry.execution == .self_hosted_gpu) {
            try std.testing.expect(entry.attach_capability_dump);
            if (entry.backend == .metal) physical_metal = true;
            if (entry.backend == .vulkan) physical_vulkan = true;
        }
        if (entry.required_for_release and entry.device_class != .none) release_gpu_jobs += 1;
    }

    try std.testing.expectEqual(@as(usize, 3), hosted_jobs);
    try std.testing.expectEqual(hosted_jobs, hosted_package_smokes);
    try std.testing.expect(physical_metal);
    try std.testing.expect(physical_vulkan);
    try std.testing.expect(release_gpu_jobs >= 4);
}

test "feature expectations keep backend evidence lanes explicit" {
    try validateBackendFeatureExpectations(backend_feature_expectations[0..]);

    var typed_unsupported: usize = 0;
    var executable: usize = 0;
    var capability_gated: usize = 0;
    var validation_only: usize = 0;
    var native_escape_hatches: usize = 0;
    for (backend_feature_expectations) |entry| {
        if (entry.vulkan == .typed_unsupported or entry.metal == .typed_unsupported) typed_unsupported += 1;
        if (entry.vulkan == .executable or entry.metal == .executable) executable += 1;
        if (entry.vulkan == .capability_gated or entry.metal == .capability_gated) capability_gated += 1;
        if (entry.vulkan == .validation_only or entry.metal == .validation_only) validation_only += 1;
        if (entry.vulkan == .native_escape_hatch or entry.metal == .native_escape_hatch) native_escape_hatches += 1;
    }

    try std.testing.expect(typed_unsupported >= 3);
    try std.testing.expect(executable >= 3);
    try std.testing.expect(capability_gated >= 3);
    try std.testing.expect(validation_only >= 1);
    try std.testing.expect(native_escape_hatches >= 1);
}

test "sync and query backend matrix is complete" {
    try validateSyncQueryMatrix(sync_query_matrix[0..]);

    var seen = [_]bool{false} ** @typeInfo(SyncQueryFeature).@"enum".fields.len;
    var portable_defaults: usize = 0;
    var escape_hatches: usize = 0;
    var capability_gated: usize = 0;
    var deferred_native: usize = 0;

    for (sync_query_matrix) |entry| {
        seen[@intFromEnum(entry.feature)] = true;
        if (entry.portable_default) portable_defaults += 1;
        if (entry.escape_hatch) escape_hatches += 1;
        if (entry.vulkan_status == .capability_gated or entry.metal_status == .capability_gated) capability_gated += 1;
        if (entry.vulkan_status == .deferred_native_lowering or entry.metal_status == .deferred_native_lowering) deferred_native += 1;
    }

    for (seen) |was_seen| {
        try std.testing.expect(was_seen);
    }
    try std.testing.expect(portable_defaults >= 4);
    try std.testing.expect(escape_hatches >= 4);
    try std.testing.expect(capability_gated >= 3);
    try std.testing.expect(deferred_native >= 1);
}

test "resource utility backend matrix is complete" {
    try validateResourceUtilityMatrix(resource_utility_matrix[0..]);

    var seen = [_]bool{false} ** @typeInfo(ResourceUtilityFeature).@"enum".fields.len;
    var native_paths: usize = 0;
    var fallback_paths: usize = 0;
    var deferred_paths: usize = 0;

    for (resource_utility_matrix) |entry| {
        seen[@intFromEnum(entry.feature)] = true;
        if (entry.vulkan_status == .native_lowering or entry.metal_status == .native_lowering) native_paths += 1;
        if (entry.vulkan_status == .portable_fallback or entry.metal_status == .portable_fallback) fallback_paths += 1;
        if (entry.vulkan_status == .deferred_native_lowering or entry.metal_status == .deferred_native_lowering) {
            deferred_paths += 1;
            try std.testing.expect(entry.deferred_to != null);
        }
    }

    for (seen) |was_seen| {
        try std.testing.expect(was_seen);
    }
    try std.testing.expect(native_paths >= 4);
    try std.testing.expect(fallback_paths >= 2);
    try std.testing.expect(deferred_paths >= 3);
}

test "platform interop backend matrix is complete" {
    try validatePlatformInteropMatrix(platform_interop_matrix[0..]);

    var seen = [_]bool{false} ** @typeInfo(PlatformInteropFeature).@"enum".fields.len;
    var runtime_paths: usize = 0;
    var capability_gated: usize = 0;
    var deferred_paths: usize = 0;

    for (platform_interop_matrix) |entry| {
        seen[@intFromEnum(entry.feature)] = true;
        if (entry.vulkan_status == .portable_runtime or entry.metal_status == .portable_runtime) runtime_paths += 1;
        if (entry.vulkan_status == .capability_gated or entry.metal_status == .capability_gated) capability_gated += 1;
        if (entry.vulkan_status == .deferred_native_lowering or entry.metal_status == .deferred_native_lowering) {
            deferred_paths += 1;
            try std.testing.expect(entry.deferred_to != null);
        }
    }

    for (seen) |was_seen| {
        try std.testing.expect(was_seen);
    }
    try std.testing.expect(runtime_paths >= 5);
    try std.testing.expect(capability_gated >= 4);
    try std.testing.expect(deferred_paths >= 2);
}

test "production hardening backend matrix is complete" {
    try validateProductionHardeningMatrix(production_hardening_matrix[0..]);

    var seen = [_]bool{false} ** @typeInfo(ProductionHardeningFeature).@"enum".fields.len;
    var runtime_paths: usize = 0;
    var deferred_paths: usize = 0;

    for (production_hardening_matrix) |entry| {
        seen[@intFromEnum(entry.feature)] = true;
        if (entry.vulkan_status == .portable_runtime or entry.metal_status == .portable_runtime) runtime_paths += 1;
        if (entry.vulkan_status == .deferred_native_lowering or entry.metal_status == .deferred_native_lowering) {
            deferred_paths += 1;
            try std.testing.expect(entry.deferred_to != null);
        }
    }

    for (seen) |was_seen| {
        try std.testing.expect(was_seen);
    }
    try std.testing.expect(runtime_paths >= 7);
    try std.testing.expect(deferred_paths >= 2);
}

test "advanced resource and geometry backend matrix is complete" {
    try validateAdvancedResourceGeometryMatrix(advanced_resource_geometry_matrix[0..]);

    var seen = [_]bool{false} ** @typeInfo(AdvancedResourceGeometryFeature).@"enum".fields.len;
    var runtime_paths: usize = 0;
    var capability_gated: usize = 0;
    var deferred_paths: usize = 0;

    for (advanced_resource_geometry_matrix) |entry| {
        seen[@intFromEnum(entry.feature)] = true;
        if (entry.vulkan_status == .portable_runtime or entry.metal_status == .portable_runtime) runtime_paths += 1;
        if (entry.vulkan_status == .capability_gated or entry.metal_status == .capability_gated) capability_gated += 1;
        if (entry.vulkan_status == .deferred_native_lowering or entry.metal_status == .deferred_native_lowering) {
            deferred_paths += 1;
            try std.testing.expect(entry.deferred_to != null);
        }
    }

    for (seen) |was_seen| {
        try std.testing.expect(was_seen);
    }
    try std.testing.expect(runtime_paths >= 5);
    try std.testing.expect(capability_gated >= 1);
    try std.testing.expect(deferred_paths >= 3);
}

test "ray tracing and native parity backend matrix is complete" {
    try validateRayTracingNativeParityMatrix(ray_tracing_native_parity_matrix[0..]);

    var seen = [_]bool{false} ** @typeInfo(RayTracingNativeParityFeature).@"enum".fields.len;
    var runtime_paths: usize = 0;
    var deferred_paths: usize = 0;
    var period29_targets: usize = 0;
    var period30_targets: usize = 0;
    var period31_targets: usize = 0;
    var period32_targets: usize = 0;
    var period32_plus_targets: usize = 0;
    var period44_targets: usize = 0;

    for (ray_tracing_native_parity_matrix) |entry| {
        seen[@intFromEnum(entry.feature)] = true;
        if (entry.vulkan_status == .portable_runtime or entry.metal_status == .portable_runtime) runtime_paths += 1;
        if (entry.vulkan_status == .deferred_native_lowering or entry.metal_status == .deferred_native_lowering) {
            deferred_paths += 1;
            try std.testing.expect(entry.deferred_to != null);
        }
        if (entry.deferred_to) |target| {
            if (std.mem.startsWith(u8, target, "Period 29 ")) period29_targets += 1;
            if (std.mem.startsWith(u8, target, "Period 30 ")) period30_targets += 1;
            if (std.mem.indexOf(u8, target, "Period 31") != null) period31_targets += 1;
            if (std.mem.indexOf(u8, target, "Period 32 ") != null) period32_targets += 1;
            if (std.mem.indexOf(u8, target, "Period 32+") != null) period32_plus_targets += 1;
            if (std.mem.indexOf(u8, target, "Period 44") != null) period44_targets += 1;
        }
    }

    for (seen) |was_seen| {
        try std.testing.expect(was_seen);
    }
    try std.testing.expect(runtime_paths >= 5);
    try std.testing.expectEqual(@as(usize, 0), deferred_paths);
    try std.testing.expectEqual(@as(usize, 0), period29_targets);
    try std.testing.expectEqual(@as(usize, 0), period30_targets);
    try std.testing.expect(period31_targets >= 2);
    try std.testing.expect(period32_targets >= 2);
    try std.testing.expect(period32_plus_targets >= 4);
    try std.testing.expect(period44_targets >= 1);
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
