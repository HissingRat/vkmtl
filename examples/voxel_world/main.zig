const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");
const atlas_data = @import("atlas.zig");
const chunk_streamer = @import("chunk_streamer.zig");
const voxel = @import("voxel.zig");
const scene = @import("scene.zig");
const ray_tracing = @import("ray_tracing.zig");
const ptgi = @import("ptgi.zig");
const postprocess = @import("postprocess.zig");
const settings = @import("settings.zig");
const sky = @import("sky.zig");
const ui = @import("ui.zig");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl voxel world";
const shader_source = @embedFile("shaders/voxel_world.slang");
const gbuffer_shader_source = @embedFile("shaders/voxel_world_gbuffer.slang");
const ui_shader_source = @embedFile("shaders/voxel_world_ui.slang");
const terrain_seed: u32 = 0x564f_584c;
const maximum_validation_rebuilds_per_frame: usize = 2;
const maximum_interactive_rebuilds_per_frame: usize = 1;
const maximum_upload_bytes_per_frame: usize = 8 * 1024 * 1024;
const tlas_rebuild_interval_frames: usize = 4;
const maximum_ui_vertices: usize = 16 * 1024;

const Uniforms = extern struct {
    view_projection_rows: [4][4]f32,
    light_direction_and_ambient: [4]f32,
    light_color_and_strength: [4]f32,
    cycle_factors: [4]f32,
    camera_position_and_ptgi: [4]f32,
};

comptime {
    if (@sizeOf(Uniforms) != 128) @compileError("voxel uniforms must match the 128-byte shader ABI");
}

const GpuChunk = struct {
    coord: voxel.ChunkCoord,
    generation: u64 = 0,
    vertex_buffer: vkmtl.Buffer,
    index_buffer: vkmtl.Buffer,
    vertex_count: usize,
    index_count: usize,
    opaque_index_count: usize,
    water_index_count: usize,
    acceleration_structure: ?vkmtl.ray_tracing.AccelerationStructure = null,
    acceleration_structure_size: u64 = 0,

    fn init(
        device: *vkmtl.Device,
        queue: *vkmtl.Queue,
        coord: voxel.ChunkCoord,
        mesh: voxel.Mesh,
        ray_tracing_enabled: bool,
    ) !GpuChunk {
        var vertex_buffer = try device.makeBuffer(.{
            .bytes = std.mem.sliceAsBytes(mesh.vertices),
            .usage = .{
                .vertex = true,
                .acceleration_structure_build_input = ray_tracing_enabled,
            },
            .storage_mode = .shared,
        });
        errdefer vertex_buffer.deinit();

        var index_buffer = try device.makeBuffer(.{
            .bytes = std.mem.sliceAsBytes(mesh.indices),
            .usage = .{
                .index = true,
                .acceleration_structure_build_input = ray_tracing_enabled,
            },
            .storage_mode = .shared,
        });
        errdefer index_buffer.deinit();

        var acceleration_structure: ?vkmtl.ray_tracing.AccelerationStructure = null;
        var acceleration_structure_size: u64 = 0;
        if (ray_tracing_enabled and mesh.opaque_index_count != 0) {
            // Transparent water is deliberately absent from the BLAS. The
            // screen-space water pass supplies tint/Fresnel while RT shadow
            // and bounce rays continue through it to the opaque lake bed.
            const primitive_count: u32 = @intCast(mesh.opaque_index_count / 3);
            const geometry = vkmtl.ray_tracing.AccelerationStructureGeometryDescriptor{
                .kind = .triangles,
                .primitive_count = primitive_count,
                .vertex_count = @intCast(mesh.vertices.len),
                .vertex_stride = @sizeOf(voxel.Vertex),
                .index_type = .uint32,
                .index_count = @intCast(mesh.opaque_index_count),
                .is_opaque = true,
            };
            const descriptor = vkmtl.ray_tracing.AccelerationStructureDescriptor{
                .label = "voxel chunk BLAS",
                .kind = .bottom_level,
                .primitive_count = primitive_count,
            };
            const plan = try vkmtl.ray_tracing.planAccelerationStructureBuild(device.*, .{
                .acceleration_structure = descriptor,
                .geometries = &.{geometry},
            });
            var bottom_level = try device.makeAccelerationStructure(descriptor);
            errdefer bottom_level.deinit();
            var scratch = try device.makeBuffer(.{
                .label = "voxel chunk BLAS scratch",
                .length = @intCast(plan.scratch_size),
                .usage = .{ .acceleration_structure_scratch = true },
                .storage_mode = .private,
            });
            defer scratch.deinit();
            var command_buffer = try queue.makeCommandBuffer();
            try command_buffer.encodeAccelerationStructureBuild(plan, .{
                .result = &bottom_level,
                .scratch = &scratch,
                .geometries = &.{.{
                    .triangles = .{
                        .descriptor = geometry,
                        .vertex_buffer = &vertex_buffer,
                        .index_buffer = &index_buffer,
                    },
                }},
            });
            try command_buffer.commit();
            acceleration_structure = bottom_level;
            acceleration_structure_size = plan.result_size;
        }

        return .{
            .coord = coord,
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
            .vertex_count = mesh.vertices.len,
            .index_count = mesh.indices.len,
            .opaque_index_count = mesh.opaque_index_count,
            .water_index_count = mesh.water_index_count,
            .acceleration_structure = acceleration_structure,
            .acceleration_structure_size = acceleration_structure_size,
        };
    }

    fn deinit(self: *GpuChunk) void {
        if (self.acceleration_structure) |*acceleration_structure| acceleration_structure.deinit();
        self.index_buffer.deinit();
        self.vertex_buffer.deinit();
    }
};

