const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const shader_artifact = @import("../../shader/artifact.zig");
const GraphicsContext = @import("graphics_context.zig");

const VulkanShaderModule = @This();

gc: *const GraphicsContext,
handle: vk.ShaderModule,

pub fn init(
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    descriptor: core.ShaderModuleDescriptor,
) !VulkanShaderModule {
    try descriptor.validate();

    switch (descriptor.source) {
        .spirv => |spirv| return try initWords(gc, spirv),
        .spirv_bytes => |bytes| {
            const words = try shader_artifact.spirvBytesToWords(allocator, bytes);
            defer allocator.free(words);
            return try initWords(gc, words);
        },
        .artifact => |artifact| {
            const words = try shader_artifact.readSpirvWords(allocator, artifact);
            defer allocator.free(words);
            return try initWords(gc, words);
        },
        else => return error.UnsupportedShaderSourceLanguage,
    }
}

fn initWords(gc: *const GraphicsContext, words: []const u32) !VulkanShaderModule {
    const handle = try gc.dev.createShaderModule(&.{
        .code_size = words.len * @sizeOf(u32),
        .p_code = words.ptr,
    }, null);

    return .{
        .gc = gc,
        .handle = handle,
    };
}

pub fn deinit(self: *VulkanShaderModule) void {
    self.gc.dev.destroyShaderModule(self.handle, null);
}

pub fn setLabel(self: *VulkanShaderModule, label_value: ?[]const u8) void {
    self.gc.setDebugName(.shader_module, GraphicsContext.debugObjectHandle(self.handle), label_value);
}
