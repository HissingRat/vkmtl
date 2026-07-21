const std = @import("std");
const vkmtl = @import("vkmtl");
const ray_tracing = @import("ray_tracing.zig");
const scene = @import("scene.zig");

const shader_source = @embedFile("shaders/voxel_world_ptgi.slang");

pub const TemporalData = extern struct {
    current_camera_position_and_tan_half_fov: [4]f32,
    current_camera_forward_and_aspect: [4]f32,
    current_camera_right_and_reset: [4]f32,
    current_camera_up_and_history_limit: [4]f32,
    previous_camera_position_and_valid: [4]f32,
    previous_view_projection_rows: [4][4]f32,
    filter_mode_and_weights: [4]f32,
};

pub const AtrousData = extern struct {
    step_and_extent: [4]f32,
    filter_parameters: [4]f32,
};

comptime {
    if (@sizeOf(TemporalData) != 160) @compileError("voxel temporal data ABI mismatch");
    if (@sizeOf(AtrousData) != 32) @compileError("voxel atrous data ABI mismatch");
}

const FilterMode = enum(u1) {
    indirect,
    visibility,
};

const visibility_minimum_current_weight: f32 = 0.08;

pub fn terrainLightingReady(ray_tracing_enabled: bool, ptgi_ready: bool) bool {
    return !ray_tracing_enabled or ptgi_ready;
}

pub const SurfaceTarget = struct {
    texture: vkmtl.Texture,
    view: vkmtl.TextureView,
    depth: vkmtl.Texture,
    depth_view: vkmtl.TextureView,

    pub fn init(device: *vkmtl.Device, extent: vkmtl.Extent2D) !SurfaceTarget {
        var texture = try device.makeTexture(.{
            .label = "voxel PTGI surface gbuffer",
            .format = .rgba16_float,
            .width = extent.width,
            .height = extent.height,
            .usage = .{
                .render_attachment = true,
                .shader_read = true,
                .copy_source = true,
            },
            .storage_mode = .private,
        });
        errdefer texture.deinit();
        var view = try texture.makeTextureView(.{});
        errdefer view.deinit();
        var depth = try device.makeTexture(.{
            .label = "voxel PTGI gbuffer depth",
            .format = .depth32_float,
            .width = extent.width,
            .height = extent.height,
            .usage = .{ .render_attachment = true },
            .storage_mode = .private,
        });
        errdefer depth.deinit();
        const depth_view = try depth.makeTextureView(.{});
        return .{
            .texture = texture,
            .view = view,
            .depth = depth,
            .depth_view = depth_view,
        };
    }

    pub fn deinit(self: *SurfaceTarget) void {
        self.depth_view.deinit();
        self.depth.deinit();
        self.view.deinit();
        self.texture.deinit();
        self.* = undefined;
    }
};

const TextureTarget = struct {
    texture: vkmtl.Texture,
    view: vkmtl.TextureView,

    fn init(
        device: *vkmtl.Device,
        extent: vkmtl.Extent2D,
        label: []const u8,
        usage: vkmtl.TextureUsage,
    ) !TextureTarget {
        var texture = try device.makeTexture(.{
            .label = label,
            .format = .rgba16_float,
            .width = extent.width,
            .height = extent.height,
            .usage = usage,
            .storage_mode = .private,
        });
        errdefer texture.deinit();
        const view = try texture.makeTextureView(.{});
        return .{ .texture = texture, .view = view };
    }

    fn deinit(self: *TextureTarget) void {
        self.view.deinit();
        self.texture.deinit();
        self.* = undefined;
    }
};