const World = struct {
    allocator: std.mem.Allocator,
    profile: scene.WorkloadProfile,
    seed: u32,
    streamer: chunk_streamer.Streamer,
    center: ?voxel.ChunkCoord = null,
    chunks: std.ArrayList(GpuChunk) = .empty,
    pending: std.ArrayList(voxel.ChunkCoord) = .empty,
    deferred_retirements: std.ArrayList(GpuChunk) = .empty,
    ready_result: ?chunk_streamer.Result = null,
    requested_rebuild: ?voxel.ChunkCoord = null,
    immediate_tlas_rebuild_required: bool = false,
    stream_ticket: u64 = 1,
    next_chunk_generation: u64 = 1,

    fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        profile: scene.WorkloadProfile,
        seed: u32,
    ) World {
        return .{
            .allocator = allocator,
            .profile = profile,
            .seed = seed,
            .streamer = chunk_streamer.Streamer.init(allocator, io),
        };
    }

    fn startStreaming(self: *World) std.Thread.SpawnError!void {
        try self.streamer.start();
    }

    fn deinit(self: *World) void {
        self.streamer.deinit();
        if (self.ready_result) |*result| result.deinit(self.allocator);
        for (self.deferred_retirements.items) |*chunk| chunk.deinit();
        self.deferred_retirements.deinit(self.allocator);
        for (self.chunks.items) |*chunk| chunk.deinit();
        self.chunks.deinit(self.allocator);
        self.pending.deinit(self.allocator);
    }

    fn syncDesired(self: *World, center: voxel.ChunkCoord, metrics: *Metrics) !void {
        if (self.center) |current| {
            if (coordEqual(current, center)) return;
        }
        self.center = center;
        self.advanceStreamTicket();

        const radius = self.profile.radius();
        var index: usize = 0;
        while (index < self.chunks.items.len) {
            const coord = self.chunks.items[index].coord;
            if (@abs(coord.x - center.x) > radius or @abs(coord.z - center.z) > radius) {
                var removed = self.chunks.swapRemove(index);
                removed.deinit();
                metrics.retired_chunks += 1;
            } else {
                index += 1;
            }
        }

        self.pending.items.len = 0;
        var ring: i32 = 0;
        while (ring <= radius) : (ring += 1) {
            var dz: i32 = -ring;
            while (dz <= ring) : (dz += 1) {
                var dx: i32 = -ring;
                while (dx <= ring) : (dx += 1) {
                    if (@max(@abs(dx), @abs(dz)) != ring) continue;
                    const coord = voxel.ChunkCoord{ .x = center.x + dx, .z = center.z + dz };
                    if (self.findChunk(coord) != null) continue;
                    try self.pending.append(self.allocator, coord);
                }
            }
        }
        if (self.requested_rebuild) |coord| {
            if (@abs(coord.x - center.x) <= radius and @abs(coord.z - center.z) <= radius) {
                if (self.pendingIndex(coord)) |pending_index| {
                    _ = self.pending.orderedRemove(pending_index);
                }
                try self.pending.insert(self.allocator, 0, coord);
            } else {
                self.requested_rebuild = null;
            }
        }
        std.debug.assert(self.pending.items.len <= self.profile.maximumResidentChunks());
        metrics.max_pending_rebuilds = @max(metrics.max_pending_rebuilds, self.pending.items.len);
    }

    fn requestRebuild(self: *World, coord: voxel.ChunkCoord, metrics: *Metrics) !void {
        self.advanceStreamTicket();
        self.requested_rebuild = coord;
        if (self.pendingIndex(coord)) |pending_index| {
            _ = self.pending.orderedRemove(pending_index);
        }
        try self.pending.insert(self.allocator, 0, coord);
        metrics.max_pending_rebuilds = @max(metrics.max_pending_rebuilds, self.pending.items.len);
    }

    fn processPending(
        self: *World,
        device: *vkmtl.Device,
        queue: *vkmtl.Queue,
        ray_tracing_enabled: bool,
        wait_for_mesh: bool,
        metrics: *Metrics,
    ) !void {
        var rebuilt: usize = 0;
        var uploaded: usize = 0;
        const rebuild_limit = if (wait_for_mesh)
            maximum_validation_rebuilds_per_frame
        else
            maximum_interactive_rebuilds_per_frame;
        while (rebuilt < rebuild_limit) {
            var result = (try self.nextMeshResult(wait_for_mesh, metrics)) orelse break;
            const wanted = result.ticket == self.stream_ticket and
                self.pendingIndex(result.coord) != null;
            if (!wanted) {
                metrics.mesh_jobs_stale += 1;
                result.deinit(self.allocator);
                continue;
            }

            var mesh = switch (result.outcome) {
                .mesh => |mesh| mesh,
                .failure => |err| {
                    metrics.mesh_jobs_failed += 1;
                    return err;
                },
            };
            result.outcome = .{ .mesh = .{
                .vertices = &.{},
                .indices = &.{},
                .opaque_index_count = 0,
                .water_index_count = 0,
            } };
            defer mesh.deinit(self.allocator);

            const mesh_bytes = std.mem.sliceAsBytes(mesh.vertices).len + std.mem.sliceAsBytes(mesh.indices).len;
            if (rebuilt != 0 and uploaded + mesh_bytes > maximum_upload_bytes_per_frame) {
                result.outcome = .{ .mesh = mesh };
                mesh = .{
                    .vertices = &.{},
                    .indices = &.{},
                    .opaque_index_count = 0,
                    .water_index_count = 0,
                };
                self.ready_result = result;
                break;
            }

            const upload_start = glfw.timeSeconds();
            var gpu_chunk = try GpuChunk.init(
                device,
                queue,
                result.coord,
                mesh,
                ray_tracing_enabled,
            );
            metrics.stream_upload_seconds += glfw.timeSeconds() - upload_start;
            gpu_chunk.generation = self.next_chunk_generation;
            self.next_chunk_generation +%= 1;
            if (self.next_chunk_generation == 0) self.next_chunk_generation = 1;
            if (self.findChunk(result.coord)) |chunk_index| {
                const removed = self.chunks.items[chunk_index];
                if (ray_tracing_enabled and removed.acceleration_structure != null) {
                    // The currently published TLAS may still retain this BLAS.
                    // Retire it only after the replacement TLAS is published.
                    self.deferred_retirements.append(self.allocator, removed) catch |err| {
                        gpu_chunk.deinit();
                        return err;
                    };
                    self.chunks.items[chunk_index] = gpu_chunk;
                    self.immediate_tlas_rebuild_required = true;
                } else {
                    self.chunks.items[chunk_index] = gpu_chunk;
                    var retired = removed;
                    retired.deinit();
                }
                metrics.retired_chunks += 1;
            } else {
                self.chunks.append(self.allocator, gpu_chunk) catch |err| {
                    gpu_chunk.deinit();
                    return err;
                };
            }
            _ = self.pending.orderedRemove(self.pendingIndex(result.coord).?);
            if (self.requested_rebuild) |coord| {
                if (coordEqual(coord, result.coord)) self.requested_rebuild = null;
            }
            rebuilt += 1;
            uploaded += mesh_bytes;
            metrics.rebuilt_chunks += 1;
            metrics.uploaded_bytes += mesh_bytes;
            metrics.buffer_allocations += 2;
            if (gpu_chunk.acceleration_structure != null) {
                metrics.blas_builds += 1;
                metrics.blas_bytes += gpu_chunk.acceleration_structure_size;
            }
        }
        self.submitNextMesh(metrics);
        metrics.max_resident_chunks = @max(metrics.max_resident_chunks, self.chunks.items.len);
        metrics.max_pending_rebuilds = @max(metrics.max_pending_rebuilds, self.pending.items.len);
    }

    fn nextMeshResult(
        self: *World,
        wait_for_mesh: bool,
        metrics: *Metrics,
    ) !?chunk_streamer.Result {
        if (self.ready_result) |result| {
            self.ready_result = null;
            return result;
        }

        if (!self.streamer.isStarted()) {
            const coord = if (self.pending.items.len != 0) self.pending.items[0] else return null;
            const mesh_start = glfw.timeSeconds();
            const outcome: @FieldType(chunk_streamer.Result, "outcome") = if (voxel.meshTerrainChunk(
                self.allocator,
                coord,
                self.seed,
            )) |mesh|
                .{ .mesh = mesh }
            else |err|
                .{ .failure = err };
            const mesh_seconds = glfw.timeSeconds() - mesh_start;
            metrics.mesh_seconds += mesh_seconds;
            return .{
                .coord = coord,
                .ticket = self.stream_ticket,
                .mesh_nanoseconds = @intFromFloat(@max(mesh_seconds, 0) * std.time.ns_per_s),
                .outcome = outcome,
            };
        }

        self.submitNextMesh(metrics);
        const result = self.streamer.take(wait_for_mesh) orelse return null;
        metrics.mesh_jobs_completed += 1;
        metrics.mesh_seconds += @as(f64, @floatFromInt(result.mesh_nanoseconds)) /
            @as(f64, std.time.ns_per_s);
        return result;
    }

    fn submitNextMesh(self: *World, metrics: *Metrics) void {
        if (!self.streamer.isStarted() or
            self.streamer.isBusy() or
            self.ready_result != null or
            self.pending.items.len == 0)
        {
            return;
        }
        if (self.streamer.submit(.{
            .coord = self.pending.items[0],
            .ticket = self.stream_ticket,
            .seed = self.seed,
        })) {
            metrics.mesh_jobs_submitted += 1;
        }
    }

    fn pendingIndex(self: *const World, coord: voxel.ChunkCoord) ?usize {
        for (self.pending.items, 0..) |pending_coord, index| {
            if (coordEqual(pending_coord, coord)) return index;
        }
        return null;
    }

    fn pendingCount(self: *const World) usize {
        return self.pending.items.len;
    }

    fn advanceStreamTicket(self: *World) void {
        self.stream_ticket +%= 1;
        if (self.stream_ticket == 0) self.stream_ticket = 1;
    }

    fn requiresImmediateTlasRebuild(self: *const World) bool {
        return self.immediate_tlas_rebuild_required;
    }

    fn finishTlasRebuild(self: *World) void {
        for (self.deferred_retirements.items) |*chunk| chunk.deinit();
        self.deferred_retirements.items.len = 0;
        self.immediate_tlas_rebuild_required = false;
    }

    fn findChunk(self: *const World, coord: voxel.ChunkCoord) ?usize {
        for (self.chunks.items, 0..) |chunk, index| {
            if (coordEqual(chunk.coord, coord)) return index;
        }
        return null;
    }

    fn centerWillChange(self: *const World, center: voxel.ChunkCoord) bool {
        return if (self.center) |current| !coordEqual(current, center) else true;
    }

    const RayTracingSourceSet = struct {
        sources: []const *vkmtl.ray_tracing.AccelerationStructure,
        signature: u64,
        complete_square: bool,
    };

    fn collectRayTracingSources(
        self: *World,
        out_sources: *[ray_tracing.maximum_traced_chunks]*vkmtl.ray_tracing.AccelerationStructure,
    ) RayTracingSourceSet {
        const center = self.center orelse return .{
            .sources = out_sources[0..0],
            .signature = 0,
            .complete_square = false,
        };
        var count: usize = 0;
        var signature: u64 = 0x9e37_79b9_7f4a_7c15;
        for (self.chunks.items) |*chunk| {
            if (@abs(chunk.coord.x - center.x) > ray_tracing.traced_chunk_radius or
                @abs(chunk.coord.z - center.z) > ray_tracing.traced_chunk_radius)
            {
                continue;
            }
            const acceleration_structure = if (chunk.acceleration_structure) |*value| value else continue;
            std.debug.assert(count < out_sources.len);
            out_sources[count] = acceleration_structure;
            count += 1;
            signature ^= mixChunkGeneration(chunk.generation);
        }
        signature +%= @as(u64, @intCast(count)) *% 0x517c_c1b7_2722_0a95;
        const diameter: usize = @intCast(self.profile.radius() * 2 + 1);
        return .{
            .sources = out_sources[0..count],
            .signature = signature,
            .complete_square = count == diameter * diameter,
        };
    }
};

const FrameSamples = struct {
    values: [2048]f64 = [_]f64{0} ** 2048,
    len: usize = 0,
    cursor: usize = 0,

    fn record(self: *FrameSamples, seconds: f64) void {
        self.values[self.cursor] = seconds;
        self.cursor = (self.cursor + 1) % self.values.len;
        self.len = @min(self.len + 1, self.values.len);
    }

    fn summary(self: FrameSamples) FrameSummary {
        if (self.len == 0) return .{};
        var sorted: [2048]f64 = undefined;
        @memcpy(sorted[0..self.len], self.values[0..self.len]);
        std.mem.sort(f64, sorted[0..self.len], {}, std.sort.asc(f64));
        return .{
            .p50_ms = sorted[(self.len - 1) * 50 / 100] * 1000.0,
            .p95_ms = sorted[(self.len - 1) * 95 / 100] * 1000.0,
            .max_ms = sorted[self.len - 1] * 1000.0,
        };
    }
};

const FrameSummary = struct {
    p50_ms: f64 = 0,
    p95_ms: f64 = 0,
    max_ms: f64 = 0,
};

