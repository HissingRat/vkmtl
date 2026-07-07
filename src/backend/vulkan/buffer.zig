const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const GraphicsContext = @import("graphics_context.zig");

const VulkanBuffer = @This();

gc: *const GraphicsContext,
handle: vk.Buffer,
memory: vk.DeviceMemory,
length_value: usize,
cpu_visible: bool,

pub const MappedRange = struct {
    bytes: []u8,
};

pub fn init(gc: *const GraphicsContext, descriptor: core.BufferDescriptor) !VulkanBuffer {
    const buffer_len = try descriptor.resolvedLength();

    const handle = try gc.dev.createBuffer(&.{
        .size = @intCast(buffer_len),
        .usage = usageFlags(descriptor.usage),
        .sharing_mode = .exclusive,
    }, null);
    errdefer gc.dev.destroyBuffer(handle, null);

    const mem_reqs = gc.dev.getBufferMemoryRequirements(handle);
    const memory = try gc.allocate(mem_reqs, memoryFlags(descriptor));
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

pub fn deinit(self: *VulkanBuffer) void {
    self.gc.dev.destroyBuffer(self.handle, null);
    self.gc.dev.freeMemory(self.memory, null);
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
        @intCast(descriptor.offset),
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

    const data = try self.gc.dev.mapMemory(self.memory, @intCast(offset), @intCast(bytes.len), .{});
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

    const data = try self.gc.dev.mapMemory(self.memory, @intCast(offset), @intCast(destination.len), .{});
    defer self.gc.dev.unmapMemory(self.memory);

    const src: [*]const u8 = @ptrCast(@alignCast(data));
    @memcpy(destination, src[0..destination.len]);
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

    if (usage.isEmpty()) {
        flags.transfer_dst_bit = true;
    }

    return flags;
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
