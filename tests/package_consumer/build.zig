const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vkmtl_dep = b.dependency("vkmtl", .{
        .target = target,
        .optimize = optimize,
        .shader_manifest = b.path("shaders/manifest.json"),
    });
    if (vkmtl_dep.builder.modules.count() != 1 or
        !vkmtl_dep.builder.modules.contains("vkmtl"))
    {
        @panic("vkmtl package must export exactly one module named vkmtl");
    }

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl_dep.module("vkmtl") },
            },
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run the external vkmtl package smoke test");
    test_step.dependOn(&run_tests.step);
}