pub const FrameResources = struct {
    allocator: std.mem.Allocator,
    extent: vkmtl.Extent2D,
    surface: SurfaceTarget,
    previous_surface: TextureTarget,
    raw: ray_tracing.LightingTarget,
    history: [2]TextureTarget,
    visibility_history: [2]TextureTarget,
    scratch: [2]TextureTarget,
    compiled_temporal: vkmtl.shader.CompiledComputeShader,
    compiled_atrous: vkmtl.shader.CompiledComputeShader,
    temporal_layout: vkmtl.binding.BindGroupLayout,
    atrous_layout: vkmtl.binding.BindGroupLayout,
    temporal_pipeline: vkmtl.ComputePipelineState,
    atrous_pipeline: vkmtl.ComputePipelineState,
    temporal_uniform_buffer: vkmtl.Buffer,
    atrous_uniform_buffer: vkmtl.Buffer,
    sampler: vkmtl.SamplerState,
    groups: ?Groups = null,
    next_history_index: usize = 0,
    history_valid: bool = false,
    previous_camera: scene.Camera = .{},
    previous_view_projection: [4][4]f32 = identityMatrix(),
    previous_light_direction: scene.Vec3 = .{ 0, 1, 0 },
    previous_light_angular_radius: f32 = scene.sun_angular_radius,
    previous_light_color: scene.Vec3 = .{ 0, 0, 0 },
    previous_light_strength: f32 = 0,

    const Groups = struct {
        temporal: [2]vkmtl.binding.BindGroup,
        visibility_temporal: [2]vkmtl.binding.BindGroup,
        atrous_initial: [2]vkmtl.binding.BindGroup,
        visibility_atrous_initial: [2]vkmtl.binding.BindGroup,
        atrous_forward: vkmtl.binding.BindGroup,
        atrous_backward: vkmtl.binding.BindGroup,

        fn deinit(self: *Groups) void {
            for (&self.visibility_atrous_initial) |*group| group.deinit();
            self.atrous_backward.deinit();
            self.atrous_forward.deinit();
            for (&self.atrous_initial) |*group| group.deinit();
            for (&self.visibility_temporal) |*group| group.deinit();
            for (&self.temporal) |*group| group.deinit();
        }
    };

    pub fn init(
        allocator: std.mem.Allocator,
        device: *vkmtl.Device,
        extent: vkmtl.Extent2D,
    ) !FrameResources {
        var surface = try SurfaceTarget.init(device, extent);
        errdefer surface.deinit();
        var previous_surface = try TextureTarget.init(device, extent, "voxel PTGI previous gbuffer", .{
            .shader_read = true,
            .copy_destination = true,
        });
        errdefer previous_surface.deinit();
        var raw = try ray_tracing.LightingTarget.init(device, extent);
        errdefer raw.deinit();

        var history: [2]TextureTarget = undefined;
        history[0] = try makeStorageTarget(device, extent, "voxel PTGI history 0");
        errdefer history[0].deinit();
        history[1] = try makeStorageTarget(device, extent, "voxel PTGI history 1");
        errdefer history[1].deinit();
        var visibility_history: [2]TextureTarget = undefined;
        visibility_history[0] = try makeStorageTarget(device, extent, "voxel PTGI visibility history 0");
        errdefer visibility_history[0].deinit();
        visibility_history[1] = try makeStorageTarget(device, extent, "voxel PTGI visibility history 1");
        errdefer visibility_history[1].deinit();
        var scratch: [2]TextureTarget = undefined;
        scratch[0] = try makeStorageTarget(device, extent, "voxel PTGI atrous 0");
        errdefer scratch[0].deinit();
        scratch[1] = try makeStorageTarget(device, extent, "voxel PTGI atrous 1");
        errdefer scratch[1].deinit();

        var compiled_temporal = try device.compileComputeShader("voxel_world_ptgi_temporal", shader_source, .{
            .entry = "temporal_cs",
        });
        errdefer compiled_temporal.deinit();
        const temporal_stage = compiled_temporal.stageDescriptor(device.selectedBackend());
        var temporal_layouts = try vkmtl.shader.Reflection.deriveComputePipelineBindGroupLayouts(
            allocator,
            temporal_stage,
        );
        defer temporal_layouts.deinit();
        if (temporal_layouts.descriptors().len != 1) return error.UnexpectedVoxelTemporalLayout;
        var temporal_layout = try device.makeBindGroupLayout(temporal_layouts.descriptors()[0]);
        errdefer temporal_layout.deinit();
        var temporal_pipeline = try device.makeComputePipelineState(.{
            .label = "voxel PTGI temporal accumulation",
            .compute = temporal_stage,
            .bind_group_layouts = &.{temporal_layout.descriptor()},
        });
        errdefer temporal_pipeline.deinit();

        var compiled_atrous = try device.compileComputeShader("voxel_world_ptgi_atrous", shader_source, .{
            .entry = "atrous_cs",
        });
        errdefer compiled_atrous.deinit();
        const atrous_stage = compiled_atrous.stageDescriptor(device.selectedBackend());
        var atrous_layouts = try vkmtl.shader.Reflection.deriveComputePipelineBindGroupLayouts(
            allocator,
            atrous_stage,
        );
        defer atrous_layouts.deinit();
        if (atrous_layouts.descriptors().len != 1) return error.UnexpectedVoxelAtrousLayout;
        var atrous_layout = try device.makeBindGroupLayout(atrous_layouts.descriptors()[0]);
        errdefer atrous_layout.deinit();
        var atrous_pipeline = try device.makeComputePipelineState(.{
            .label = "voxel PTGI atrous denoiser",
            .compute = atrous_stage,
            .bind_group_layouts = &.{atrous_layout.descriptor()},
        });
        errdefer atrous_pipeline.deinit();

        var temporal_data = std.mem.zeroes(TemporalData);
        var temporal_uniform_buffer = try device.makeBuffer(.{
            .label = "voxel PTGI temporal uniforms",
            .bytes = std.mem.asBytes(&temporal_data),
            .usage = .{ .uniform = true },
            .storage_mode = .shared,
        });
        errdefer temporal_uniform_buffer.deinit();
        var atrous_data = AtrousData{
            .step_and_extent = .{ 1, @floatFromInt(extent.width), @floatFromInt(extent.height), 0 },
            .filter_parameters = .{ 32, 0.035, 0.45, 0 },
        };
        var atrous_uniform_buffer = try device.makeBuffer(.{
            .label = "voxel PTGI atrous uniforms",
            .bytes = std.mem.asBytes(&atrous_data),
            .usage = .{ .uniform = true },
            .storage_mode = .shared,
        });
        errdefer atrous_uniform_buffer.deinit();
        var sampler = try device.makeSamplerState(.{
            .min_filter = .linear,
            .mag_filter = .linear,
        });
        errdefer sampler.deinit();

        return .{
            .allocator = allocator,
            .extent = extent,
            .surface = surface,
            .previous_surface = previous_surface,
            .raw = raw,
            .history = history,
            .visibility_history = visibility_history,
            .scratch = scratch,
            .compiled_temporal = compiled_temporal,
            .compiled_atrous = compiled_atrous,
            .temporal_layout = temporal_layout,
            .atrous_layout = atrous_layout,
            .temporal_pipeline = temporal_pipeline,
            .atrous_pipeline = atrous_pipeline,
            .temporal_uniform_buffer = temporal_uniform_buffer,
            .atrous_uniform_buffer = atrous_uniform_buffer,
            .sampler = sampler,
        };
    }

    pub fn prepare(self: *FrameResources, device: *vkmtl.Device) !void {
        if (self.groups != null) return;
        var temporal: [2]vkmtl.binding.BindGroup = undefined;
        temporal[0] = try makeTemporalGroup(
            device,
            &self.temporal_layout,
            &self.temporal_uniform_buffer,
            &self.raw.view,
            &self.surface.view,
            &self.history[1].view,
            &self.previous_surface.view,
            &self.sampler,
            &self.history[0].view,
        );
        errdefer temporal[0].deinit();
        temporal[1] = try makeTemporalGroup(
            device,
            &self.temporal_layout,
            &self.temporal_uniform_buffer,
            &self.raw.view,
            &self.surface.view,
            &self.history[0].view,
            &self.previous_surface.view,
            &self.sampler,
            &self.history[1].view,
        );
        errdefer temporal[1].deinit();

        var visibility_temporal: [2]vkmtl.binding.BindGroup = undefined;
        visibility_temporal[0] = try makeTemporalGroup(
            device,
            &self.temporal_layout,
            &self.temporal_uniform_buffer,
            &self.raw.view,
            &self.surface.view,
            &self.visibility_history[1].view,
            &self.previous_surface.view,
            &self.sampler,
            &self.visibility_history[0].view,
        );
        errdefer visibility_temporal[0].deinit();
        visibility_temporal[1] = try makeTemporalGroup(
            device,
            &self.temporal_layout,
            &self.temporal_uniform_buffer,
            &self.raw.view,
            &self.surface.view,
            &self.visibility_history[0].view,
            &self.previous_surface.view,
            &self.sampler,
            &self.visibility_history[1].view,
        );
        errdefer visibility_temporal[1].deinit();

        var atrous_initial: [2]vkmtl.binding.BindGroup = undefined;
        atrous_initial[0] = try makeAtrousGroup(
            device,
            &self.atrous_layout,
            &self.atrous_uniform_buffer,
            &self.history[0].view,
            &self.surface.view,
            &self.scratch[0].view,
        );
        errdefer atrous_initial[0].deinit();
        atrous_initial[1] = try makeAtrousGroup(
            device,
            &self.atrous_layout,
            &self.atrous_uniform_buffer,
            &self.history[1].view,
            &self.surface.view,
            &self.scratch[0].view,
        );
        errdefer atrous_initial[1].deinit();
        var atrous_forward = try makeAtrousGroup(
            device,
            &self.atrous_layout,
            &self.atrous_uniform_buffer,
            &self.scratch[0].view,
            &self.surface.view,
            &self.scratch[1].view,
        );
        errdefer atrous_forward.deinit();
        var atrous_backward = try makeAtrousGroup(
            device,
            &self.atrous_layout,
            &self.atrous_uniform_buffer,
            &self.scratch[1].view,
            &self.surface.view,
            &self.scratch[0].view,
        );
        errdefer atrous_backward.deinit();

        var visibility_atrous_initial: [2]vkmtl.binding.BindGroup = undefined;
        visibility_atrous_initial[0] = try makeAtrousGroup(
            device,
            &self.atrous_layout,
            &self.atrous_uniform_buffer,
            &self.visibility_history[0].view,
            &self.surface.view,
            &self.scratch[0].view,
        );
        errdefer visibility_atrous_initial[0].deinit();
        visibility_atrous_initial[1] = try makeAtrousGroup(
            device,
            &self.atrous_layout,
            &self.atrous_uniform_buffer,
            &self.visibility_history[1].view,
            &self.surface.view,
            &self.scratch[0].view,
        );
        errdefer visibility_atrous_initial[1].deinit();
        self.groups = .{
            .temporal = temporal,
            .visibility_temporal = visibility_temporal,
            .atrous_initial = atrous_initial,
            .visibility_atrous_initial = visibility_atrous_initial,
            .atrous_forward = atrous_forward,
            .atrous_backward = atrous_backward,
        };
    }

    pub fn deinit(self: *FrameResources) void {
        if (self.groups) |*groups| groups.deinit();
        self.sampler.deinit();
        self.atrous_uniform_buffer.deinit();
        self.temporal_uniform_buffer.deinit();
        self.atrous_pipeline.deinit();
        self.temporal_pipeline.deinit();
        self.atrous_layout.deinit();
        self.temporal_layout.deinit();
        self.compiled_atrous.deinit();
        self.compiled_temporal.deinit();
        for (&self.scratch) |*target| target.deinit();
        for (&self.visibility_history) |*target| target.deinit();
        for (&self.history) |*target| target.deinit();
        self.raw.deinit();
        self.previous_surface.deinit();
        self.surface.deinit();
        self.* = undefined;
    }

    pub fn filteredView(self: *FrameResources) *vkmtl.TextureView {
        return &self.scratch[1].view;
    }

    pub fn filteredTexture(self: *FrameResources) *vkmtl.Texture {
        return &self.scratch[1].texture;
    }

    pub fn filteredVisibilityView(self: *FrameResources) *vkmtl.TextureView {
        return &self.scratch[0].view;
    }

    pub fn filteredVisibilityTexture(self: *FrameResources) *vkmtl.Texture {
        return &self.scratch[0].texture;
    }

    pub fn dispatch(
        self: *FrameResources,
        queue: *vkmtl.Queue,
        camera: scene.Camera,
        celestial: scene.CelestialState,
        reset_history: bool,
    ) !void {
        const history_index = self.next_history_index;
        const groups = if (self.groups) |*value| value else return error.VoxelPtgiResourcesNotPrepared;
        const light_change = if (self.history_valid)
            lightHistoryChange(
                self.previous_light_direction,
                self.previous_light_angular_radius,
                self.previous_light_color,
                self.previous_light_strength,
                celestial,
            )
        else
            LightHistoryChange{ .reset = true, .history_limit = 1 };
        const camera_cut = self.history_valid and cameraHistoryDiscontinuous(
            self.previous_camera,
            camera,
        );
        const reset = reset_history or !self.history_valid or light_change.reset or camera_cut;
        var temporal_data = makeTemporalData(
            camera,
            self.previous_camera,
            self.previous_view_projection,
            self.extent,
            reset,
            self.history_valid,
            light_change.history_limit,
            .indirect,
        );
        try self.temporal_uniform_buffer.replaceBytes(0, std.mem.asBytes(&temporal_data));
        try dispatchCompute(
            queue,
            &self.temporal_pipeline,
            &groups.temporal[history_index],
            self.extent,
        );

        const steps = [_]f32{ 1, 2, 4, 8 };
        const atrous_groups = [_]*vkmtl.binding.BindGroup{
            &groups.atrous_initial[history_index],
            &groups.atrous_forward,
            &groups.atrous_backward,
            &groups.atrous_forward,
        };
        for (steps, atrous_groups) |step, group| {
            const atrous_data = makeAtrousData(self.extent, step, .indirect);
            try self.atrous_uniform_buffer.replaceBytes(0, std.mem.asBytes(&atrous_data));
            try dispatchCompute(queue, &self.atrous_pipeline, group, self.extent);
        }

        temporal_data.filter_mode_and_weights[0] = filterModeValue(.visibility);
        try self.temporal_uniform_buffer.replaceBytes(0, std.mem.asBytes(&temporal_data));
        try dispatchCompute(
            queue,
            &self.temporal_pipeline,
            &groups.visibility_temporal[history_index],
            self.extent,
        );

        const visibility_atrous_data = makeAtrousData(self.extent, 1, .visibility);
        try self.atrous_uniform_buffer.replaceBytes(0, std.mem.asBytes(&visibility_atrous_data));
        try dispatchCompute(
            queue,
            &self.atrous_pipeline,
            &groups.visibility_atrous_initial[history_index],
            self.extent,
        );

        var copy_commands = try queue.makeCommandBuffer();
        var blit = try copy_commands.makeBlitCommandEncoder();
        try blit.copyTextureToTexture(&self.surface.texture, &self.previous_surface.texture, .{
            .source_region = .{ .size = .{
                .width = self.extent.width,
                .height = self.extent.height,
            } },
        });
        try blit.endEncoding();
        try copy_commands.commit();

        self.previous_camera = camera;
        const aspect = @as(f32, @floatFromInt(self.extent.width)) /
            @as(f32, @floatFromInt(@max(self.extent.height, 1)));
        self.previous_view_projection = camera.viewProjection(aspect);
        self.previous_light_direction = celestial.light_direction;
        self.previous_light_angular_radius = celestial.light_angular_radius;
        self.previous_light_color = celestial.light_color;
        self.previous_light_strength = celestial.strength;
        self.history_valid = true;
        self.next_history_index = 1 - history_index;
    }
};

