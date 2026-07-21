const std = @import("std");
const vkmtl = @import("vkmtl");

pub const shader_name = "voxel_world_present";
pub const shader_source = @embedFile("shaders/voxel_world_present.slang");

const PresentationData = extern struct {
    manual_output_transfer_and_padding: [4]f32,
};

comptime {
    if (@sizeOf(PresentationData) != 16) @compileError("voxel presentation data ABI mismatch");
}

pub const Renderer = struct {
    extent: vkmtl.Extent2D,
    hdr_texture: vkmtl.Texture,
    hdr_view: vkmtl.TextureView,
    depth_texture: vkmtl.Texture,
    depth_view: vkmtl.TextureView,
    opaque_surface_texture: vkmtl.Texture,
    opaque_surface_view: vkmtl.TextureView,
    opaque_surface_depth_texture: vkmtl.Texture,
    opaque_surface_depth_view: vkmtl.TextureView,
    water_surface_texture: vkmtl.Texture,
    water_surface_view: vkmtl.TextureView,
    water_reflection_texture: vkmtl.Texture,
    water_reflection_view: vkmtl.TextureView,
    water_overlay_texture: vkmtl.Texture,
    water_overlay_view: vkmtl.TextureView,
    compiled_shader: vkmtl.shader.CompiledRenderShader,
    bind_group_layout: vkmtl.binding.BindGroupLayout,
    bind_group: ?vkmtl.binding.BindGroup = null,
    presentation_buffer: vkmtl.Buffer,
    sampler: vkmtl.SamplerState,
    pipeline: vkmtl.RenderPipelineState,

    pub fn isUsable(device: *const vkmtl.Device) bool {
        const features = device.features();
        const limits = device.limits();
        const hdr = device.getFormatCaps(.rgba16_float);
        const depth = device.getFormatCaps(.depth32_float);
        return features.blend_state and features.independent_blend and
            limits.max_color_attachments >= 3 and
            hdr.sampled and hdr.filterable and hdr.linear_filter and
            hdr.color_attachment and
            depth.depth_stencil_attachment;
    }

    pub fn init(
        allocator: std.mem.Allocator,
        device: *vkmtl.Device,
        extent: vkmtl.Extent2D,
        presentation_format: vkmtl.TextureFormat,
        enable_rt_reflection: bool,
    ) !Renderer {
        var hdr_texture = try device.makeTexture(.{
            .label = "voxel linear HDR scene",
            .format = .rgba16_float,
            .width = extent.width,
            .height = extent.height,
            .usage = .{
                .render_attachment = true,
                .shader_read = true,
            },
            .storage_mode = .private,
        });
        errdefer hdr_texture.deinit();
        var hdr_view = try hdr_texture.makeTextureView(.{});
        errdefer hdr_view.deinit();
        var depth_texture = try device.makeTexture(.{
            .label = "voxel HDR scene depth",
            .format = .depth32_float,
            .width = extent.width,
            .height = extent.height,
            .usage = .{ .render_attachment = true },
            .storage_mode = .private,
        });
        errdefer depth_texture.deinit();
        var depth_view = try depth_texture.makeTextureView(.{});
        errdefer depth_view.deinit();
        var opaque_surface_texture = try device.makeTexture(.{
            .label = "voxel opaque surface",
            .format = .rgba16_float,
            .width = extent.width,
            .height = extent.height,
            .usage = .{
                .render_attachment = true,
                .shader_read = true,
            },
            .storage_mode = .private,
        });
        errdefer opaque_surface_texture.deinit();
        var opaque_surface_view = try opaque_surface_texture.makeTextureView(.{});
        errdefer opaque_surface_view.deinit();
        var opaque_surface_depth_texture = try device.makeTexture(.{
            .label = "voxel opaque surface depth",
            .format = .depth32_float,
            .width = extent.width,
            .height = extent.height,
            .usage = .{ .render_attachment = true },
            .storage_mode = .private,
        });
        errdefer opaque_surface_depth_texture.deinit();
        var opaque_surface_depth_view = try opaque_surface_depth_texture.makeTextureView(.{});
        errdefer opaque_surface_depth_view.deinit();
        var water_surface_texture = try device.makeTexture(.{
            .label = "voxel water surface",
            .format = .rgba16_float,
            .width = extent.width,
            .height = extent.height,
            .usage = .{
                .render_attachment = true,
                .shader_read = true,
            },
            .storage_mode = .private,
        });
        errdefer water_surface_texture.deinit();
        var water_surface_view = try water_surface_texture.makeTextureView(.{});
        errdefer water_surface_view.deinit();
        var water_reflection_texture = try device.makeTexture(.{
            .label = "voxel water reflection",
            .format = .rgba16_float,
            .width = extent.width,
            .height = extent.height,
            .usage = .{
                .render_attachment = true,
                .shader_read = true,
                .shader_write = enable_rt_reflection,
                .copy_source = enable_rt_reflection,
            },
            .storage_mode = .private,
        });
        errdefer water_reflection_texture.deinit();
        var water_reflection_view = try water_reflection_texture.makeTextureView(.{});
        errdefer water_reflection_view.deinit();
        var water_overlay_texture = try device.makeTexture(.{
            .label = "voxel water overlay",
            .format = .rgba16_float,
            .width = extent.width,
            .height = extent.height,
            .usage = .{
                .render_attachment = true,
                .shader_read = true,
            },
            .storage_mode = .private,
        });
        errdefer water_overlay_texture.deinit();
        var water_overlay_view = try water_overlay_texture.makeTextureView(.{});
        errdefer water_overlay_view.deinit();
        var sampler = try device.makeSamplerState(.{
            .min_filter = .linear,
            .mag_filter = .linear,
        });
        errdefer sampler.deinit();
        var presentation_data = PresentationData{
            .manual_output_transfer_and_padding = .{
                @floatFromInt(@intFromBool(!vkmtl.resource.isSrgbFormat(presentation_format))),
                0,
                0,
                0,
            },
        };
        var presentation_buffer = try device.makeBuffer(.{
            .label = "voxel presentation transfer metadata",
            .bytes = std.mem.asBytes(&presentation_data),
            .usage = .{ .uniform = true },
            .storage_mode = .shared,
        });
        errdefer presentation_buffer.deinit();
        var compiled_shader = try device.compileRenderShader(shader_name, shader_source, .{
            .vertex_entry = "present_vs",
            .fragment_entry = "present_fs",
        });
        errdefer compiled_shader.deinit();
        const stages = compiled_shader.stageDescriptors(device.selectedBackend());
        var layouts = try vkmtl.shader.Reflection.deriveRenderPipelineBindGroupLayouts(
            allocator,
            stages.vertex,
            stages.fragment,
        );
        defer layouts.deinit();
        if (layouts.descriptors().len != 1) return error.UnexpectedVoxelPresentLayout;
        var bind_group_layout = try device.makeBindGroupLayout(layouts.descriptors()[0]);
        errdefer bind_group_layout.deinit();
        const pipeline = try device.makeRenderPipelineState(.{
            .label = "voxel SEUS-inspired presentation",
            .vertex = stages.vertex,
            .fragment = stages.fragment,
            .bind_group_layouts = &.{bind_group_layout.descriptor()},
            .primitive_topology = .triangle,
            .color_attachments = &.{.{ .format = presentation_format }},
        });
        return .{
            .extent = extent,
            .hdr_texture = hdr_texture,
            .hdr_view = hdr_view,
            .depth_texture = depth_texture,
            .depth_view = depth_view,
            .opaque_surface_texture = opaque_surface_texture,
            .opaque_surface_view = opaque_surface_view,
            .opaque_surface_depth_texture = opaque_surface_depth_texture,
            .opaque_surface_depth_view = opaque_surface_depth_view,
            .water_surface_texture = water_surface_texture,
            .water_surface_view = water_surface_view,
            .water_reflection_texture = water_reflection_texture,
            .water_reflection_view = water_reflection_view,
            .water_overlay_texture = water_overlay_texture,
            .water_overlay_view = water_overlay_view,
            .compiled_shader = compiled_shader,
            .bind_group_layout = bind_group_layout,
            .presentation_buffer = presentation_buffer,
            .sampler = sampler,
            .pipeline = pipeline,
        };
    }

    pub fn prepare(self: *Renderer, device: *vkmtl.Device) !void {
        if (self.bind_group != null) return;
        self.bind_group = try device.makeBindGroup(.{
            .label = "voxel HDR presentation resources",
            .layout = &self.bind_group_layout,
            .entries = &.{
                .{ .binding = 0, .resource = .{ .sampled_texture = &self.hdr_view } },
                .{ .binding = 1, .resource = .{ .sampler = &self.sampler } },
                .{ .binding = 2, .resource = .{ .uniform_buffer = .{
                    .buffer = &self.presentation_buffer,
                    .size = @sizeOf(PresentationData),
                } } },
                .{ .binding = 3, .resource = .{ .sampled_texture = &self.water_overlay_view } },
            },
        });
    }

    pub fn deinit(self: *Renderer) void {
        self.pipeline.deinit();
        if (self.bind_group) |*bind_group| bind_group.deinit();
        self.bind_group_layout.deinit();
        self.compiled_shader.deinit();
        self.presentation_buffer.deinit();
        self.sampler.deinit();
        self.water_overlay_view.deinit();
        self.water_overlay_texture.deinit();
        self.water_reflection_view.deinit();
        self.water_reflection_texture.deinit();
        self.water_surface_view.deinit();
        self.water_surface_texture.deinit();
        self.opaque_surface_depth_view.deinit();
        self.opaque_surface_depth_texture.deinit();
        self.opaque_surface_view.deinit();
        self.opaque_surface_texture.deinit();
        self.depth_view.deinit();
        self.depth_texture.deinit();
        self.hdr_view.deinit();
        self.hdr_texture.deinit();
        self.* = undefined;
    }

    pub fn hdrView(self: *Renderer) *vkmtl.TextureView {
        return &self.hdr_view;
    }

    pub fn depthView(self: *Renderer) *vkmtl.TextureView {
        return &self.depth_view;
    }

    pub fn opaqueSurfaceView(self: *Renderer) *vkmtl.TextureView {
        return &self.opaque_surface_view;
    }

    pub fn opaqueSurfaceDepthView(self: *Renderer) *vkmtl.TextureView {
        return &self.opaque_surface_depth_view;
    }

    pub fn waterSurfaceView(self: *Renderer) *vkmtl.TextureView {
        return &self.water_surface_view;
    }

    pub fn waterReflectionView(self: *Renderer) *vkmtl.TextureView {
        return &self.water_reflection_view;
    }

    pub fn waterReflectionTexture(self: *Renderer) *vkmtl.Texture {
        return &self.water_reflection_texture;
    }

    pub fn waterOverlayView(self: *Renderer) *vkmtl.TextureView {
        return &self.water_overlay_view;
    }

    pub fn encode(self: *Renderer, encoder: *vkmtl.command.RenderCommandEncoder) !void {
        try encoder.setRenderPipelineState(&self.pipeline);
        try encoder.setBindGroup(&self.bind_group.?, .{ .index = 0 });
        try encoder.drawPrimitives(.{
            .primitive_type = .triangle,
            .vertex_count = 3,
        });
    }
};
