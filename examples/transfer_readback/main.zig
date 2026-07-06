const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl transfer readback";
const pixels = [_]u8{
    0xf5, 0x4e, 0x42, 0xff,
    0xff, 0xd1, 0x4a, 0xff,
    0x28, 0xd6, 0x7a, 0xff,
    0x46, 0x95, 0xff, 0xff,
};

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 64,
        .height = 64,
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

    var device = context.device();
    var queue = context.queue();

    var source_buffer = try device.makeBuffer(.{
        .bytes = pixels[0..],
        .usage = .{ .copy_source = true },
        .storage_mode = .shared,
    });
    defer source_buffer.deinit();

    var buffer_readback = try device.makeBuffer(.{
        .length = pixels.len,
        .usage = .{ .copy_destination = true },
        .storage_mode = .shared,
    });
    defer buffer_readback.deinit();

    var texture = try device.makeTexture(.{
        .format = .rgba8_unorm,
        .width = 2,
        .height = 2,
        .usage = .{
            .copy_source = true,
            .copy_destination = true,
        },
        .storage_mode = .private,
    });
    defer texture.deinit();

    var texture_readback = try device.makeBuffer(.{
        .length = pixels.len,
        .usage = .{ .copy_destination = true },
        .storage_mode = .shared,
    });
    defer texture_readback.deinit();

    var command_buffer = try queue.makeCommandBuffer();
    var blit = try command_buffer.makeBlitCommandEncoder();
    try blit.copyBufferToBuffer(&source_buffer, &buffer_readback, .{
        .size = pixels.len,
    });
    try blit.copyBufferToTexture(&source_buffer, &texture, .{
        .destination_region = .{ .size = .{ .width = 2, .height = 2 } },
    });
    try blit.copyTextureToBuffer(&texture, &texture_readback, .{
        .source_region = .{ .size = .{ .width = 2, .height = 2 } },
    });
    try blit.endEncoding();
    try command_buffer.commit();

    var copied_buffer: [pixels.len]u8 = undefined;
    try buffer_readback.readBytes(0, copied_buffer[0..]);
    if (!std.mem.eql(u8, pixels[0..], copied_buffer[0..])) {
        return error.BufferCopyMismatch;
    }

    var copied_texture: [pixels.len]u8 = undefined;
    try texture_readback.readBytes(0, copied_texture[0..]);
    if (!std.mem.eql(u8, pixels[0..], copied_texture[0..])) {
        return error.TextureCopyMismatch;
    }

    std.debug.print("transfer readback ok\n", .{});
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    if (std.ascii.eqlIgnoreCase(value, "vulkan")) return .vulkan;
    if (std.ascii.eqlIgnoreCase(value, "metal")) return .metal;

    std.debug.print("Ignoring unsupported VKMTL_BACKEND value: {s}\n", .{value});
    return null;
}
