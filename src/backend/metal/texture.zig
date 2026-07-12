const core = @import("../../core.zig");
const debug = @import("debug.zig");
const metal = @import("metal_bridge");
const MetalClearScreen = @import("clear_screen.zig");
const MetalTextureView = @import("texture_view.zig");

const MetalTexture = @This();

handle: *metal.vkmtl_metal_texture,
descriptor: core.TextureDescriptor,
width_value: u32,
height_value: u32,
depth_or_array_layers_value: u32,
mip_level_count_value: u32,
sample_count_value: u32,

const Error = error{
    MetalUnsupported,
    InvalidTexture,
    CommandFailed,
    UnexpectedMetalStatus,
};

pub fn init(owner: *MetalClearScreen, descriptor: core.TextureDescriptor) !MetalTexture {
    try descriptor.validate();

    var handle: ?*metal.vkmtl_metal_texture = null;
    try check(metal.vkmtl_metal_texture_create(
        owner.handle,
        textureDimension(descriptor.dimension),
        textureFormat(descriptor.format),
        descriptor.width,
        descriptor.height,
        descriptor.depth_or_array_layers,
        descriptor.mip_level_count,
        descriptor.sample_count,
        usageFlags(descriptor.usage, descriptor.format),
        storageMode(descriptor.storage_mode),
        &handle,
    ));

    const raw_handle = handle orelse return Error.InvalidTexture;
    return .{
        .handle = raw_handle,
        .descriptor = descriptor,
        .width_value = metal.vkmtl_metal_texture_width(raw_handle),
        .height_value = metal.vkmtl_metal_texture_height(raw_handle),
        .depth_or_array_layers_value = metal.vkmtl_metal_texture_depth_or_array_layers(raw_handle),
        .mip_level_count_value = metal.vkmtl_metal_texture_mip_level_count(raw_handle),
        .sample_count_value = descriptor.sample_count,
    };
}

pub fn deinit(self: *MetalTexture) void {
    metal.vkmtl_metal_texture_destroy(self.handle);
}

pub fn width(self: MetalTexture) u32 {
    return self.width_value;
}

pub fn height(self: MetalTexture) u32 {
    return self.height_value;
}

pub fn depthOrArrayLayers(self: MetalTexture) u32 {
    return self.depth_or_array_layers_value;
}

pub fn mipLevelCount(self: MetalTexture) u32 {
    return self.mip_level_count_value;
}

pub fn sampleCount(self: MetalTexture) u32 {
    return self.sample_count_value;
}

pub fn setLabel(self: *MetalTexture, label_value: ?[]const u8) void {
    debug.ignore(metal.vkmtl_metal_texture_set_label(
        self.handle,
        debug.labelPtr(label_value),
        debug.labelLen(label_value),
    ));
}

pub fn makeTextureView(self: *const MetalTexture, descriptor: core.TextureViewDescriptor) !MetalTextureView {
    return try MetalTextureView.init(self, descriptor);
}

pub fn replaceRegion(
    self: *MetalTexture,
    region: core.Region3D,
    descriptor: core.TextureReplaceRegionDescriptor,
) !void {
    if (self.descriptor.storage_mode == .private) return Error.InvalidTexture;
    const resolved = try descriptor.resolveForTexture(self.descriptor, region);

    try check(metal.vkmtl_metal_texture_replace_region(
        self.handle,
        resolved.region.origin.x,
        resolved.region.origin.y,
        resolved.region.origin.z,
        resolved.region.size.width,
        resolved.region.size.height,
        resolved.region.size.depth,
        resolved.mip_level,
        resolved.slice,
        resolved.bytes.ptr,
        resolved.bytes.len,
        resolved.bytes_per_row,
        resolved.bytes_per_image,
    ));
}

fn textureDimension(dimension: core.TextureDimension) metal.vkmtl_metal_texture_dimension {
    return switch (dimension) {
        .one_d => metal.VKMTL_METAL_TEXTURE_DIMENSION_1D,
        .two_d => metal.VKMTL_METAL_TEXTURE_DIMENSION_2D,
        .three_d => metal.VKMTL_METAL_TEXTURE_DIMENSION_3D,
    };
}

