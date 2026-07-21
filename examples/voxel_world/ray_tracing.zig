const std = @import("std");
const vkmtl = @import("vkmtl");
const scene = @import("scene.zig");
const voxel = @import("voxel.zig");

const shader_source = @embedFile("shaders/voxel_world_rt.slang");

pub const traced_chunk_radius: i32 = 8;
pub const maximum_traced_chunks: usize = 289;
pub const diffuse_bounce_count: u32 = 3;
const traced_chunk_diameter: usize = @intCast(traced_chunk_radius * 2 + 1);
const material_column_width: usize = traced_chunk_diameter * @as(usize, @intCast(voxel.chunk_width));
const material_column_depth: usize = traced_chunk_diameter * @as(usize, @intCast(voxel.chunk_depth));

const MaterialColumn = extern struct {
    height: i32,
    surface_and_water: u32,
    wood_span: u32,
    leaves_span: u32,
};

pub const FrameData = extern struct {
    camera_position_and_tan_half_fov: [4]f32,
    camera_forward_and_aspect: [4]f32,
    camera_right_and_max_distance: [4]f32,
    camera_up_and_shadow_bias: [4]f32,
    light_direction_and_strength: [4]f32,
    light_color_and_daylight: [4]f32,
    sky_color_and_night: [4]f32,
    frame_index_seed_and_light_radius: [4]f32,
    sun_direction_and_cloud_time: [4]f32,
    material_origin_and_extent: [4]f32,
    traced_origin_and_extent: [4]f32,
};

comptime {
    if (@sizeOf(FrameData) != 176) @compileError("voxel RT frame data must match the 176-byte shader ABI");
    if (@sizeOf(MaterialColumn) != 16) @compileError("voxel RT material column ABI mismatch");
    if (@intFromEnum(voxel.BlockId.wood) != 6 or
        @intFromEnum(voxel.BlockId.leaves) != 7 or
        @intFromEnum(voxel.BlockId.water) != 8)
    {
        @compileError("voxel RT feature block ids must match the shader contract");
    }
    if (@intFromEnum(voxel.materialForFace(.wood, .{ 0, 1, 0 })) != 7 or
        @intFromEnum(voxel.materialForFace(.wood, .{ 1, 0, 0 })) != 8 or
        @intFromEnum(voxel.materialForFace(.leaves, .{ 0, 1, 0 })) != 9 or
        @intFromEnum(voxel.materialForFace(.water, .{ 0, 1, 0 })) != 10)
    {
        @compileError("voxel RT feature material tiles must match the shader contract");
    }
}

pub const RebuildInfo = struct {
    instance_count: usize,
    result_size: u64,
    scratch_size: u64,
};

const TracedBounds = struct {
    origin: [2]i32,
    extent: [2]i32,
};

fn makeTracedBounds(center: voxel.ChunkCoord, radius: i32) TracedBounds {
    std.debug.assert(radius >= 0 and radius <= traced_chunk_radius);
    const diameter = radius * 2 + 1;
    return .{
        .origin = .{
            (center.x - radius) * voxel.chunk_width,
            (center.z - radius) * voxel.chunk_depth,
        },
        .extent = .{
            diameter * voxel.chunk_width,
            diameter * voxel.chunk_depth,
        },
    };
}

fn publishedTracedBounds(
    center: voxel.ChunkCoord,
    radius: i32,
    complete_square: bool,
) TracedBounds {
    return if (complete_square)
        makeTracedBounds(center, radius)
    else
        .{ .origin = .{ 0, 0 }, .extent = .{ 0, 0 } };
}

pub const LightingTarget = struct {
    texture: vkmtl.Texture,
    view: vkmtl.TextureView,

    pub fn init(device: *vkmtl.Device, extent: vkmtl.Extent2D) !LightingTarget {
        var texture = try device.makeTexture(.{
            .label = "voxel ray-traced lighting",
            .format = .rgba16_float,
            .width = extent.width,
            .height = extent.height,
            .usage = .{
                .shader_read = true,
                .shader_write = true,
                .copy_source = true,
            },
            .storage_mode = .private,
        });
        errdefer texture.deinit();
        const view = try texture.makeTextureView(.{});
        return .{ .texture = texture, .view = view };
    }

    pub fn deinit(self: *LightingTarget) void {
        self.view.deinit();
        self.texture.deinit();
        self.* = undefined;
    }
};

