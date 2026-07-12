const std = @import("std");
const core = @import("../../core.zig");
const debug = @import("debug.zig");
const metal = @import("metal_bridge");
const MetalClearScreen = @import("clear_screen.zig");
const MetalShaderModule = @import("shader_module.zig");
const specialization = @import("specialization.zig");
const slots = @import("slots.zig");

const MetalRenderPipelineState = @This();

handle: *metal.vkmtl_metal_render_pipeline_state,
uses_depth: bool,
sample_count: u32,
fill_mode: metal.vkmtl_metal_triangle_fill_mode,
depth_bias: core.DepthBiasDescriptor,

const Error = error{
    MetalUnsupported,
    InvalidShader,
    InvalidPipeline,
    CommandFailed,
    UnexpectedMetalStatus,
};

pub fn init(
    owner: *MetalClearScreen,
    allocator: std.mem.Allocator,
    descriptor: core.RenderPipelineDescriptor,
) !MetalRenderPipelineState {
    try descriptor.validate();

    var vertex_module = try MetalShaderModule.init(owner, allocator, descriptor.vertex.module);
    defer vertex_module.deinit();

    var fragment_module: ?MetalShaderModule = if (descriptor.fragment) |fragment|
        try MetalShaderModule.init(owner, allocator, fragment.module)
    else
        null;
    defer if (fragment_module) |*module| module.deinit();

    const vertex_constants = try specialization.translate(allocator, descriptor.vertex.specialization);
    defer allocator.free(vertex_constants);
    const fragment_constants = if (descriptor.fragment) |fragment|
        try specialization.translate(allocator, fragment.specialization)
    else
        try allocator.alloc(metal.vkmtl_metal_function_constant, 0);
    defer allocator.free(fragment_constants);

    const vertex_buffers = try makeVertexBufferLayouts(allocator, descriptor.vertex_descriptor);
    defer allocator.free(vertex_buffers);
    const vertex_attributes = try makeVertexAttributes(allocator, descriptor.vertex_descriptor);
    defer allocator.free(vertex_attributes);

    const color_attachments = makeColorAttachments(descriptor.color_attachments);
    const color_attachment_slice = color_attachments[0..descriptor.color_attachments.len];
    const stencil = if (descriptor.depth_stencil) |depth| depth.stencil else core.StencilDescriptor{};
    var handle: ?*metal.vkmtl_metal_render_pipeline_state = null;
    try check(metal.vkmtl_metal_render_pipeline_state_create(
        owner.handle,
        vertex_module.handle,
        descriptor.vertex.entry_point.ptr,
        descriptor.vertex.entry_point.len,
        if (vertex_constants.len == 0) null else vertex_constants.ptr,
        vertex_constants.len,
        if (fragment_module) |module| module.handle else null,
        if (descriptor.fragment) |fragment| fragment.entry_point.ptr else null,
        if (descriptor.fragment) |fragment| fragment.entry_point.len else 0,
        if (fragment_constants.len == 0) null else fragment_constants.ptr,
        fragment_constants.len,
        color_attachment_slice.ptr,
        color_attachment_slice.len,
        if (descriptor.depth_stencil) |depth| textureFormat(depth.format) else metal.VKMTL_METAL_TEXTURE_FORMAT_INVALID,
        if (descriptor.depth_stencil) |depth| compareFunction(depth.depth_compare_function) else metal.VKMTL_METAL_COMPARE_FUNCTION_ALWAYS,
        if (descriptor.depth_stencil) |depth| if (depth.depth_write_enabled) 1 else 0 else 0,
        if (stencil.enabled) 1 else 0,
        stencilOperation(stencil.front.stencil_fail_operation),
        stencilOperation(stencil.front.depth_fail_operation),
        stencilOperation(stencil.front.depth_stencil_pass_operation),
        compareFunction(stencil.front.stencil_compare_function),
        stencilOperation(stencil.back.stencil_fail_operation),
        stencilOperation(stencil.back.depth_fail_operation),
        stencilOperation(stencil.back.depth_stencil_pass_operation),
        compareFunction(stencil.back.stencil_compare_function),
        stencil.read_mask,
        stencil.write_mask,
        descriptor.sample_count,
        if (vertex_buffers.len == 0) null else vertex_buffers.ptr,
        vertex_buffers.len,
        if (vertex_attributes.len == 0) null else vertex_attributes.ptr,
        vertex_attributes.len,
        &handle,
    ));

    return .{
        .handle = handle orelse return Error.InvalidPipeline,
        .uses_depth = descriptor.depth_stencil != null,
        .sample_count = descriptor.sample_count,
        .fill_mode = triangleFillMode(descriptor.fill_mode),
        .depth_bias = descriptor.depth_bias,
    };
}

pub fn deinit(self: *MetalRenderPipelineState) void {
    metal.vkmtl_metal_render_pipeline_state_destroy(self.handle);
}

pub fn setLabel(self: *MetalRenderPipelineState, label_value: ?[]const u8) void {
    debug.ignore(metal.vkmtl_metal_render_pipeline_state_set_label(
        self.handle,
        debug.labelPtr(label_value),
        debug.labelLen(label_value),
    ));
}

