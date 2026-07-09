const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl mesh shader";

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
    const descriptor = vkmtl.MeshPipelineDescriptor{
        .mesh_entry_point = "mesh_main",
        .mesh_threads_per_threadgroup = 32,
    };
    const dispatch = vkmtl.MeshDispatchDescriptor{
        .pipeline = descriptor,
        .threadgroup_count_x = 8,
        .threadgroup_count_y = 1,
        .threadgroup_count_z = 1,
    };

    const dispatch_plan = device.planMeshDispatch(dispatch) catch |err| {
        std.debug.print("mesh shader dispatch unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    std.debug.print("mesh dispatch plan: groups={}x{}x{}, total={}\n", .{
        dispatch_plan.threadgroup_count_x,
        dispatch_plan.threadgroup_count_y,
        dispatch_plan.threadgroup_count_z,
        dispatch_plan.total_threadgroups,
    });

    switch (device.selectedBackend()) {
        .vulkan => {
            const lowering = try device.planVulkanMeshDispatch(dispatch);
            std.debug.print("Vulkan mesh dispatch plan ok: mesh_entry={s}, threads={}, groups={}x{}x{}, total={}\n", .{
                lowering.mesh_entry_point,
                lowering.mesh_threads_per_threadgroup,
                lowering.group_count_x,
                lowering.group_count_y,
                lowering.group_count_z,
                lowering.total_threadgroups,
            });
        },
        .metal => {
            const lowering = try device.planMetalMeshDispatch(dispatch);
            std.debug.print("Metal mesh dispatch plan ok: mesh_entry={s}, object_stage={}, groups={}x{}x{}, total={}\n", .{
                lowering.mesh_entry_point,
                lowering.hasObjectStage(),
                lowering.group_count_x,
                lowering.group_count_y,
                lowering.group_count_z,
                lowering.total_threadgroups,
            });
        },
    }
}