pub const LightingStats = struct {
    primary_hit_pixels: u64 = 0,
    directionally_lit_pixels: u64 = 0,
    shadowed_pixels: u64 = 0,
    indirect_lit_pixels: u64 = 0,
    low_indirect_pixels: u64 = 0,
    non_finite_pixels: u64 = 0,
    negative_radiance_pixels: u64 = 0,

    pub fn hasNativeOcclusion(self: LightingStats, require_direct_light: bool) bool {
        return self.primary_hit_pixels != 0 and
            (!require_direct_light or self.directionally_lit_pixels != 0) and
            self.shadowed_pixels != 0;
    }

    pub fn hasIndirectRadiance(self: LightingStats) bool {
        return self.indirect_lit_pixels != 0;
    }

    pub fn isFiniteAndNonNegative(self: LightingStats) bool {
        return self.non_finite_pixels == 0 and self.negative_radiance_pixels == 0;
    }

    fn observe(self: *LightingStats, sample: [4]f32) void {
        for (sample) |channel| {
            if (!std.math.isFinite(channel)) {
                self.non_finite_pixels += 1;
                return;
            }
        }
        if (sample[3] < 0.0) return;
        if (sample[0] < 0.0 or sample[1] < 0.0 or sample[2] < 0.0) {
            self.negative_radiance_pixels += 1;
            return;
        }

        self.primary_hit_pixels += 1;
        if (sample[3] >= 0.99) {
            self.directionally_lit_pixels += 1;
        } else {
            self.shadowed_pixels += 1;
        }
        const indirect_radiance = sample[0] + sample[1] + sample[2];
        if (indirect_radiance > 0.001) self.indirect_lit_pixels += 1;
        if (indirect_radiance < 0.02) self.low_indirect_pixels += 1;
    }
};

pub const RadianceStats = struct {
    lit_pixels: u64 = 0,
    non_finite_pixels: u64 = 0,
    negative_pixels: u64 = 0,

    pub fn isValid(self: RadianceStats) bool {
        return self.lit_pixels != 0 and
            self.non_finite_pixels == 0 and
            self.negative_pixels == 0;
    }

    fn observe(self: *RadianceStats, sample: [4]f32) void {
        for (sample[0..3]) |channel| {
            if (!std.math.isFinite(channel)) {
                self.non_finite_pixels += 1;
                return;
            }
            if (channel < 0.0) {
                self.negative_pixels += 1;
                return;
            }
        }
        if (sample[0] + sample[1] + sample[2] > 0.001) self.lit_pixels += 1;
    }
};

pub const ReflectionStats = struct {
    covered_pixels: u64 = 0,
    lit_pixels: u64 = 0,
    invalid_pixels: u64 = 0,

    pub fn isValid(self: ReflectionStats) bool {
        return self.covered_pixels != 0 and
            self.lit_pixels != 0 and
            self.invalid_pixels == 0;
    }

    fn observe(self: *ReflectionStats, sample: [4]f32) void {
        for (sample) |channel| {
            if (!std.math.isFinite(channel)) {
                self.invalid_pixels += 1;
                return;
            }
        }
        if (sample[0] < 0.0 or sample[1] < 0.0 or sample[2] < 0.0 or
            sample[3] < 0.0 or sample[3] > 1.001)
        {
            self.invalid_pixels += 1;
            return;
        }
        if (sample[3] <= 0.01) {
            if (sample[0] + sample[1] + sample[2] > 0.001) self.invalid_pixels += 1;
            return;
        }
        if (sample[3] < 0.99) {
            self.invalid_pixels += 1;
            return;
        }

        self.covered_pixels += 1;
        if (sample[0] + sample[1] + sample[2] > 0.001) self.lit_pixels += 1;
    }
};

pub const VisibilityStats = struct {
    surface_pixels: u64 = 0,
    fully_lit_pixels: u64 = 0,
    fully_shadowed_pixels: u64 = 0,
    penumbra_pixels: u64 = 0,
    invalid_pixels: u64 = 0,

    pub fn isValid(self: VisibilityStats) bool {
        return self.surface_pixels != 0 and self.invalid_pixels == 0;
    }

    fn observe(self: *VisibilityStats, sample: [4]f32) void {
        const visibility = sample[3];
        if (!std.math.isFinite(visibility)) {
            self.invalid_pixels += 1;
            return;
        }
        if (visibility < 0.0) return;
        if (visibility > 1.001) {
            self.invalid_pixels += 1;
            return;
        }

        self.surface_pixels += 1;
        if (visibility <= 0.01) {
            self.fully_shadowed_pixels += 1;
        } else if (visibility >= 0.99) {
            self.fully_lit_pixels += 1;
        } else {
            self.penumbra_pixels += 1;
        }
    }
};