fn makeStorageTarget(
    device: *vkmtl.Device,
    extent: vkmtl.Extent2D,
    label: []const u8,
) !TextureTarget {
    return TextureTarget.init(device, extent, label, .{
        .shader_read = true,
        .shader_write = true,
        .copy_source = true,
    });
}

fn makeTemporalGroup(
    device: *vkmtl.Device,
    layout: *vkmtl.binding.BindGroupLayout,
    uniform_buffer: *vkmtl.Buffer,
    current: *vkmtl.TextureView,
    gbuffer: *vkmtl.TextureView,
    previous: *vkmtl.TextureView,
    previous_gbuffer: *vkmtl.TextureView,
    sampler: *vkmtl.SamplerState,
    output: *vkmtl.TextureView,
) !vkmtl.binding.BindGroup {
    return device.makeBindGroup(.{
        .layout = layout,
        .entries = &.{
            .{ .binding = 0, .resource = .{ .uniform_buffer = .{
                .buffer = uniform_buffer,
                .size = @sizeOf(TemporalData),
            } } },
            .{ .binding = 1, .resource = .{ .sampled_texture = current } },
            .{ .binding = 2, .resource = .{ .sampled_texture = gbuffer } },
            .{ .binding = 3, .resource = .{ .sampled_texture = previous } },
            .{ .binding = 4, .resource = .{ .sampled_texture = previous_gbuffer } },
            .{ .binding = 5, .resource = .{ .sampler = sampler } },
            .{ .binding = 6, .resource = .{ .storage_texture = output } },
        },
    });
}

