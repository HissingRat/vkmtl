const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl multi window";

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const window_a = try glfw.createWindow(.{
        .width = 480,
        .height = 360,
        .title = "vkmtl multi window A",
    });
    defer glfw.destroyWindow(window_a);

    const window_b = try glfw.createWindow(.{
        .width = 360,
        .height = 300,
        .title = "vkmtl multi window B",
    });
    defer glfw.destroyWindow(window_b);

    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var context = try vkmtl.WindowContext.init(allocator, .{
        .app_name = app_name,
        .backend = .auto,
        .surface = common.surfaceDescriptor(window_a),
        .presentation = common.presentationDescriptor(window_a, .fifo),
    });
    defer context.deinit();

    var device = context.device();
    var surfaces = vkmtl.presentation.SurfaceCollection.init(allocator, context.selectedBackend());
    defer surfaces.deinit();

    const surface_a = try surfaces.add(.{
        .label = "window-a",
        .source = common.surfaceDescriptor(window_a).source,
    }, common.presentationDescriptor(window_a, .fifo));
    const surface_b = try surfaces.add(.{
        .label = "window-b",
        .source = common.surfaceDescriptor(window_b).source,
    }, common.presentationDescriptor(window_b, .mailbox).withResolvedPresentMode(.{}));

    dumpSurface("A", try surfaces.info(surface_a));
    dumpSurface("B", try surfaces.info(surface_b));

    if (!device.features().multi_surface) {
        std.debug.print("native multi-window presentation is feature-gated on this backend\n", .{});
        return;
    }

    std.debug.print("native multi-window presentation is available for backend={s}\n", .{
        @tagName(context.selectedBackend()),
    });
}

fn dumpSurface(name: []const u8, info: vkmtl.presentation.SurfaceInfo) void {
    const presentation = info.presentation orelse {
        std.debug.print("surface {s}: backend={s}, state={s}, unconfigured\n", .{
            name,
            @tagName(info.backend),
            @tagName(info.state),
        });
        return;
    };
    std.debug.print("surface {s}: backend={s}, provider={s}, state={s}, extent={}x{}, present={s}\n", .{
        name,
        @tagName(info.backend),
        @tagName(info.provider),
        @tagName(info.state),
        presentation.extent.width,
        presentation.extent.height,
        @tagName(presentation.present_mode),
    });
}
