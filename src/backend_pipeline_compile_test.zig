const std = @import("std");
const core = @import("core.zig");
const MetalBindGroupBackend = @import("backend/metal/bind_group.zig");
const MetalCommand = @import("backend/metal/command.zig");
const MetalRenderPipelineState = @import("backend/metal/render_pipeline.zig");
const MetalShaderModule = @import("backend/metal/shader_module.zig");
const VulkanCommand = @import("backend/vulkan/command.zig");
const VulkanRenderPipelineState = @import("backend/vulkan/render_pipeline.zig");
const VulkanShaderModule = @import("backend/vulkan/shader_module.zig");

test "backend render pipeline init paths validate before native work" {
    const vertex_module = core.ShaderModuleDescriptor{
        .source = .{ .spirv = &.{0x07230203} },
    };
    const descriptor = core.RenderPipelineDescriptor{
        .vertex = .{
            .module = vertex_module,
            .stage = .vertex,
        },
    };

    try std.testing.expectError(
        core.PipelineError.MissingColorAttachment,
        VulkanRenderPipelineState.init(undefined, std.testing.allocator, descriptor),
    );
    try std.testing.expectError(
        core.PipelineError.MissingColorAttachment,
        MetalRenderPipelineState.init(undefined, std.testing.allocator, descriptor),
    );
}

test "backend command init paths validate before native work" {
    var vulkan_encoder: VulkanCommand.RenderCommandEncoder = undefined;
    var metal_encoder: MetalCommand.RenderCommandEncoder = undefined;
    try std.testing.expectError(
        core.CommandEncodingError.InvalidVertexCount,
        vulkan_encoder.drawPrimitives(.{}),
    );
    try std.testing.expectError(
        core.CommandEncodingError.InvalidVertexCount,
        metal_encoder.drawPrimitives(.{}),
    );
}

test "metal bind group stores layout visibility before native work" {
    const layout_entries = [_]core.BindGroupLayoutEntry{
        .{
            .binding = 4,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
        },
    };

    var layout = try MetalBindGroupBackend.MetalBindGroupLayout.init(std.testing.allocator, .{
        .entries = layout_entries[0..],
    });
    defer layout.deinit();

    var bind_group = try MetalBindGroupBackend.MetalBindGroup.init(std.testing.allocator, &layout, &.{});
    defer bind_group.deinit();

    const entry = bind_group.layoutEntryForBinding(4).?;
    try std.testing.expectEqual(core.BindingResourceKind.sampler, entry.resource);
    try std.testing.expect(entry.visibility.fragment);

    var encoder: MetalCommand.RenderCommandEncoder = undefined;
    try std.testing.expectError(
        core.CommandEncodingError.InvalidBindGroupIndex,
        encoder.setBindGroup(&bind_group, .{ .index = 16 }),
    );
}

test "backend shader artifact language validates before native work" {
    try std.testing.expectError(
        error.UnsupportedShaderArtifactLanguage,
        VulkanShaderModule.init(undefined, std.testing.allocator, .{
            .source = .{ .artifact = .{
                .path = "triangle.vertex.msl",
                .language = .msl,
            } },
        }),
    );

    try std.testing.expectError(
        error.UnsupportedShaderArtifactLanguage,
        MetalShaderModule.init(undefined, std.testing.allocator, .{
            .source = .{ .artifact = .{
                .path = "triangle.vertex.spv",
                .language = .spirv,
            } },
        }),
    );
}