pub const Lighting = struct {
    allocator: std.mem.Allocator,
    compiled_shader: vkmtl.shader.CompiledRayTracingShader,
    pipeline: vkmtl.ray_tracing.RayTracingPipelineState,
    shader_binding_table: vkmtl.ray_tracing.ShaderBindingTable,
    bind_group_layout: vkmtl.binding.BindGroupLayout,
    bind_group: ?vkmtl.binding.BindGroup = null,
    material_columns: ?vkmtl.Buffer = null,
    material_center: ?voxel.ChunkCoord = null,
    material_origin: [2]i32 = .{ 0, 0 },
    traced_origin: [2]i32 = .{ 0, 0 },
    traced_extent: [2]i32 = .{ 0, 0 },
    top_level: ?vkmtl.ray_tracing.AccelerationStructure = null,
    instance_count: usize = 0,

    pub fn isUsable(device: *const vkmtl.Device) bool {
        const features = device.features();
        if (!features.ray_tracing or
            !features.acceleration_structures or
            !features.storage_buffers)
        {
            return false;
        }
        const limits = device.limits();
        if (limits.max_ray_tracing_recursion_depth != 0 and
            limits.max_ray_tracing_recursion_depth < 1)
        {
            return false;
        }
        if (limits.max_acceleration_structure_instances != 0 and
            limits.max_acceleration_structure_instances < maximum_traced_chunks)
        {
            return false;
        }
        const format = device.getFormatCaps(.rgba16_float);
        const depth = device.getFormatCaps(.depth32_float);
        return format.storage and format.sampled and format.color_attachment and
            format.copy_source and format.copy_destination and
            depth.depth_stencil_attachment;
    }

    pub fn init(allocator: std.mem.Allocator, device: *vkmtl.Device) !Lighting {
        var compiled_shader = try device.compileRayTracingShader("voxel_world_rt", shader_source, .{
            .intersection_entry = "unused_intersection",
        });
        errdefer compiled_shader.deinit();

        const groups = [_]vkmtl.ray_tracing.RayTracingShaderGroupDescriptor{
            .{ .kind = .ray_generation, .entry_point = "raygen" },
            .{ .kind = .miss, .entry_point = "miss" },
            .{ .kind = .hit, .entry_point = "closest_hit", .hit_group_kind = .triangles },
        };
        var pipeline_descriptor = vkmtl.ray_tracing.RayTracingPipelineDescriptor{
            .label = "voxel ray-traced lighting",
            .shader_groups = groups[0..],
            // The three diffuse segments are sequential TraceRay calls from
            // raygen, not nested calls from a hit shader.
            .max_recursion_depth = 1,
            .bind_group_layout = .{ .entries = &.{
                .{
                    .binding = 3,
                    .resource = .sampled_texture,
                    .visibility = .{ .ray_tracing = true },
                },
                .{
                    .binding = 4,
                    .resource = .sampled_texture,
                    .visibility = .{ .ray_tracing = true },
                },
                .{
                    .binding = 5,
                    .resource = .sampler,
                    .visibility = .{ .ray_tracing = true },
                },
                .{
                    .binding = 6,
                    .resource = .storage_buffer,
                    .visibility = .{ .ray_tracing = true },
                    .storage_access = .read,
                },
                .{
                    .binding = 7,
                    .resource = .sampled_texture,
                    .visibility = .{ .ray_tracing = true },
                },
                .{
                    .binding = 8,
                    .resource = .storage_texture,
                    .visibility = .{ .ray_tracing = true },
                    .storage_access = .write,
                },
            } },
        };
        compiled_shader.applyToPipelineDescriptor(device.selectedBackend(), &pipeline_descriptor);
        // Schema 2 carries an intersection artifact for every RT declaration,
        // but this pipeline uses native triangle intersections.
        pipeline_descriptor.intersection = null;

        var pipeline = try device.makeRayTracingPipelineState(pipeline_descriptor);
        errdefer pipeline.deinit();
        var bind_group_layout = try device.makeBindGroupLayout(pipeline_descriptor.bind_group_layout.?);
        errdefer bind_group_layout.deinit();
        const sbt_descriptor = vkmtl.ray_tracing.ShaderBindingTableDescriptor{
            .stride = @max(device.limits().shader_binding_table_alignment, 64),
            .ray_generation_count = 1,
            .miss_count = 1,
            .hit_count = 1,
        };
        const shader_binding_table = try device.makeShaderBindingTable(sbt_descriptor);
        return .{
            .allocator = allocator,
            .compiled_shader = compiled_shader,
            .pipeline = pipeline,
            .shader_binding_table = shader_binding_table,
            .bind_group_layout = bind_group_layout,
        };
    }

    pub fn deinit(self: *Lighting) void {
        self.invalidateScene();
        self.clearResources();
        if (self.material_columns) |*columns| columns.deinit();
        self.shader_binding_table.deinit();
        self.bind_group_layout.deinit();
        self.pipeline.deinit();
        self.compiled_shader.deinit();
        self.* = undefined;
    }

    pub fn clearResources(self: *Lighting) void {
        if (self.bind_group) |*bind_group| bind_group.deinit();
        self.bind_group = null;
    }

    pub fn setResources(
        self: *Lighting,
        device: *vkmtl.Device,
        gbuffer: *vkmtl.TextureView,
        water_gbuffer: *vkmtl.TextureView,
        water_reflection: *vkmtl.TextureView,
        atlas: *vkmtl.TextureView,
        sampler: *vkmtl.SamplerState,
        center: voxel.ChunkCoord,
        seed: u32,
    ) !void {
        try self.updateMaterialVolume(device, center, seed);
        const material_columns = if (self.material_columns) |*value| value else return error.VoxelRayTracingMaterialVolumeUnavailable;
        const replacement = try device.makeBindGroup(.{
            .label = "voxel PTGI ray resources",
            .layout = &self.bind_group_layout,
            .entries = &.{
                .{ .binding = 3, .resource = .{ .sampled_texture = gbuffer } },
                .{ .binding = 4, .resource = .{ .sampled_texture = atlas } },
                .{ .binding = 5, .resource = .{ .sampler = sampler } },
                .{ .binding = 6, .resource = .{ .storage_buffer = .{
                    .buffer = material_columns,
                    .size = material_column_width * material_column_depth * @sizeOf(MaterialColumn),
                } } },
                .{ .binding = 7, .resource = .{ .sampled_texture = water_gbuffer } },
                .{ .binding = 8, .resource = .{ .storage_texture = water_reflection } },
            },
        });
        self.clearResources();
        self.bind_group = replacement;
    }

    pub fn updateMaterialVolume(
        self: *Lighting,
        device: *vkmtl.Device,
        center: voxel.ChunkCoord,
        seed: u32,
    ) !void {
        if (self.material_center) |current| {
            if (current.x == center.x and current.z == center.z and self.material_columns != null) return;
        }

        const origin_x = (center.x - traced_chunk_radius) * voxel.chunk_width;
        const origin_z = (center.z - traced_chunk_radius) * voxel.chunk_depth;
        const columns = try self.allocator.alloc(MaterialColumn, material_column_width * material_column_depth);
        defer self.allocator.free(columns);
        const terrain = voxel.TerrainSampler{ .seed = seed };
        for (0..material_column_depth) |local_z| {
            for (0..material_column_width) |local_x| {
                const column = terrain.columnAt(
                    origin_x + @as(i32, @intCast(local_x)),
                    origin_z + @as(i32, @intCast(local_z)),
                );
                columns[local_z * material_column_width + local_x] = .{
                    .height = column.height,
                    .surface_and_water = @as(u32, @intFromEnum(column.surface)) |
                        (packMaterialLevel(column.water_level) << 8),
                    .wood_span = packMaterialSpan(column.wood_min, column.wood_max),
                    .leaves_span = packMaterialSpan(column.leaves_min, column.leaves_max),
                };
            }
        }

        if (self.material_columns) |*buffer| {
            try buffer.replaceBytes(0, std.mem.sliceAsBytes(columns));
        } else {
            self.material_columns = try device.makeBuffer(.{
                .label = "voxel RT material columns",
                .bytes = std.mem.sliceAsBytes(columns),
                .usage = .{ .storage = true },
                .storage_mode = .shared,
            });
        }
        self.material_center = center;
        self.material_origin = .{ origin_x, origin_z };
    }

    pub fn invalidateScene(self: *Lighting) void {
        if (self.top_level) |*top_level| top_level.deinit();
        self.top_level = null;
        self.instance_count = 0;
    }

    pub fn rebuild(
        self: *Lighting,
        device: *vkmtl.Device,
        queue: *vkmtl.Queue,
        sources: []const *vkmtl.ray_tracing.AccelerationStructure,
        center: voxel.ChunkCoord,
        radius: i32,
        complete_square: bool,
    ) !?RebuildInfo {
        const traced_bounds = publishedTracedBounds(center, radius, complete_square);
        if (sources.len > maximum_traced_chunks) return error.TooManyVoxelRayTracingChunks;
        if (sources.len == 0) {
            self.invalidateScene();
            return null;
        }

        const descriptor = vkmtl.ray_tracing.AccelerationStructureDescriptor{
            .label = "voxel nearby-chunk TLAS",
            .kind = .top_level,
            .primitive_count = @intCast(sources.len),
        };
        const plan = try vkmtl.ray_tracing.planAccelerationStructureBuild(device.*, .{
            .acceleration_structure = descriptor,
        });
        var top_level = try device.makeAccelerationStructure(descriptor);
        errdefer top_level.deinit();
        var scratch = try device.makeBuffer(.{
            .label = "voxel TLAS scratch",
            .length = @intCast(plan.scratch_size),
            .usage = .{ .acceleration_structure_scratch = true },
            .storage_mode = .private,
        });
        defer scratch.deinit();

        var command_buffer = try queue.makeCommandBuffer();
        try command_buffer.encodeAccelerationStructureBuild(plan, .{
            .result = &top_level,
            .scratch = &scratch,
            .instance_sources = sources,
        });
        try command_buffer.commit();

        self.invalidateScene();
        self.top_level = top_level;
        self.instance_count = sources.len;
        self.traced_origin = traced_bounds.origin;
        self.traced_extent = traced_bounds.extent;
        return .{
            .instance_count = sources.len,
            .result_size = plan.result_size,
            .scratch_size = plan.scratch_size,
        };
    }

    pub fn dispatch(
        self: *Lighting,
        queue: *vkmtl.Queue,
        target: *LightingTarget,
        camera: scene.Camera,
        extent: vkmtl.Extent2D,
        light_direction: scene.Vec3,
        sun_direction: scene.Vec3,
        light_angular_radius: f32,
        light_color: scene.Vec3,
        light_strength: f32,
        daylight: f32,
        night: f32,
        cloud_time_seconds: f32,
        frame_index: u64,
    ) !vkmtl.ray_tracing.RayDispatchPlan {
        const top_level = if (self.top_level) |*value| value else return error.VoxelRayTracingSceneUnavailable;
        const bind_group = if (self.bind_group) |*value| value else return error.VoxelRayTracingResourcesUnavailable;
        const frame_data = makeFrameData(
            camera,
            extent,
            light_direction,
            sun_direction,
            light_angular_radius,
            light_color,
            light_strength,
            daylight,
            night,
            cloud_time_seconds,
            frame_index,
            self.material_origin,
            self.traced_origin,
            self.traced_extent,
        );
        var command_buffer = try queue.makeCommandBuffer();
        const plan = try command_buffer.dispatchRaysToTexture(
            &self.pipeline,
            &self.shader_binding_table,
            .{
                .width = extent.width,
                .height = extent.height,
                .inline_data = std.mem.asBytes(&frame_data),
                .inline_data_binding = 2,
            },
            .{
                .acceleration_structure = top_level,
                .output = &target.view,
                .bind_group = bind_group,
            },
        );
        try command_buffer.commit();
        return plan;
    }

    pub fn lastDispatchSubmittedToDriver(self: *const Lighting) bool {
        return self.shader_binding_table.lastDispatchSubmittedToDriver();
    }
};

