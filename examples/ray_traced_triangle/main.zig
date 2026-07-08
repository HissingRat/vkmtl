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
    var queue = context.queue();
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
    var acceleration_structure = device.makeAccelerationStructure(as_build.acceleration_structure) catch |err| {
        std.debug.print("ray tracing unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    defer acceleration_structure.deinit();

    const as_plan = device.planAccelerationStructureBuild(as_build) catch |err| {
        std.debug.print("ray tracing unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    var scratch_buffer = try device.makeBuffer(.{
        .label = "ray tracing scratch",
        .length = @intCast(as_plan.scratch_size),
        .usage = .{ .acceleration_structure_scratch = true },
        .storage_mode = .private,
    });
    defer scratch_buffer.deinit();

    const groups = [_]vkmtl.RayTracingShaderGroupDescriptor{
        .{ .kind = .ray_generation, .entry_point = "raygen" },
        .{ .kind = .miss, .entry_point = "miss" },
        .{ .kind = .hit, .entry_point = "closest_hit" },
    };
    const pipeline = vkmtl.RayTracingPipelineDescriptor{
        .shader_groups = groups[0..],
        .max_recursion_depth = 1,
    };
    var pipeline_state = device.makeRayTracingPipelineState(pipeline) catch |err| {
        std.debug.print("ray tracing pipeline unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    defer pipeline_state.deinit();

    const sbt = vkmtl.ShaderBindingTableDescriptor{
        .stride = @max(device.limits().shader_binding_table_alignment, 64),
        .ray_generation_count = 1,
        .miss_count = 1,
        .hit_count = 1,
    };
    var shader_binding_table = device.makeShaderBindingTable(sbt) catch |err| {
        std.debug.print("shader binding table unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    defer shader_binding_table.deinit();

    var metal_function_table_entries: u32 = 0;
    if (device.selectedBackend() == .metal) {
        const intersections = [_]vkmtl.MetalIntersectionFunctionDescriptor{.{
            .entry_point = "intersect_triangle",
        }};
        var metal_mapping = device.makeMetalRayTracingExecutionMapping(.{
            .pipeline = pipeline,
            .intersections = intersections[0..],
        }) catch |err| {
            std.debug.print("metal ray tracing mapping unsupported: {s}\n", .{@errorName(err)});
            return;
        };
        defer metal_mapping.deinit();
        metal_function_table_entries = metal_mapping.functionTableEntryCount();
    }

    var command_buffer = try queue.makeCommandBuffer();
    try command_buffer.encodeAccelerationStructureBuild(as_plan, .{
        .result = &acceleration_structure,
        .scratch = &scratch_buffer,
    });
    const dispatch_plan = try command_buffer.dispatchRays(&pipeline_state, &shader_binding_table, .{
        .width = 512,
        .height = 384,
    });
    try command_buffer.commit();

    std.debug.print("ray traced triangle runtime contract ok: backend={s}, as_size={}, scratch_size={}, groups={}, sbt_size={}, rays={}, metal_table_entries={}, as_built={}\n", .{
        @tagName(device.selectedBackend()),
        as_plan.result_size,
        as_plan.scratch_size,
        pipeline_state.functionTableEntryCount(),
        dispatch_plan.sbt_size,
        dispatch_plan.total_rays,
        metal_function_table_entries,
        acceleration_structure.isBuilt(),
    });
}
