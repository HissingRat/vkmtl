const core = @import("../../core.zig");
const metal = @import("metal_bridge");
const MetalBuffer = @import("buffer.zig");
const MetalClearScreen = @import("clear_screen.zig");
const MetalTexture = @import("texture.zig");

const MetalHeap = @This();

handle: *metal.vkmtl_metal_heap,
owner: *MetalClearScreen,

const Error = error{
    MetalUnsupported,
    InvalidHeap,
    CommandFailed,
    UnexpectedMetalStatus,
};

pub fn init(owner: *MetalClearScreen, descriptor: core.HeapDescriptor) !MetalHeap {
    var handle: ?*metal.vkmtl_metal_heap = null;
    try check(metal.vkmtl_metal_heap_create(
        owner.handle,
        descriptor.size,
        @intFromEnum(descriptor.storage_mode),
        &handle,
    ));
    return .{
        .handle = handle orelse return Error.InvalidHeap,
        .owner = owner,
    };
}

pub fn deinit(self: *MetalHeap) void {
    metal.vkmtl_metal_heap_destroy(self.handle);
}

pub fn bufferAllocationRequirements(
    self: MetalHeap,
    descriptor: core.BufferDescriptor,
) !core.HeapAllocationDescriptor {
    const length = try descriptor.resolvedLength();
    var size: u64 = 0;
    var alignment: u64 = 0;
    try check(metal.vkmtl_metal_heap_buffer_size_and_align(
        self.handle,
        length,
        &size,
        &alignment,
    ));
    return .{ .size = size, .alignment = alignment };
}

pub fn textureAllocationRequirements(
    self: MetalHeap,
    descriptor: core.TextureDescriptor,
) !core.HeapAllocationDescriptor {
    try descriptor.validate();
    var size: u64 = 0;
    var alignment: u64 = 0;
    try check(metal.vkmtl_metal_heap_texture_size_and_align(
        self.handle,
        MetalTexture.textureDimension(descriptor.dimension),
        MetalTexture.textureFormat(descriptor.format),
        descriptor.width,
        descriptor.height,
        descriptor.depth_or_array_layers,
        descriptor.mip_level_count,
        descriptor.sample_count,
        MetalTexture.usageFlags(descriptor.usage, descriptor.format),
        &size,
        &alignment,
    ));
    return .{ .size = size, .alignment = alignment };
}

pub fn makeBuffer(
    self: MetalHeap,
    descriptor: core.BufferDescriptor,
    allocation: core.HeapAllocationInfo,
) !MetalBuffer {
    return try MetalBuffer.initFromHeap(self.handle, descriptor, allocation);
}

pub fn makeTexture(
    self: MetalHeap,
    descriptor: core.TextureDescriptor,
    allocation: core.HeapAllocationInfo,
) !MetalTexture {
    return try MetalTexture.initFromHeap(self.handle, descriptor, allocation);
}

pub fn formatCapabilities(self: MetalHeap, format: core.TextureFormat) core.FormatCapabilities {
    return self.owner.formatCapabilities(format);
}

fn check(status: metal.vkmtl_metal_status) Error!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => Error.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_INVALID_BUFFER,
        metal.VKMTL_METAL_STATUS_INVALID_TEXTURE,
        => Error.InvalidHeap,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED => Error.CommandFailed,
        else => Error.UnexpectedMetalStatus,
    };
}