const Metrics = struct {
    frames: usize = 0,
    rebuilt_chunks: usize = 0,
    retired_chunks: usize = 0,
    uploaded_bytes: usize = 0,
    buffer_allocations: usize = 0,
    max_resident_chunks: usize = 0,
    max_pending_rebuilds: usize = 0,
    mesh_seconds: f64 = 0,
    stream_upload_seconds: f64 = 0,
    tlas_build_seconds: f64 = 0,
    mesh_jobs_submitted: usize = 0,
    mesh_jobs_completed: usize = 0,
    mesh_jobs_stale: usize = 0,
    mesh_jobs_failed: usize = 0,
    background_streaming: bool = false,
    encode_seconds: f64 = 0,
    commit_seconds: f64 = 0,
    visible_chunks: usize = 0,
    culled_chunks: usize = 0,
    draw_calls: usize = 0,
    visible_vertices: usize = 0,
    visible_indices: usize = 0,
    ray_tracing_enabled: bool = false,
    blas_builds: usize = 0,
    blas_bytes: u64 = 0,
    tlas_builds: usize = 0,
    traced_chunks: usize = 0,
    ray_dispatches: usize = 0,
    primary_rays: u64 = 0,
    ray_dispatch_seconds: f64 = 0,
    ray_driver_submitted: bool = false,
    rt_visibility_validated: bool = false,
    rt_ptgi_validated: bool = false,
    rt_reflection_validated: bool = false,
    rt_primary_hit_pixels: u64 = 0,
    rt_directionally_lit_pixels: u64 = 0,
    rt_shadowed_pixels: u64 = 0,
    rt_indirect_lit_pixels: u64 = 0,
    rt_low_indirect_pixels: u64 = 0,
    rt_reconstructed_lit_pixels: u64 = 0,
    rt_reflection_pixels: u64 = 0,
    rt_reflection_lit_pixels: u64 = 0,
    rt_penumbra_pixels: u64 = 0,
    rt_invalid_pixels: u64 = 0,
    frame_samples: FrameSamples = .{},

    fn report(
        self: Metrics,
        backend: vkmtl.Backend,
        profile: scene.WorkloadProfile,
        resident_chunks: usize,
        pending_rebuilds: usize,
    ) void {
        const frames = @max(self.frames, 1);
        const frame_summary = self.frame_samples.summary();
        std.debug.print(
            "voxel metrics: backend={s} profile={s} frames={} resident={} visible={} culled={} pending={} draws={} vertices={} indices={} rebuilt={} retired={} uploaded_bytes={} buffers={} max_resident={} max_pending={} streaming={s} mesh_jobs={}/{}/{}/{} mesh_ms={d:.3} stream_upload_ms={d:.3} tlas_build_ms={d:.3} encode_ms_per_frame={d:.3} commit_ms_per_frame={d:.3} frame_p50_ms={d:.3} frame_p95_ms={d:.3} frame_max_ms={d:.3}",
            .{
                @tagName(backend),
                @tagName(profile),
                self.frames,
                resident_chunks,
                self.visible_chunks,
                self.culled_chunks,
                pending_rebuilds,
                self.draw_calls,
                self.visible_vertices,
                self.visible_indices,
                self.rebuilt_chunks,
                self.retired_chunks,
                self.uploaded_bytes,
                self.buffer_allocations,
                self.max_resident_chunks,
                self.max_pending_rebuilds,
                if (self.background_streaming) "background" else "sync_fallback",
                self.mesh_jobs_submitted,
                self.mesh_jobs_completed,
                self.mesh_jobs_stale,
                self.mesh_jobs_failed,
                self.mesh_seconds * 1000.0,
                self.stream_upload_seconds * 1000.0,
                self.tlas_build_seconds * 1000.0,
                self.encode_seconds * 1000.0 / @as(f64, @floatFromInt(frames)),
                self.commit_seconds * 1000.0 / @as(f64, @floatFromInt(frames)),
                frame_summary.p50_ms,
                frame_summary.p95_ms,
                frame_summary.max_ms,
            },
        );
        std.debug.print(
            " renderer={s} ptgi_bounces={} blas_builds={} blas_bytes={} tlas_builds={} traced_chunks={} rt_dispatches={} primary_rays={} rt_ms_per_frame={d:.3} rt_driver_submitted={} rt_visibility_validated={} rt_ptgi_validated={} rt_reflection_validated={} rt_primary_hits={} rt_direct_lit={} rt_shadowed={} rt_indirect_lit={} rt_low_indirect={} rt_reconstructed_lit={} rt_reflection_pixels={} rt_reflection_lit={} rt_penumbra={} rt_invalid={}\n",
            .{
                if (self.ray_tracing_enabled) "hybrid_rt" else "raster",
                if (self.ray_tracing_enabled) ray_tracing.diffuse_bounce_count else 0,
                self.blas_builds,
                self.blas_bytes,
                self.tlas_builds,
                self.traced_chunks,
                self.ray_dispatches,
                self.primary_rays,
                self.ray_dispatch_seconds * 1000.0 / @as(f64, @floatFromInt(frames)),
                self.ray_driver_submitted,
                self.rt_visibility_validated,
                self.rt_ptgi_validated,
                self.rt_reflection_validated,
                self.rt_primary_hit_pixels,
                self.rt_directionally_lit_pixels,
                self.rt_shadowed_pixels,
                self.rt_indirect_lit_pixels,
                self.rt_low_indirect_pixels,
                self.rt_reconstructed_lit_pixels,
                self.rt_reflection_pixels,
                self.rt_reflection_lit_pixels,
                self.rt_penumbra_pixels,
                self.rt_invalid_pixels,
            },
        );
        std.debug.print(
            "voxel_world_pressure_test={s} backend={s} profile={s} frames={} renderer={s} ptgi_bounces={} streaming_drained={} rt_driver_submitted={} rt_visibility_validated={} rt_ptgi_validated={} rt_reflection_validated={}\n",
            .{
                if (pending_rebuilds == 0) "ok" else "incomplete",
                @tagName(backend),
                @tagName(profile),
                self.frames,
                if (self.ray_tracing_enabled) "hybrid_rt" else "raster",
                if (self.ray_tracing_enabled) ray_tracing.diffuse_bounce_count else 0,
                pending_rebuilds == 0,
                self.ray_driver_submitted,
                self.rt_visibility_validated,
                self.rt_ptgi_validated,
                self.rt_reflection_validated,
            },
        );
    }
};

const InputState = struct {
    mouse_initialized: bool = false,
    last_mouse_x: f64 = 0,
    last_mouse_y: f64 = 0,
    rebuild_down: bool = false,
    escape_down: bool = false,
    title_open: bool = false,
};