fn makeAtrousGroup(
    device: *vkmtl.Device,
    layout: *vkmtl.binding.BindGroupLayout,
    uniform_buffer: *vkmtl.Buffer,
    input: *vkmtl.TextureView,
    gbuffer: *vkmtl.TextureView,
    output: *vkmtl.TextureView,
) !vkmtl.binding.BindGroup {
    return device.makeBindGroup(.{
        .layout = layout,
        .entries = &.{
            .{ .binding = 7, .resource = .{ .uniform_buffer = .{
                .buffer = uniform_buffer,
                .size = @sizeOf(AtrousData),
            } } },
            .{ .binding = 8, .resource = .{ .sampled_texture = input } },
            .{ .binding = 9, .resource = .{ .sampled_texture = gbuffer } },
            .{ .binding = 11, .resource = .{ .storage_texture = output } },
        },
    });
}

fn dispatchCompute(
    queue: *vkmtl.Queue,
    pipeline: *vkmtl.ComputePipelineState,
    bind_group: *vkmtl.binding.BindGroup,
    extent: vkmtl.Extent2D,
) !void {
    var commands = try queue.makeCommandBuffer();
    var encoder = try commands.makeComputeCommandEncoder();
    try encoder.setComputePipelineState(pipeline);
    try encoder.setBindGroup(bind_group, .{ .index = 0 });
    try encoder.dispatchThreadgroups(.{
        .threadgroup_count_x = (extent.width + 7) / 8,
        .threadgroup_count_y = (extent.height + 7) / 8,
        .threads_per_threadgroup_x = 8,
        .threads_per_threadgroup_y = 8,
    });
    try encoder.endEncoding();
    try commands.commit();
}

