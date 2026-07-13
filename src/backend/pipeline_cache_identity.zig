const core = @import("../core.zig");

pub fn hash(identity: core.DriverCacheIdentityDescriptor) u64 {
    var value: u64 = 0xcbf29ce484222325;
    update(&value, @tagName(identity.backend));
    update(&value, identity.device_id);
    update(&value, identity.driver_id);
    update(&value, identity.shader_hash);
    update(&value, identity.schema_version);
    return value;
}

fn update(value: *u64, bytes: []const u8) void {
    for (bytes) |byte| {
        value.* ^= byte;
        value.* *%= 0x100000001b3;
    }
    value.* ^= 0xff;
    value.* *%= 0x100000001b3;
}
