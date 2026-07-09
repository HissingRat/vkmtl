const std = @import("std");
const builtin = @import("builtin");

const slang_version = "2026.12.2";
const slang_tag = "v2026.12.2";
const slang_cache_namespace = "vkmtl-tools";

const SlangPackage = struct {
    id: []const u8,
    url: []const u8,
    sha256: []const u8,
    slangc_path: []const u8,
};

const VulkanRuntimeOptions = struct {
    loader_dir: ?[]const u8,
    icd: ?[]const u8,
};

const shader_source_paths = [_][]const u8{
    "examples/triangle/shaders/triangle.slang",
    "examples/uniform_buffer/shaders/uniform_buffer.slang",
    "examples/sampled_texture/shaders/sampled_texture.slang",
    "examples/depth_triangles/shaders/depth_triangles.slang",
    "examples/rainbow_cube/shaders/rainbow_cube.slang",
    "examples/msaa_triangle/shaders/msaa_triangle.slang",
    "examples/offscreen_texture/shaders/offscreen_texture.slang",
    "examples/compute_readback/shaders/compute_readback.slang",
    "examples/ray_traced_scene/shaders/ray_traced_scene_rt.slang",
};

const slang_packages = [_]SlangPackage{
    .{
        .id = "macos-aarch64",
        .url = "https://github.com/shader-slang/slang/releases/download/v2026.12.2/slang-macos-dist-aarch64.zip",
        .sha256 = "0a1dd86629f79feb339d91fe1261dd80ef71f5e71490d3460c0df00bf74976e0",
        .slangc_path = "slangc",
    },
    .{
        .id = "macos-x86_64",
        .url = "https://github.com/shader-slang/slang/releases/download/v2026.12.2/slang-macos-dist-x86_64.zip",
        .sha256 = "fd2b34b91fa9e14001d77f930e325cd65e7225250ee5e0b6e19e4205ecb829ab",
        .slangc_path = "slangc",
    },
    .{
        .id = "linux-aarch64",
        .url = "https://github.com/shader-slang/slang/releases/download/v2026.12.2/slang-2026.12.2-linux-aarch64-glibc-2.28.zip",
        .sha256 = "c8b02fd0d892005b12feb482d30775ae0a5767f5bd0e7f6f05db3d32d743ffc1",
        .slangc_path = "bin/slangc",
    },
    .{
        .id = "linux-x86_64",
        .url = "https://github.com/shader-slang/slang/releases/download/v2026.12.2/slang-2026.12.2-linux-x86_64-glibc-2.27.zip",
        .sha256 = "826e9924d6b6d28fdb37eed56cd2d1cd1d3a8f17590510953b1f360011123038",
        .slangc_path = "bin/slangc",
    },
    .{
        .id = "windows-aarch64",
        .url = "https://github.com/shader-slang/slang/releases/download/v2026.12.2/slang-2026.12.2-windows-aarch64.zip",
        .sha256 = "65bb80430181d7a78de10506cef8ea52dba757c0e7fbdaa6333b9af926f53377",
        .slangc_path = "bin/slangc.exe",
    },
    .{
        .id = "windows-x86_64",
        .url = "https://github.com/shader-slang/slang/releases/download/v2026.12.2/slang-2026.12.2-windows-x86_64.zip",
        .sha256 = "e44a29e4ba766e892db19e7f491b0c1fc21f548a0380a1b2931039569bf747e7",
        .slangc_path = "bin/slangc.exe",
    },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const shader_tools = resolveSlangTool(b, b.option([]const u8, "slangc", "Path to a build-time Slang compiler executable"), b.graph.host.result);
    const precompiled_shaders = addPrecompiledShaderModule(b, shader_tools, target, optimize);
    const force_vulkan = b.option(bool, "vulkan", "Force WindowContext to use the Vulkan backend") orelse false;
    const vulkan_runtime = VulkanRuntimeOptions{
        .loader_dir = b.option([]const u8, "vulkan-loader-dir", "Directory containing the macOS Vulkan loader dylib for forced Vulkan example runs"),
        .icd = b.option([]const u8, "vulkan-icd", "Path to the macOS MoltenVK ICD JSON for forced Vulkan example runs"),
    };
    const vkmtl_build_options = b.addOptions();
    vkmtl_build_options.addOption(bool, "force_vulkan", force_vulkan);

    const vulkan_headers = b.dependency("vulkan_headers", .{});
    const registry = vulkan_headers.path("registry/vk.xml");
    const vulkan = b.dependency("vulkan", .{
        .registry = registry,
    }).module("vulkan-zig");

    const zig_glfw_dep = b.dependency("zig_glfw", .{
        .target = target,
        .optimize = optimize,
    });
    const zig_glfw = zig_glfw_dep.module("zig_glfw");
    const glfw = zig_glfw_dep.artifact("glfw");

    const metal_bridge = b.addTranslateC(.{
        .root_source_file = b.path("src/backend/metal/bridge.h"),
        .target = target,
        .optimize = optimize,
    });

    const vkmtl = b.addModule("vkmtl", .{
        .root_source_file = b.path("src/vkmtl.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vulkan", .module = vulkan },
            .{ .name = "metal_bridge", .module = metal_bridge.createModule() },
            .{ .name = "vkmtl_build_options", .module = vkmtl_build_options.createModule() },
            .{ .name = "vkmtl_precompiled_shaders", .module = precompiled_shaders },
        },
    });
    addMetalBridge(b, vkmtl, target.result.os.tag);

    const vkmtl_examples_common = b.addModule("vkmtl_examples_common", .{
        .root_source_file = b.path("examples/common.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vkmtl", .module = vkmtl },
            .{ .name = "zig_glfw", .module = zig_glfw },
        },
    });

    const clear_screen = b.addExecutable(.{
        .name = "vkmtl-clear-screen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/clear_screen/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    clear_screen.root_module.linkLibrary(glfw);
    b.installArtifact(clear_screen);

    const clear_screen_cmd = b.addRunArtifact(clear_screen);
    clear_screen_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, clear_screen_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, clear_screen_cmd);

    const clear_screen_step = b.step("run-clear-screen", "Run the vkmtl clear-screen example");
    clear_screen_step.dependOn(&clear_screen_cmd.step);

    const triangle = b.addExecutable(.{
        .name = "vkmtl-triangle",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/triangle/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    triangle.root_module.linkLibrary(glfw);
    b.installArtifact(triangle);

    const triangle_cmd = b.addRunArtifact(triangle);
    triangle_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, triangle_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, triangle_cmd);

    const triangle_step = b.step("run-triangle", "Run the vkmtl triangle example");
    triangle_step.dependOn(&triangle_cmd.step);

    const run_step = b.step("run", "Run the vkmtl triangle example");
    run_step.dependOn(&triangle_cmd.step);

    const uniform_buffer = b.addExecutable(.{
        .name = "vkmtl-uniform-buffer",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/uniform_buffer/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    uniform_buffer.root_module.linkLibrary(glfw);
    b.installArtifact(uniform_buffer);

    const uniform_buffer_cmd = b.addRunArtifact(uniform_buffer);
    uniform_buffer_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, uniform_buffer_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, uniform_buffer_cmd);

    const uniform_buffer_step = b.step("run-uniform-buffer", "Run the vkmtl uniform-buffer example");
    uniform_buffer_step.dependOn(&uniform_buffer_cmd.step);

    const sampled_texture = b.addExecutable(.{
        .name = "vkmtl-sampled-texture",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/sampled_texture/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    sampled_texture.root_module.linkLibrary(glfw);
    b.installArtifact(sampled_texture);

    const sampled_texture_cmd = b.addRunArtifact(sampled_texture);
    sampled_texture_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, sampled_texture_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, sampled_texture_cmd);

    const sampled_texture_step = b.step("run-sampled-texture", "Run the vkmtl sampled-texture example");
    sampled_texture_step.dependOn(&sampled_texture_cmd.step);

    const depth_triangles = b.addExecutable(.{
        .name = "vkmtl-depth-triangles",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/depth_triangles/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    depth_triangles.root_module.linkLibrary(glfw);
    b.installArtifact(depth_triangles);

    const depth_triangles_cmd = b.addRunArtifact(depth_triangles);
    depth_triangles_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, depth_triangles_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, depth_triangles_cmd);

    const depth_triangles_step = b.step("run-depth-triangles", "Run the vkmtl depth-tested triangles example");
    depth_triangles_step.dependOn(&depth_triangles_cmd.step);

    const offscreen_texture = b.addExecutable(.{
        .name = "vkmtl-offscreen-texture",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/offscreen_texture/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    offscreen_texture.root_module.linkLibrary(glfw);
    b.installArtifact(offscreen_texture);

    const offscreen_texture_cmd = b.addRunArtifact(offscreen_texture);
    offscreen_texture_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, offscreen_texture_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, offscreen_texture_cmd);

    const offscreen_texture_step = b.step("run-offscreen-texture", "Run the vkmtl offscreen texture example");
    offscreen_texture_step.dependOn(&offscreen_texture_cmd.step);

    const msaa_triangle = b.addExecutable(.{
        .name = "vkmtl-msaa-triangle",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/msaa_triangle/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    msaa_triangle.root_module.linkLibrary(glfw);
    b.installArtifact(msaa_triangle);

    const msaa_triangle_cmd = b.addRunArtifact(msaa_triangle);
    msaa_triangle_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, msaa_triangle_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, msaa_triangle_cmd);

    const msaa_triangle_step = b.step("run-msaa-triangle", "Run the vkmtl MSAA triangle example");
    msaa_triangle_step.dependOn(&msaa_triangle_cmd.step);

    const rainbow_cube = b.addExecutable(.{
        .name = "vkmtl-rainbow-cube",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/rainbow_cube/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    rainbow_cube.root_module.linkLibrary(glfw);
    b.installArtifact(rainbow_cube);

    const rainbow_cube_cmd = b.addRunArtifact(rainbow_cube);
    rainbow_cube_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, rainbow_cube_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, rainbow_cube_cmd);

    const rainbow_cube_step = b.step("run-rainbow-cube", "Run the vkmtl rotating rainbow cube example");
    rainbow_cube_step.dependOn(&rainbow_cube_cmd.step);

    const transfer_readback = b.addExecutable(.{
        .name = "vkmtl-transfer-readback",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/transfer_readback/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    transfer_readback.root_module.linkLibrary(glfw);
    b.installArtifact(transfer_readback);

    const transfer_readback_cmd = b.addRunArtifact(transfer_readback);
    transfer_readback_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, transfer_readback_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, transfer_readback_cmd);

    const transfer_readback_step = b.step("run-transfer-readback", "Run the vkmtl transfer readback example");
    transfer_readback_step.dependOn(&transfer_readback_cmd.step);

    const compute_readback = b.addExecutable(.{
        .name = "vkmtl-compute-readback",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/compute_readback/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    compute_readback.root_module.linkLibrary(glfw);
    b.installArtifact(compute_readback);

    const compute_readback_cmd = b.addRunArtifact(compute_readback);
    compute_readback_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, compute_readback_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, compute_readback_cmd);

    const compute_readback_step = b.step("run-compute-readback", "Run the vkmtl compute readback example");
    compute_readback_step.dependOn(&compute_readback_cmd.step);

    const capability_dump = b.addExecutable(.{
        .name = "vkmtl-capability-dump",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/capability_dump/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    capability_dump.root_module.linkLibrary(glfw);
    b.installArtifact(capability_dump);

    const capability_dump_cmd = b.addRunArtifact(capability_dump);
    capability_dump_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, capability_dump_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, capability_dump_cmd);

    const capability_dump_step = b.step("run-capability-dump", "Run the vkmtl backend capability dump example");
    capability_dump_step.dependOn(&capability_dump_cmd.step);

    const bindless_textures = b.addExecutable(.{
        .name = "vkmtl-bindless-textures",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/bindless_textures/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    bindless_textures.root_module.linkLibrary(glfw);
    b.installArtifact(bindless_textures);

    const bindless_textures_cmd = b.addRunArtifact(bindless_textures);
    bindless_textures_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, bindless_textures_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, bindless_textures_cmd);

    const bindless_textures_step = b.step("run-bindless-textures", "Run the vkmtl bindless textures feature-gate example");
    bindless_textures_step.dependOn(&bindless_textures_cmd.step);

    const multi_window = b.addExecutable(.{
        .name = "vkmtl-multi-window",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/multi_window/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    multi_window.root_module.linkLibrary(glfw);
    b.installArtifact(multi_window);

    const multi_window_cmd = b.addRunArtifact(multi_window);
    multi_window_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, multi_window_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, multi_window_cmd);

    const multi_window_step = b.step("run-multi-window", "Run the vkmtl multi-window feature-gate example");
    multi_window_step.dependOn(&multi_window_cmd.step);

    const external_texture = b.addExecutable(.{
        .name = "vkmtl-external-texture",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/external_texture/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    external_texture.root_module.linkLibrary(glfw);
    b.installArtifact(external_texture);

    const external_texture_cmd = b.addRunArtifact(external_texture);
    external_texture_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, external_texture_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, external_texture_cmd);

    const external_texture_step = b.step("run-external-texture", "Run the vkmtl external texture feature-gate example");
    external_texture_step.dependOn(&external_texture_cmd.step);

    const streaming_texture = b.addExecutable(.{
        .name = "vkmtl-streaming-texture",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/streaming_texture/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    streaming_texture.root_module.linkLibrary(glfw);
    b.installArtifact(streaming_texture);

    const streaming_texture_cmd = b.addRunArtifact(streaming_texture);
    streaming_texture_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, streaming_texture_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, streaming_texture_cmd);

    const streaming_texture_step = b.step("run-streaming-texture", "Run the vkmtl streaming texture feature-gate example");
    streaming_texture_step.dependOn(&streaming_texture_cmd.step);

    const tessellation = b.addExecutable(.{
        .name = "vkmtl-tessellation",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/tessellation/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    tessellation.root_module.linkLibrary(glfw);
    b.installArtifact(tessellation);

    const tessellation_cmd = b.addRunArtifact(tessellation);
    tessellation_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, tessellation_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, tessellation_cmd);

    const tessellation_step = b.step("run-tessellation", "Run the vkmtl tessellation feature-gate example");
    tessellation_step.dependOn(&tessellation_cmd.step);

    const mesh_shader = b.addExecutable(.{
        .name = "vkmtl-mesh-shader",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/mesh_shader/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    mesh_shader.root_module.linkLibrary(glfw);
    b.installArtifact(mesh_shader);

    const mesh_shader_cmd = b.addRunArtifact(mesh_shader);
    mesh_shader_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, mesh_shader_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, mesh_shader_cmd);

    const mesh_shader_step = b.step("run-mesh-shader", "Run the vkmtl mesh shader feature-gate example");
    mesh_shader_step.dependOn(&mesh_shader_cmd.step);

    const ray_traced_scene = b.addExecutable(.{
        .name = "vkmtl-ray-traced-scene",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/ray_traced_scene/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
                .{ .name = "zig_glfw", .module = zig_glfw },
                .{ .name = "vkmtl_examples_common", .module = vkmtl_examples_common },
            },
        }),
    });
    ray_traced_scene.root_module.linkLibrary(glfw);
    b.installArtifact(ray_traced_scene);

    const ray_traced_scene_cmd = b.addRunArtifact(ray_traced_scene);
    ray_traced_scene_cmd.step.dependOn(b.getInstallStep());
    configureVulkanRuntimeForRun(b, ray_traced_scene_cmd, target.result.os.tag, vulkan_runtime);
    forwardRunArgs(b, ray_traced_scene_cmd);

    const ray_traced_scene_step = b.step("run-ray-traced-scene", "Run the vkmtl ray tracing feature-gate example");
    ray_traced_scene_step.dependOn(&ray_traced_scene_cmd.step);

    const stability_plan = b.addExecutable(.{
        .name = "vkmtl-stability-plan",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/stability_plan/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vkmtl", .module = vkmtl },
            },
        }),
    });
    b.installArtifact(stability_plan);

    const stability_plan_cmd = b.addRunArtifact(stability_plan);
    forwardRunArgs(b, stability_plan_cmd);

    const stability_plan_step = b.step("run-stability-plan", "Run the vkmtl opt-in stability plan diagnostic");
    stability_plan_step.dependOn(&stability_plan_cmd.step);

    const probe = b.addExecutable(.{
        .name = "vkmtl-metal-probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/probes/metal_probe.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "metal_bridge", .module = metal_bridge.createModule() },
            },
        }),
    });
    addMetalBridge(b, probe.root_module, target.result.os.tag);
    b.installArtifact(probe);

    const probe_build_step = b.step("probe-build", "Build backend binding probes");
    probe_build_step.dependOn(&probe.step);

    const probe_cmd = b.addRunArtifact(probe);

    const probe_step = b.step("probe", "Probe native backend bindings");
    probe_step.dependOn(&probe_cmd.step);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/core.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const root_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vkmtl.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vulkan", .module = vulkan },
                .{ .name = "metal_bridge", .module = metal_bridge.createModule() },
                .{ .name = "vkmtl_build_options", .module = vkmtl_build_options.createModule() },
                .{ .name = "vkmtl_precompiled_shaders", .module = precompiled_shaders },
            },
        }),
    });
    addMetalBridge(b, root_tests.root_module, target.result.os.tag);
    const run_root_tests = b.addRunArtifact(root_tests);

    const backend_pipeline_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/backend_pipeline_compile_test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "vulkan", .module = vulkan },
                .{ .name = "metal_bridge", .module = metal_bridge.createModule() },
            },
        }),
    });
    addMetalBridge(b, backend_pipeline_tests.root_module, target.result.os.tag);
    const run_backend_pipeline_tests = b.addRunArtifact(backend_pipeline_tests);

    const test_step = b.step("test", "Run vkmtl tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_root_tests.step);
    test_step.dependOn(&run_backend_pipeline_tests.step);
}

