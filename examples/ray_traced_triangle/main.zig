const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl ray traced triangle";

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
    const geometry = [_]vkmtl.AccelerationStructureGeometryDescriptor{.{
        .kind = .triangles,
        .primitive_count = 1,
        .vertex_stride = 24,
    }};
    const as_build = vkmtl.AccelerationStructureBuildDescriptor{
        .acceleration_structure = .{
            .kind = .bottom_level,
            .primitive_count = 1,
        },
        .geometries = geometry[0..],
    };
    const as_plan = device.planAccelerationStructureBuild(as_build) catch |err| {
        std.debug.print("ray tracing unsupported: {s}\n", .{@errorName(err)});
        return;
    };

    const groups = [_]vkmtl.RayTracingShaderGroupDescriptor{
        .{ .kind = .ray_generation, .entry_point = "raygen" },
        .{ .kind = .miss, .entry_point = "miss" },
        .{ .kind = .hit, .entry_point = "closest_hit" },
    };
    const pipeline = vkmtl.RayTracingPipelineDescriptor{
        .shader_groups = groups[0..],
        .max_recursion_depth = 1,
    };
    const pipeline_plan = device.planRayTracingPipelineLowering(pipeline) catch |err| {
        std.debug.print("ray tracing pipeline unsupported: {s}\n", .{@errorName(err)});
        return;
    };

    const sbt = vkmtl.ShaderBindingTableDescriptor{
        .stride = @max(device.limits().shader_binding_table_alignment, 64),
        .ray_generation_count = 1,
        .miss_count = 1,
        .hit_count = 1,
    };
    const dispatch_plan = device.planRayDispatch(sbt, .{
        .width = 512,
        .height = 384,
    }) catch |err| {
        std.debug.print("ray dispatch unsupported: {s}\n", .{@errorName(err)});
        return;
    };

    var metal_function_table_entries: u32 = 0;
    if (device.selectedBackend() == .metal) {
        const intersections = [_]vkmtl.MetalIntersectionFunctionDescriptor{.{
            .entry_point = "intersect_triangle",
        }};
        const metal_plan = device.planMetalRayTracingMapping(.{
            .pipeline = pipeline,
            .intersections = intersections[0..],
        }) catch |err| {
            std.debug.print("metal ray tracing mapping unsupported: {s}\n", .{@errorName(err)});
            return;
        };
        metal_function_table_entries = metal_plan.function_table_entries;
    }

    std.debug.print("ray traced triangle planning ok: backend={s}, as_size={}, scratch_size={}, groups={}, sbt_size={}, rays={}, metal_table_entries={}\n", .{
        @tagName(device.selectedBackend()),
        as_plan.result_size,
        as_plan.scratch_size,
        pipeline_plan.functionTableEntryCount(),
        dispatch_plan.sbt_size,
        dispatch_plan.total_rays,
        metal_function_table_entries,
    });
}
