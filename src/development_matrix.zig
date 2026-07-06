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

    pub fn enabled(self: FeatureGate, features: core.DeviceFeatures) bool {
        return switch (self) {
            .multi_surface => features.multi_surface,
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

test "example gallery metadata is valid" {
    try validateExamples(examples[0..]);
    try std.testing.expectEqual(@as(usize, 10), implementedExampleCount(examples[0..]));
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
