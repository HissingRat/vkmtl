const vk = @import("vulkan");
const core = @import("../../core.zig");
const GraphicsContext = @import("graphics_context.zig");

const VulkanSamplerState = @This();

gc: *const GraphicsContext,
handle: vk.Sampler,

pub fn init(gc: *const GraphicsContext, descriptor: core.SamplerDescriptor) !VulkanSamplerState {
    try descriptor.validate();

    const handle = try gc.dev.createSampler(&.{
        .mag_filter = filter(descriptor.mag_filter),
        .min_filter = filter(descriptor.min_filter),
        .mipmap_mode = mipmapMode(descriptor.mip_filter),
        .address_mode_u = addressMode(descriptor.address_mode_u),
        .address_mode_v = addressMode(descriptor.address_mode_v),
        .address_mode_w = addressMode(descriptor.address_mode_w),
        .mip_lod_bias = 0,
        .anisotropy_enable = .false,
        .max_anisotropy = 1,
        .compare_enable = .false,
        .compare_op = .always,
        .min_lod = descriptor.lod_min_clamp,
        .max_lod = descriptor.lod_max_clamp,
        .border_color = .float_transparent_black,
        .unnormalized_coordinates = .false,
    }, null);

    return .{
        .gc = gc,
        .handle = handle,
    };
}

pub fn deinit(self: *VulkanSamplerState) void {
    self.gc.dev.destroySampler(self.handle, null);
}

fn filter(value: core.SamplerMinMagFilter) vk.Filter {
    return switch (value) {
        .nearest => .nearest,
        .linear => .linear,
    };
}

fn mipmapMode(value: core.SamplerMipFilter) vk.SamplerMipmapMode {
    return switch (value) {
        .not_mipmapped, .nearest => .nearest,
        .linear => .linear,
    };
}

fn addressMode(value: core.SamplerAddressMode) vk.SamplerAddressMode {
    return switch (value) {
        .clamp_to_edge => .clamp_to_edge,
        .repeat => .repeat,
        .mirror_repeat => .mirrored_repeat,
    };
}