pub fn main(init: std.process.Init) !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 1280,
        .height = 720,
        .title = app_name,
    });
    defer glfw.destroyWindow(window);

    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var context = try vkmtl.WindowContext.init(allocator, .{
        .app_name = app_name,
        .backend = .auto,
        .debug_backend_override = backendOverrideFromEnv(),
        .surface = common.surfaceDescriptor(window),
        .presentation = common.presentationDescriptor(window, .fifo),
    });
    defer context.deinit();

    const profile = profileFromEnv();
    const frame_limit = frameLimitFromEnv();
    const autopilot = boolFromEnv("VKMTL_VOXEL_AUTOPILOT");
    const fixed_cycle_time = cycleTimeFromEnv();
    const ray_tracing_mode = rayTracingModeFromEnv() catch |err| {
        std.debug.print("Invalid VKMTL_VOXEL_RT value; use auto, off, or required\n", .{});
        return err;
    };
    std.debug.print("Using backend: {}\n", .{context.selectedBackend()});
    std.debug.print(
        "voxel workload contract: profile={s} chunk={}x{}x{} radius={} max_resident={} interactive_rebuilds_per_frame={} validation_rebuilds_per_frame={} upload_budget={} tlas_rebuild_interval_frames={}\n",
        .{
            @tagName(profile),
            voxel.chunk_width,
            voxel.chunk_height,
            voxel.chunk_depth,
            profile.radius(),
            profile.maximumResidentChunks(),
            maximum_interactive_rebuilds_per_frame,
            maximum_validation_rebuilds_per_frame,
            maximum_upload_bytes_per_frame,
            tlas_rebuild_interval_frames,
        },
    );

    var device = context.device();
    var queue = context.queue();
    var swapchain = context.swapchain();
    if (!postprocess.Renderer.isUsable(&device)) {
        std.debug.print("voxel HDR composition unavailable: three independent color attachments, linearly filterable rgba16_float, blend state, or depth32_float attachment support is missing\n", .{});
        return error.VoxelHdrCompositionUnavailable;
    }
    const ray_tracing_usable = ray_tracing.Lighting.isUsable(&device);
    if (ray_tracing_mode == .required and !ray_tracing_usable) {
        std.debug.print("voxel ray tracing required but the selected device or rgba16_float PTGI path is unavailable\n", .{});
        return error.VoxelRayTracingRequiredUnavailable;
    }
    const ray_tracing_enabled = ray_tracing_mode != .disabled and ray_tracing_usable;
    std.debug.print(
        "voxel renderer: mode={s} selected={s} ptgi_bounces={} traced_radius={} traced_chunks_max={}\n",
        .{
            @tagName(ray_tracing_mode),
            if (ray_tracing_enabled) "hybrid_rt" else "raster",
            if (ray_tracing_enabled) ray_tracing.diffuse_bounce_count else 0,
            ray_tracing.traced_chunk_radius,
            ray_tracing.maximum_traced_chunks,
        },
    );

    var metrics = Metrics{ .ray_tracing_enabled = ray_tracing_enabled };
    var world = World.init(allocator, init.io, profile, terrain_seed);
    defer world.deinit();
    world.startStreaming() catch |err| {
        std.debug.print("voxel chunk streaming fell back to synchronous meshing: {}\n", .{err});
    };
    metrics.background_streaming = world.streamer.isStarted();
    var traced_lighting: ?ray_tracing.Lighting = if (ray_tracing_enabled)
        try ray_tracing.Lighting.init(allocator, &device)
    else
        null;
    defer if (traced_lighting) |*lighting| lighting.deinit();

    const color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
        .{ .format = .rgba16_float },
    };

    var camera = scene.Camera{};
    var celestial = scene.celestialState(0);
    var uniforms = makeUniforms(camera, 1280, 720, celestial, false, 0.0);
    var uniform_buffer = try device.makeBuffer(.{
        .bytes = std.mem.asBytes(&uniforms),
        .usage = .{ .uniform = true },
        .storage_mode = .shared,
    });
    defer uniform_buffer.deinit();

    var atlas_pixels: [atlas_data.byte_len]u8 = undefined;
    try atlas_data.fill(atlas_pixels[0..]);
    var atlas = try device.makeTexture(.{
        .format = .rgba8_unorm_srgb,
        .width = atlas_data.width,
        .height = atlas_data.height,
        .usage = .{ .shader_read = true },
        .storage_mode = .shared,
    });
    defer atlas.deinit();
    try atlas.replaceAll2D(.{ .bytes = atlas_pixels[0..] });

    var atlas_view = try atlas.makeTextureView(.{});
    defer atlas_view.deinit();
    const maximum_anisotropy = if (device.features().sampler_anisotropy)
        @min(@as(f32, 8), device.limits().max_sampler_anisotropy)
    else
        1;
    var sampler = try device.makeSamplerState(.{
        .min_filter = .linear,
        .mag_filter = .linear,
        .max_anisotropy = maximum_anisotropy,
    });
    defer sampler.deinit();

    const fallback_lighting_pixel = [_]u8{ 0, 0, 0, 255 };
    var fallback_lighting_texture = try device.makeTexture(.{
        .label = "voxel raster lighting fallback",
        .format = .rgba8_unorm,
        .width = 1,
        .height = 1,
        .usage = .{ .shader_read = true },
        .storage_mode = .shared,
    });
    defer fallback_lighting_texture.deinit();
    try fallback_lighting_texture.replaceAll2D(.{ .bytes = fallback_lighting_pixel[0..] });
    var fallback_lighting_view = try fallback_lighting_texture.makeTextureView(.{});
    defer fallback_lighting_view.deinit();

    var compiled_shader = try device.compileRenderShader("voxel_world", shader_source, .{
        .vertex_entry = "vs_main",
        .fragment_entry = "fs_main",
    });
    defer compiled_shader.deinit();
    const stages = compiled_shader.stageDescriptors(context.selectedBackend());

    var derived_vertex_descriptor = try vkmtl.shader.Reflection.deriveSingleBufferVertexDescriptor(
        allocator,
        stages.vertex,
        .{ .stride = @sizeOf(voxel.Vertex) },
    );
    defer derived_vertex_descriptor.deinit();

    var derived_bind_group_layouts = try vkmtl.shader.Reflection.deriveRenderPipelineBindGroupLayouts(
        allocator,
        stages.vertex,
        stages.fragment,
    );
    defer derived_bind_group_layouts.deinit();
    if (derived_bind_group_layouts.descriptors().len != 1) return error.UnexpectedVoxelBindGroupLayout;

    var bind_group_layout = try device.makeBindGroupLayout(derived_bind_group_layouts.descriptors()[0]);
    defer bind_group_layout.deinit();
    var frame_resources: ?ptgi.FrameResources = null;
    var frame_resource_extent = vkmtl.Extent2D{ .width = 0, .height = 0 };
    var presentation: ?postprocess.Renderer = null;
    var bind_group: ?vkmtl.binding.BindGroup = try makeVoxelBindGroup(
        &device,
        &bind_group_layout,
        &uniform_buffer,
        &atlas_view,
        &sampler,
        &fallback_lighting_view,
        &fallback_lighting_view,
    );
    defer {
        if (bind_group) |*value| value.deinit();
        if (presentation) |*renderer| renderer.deinit();
        if (frame_resources) |*resources| resources.deinit();
    }

    const pipeline_bind_group_layouts = [_]vkmtl.BindGroupLayoutDescriptor{
        bind_group_layout.descriptor(),
    };
    var pipeline = try device.makeRenderPipelineState(.{
        .vertex = stages.vertex,
        .fragment = stages.fragment,
        .vertex_descriptor = derived_vertex_descriptor.descriptor,
        .bind_group_layouts = pipeline_bind_group_layouts[0..],
        .primitive_topology = .triangle,
        .cull_mode = .back,
        .color_attachments = color_attachments[0..],
        .depth_stencil = .{
            .format = .depth32_float,
            .depth_compare_function = .less_equal,
            .depth_write_enabled = true,
        },
    });
    defer pipeline.deinit();

    var compiled_water_shader = try device.compileRenderShader("voxel_world_water", shader_source, .{
        .vertex_entry = "vs_main",
        .fragment_entry = "water_fs",
    });
    defer compiled_water_shader.deinit();
    const water_stages = compiled_water_shader.stageDescriptors(context.selectedBackend());
    var derived_water_bind_group_layouts = try vkmtl.shader.Reflection.deriveRenderPipelineBindGroupLayouts(
        allocator,
        water_stages.vertex,
        water_stages.fragment,
    );
    defer derived_water_bind_group_layouts.deinit();
    if (derived_water_bind_group_layouts.descriptors().len != 1) {
        return error.UnexpectedVoxelWaterBindGroupLayout;
    }
    var water_bind_group_layout = try device.makeBindGroupLayout(
        derived_water_bind_group_layouts.descriptors()[0],
    );
    defer water_bind_group_layout.deinit();
    var water_bind_group: ?vkmtl.binding.BindGroup = null;
    defer if (water_bind_group) |*value| value.deinit();
    const water_pipeline_bind_group_layouts = [_]vkmtl.BindGroupLayoutDescriptor{
        water_bind_group_layout.descriptor(),
    };
    const water_color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
        .{ .format = .rgba16_float },
    };
    var water_pipeline = try device.makeRenderPipelineState(.{
        .label = "voxel refractive animated water overlay",
        .vertex = water_stages.vertex,
        .fragment = water_stages.fragment,
        .vertex_descriptor = derived_vertex_descriptor.descriptor,
        .bind_group_layouts = water_pipeline_bind_group_layouts[0..],
        .primitive_topology = .triangle,
        .cull_mode = .none,
        .color_attachments = water_color_attachments[0..],
        .depth_stencil = .{
            .format = .depth32_float,
            .depth_compare_function = .less_equal,
            .depth_write_enabled = true,
        },
    });
    defer water_pipeline.deinit();

    var compiled_gbuffer_shader = try device.compileRenderShader("voxel_world_gbuffer", gbuffer_shader_source, .{
        .vertex_entry = "gbuffer_vs",
        .fragment_entry = "gbuffer_fs",
    });
    defer compiled_gbuffer_shader.deinit();
    const gbuffer_stages = compiled_gbuffer_shader.stageDescriptors(context.selectedBackend());
    var compiled_water_gbuffer_shader = try device.compileRenderShader(
        "voxel_world_water_gbuffer",
        gbuffer_shader_source,
        .{
            .vertex_entry = "gbuffer_vs",
            .fragment_entry = "water_gbuffer_fs",
        },
    );
    defer compiled_water_gbuffer_shader.deinit();
    const water_gbuffer_stages = compiled_water_gbuffer_shader.stageDescriptors(
        context.selectedBackend(),
    );
    const gbuffer_layout_descriptor = vkmtl.BindGroupLayoutDescriptor{ .entries = &.{
        .{
            .binding = 0,
            .resource = .uniform_buffer,
            .visibility = .{ .vertex = true, .fragment = true },
        },
        .{
            .binding = 1,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
        },
        .{
            .binding = 2,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
        },
    } };
    var gbuffer_layout = try device.makeBindGroupLayout(gbuffer_layout_descriptor);
    defer gbuffer_layout.deinit();
    var gbuffer_bind_group = try makeGBufferBindGroup(
        &device,
        &gbuffer_layout,
        &uniform_buffer,
        &atlas_view,
        &sampler,
    );
    defer gbuffer_bind_group.deinit();
    const no_color_writes = vkmtl.render.ColorWriteMask{
        .red = false,
        .green = false,
        .blue = false,
        .alpha = false,
    };
    const gbuffer_color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
        .{ .format = .rgba16_float },
        .{ .format = .rgba16_float, .write_mask = no_color_writes },
        .{ .format = .rgba16_float, .write_mask = no_color_writes },
    };
    var gbuffer_pipeline = try device.makeRenderPipelineState(.{
        .label = "voxel PTGI surface gbuffer",
        .vertex = gbuffer_stages.vertex,
        .fragment = gbuffer_stages.fragment,
        .vertex_descriptor = derived_vertex_descriptor.descriptor,
        .bind_group_layouts = &.{gbuffer_layout.descriptor()},
        .primitive_topology = .triangle,
        .cull_mode = .back,
        .color_attachments = gbuffer_color_attachments[0..],
        .depth_stencil = .{
            .format = .depth32_float,
            .depth_compare_function = .less_equal,
            .depth_write_enabled = true,
        },
    });
    defer gbuffer_pipeline.deinit();

    const water_gbuffer_color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
        .{ .format = .rgba16_float, .write_mask = no_color_writes },
        .{ .format = .rgba16_float },
        .{ .format = .rgba16_float, .write_mask = no_color_writes },
    };
    var water_gbuffer_pipeline = try device.makeRenderPipelineState(.{
        .label = "voxel animated water surface gbuffer",
        .vertex = water_gbuffer_stages.vertex,
        .fragment = water_gbuffer_stages.fragment,
        .vertex_descriptor = derived_vertex_descriptor.descriptor,
        .bind_group_layouts = &.{gbuffer_layout.descriptor()},
        .primitive_topology = .triangle,
        .cull_mode = .none,
        .color_attachments = water_gbuffer_color_attachments[0..],
        .depth_stencil = .{
            .format = .depth32_float,
            .depth_compare_function = .less_equal,
            .depth_write_enabled = true,
        },
    });
    defer water_gbuffer_pipeline.deinit();

    var sky_uniforms = sky.makeUniforms(camera, 0, 0);
    var sky_uniform_buffer = try device.makeBuffer(.{
        .label = "voxel day-night sky uniforms",
        .bytes = std.mem.asBytes(&sky_uniforms),
        .usage = .{ .uniform = true },
        .storage_mode = .shared,
    });
    defer sky_uniform_buffer.deinit();

    var compiled_sky_shader = try device.compileRenderShader(
        sky.shader_name,
        sky.shader_source,
        .{
            .vertex_entry = sky.vertex_entry,
            .fragment_entry = sky.fragment_entry,
        },
    );
    defer compiled_sky_shader.deinit();
    const sky_stages = compiled_sky_shader.stageDescriptors(context.selectedBackend());
    var sky_bind_group_layouts = try vkmtl.shader.Reflection.deriveRenderPipelineBindGroupLayouts(
        allocator,
        sky_stages.vertex,
        sky_stages.fragment,
    );
    defer sky_bind_group_layouts.deinit();
    if (sky_bind_group_layouts.descriptors().len != 1) return error.UnexpectedVoxelSkyBindGroupLayout;

    var sky_bind_group_layout = try device.makeBindGroupLayout(sky_bind_group_layouts.descriptors()[0]);
    defer sky_bind_group_layout.deinit();
    var sky_bind_group = try makeSkyBindGroup(
        &device,
        &sky_bind_group_layout,
        &sky_uniform_buffer,
    );
    defer sky_bind_group.deinit();
    const sky_pipeline_bind_group_layouts = [_]vkmtl.BindGroupLayoutDescriptor{
        sky_bind_group_layout.descriptor(),
    };
    var sky_pipeline = try device.makeRenderPipelineState(.{
        .label = "voxel day-night sky",
        .vertex = sky_stages.vertex,
        .fragment = sky_stages.fragment,
        .bind_group_layouts = sky_pipeline_bind_group_layouts[0..],
        .primitive_topology = .triangle,
        .color_attachments = color_attachments[0..],
        .depth_stencil = .{
            .format = .depth32_float,
            .depth_compare_function = .always,
            .depth_write_enabled = false,
        },
    });
    defer sky_pipeline.deinit();

    var compiled_ui_shader = try device.compileRenderShader("voxel_world_ui", ui_shader_source, .{
        .vertex_entry = "vs_main",
        .fragment_entry = "fs_main",
    });
    defer compiled_ui_shader.deinit();
    const ui_stages = compiled_ui_shader.stageDescriptors(context.selectedBackend());
    var ui_vertex_descriptor = try vkmtl.shader.Reflection.deriveSingleBufferVertexDescriptor(
        allocator,
        ui_stages.vertex,
        .{ .stride = @sizeOf(ui.Vertex) },
    );
    defer ui_vertex_descriptor.deinit();
    const ui_color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{.{
        .format = swapchain.selectedFormat(),
        .blend = .{
            .source_rgb_blend_factor = .source_alpha,
            .destination_rgb_blend_factor = .one_minus_source_alpha,
            .source_alpha_blend_factor = .one,
            .destination_alpha_blend_factor = .one_minus_source_alpha,
        },
    }};
    var ui_pipeline = try device.makeRenderPipelineState(.{
        .label = "voxel text and title overlay",
        .vertex = ui_stages.vertex,
        .fragment = ui_stages.fragment,
        .vertex_descriptor = ui_vertex_descriptor.descriptor,
        .primitive_topology = .triangle,
        .color_attachments = ui_color_attachments[0..],
    });
    defer ui_pipeline.deinit();

    var ui_vertex_storage: [maximum_ui_vertices]ui.Vertex = undefined;
    var ui_batch = ui.Batch.init(ui_vertex_storage[0..]);
    var ui_vertex_buffer = try device.makeBuffer(.{
        .label = "voxel dynamic UI vertices",
        .length = maximum_ui_vertices * @sizeOf(ui.Vertex),
        .usage = .{ .vertex = true },
        .storage_mode = .shared,
    });
    defer ui_vertex_buffer.deinit();
    var fps_counter = ui.FpsCounter{};

    try world.syncDesired(camera.chunkCoord(), &metrics);

    var input = InputState{};
    if (!autopilot and frame_limit == null) captureMouse(window);
    const cycle_start_seconds = glfw.timeSeconds();
    var previous_seconds = cycle_start_seconds;
    var last_periodic_report = previous_seconds;
    var traced_source_signature: ?u64 = null;

    while (!glfw.windowShouldClose(window)) {
        const frame_start = glfw.timeSeconds();
        const cycle_seconds_f64: f64 = scene.day_cycle_seconds;
        const cycle_elapsed_seconds = @max(frame_start - cycle_start_seconds, 0.0);
        const wrapped_cycle_seconds = cycle_elapsed_seconds -
            @floor(cycle_elapsed_seconds / cycle_seconds_f64) * cycle_seconds_f64;
        const cycle_time_seconds: f32 = fixed_cycle_time orelse @floatCast(wrapped_cycle_seconds);
        const cloud_time_seconds: f32 = @floatCast(cycle_elapsed_seconds);
        const water_phase = scene.waterPhase(cycle_elapsed_seconds);
        celestial = scene.celestialState(cycle_time_seconds);
        const raw_delta_seconds = @max(frame_start - previous_seconds, 0);
        const delta_seconds = @as(f32, @floatCast(@min(raw_delta_seconds, 0.1)));
        previous_seconds = frame_start;
        fps_counter.recordFrame(raw_delta_seconds);
        var reset_ptgi_history = false;

        var rebuild_requested = false;
        if (autopilot) {
            camera.position[0] += 0.75;
            camera.yaw = @as(f32, @floatFromInt(metrics.frames)) * 0.012;
            rebuild_requested = metrics.frames != 0 and metrics.frames % 16 == 0;
        } else if (frame_limit == null) {
            updateTitleToggle(window, &input);
            if (!input.title_open) {
                rebuild_requested = updateCameraFromInput(window, &camera, delta_seconds, &input);
            }
        }

        const desired_center = camera.chunkCoord();
        if (traced_lighting) |*lighting| {
            if (world.centerWillChange(desired_center) or rebuild_requested) {
                lighting.invalidateScene();
                traced_source_signature = null;
                reset_ptgi_history = true;
            }
        }
        try world.syncDesired(desired_center, &metrics);
        if (rebuild_requested) try world.requestRebuild(desired_center, &metrics);
        try world.processPending(
            &device,
            &queue,
            ray_tracing_enabled,
            frame_limit != null,
            &metrics,
        );

        if (traced_lighting) |*lighting| {
            var source_storage: [ray_tracing.maximum_traced_chunks]*vkmtl.ray_tracing.AccelerationStructure = undefined;
            const source_set = world.collectRayTracingSources(&source_storage);
            const source_changed = traced_source_signature == null or
                traced_source_signature.? != source_set.signature;
            const immediate_tlas_rebuild = world.requiresImmediateTlasRebuild();
            const tlas_rebuild_due = traced_source_signature == null or
                (lighting.instance_count == 0 and source_set.sources.len != 0) or
                immediate_tlas_rebuild or
                world.pendingCount() == 0 or
                metrics.frames % tlas_rebuild_interval_frames == 0;
            if ((source_changed or immediate_tlas_rebuild) and tlas_rebuild_due) {
                const tlas_start = glfw.timeSeconds();
                if (try lighting.rebuild(
                    &device,
                    &queue,
                    source_set.sources,
                    desired_center,
                    profile.radius(),
                    source_set.complete_square,
                )) |info| {
                    metrics.tlas_builds += 1;
                    metrics.traced_chunks = info.instance_count;
                } else {
                    metrics.traced_chunks = 0;
                }
                metrics.tlas_build_seconds += glfw.timeSeconds() - tlas_start;
                traced_source_signature = source_set.signature;
                world.finishTlasRebuild();
                reset_ptgi_history = true;
            }
        }

        const extent = common.framebufferExtent(window);
        if (extent.isZero()) {
            glfw.pollEvents();
            continue;
        }
        try swapchain.resize(extent);
        const drawable_extent = swapchain.extent();

        if (presentation == null or
            frame_resource_extent.width != drawable_extent.width or
            frame_resource_extent.height != drawable_extent.height)
        {
            if (bind_group) |*value| value.deinit();
            bind_group = null;
            if (water_bind_group) |*value| value.deinit();
            water_bind_group = null;
            if (presentation) |*renderer| renderer.deinit();
            presentation = null;
            if (traced_lighting) |*lighting| lighting.clearResources();
            if (frame_resources) |*resources| resources.deinit();
            frame_resources = null;
            presentation = try postprocess.Renderer.init(
                allocator,
                &device,
                drawable_extent,
                swapchain.selectedFormat(),
                ray_tracing_enabled,
            );
            try presentation.?.prepare(&device);
            if (ray_tracing_enabled) {
                frame_resources = try ptgi.FrameResources.init(allocator, &device, drawable_extent);
                try frame_resources.?.prepare(&device);
                if (traced_lighting) |*lighting| {
                    try lighting.setResources(
                        &device,
                        &frame_resources.?.surface.view,
                        presentation.?.waterSurfaceView(),
                        presentation.?.waterReflectionView(),
                        &atlas_view,
                        &sampler,
                        desired_center,
                        world.seed,
                    );
                }
                bind_group = try makeVoxelBindGroup(
                    &device,
                    &bind_group_layout,
                    &uniform_buffer,
                    &atlas_view,
                    &sampler,
                    frame_resources.?.filteredVisibilityView(),
                    frame_resources.?.filteredView(),
                );
            } else {
                bind_group = try makeVoxelBindGroup(
                    &device,
                    &bind_group_layout,
                    &uniform_buffer,
                    &atlas_view,
                    &sampler,
                    &fallback_lighting_view,
                    &fallback_lighting_view,
                );
            }
            const opaque_surface_view = if (frame_resources) |*resources|
                &resources.surface.view
            else
                presentation.?.opaqueSurfaceView();
            const water_visibility_view = if (frame_resources) |*resources|
                resources.filteredVisibilityView()
            else
                &fallback_lighting_view;
            const water_indirect_view = if (frame_resources) |*resources|
                resources.filteredView()
            else
                &fallback_lighting_view;
            water_bind_group = try makeWaterBindGroup(
                &device,
                &water_bind_group_layout,
                &uniform_buffer,
                &sampler,
                water_visibility_view,
                water_indirect_view,
                presentation.?.hdrView(),
                opaque_surface_view,
                presentation.?.waterReflectionView(),
            );
            frame_resource_extent = drawable_extent;
            reset_ptgi_history = true;
        }

        if (traced_lighting) |*lighting| {
            try lighting.updateMaterialVolume(&device, desired_center, world.seed);
        }

        const ptgi_ready = if (traced_lighting) |*lighting|
            frame_resources != null and lighting.instance_count != 0
        else
            false;
        uniforms = makeUniforms(
            camera,
            drawable_extent.width,
            drawable_extent.height,
            celestial,
            ptgi_ready,
            water_phase,
        );
        try uniform_buffer.replaceBytes(0, std.mem.asBytes(&uniforms));

        const aspect = @as(f32, @floatFromInt(drawable_extent.width)) / @as(f32, @floatFromInt(drawable_extent.height));
        sky_uniforms = sky.makeUniformsForAspect(
            camera,
            cycle_time_seconds,
            cloud_time_seconds,
            aspect,
        );
        try sky_uniform_buffer.replaceBytes(0, std.mem.asBytes(&sky_uniforms));

        const opaque_surface_view = if (frame_resources) |*resources|
            &resources.surface.view
        else
            presentation.?.opaqueSurfaceView();
        const opaque_surface_depth_view = if (frame_resources) |*resources|
            &resources.surface.depth_view
        else
            presentation.?.opaqueSurfaceDepthView();
        var gbuffer_commands = try queue.makeCommandBuffer();
        var gbuffer_encoder = try gbuffer_commands.makeRenderCommandEncoder(.{
            .color_attachments = &.{
                .{
                    .target = .{ .texture_view = opaque_surface_view },
                    .clear_color = .{ .alpha = 0.0 },
                },
                .{
                    .target = .{ .texture_view = presentation.?.waterSurfaceView() },
                    .clear_color = .{ .alpha = 0.0 },
                },
                .{
                    // The RT dispatch overwrites covered water pixels. The
                    // clear keeps raster fallback and empty TLAS frames exact.
                    .target = .{ .texture_view = presentation.?.waterReflectionView() },
                    .clear_color = .{ .alpha = 0.0 },
                },
            },
            .depth_attachment = .{
                .target = .{ .texture_view = opaque_surface_depth_view },
                .clear_depth = 1.0,
            },
        });
        try gbuffer_encoder.setRenderPipelineState(&gbuffer_pipeline);
        try gbuffer_encoder.setBindGroup(&gbuffer_bind_group, .{ .index = 0 });
        for (world.chunks.items) |*chunk| {
            if (!camera.chunkVisible(aspect, chunk.coord)) continue;
            if (chunk.opaque_index_count == 0) continue;
            try gbuffer_encoder.setVertexBuffer(&chunk.vertex_buffer, .{ .index = 0 });
            try gbuffer_encoder.setIndexBuffer(&chunk.index_buffer);
            try gbuffer_encoder.drawIndexedPrimitives(.{
                .primitive_type = .triangle,
                .index_type = .uint32,
                .index_count = @intCast(chunk.opaque_index_count),
            });
        }
        try gbuffer_encoder.setRenderPipelineState(&water_gbuffer_pipeline);
        for (world.chunks.items) |*chunk| {
            if (!camera.chunkVisible(aspect, chunk.coord)) continue;
            if (chunk.water_index_count == 0) continue;
            try gbuffer_encoder.setVertexBuffer(&chunk.vertex_buffer, .{ .index = 0 });
            try gbuffer_encoder.setIndexBuffer(&chunk.index_buffer);
            try gbuffer_encoder.drawIndexedPrimitives(.{
                .primitive_type = .triangle,
                .index_type = .uint32,
                .index_count = @intCast(chunk.water_index_count),
                .index_buffer_offset = @intCast(chunk.opaque_index_count * @sizeOf(u32)),
            });
        }
        try gbuffer_encoder.endEncoding();
        try gbuffer_commands.commit();

        if (traced_lighting) |*lighting| {
            if (frame_resources) |*resources| {
                if (lighting.instance_count != 0) {
                    const ray_start = glfw.timeSeconds();
                    const dispatch_plan = try lighting.dispatch(
                        &queue,
                        &resources.raw,
                        camera,
                        drawable_extent,
                        celestial.light_direction,
                        celestial.sun_direction,
                        celestial.light_angular_radius,
                        celestial.light_color,
                        celestial.strength,
                        celestial.daylight,
                        celestial.night,
                        cloud_time_seconds,
                        metrics.frames,
                    );
                    try resources.dispatch(&queue, camera, celestial, reset_ptgi_history);
                    metrics.ray_dispatch_seconds += glfw.timeSeconds() - ray_start;
                    metrics.ray_dispatches += 1;
                    metrics.primary_rays += dispatch_plan.total_rays;
                    metrics.ray_driver_submitted = lighting.lastDispatchSubmittedToDriver();
                    const final_visibility_check = if (frame_limit) |limit|
                        metrics.frames + 1 == limit
                    else
                        false;
                    if (frame_limit != null and
                        world.pendingCount() == 0 and
                        (!metrics.rt_visibility_validated or final_visibility_check))
                    {
                        const lighting_stats = try ray_tracing.readLightingStats(
                            allocator,
                            &device,
                            &queue,
                            &resources.raw,
                            drawable_extent,
                        );
                        const reconstruction = try ray_tracing.readRadianceStats(
                            allocator,
                            &device,
                            &queue,
                            resources.filteredTexture(),
                            drawable_extent,
                        );
                        const visibility = try ray_tracing.readVisibilityStats(
                            allocator,
                            &device,
                            &queue,
                            resources.filteredVisibilityTexture(),
                            drawable_extent,
                        );
                        const reflection = try ray_tracing.readReflectionStats(
                            allocator,
                            &device,
                            &queue,
                            presentation.?.waterReflectionTexture(),
                            drawable_extent,
                        );
                        const invalid_pixels = lighting_stats.non_finite_pixels +
                            lighting_stats.negative_radiance_pixels +
                            reconstruction.non_finite_pixels +
                            reconstruction.negative_pixels +
                            visibility.invalid_pixels +
                            reflection.invalid_pixels;
                        if (invalid_pixels != 0) {
                            return error.VoxelPtgiNonFiniteOrNegativeRadiance;
                        }
                        if (!lighting_stats.hasNativeOcclusion(celestial.strength > 0.001) or
                            !lighting_stats.hasIndirectRadiance() or
                            !reconstruction.isValid() or
                            !visibility.isValid())
                        {
                            return error.VoxelPtgiLightingRegression;
                        }
                        // A fixed-camera finite run is the deterministic water
                        // feature lane. Autopilot may legitimately turn away
                        // from every lake while it stresses streaming.
                        if (!autopilot and !reflection.isValid()) {
                            return error.VoxelWaterReflectionRegression;
                        }
                        metrics.rt_visibility_validated = true;
                        metrics.rt_ptgi_validated = true;
                        metrics.rt_reflection_validated =
                            metrics.rt_reflection_validated or reflection.isValid();
                        metrics.rt_primary_hit_pixels = lighting_stats.primary_hit_pixels;
                        metrics.rt_directionally_lit_pixels = lighting_stats.directionally_lit_pixels;
                        metrics.rt_shadowed_pixels = lighting_stats.shadowed_pixels;
                        metrics.rt_indirect_lit_pixels = lighting_stats.indirect_lit_pixels;
                        metrics.rt_low_indirect_pixels = lighting_stats.low_indirect_pixels;
                        metrics.rt_reconstructed_lit_pixels = reconstruction.lit_pixels;
                        metrics.rt_reflection_lit_pixels = @max(
                            metrics.rt_reflection_lit_pixels,
                            reflection.lit_pixels,
                        );
                        metrics.rt_reflection_pixels = @max(
                            metrics.rt_reflection_pixels,
                            reflection.covered_pixels,
                        );
                        metrics.rt_penumbra_pixels = visibility.penumbra_pixels;
                        metrics.rt_invalid_pixels = invalid_pixels;
                    }
                }
            }
        }

        try ui_batch.begin(drawable_extent.width, drawable_extent.height);
        if (input.title_open) {
            try appendTitleOverlay(&ui_batch, drawable_extent);
        }
        var fps_text_buffer: [32]u8 = undefined;
        const fps_text = try fps_counter.writeLabel(fps_text_buffer[0..]);
        try appendFps(&ui_batch, drawable_extent, fps_text);
        const ui_vertices = ui_batch.vertices();
        try ui_vertex_buffer.replaceBytes(0, std.mem.sliceAsBytes(ui_vertices));

        var visible_chunks: usize = 0;
        var culled_chunks: usize = 0;
        var draw_calls: usize = 0;
        var visible_vertices: usize = 0;
        var visible_indices: usize = 0;
        var water_draw_chunks: [ray_tracing.maximum_traced_chunks]*GpuChunk = undefined;
        var water_draw_count: usize = 0;

        const encode_start = glfw.timeSeconds();
        var command_buffer = try queue.makeCommandBuffer();
        var encoder = try command_buffer.makeRenderCommandEncoder(.{
            .color_attachments = &.{.{
                .target = .{ .texture_view = presentation.?.hdrView() },
                .clear_color = .{
                    .red = 0.002,
                    .green = 0.004,
                    .blue = 0.018,
                    .alpha = 1,
                },
            }},
            .depth_attachment = .{
                .target = .{ .texture_view = presentation.?.depthView() },
                .clear_depth = 1.0,
                .store_action = .store,
            },
        });
        try encoder.setRenderPipelineState(&sky_pipeline);
        try encoder.setBindGroup(&sky_bind_group, .{ .index = 0 });
        try encoder.drawPrimitives(.{
            .primitive_type = .triangle,
            .vertex_count = 3,
        });

        // In RT mode the first asynchronous streaming frame can have no TLAS
        // and therefore no initialized PTGI scratch textures. Do not bind
        // those sampled views after the sky draw has started a Vulkan render
        // pass; the first successful RT/PTGI dispatch makes them ready.
        if (ptgi.terrainLightingReady(ray_tracing_enabled, ptgi_ready)) {
            try encoder.setRenderPipelineState(&pipeline);
            try encoder.setBindGroup(&bind_group.?, .{ .index = 0 });
            for (world.chunks.items) |*chunk| {
                if (!camera.chunkVisible(aspect, chunk.coord)) {
                    culled_chunks += 1;
                    continue;
                }
                visible_chunks += 1;
                if (chunk.opaque_index_count != 0) {
                    try encoder.setVertexBuffer(&chunk.vertex_buffer, .{ .index = 0 });
                    try encoder.setIndexBuffer(&chunk.index_buffer);
                    try encoder.drawIndexedPrimitives(.{
                        .primitive_type = .triangle,
                        .index_type = .uint32,
                        .index_count = @intCast(chunk.opaque_index_count),
                    });
                    draw_calls += 1;
                }
                if (chunk.water_index_count != 0) {
                    std.debug.assert(water_draw_count < water_draw_chunks.len);
                    water_draw_chunks[water_draw_count] = chunk;
                    water_draw_count += 1;
                }
                visible_vertices += chunk.vertex_count;
                visible_indices += chunk.index_count;
            }
        }

        // Keep a deterministic order for coincident shoreline faces. The
        // overlay depth write still selects the closest visible water surface.
        sortWaterChunksBackToFront(water_draw_chunks[0..water_draw_count], camera.position);
        try encoder.endEncoding();
        const commit_start = glfw.timeSeconds();
        try command_buffer.commit();

        // Water resolves transmission into a separate HDR overlay. This lets
        // the fragment shader sample the complete opaque HDR scene without a
        // read/write feedback hazard on either backend.
        var water_commands = try queue.makeCommandBuffer();
        var water_encoder = try water_commands.makeRenderCommandEncoder(.{
            .color_attachments = &.{.{
                .target = .{ .texture_view = presentation.?.waterOverlayView() },
                .clear_color = .{ .alpha = 0.0 },
            }},
            .depth_attachment = .{
                .target = .{ .texture_view = presentation.?.depthView() },
                .load_action = .load,
            },
        });
        if (water_draw_count != 0) {
            try water_encoder.setRenderPipelineState(&water_pipeline);
            try water_encoder.setBindGroup(&water_bind_group.?, .{ .index = 0 });
            for (water_draw_chunks[0..water_draw_count]) |chunk| {
                try water_encoder.setVertexBuffer(&chunk.vertex_buffer, .{ .index = 0 });
                try water_encoder.setIndexBuffer(&chunk.index_buffer);
                try water_encoder.drawIndexedPrimitives(.{
                    .primitive_type = .triangle,
                    .index_type = .uint32,
                    .index_count = @intCast(chunk.water_index_count),
                    .index_buffer_offset = @intCast(chunk.opaque_index_count * @sizeOf(u32)),
                });
                draw_calls += 1;
            }
        }
        try water_encoder.endEncoding();
        try water_commands.commit();

        var present_commands = try queue.makeCommandBuffer();
        var present_encoder = try present_commands.makeRenderCommandEncoder(.{
            .color_attachments = &.{.{
                .clear_color = .{ .alpha = 1.0 },
            }},
        });
        try presentation.?.encode(&present_encoder);
        try present_encoder.setRenderPipelineState(&ui_pipeline);
        try present_encoder.setVertexBuffer(&ui_vertex_buffer, .{ .index = 0 });
        try present_encoder.drawPrimitives(.{
            .primitive_type = .triangle,
            .vertex_count = @intCast(ui_vertices.len),
        });
        try present_encoder.endEncoding();
        try present_commands.presentDrawable();
        metrics.encode_seconds += glfw.timeSeconds() - encode_start;
        try present_commands.commit();
        metrics.commit_seconds += glfw.timeSeconds() - commit_start;
        metrics.frames += 1;
        metrics.visible_chunks = visible_chunks;
        metrics.culled_chunks = culled_chunks;
        metrics.draw_calls = draw_calls;
        metrics.visible_vertices = visible_vertices;
        metrics.visible_indices = visible_indices;
        metrics.frame_samples.record(glfw.timeSeconds() - frame_start);

        glfw.pollEvents();
        const now = glfw.timeSeconds();
        if (now - last_periodic_report >= 1.0) {
            std.debug.print(
                "voxel live: fps={d:.1} resident={} visible={} culled={} pending={} draws={} rebuilt={} uploaded_bytes={}\n",
                .{
                    fps_counter.display_fps,
                    world.chunks.items.len,
                    visible_chunks,
                    culled_chunks,
                    world.pendingCount(),
                    draw_calls,
                    metrics.rebuilt_chunks,
                    metrics.uploaded_bytes,
                },
            );
            last_periodic_report = now;
        }
        if (frame_limit) |limit| {
            if (metrics.frames >= limit) break;
        }
    }

    metrics.report(
        context.selectedBackend(),
        profile,
        world.chunks.items.len,
        world.pendingCount(),
    );
    if (frame_limit != null and world.pendingCount() != 0) {
        return error.VoxelWorldStreamingNotDrained;
    }
}

