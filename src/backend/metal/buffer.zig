const core = @import("../../core.zig");
const debug = @import("debug.zig");
const metal = @import("metal_bridge");
const MetalClearScreen = @import("clear_screen.zig");

const MetalBuffer = @This();

handle: *metal.vkmtl_metal_buffer,
length_value: usize,
storage_mode: core.ResourceStorageMode,

const Error = error{
    MetalUnsupported,
    InvalidBuffer,
    CommandFailed,
    UnexpectedMetalStatus,
};

pub const MappedRange = struct {
    bytes: []u8,
    offset: usize,
    write: bool,
};

pub fn init(owner: *MetalClearScreen, descriptor: core.BufferDescriptor) !MetalBuffer {
    const buffer_len = try descriptor.resolvedLength();
    const bytes = descriptor.bytes;

    var handle: ?*metal.vkmtl_metal_buffer = null;
    try check(metal.vkmtl_metal_buffer_create(
        owner.handle,
        buffer_len,
        if (bytes) |data| data.ptr else null,
        if (bytes) |data| data.len else 0,
        storageMode(descriptor.storage_mode),
        &handle,
    ));

    const raw_handle = handle orelse return Error.InvalidBuffer;
    return .{
        .handle = raw_handle,
        .length_value = metal.vkmtl_metal_buffer_length(raw_handle),
        .storage_mode = descriptor.storage_mode,
    };
}

pub fn deinit(self: *MetalBuffer) void {
    metal.vkmtl_metal_buffer_destroy(self.handle);
}

pub fn length(self: MetalBuffer) usize {
    return self.length_value;
}

pub fn gpuAddress(self: MetalBuffer) core.BufferError!u64 {
    var address: u64 = 0;
    const status = metal.vkmtl_metal_buffer_gpu_address(self.handle, &address);
    if (status == metal.VKMTL_METAL_STATUS_UNSUPPORTED) {
        return core.BufferError.UnsupportedBufferGpuAddress;
    }
    if (status != metal.VKMTL_METAL_STATUS_OK or address == 0) {
        return core.BufferError.BufferGpuAddressUnavailable;
    }
    return address;
}

pub fn setLabel(self: *MetalBuffer, label_value: ?[]const u8) void {
    debug.ignore(metal.vkmtl_metal_buffer_set_label(
        self.handle,
        debug.labelPtr(label_value),
        debug.labelLen(label_value),
    ));
}

pub fn mapRange(self: *MetalBuffer, descriptor: core.BufferMapDescriptor) !MappedRange {
    if (!self.storage_mode.cpuVisible()) return core.BufferError.BufferNotCpuVisible;
    try descriptor.validate(self.length_value);

    var contents: ?*anyopaque = null;
    try check(metal.vkmtl_metal_buffer_contents(self.handle, &contents));
    const base: [*]u8 = @ptrCast(@alignCast(contents orelse return Error.InvalidBuffer));
    return .{
        .bytes = base[descriptor.offset..][0..descriptor.length],
        .offset = descriptor.offset,
        .write = descriptor.mode.write,
    };
}

pub fn unmapRange(self: *MetalBuffer, range: MappedRange) !void {
    if (range.write) {
        try check(metal.vkmtl_metal_buffer_did_modify_range(
            self.handle,
            range.offset,
            range.bytes.len,
        ));
    }
}

pub fn replaceBytes(self: *MetalBuffer, offset: usize, bytes: []const u8) !void {
    try (core.BufferWriteDescriptor{
        .offset = offset,
        .bytes = bytes,
    }).validate(self.length_value);
    try check(metal.vkmtl_metal_buffer_replace_bytes(
        self.handle,
        offset,
        bytes.ptr,
        bytes.len,
    ));
}

pub fn readBytes(self: *MetalBuffer, offset: usize, destination: []u8) !void {
    try (core.BufferReadDescriptor{
        .offset = offset,
        .destination = destination,
    }).validate(self.length_value);
    try check(metal.vkmtl_metal_buffer_read_bytes(
        self.handle,
        offset,
        destination.ptr,
        destination.len,
    ));
}

fn storageMode(mode: core.ResourceStorageMode) metal.vkmtl_metal_storage_mode {
    return switch (mode) {
        .automatic => metal.VKMTL_METAL_STORAGE_MODE_AUTOMATIC,
        .shared => metal.VKMTL_METAL_STORAGE_MODE_SHARED,
        .managed => metal.VKMTL_METAL_STORAGE_MODE_MANAGED,
        .private => metal.VKMTL_METAL_STORAGE_MODE_PRIVATE,
    };
}

fn check(status: metal.vkmtl_metal_status) Error!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => Error.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_INVALID_BUFFER => Error.InvalidBuffer,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED => Error.CommandFailed,
        else => Error.UnexpectedMetalStatus,
    };
}
