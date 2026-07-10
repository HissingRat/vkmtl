const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl GPU soak";
const shader_source = @embedFile("shaders/soak.slang");
const texture_width = 4;
const texture_height = 4;
const tight_bytes_per_row = texture_width * 4;

const Options = struct {
    iterations: u32 = 120,
    resize_interval: u32 = 8,
    shader_interval: u32 = 16,
    backend: ?vkmtl.Backend = null,
};

pub fn main(init: std.process.Init) !void {
    run(init) catch |err| {
        std.debug.print("gpu soak failed: {s} category={s}\n", .{
            @errorName(err),
            @tagName(vkmtl.classifyError(err)),
        });
        return err;
    };
}

fn run(init: std.process.Init) !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();
    _ = args.skip();
    var options = try parseOptions(&args);
    if (options.backend == null) options.backend = backendOverrideFromEnv();

    try glfw.init();
    defer glfw.terminate();
    const window = try glfw.createWindow(.{
        .width = 96,
        .height = 96,
        .title = app_name,
    });
    defer glfw.destroyWindow(window);

    var context = try vkmtl.WindowContext.init(allocator, .{
        .app_name = app_name,
        .backend = .auto,
        .debug_backend_override = options.backend,
        .surface = common.surfaceDescriptor(window),
        .presentation = common.presentationDescriptor(window, .fifo),
    });
    defer context.deinit();

    var device = context.device();
    var queue = context.queue();
    var swapchain = context.swapchain();
    var residency_map = vkmtl.SparseResidencyMap.init(allocator);
    defer residency_map.deinit();
    const row_alignment: usize = @max(
        1,
        @as(usize, device.limits().buffer_texture_copy_row_pitch_alignment),
    );
    const bytes_per_row = std.mem.alignForward(usize, tight_bytes_per_row, row_alignment);
    const transfer_bytes = bytes_per_row * texture_height;

    var resize_events: u64 = 0;
    var shader_resolutions: u64 = 0;
    var upload_readbacks: u64 = 0;
    var residency_churn_cycles: u64 = 0;
    var max_live_resources: usize = 0;
    var last_submitted_serial: u64 = 0;

    var iteration: u32 = 0;
    while (iteration < options.iterations) : (iteration += 1) {
        std.debug.print("gpu soak iteration {}/{} backend={s}\n", .{
            iteration + 1,
            options.iterations,
            @tagName(context.selectedBackend()),
        });

        if (iteration % options.resize_interval == 0) {
            const logical_size: c_int = if ((iteration / options.resize_interval) % 2 == 0) 96 else 112;
            glfw.c.glfwSetWindowSize(window, logical_size, logical_size);
            glfw.pollEvents();
            const extent = common.framebufferExtent(window);
            if (!extent.isZero()) try swapchain.resize(extent);
            resize_events += 1;
        }

        try swapchain.clear(.{
            .red = 0.01 + @as(f32, @floatFromInt(iteration % 5)) * 0.01,
            .green = 0.02,
            .blue = 0.03,
            .alpha = 1.0,
        });

        if (iteration % options.shader_interval == 0) {
            var compiled = try device.compileComputeShader("gpu_soak", shader_source, .{
                .entry = "cs_main",
            });
            compiled.deinit();
            shader_resolutions += 1;
        }

        {
            const source_bytes = try allocator.alloc(u8, transfer_bytes);
            defer allocator.free(source_bytes);
            fillPattern(source_bytes, bytes_per_row, iteration);

            var source = try device.makeBuffer(.{
                .label = "gpu soak source",
                .bytes = source_bytes,
                .usage = .{ .copy_source = true },
                .storage_mode = .shared,
            });
            defer source.deinit();
            var buffer_readback = try device.makeBuffer(.{
                .label = "gpu soak buffer readback",
                .length = transfer_bytes,
                .usage = .{ .copy_destination = true },
                .storage_mode = .shared,
            });
            defer buffer_readback.deinit();
            var texture = try device.makeTexture(.{
                .label = "gpu soak texture",
                .format = .rgba8_unorm,
                .width = texture_width,
                .height = texture_height,
                .usage = .{ .copy_source = true, .copy_destination = true },
                .storage_mode = .private,
            });
            defer texture.deinit();
            var texture_readback = try device.makeBuffer(.{
                .label = "gpu soak texture readback",
                .length = transfer_bytes,
                .usage = .{ .copy_destination = true },
                .storage_mode = .shared,
            });
            defer texture_readback.deinit();

            max_live_resources = @max(max_live_resources, device.runtimeDiagnostics().live_resources);

            var command_buffer = try queue.makeCommandBuffer();
            var blit = try command_buffer.makeBlitCommandEncoder();
            try blit.copyBufferToBuffer(&source, &buffer_readback, .{ .size = transfer_bytes });
            try blit.copyBufferToTexture(&source, &texture, .{
                .destination_region = .{ .size = .{
                    .width = texture_width,
                    .height = texture_height,
                } },
                .source = .{ .bytes_per_row = bytes_per_row },
            });
            try blit.copyTextureToBuffer(&texture, &texture_readback, .{
                .source_region = .{ .size = .{
                    .width = texture_width,
                    .height = texture_height,
                } },
                .destination = .{ .bytes_per_row = bytes_per_row },
            });
            try blit.endEncoding();
            try command_buffer.commit();

            const copied_buffer = try allocator.alloc(u8, transfer_bytes);
            defer allocator.free(copied_buffer);
            try buffer_readback.readBytes(0, copied_buffer);
            if (!std.mem.eql(u8, source_bytes, copied_buffer)) return error.GpuSoakBufferReadbackMismatch;

            const copied_texture = try allocator.alloc(u8, transfer_bytes);
            defer allocator.free(copied_texture);
            try texture_readback.readBytes(0, copied_texture);
            try validateTextureRows(source_bytes, copied_texture, bytes_per_row);
            upload_readbacks += 1;
        }

        const diagnostics = device.runtimeDiagnostics();
        if (diagnostics.live_resources != 0) return error.GpuSoakLiveResourceLeak;
        if (diagnostics.pending_retirements != 0) return error.GpuSoakPendingRetirements;
        if (diagnostics.completed_work_serial < diagnostics.submitted_work_serial) return error.GpuSoakIncompleteWork;
        if (diagnostics.submitted_work_serial < last_submitted_serial) return error.GpuSoakWorkSerialRegression;
        last_submitted_serial = diagnostics.submitted_work_serial;

        const resident = [_]vkmtl.SparseBufferMappingDescriptor{.{
            .offset = 0,
            .size = 4096,
            .page_size = 4096,
            .residency = .resident,
        }};
        const evicted = [_]vkmtl.SparseBufferMappingDescriptor{.{
            .offset = 0,
            .size = 4096,
            .page_size = 4096,
            .residency = .evicted,
        }};
        try residency_map.apply(.{ .buffers = resident[0..] });
        try residency_map.apply(.{ .buffers = evicted[0..] });
        const residency = residency_map.diagnostics();
        if (residency.buffer_regions != 0 or residency.resident_buffer_bytes != 0) {
            return error.GpuSoakResidencyStateLeak;
        }
        residency_churn_cycles += 1;
        glfw.pollEvents();
    }

    const budget = try device.memoryBudgetReport(.{
        .budget_bytes = 64 * 1024 * 1024,
        .explicit_usage_bytes = transfer_bytes * 4,
    });
    const diagnostics = device.runtimeDiagnostics();
    std.debug.print("gpu soak ok\n", .{});
    std.debug.print("backend: {s}\n", .{@tagName(context.selectedBackend())});
    std.debug.print("iterations: {}\n", .{options.iterations});
    std.debug.print("resize events: {}\n", .{resize_events});
    std.debug.print("shader resolutions: {}\n", .{shader_resolutions});
    std.debug.print("upload/readback cycles: {}\n", .{upload_readbacks});
    std.debug.print("portable residency churn cycles: {}\n", .{residency_churn_cycles});
    std.debug.print("max live resources: {}\n", .{max_live_resources});
    std.debug.print("submitted/completed serial: {}/{}\n", .{
        diagnostics.submitted_work_serial,
        diagnostics.completed_work_serial,
    });
    std.debug.print("memory budget source: {s}\n", .{@tagName(budget.source)});
    std.debug.print("memory pressure: {s}\n", .{@tagName(budget.pressure)});
}