const SlangTool = struct {
    slangc: []const u8,
    setup_step: ?*std.Build.Step = null,
};

fn resolveSlangTool(b: *std.Build, explicit_slangc: ?[]const u8, target: std.Target) SlangTool {
    if (explicit_slangc) |slangc| {
        return .{ .slangc = slangc };
    }

    const package = slangPackageForTarget(target) orelse {
        std.log.err(
            "vkmtl has no pinned build-time Slang distribution for host {s}-{s}; pass -Dslangc=/path/to/slangc.",
            .{ @tagName(target.os.tag), @tagName(target.cpu.arch) },
        );
        @panic("missing build-time Slang compiler");
    };
    const cache_root = b.cache_root.path orelse ".zig-cache";
    const root = b.pathJoin(&.{ cache_root, slang_cache_namespace, "slang", slang_tag, package.id });
    const archive_dir = b.pathJoin(&.{ cache_root, slang_cache_namespace, "downloads" });
    const archive = b.pathJoin(&.{ archive_dir, b.fmt("{s}.zip", .{package.id}) });
    const stamp = b.pathJoin(&.{ root, ".complete" });
    const slangc = b.pathJoin(&.{ root, package.slangc_path });

    const setup = addSlangSetupStep(b, package, root, archive_dir, archive, stamp, slangc);
    return .{
        .slangc = slangc,
        .setup_step = &setup.step,
    };
}

