const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl clear screen";

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 800,
        .height = 600,
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
    std.debug.print("Using backend: {}\n", .{context.selectedBackend()});

    var texture = try context.makeTexture(.{
        .format = .rgba8_unorm,
        .width = 2,
        .height = 2,
        .usage = .{ .shader_read = true },
    });
    defer texture.deinit();

    // Resource smoke only: this upload is not visible until vkmtl has a
    // public blit or draw path that presents texture contents.
    const pixels = [_]u8{
        0xff, 0x00, 0x00, 0xff,
        0x00, 0xff, 0x00, 0xff,
        0x00, 0x00, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff,
    };
    try texture.replaceAll2D(.{
        .bytes = pixels[0..],
    });

    var texture_view = try texture.makeTextureView(.{});
    defer texture_view.deinit();

    var sampler = try context.makeSamplerState(.{
        .min_filter = .linear,
        .mag_filter = .linear,
    });
    defer sampler.deinit();

    while (!glfw.windowShouldClose(window)) {
        const extent = common.framebufferExtent(window);
        if (extent.isZero()) {
            glfw.pollEvents();
            continue;
        }

        try context.resize(extent);
        try context.clear(.{
            .red = 0.04,
            .green = 0.07,
            .blue = 0.10,
            .alpha = 1,
        });

        glfw.pollEvents();
    }
}