fn sortWaterChunksBackToFront(chunks: []*GpuChunk, camera_position: [3]f32) void {
    var index: usize = 1;
    while (index < chunks.len) : (index += 1) {
        const candidate = chunks[index];
        const candidate_distance = waterChunkDistanceSquared(candidate, camera_position);
        var insertion = index;
        while (insertion > 0 and
            waterChunkDistanceSquared(chunks[insertion - 1], camera_position) < candidate_distance)
        {
            chunks[insertion] = chunks[insertion - 1];
            insertion -= 1;
        }
        chunks[insertion] = candidate;
    }
}

fn waterChunkDistanceSquared(chunk: *const GpuChunk, camera_position: [3]f32) f32 {
    const center_x = @as(f32, @floatFromInt(chunk.coord.x * voxel.chunk_width)) +
        @as(f32, @floatFromInt(voxel.chunk_width)) * 0.5;
    const center_y = @as(f32, @floatFromInt(voxel.lake_water_level + 1));
    const center_z = @as(f32, @floatFromInt(chunk.coord.z * voxel.chunk_depth)) +
        @as(f32, @floatFromInt(voxel.chunk_depth)) * 0.5;
    const dx = center_x - camera_position[0];
    const dy = center_y - camera_position[1];
    const dz = center_z - camera_position[2];
    return dx * dx + dy * dy + dz * dz;
}

