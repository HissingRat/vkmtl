const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");
const voxel = @import("voxel.zig");
const scene = @import("scene.zig");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl voxel world";
const shader_source = @embedFile("shaders/voxel_world.slang");
const terrain_seed: u32 = 0x564f_584c;
const atlas_tile_size: usize = 16;
const atlas_tile_count: usize = 3;
const atlas_width: usize = atlas_tile_size * atlas_tile_count;
const atlas_height: usize = atlas_tile_size;
const maximum_rebuilds_per_frame: usize = 2;
const maximum_upload_bytes_per_frame: usize = 8 * 1024 * 1024;

const color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
    .{ .format = .bgra8_unorm_srgb },
};

const Uniforms = extern struct {
    view_projection_rows: [4][4]f32,
    light_direction_and_ambient: [4]f32,
    light_color_and_strength: [4]f32,
};

comptime {
    if (@sizeOf(Uniforms) != 96) @compileError("voxel uniforms must match the 96-byte shader ABI");
}

const GpuChunk = struct {
    coord: voxel.ChunkCoord,
    vertex_buffer: vkmtl.Buffer,
    index_buffer: vkmtl.Buffer,
    vertex_count: usize,
    index_count: usize,

    fn init(device: *vkmtl.Device, coord: voxel.ChunkCoord, mesh: voxel.Mesh) !GpuChunk {
        var vertex_buffer = try device.makeBuffer(.{
            .bytes = std.mem.sliceAsBytes(mesh.vertices),
            .usage = .{ .vertex = true },
            .storage_mode = .shared,
        });
        errdefer vertex_buffer.deinit();

        var index_buffer = try device.makeBuffer(.{
            .bytes = std.mem.sliceAsBytes(mesh.indices),
            .usage = .{ .index = true },
            .storage_mode = .shared,
        });
        errdefer index_buffer.deinit();

        return .{
            .coord = coord,
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
            .vertex_count = mesh.vertices.len,
            .index_count = mesh.indices.len,
        };
    }

    fn deinit(self: *GpuChunk) void {
        self.index_buffer.deinit();
        self.vertex_buffer.deinit();
    }
};

