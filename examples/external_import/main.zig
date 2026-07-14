const std = @import("std");
const vkmtl = @import("vkmtl");

extern fn vkmtl_example_metal_buffer_create(length: usize, value: u8) ?*anyopaque;
extern fn vkmtl_example_objc_release(object: ?*anyopaque) void;
extern fn vkmtl_example_metal_texture_create(width: u32, height: u32, value: u8) ?*anyopaque;
extern fn vkmtl_example_iosurface_create(width: u32, height: u32, value: u8) ?*anyopaque;
extern fn vkmtl_example_iosurface_release(surface: ?*anyopaque) void;

const buffer_length = 256;
const buffer_value = 0x3c;
const texture_width = 64;
const texture_height = 4;
const texture_value = 0x5a;
const raw_texture_value = 0x4d;
const texture_bytes_per_row = texture_width * 4;
const texture_bytes = texture_bytes_per_row * texture_height;

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();

    var context = try vkmtl.HeadlessContext.init(debug_allocator.allocator(), .{
        .app_name = "vkmtl external import",
        .backend = .metal,
    });
    defer context.deinit();

    var device = context.device();
    var queue = context.queue();
    if (device.selectedBackend() != .metal or
        !device.features().external_memory or
        !device.features().external_textures)
    {
        return error.ExternalImportUnavailable;
    }

    try verifyBufferImport(&device, &queue);
    try verifyRawTextureImport(&device, &queue);
    try verifyIOSurfaceImport(&device, &queue);

    const topology = vkmtl.diagnostics.deviceTopology(device);
    std.debug.print(
        "external import ok: identity={s}, peer_count={}\n",
        .{ @tagName(topology.identity_kind), topology.peer_count },
    );
}

fn verifyRawTextureImport(device: *vkmtl.Device, queue: *vkmtl.Queue) !void {
    const native_texture = vkmtl_example_metal_texture_create(texture_width, texture_height, raw_texture_value) orelse
        return error.NativeTextureCreationFailed;
    defer vkmtl_example_objc_release(native_texture);

    var external = try device.makeExternalTexture(.{
        .label = "borrowed MTLTexture",
        .handle = .{
            .kind = .metal_texture,
            .value = @intFromPtr(native_texture),
            .backend = .metal,
        },
        .format = .bgra8_unorm,
        .width = texture_width,
        .height = texture_height,
        .usage = .{ .copy_source = true },
        .storage_mode = .shared,
        .ownership = .borrowed,
    });
    defer external.deinit();
    if (!external.hasImportedTexture()) return error.MissingImportedTexture;
    try copyAndVerifyTexture(device, queue, try external.importedTexture(), raw_texture_value);
}

fn verifyBufferImport(device: *vkmtl.Device, queue: *vkmtl.Queue) !void {
    const native_buffer = vkmtl_example_metal_buffer_create(buffer_length, buffer_value) orelse
        return error.NativeBufferCreationFailed;
    defer vkmtl_example_objc_release(native_buffer);

    var external = try device.makeExternalBuffer(.{
        .label = "borrowed MTLBuffer",
        .handle = .{
            .kind = .metal_buffer,
            .value = @intFromPtr(native_buffer),
            .backend = .metal,
        },
        .length = buffer_length,
        .usage = .{ .copy_source = true },
        .storage_mode = .shared,
        .ownership = .borrowed,
    });
    defer external.deinit();
    if (!external.hasImportedBuffer()) return error.MissingImportedBuffer;
    const imported = try external.importedBuffer();

    var readback = try device.makeBuffer(.{
        .length = buffer_length,
        .usage = .{ .copy_destination = true },
        .storage_mode = .shared,
    });
    defer readback.deinit();

    var command_buffer = try queue.makeCommandBuffer();
    var blit = try command_buffer.makeBlitCommandEncoder();
    try blit.copyBufferToBuffer(imported, &readback, .{ .size = buffer_length });
    try blit.endEncoding();
    try command_buffer.commit();

    var copied: [buffer_length]u8 = undefined;
    try readback.readBytes(0, copied[0..]);
    for (copied) |byte| if (byte != buffer_value) return error.ExternalBufferReadbackMismatch;
}

fn verifyIOSurfaceImport(device: *vkmtl.Device, queue: *vkmtl.Queue) !void {
    const surface = vkmtl_example_iosurface_create(texture_width, texture_height, texture_value) orelse
        return error.IOSurfaceCreationFailed;
    defer vkmtl_example_iosurface_release(surface);

    var external = try device.makeExternalTexture(.{
        .label = "borrowed IOSurface",
        .handle = .{
            .kind = .iosurface,
            .value = @intFromPtr(surface),
            .backend = .metal,
        },
        .format = .bgra8_unorm,
        .width = texture_width,
        .height = texture_height,
        .usage = .{ .copy_source = true },
        .storage_mode = .shared,
        .ownership = .borrowed,
    });
    defer external.deinit();
    if (!external.hasImportedTexture()) return error.MissingImportedTexture;
    try copyAndVerifyTexture(device, queue, try external.importedTexture(), texture_value);
}

fn copyAndVerifyTexture(device: *vkmtl.Device, queue: *vkmtl.Queue, imported: *vkmtl.Texture, expected: u8) !void {
    var readback = try device.makeBuffer(.{
        .length = texture_bytes,
        .usage = .{ .copy_destination = true },
        .storage_mode = .shared,
    });
    defer readback.deinit();

    var command_buffer = try queue.makeCommandBuffer();
    var blit = try command_buffer.makeBlitCommandEncoder();
    try blit.copyTextureToBuffer(imported, &readback, .{
        .source_region = .{
            .size = .{ .width = texture_width, .height = texture_height },
        },
        .destination = .{ .bytes_per_row = texture_bytes_per_row },
    });
    try blit.endEncoding();
    try command_buffer.commit();

    var copied: [texture_bytes]u8 = undefined;
    try readback.readBytes(0, copied[0..]);
    for (copied) |byte| if (byte != expected) return error.ExternalTextureReadbackMismatch;
}
