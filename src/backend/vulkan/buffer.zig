const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const GraphicsContext = @import("graphics_context.zig");

const VulkanBuffer = @This();

gc: *const GraphicsContext,
handle: vk.Buffer,
memory: vk.DeviceMemory,
memory_offset: u64 = 0,
owns_memory: bool = true,
length_value: usize,
cpu_visible: bool,

pub const MappedRange = struct {
    bytes: []u8,
};

pub fn init(gc: *const GraphicsContext, descriptor: core.BufferDescriptor) !VulkanBuffer {
    const buffer_len = try descriptor.resolvedLength();
    const handle = try createHandle(gc, descriptor, buffer_len);
    errdefer gc.dev.destroyBuffer(handle, null);

    const mem_reqs = gc.dev.getBufferMemoryRequirements(handle);
    const memory = if (requiresDeviceAddress(descriptor.usage))
        try gc.allocateDeviceAddressable(mem_reqs, memoryFlags(descriptor))
    else
        try gc.allocate(mem_reqs, memoryFlags(descriptor));
    errdefer gc.dev.freeMemory(memory, null);

    try gc.dev.bindBufferMemory(handle, memory, 0);

    if (descriptor.bytes) |bytes| {
        const data = try gc.dev.mapMemory(memory, 0, @intCast(bytes.len), .{});
        defer gc.dev.unmapMemory(memory);

        const dst: [*]u8 = @ptrCast(@alignCast(data));
        @memcpy(dst[0..bytes.len], bytes);
    }

    return .{
        .gc = gc,
        .handle = handle,
        .memory = memory,
        .length_value = buffer_len,
        .cpu_visible = descriptor.storage_mode != .private,
    };
}

pub fn allocationRequirements(
    gc: *const GraphicsContext,
    descriptor: core.BufferDescriptor,
) !core.HeapAllocationDescriptor {
    const buffer_len = try descriptor.resolvedLength();
    const handle = try createHandle(gc, descriptor, buffer_len);
    defer gc.dev.destroyBuffer(handle, null);
    const requirements = gc.dev.getBufferMemoryRequirements(handle);
    return .{ .size = requirements.size, .alignment = requirements.alignment };
}

pub fn initFromHeap(
    gc: *const GraphicsContext,
    descriptor: core.BufferDescriptor,
    heap_memory: vk.DeviceMemory,
    heap_memory_type_index: u32,
    allocation: core.HeapAllocationInfo,
) !VulkanBuffer {
    const buffer_len = try descriptor.resolvedLength();
    const handle = try createHandle(gc, descriptor, buffer_len);
    errdefer gc.dev.destroyBuffer(handle, null);
    const requirements = gc.dev.getBufferMemoryRequirements(handle);
    if (requirements.memory_type_bits & (@as(u32, 1) << @intCast(heap_memory_type_index)) == 0) {
        return core.HeapError.HeapResourceIncompatible;
    }
    if (allocation.size < requirements.size or allocation.offset % requirements.alignment != 0) {
        return core.HeapError.HeapAllocationTooSmall;
    }
    try gc.dev.bindBufferMemory(handle, heap_memory, allocation.offset);

    if (descriptor.bytes) |bytes| {
        const data = try gc.dev.mapMemory(heap_memory, allocation.offset, @intCast(bytes.len), .{});
        defer gc.dev.unmapMemory(heap_memory);
        const dst: [*]u8 = @ptrCast(@alignCast(data));
        @memcpy(dst[0..bytes.len], bytes);
    }

    return .{
        .gc = gc,
        .handle = handle,
        .memory = heap_memory,
        .memory_offset = allocation.offset,
        .owns_memory = false,
        .length_value = buffer_len,
        .cpu_visible = descriptor.storage_mode != .private,
    };
}

pub fn deinit(self: *VulkanBuffer) void {
    self.gc.dev.destroyBuffer(self.handle, null);
    if (self.owns_memory) self.gc.dev.freeMemory(self.memory, null);
}

pub fn length(self: VulkanBuffer) usize {
    return self.length_value;
}

pub fn setLabel(self: *VulkanBuffer, label_value: ?[]const u8) void {
    self.gc.setDebugName(.buffer, GraphicsContext.debugObjectHandle(self.handle), label_value);
}

pub fn mapRange(self: *VulkanBuffer, descriptor: core.BufferMapDescriptor) !MappedRange {
    if (!self.cpu_visible) return core.BufferError.BufferNotCpuVisible;
    try descriptor.validate(self.length_value);

    const data = try self.gc.dev.mapMemory(
        self.memory,
        @intCast(self.memory_offset + descriptor.offset),
        @intCast(descriptor.length),
        .{},
    );
    const ptr: [*]u8 = @ptrCast(@alignCast(data));
    return .{ .bytes = ptr[0..descriptor.length] };
}