pub fn makeFrameData(
    camera: scene.Camera,
    extent: vkmtl.Extent2D,
    light_direction: scene.Vec3,
    sun_direction: scene.Vec3,
    light_angular_radius: f32,
    light_color: scene.Vec3,
    light_strength: f32,
    daylight: f32,
    night: f32,
    cloud_time_seconds: f32,
    frame_index: u64,
    material_origin: [2]i32,
    traced_origin: [2]i32,
    traced_extent: [2]i32,
) FrameData {
    const forward = camera.forward();
    const right = camera.right();
    const up = camera.up();
    const normalized_light_direction = scene.normalize(light_direction);
    const normalized_sun_direction = scene.normalize(sun_direction);
    const safe_cloud_time = if (std.math.isFinite(cloud_time_seconds)) cloud_time_seconds else 0.0;
    const aspect = @as(f32, @floatFromInt(extent.width)) /
        @as(f32, @floatFromInt(@max(extent.height, 1)));
    return .{
        .camera_position_and_tan_half_fov = .{
            camera.position[0],
            camera.position[1],
            camera.position[2],
            @tan(std.math.degreesToRadians(62.0) * 0.5),
        },
        .camera_forward_and_aspect = .{ forward[0], forward[1], forward[2], aspect },
        .camera_right_and_max_distance = .{ right[0], right[1], right[2], 384.0 },
        .camera_up_and_shadow_bias = .{ up[0], up[1], up[2], 0.015 },
        .light_direction_and_strength = .{
            normalized_light_direction[0],
            normalized_light_direction[1],
            normalized_light_direction[2],
            light_strength,
        },
        .light_color_and_daylight = .{ light_color[0], light_color[1], light_color[2], daylight },
        .sky_color_and_night = .{
            std.math.lerp(0.025, 0.42, daylight),
            std.math.lerp(0.04, 0.58, daylight),
            std.math.lerp(0.09, 0.84, daylight),
            night,
        },
        .frame_index_seed_and_light_radius = .{
            @floatFromInt(frame_index & 0x00ff_ffff),
            @floatFromInt(0x564f_584c & 0x00ff_ffff),
            if (std.math.isFinite(light_angular_radius) and light_angular_radius > 0.0)
                @min(light_angular_radius, std.math.pi / 2.0)
            else
                0.0,
            @floatFromInt(diffuse_bounce_count),
        },
        .sun_direction_and_cloud_time = .{
            normalized_sun_direction[0],
            normalized_sun_direction[1],
            normalized_sun_direction[2],
            safe_cloud_time,
        },
        .material_origin_and_extent = .{
            @floatFromInt(material_origin[0]),
            @floatFromInt(material_origin[1]),
            @floatFromInt(material_column_width),
            @floatFromInt(material_column_depth),
        },
        .traced_origin_and_extent = .{
            @floatFromInt(traced_origin[0]),
            @floatFromInt(traced_origin[1]),
            @floatFromInt(traced_extent[0]),
            @floatFromInt(traced_extent[1]),
        },
    };
}

