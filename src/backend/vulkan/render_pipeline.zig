const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const VulkanBindGroupLayout = @import("bind_group.zig").VulkanBindGroupLayout;
const VulkanAdvancedBindGroupLayout = @import("advanced_binding.zig");
const GraphicsContext = @import("graphics_context.zig");
const VulkanShaderModule = @import("shader_module.zig");
const VulkanTexture = @import("texture.zig");
const PipelineCache = @import("pipeline_cache.zig");

const VulkanRenderPipelineState = @This();

gc: *const GraphicsContext,
allocator: std.mem.Allocator,
handle: vk.Pipeline,
layout: vk.PipelineLayout,
bind_group_layouts: []VulkanBindGroupLayout,
resource_table_layouts: []VulkanAdvancedBindGroupLayout,
render_pass: vk.RenderPass,
uses_depth: bool,
sample_count: u32,
depth_bias: core.DepthBiasDescriptor,

pub fn init(
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    descriptor: core.RenderPipelineDescriptor,
) !VulkanRenderPipelineState {
    try descriptor.validate();
    for (descriptor.color_attachments) |attachment| {
        if (!gc.supportsSampleCount(attachment.format, descriptor.sample_count)) {
            return core.PipelineError.UnsupportedSampleCount;
        }
    }
    if (descriptor.depth_stencil) |depth_stencil| {
        if (!gc.supportsSampleCount(depth_stencil.format, descriptor.sample_count)) {
            return core.PipelineError.UnsupportedSampleCount;
        }
    }

    const render_pass = try createRenderPassForDescriptor(gc, descriptor);
    errdefer gc.dev.destroyRenderPass(render_pass, null);

    var vertex_module = try VulkanShaderModule.init(gc, allocator, descriptor.vertex.module);
    defer vertex_module.deinit();

    var fragment_module: ?VulkanShaderModule = if (descriptor.fragment) |fragment|
        try VulkanShaderModule.init(gc, allocator, fragment.module)
    else
        null;
    defer if (fragment_module) |*module| module.deinit();

    const vertex_entry = try allocator.dupeZ(u8, descriptor.vertex.entry_point);
    defer allocator.free(vertex_entry);
    const fragment_entry = if (descriptor.fragment) |fragment|
        try allocator.dupeZ(u8, fragment.entry_point)
    else
        null;
    defer if (fragment_entry) |entry| allocator.free(entry);

    var vertex_specialization = try SpecializationState.init(allocator, descriptor.vertex.specialization);
    defer vertex_specialization.deinit();
    var fragment_specialization = if (descriptor.fragment) |fragment|
        try SpecializationState.init(allocator, fragment.specialization)
    else
        SpecializationState.empty();
    defer fragment_specialization.deinit();

    var stages_buffer: [2]vk.PipelineShaderStageCreateInfo = undefined;
    stages_buffer[0] = .{
        .stage = .{ .vertex_bit = true },
        .module = vertex_module.handle,
        .p_name = vertex_entry,
        .p_specialization_info = vertex_specialization.infoPtr(),
    };
    var stage_count: u32 = 1;
    if (fragment_module) |module| {
        stages_buffer[1] = .{
            .stage = .{ .fragment_bit = true },
            .module = module.handle,
            .p_name = fragment_entry.?,
            .p_specialization_info = fragment_specialization.infoPtr(),
        };
        stage_count = 2;
    }

    const vertex_bindings = try makeVertexBindings(allocator, descriptor.vertex_descriptor);
    defer allocator.free(vertex_bindings);
    const vertex_attributes = try makeVertexAttributes(allocator, descriptor.vertex_descriptor);
    defer allocator.free(vertex_attributes);
    const vertex_divisors = try makeVertexBindingDivisors(allocator, descriptor.vertex_descriptor);
    defer allocator.free(vertex_divisors);
    const vertex_divisor_state = vk.PipelineVertexInputDivisorStateCreateInfoEXT{
        .vertex_binding_divisor_count = @intCast(vertex_divisors.len),
        .p_vertex_binding_divisors = if (vertex_divisors.len == 0) undefined else vertex_divisors.ptr,
    };

    const vertex_input = vk.PipelineVertexInputStateCreateInfo{
        .p_next = if (vertex_divisors.len == 0) null else &vertex_divisor_state,
        .vertex_binding_description_count = @intCast(vertex_bindings.len),
        .p_vertex_binding_descriptions = if (vertex_bindings.len == 0) null else vertex_bindings.ptr,
        .vertex_attribute_description_count = @intCast(vertex_attributes.len),
        .p_vertex_attribute_descriptions = if (vertex_attributes.len == 0) null else vertex_attributes.ptr,
    };

    const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
        .topology = primitiveTopology(descriptor.primitive_topology),
        .primitive_restart_enable = .false,
    };

    const viewport_state = vk.PipelineViewportStateCreateInfo{
        .viewport_count = 1,
        .p_viewports = undefined,
        .scissor_count = 1,
        .p_scissors = undefined,
    };

    const rasterization = vk.PipelineRasterizationStateCreateInfo{
        .depth_clamp_enable = .false,
        .rasterizer_discard_enable = .false,
        .polygon_mode = polygonMode(descriptor.fill_mode),
        .cull_mode = cullMode(descriptor.cull_mode),
        .front_face = frontFace(descriptor.front_facing_winding),
        .depth_bias_enable = if (descriptor.depth_bias.enabled) .true else .false,
        .depth_bias_constant_factor = descriptor.depth_bias.constant,
        .depth_bias_clamp = descriptor.depth_bias.clamp,
        .depth_bias_slope_factor = descriptor.depth_bias.slope,
        .line_width = 1,
    };

    const multisample = vk.PipelineMultisampleStateCreateInfo{
        .rasterization_samples = VulkanTexture.sampleCountFlags(descriptor.sample_count),
        .sample_shading_enable = .false,
        .min_sample_shading = 1,
        .alpha_to_coverage_enable = .false,
        .alpha_to_one_enable = .false,
    };

    const depth_stencil = if (descriptor.depth_stencil) |depth| makeDepthStencilState(depth) else null;

    const color_blend_attachments = try makeColorBlendAttachments(allocator, descriptor.color_attachments);
    defer allocator.free(color_blend_attachments);

    const color_blend = vk.PipelineColorBlendStateCreateInfo{
        .logic_op_enable = .false,
        .logic_op = .copy,
        .attachment_count = @intCast(color_blend_attachments.len),
        .p_attachments = color_blend_attachments.ptr,
        .blend_constants = [_]f32{ 0, 0, 0, 0 },
    };

    const dynamic_states = [_]vk.DynamicState{
        .viewport,
        .scissor,
        .blend_constants,
        .stencil_reference,
        .depth_bias,
    };
    const dynamic_state = vk.PipelineDynamicStateCreateInfo{
        .flags = .{},
        .dynamic_state_count = dynamic_states.len,
        .p_dynamic_states = &dynamic_states,
    };

    const bind_group_layouts = try makeBindGroupLayouts(gc, allocator, descriptor.bind_group_layouts);
    errdefer destroyBindGroupLayouts(allocator, bind_group_layouts);
    const resource_table_layouts = try makeResourceTableLayouts(gc, allocator, descriptor.resource_table_layouts);
    errdefer destroyResourceTableLayouts(allocator, resource_table_layouts);

    const set_layout_handles = try makeDescriptorSetLayoutHandles(allocator, bind_group_layouts, resource_table_layouts);
    defer allocator.free(set_layout_handles);
    const push_constant_ranges = try makePushConstantRanges(allocator, descriptor.root_constant_layout);
    defer allocator.free(push_constant_ranges);

    const layout = try gc.dev.createPipelineLayout(&.{
        .flags = .{},
        .set_layout_count = @intCast(set_layout_handles.len),
        .p_set_layouts = if (set_layout_handles.len == 0) null else set_layout_handles.ptr,
        .push_constant_range_count = @intCast(push_constant_ranges.len),
        .p_push_constant_ranges = if (push_constant_ranges.len == 0) null else push_constant_ranges.ptr,
    }, null);
    errdefer gc.dev.destroyPipelineLayout(layout, null);

    const pipeline_info = vk.GraphicsPipelineCreateInfo{
        .flags = .{},
        .stage_count = stage_count,
        .p_stages = &stages_buffer,
        .p_vertex_input_state = &vertex_input,
        .p_input_assembly_state = &input_assembly,
        .p_tessellation_state = null,
        .p_viewport_state = &viewport_state,
        .p_rasterization_state = &rasterization,
        .p_multisample_state = &multisample,
        .p_depth_stencil_state = if (depth_stencil) |*state| state else null,
        .p_color_blend_state = &color_blend,
        .p_dynamic_state = &dynamic_state,
        .layout = layout,
        .render_pass = render_pass,
        .subpass = 0,
        .base_pipeline_handle = .null_handle,
        .base_pipeline_index = -1,
    };

    var pipeline_cache = try PipelineCache.Session.init(gc, allocator, descriptor.driver_cache);
    defer pipeline_cache.deinit();
    var pipeline: vk.Pipeline = undefined;
    _ = try gc.dev.createGraphicsPipelines(pipeline_cache.handle, &.{pipeline_info}, null, (&pipeline)[0..1]);

    return .{
        .gc = gc,
        .allocator = allocator,
        .handle = pipeline,
        .layout = layout,
        .bind_group_layouts = bind_group_layouts,
        .resource_table_layouts = resource_table_layouts,
        .render_pass = render_pass,
        .uses_depth = descriptor.depth_stencil != null,
        .sample_count = descriptor.sample_count,
        .depth_bias = descriptor.depth_bias,
    };
}

