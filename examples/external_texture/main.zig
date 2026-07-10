const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl external texture";

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
    const handle_kind: vkmtl.ExternalHandleKind = switch (device.selectedBackend()) {
        .vulkan => .vulkan_image,
        .metal => .metal_texture,
    };
    const interop_matrix = device.externalInteropCapabilityMatrix();
    if (interop_matrix.find(.texture, handle_kind)) |entry| {
        std.debug.print("external texture capability: backend={s}, platform={s}, handle={s}, lane={s}, enabled={}\n", .{
            @tagName(device.selectedBackend()),
            @tagName(interop_matrix.platform),
            @tagName(handle_kind),
            @tagName(entry.lane),
            interop_matrix.entryEnabled(entry),
        });
    }

    const external_texture_descriptor = vkmtl.ExternalTextureDescriptor{
        .label = "example external texture",
        .handle = .{
            .kind = handle_kind,
            .value = 1,
            .backend = device.selectedBackend(),
        },
        .format = .rgba8_unorm,
        .width = 64,
        .height = 64,
        .usage = .{
            .shader_read = true,
            .copy_source = true,
            .copy_destination = true,
            .render_attachment = true,
        },
    };
    const usage_plan = device.planExternalTextureUsage(.{
        .texture = external_texture_descriptor,
        .sample = true,
        .copy_source = true,
        .copy_destination = true,
        .present = true,
    }) catch |err| {
        std.debug.print("external texture usage unsupported: {s}\n", .{@errorName(err)});
        return;
    };

    var texture = device.makeExternalTexture(external_texture_descriptor) catch |err| {
        std.debug.print("external texture unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    defer texture.deinit();

    const descriptor = texture.textureDescriptor();
    std.debug.print("external texture wrapper ok: backend={s}, format={s}, extent={}x{}, ownership={s}, lane={s}, sample={}, copy={}, present={}\n", .{
        @tagName(texture.selectedBackend()),
        @tagName(descriptor.format),
        descriptor.width,
        descriptor.height,
        @tagName(texture.ownership()),
        @tagName(usage_plan.import_plan.lane),
        usage_plan.requiresSampling(),
        usage_plan.requiresCopy(),
        usage_plan.requiresPresentation(),
    });
}