fn packMaterialLevel(level: i32) u32 {
    if (level < 0) return 0xff;
    std.debug.assert(level < 0xff);
    return @intCast(level);
}

fn packMaterialSpan(minimum: i32, maximum: i32) u32 {
    return packMaterialLevel(minimum) | (packMaterialLevel(maximum) << 8);
}

pub fn readLightingStats(
    allocator: std.mem.Allocator,
    device: *vkmtl.Device,
    queue: *vkmtl.Queue,
    target: *LightingTarget,
    extent: vkmtl.Extent2D,
) !LightingStats {
    return readTextureStats(
        LightingStats,
        allocator,
        device,
        queue,
        &target.texture,
        extent,
        "voxel ray-traced lighting readback",
    );
}

pub fn readRadianceStats(
    allocator: std.mem.Allocator,
    device: *vkmtl.Device,
    queue: *vkmtl.Queue,
    texture: *vkmtl.Texture,
    extent: vkmtl.Extent2D,
) !RadianceStats {
    return readTextureStats(
        RadianceStats,
        allocator,
        device,
        queue,
        texture,
        extent,
        "voxel reconstructed radiance readback",
    );
}

pub fn readReflectionStats(
    allocator: std.mem.Allocator,
    device: *vkmtl.Device,
    queue: *vkmtl.Queue,
    texture: *vkmtl.Texture,
    extent: vkmtl.Extent2D,
) !ReflectionStats {
    return readTextureStats(
        ReflectionStats,
        allocator,
        device,
        queue,
        texture,
        extent,
        "voxel water reflection readback",
    );
}