fn makeTemporalData(
    current: scene.Camera,
    previous: scene.Camera,
    previous_view_projection: [4][4]f32,
    extent: vkmtl.Extent2D,
    reset: bool,
    previous_valid: bool,
    history_limit: f32,
    filter_mode: FilterMode,
) TemporalData {
    const forward = current.forward();
    const right = current.right();
    const up = current.up();
    const aspect = @as(f32, @floatFromInt(extent.width)) /
        @as(f32, @floatFromInt(@max(extent.height, 1)));
    return .{
        .current_camera_position_and_tan_half_fov = .{
            current.position[0],
            current.position[1],
            current.position[2],
            @tan(std.math.degreesToRadians(62.0) * 0.5),
        },
        .current_camera_forward_and_aspect = .{ forward[0], forward[1], forward[2], aspect },
        .current_camera_right_and_reset = .{ right[0], right[1], right[2], @floatFromInt(@intFromBool(reset)) },
        .current_camera_up_and_history_limit = .{ up[0], up[1], up[2], history_limit },
        .previous_camera_position_and_valid = .{
            previous.position[0],
            previous.position[1],
            previous.position[2],
            @floatFromInt(@intFromBool(previous_valid)),
        },
        .previous_view_projection_rows = previous_view_projection,
        .filter_mode_and_weights = .{
            filterModeValue(filter_mode),
            visibility_minimum_current_weight,
            0,
            0,
        },
    };
}