pub fn deinit(self: *VulkanRenderPipelineState) void {
    self.gc.dev.destroyPipeline(self.handle, null);
    self.gc.dev.destroyRenderPass(self.render_pass, null);
    self.gc.dev.destroyPipelineLayout(self.layout, null);
    destroyBindGroupLayouts(self.allocator, self.bind_group_layouts);
    destroyResourceTableLayouts(self.allocator, self.resource_table_layouts);
}

pub fn setLabel(self: *VulkanRenderPipelineState, label_value: ?[]const u8) void {
    self.gc.setDebugName(.pipeline, GraphicsContext.debugObjectHandle(self.handle), label_value);
}

fn createRenderPassForDescriptor(
    gc: *const GraphicsContext,
    descriptor: core.RenderPipelineDescriptor,
) !vk.RenderPass {
    var attachments: [core.default_max_color_attachments * 2 + 1]vk.AttachmentDescription = undefined;
    var color_attachment_refs: [core.default_max_color_attachments]vk.AttachmentReference = undefined;
    var resolve_attachment_refs: [core.default_max_color_attachments]vk.AttachmentReference = undefined;
    var attachment_count: u32 = 0;
    const uses_resolve = descriptor.sample_count != 1;
    for (descriptor.color_attachments, 0..) |color_attachment, i| {
        attachments[attachment_count] = .{
            .format = textureFormat(color_attachment.format),
            .samples = VulkanTexture.sampleCountFlags(descriptor.sample_count),
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = .color_attachment_optimal,
        };
        color_attachment_refs[i] = .{
            .attachment = attachment_count,
            .layout = .color_attachment_optimal,
        };
        attachment_count += 1;
    }
    if (uses_resolve) {
        for (descriptor.color_attachments, 0..) |color_attachment, i| {
            attachments[attachment_count] = .{
                .format = textureFormat(color_attachment.format),
                .samples = .{ .@"1_bit" = true },
                .load_op = .dont_care,
                .store_op = .store,
                .stencil_load_op = .dont_care,
                .stencil_store_op = .dont_care,
                .initial_layout = .undefined,
                .final_layout = .color_attachment_optimal,
            };
            resolve_attachment_refs[i] = .{
                .attachment = attachment_count,
                .layout = .color_attachment_optimal,
            };
            attachment_count += 1;
        }
    }

    var depth_attachment_ref: vk.AttachmentReference = undefined;
    if (descriptor.depth_stencil) |depth_stencil| {
        attachments[attachment_count] = .{
            .format = textureFormat(depth_stencil.format),
            .samples = VulkanTexture.sampleCountFlags(descriptor.sample_count),
            .load_op = .clear,
            .store_op = .dont_care,
            .stencil_load_op = if (core.isStencilFormat(depth_stencil.format)) .clear else .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = .depth_stencil_attachment_optimal,
        };
        depth_attachment_ref = .{
            .attachment = attachment_count,
            .layout = .depth_stencil_attachment_optimal,
        };
        attachment_count += 1;
    }

    const color_attachment_ref_slice = color_attachment_refs[0..descriptor.color_attachments.len];
    const resolve_attachment_ref_slice = resolve_attachment_refs[0..descriptor.color_attachments.len];
    const subpass = vk.SubpassDescription{
        .pipeline_bind_point = .graphics,
        .color_attachment_count = @intCast(descriptor.color_attachments.len),
        .p_color_attachments = color_attachment_ref_slice.ptr,
        .p_resolve_attachments = if (uses_resolve) resolve_attachment_ref_slice.ptr else null,
        .p_depth_stencil_attachment = if (descriptor.depth_stencil != null) &depth_attachment_ref else null,
    };

    return try gc.dev.createRenderPass(&.{
        .attachment_count = attachment_count,
        .p_attachments = &attachments,
        .subpass_count = 1,
        .p_subpasses = @ptrCast(&subpass),
    }, null);
}

