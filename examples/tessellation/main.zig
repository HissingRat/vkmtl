const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl tessellation";

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 480,
        .height = 320,
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
    const descriptor = vkmtl.render.TessellationDescriptor{
        .control_point_count = 3,
        .domain = .triangle,
        .partition_mode = .integer,
        .control_stage = .{ .entry_point = "tc_main" },
        .evaluation_stage = .{ .entry_point = "te_main" },
    };
    const patch_draw = vkmtl.render.TessellationPatchDrawDescriptor{
        .tessellation = descriptor,
        .patch_count = 16,
        .instance_count = 1,
    };

    const patch_plan = vkmtl.render.planTessellationPatchDraw(device, patch_draw) catch |err| {
        std.debug.print("tessellation patch draw unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    std.debug.print("tessellation patch draw plan: patches={}, total={}\n", .{
        patch_plan.patch_count,
        patch_plan.total_patches,
    });

    switch (device.selectedBackend()) {
        .vulkan => {
            const lowering = try vkmtl.native.vulkan.planTessellationPatchDraw(device, patch_draw);
            std.debug.print("Vulkan tessellation patch draw plan ok: patch_points={}, vertices={}, instances={}, first_vertex={}\n", .{
                lowering.patch_control_points,
                lowering.draw_vertex_count,
                lowering.draw_instance_count,
                lowering.first_vertex,
            });
        },
        .metal => {
            const lowering = try vkmtl.native.metal.planTessellationPatchDraw(device, patch_draw);
            std.debug.print("Metal tessellation patch draw plan ok: patch_points={}, factor_owner={s}, factor_stride={}\n", .{
                lowering.patch_control_points,
                @tagName(lowering.factor_buffer_ownership),
                lowering.factor_buffer.stride,
            });
        },
    }
}