fn makeAtrousData(extent: vkmtl.Extent2D, step: f32, filter_mode: FilterMode) AtrousData {
    return .{
        .step_and_extent = .{
            step,
            @floatFromInt(extent.width),
            @floatFromInt(extent.height),
            filterModeValue(filter_mode),
        },
        .filter_parameters = .{ 32, 0.035, 0.45, 0 },
    };
}

fn filterModeValue(filter_mode: FilterMode) f32 {
    return @floatFromInt(@intFromEnum(filter_mode));
}

const LightHistoryChange = struct {
    reset: bool,
    history_limit: f32,
};

fn lightHistoryChange(
    previous_direction: scene.Vec3,
    previous_angular_radius: f32,
    previous_color: scene.Vec3,
    previous_strength: f32,
    current: scene.CelestialState,
) LightHistoryChange {
    const alignment = std.math.clamp(scene.dot(previous_direction, current.light_direction), -1.0, 1.0);
    const active_strength = @max(previous_strength, current.strength);
    const direction_change = (1.0 - alignment) * active_strength;
    const strength_change = @abs(previous_strength - current.strength);
    const radius_scale = @max(@max(previous_angular_radius, current.light_angular_radius), 0.001);
    const radius_change = @abs(previous_angular_radius - current.light_angular_radius) /
        radius_scale * active_strength;
    const color_delta = scene.length(scene.sub(previous_color, current.light_color));
    const weighted_change = direction_change + radius_change * 0.25 +
        strength_change * 0.45 + color_delta * 0.18;
    return .{
        .reset = weighted_change > 0.20,
        .history_limit = std.math.clamp(24.0 / (1.0 + weighted_change * 96.0), 4.0, 24.0),
    };
}

