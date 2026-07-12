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
    try probeBufferGpuAddress(&device);
    try dumpDiagnostics(device);
    dumpFormatCaps(&device, .rgba8_unorm);
    dumpFormatCaps(&device, .rgba16_float);
    dumpFormatCaps(&device, .r32_uint);
    dumpFormatCaps(&device, .bgra8_unorm);
    dumpFormatCaps(&device, .bgra8_unorm_srgb);
    dumpFormatCaps(&device, .depth32_float);
    dumpFormatCaps(&device, .depth16_unorm);
    dumpFormatCaps(&device, .stencil8);
    dumpFormatCaps(&device, .depth32_float_stencil8);
}

fn probeBufferGpuAddress(device: *vkmtl.Device) !void {
    if (!device.features().buffer_gpu_address) {
        std.debug.print("buffer GPU address probe: unsupported\n", .{});
        return;
    }
    var buffer = try device.makeBuffer(.{
        .length = 16,
        .usage = .{ .shader_device_address = true },
        .storage_mode = .private,
    });
    defer buffer.deinit();
    const address = try buffer.gpuAddress();
    std.debug.print("buffer GPU address probe: nonzero={}\n", .{address != 0});
}

fn dumpDiagnostics(device: vkmtl.Device) !void {
    const markers = vkmtl.diagnostics.debugMarkerCapabilities(device);
    const capture = vkmtl.diagnostics.captureCapabilities(device);
    const profiling = vkmtl.diagnostics.profilingCapabilities(device);
    const plan = try vkmtl.diagnostics.planProfiling(device, .{});
    const issue = try vkmtl.diagnostics.issueReport(device, .{
        .operation = "blitTexture",
        .object_kind = "texture",
        .object_label = "capability-probe",
        .failure = error.UnsupportedTextureBlit,
    });

    std.debug.print("debug markers:\n", .{});
    std.debug.print("  object labels: {s}\n", .{@tagName(markers.object_labels)});
    std.debug.print("  command-buffer groups: {s}\n", .{@tagName(markers.command_buffer_groups)});
    std.debug.print("  command-buffer signposts: {s}\n", .{@tagName(markers.command_buffer_signposts)});
    std.debug.print("  encoder groups: {s}\n", .{@tagName(markers.encoder_groups)});
    std.debug.print("  encoder signposts: {s}\n", .{@tagName(markers.encoder_signposts)});
    std.debug.print("capture:\n", .{});
    std.debug.print("  native: {}\n", .{capture.native_capture});
    std.debug.print("  scoped: {}\n", .{capture.scoped_capture});
    std.debug.print("  developer tools destination: {}\n", .{capture.developer_tools_destination});
    std.debug.print("profiling:\n", .{});
    std.debug.print("  timestamp source: {s}\n", .{@tagName(profiling.timestamp_source)});
    std.debug.print("  native GPU timestamps: {}\n", .{profiling.native_gpu_timestamps});
    std.debug.print("  selected mode: {s}\n", .{@tagName(plan.mode)});
    std.debug.print("  GPU duration available: {}\n", .{plan.gpu_duration_available});
    std.debug.print("  reason: {s}\n", .{plan.reason});
    dumpIssueReport(issue);
}

fn dumpIssueReport(report: vkmtl.diagnostics.IssueReportSnapshot) void {
    std.debug.print("issue report probe:\n", .{});
    std.debug.print("  backend: {s}\n", .{@tagName(report.backend)});
    std.debug.print("  adapter: {s}\n", .{report.adapter_name});
    std.debug.print("  capability source: {s}\n", .{@tagName(report.capability_source)});
    std.debug.print("  operation: {s}\n", .{report.operation});
    std.debug.print("  object: {s}\n", .{report.object_kind});
    if (report.object_label) |label| std.debug.print("  object label: {s}\n", .{label});
    if (report.failure_name) |failure| std.debug.print("  failure: {s}\n", .{failure});
    if (report.failure_category) |category| std.debug.print("  category: {s}\n", .{@tagName(category)});
    std.debug.print("  live resources: {}\n", .{report.runtime.live_resources});
    std.debug.print("  pending retirements: {}\n", .{report.runtime.pending_retirements});
    std.debug.print("  submitted/completed serial: {}/{}\n", .{
        report.runtime.submitted_work_serial,
        report.runtime.completed_work_serial,
    });
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
    std.debug.print("  max buffer length: {}\n", .{report.limits.max_buffer_length});
    std.debug.print("  max 2D texture dimension: {}\n", .{report.limits.max_texture_dimension_2d});
    std.debug.print("  max texture array layers: {}\n", .{report.limits.max_texture_array_layers});
    std.debug.print("  max compute threads/threadgroup: {}\n", .{report.limits.max_compute_total_threads_per_threadgroup});
    std.debug.print("  buffer/texture copy offset alignment: {}\n", .{report.limits.buffer_texture_copy_offset_alignment});
    std.debug.print("  buffer/texture copy row-pitch alignment: {}\n", .{report.limits.buffer_texture_copy_row_pitch_alignment});
    std.debug.print("  max bindless descriptors/range: {}\n", .{report.limits.max_bindless_descriptors_per_range});
    dumpRayTracingDiagnostics(report.ray_tracing);
}

fn dumpFeatureSet(features: vkmtl.diagnostics.DeviceFeatures) void {
    std.debug.print("  runtime slang: {}\n", .{features.runtime_slang});
    std.debug.print("  shader reflection: {}\n", .{features.shader_reflection});
    std.debug.print("  shader specialization: {}\n", .{features.shader_specialization});
    std.debug.print("  render pipelines: {}\n", .{features.render_pipelines});
    std.debug.print("  compute pipelines: {}\n", .{features.compute_pipelines});
    std.debug.print("  bind groups: {}\n", .{features.bind_groups});
    std.debug.print("  occlusion queries: {}\n", .{features.occlusion_queries});
    std.debug.print("  timestamp queries: {}\n", .{features.timestamp_queries});
    std.debug.print("  pipeline statistics queries: {}\n", .{features.pipeline_statistics_queries});
    std.debug.print("  native handles: {}\n", .{features.native_handles});
    std.debug.print("  buffer GPU address: {}\n", .{features.buffer_gpu_address});
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

fn dumpRayTracingDiagnostics(diagnostics: vkmtl.diagnostics.RayTracingCapabilityDiagnostics) void {
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