const World = struct {
    allocator: std.mem.Allocator,
    profile: scene.WorkloadProfile,
    seed: u32,
    center: ?voxel.ChunkCoord = null,
    chunks: std.ArrayList(GpuChunk) = .empty,
    pending: std.ArrayList(voxel.ChunkCoord) = .empty,

    fn init(allocator: std.mem.Allocator, profile: scene.WorkloadProfile, seed: u32) World {
        return .{
            .allocator = allocator,
            .profile = profile,
            .seed = seed,
        };
    }

    fn deinit(self: *World) void {
        for (self.chunks.items) |*chunk| chunk.deinit();
        self.chunks.deinit(self.allocator);
        self.pending.deinit(self.allocator);
    }

    fn syncDesired(self: *World, center: voxel.ChunkCoord, metrics: *Metrics) !void {
        if (self.center) |current| {
            if (coordEqual(current, center)) return;
        }
        self.center = center;

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
        std.debug.assert(self.pending.items.len <= self.profile.maximumResidentChunks());
        metrics.max_pending_rebuilds = @max(metrics.max_pending_rebuilds, self.pending.items.len);
    }

    fn requestRebuild(self: *World, coord: voxel.ChunkCoord, metrics: *Metrics) !void {
        if (self.findChunk(coord)) |chunk_index| {
            var removed = self.chunks.swapRemove(chunk_index);
            removed.deinit();
            metrics.retired_chunks += 1;
        }
        for (self.pending.items) |pending_coord| {
            if (coordEqual(pending_coord, coord)) return;
        }
        try self.pending.insert(self.allocator, 0, coord);
        metrics.max_pending_rebuilds = @max(metrics.max_pending_rebuilds, self.pending.items.len);
    }

    fn processPending(self: *World, device: *vkmtl.Device, metrics: *Metrics) !void {
        var rebuilt: usize = 0;
        var uploaded: usize = 0;
        while (rebuilt < maximum_rebuilds_per_frame and self.pending.items.len != 0) {
            const coord = self.pending.orderedRemove(0);
            const mesh_start = glfw.timeSeconds();
            var mesh = try voxel.meshTerrainChunk(self.allocator, coord, self.seed);
            metrics.mesh_seconds += glfw.timeSeconds() - mesh_start;
            defer mesh.deinit(self.allocator);

            const mesh_bytes = std.mem.sliceAsBytes(mesh.vertices).len + std.mem.sliceAsBytes(mesh.indices).len;
            if (rebuilt != 0 and uploaded + mesh_bytes > maximum_upload_bytes_per_frame) {
                try self.pending.insert(self.allocator, 0, coord);
                break;
            }

            var gpu_chunk = try GpuChunk.init(device, coord, mesh);
            self.chunks.append(self.allocator, gpu_chunk) catch |err| {
                gpu_chunk.deinit();
                return err;
            };
            rebuilt += 1;
            uploaded += mesh_bytes;
            metrics.rebuilt_chunks += 1;
            metrics.uploaded_bytes += mesh_bytes;
            metrics.buffer_allocations += 2;
        }
        metrics.max_resident_chunks = @max(metrics.max_resident_chunks, self.chunks.items.len);
        metrics.max_pending_rebuilds = @max(metrics.max_pending_rebuilds, self.pending.items.len);
    }

    fn findChunk(self: *const World, coord: voxel.ChunkCoord) ?usize {
        for (self.chunks.items, 0..) |chunk, index| {
            if (coordEqual(chunk.coord, coord)) return index;
        }
        return null;
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
    encode_seconds: f64 = 0,
    commit_seconds: f64 = 0,
    visible_chunks: usize = 0,
    culled_chunks: usize = 0,
    draw_calls: usize = 0,
    visible_vertices: usize = 0,
    visible_indices: usize = 0,
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
            "voxel metrics: backend={s} profile={s} frames={} resident={} visible={} culled={} pending={} draws={} vertices={} indices={} rebuilt={} retired={} uploaded_bytes={} buffers={} max_resident={} max_pending={} mesh_ms={d:.3} encode_ms_per_frame={d:.3} commit_ms_per_frame={d:.3} frame_p50_ms={d:.3} frame_p95_ms={d:.3} frame_max_ms={d:.3}\n",
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
                self.mesh_seconds * 1000.0,
                self.encode_seconds * 1000.0 / @as(f64, @floatFromInt(frames)),
                self.commit_seconds * 1000.0 / @as(f64, @floatFromInt(frames)),
                frame_summary.p50_ms,
                frame_summary.p95_ms,
                frame_summary.max_ms,
            },
        );
        std.debug.print(
            "voxel_world_pressure_test=ok backend={s} profile={s} frames={}\n",
            .{ @tagName(backend), @tagName(profile), self.frames },
        );
    }
};

const InputState = struct {
    mouse_initialized: bool = false,
    last_mouse_x: f64 = 0,
    last_mouse_y: f64 = 0,
    rebuild_down: bool = false,
};