fn cameraHistoryDiscontinuous(previous: scene.Camera, current: scene.Camera) bool {
    const translation = scene.length(scene.sub(current.position, previous.position));
    const facing_alignment = std.math.clamp(
        scene.dot(previous.forward(), current.forward()),
        -1.0,
        1.0,
    );
    return !std.math.isFinite(translation) or
        !std.math.isFinite(facing_alignment) or
        translation > 4.0 or
        facing_alignment < 0.90;
}

fn identityMatrix() [4][4]f32 {
    return .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
}

test "terrain lighting waits for the first PTGI producer in RT mode" {
    try std.testing.expect(terrainLightingReady(false, false));
    try std.testing.expect(terrainLightingReady(false, true));
    try std.testing.expect(!terrainLightingReady(true, false));
    try std.testing.expect(terrainLightingReady(true, true));
}

test "temporal history adapts to celestial motion" {
    const stable = scene.celestialState(scene.day_cycle_seconds * 0.5);
    const unchanged = lightHistoryChange(
        stable.light_direction,
        stable.light_angular_radius,
        stable.light_color,
        stable.strength,
        stable,
    );
    try std.testing.expect(!unchanged.reset);
    try std.testing.expectEqual(@as(f32, 24), unchanged.history_limit);

    var discontinuity = stable;
    discontinuity.light_direction = scene.scale(stable.light_direction, -1);
    const changed = lightHistoryChange(
        stable.light_direction,
        stable.light_angular_radius,
        stable.light_color,
        stable.strength,
        discontinuity,
    );
    try std.testing.expect(changed.reset);
    try std.testing.expect(changed.history_limit <= 4.01);
}

test "temporal history detects camera cuts without rejecting ordinary motion" {
    const previous = scene.Camera{};
    var current = previous;
    current.position[0] += 0.25;
    current.yaw += 0.02;
    try std.testing.expect(!cameraHistoryDiscontinuous(previous, current));

    current = previous;
    current.position[0] += 8;
    try std.testing.expect(cameraHistoryDiscontinuous(previous, current));

    current = previous;
    current.yaw += std.math.pi * 0.5;
    try std.testing.expect(cameraHistoryDiscontinuous(previous, current));
}

test "PTGI filter uniforms keep indirect and visibility modes independent" {
    const camera = scene.Camera{};
    const extent = vkmtl.Extent2D{ .width = 640, .height = 360 };
    const indirect = makeTemporalData(
        camera,
        camera,
        identityMatrix(),
        extent,
        false,
        true,
        24,
        .indirect,
    );
    const visibility = makeTemporalData(
        camera,
        camera,
        identityMatrix(),
        extent,
        false,
        true,
        24,
        .visibility,
    );

    try std.testing.expectEqual(@as(f32, 0), indirect.filter_mode_and_weights[0]);
    try std.testing.expectEqual(@as(f32, 1), visibility.filter_mode_and_weights[0]);
    try std.testing.expectEqual(
        visibility_minimum_current_weight,
        visibility.filter_mode_and_weights[1],
    );

    const indirect_atrous = makeAtrousData(extent, 8, .indirect);
    const visibility_atrous = makeAtrousData(extent, 1, .visibility);
    try std.testing.expectEqual(@as(f32, 0), indirect_atrous.step_and_extent[3]);
    try std.testing.expectEqual(@as(f32, 1), visibility_atrous.step_and_extent[3]);
}