fn fillPattern(bytes: []u8, bytes_per_row: usize, iteration: u32) void {
    @memset(bytes, 0xcd);
    var y: usize = 0;
    while (y < texture_height) : (y += 1) {
        var x: usize = 0;
        while (x < texture_width) : (x += 1) {
            const offset = y * bytes_per_row + x * 4;
            bytes[offset + 0] = @truncate(iteration + @as(u32, @intCast(x * 17)));
            bytes[offset + 1] = @truncate(iteration + @as(u32, @intCast(y * 29)));
            bytes[offset + 2] = @truncate(iteration + @as(u32, @intCast((x + y) * 11)));
            bytes[offset + 3] = 0xff;
        }
    }
}

fn validateTextureRows(expected: []const u8, actual: []const u8, bytes_per_row: usize) !void {
    var y: usize = 0;
    while (y < texture_height) : (y += 1) {
        const offset = y * bytes_per_row;
        if (!std.mem.eql(
            u8,
            expected[offset .. offset + tight_bytes_per_row],
            actual[offset .. offset + tight_bytes_per_row],
        )) return error.GpuSoakTextureReadbackMismatch;
    }
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options = Options{};
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--iterations=")) {
            options.iterations = try std.fmt.parseUnsigned(u32, arg["--iterations=".len..], 10);
        } else if (std.mem.startsWith(u8, arg, "--resize-interval=")) {
            options.resize_interval = try std.fmt.parseUnsigned(u32, arg["--resize-interval=".len..], 10);
        } else if (std.mem.startsWith(u8, arg, "--shader-interval=")) {
            options.shader_interval = try std.fmt.parseUnsigned(u32, arg["--shader-interval=".len..], 10);
        } else if (std.mem.startsWith(u8, arg, "--backend=")) {
            options.backend = try parseBackend(arg["--backend=".len..]);
        } else {
            return error.UnknownArgument;
        }
    }
    if (options.iterations == 0) return error.InvalidIterations;
    if (options.resize_interval == 0) return error.InvalidResizeInterval;
    if (options.shader_interval == 0) return error.InvalidShaderInterval;
    return options;
}

fn parseBackend(value: []const u8) !vkmtl.Backend {
    if (std.mem.eql(u8, value, "vulkan")) return .vulkan;
    if (std.mem.eql(u8, value, "metal")) return .metal;
    return error.InvalidBackend;
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    return parseBackend(value) catch null;
}
