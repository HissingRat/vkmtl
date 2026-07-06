const std = @import("std");
const core = @import("../../core.zig");
const shader_artifact = @import("../../shader/artifact.zig");
const metal = @import("metal_bridge");
const MetalClearScreen = @import("clear_screen.zig");

const MetalShaderModule = @This();

handle: *metal.vkmtl_metal_shader_module,

const Error = error{
    MetalUnsupported,
    InvalidShader,
    CommandFailed,
    UnexpectedMetalStatus,
    UnsupportedShaderSourceLanguage,
};

pub fn init(
    owner: *MetalClearScreen,
    allocator: std.mem.Allocator,
    descriptor: core.ShaderModuleDescriptor,
) !MetalShaderModule {
    try descriptor.validate();

    switch (descriptor.source) {
        .msl => |msl| return try initMsl(owner, msl),
        .artifact => |artifact| {
            const source = try shader_artifact.readBytes(allocator, artifact, .msl);
            defer allocator.free(source);
            return try initMsl(owner, source);
        },
        else => return Error.UnsupportedShaderSourceLanguage,
    }
}

fn initMsl(owner: *MetalClearScreen, source: []const u8) !MetalShaderModule {
    var handle: ?*metal.vkmtl_metal_shader_module = null;
    try check(metal.vkmtl_metal_shader_module_create_msl(
        owner.handle,
        source.ptr,
        source.len,
        &handle,
    ));

    return .{
        .handle = handle orelse return Error.InvalidShader,
    };
}

pub fn deinit(self: *MetalShaderModule) void {
    metal.vkmtl_metal_shader_module_destroy(self.handle);
}

fn check(status: metal.vkmtl_metal_status) Error!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => Error.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_INVALID_SHADER => Error.InvalidShader,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED => Error.CommandFailed,
        else => Error.UnexpectedMetalStatus,
    };
}