fn addPrecompiledShaderModule(
    b: *std.Build,
    shader_tools: SlangTool,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const generator = b.addExecutable(.{
        .name = "vkmtl-precompile-shaders",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/precompile_shaders/main.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    const run_generator = b.addRunArtifact(generator);
    run_generator.setName("precompile vkmtl shaders");
    const generated_dir = run_generator.addOutputDirectoryArg("vkmtl-precompiled-shaders");
    run_generator.addArg(shader_tools.slangc);
    run_generator.setCwd(b.path("."));
    if (shader_tools.setup_step) |setup_step| {
        run_generator.step.dependOn(setup_step);
    }
    for (shader_source_paths) |path| {
        run_generator.addFileArg(b.path(path));
    }

    return b.createModule(.{
        .root_source_file = generated_dir.path(b, "precompiled_shaders.zig"),
        .target = target,
        .optimize = optimize,
    });
}

fn addSlangSetupStep(
    b: *std.Build,
    package: SlangPackage,
    root: []const u8,
    archive_dir: []const u8,
    archive: []const u8,
    stamp: []const u8,
    slangc: []const u8,
) *std.Build.Step.Run {
    return switch (builtin.os.tag) {
        .windows => addWindowsSlangSetupStep(b, package, root, archive_dir, archive, stamp, slangc),
        else => addPosixSlangSetupStep(b, package, root, archive_dir, archive, stamp, slangc),
    };
}

fn addPosixSlangSetupStep(
    b: *std.Build,
    package: SlangPackage,
    root: []const u8,
    archive_dir: []const u8,
    archive: []const u8,
    stamp: []const u8,
    slangc: []const u8,
) *std.Build.Step.Run {
    const setup = b.addSystemCommand(&.{"sh"});
    setup.addFileArg(b.path("scripts/setup_slang_posix.sh"));
    addSlangSetupArgs(setup, package, root, archive_dir, archive, stamp, slangc);
    return setup;
}

fn addWindowsSlangSetupStep(
    b: *std.Build,
    package: SlangPackage,
    root: []const u8,
    archive_dir: []const u8,
    archive: []const u8,
    stamp: []const u8,
    slangc: []const u8,
) *std.Build.Step.Run {
    const setup = b.addSystemCommand(&.{
        "powershell.exe",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    setup.addFileArg(b.path("scripts/setup_slang_windows.ps1"));
    addSlangSetupArgs(setup, package, root, archive_dir, archive, stamp, slangc);
    return setup;
}

fn addSlangSetupArgs(
    step: *std.Build.Step.Run,
    package: SlangPackage,
    root: []const u8,
    archive_dir: []const u8,
    archive: []const u8,
    stamp: []const u8,
    slangc: []const u8,
) void {
    step.addArgs(&.{
        root,
        archive_dir,
        archive,
        stamp,
        slangc,
        package.url,
        package.sha256,
        slang_tag,
        package.id,
    });
}

fn slangPackageForTarget(target: std.Target) ?SlangPackage {
    const os = target.os.tag;
    const arch = target.cpu.arch;

    for (slang_packages) |package| {
        if (std.mem.eql(u8, package.id, "macos-aarch64") and os == .macos and arch == .aarch64) return package;
        if (std.mem.eql(u8, package.id, "macos-x86_64") and os == .macos and arch == .x86_64) return package;
        if (std.mem.eql(u8, package.id, "linux-aarch64") and os == .linux and arch == .aarch64) return package;
        if (std.mem.eql(u8, package.id, "linux-x86_64") and os == .linux and arch == .x86_64) return package;
        if (std.mem.eql(u8, package.id, "windows-aarch64") and os == .windows and arch == .aarch64) return package;
        if (std.mem.eql(u8, package.id, "windows-x86_64") and os == .windows and arch == .x86_64) return package;
    }

    return null;
}

fn addMetalBridge(b: *std.Build, module: *std.Build.Module, os_tag: std.Target.Os.Tag) void {
    const flags = &.{
        "-std=c99",
        "-Wno-deprecated-declarations",
    };

    switch (os_tag) {
        .macos => {
            module.addCSourceFile(.{
                .file = b.path("src/backend/metal/bridge.m"),
                .flags = &.{"-Wno-deprecated-declarations"},
            });
            module.linkFramework("AppKit", .{});
            module.linkFramework("Foundation", .{});
            module.linkFramework("Metal", .{});
            module.linkFramework("QuartzCore", .{});
        },
        else => {
            module.addCSourceFile(.{
                .file = b.path("src/backend/metal/bridge_stub.c"),
                .flags = flags,
            });
        },
    }
}

fn configureVulkanRuntimeForRun(
    _: *std.Build,
    run_cmd: *std.Build.Step.Run,
    os_tag: std.Target.Os.Tag,
    options: VulkanRuntimeOptions,
) void {
    if (os_tag != .macos) return;

    if (options.loader_dir) |loader_dir| {
        run_cmd.setEnvironmentVariable("DYLD_LIBRARY_PATH", loader_dir);
    }

    if (options.icd) |icd| {
        run_cmd.setEnvironmentVariable("VK_ICD_FILENAMES", icd);
    }
}

fn forwardRunArgs(b: *std.Build, run_cmd: *std.Build.Step.Run) void {
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