pub fn main(_: std.process.Init.Minimal) !void {
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
    std.debug.print("Using backend: {}\n", .{context.selectedBackend()});
    std.debug.print(
        "voxel workload contract: profile={s} chunk={}x{}x{} radius={} max_resident={} rebuilds_per_frame={} upload_budget={}\n",
        .{
            @tagName(profile),
            voxel.chunk_width,
            voxel.chunk_height,
            voxel.chunk_depth,
            profile.radius(),
            profile.maximumResidentChunks(),
            maximum_rebuilds_per_frame,
            maximum_upload_bytes_per_frame,
        },
    );

    var device = context.device();
    var queue = context.queue();
    var swapchain = context.swapchain();

    var camera = scene.Camera{};
    var uniforms = makeUniforms(camera, 1280, 720);
    var uniform_buffer = try device.makeBuffer(.{
        .bytes = std.mem.asBytes(&uniforms),
        .usage = .{ .uniform = true },
        .storage_mode = .shared,
    });
    defer uniform_buffer.deinit();

    var atlas_pixels: [atlas_width * atlas_height * 4]u8 = undefined;
    fillAtlas(&atlas_pixels);
    var atlas = try device.makeTexture(.{
        .format = .rgba8_unorm_srgb,
        .width = atlas_width,
        .height = atlas_height,
        .usage = .{ .shader_read = true },
        .storage_mode = .shared,
    });
    defer atlas.deinit();
    try atlas.replaceAll2D(.{ .bytes = atlas_pixels[0..] });

    var atlas_view = try atlas.makeTextureView(.{});
    defer atlas_view.deinit();
    var sampler = try device.makeSamplerState(.{
        .min_filter = .nearest,
        .mag_filter = .nearest,
    });
    defer sampler.deinit();

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
    const bind_group_entries = [_]vkmtl.BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .uniform_buffer = .{
                .buffer = &uniform_buffer,
                .size = @sizeOf(Uniforms),
            } },
        },
        .{ .binding = 1, .resource = .{ .sampled_texture = &atlas_view } },
        .{ .binding = 2, .resource = .{ .sampler = &sampler } },
    };
    var bind_group = try device.makeBindGroup(.{
        .layout = &bind_group_layout,
        .entries = bind_group_entries[0..],
    });
    defer bind_group.deinit();

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

    var metrics = Metrics{};
    var world = World.init(allocator, profile, terrain_seed);
    defer world.deinit();
    try world.syncDesired(camera.chunkCoord(), &metrics);

    var input = InputState{};
    if (!autopilot and frame_limit == null) captureMouse(window);
    var previous_seconds = glfw.timeSeconds();
    var last_periodic_report = previous_seconds;

    while (!glfw.windowShouldClose(window)) {
        const frame_start = glfw.timeSeconds();
        const delta_seconds = @as(f32, @floatCast(@min(frame_start - previous_seconds, 0.1)));
        previous_seconds = frame_start;

        var rebuild_requested = false;
        if (autopilot) {
            camera.position[0] += 0.75;
            camera.yaw = @as(f32, @floatFromInt(metrics.frames)) * 0.012;
            rebuild_requested = metrics.frames != 0 and metrics.frames % 16 == 0;
        } else {
            rebuild_requested = updateCameraFromInput(window, &camera, delta_seconds, &input);
        }

        try world.syncDesired(camera.chunkCoord(), &metrics);
        if (rebuild_requested) try world.requestRebuild(camera.chunkCoord(), &metrics);
        try world.processPending(&device, &metrics);

        const extent = common.framebufferExtent(window);
        if (extent.isZero()) {
            glfw.pollEvents();
            continue;
        }
        try swapchain.resize(extent);

        uniforms = makeUniforms(camera, extent.width, extent.height);
        try uniform_buffer.replaceBytes(0, std.mem.asBytes(&uniforms));

        const aspect = @as(f32, @floatFromInt(extent.width)) / @as(f32, @floatFromInt(extent.height));
        var visible_chunks: usize = 0;
        var culled_chunks: usize = 0;
        var draw_calls: usize = 0;
        var visible_vertices: usize = 0;
        var visible_indices: usize = 0;

        const encode_start = glfw.timeSeconds();
        var command_buffer = try queue.makeCommandBuffer();
        var encoder = try command_buffer.makeRenderCommandEncoder(.{
            .color_attachments = &.{.{
                .clear_color = .{
                    .red = 0.46,
                    .green = 0.68,
                    .blue = 0.88,
                    .alpha = 1,
                },
            }},
            .depth_attachment = .{ .clear_depth = 1.0 },
        });
        try encoder.setRenderPipelineState(&pipeline);
        try encoder.setBindGroup(&bind_group, .{ .index = 0 });
        for (world.chunks.items) |*chunk| {
            if (!camera.chunkVisible(aspect, chunk.coord)) {
                culled_chunks += 1;
                continue;
            }
            visible_chunks += 1;
            try encoder.setVertexBuffer(&chunk.vertex_buffer, .{ .index = 0 });
            try encoder.setIndexBuffer(&chunk.index_buffer);
            try encoder.drawIndexedPrimitives(.{
                .primitive_type = .triangle,
                .index_type = .uint32,
                .index_count = @intCast(chunk.index_count),
            });
            draw_calls += 1;
            visible_vertices += chunk.vertex_count;
            visible_indices += chunk.index_count;
        }
        try encoder.endEncoding();
        try command_buffer.presentDrawable();
        metrics.encode_seconds += glfw.timeSeconds() - encode_start;

        const commit_start = glfw.timeSeconds();
        try command_buffer.commit();
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
                "voxel live: resident={} visible={} culled={} pending={} draws={} rebuilt={} uploaded_bytes={}\n",
                .{
                    world.chunks.items.len,
                    visible_chunks,
                    culled_chunks,
                    world.pending.items.len,
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
        world.pending.items.len,
    );
}