pub fn readVisibilityStats(
    allocator: std.mem.Allocator,
    device: *vkmtl.Device,
    queue: *vkmtl.Queue,
    texture: *vkmtl.Texture,
    extent: vkmtl.Extent2D,
) !VisibilityStats {
    return readTextureStats(
        VisibilityStats,
        allocator,
        device,
        queue,
        texture,
        extent,
        "voxel reconstructed visibility readback",
    );
}

fn readTextureStats(
    comptime Stats: type,
    allocator: std.mem.Allocator,
    device: *vkmtl.Device,
    queue: *vkmtl.Queue,
    texture: *vkmtl.Texture,
    extent: vkmtl.Extent2D,
    label: []const u8,
) !Stats {
    const bytes_per_pixel = @sizeOf([4]f16);
    const tight_bytes_per_row = @as(usize, extent.width) * bytes_per_pixel;
    const row_alignment = @max(
        @as(usize, 1),
        @as(usize, device.limits().buffer_texture_copy_row_pitch_alignment),
    );
    const bytes_per_row = std.mem.alignForward(usize, tight_bytes_per_row, row_alignment);
    const readback_len = bytes_per_row * @as(usize, extent.height);

    var readback = try device.makeBuffer(.{
        .label = label,
        .length = readback_len,
        .usage = .{ .copy_destination = true },
        .storage_mode = .shared,
    });
    defer readback.deinit();

    var command_buffer = try queue.makeCommandBuffer();
    var blit = try command_buffer.makeBlitCommandEncoder();
    try blit.copyTextureToBuffer(texture, &readback, .{
        .source_region = .{ .size = .{
            .width = extent.width,
            .height = extent.height,
        } },
        .destination = .{ .bytes_per_row = bytes_per_row },
    });
    try blit.endEncoding();
    try command_buffer.commit();

    const bytes = try allocator.alloc(u8, readback_len);
    defer allocator.free(bytes);
    try readback.readBytes(0, bytes);

    var stats = Stats{};
    for (0..@as(usize, extent.height)) |y| {
        for (0..@as(usize, extent.width)) |x| {
            const offset = y * bytes_per_row + x * bytes_per_pixel;
            stats.observe(readRgba16(bytes[offset..][0..bytes_per_pixel]));
        }
    }
    return stats;
}