fn makeBindGroupLayouts(
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    descriptors: []const core.BindGroupLayoutDescriptor,
) ![]VulkanBindGroupLayout {
    const layouts = try allocator.alloc(VulkanBindGroupLayout, descriptors.len);
    errdefer allocator.free(layouts);

    var initialized: usize = 0;
    errdefer {
        for (layouts[0..initialized]) |*layout| {
            layout.deinit();
        }
    }

    for (descriptors, layouts) |descriptor, *layout| {
        layout.* = try VulkanBindGroupLayout.init(gc, allocator, descriptor);
        initialized += 1;
    }

    return layouts;
}

fn makeDescriptorSetLayoutHandles(
    allocator: std.mem.Allocator,
    layouts: []const VulkanBindGroupLayout,
    resource_table_layouts: []const VulkanAdvancedBindGroupLayout,
) ![]vk.DescriptorSetLayout {
    const handles = try allocator.alloc(vk.DescriptorSetLayout, layouts.len + resource_table_layouts.len);
    for (layouts, handles) |layout, *handle| {
        handle.* = layout.handle;
    }
    for (resource_table_layouts, handles[layouts.len..]) |layout, *handle| handle.* = layout.handle;
    return handles;
}

fn makeResourceTableLayouts(
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    descriptors: []const core.DescriptorIndexingLayoutDescriptor,
) ![]VulkanAdvancedBindGroupLayout {
    const layouts = try allocator.alloc(VulkanAdvancedBindGroupLayout, descriptors.len);
    errdefer allocator.free(layouts);
    var initialized: usize = 0;
    errdefer for (layouts[0..initialized]) |*layout| layout.deinit();
    for (descriptors, layouts) |descriptor, *layout| {
        layout.* = try VulkanAdvancedBindGroupLayout.init(gc, allocator, descriptor);
        initialized += 1;
    }
    return layouts;
}