fn makeVertexBufferLayouts(
    allocator: std.mem.Allocator,
    descriptor: core.VertexDescriptor,
) ![]metal.vkmtl_metal_vertex_buffer_layout {
    const layouts = try allocator.alloc(metal.vkmtl_metal_vertex_buffer_layout, descriptor.buffers.len);
    for (descriptor.buffers, layouts, 0..) |buffer, *layout, i| {
        const buffer_index = buffer.resolvedBufferIndex(i);
        layout.* = .{
            .buffer_index = slots.vertexBufferSlotUnchecked(buffer_index) orelse return core.CommandEncodingError.InvalidVertexBufferIndex,
            .stride = buffer.stride,
            .step_function = vertexStepFunction(buffer.step_function),
            .step_rate = buffer.instance_step_rate,
        };
    }
    return layouts;
}

fn makeColorAttachments(
    descriptors: []const core.RenderPipelineColorAttachmentDescriptor,
) [core.default_max_color_attachments]metal.vkmtl_metal_render_pipeline_color_attachment {
    var out: [core.default_max_color_attachments]metal.vkmtl_metal_render_pipeline_color_attachment = undefined;
    for (descriptors, 0..) |descriptor, i| {
        const blend = descriptor.blend;
        out[i] = .{
            .format = textureFormat(descriptor.format),
            .color_write_mask = colorWriteMask(descriptor.write_mask),
            .blend_enabled = if (blend != null) 1 else 0,
            .source_rgb_blend_factor = if (blend) |value| blendFactor(value.source_rgb_blend_factor) else metal.VKMTL_METAL_BLEND_FACTOR_ONE,
            .destination_rgb_blend_factor = if (blend) |value| blendFactor(value.destination_rgb_blend_factor) else metal.VKMTL_METAL_BLEND_FACTOR_ZERO,
            .rgb_blend_operation = if (blend) |value| blendOperation(value.rgb_blend_operation) else metal.VKMTL_METAL_BLEND_OPERATION_ADD,
            .source_alpha_blend_factor = if (blend) |value| blendFactor(value.source_alpha_blend_factor) else metal.VKMTL_METAL_BLEND_FACTOR_ONE,
            .destination_alpha_blend_factor = if (blend) |value| blendFactor(value.destination_alpha_blend_factor) else metal.VKMTL_METAL_BLEND_FACTOR_ZERO,
            .alpha_blend_operation = if (blend) |value| blendOperation(value.alpha_blend_operation) else metal.VKMTL_METAL_BLEND_OPERATION_ADD,
        };
    }
    return out;
}

fn makeVertexAttributes(
    allocator: std.mem.Allocator,
    descriptor: core.VertexDescriptor,
) ![]metal.vkmtl_metal_vertex_attribute {
    var count: usize = 0;
    for (descriptor.buffers) |buffer| count += buffer.attributes.len;

    const attributes = try allocator.alloc(metal.vkmtl_metal_vertex_attribute, count);
    var out_index: usize = 0;
    for (descriptor.buffers, 0..) |buffer, buffer_index| {
        const resolved_buffer_index = buffer.resolvedBufferIndex(buffer_index);
        for (buffer.attributes) |attribute| {
            attributes[out_index] = .{
                .location = attribute.location,
                .buffer_index = slots.vertexBufferSlotUnchecked(resolved_buffer_index) orelse return core.CommandEncodingError.InvalidVertexBufferIndex,
                .format = vertexFormat(attribute.format),
                .offset = attribute.offset,
            };
            out_index += 1;
        }
    }
    return attributes;
}

fn vertexFormat(format: core.VertexFormat) metal.vkmtl_metal_vertex_format {
    return switch (format) {
        .float32 => metal.VKMTL_METAL_VERTEX_FORMAT_FLOAT,
        .float32x2 => metal.VKMTL_METAL_VERTEX_FORMAT_FLOAT2,
        .float32x3 => metal.VKMTL_METAL_VERTEX_FORMAT_FLOAT3,
        .float32x4 => metal.VKMTL_METAL_VERTEX_FORMAT_FLOAT4,
    };
}

fn vertexStepFunction(step: core.VertexStepFunction) metal.vkmtl_metal_vertex_step_function {
    return switch (step) {
        .per_vertex => metal.VKMTL_METAL_VERTEX_STEP_FUNCTION_PER_VERTEX,
        .per_instance => metal.VKMTL_METAL_VERTEX_STEP_FUNCTION_PER_INSTANCE,
    };
}

fn triangleFillMode(fill_mode: core.TriangleFillMode) metal.vkmtl_metal_triangle_fill_mode {
    return switch (fill_mode) {
        .fill => metal.VKMTL_METAL_TRIANGLE_FILL_MODE_FILL,
        .lines => metal.VKMTL_METAL_TRIANGLE_FILL_MODE_LINES,
    };
}