pub fn unmapRange(self: *VulkanBuffer, range: MappedRange) void {
    _ = range;
    self.gc.dev.unmapMemory(self.memory);
}

pub fn replaceBytes(self: *VulkanBuffer, offset: usize, bytes: []const u8) !void {
    if (!self.cpu_visible) return core.BufferError.BufferNotCpuVisible;
    try (core.BufferWriteDescriptor{
        .offset = offset,
        .bytes = bytes,
    }).validate(self.length_value);

    const data = try self.gc.dev.mapMemory(self.memory, @intCast(self.memory_offset + offset), @intCast(bytes.len), .{});
    defer self.gc.dev.unmapMemory(self.memory);

    const dst: [*]u8 = @ptrCast(@alignCast(data));
    @memcpy(dst[0..bytes.len], bytes);
}

pub fn readBytes(self: *VulkanBuffer, offset: usize, destination: []u8) !void {
    if (!self.cpu_visible) return core.BufferError.BufferNotCpuVisible;
    try (core.BufferReadDescriptor{
        .offset = offset,
        .destination = destination,
    }).validate(self.length_value);

    const data = try self.gc.dev.mapMemory(self.memory, @intCast(self.memory_offset + offset), @intCast(destination.len), .{});
    defer self.gc.dev.unmapMemory(self.memory);

    const src: [*]const u8 = @ptrCast(@alignCast(data));
    @memcpy(destination, src[0..destination.len]);
}

pub fn gpuAddress(self: VulkanBuffer) core.BufferError!u64 {
    var address: vk.DeviceAddress = 0;
    if (self.gc.dev.wrapper.dispatch.vkGetBufferDeviceAddressKHR != null) {
        address = self.gc.dev.getBufferDeviceAddressKHR(&.{ .buffer = self.handle });
    } else if (self.gc.dev.wrapper.dispatch.vkGetBufferDeviceAddress != null) {
        address = self.gc.dev.getBufferDeviceAddress(&.{ .buffer = self.handle });
    } else {
        return core.BufferError.UnsupportedBufferGpuAddress;
    }
    if (address == 0) return core.BufferError.BufferGpuAddressUnavailable;
    return address;
}

pub fn deviceAddress(self: VulkanBuffer) core.BufferError!u64 {
    return self.gpuAddress();
}

fn usageFlags(usage: core.BufferUsage) vk.BufferUsageFlags {
    var flags = vk.BufferUsageFlags{};

    if (usage.copy_source) flags.transfer_src_bit = true;
    if (usage.copy_destination) flags.transfer_dst_bit = true;
    if (usage.vertex) flags.vertex_buffer_bit = true;
    if (usage.index) flags.index_buffer_bit = true;
    if (usage.uniform) flags.uniform_buffer_bit = true;
    if (usage.storage) flags.storage_buffer_bit = true;
    if (usage.indirect) flags.indirect_buffer_bit = true;
    if (usage.acceleration_structure_scratch) {
        flags.storage_buffer_bit = true;
        flags.shader_device_address_bit = true;
    }
    if (usage.acceleration_structure_build_input) {
        flags.acceleration_structure_build_input_read_only_bit_khr = true;
        flags.shader_device_address_bit = true;
    }
    if (usage.shader_binding_table) {
        flags.shader_binding_table_bit_khr = true;
        flags.shader_device_address_bit = true;
    }
    if (usage.shader_device_address) flags.shader_device_address_bit = true;

    if (usage.isEmpty()) {
        flags.transfer_dst_bit = true;
    }

    return flags;
}

fn createHandle(gc: *const GraphicsContext, descriptor: core.BufferDescriptor, buffer_len: usize) !vk.Buffer {
    const queue_families = gc.workQueueFamilies();
    return try gc.dev.createBuffer(&.{
        .size = @intCast(buffer_len),
        .usage = usageFlags(descriptor.usage),
        .sharing_mode = if (queue_families.count > 1) .concurrent else .exclusive,
        .queue_family_index_count = queue_families.count,
        .p_queue_family_indices = &queue_families.values,
    }, null);
}

fn requiresDeviceAddress(usage: core.BufferUsage) bool {
    return usage.acceleration_structure_scratch or
        usage.acceleration_structure_build_input or
        usage.shader_binding_table or
        usage.shader_device_address;
}

fn memoryFlags(descriptor: core.BufferDescriptor) vk.MemoryPropertyFlags {
    if (descriptor.storage_mode == .private) {
        return .{ .device_local_bit = true };
    }
    return .{
        .host_visible_bit = true,
        .host_coherent_bit = true,
    };
}

test "Vulkan buffer GPU address usage requests native usage and allocation flags" {
    const usage = core.BufferUsage{ .shader_device_address = true };
    try std.testing.expect(usageFlags(usage).shader_device_address_bit);
    try std.testing.expect(requiresDeviceAddress(usage));
}