fn destroyResourceTableLayouts(allocator: std.mem.Allocator, layouts: []VulkanAdvancedBindGroupLayout) void {
    for (layouts) |*layout| layout.deinit();
    allocator.free(layouts);
}

fn makePushConstantRanges(
    allocator: std.mem.Allocator,
    layout: ?core.RootConstantLayoutDescriptor,
) ![]vk.PushConstantRange {
    const root_layout = layout orelse return &.{};
    const ranges = try allocator.alloc(vk.PushConstantRange, root_layout.ranges.len);
    for (root_layout.ranges, ranges) |range, *out| {
        out.* = .{
            .stage_flags = shaderStageFlags(range.visibility),
            .offset = range.offset,
            .size = range.size,
        };
    }
    return ranges;
}

fn destroyBindGroupLayouts(
    allocator: std.mem.Allocator,
    layouts: []VulkanBindGroupLayout,
) void {
    for (layouts) |*layout| {
        layout.deinit();
    }
    allocator.free(layouts);
}

fn shaderStageFlags(visibility: core.ShaderVisibility) vk.ShaderStageFlags {
    return .{
        .vertex_bit = visibility.vertex,
        .fragment_bit = visibility.fragment,
        .compute_bit = visibility.compute,
    };
}

const SpecializationState = struct {
    allocator: ?std.mem.Allocator = null,
    entries: []vk.SpecializationMapEntry = &.{},
    data: []u8 = &.{},
    info: vk.SpecializationInfo = .{},

    fn empty() SpecializationState {
        return .{};
    }

    fn init(
        allocator: std.mem.Allocator,
        descriptor: core.ShaderSpecializationDescriptor,
    ) !SpecializationState {
        if (descriptor.constants.len == 0) return empty();

        const entries = try allocator.alloc(vk.SpecializationMapEntry, descriptor.constants.len);
        errdefer allocator.free(entries);
        const data = try allocator.alloc(u8, descriptor.constants.len * 4);
        errdefer allocator.free(data);

        var offset: u32 = 0;
        for (descriptor.constants, entries) |constant, *entry| {
            entry.* = .{
                .constant_id = constant.id,
                .offset = offset,
                .size = 4,
            };
            writeSpecializationValue(data[offset..][0..4], constant.value);
            offset += 4;
        }

        return .{
            .allocator = allocator,
            .entries = entries,
            .data = data,
            .info = .{
                .map_entry_count = @intCast(entries.len),
                .p_map_entries = entries.ptr,
                .data_size = data.len,
                .p_data = data.ptr,
            },
        };
    }

    fn deinit(self: *SpecializationState) void {
        if (self.allocator) |allocator| {
            allocator.free(self.entries);
            allocator.free(self.data);
        }
        self.* = undefined;
    }

    fn infoPtr(self: *const SpecializationState) ?*const vk.SpecializationInfo {
        if (self.entries.len == 0) return null;
        return &self.info;
    }
};

