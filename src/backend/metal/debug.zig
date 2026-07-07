const metal = @import("metal_bridge");

pub fn labelPtr(label_value: ?[]const u8) [*c]const u8 {
    return if (label_value) |value| value.ptr else null;
}

pub fn labelLen(label_value: ?[]const u8) usize {
    return if (label_value) |value| value.len else 0;
}

pub fn requiredLabelPtr(label_value: []const u8) [*c]const u8 {
    return label_value.ptr;
}

pub fn ignore(status: metal.vkmtl_metal_status) void {
    _ = status;
}
