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

    var swapchain = context.swapchain();

    while (!glfw.windowShouldClose(window)) {
        const extent = common.framebufferExtent(window);
        if (extent.isZero()) {
            glfw.pollEvents();
            continue;
        }

        try swapchain.resize(extent);
        try swapchain.clear(.{
            .red = 0.04,
            .green = 0.07,
            .blue = 0.10,
            .alpha = 1,
        });

        glfw.pollEvents();
    }
}
