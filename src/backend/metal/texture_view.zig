const core = @import("../../core.zig");
const metal = @import("metal_bridge");
const MetalTexture = @import("texture.zig");

const MetalTextureView = @This();

handle: *metal.vkmtl_metal_texture_view,
sample_count: u32,

const Error = error{
    MetalUnsupported,
    InvalidTextureView,
    CommandFailed,
    UnexpectedMetalStatus,
};

pub fn init(texture: *const MetalTexture, descriptor: core.TextureViewDescriptor) !MetalTextureView {
    const resolved = try descriptor.resolveForTexture(texture.descriptor);

    var handle: ?*metal.vkmtl_metal_texture_view = null;
    try check(metal.vkmtl_metal_texture_view_create(
        texture.handle,
        viewDimension(resolved.dimension),
        MetalTexture.textureFormat(resolved.format),
        resolved.base_mip_level,
        resolved.mip_level_count,
        resolved.base_array_layer,
        resolved.array_layer_count,
        &handle,
    ));

    return .{
        .handle = handle orelse return Error.InvalidTextureView,
        .sample_count = texture.sampleCount(),
    };
}

pub fn deinit(self: *MetalTextureView) void {
    metal.vkmtl_metal_texture_view_destroy(self.handle);
}

fn viewDimension(dimension: core.TextureViewDimension) metal.vkmtl_metal_texture_view_dimension {
    return switch (dimension) {
        .automatic => unreachable,
        .one_d => metal.VKMTL_METAL_TEXTURE_VIEW_DIMENSION_1D,
        .one_d_array => metal.VKMTL_METAL_TEXTURE_VIEW_DIMENSION_1D_ARRAY,
        .two_d => metal.VKMTL_METAL_TEXTURE_VIEW_DIMENSION_2D,
        .two_d_array => metal.VKMTL_METAL_TEXTURE_VIEW_DIMENSION_2D_ARRAY,
        .three_d => metal.VKMTL_METAL_TEXTURE_VIEW_DIMENSION_3D,
    };
}

fn check(status: metal.vkmtl_metal_status) Error!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => Error.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW => Error.InvalidTextureView,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED => Error.CommandFailed,
        else => Error.UnexpectedMetalStatus,
    };
}