fn makeUniforms(
    camera: scene.Camera,
    width: u32,
    height: u32,
    celestial: scene.CelestialState,
    ptgi_enabled: bool,
    water_phase: f32,
) Uniforms {
    const aspect = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));
    return .{
        .view_projection_rows = camera.viewProjection(aspect),
        .light_direction_and_ambient = .{
            celestial.light_direction[0],
            celestial.light_direction[1],
            celestial.light_direction[2],
            celestial.ambient,
        },
        .light_color_and_strength = .{
            celestial.light_color[0],
            celestial.light_color[1],
            celestial.light_color[2],
            celestial.strength,
        },
        .cycle_factors = .{
            celestial.daylight,
            celestial.night,
            celestial.twilight,
            water_phase,
        },
        .camera_position_and_ptgi = .{
            camera.position[0],
            camera.position[1],
            camera.position[2],
            @floatFromInt(@intFromBool(ptgi_enabled)),
        },
    };
}

fn makeSkyBindGroup(
    device: *vkmtl.Device,
    layout: *vkmtl.binding.BindGroupLayout,
    uniform_buffer: *vkmtl.Buffer,
) !vkmtl.binding.BindGroup {
    const entries = [_]vkmtl.BindGroupEntry{.{
        .binding = 0,
        .resource = .{ .uniform_buffer = .{
            .buffer = uniform_buffer,
            .size = @sizeOf(sky.Uniforms),
        } },
    }};
    return device.makeBindGroup(.{
        .layout = layout,
        .entries = entries[0..],
    });
}