fn writeSpecializationValue(out: []u8, value: core.ShaderSpecializationValue) void {
    const bits: u32 = switch (value) {
        .bool => |v| if (v) 1 else 0,
        .i32 => |v| @bitCast(v),
        .u32 => |v| v,
        .f32 => |v| @bitCast(v),
    };
    std.mem.writeInt(u32, out[0..4], bits, .little);
}

fn makeVertexBindings(
    allocator: std.mem.Allocator,
    descriptor: core.VertexDescriptor,
) ![]vk.VertexInputBindingDescription {
    const bindings = try allocator.alloc(vk.VertexInputBindingDescription, descriptor.buffers.len);
    for (descriptor.buffers, bindings, 0..) |buffer, *binding, i| {
        binding.* = .{
            .binding = buffer.resolvedBufferIndex(i),
            .stride = buffer.stride,
            .input_rate = vertexInputRate(buffer.step_function),
        };
    }
    return bindings;
}

fn makeVertexAttributes(
    allocator: std.mem.Allocator,
    descriptor: core.VertexDescriptor,
) ![]vk.VertexInputAttributeDescription {
    var count: usize = 0;
    for (descriptor.buffers) |buffer| count += buffer.attributes.len;

    const attributes = try allocator.alloc(vk.VertexInputAttributeDescription, count);
    var out_index: usize = 0;
    for (descriptor.buffers, 0..) |buffer, binding| {
        for (buffer.attributes) |attribute| {
            attributes[out_index] = .{
                .location = attribute.location,
                .binding = buffer.resolvedBufferIndex(binding),
                .format = vertexFormat(attribute.format),
                .offset = attribute.offset,
            };
            out_index += 1;
        }
    }
    return attributes;
}

fn makeVertexBindingDivisors(
    allocator: std.mem.Allocator,
    descriptor: core.VertexDescriptor,
) ![]vk.VertexInputBindingDivisorDescriptionEXT {
    var count: usize = 0;
    for (descriptor.buffers) |buffer| {
        if (buffer.step_function == .per_instance and buffer.instance_step_rate != 1) count += 1;
    }

    const divisors = try allocator.alloc(vk.VertexInputBindingDivisorDescriptionEXT, count);
    var out_index: usize = 0;
    for (descriptor.buffers, 0..) |buffer, binding| {
        if (buffer.step_function != .per_instance or buffer.instance_step_rate == 1) continue;
        divisors[out_index] = .{
            .binding = buffer.resolvedBufferIndex(binding),
            .divisor = buffer.instance_step_rate,
        };
        out_index += 1;
    }
    return divisors;
}

