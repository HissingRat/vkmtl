const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl capability dump";

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 320,
        .height = 240,
        .title = app_name,
    });
    defer glfw.destroyWindow(window);

    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var context = try vkmtl.WindowContext.init(allocator, .{
        .app_name = app_name,
        .backend = .auto,
        .surface = common.surfaceDescriptor(window),
        .presentation = common.presentationDescriptor(window, .fifo),
    });
    defer context.deinit();

    var device = context.device();
    dumpAdapter(device.adapterInfo());
    dumpReport(device.capabilityReport());
    dumpFormatCaps(&device, .rgba8_unorm);
    dumpFormatCaps(&device, .bgra8_unorm);
    dumpFormatCaps(&device, .bgra8_unorm_srgb);
    dumpFormatCaps(&device, .depth32_float);
    dumpFormatCaps(&device, .depth32_float_stencil8);
}

fn dumpAdapter(adapter: vkmtl.AdapterInfo) void {
    std.debug.print("backend: {s}\n", .{@tagName(adapter.backend)});
    std.debug.print("adapter: {s}\n", .{adapter.name});
    if (adapter.vendor.len != 0) std.debug.print("vendor: {s}\n", .{adapter.vendor});
    std.debug.print("device type: {s}\n", .{@tagName(adapter.device_type)});
}

fn dumpReport(report: vkmtl.diagnostics.DeviceCapabilityReport) void {
    std.debug.print("capability source: {s}\n", .{@tagName(report.source)});
    std.debug.print("usable features:\n", .{});
    dumpFeatureSet(report.features);
    std.debug.print("native queried features:\n", .{});
    dumpFeatureSet(report.native_features);
    std.debug.print("limits:\n", .{});
    std.debug.print("  max vertex buffers: {}\n", .{report.limits.max_vertex_buffer_slots});
    std.debug.print("  max bind groups: {}\n", .{report.limits.max_bind_group_slots});
    std.debug.print("  max color attachments: {}\n", .{report.limits.max_color_attachments});
    std.debug.print("  max sample count: {}\n", .{report.limits.max_sample_count});
    std.debug.print("  max compute threads/threadgroup: {}\n", .{report.limits.max_compute_total_threads_per_threadgroup});
    std.debug.print("  buffer/texture copy offset alignment: {}\n", .{report.limits.buffer_texture_copy_offset_alignment});
    std.debug.print("  buffer/texture copy row-pitch alignment: {}\n", .{report.limits.buffer_texture_copy_row_pitch_alignment});
    std.debug.print("  max bindless descriptors/range: {}\n", .{report.limits.max_bindless_descriptors_per_range});
    dumpRayTracingDiagnostics(report.ray_tracing);
}

fn dumpFeatureSet(features: vkmtl.diagnostics.DeviceFeatures) void {
    std.debug.print("  runtime slang: {}\n", .{features.runtime_slang});
    std.debug.print("  shader reflection: {}\n", .{features.shader_reflection});
    std.debug.print("  render pipelines: {}\n", .{features.render_pipelines});
    std.debug.print("  compute pipelines: {}\n", .{features.compute_pipelines});
    std.debug.print("  bind groups: {}\n", .{features.bind_groups});
    std.debug.print("  native handles: {}\n", .{features.native_handles});
    std.debug.print("  descriptor indexing: {}\n", .{features.descriptor_indexing});
    std.debug.print("  argument buffers: {}\n", .{features.argument_buffers});
    std.debug.print("  sparse buffers: {}\n", .{features.sparse_buffers});
    std.debug.print("  sparse textures: {}\n", .{features.sparse_textures});
    std.debug.print("  memory budget: {}\n", .{features.memory_budget});
    std.debug.print("  memory pressure: {}\n", .{features.memory_pressure});
    std.debug.print("  external textures: {}\n", .{features.external_textures});
    std.debug.print("  tessellation: {}\n", .{features.tessellation});
    std.debug.print("  mesh shaders: {}\n", .{features.mesh_shaders});
    std.debug.print("  ray tracing: {}\n", .{features.ray_tracing});
    std.debug.print("  driver pipeline cache: {}\n", .{features.driver_pipeline_cache});
    std.debug.print("  Metal binary archive: {}\n", .{features.metal_binary_archive});
}

fn dumpRayTracingDiagnostics(diagnostics: vkmtl.RayTracingCapabilityDiagnostics) void {
    std.debug.print("ray tracing diagnostics:\n", .{});
    std.debug.print("  supported: {}\n", .{diagnostics.supported});
    std.debug.print("  blocker: {s}\n", .{@tagName(diagnostics.blocker)});
    if (diagnostics.requirement.len != 0) {
        std.debug.print("  requirement: {s}\n", .{diagnostics.requirement});
    }
    if (diagnostics.details.len != 0) {
        std.debug.print("  details: {s}\n", .{diagnostics.details});
    }
    if (diagnostics.supported) {
        std.debug.print("  max recursion depth: {}\n", .{diagnostics.max_recursion_depth});
        std.debug.print("  shader group handle size: {}\n", .{diagnostics.shader_group_handle_size});
        std.debug.print("  shader group handle alignment: {}\n", .{diagnostics.shader_group_handle_alignment});
        std.debug.print("  shader group base alignment: {}\n", .{diagnostics.shader_group_base_alignment});
        std.debug.print("  AS scratch alignment: {}\n", .{diagnostics.acceleration_structure_scratch_alignment});
    }
}

fn dumpFormatCaps(device: *vkmtl.Device, format: vkmtl.resource.TextureFormat) void {
    const caps = device.getFormatCaps(format);
    std.debug.print("format {s}: sampled={}, storage={}, color={}, depth_stencil={}, filterable={}, blendable={}, copy_src={}, copy_dst={}, blit_src={}, blit_dst={}, present={}, color_resolve={}, depth_resolve={}, stencil_resolve={}, depth_copy={}, stencil_copy={}\n", .{
        @tagName(format),
        caps.sampled,
        caps.storage,
        caps.color_attachment,
        caps.depth_stencil_attachment,
        caps.filterable,
        caps.blendable,
        caps.copy_source,
        caps.copy_destination,
        caps.blit_source,
        caps.blit_destination,
        caps.presentation,
        caps.color_resolve,
        caps.depth_resolve,
        caps.stencil_resolve,
        caps.depth_copy,
        caps.stencil_copy,
    });
}