pub fn textureFormat(format: core.TextureFormat) metal.vkmtl_metal_texture_format {
    return switch (format) {
        .automatic => metal.VKMTL_METAL_TEXTURE_FORMAT_INVALID,
        .r8_unorm => metal.VKMTL_METAL_TEXTURE_FORMAT_R8_UNORM,
        .rg8_unorm => metal.VKMTL_METAL_TEXTURE_FORMAT_RG8_UNORM,
        .bgra8_unorm => metal.VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM,
        .bgra8_unorm_srgb => metal.VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM_SRGB,
        .rgba8_unorm => metal.VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UNORM,
        .rgba8_unorm_srgb => metal.VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UNORM_SRGB,
        .rgba8_uint => metal.VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UINT,
        .rgba8_sint => metal.VKMTL_METAL_TEXTURE_FORMAT_RGBA8_SINT,
        .r16_float => metal.VKMTL_METAL_TEXTURE_FORMAT_R16_FLOAT,
        .rg16_float => metal.VKMTL_METAL_TEXTURE_FORMAT_RG16_FLOAT,
        .rgba16_float => metal.VKMTL_METAL_TEXTURE_FORMAT_RGBA16_FLOAT,
        .r32_float => metal.VKMTL_METAL_TEXTURE_FORMAT_R32_FLOAT,
        .rg32_float => metal.VKMTL_METAL_TEXTURE_FORMAT_RG32_FLOAT,
        .rgba32_float => metal.VKMTL_METAL_TEXTURE_FORMAT_RGBA32_FLOAT,
        .r32_uint => metal.VKMTL_METAL_TEXTURE_FORMAT_R32_UINT,
        .r32_sint => metal.VKMTL_METAL_TEXTURE_FORMAT_R32_SINT,
        .depth16_unorm => metal.VKMTL_METAL_TEXTURE_FORMAT_DEPTH16_UNORM,
        .depth32_float => metal.VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT,
        .stencil8 => metal.VKMTL_METAL_TEXTURE_FORMAT_STENCIL8,
        .depth32_float_stencil8 => metal.VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT_STENCIL8,
    };
}

fn usageFlags(usage: core.TextureUsage, format: core.TextureFormat) c_uint {
    var flags: c_uint = 0;

    if (usage.copy_source) flags |= metal.VKMTL_METAL_TEXTURE_USAGE_COPY_SOURCE;
    if (usage.copy_destination) flags |= metal.VKMTL_METAL_TEXTURE_USAGE_COPY_DESTINATION;
    if (usage.shader_read) flags |= metal.VKMTL_METAL_TEXTURE_USAGE_SHADER_READ;
    if (usage.shader_write) flags |= metal.VKMTL_METAL_TEXTURE_USAGE_SHADER_WRITE;
    if (usage.render_attachment) flags |= metal.VKMTL_METAL_TEXTURE_USAGE_RENDER_ATTACHMENT;
    if (core.textureFormatSupportsViewReinterpretation(format)) {
        flags |= metal.VKMTL_METAL_TEXTURE_USAGE_PIXEL_FORMAT_VIEW;
    }

    return flags;
}

fn storageMode(mode: core.ResourceStorageMode) metal.vkmtl_metal_storage_mode {
    return switch (mode) {
        .automatic => metal.VKMTL_METAL_STORAGE_MODE_AUTOMATIC,
        .shared => metal.VKMTL_METAL_STORAGE_MODE_SHARED,
        .managed => metal.VKMTL_METAL_STORAGE_MODE_MANAGED,
        .private => metal.VKMTL_METAL_STORAGE_MODE_PRIVATE,
    };
}

fn check(status: metal.vkmtl_metal_status) Error!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => Error.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_INVALID_TEXTURE => Error.InvalidTexture,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED => Error.CommandFailed,
        else => Error.UnexpectedMetalStatus,
    };
}