fn makeGBufferBindGroup(
    device: *vkmtl.Device,
    layout: *vkmtl.binding.BindGroupLayout,
    uniform_buffer: *vkmtl.Buffer,
    atlas_view: *vkmtl.TextureView,
    sampler: *vkmtl.SamplerState,
) !vkmtl.binding.BindGroup {
    return device.makeBindGroup(.{
        .label = "voxel PTGI gbuffer resources",
        .layout = layout,
        .entries = &.{
            .{ .binding = 0, .resource = .{ .uniform_buffer = .{
                .buffer = uniform_buffer,
                .size = @sizeOf(Uniforms),
            } } },
            .{ .binding = 1, .resource = .{ .sampled_texture = atlas_view } },
            .{ .binding = 2, .resource = .{ .sampler = sampler } },
        },
    });
}

fn appendTitleOverlay(batch: *ui.Batch, extent: vkmtl.Extent2D) ui.Error!void {
    const width: f32 = @floatFromInt(extent.width);
    const height: f32 = @floatFromInt(extent.height);
    _ = try batch.addRect(0, 0, width, height, .{ 0.003, 0.006, 0.018, 0.74 });

    const title = "VKMTL VOXEL WORLD";
    const title_scale: f32 = 5;
    const title_x = (width - ui.textWidth(title, title_scale)) * 0.5;
    const title_y = height * 0.38;
    _ = try batch.addText(title_x + 3, title_y + 3, title_scale, title, .{ 0, 0, 0, 0.7 });
    _ = try batch.addText(title_x, title_y, title_scale, title, .{ 0.66, 0.78, 1.0, 1.0 });

    const prompt = "Press ESC to continue";
    const prompt_scale: f32 = 4;
    const prompt_x = (width - ui.textWidth(prompt, prompt_scale)) * 0.5;
    const prompt_y = title_y + ui.textHeight(title_scale) + 42;
    _ = try batch.addText(prompt_x + 2, prompt_y + 2, prompt_scale, prompt, .{ 0, 0, 0, 0.7 });
    _ = try batch.addText(prompt_x, prompt_y, prompt_scale, prompt, .{ 0.93, 0.95, 1.0, 1.0 });
}

fn appendFps(batch: *ui.Batch, extent: vkmtl.Extent2D, text: []const u8) ui.Error!void {
    const scale: f32 = 3;
    const margin: f32 = 14;
    const padding: f32 = 8;
    const text_width = ui.textWidth(text, scale);
    const text_height = ui.textHeight(scale);
    const x = @as(f32, @floatFromInt(extent.width)) - text_width - margin;
    _ = try batch.addRect(
        x - padding,
        margin - padding,
        text_width + padding * 2,
        text_height + padding * 2,
        .{ 0.002, 0.004, 0.012, 0.58 },
    );
    _ = try batch.addText(x + 2, margin + 2, scale, text, .{ 0, 0, 0, 0.8 });
    _ = try batch.addText(x, margin, scale, text, .{ 0.68, 0.92, 1.0, 1.0 });
}