fn readRgba16(bytes: *const [@sizeOf([4]f16)]u8) [4]f32 {
    return .{
        readHalf(bytes[0..2]),
        readHalf(bytes[2..4]),
        readHalf(bytes[4..6]),
        readHalf(bytes[6..8]),
    };
}

fn readHalf(bytes: *const [2]u8) f32 {
    const bits = std.mem.readInt(u16, bytes, .little);
    return @floatCast(@as(f16, @bitCast(bits)));
}

test "RT frame data carries the material volume and cloud contracts" {
    const camera = scene.Camera{};
    const sun_direction = scene.normalize(.{ 0.25, 0.90, -0.10 });
    const data = makeFrameData(
        camera,
        .{ .width = 1280, .height = 720 },
        .{ 0, 1, 0 },
        sun_direction,
        scene.sun_angular_radius,
        .{ 1, 1, 1 },
        1,
        1,
        0,
        37.25,
        7,
        .{ -128, 64 },
        .{ -96, -96 },
        .{ 208, 208 },
    );
    try std.testing.expectEqual(@as(usize, 176), @sizeOf(FrameData));
    try std.testing.expectEqual(@as(usize, 128), @offsetOf(FrameData, "sun_direction_and_cloud_time"));
    try std.testing.expectEqual(@as(usize, 144), @offsetOf(FrameData, "material_origin_and_extent"));
    try std.testing.expectEqual(@as(usize, 160), @offsetOf(FrameData, "traced_origin_and_extent"));
    try std.testing.expectEqual(@as(f32, -128), data.material_origin_and_extent[0]);
    try std.testing.expectEqual(@as(f32, 64), data.material_origin_and_extent[1]);
    try std.testing.expectEqual(@as(f32, @floatFromInt(material_column_width)), data.material_origin_and_extent[2]);
    try std.testing.expectEqual(@as(f32, @floatFromInt(material_column_depth)), data.material_origin_and_extent[3]);
    try std.testing.expectEqualSlices(
        f32,
        &[_]f32{ -96, -96, 208, 208 },
        data.traced_origin_and_extent[0..],
    );
    try std.testing.expectEqual(scene.sun_angular_radius, data.frame_index_seed_and_light_radius[2]);
    try std.testing.expectEqual(
        @as(f32, @floatFromInt(diffuse_bounce_count)),
        data.frame_index_seed_and_light_radius[3],
    );
    try std.testing.expectEqualSlices(f32, camera.position[0..], data.camera_position_and_tan_half_fov[0..3]);
    for (sun_direction, data.sun_direction_and_cloud_time[0..3].*) |expected, actual| {
        try std.testing.expectApproxEqAbs(expected, actual, 0.000001);
    }
    try std.testing.expectEqual(@as(f32, 37.25), data.sun_direction_and_cloud_time[3]);

    const sanitized = makeFrameData(
        camera,
        .{ .width = 1280, .height = 720 },
        .{ 0, 1, 0 },
        sun_direction,
        scene.sun_angular_radius,
        .{ 1, 1, 1 },
        1,
        1,
        0,
        std.math.inf(f32),
        7,
        .{ -128, 64 },
        .{ -96, -96 },
        .{ 208, 208 },
    );
    try std.testing.expectEqual(@as(f32, 0), sanitized.sun_direction_and_cloud_time[3]);
}

