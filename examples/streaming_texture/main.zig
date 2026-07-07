const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl streaming texture";

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 512,
        .height = 384,
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
    const features = device.features();
    if (!features.sparse_textures and !features.tiled_textures) {
        std.debug.print("streaming texture unsupported: sparse/tiled textures unavailable\n", .{});
        return;
    }

    const kind: vkmtl.SparseTextureKind = if (features.sparse_textures) .sparse_texture else .tiled_texture;
    const page_extent = vkmtl.Size3D{
        .width = @max(device.limits().sparse_texture_page_width, 64),
        .height = @max(device.limits().sparse_texture_page_height, 64),
        .depth = @max(device.limits().sparse_texture_page_depth, 1),
    };
    try device.validateSparseTextureDescriptor(.{
        .kind = kind,
        .texture = .{
            .format = .rgba8_unorm,
            .width = page_extent.width * 4,
            .height = page_extent.height * 4,
            .usage = .{ .shader_read = true },
        },
        .page_extent = page_extent,
    });

    var residency = vkmtl.SparseResidencyMap.init(allocator);
    defer residency.deinit();
    try residency.apply(.{ .textures = &.{.{
        .kind = kind,
        .region = .{ .size = page_extent },
        .page_extent = page_extent,
    }} });

    std.debug.print("streaming texture residency ok: backend={s}, texture_regions={}\n", .{
        @tagName(device.selectedBackend()),
        residency.diagnostics().texture_regions,
    });
}