fn makeColorBlendAttachments(
    allocator: std.mem.Allocator,
    attachments: []const core.RenderPipelineColorAttachmentDescriptor,
) ![]vk.PipelineColorBlendAttachmentState {
    const states = try allocator.alloc(vk.PipelineColorBlendAttachmentState, attachments.len);
    for (attachments, states) |attachment, *state| {
        const blend = attachment.blend;
        state.* = .{
            .blend_enable = if (blend != null) .true else .false,
            .src_color_blend_factor = if (blend) |value| blendFactor(value.source_rgb_blend_factor) else .one,
            .dst_color_blend_factor = if (blend) |value| blendFactor(value.destination_rgb_blend_factor) else .zero,
            .color_blend_op = if (blend) |value| blendOp(value.rgb_blend_operation) else .add,
            .src_alpha_blend_factor = if (blend) |value| blendFactor(value.source_alpha_blend_factor) else .one,
            .dst_alpha_blend_factor = if (blend) |value| blendFactor(value.destination_alpha_blend_factor) else .zero,
            .alpha_blend_op = if (blend) |value| blendOp(value.alpha_blend_operation) else .add,
            .color_write_mask = colorWriteMask(attachment.write_mask),
        };
    }
    return states;
}

fn blendFactor(factor: core.BlendFactor) vk.BlendFactor {
    return switch (factor) {
        .zero => .zero,
        .one => .one,
        .source_color => .src_color,
        .one_minus_source_color => .one_minus_src_color,
        .source_alpha => .src_alpha,
        .one_minus_source_alpha => .one_minus_src_alpha,
        .destination_color => .dst_color,
        .one_minus_destination_color => .one_minus_dst_color,
        .destination_alpha => .dst_alpha,
        .one_minus_destination_alpha => .one_minus_dst_alpha,
        .blend_color => .constant_color,
        .one_minus_blend_color => .one_minus_constant_color,
        .blend_alpha => .constant_alpha,
        .one_minus_blend_alpha => .one_minus_constant_alpha,
    };
}

fn blendOp(operation: core.BlendOperation) vk.BlendOp {
    return switch (operation) {
        .add => .add,
        .subtract => .subtract,
        .reverse_subtract => .reverse_subtract,
        .min => .min,
        .max => .max,
    };
}

fn vertexFormat(format: core.VertexFormat) vk.Format {
    return switch (format) {
        .float16x2 => .r16g16_sfloat,
        .float16x4 => .r16g16b16a16_sfloat,
        .float32 => .r32_sfloat,
        .float32x2 => .r32g32_sfloat,
        .float32x3 => .r32g32b32_sfloat,
        .float32x4 => .r32g32b32a32_sfloat,
        .unorm8x2 => .r8g8_unorm,
        .unorm8x4 => .r8g8b8a8_unorm,
        .snorm8x2 => .r8g8_snorm,
        .snorm8x4 => .r8g8b8a8_snorm,
        .uint32 => .r32_uint,
        .uint32x2 => .r32g32_uint,
        .uint32x3 => .r32g32b32_uint,
        .uint32x4 => .r32g32b32a32_uint,
        .sint32 => .r32_sint,
        .sint32x2 => .r32g32_sint,
        .sint32x3 => .r32g32b32_sint,
        .sint32x4 => .r32g32b32a32_sint,
    };
}