fn makeVoxelBindGroup(
    device: *vkmtl.Device,
    layout: *vkmtl.binding.BindGroupLayout,
    uniform_buffer: *vkmtl.Buffer,
    atlas_view: *vkmtl.TextureView,
    sampler: *vkmtl.SamplerState,
    visibility_view: *vkmtl.TextureView,
    indirect_view: *vkmtl.TextureView,
) !vkmtl.binding.BindGroup {
    const entries = [_]vkmtl.BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .uniform_buffer = .{
                .buffer = uniform_buffer,
                .size = @sizeOf(Uniforms),
            } },
        },
        .{ .binding = 1, .resource = .{ .sampled_texture = atlas_view } },
        .{ .binding = 2, .resource = .{ .sampler = sampler } },
        .{ .binding = 3, .resource = .{ .sampled_texture = visibility_view } },
        .{ .binding = 4, .resource = .{ .sampled_texture = indirect_view } },
    };
    return device.makeBindGroup(.{
        .layout = layout,
        .entries = entries[0..],
    });
}

fn makeWaterBindGroup(
    device: *vkmtl.Device,
    layout: *vkmtl.binding.BindGroupLayout,
    uniform_buffer: *vkmtl.Buffer,
    sampler: *vkmtl.SamplerState,
    visibility_view: *vkmtl.TextureView,
    indirect_view: *vkmtl.TextureView,
    opaque_hdr_view: *vkmtl.TextureView,
    opaque_surface_view: *vkmtl.TextureView,
    reflection_view: *vkmtl.TextureView,
) !vkmtl.binding.BindGroup {
    return device.makeBindGroup(.{
        .label = "voxel refractive water resources",
        .layout = layout,
        .entries = &.{
            .{ .binding = 0, .resource = .{ .uniform_buffer = .{
                .buffer = uniform_buffer,
                .size = @sizeOf(Uniforms),
            } } },
            .{ .binding = 2, .resource = .{ .sampler = sampler } },
            .{ .binding = 3, .resource = .{ .sampled_texture = visibility_view } },
            .{ .binding = 4, .resource = .{ .sampled_texture = indirect_view } },
            .{ .binding = 5, .resource = .{ .sampled_texture = opaque_hdr_view } },
            .{ .binding = 6, .resource = .{ .sampled_texture = opaque_surface_view } },
            .{ .binding = 7, .resource = .{ .sampled_texture = reflection_view } },
        },
    });
}

fn updateCameraFromInput(
    window: glfw.Window,
    camera: *scene.Camera,
    delta_seconds: f32,
    state: *InputState,
) bool {
    const speed: f32 = if (keyDown(window, glfw.c.GLFW_KEY_LEFT_CONTROL) or
        keyDown(window, glfw.c.GLFW_KEY_RIGHT_CONTROL)) 28.0 else 10.0;
    var forward_axis: f32 = 0;
    var right_axis: f32 = 0;
    var vertical_axis: f32 = 0;
    if (keyDown(window, glfw.c.GLFW_KEY_W)) forward_axis += 1;
    if (keyDown(window, glfw.c.GLFW_KEY_S)) forward_axis -= 1;
    if (keyDown(window, glfw.c.GLFW_KEY_D)) right_axis += 1;
    if (keyDown(window, glfw.c.GLFW_KEY_A)) right_axis -= 1;
    if (keyDown(window, glfw.c.GLFW_KEY_SPACE)) vertical_axis += 1;
    if (keyDown(window, glfw.c.GLFW_KEY_LEFT_SHIFT) or
        keyDown(window, glfw.c.GLFW_KEY_RIGHT_SHIFT)) vertical_axis -= 1;
    camera.move(
        forward_axis * speed * delta_seconds,
        right_axis * speed * delta_seconds,
        vertical_axis * speed * delta_seconds,
    );

    const look_speed = 1.4 * delta_seconds;
    if (keyDown(window, glfw.c.GLFW_KEY_LEFT)) camera.yaw -= look_speed;
    if (keyDown(window, glfw.c.GLFW_KEY_RIGHT)) camera.yaw += look_speed;
    if (keyDown(window, glfw.c.GLFW_KEY_UP)) camera.pitch += look_speed;
    if (keyDown(window, glfw.c.GLFW_KEY_DOWN)) camera.pitch -= look_speed;

    var mouse_x: f64 = 0;
    var mouse_y: f64 = 0;
    glfw.c.glfwGetCursorPos(window, &mouse_x, &mouse_y);
    if (state.mouse_initialized) {
        camera.yaw += @as(f32, @floatCast(mouse_x - state.last_mouse_x)) * 0.0025;
        camera.pitch -= @as(f32, @floatCast(mouse_y - state.last_mouse_y)) * 0.0025;
    } else {
        state.mouse_initialized = true;
    }
    state.last_mouse_x = mouse_x;
    state.last_mouse_y = mouse_y;
    camera.pitch = std.math.clamp(camera.pitch, -1.48, 1.48);

    const rebuild_down = keyDown(window, glfw.c.GLFW_KEY_R);
    const requested = rebuild_down and !state.rebuild_down;
    state.rebuild_down = rebuild_down;
    return requested;
}

fn updateTitleToggle(window: glfw.Window, state: *InputState) void {
    const escape_down = keyDown(window, glfw.c.GLFW_KEY_ESCAPE);
    if (escape_down and !state.escape_down) {
        state.title_open = !state.title_open;
        state.mouse_initialized = false;
        if (state.title_open) {
            releaseMouse(window);
        } else {
            captureMouse(window);
        }
    }
    state.escape_down = escape_down;
}

fn captureMouse(window: glfw.Window) void {
    glfw.c.glfwSetInputMode(window, glfw.c.GLFW_CURSOR, glfw.c.GLFW_CURSOR_DISABLED);
    if (glfw.c.glfwRawMouseMotionSupported() == glfw.c.GLFW_TRUE) {
        glfw.c.glfwSetInputMode(window, glfw.c.GLFW_RAW_MOUSE_MOTION, glfw.c.GLFW_TRUE);
    }
}

fn releaseMouse(window: glfw.Window) void {
    if (glfw.c.glfwRawMouseMotionSupported() == glfw.c.GLFW_TRUE) {
        glfw.c.glfwSetInputMode(window, glfw.c.GLFW_RAW_MOUSE_MOTION, glfw.c.GLFW_FALSE);
    }
    glfw.c.glfwSetInputMode(window, glfw.c.GLFW_CURSOR, glfw.c.GLFW_CURSOR_NORMAL);
}

fn keyDown(window: glfw.Window, key: c_int) bool {
    return glfw.c.glfwGetKey(window, key) == glfw.c.GLFW_PRESS;
}

fn coordEqual(a: voxel.ChunkCoord, b: voxel.ChunkCoord) bool {
    return a.x == b.x and a.z == b.z;
}

fn mixChunkGeneration(generation: u64) u64 {
    var value = generation;
    value ^= value >> 30;
    value *%= 0xbf58_476d_1ce4_e5b9;
    value ^= value >> 27;
    value *%= 0x94d0_49bb_1331_11eb;
    value ^= value >> 31;
    return value;
}

fn profileFromEnv() scene.WorkloadProfile {
    const value = std.mem.span(getenv("VKMTL_VOXEL_PROFILE") orelse return .default);
    if (std.ascii.eqlIgnoreCase(value, "smoke")) return .smoke;
    if (std.ascii.eqlIgnoreCase(value, "default")) return .default;
    if (std.ascii.eqlIgnoreCase(value, "stress")) return .stress;
    std.debug.print("Ignoring unsupported VKMTL_VOXEL_PROFILE value: {s}\n", .{value});
    return .default;
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    if (std.ascii.eqlIgnoreCase(value, "vulkan")) return .vulkan;
    if (std.ascii.eqlIgnoreCase(value, "metal")) return .metal;
    std.debug.print("Ignoring unsupported VKMTL_BACKEND value: {s}\n", .{value});
    return null;
}

fn rayTracingModeFromEnv() settings.ParseError!settings.RayTracingMode {
    const value = getenv("VKMTL_VOXEL_RT");
    return settings.parseRayTracingMode(if (value) |text| std.mem.span(text) else null);
}

fn frameLimitFromEnv() ?usize {
    const value = std.mem.span(getenv("VKMTL_VOXEL_FRAME_LIMIT") orelse return null);
    const limit = std.fmt.parseUnsigned(usize, value, 10) catch {
        std.debug.print("Ignoring invalid VKMTL_VOXEL_FRAME_LIMIT value: {s}\n", .{value});
        return null;
    };
    if (limit == 0) {
        std.debug.print("Ignoring zero VKMTL_VOXEL_FRAME_LIMIT value\n", .{});
        return null;
    }
    return limit;
}

fn cycleTimeFromEnv() ?f32 {
    const value = std.mem.span(getenv("VKMTL_VOXEL_CYCLE_TIME") orelse return null);
    const time_seconds = std.fmt.parseFloat(f32, value) catch {
        std.debug.print("Ignoring invalid VKMTL_VOXEL_CYCLE_TIME value: {s}\n", .{value});
        return null;
    };
    if (!std.math.isFinite(time_seconds)) {
        std.debug.print("Ignoring non-finite VKMTL_VOXEL_CYCLE_TIME value: {s}\n", .{value});
        return null;
    }
    return time_seconds;
}

fn boolFromEnv(name: [*:0]const u8) bool {
    const value = std.mem.span(getenv(name) orelse return false);
    return std.ascii.eqlIgnoreCase(value, "1") or
        std.ascii.eqlIgnoreCase(value, "true") or
        std.ascii.eqlIgnoreCase(value, "yes");
}
