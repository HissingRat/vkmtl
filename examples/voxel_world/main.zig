const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl voxel world";

const ReferenceWorkload = struct {
    const chunk_width = 16;
    const chunk_height = 64;
    const chunk_depth = 16;
    const default_radius = 4;
    const default_diameter = default_radius * 2 + 1;
    const default_resident_chunks = default_diameter * default_diameter;
};

pub fn main(_: std.process.Init.Minimal) !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 1280,
        .height = 720,
        .title = app_name,
    });
    defer glfw.destroyWindow(window);

    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var context = try vkmtl.WindowContext.init(allocator, .{
        .app_name = app_name,
        .backend = .auto,
        .debug_backend_override = backendOverrideFromEnv(),
        .surface = common.surfaceDescriptor(window),
        .presentation = common.presentationDescriptor(window, .fifo),
    });
    defer context.deinit();

    std.debug.print("Using backend: {}\n", .{context.selectedBackend()});
    std.debug.print(
        "voxel workload contract: chunk={}x{}x{}, default_grid={}x{}, max_resident={}\n",
        .{
            ReferenceWorkload.chunk_width,
            ReferenceWorkload.chunk_height,
            ReferenceWorkload.chunk_depth,
            ReferenceWorkload.default_diameter,
            ReferenceWorkload.default_diameter,
            ReferenceWorkload.default_resident_chunks,
        },
    );

    const frame_limit = frameLimitFromEnv();
    var rendered_frames: usize = 0;
    var swapchain = context.swapchain();

    while (!glfw.windowShouldClose(window)) {
        const extent = common.framebufferExtent(window);
        if (extent.isZero()) {
            glfw.pollEvents();
            continue;
        }

        try swapchain.resize(extent);
        try swapchain.clear(.{
            .red = 0.46,
            .green = 0.68,
            .blue = 0.88,
            .alpha = 1,
        });

        rendered_frames += 1;
        glfw.pollEvents();
        if (frame_limit) |limit| {
            if (rendered_frames >= limit) break;
        }
    }

    if (frame_limit != null) {
        std.debug.print("voxel_world_phase1_scaffold=ok frames={}\n", .{rendered_frames});
    }
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    if (std.ascii.eqlIgnoreCase(value, "vulkan")) return .vulkan;
    if (std.ascii.eqlIgnoreCase(value, "metal")) return .metal;

    std.debug.print("Ignoring unsupported VKMTL_BACKEND value: {s}\n", .{value});
    return null;
}

fn frameLimitFromEnv() ?usize {
    const value = std.mem.span(getenv("VKMTL_VOXEL_FRAME_LIMIT") orelse return null);
    const limit = std.fmt.parseUnsigned(usize, value, 10) catch {
        std.debug.print("Ignoring invalid VKMTL_VOXEL_FRAME_LIMIT value: {s}\n", .{value});
        return null;
    };
    if (limit == 0) {
        std.debug.print("Ignoring zero VKMTL_VOXEL_FRAME_LIMIT value\n", .{});
        return null;
    }
    return limit;
}