test "RT shader sources keep the three-bounce contract aligned" {
    const metal_shader_source = @embedFile("shaders/voxel_world_rt_metal.msl");
    try std.testing.expectEqual(@as(u32, 3), diffuse_bounce_count);
    try std.testing.expect(std.mem.indexOf(
        u8,
        shader_source,
        "maximum_diffuse_bounce_count = 3u",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        metal_shader_source,
        "maximum_diffuse_bounce_count = 3u",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        shader_source,
        "bounce_index < maximum_diffuse_bounce_count",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        metal_shader_source,
        "bounce_index < maximum_diffuse_bounce_count",
    ) != null);
    try std.testing.expect(std.mem.indexOf(u8, shader_source, "throughput *= albedo") != null);
    try std.testing.expect(std.mem.indexOf(u8, metal_shader_source, "throughput *= albedo") != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        shader_source,
        "diffuseMissReachesEnvironment",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        metal_shader_source,
        "diffuse_miss_reaches_environment",
    ) != null);
    try std.testing.expectEqual(@as(i32, 64), voxel.chunk_height);
}

test "traced bounds activate only for a complete profile square" {
    const bounds = publishedTracedBounds(.{ .x = 4, .z = -3 }, 6, true);
    try std.testing.expectEqualSlices(i32, &.{ -32, -144 }, bounds.origin[0..]);
    try std.testing.expectEqualSlices(i32, &.{ 208, 208 }, bounds.extent[0..]);

    const sparse = publishedTracedBounds(.{ .x = 4, .z = -3 }, 6, false);
    try std.testing.expectEqualSlices(i32, &.{ 0, 0 }, sparse.origin[0..]);
    try std.testing.expectEqualSlices(i32, &.{ 0, 0 }, sparse.extent[0..]);
}

test "RT material column packing preserves feature spans and sentinels" {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(MaterialColumn));
    try std.testing.expectEqual(@as(u32, 0xff), packMaterialLevel(-1));
    try std.testing.expectEqual(@as(u32, 12), packMaterialLevel(12));
    try std.testing.expectEqual(@as(u32, 0xff_ff), packMaterialSpan(-1, -1));
    try std.testing.expectEqual(@as(u32, 21 | (25 << 8)), packMaterialSpan(21, 25));
}

test "RT validation requires finite direct and indirect lighting" {
    var stats = LightingStats{};
    stats.observe(.{ 0, 0, 0, -1 });
    stats.observe(.{ 0.25, 0.1, 0.05, 1 });
    stats.observe(.{ 0.01, 0.01, 0.01, 0 });
    try std.testing.expect(stats.hasNativeOcclusion(true));
    try std.testing.expect(stats.hasIndirectRadiance());
    try std.testing.expect(stats.isFiniteAndNonNegative());

    var horizon = LightingStats{};
    horizon.observe(.{ 0.1, 0.1, 0.1, 0 });
    try std.testing.expect(horizon.hasNativeOcclusion(false));
    try std.testing.expect(!horizon.hasNativeOcclusion(true));

    stats.observe(.{ @as(f32, @bitCast(@as(u32, 0x7fc0_0000))), 0, 0, 1 });
    try std.testing.expect(!stats.isFiniteAndNonNegative());
}

test "reconstructed radiance rejects invalid pixels" {
    var stats = RadianceStats{};
    stats.observe(.{ 0.2, 0.3, 0.4, 1 });
    try std.testing.expect(stats.isValid());
    stats.observe(.{ -0.1, 0, 0, 1 });
    try std.testing.expect(!stats.isValid());
}

test "water reflection validation requires a binary covered radiance sample" {
    var stats = ReflectionStats{};
    stats.observe(.{ 0, 0, 0, 0 });
    stats.observe(.{ 0.2, 0.3, 0.4, 1 });
    try std.testing.expect(stats.isValid());
    try std.testing.expectEqual(@as(u64, 1), stats.covered_pixels);
    try std.testing.expectEqual(@as(u64, 1), stats.lit_pixels);

    stats.observe(.{ 0.1, 0.1, 0.1, 0.5 });
    try std.testing.expect(!stats.isValid());
}

test "reconstructed visibility separates umbra penumbra and lit samples" {
    var stats = VisibilityStats{};
    stats.observe(.{ 0, 0, 0, -1 });
    stats.observe(.{ 0, 0, 0, 0 });
    stats.observe(.{ 0, 0, 0, 0.35 });
    stats.observe(.{ 0, 0, 0, 1 });
    try std.testing.expect(stats.isValid());
    try std.testing.expectEqual(@as(u64, 3), stats.surface_pixels);
    try std.testing.expectEqual(@as(u64, 1), stats.fully_shadowed_pixels);
    try std.testing.expectEqual(@as(u64, 1), stats.penumbra_pixels);
    try std.testing.expectEqual(@as(u64, 1), stats.fully_lit_pixels);

    stats.observe(.{ 0, 0, 0, 1.5 });
    try std.testing.expect(!stats.isValid());
}
