const builtin = @import("builtin");
const core = @import("../../core.zig");
const debug = @import("debug.zig");
const metal = @import("metal_bridge");
const MetalClearScreen = @import("clear_screen.zig");

const MetalIndirectCommandBuffer = @This();

handle: ?*metal.vkmtl_metal_indirect_command_buffer,
kind: core.IndirectCommandKind,

pub fn init(owner: *MetalClearScreen, descriptor: core.IndirectCommandBufferDescriptor) !MetalIndirectCommandBuffer {
    var handle: ?*metal.vkmtl_metal_indirect_command_buffer = null;
    const status = metal.vkmtl_metal_indirect_command_buffer_create(
        owner.handle,
        @intFromEnum(descriptor.kind),
        descriptor.max_command_count,
        &handle,
    );
    if (status != metal.VKMTL_METAL_STATUS_OK and status != metal.VKMTL_METAL_STATUS_UNSUPPORTED and !builtin.is_test) try check(status);
    return .{ .handle = handle, .kind = descriptor.kind };
}

pub fn deinit(self: *MetalIndirectCommandBuffer) void {
    if (self.handle) |handle| metal.vkmtl_metal_indirect_command_buffer_destroy(handle);
}

pub fn setLabel(self: *MetalIndirectCommandBuffer, label: ?[]const u8) void {
    const handle = self.handle orelse return;
    debug.ignore(metal.vkmtl_metal_indirect_command_buffer_set_label(
        handle,
        debug.labelPtr(label),
        debug.labelLen(label),
    ));
}

pub fn reset(self: *MetalIndirectCommandBuffer, range: core.IndirectCommandRange) !void {
    const handle = self.handle orelse return;
    try check(metal.vkmtl_metal_indirect_command_buffer_reset(handle, range.location, range.count));
}

pub fn encodeDraw(self: *MetalIndirectCommandBuffer, command_index: u32, descriptor: core.DrawPrimitivesDescriptor) !void {
    const handle = self.handle orelse return;
    try check(metal.vkmtl_metal_indirect_command_buffer_encode_draw(
        handle,
        command_index,
        @intFromEnum(descriptor.primitive_type),
        descriptor.vertex_start,
        descriptor.vertex_count,
        descriptor.instance_count,
        descriptor.base_instance,
    ));
}

pub fn encodeDispatch(self: *MetalIndirectCommandBuffer, command_index: u32, descriptor: core.DispatchThreadgroupsDescriptor) !void {
    const handle = self.handle orelse return;
    try check(metal.vkmtl_metal_indirect_command_buffer_encode_dispatch(
        handle,
        command_index,
        descriptor.threadgroup_count_x,
        descriptor.threadgroup_count_y,
        descriptor.threadgroup_count_z,
        descriptor.threads_per_threadgroup_x,
        descriptor.threads_per_threadgroup_y,
        descriptor.threads_per_threadgroup_z,
    ));
}

const Error = error{
    MetalUnsupported,
    InvalidIndirectCommand,
    CommandFailed,
    UnexpectedMetalStatus,
};

fn check(status: metal.vkmtl_metal_status) Error!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => Error.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_INVALID_COMMAND => Error.InvalidIndirectCommand,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED => Error.CommandFailed,
        else => Error.UnexpectedMetalStatus,
    };
}