fn colorWriteMask(mask: core.ColorWriteMask) u32 {
    return (if (mask.red) @as(u32, 1) << 0 else 0) |
        (if (mask.green) @as(u32, 1) << 1 else 0) |
        (if (mask.blue) @as(u32, 1) << 2 else 0) |
        (if (mask.alpha) @as(u32, 1) << 3 else 0);
}

fn blendFactor(factor: core.BlendFactor) metal.vkmtl_metal_blend_factor {
    return switch (factor) {
        .zero => metal.VKMTL_METAL_BLEND_FACTOR_ZERO,
        .one => metal.VKMTL_METAL_BLEND_FACTOR_ONE,
        .source_color => metal.VKMTL_METAL_BLEND_FACTOR_SOURCE_COLOR,
        .one_minus_source_color => metal.VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_SOURCE_COLOR,
        .source_alpha => metal.VKMTL_METAL_BLEND_FACTOR_SOURCE_ALPHA,
        .one_minus_source_alpha => metal.VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_SOURCE_ALPHA,
        .destination_color => metal.VKMTL_METAL_BLEND_FACTOR_DESTINATION_COLOR,
        .one_minus_destination_color => metal.VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_DESTINATION_COLOR,
        .destination_alpha => metal.VKMTL_METAL_BLEND_FACTOR_DESTINATION_ALPHA,
        .one_minus_destination_alpha => metal.VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_DESTINATION_ALPHA,
        .blend_color => metal.VKMTL_METAL_BLEND_FACTOR_BLEND_COLOR,
        .one_minus_blend_color => metal.VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_BLEND_COLOR,
        .blend_alpha => metal.VKMTL_METAL_BLEND_FACTOR_BLEND_ALPHA,
        .one_minus_blend_alpha => metal.VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_BLEND_ALPHA,
    };
}

fn blendOperation(operation: core.BlendOperation) metal.vkmtl_metal_blend_operation {
    return switch (operation) {
        .add => metal.VKMTL_METAL_BLEND_OPERATION_ADD,
        .subtract => metal.VKMTL_METAL_BLEND_OPERATION_SUBTRACT,
        .reverse_subtract => metal.VKMTL_METAL_BLEND_OPERATION_REVERSE_SUBTRACT,
        .min => metal.VKMTL_METAL_BLEND_OPERATION_MIN,
        .max => metal.VKMTL_METAL_BLEND_OPERATION_MAX,
    };
}

fn stencilOperation(operation: core.StencilOperation) metal.vkmtl_metal_stencil_operation {
    return switch (operation) {
        .keep => metal.VKMTL_METAL_STENCIL_OPERATION_KEEP,
        .zero => metal.VKMTL_METAL_STENCIL_OPERATION_ZERO,
        .replace => metal.VKMTL_METAL_STENCIL_OPERATION_REPLACE,
        .increment_clamp => metal.VKMTL_METAL_STENCIL_OPERATION_INCREMENT_CLAMP,
        .decrement_clamp => metal.VKMTL_METAL_STENCIL_OPERATION_DECREMENT_CLAMP,
        .invert => metal.VKMTL_METAL_STENCIL_OPERATION_INVERT,
        .increment_wrap => metal.VKMTL_METAL_STENCIL_OPERATION_INCREMENT_WRAP,
        .decrement_wrap => metal.VKMTL_METAL_STENCIL_OPERATION_DECREMENT_WRAP,
    };
}

fn textureFormat(format: core.TextureFormat) metal.vkmtl_metal_texture_format {
    return switch (format) {
        .automatic => metal.VKMTL_METAL_TEXTURE_FORMAT_INVALID,
        .bgra8_unorm => metal.VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM,
        .bgra8_unorm_srgb => metal.VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM_SRGB,
        .rgba8_unorm => metal.VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UNORM,
        .rgba8_unorm_srgb => metal.VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UNORM_SRGB,
        .depth32_float => metal.VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT,
        .depth32_float_stencil8 => metal.VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT_STENCIL8,
    };
}

fn compareFunction(function: core.CompareFunction) metal.vkmtl_metal_compare_function {
    return switch (function) {
        .never => metal.VKMTL_METAL_COMPARE_FUNCTION_NEVER,
        .less => metal.VKMTL_METAL_COMPARE_FUNCTION_LESS,
        .equal => metal.VKMTL_METAL_COMPARE_FUNCTION_EQUAL,
        .less_equal => metal.VKMTL_METAL_COMPARE_FUNCTION_LESS_EQUAL,
        .greater => metal.VKMTL_METAL_COMPARE_FUNCTION_GREATER,
        .not_equal => metal.VKMTL_METAL_COMPARE_FUNCTION_NOT_EQUAL,
        .greater_equal => metal.VKMTL_METAL_COMPARE_FUNCTION_GREATER_EQUAL,
        .always => metal.VKMTL_METAL_COMPARE_FUNCTION_ALWAYS,
    };
}

fn check(status: metal.vkmtl_metal_status) Error!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => Error.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_INVALID_SHADER => Error.InvalidShader,
        metal.VKMTL_METAL_STATUS_INVALID_PIPELINE => Error.InvalidPipeline,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED => Error.CommandFailed,
        else => Error.UnexpectedMetalStatus,
    };
}
