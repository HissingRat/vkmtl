const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const VulkanBuffer = @import("buffer.zig");
const GraphicsContext = @import("graphics_context.zig");
const VulkanTexture = @import("texture.zig");

const VulkanHeap = @This();

gc: *const GraphicsContext,
memory: vk.DeviceMemory,
memory_type_index: u32,
descriptor: core.HeapDescriptor,

pub fn init(gc: *const GraphicsContext, descriptor: core.HeapDescriptor) !VulkanHeap {
    const flags = memoryFlags(descriptor.storage_mode);
    const memory_type_index = try gc.findMemoryTypeIndex(std.math.maxInt(u32), flags);
    var address_flags = vk.MemoryAllocateFlagsInfo{
        .flags = .{ .device_address_bit = true },
        .device_mask = 0,
    };
    const memory = try gc.dev.allocateMemory(&.{
        .p_next = if (gc.features().buffer_gpu_address) &address_flags else null,
        .allocation_size = descriptor.size,
        .memory_type_index = memory_type_index,
    }, null);
    return .{
        .gc = gc,
        .memory = memory,
        .memory_type_index = memory_type_index,
        .descriptor = descriptor,
    };
}

pub fn deinit(self: *VulkanHeap) void {
    self.gc.dev.freeMemory(self.memory, null);
    self.memory = .null_handle;
}

pub fn bufferAllocationRequirements(
    self: VulkanHeap,
    descriptor: core.BufferDescriptor,
) !core.HeapAllocationDescriptor {
    try self.validateBufferCompatibility(descriptor);
    return try VulkanBuffer.allocationRequirements(self.gc, descriptor);
}

pub fn textureAllocationRequirements(
    self: VulkanHeap,
    descriptor: core.TextureDescriptor,
) !core.HeapAllocationDescriptor {
    try self.validateTextureCompatibility(descriptor);
    return try VulkanTexture.allocationRequirements(self.gc, descriptor);
}

pub fn makeBuffer(
    self: VulkanHeap,
    descriptor: core.BufferDescriptor,
    allocation: core.HeapAllocationInfo,
) !VulkanBuffer {
    try self.validateBufferCompatibility(descriptor);
    return try VulkanBuffer.initFromHeap(
        self.gc,
        descriptor,
        self.memory,
        self.memory_type_index,
        allocation,
    );
}

pub fn makeTexture(
    self: VulkanHeap,
    descriptor: core.TextureDescriptor,
    allocation: core.HeapAllocationInfo,
) !VulkanTexture {
    try self.validateTextureCompatibility(descriptor);
    return try VulkanTexture.initFromHeap(
        self.gc,
        descriptor,
        self.memory,
        self.memory_type_index,
        allocation,
    );
}

fn validateBufferCompatibility(self: VulkanHeap, descriptor: core.BufferDescriptor) !void {
    _ = try descriptor.resolvedLength();
    switch (self.descriptor.storage_mode) {
        .automatic, .device_local => if (descriptor.storage_mode != .private) {
            return core.HeapError.HeapResourceIncompatible;
        },
        .cpu_visible => if (descriptor.storage_mode == .private or descriptor.storage_mode == .memoryless) {
            return core.HeapError.HeapResourceIncompatible;
        },
    }
}

fn validateTextureCompatibility(self: VulkanHeap, descriptor: core.TextureDescriptor) !void {
    try descriptor.validate();
    if (self.descriptor.storage_mode == .cpu_visible or descriptor.storage_mode != .private) {
        return core.HeapError.HeapResourceIncompatible;
    }
}

fn memoryFlags(storage_mode: core.HeapStorageMode) vk.MemoryPropertyFlags {
    return switch (storage_mode) {
        .automatic, .device_local => .{ .device_local_bit = true },
        .cpu_visible => .{ .host_visible_bit = true, .host_coherent_bit = true },
    };
}
