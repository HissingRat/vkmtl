const core = @import("../../core.zig");
const debug = @import("debug.zig");
const metal = @import("metal_bridge");
const MetalClearScreen = @import("clear_screen.zig");

const MetalSamplerState = @This();

handle: *metal.vkmtl_metal_sampler_state,

const Error = error{
    MetalUnsupported,
    InvalidSampler,
    CommandFailed,
    UnexpectedMetalStatus,
};

pub fn init(owner: *MetalClearScreen, descriptor: core.SamplerDescriptor) !MetalSamplerState {
    try descriptor.validate();

    var handle: ?*metal.vkmtl_metal_sampler_state = null;
    try check(metal.vkmtl_metal_sampler_state_create(
        owner.handle,
        filter(descriptor.min_filter),
        filter(descriptor.mag_filter),
        mipFilter(descriptor.mip_filter),
        addressMode(descriptor.address_mode_u),
        addressMode(descriptor.address_mode_v),
        addressMode(descriptor.address_mode_w),
        descriptor.lod_min_clamp,
        descriptor.lod_max_clamp,
        if (descriptor.compare_function != null) 1 else 0,
        if (descriptor.compare_function) |compare| compareFunction(compare) else metal.VKMTL_METAL_COMPARE_FUNCTION_ALWAYS,
        descriptor.max_anisotropy,
        borderColor(descriptor.border_color orelse .transparent_black),
        if (descriptor.normalized_coordinates) 1 else 0,
        &handle,
    ));

    return .{
        .handle = handle orelse return Error.InvalidSampler,
    };
}

pub fn deinit(self: *MetalSamplerState) void {
    metal.vkmtl_metal_sampler_state_destroy(self.handle);
}

pub fn setLabel(self: *MetalSamplerState, label_value: ?[]const u8) void {
    debug.ignore(metal.vkmtl_metal_sampler_state_set_label(
        self.handle,
        debug.labelPtr(label_value),
        debug.labelLen(label_value),
    ));
}

fn filter(value: core.SamplerMinMagFilter) metal.vkmtl_metal_filter {
    return switch (value) {
        .nearest => metal.VKMTL_METAL_FILTER_NEAREST,
        .linear => metal.VKMTL_METAL_FILTER_LINEAR,
    };
}

fn mipFilter(value: core.SamplerMipFilter) metal.vkmtl_metal_mip_filter {
    return switch (value) {
        .not_mipmapped => metal.VKMTL_METAL_MIP_FILTER_NOT_MIPMAPPED,
        .nearest => metal.VKMTL_METAL_MIP_FILTER_NEAREST,
        .linear => metal.VKMTL_METAL_MIP_FILTER_LINEAR,
    };
}

fn addressMode(value: core.SamplerAddressMode) metal.vkmtl_metal_address_mode {
    return switch (value) {
        .clamp_to_edge => metal.VKMTL_METAL_ADDRESS_MODE_CLAMP_TO_EDGE,
        .clamp_to_border => metal.VKMTL_METAL_ADDRESS_MODE_CLAMP_TO_BORDER,
        .repeat => metal.VKMTL_METAL_ADDRESS_MODE_REPEAT,
        .mirror_repeat => metal.VKMTL_METAL_ADDRESS_MODE_MIRROR_REPEAT,
    };
}

fn borderColor(value: core.SamplerBorderColor) metal.vkmtl_metal_sampler_border_color {
    return switch (value) {
        .transparent_black => metal.VKMTL_METAL_SAMPLER_BORDER_COLOR_TRANSPARENT_BLACK,
        .opaque_black => metal.VKMTL_METAL_SAMPLER_BORDER_COLOR_OPAQUE_BLACK,
        .opaque_white => metal.VKMTL_METAL_SAMPLER_BORDER_COLOR_OPAQUE_WHITE,
    };
}

fn compareFunction(value: core.CompareFunction) metal.vkmtl_metal_compare_function {
    return switch (value) {
        .never => metal.VKMTL_METAL_COMPARE_FUNCTION_NEVER,
        .less => metal.VKMTL_METAL_COMPARE_FUNCTION_LESS,
        .equal => metal.VKMTL_METAL_COMPARE_FUNCTION_EQUAL,
        .less_equal => metal.VKMTL_METAL_COMPARE_FUNCTION_LESS_EQUAL,
        .greater => metal.VKMTL_METAL_COMPARE_FUNCTION_GREATER,
        .not_equal => metal.VKMTL_METAL_COMPARE_FUNCTION_NOT_EQUAL,
        .greater_equal => metal.VKMTL_METAL_COMPARE_FUNCTION_GREATER_EQUAL,
        .always => metal.VKMTL_METAL_COMPARE_FUNCTION_ALWAYS,
    };
}

fn check(status: metal.vkmtl_metal_status) Error!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => Error.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_INVALID_SAMPLER => Error.InvalidSampler,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED => Error.CommandFailed,
        else => Error.UnexpectedMetalStatus,
    };
}