fn textureFormat(format: core.TextureFormat) vk.Format {
    return switch (format) {
        .automatic => unreachable,
        .r8_unorm => .r8_unorm,
        .rg8_unorm => .r8g8_unorm,
        .rgba8_uint => .r8g8b8a8_uint,
        .rgba8_sint => .r8g8b8a8_sint,
        .r16_float => .r16_sfloat,
        .rg16_float => .r16g16_sfloat,
        .rgba16_float => .r16g16b16a16_sfloat,
        .r32_float => .r32_sfloat,
        .rg32_float => .r32g32_sfloat,
        .rgba32_float => .r32g32b32a32_sfloat,
        .r32_uint => .r32_uint,
        .r32_sint => .r32_sint,
        .depth16_unorm => .d16_unorm,
        .stencil8 => .s8_uint,
        .bgra8_unorm => .b8g8r8a8_unorm,
        .bgra8_unorm_srgb => .b8g8r8a8_srgb,
        .rgba8_unorm => .r8g8b8a8_unorm,
        .rgba8_unorm_srgb => .r8g8b8a8_srgb,
        .depth32_float => .d32_sfloat,
        .depth32_float_stencil8 => .d32_sfloat_s8_uint,
    };
}

fn vertexInputRate(step: core.VertexStepFunction) vk.VertexInputRate {
    return switch (step) {
        .per_vertex => .vertex,
        .per_instance => .instance,
    };
}

fn primitiveTopology(topology: core.PrimitiveTopology) vk.PrimitiveTopology {
    return switch (topology) {
        .triangle => .triangle_list,
        .line => .line_list,
        .point => .point_list,
    };
}

fn frontFace(winding: core.Winding) vk.FrontFace {
    return switch (winding) {
        .clockwise => .clockwise,
        .counter_clockwise => .counter_clockwise,
    };
}

fn polygonMode(fill_mode: core.TriangleFillMode) vk.PolygonMode {
    return switch (fill_mode) {
        .fill => .fill,
        .lines => .line,
    };
}

fn cullMode(mode: core.CullMode) vk.CullModeFlags {
    return switch (mode) {
        .none => .{},
        .front => .{ .front_bit = true },
        .back => .{ .back_bit = true },
    };
}

fn colorWriteMask(mask: core.ColorWriteMask) vk.ColorComponentFlags {
    return .{
        .r_bit = mask.red,
        .g_bit = mask.green,
        .b_bit = mask.blue,
        .a_bit = mask.alpha,
    };
}

fn makeDepthStencilState(descriptor: core.DepthStencilDescriptor) vk.PipelineDepthStencilStateCreateInfo {
    return .{
        .depth_test_enable = if (descriptor.depth_test_enabled) .true else .false,
        .depth_write_enable = if (descriptor.depth_write_enabled) .true else .false,
        .depth_compare_op = compareOp(descriptor.depth_compare_function),
        .depth_bounds_test_enable = .false,
        .stencil_test_enable = if (descriptor.stencil.enabled) .true else .false,
        .front = stencilOpState(descriptor.stencil.front, descriptor.stencil.read_mask, descriptor.stencil.write_mask),
        .back = stencilOpState(descriptor.stencil.back, descriptor.stencil.read_mask, descriptor.stencil.write_mask),
        .min_depth_bounds = 0,
        .max_depth_bounds = 1,
    };
}

fn stencilOpState(
    descriptor: core.StencilFaceDescriptor,
    read_mask: u32,
    write_mask: u32,
) vk.StencilOpState {
    return .{
        .fail_op = stencilOp(descriptor.stencil_fail_operation),
        .pass_op = stencilOp(descriptor.depth_stencil_pass_operation),
        .depth_fail_op = stencilOp(descriptor.depth_fail_operation),
        .compare_op = compareOp(descriptor.stencil_compare_function),
        .compare_mask = read_mask,
        .write_mask = write_mask,
        .reference = 0,
    };
}

fn stencilOp(operation: core.StencilOperation) vk.StencilOp {
    return switch (operation) {
        .keep => .keep,
        .zero => .zero,
        .replace => .replace,
        .increment_clamp => .increment_and_clamp,
        .decrement_clamp => .decrement_and_clamp,
        .invert => .invert,
        .increment_wrap => .increment_and_wrap,
        .decrement_wrap => .decrement_and_wrap,
    };
}

fn compareOp(function: core.CompareFunction) vk.CompareOp {
    return switch (function) {
        .never => .never,
        .less => .less,
        .equal => .equal,
        .less_equal => .less_or_equal,
        .greater => .greater,
        .not_equal => .not_equal,
        .greater_equal => .greater_or_equal,
        .always => .always,
    };
}
