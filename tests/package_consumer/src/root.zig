const std = @import("std");
const vkmtl = @import("vkmtl");

test "external package exposes the canonical API without a GPU" {
    comptime {
        if (!@hasDecl(vkmtl, "resource")) @compileError("missing resource facade");
        if (!@hasDecl(vkmtl, "shader")) @compileError("missing shader facade");
        if (!@hasDecl(vkmtl, "Device")) @compileError("missing Device owner");
        if (!@hasDecl(vkmtl, "HeadlessContext")) @compileError("missing HeadlessContext owner");
        if (!@hasDecl(vkmtl.HeadlessContext, "Options")) @compileError("missing HeadlessContext.Options");
        if (!@hasDecl(vkmtl.resource, "TextureDescriptor")) {
            @compileError("missing canonical TextureDescriptor");
        }
        if (!@hasDecl(vkmtl.Device, "compileRenderShader")) {
            @compileError("missing render shader compilation owner method");
        }
    }

    const extent: vkmtl.Extent2D = .{ .width = 1, .height = 2 };
    try std.testing.expectEqual(@as(u32, 2), extent.height);

    const descriptor: vkmtl.resource.TextureDescriptor = .{
        .format = .rgba8_unorm,
        .width = 1,
        .height = 1,
    };
    try descriptor.validate();

    const options: vkmtl.shader.RenderShaderCompileOptions = .{
        .vertex_entry = "consumer_vs",
        .fragment_entry = "consumer_fs",
    };
    try std.testing.expectEqualStrings("consumer_vs", options.vertex_entry);
    try std.testing.expectEqualStrings("consumer_fs", options.fragment_entry);
}