fn makeUniforms(camera: scene.Camera, width: u32, height: u32) Uniforms {
    const aspect = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));
    const light_direction = scene.normalize(.{ 0.42, 0.86, 0.30 });
    return .{
        .view_projection_rows = camera.viewProjection(aspect),
        .light_direction_and_ambient = .{
            light_direction[0],
            light_direction[1],
            light_direction[2],
            0.30,
        },
        .light_color_and_strength = .{ 1.0, 0.96, 0.86, 0.82 },
    };
}

fn fillAtlas(out_pixels: *[atlas_width * atlas_height * 4]u8) void {
    const base_colors = [_][3]u8{
        .{ 88, 166, 72 },
        .{ 132, 88, 52 },
        .{ 126, 132, 140 },
    };
    for (0..atlas_height) |y| {
        for (0..atlas_width) |x| {
            const tile = x / atlas_tile_size;
            const local_x = x % atlas_tile_size;
            const variation: i16 = @intCast((local_x * 7 + y * 11 + tile * 13) % 25);
            const signed_variation = variation - 12;
            const destination = (y * atlas_width + x) * 4;
            inline for (0..3) |channel| {
                out_pixels[destination + channel] = @intCast(std.math.clamp(
                    @as(i16, base_colors[tile][channel]) + signed_variation,
                    0,
                    255,
                ));
            }
            out_pixels[destination + 3] = 255;
        }
    }
}

fn updateCameraFromInput(
    window: glfw.Window,
    camera: *scene.Camera,
    delta_seconds: f32,
    state: *InputState,
) bool {
    const speed: f32 = if (keyDown(window, glfw.c.GLFW_KEY_LEFT_SHIFT) or
        keyDown(window, glfw.c.GLFW_KEY_RIGHT_SHIFT)) 28.0 else 10.0;
    var forward_axis: f32 = 0;
    var right_axis: f32 = 0;
    var vertical_axis: f32 = 0;
    if (keyDown(window, glfw.c.GLFW_KEY_W)) forward_axis += 1;
    if (keyDown(window, glfw.c.GLFW_KEY_S)) forward_axis -= 1;
    if (keyDown(window, glfw.c.GLFW_KEY_D)) right_axis += 1;
    if (keyDown(window, glfw.c.GLFW_KEY_A)) right_axis -= 1;
    if (keyDown(window, glfw.c.GLFW_KEY_E)) vertical_axis += 1;
    if (keyDown(window, glfw.c.GLFW_KEY_Q)) vertical_axis -= 1;
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

    if (keyDown(window, glfw.c.GLFW_KEY_ESCAPE)) {
        glfw.c.glfwSetWindowShouldClose(window, glfw.c.GLFW_TRUE);
    }
    const rebuild_down = keyDown(window, glfw.c.GLFW_KEY_R);
    const requested = rebuild_down and !state.rebuild_down;
    state.rebuild_down = rebuild_down;
    return requested;
}

fn captureMouse(window: glfw.Window) void {
    glfw.c.glfwSetInputMode(window, glfw.c.GLFW_CURSOR, glfw.c.GLFW_CURSOR_DISABLED);
    if (glfw.c.glfwRawMouseMotionSupported() == glfw.c.GLFW_TRUE) {
        glfw.c.glfwSetInputMode(window, glfw.c.GLFW_RAW_MOUSE_MOTION, glfw.c.GLFW_TRUE);
    }
}

fn keyDown(window: glfw.Window, key: c_int) bool {
    return glfw.c.glfwGetKey(window, key) == glfw.c.GLFW_PRESS;
}

fn coordEqual(a: voxel.ChunkCoord, b: voxel.ChunkCoord) bool {
    return a.x == b.x and a.z == b.z;
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

fn boolFromEnv(name: [*:0]const u8) bool {
    const value = std.mem.span(getenv(name) orelse return false);
    return std.ascii.eqlIgnoreCase(value, "1") or
        std.ascii.eqlIgnoreCase(value, "true") or
        std.ascii.eqlIgnoreCase(value, "yes");
}
