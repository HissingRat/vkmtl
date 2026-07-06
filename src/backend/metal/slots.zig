const core = @import("../../core.zig");

pub const vertex_buffer_slot_base: u32 = 16;
pub const max_metal_buffer_slots: u32 = 31;

pub fn vertexBufferSlot(binding: core.VertexBufferBinding) core.CommandEncodingError!u32 {
    try binding.validate();
    return vertexBufferSlotUnchecked(binding.index) orelse core.CommandEncodingError.InvalidVertexBufferIndex;
}

pub fn vertexBufferSlotUnchecked(index: u32) ?u32 {
    const native_index = vertex_buffer_slot_base + index;
    if (native_index >= max_metal_buffer_slots) return null;
    return native_index;
}

test "metal vertex buffers use slots above shader resource buffers" {
    try @import("std").testing.expectEqual(@as(u32, 16), vertexBufferSlotUnchecked(0).?);
    try @import("std").testing.expectEqual(@as(u32, 30), vertexBufferSlotUnchecked(14).?);
    try @import("std").testing.expectEqual(@as(?u32, null), vertexBufferSlotUnchecked(15));
}
