const std = @import("std");
const glfw = @import("zig_glfw");
const vkmtl = @import("vkmtl");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

pub fn surfaceDescriptor(window: glfw.Window) vkmtl.SurfaceDescriptor {
    return .{
        .source = .{
            .provider = .external,
            .window = glfw.rawWindow(window),
            .display = glfw.nativeCocoaWindow(window),
            .vulkan = vulkanSurfaceProvider(window),
        },
    };
}

pub fn presentationDescriptor(window: glfw.Window, present_mode: vkmtl.PresentMode) vkmtl.PresentationDescriptor {
    return .{
        .extent = framebufferExtent(window),
        .format = presentationFormatFromEnv(),
        .present_mode = present_mode,
    };
}

fn presentationFormatFromEnv() vkmtl.TextureFormat {
    const value = std.mem.span(getenv("VKMTL_PRESENTATION_FORMAT") orelse return .automatic);
    if (std.ascii.eqlIgnoreCase(value, "automatic")) return .automatic;
    if (std.ascii.eqlIgnoreCase(value, "srgb")) return .bgra8_unorm_srgb;
    if (std.ascii.eqlIgnoreCase(value, "linear")) return .bgra8_unorm;

    std.debug.print("Ignoring unsupported VKMTL_PRESENTATION_FORMAT value: {s}\n", .{value});
    return .automatic;
}

pub fn framebufferExtent(window: glfw.Window) vkmtl.Extent2D {
    const extent = glfw.framebufferExtent(window);
    return .{
        .width = extent.width,
        .height = extent.height,
    };
}

fn vulkanSurfaceProvider(window: glfw.Window) vkmtl.native.vulkan.SurfaceProvider {
    return .{
        .context = glfw.rawWindow(window),
        .get_instance_proc_addr = getInstanceProcAddress,
        .get_required_instance_extensions = getRequiredInstanceExtensions,
        .create_surface = createSurface,
    };
}

fn getInstanceProcAddress(
    context: *anyopaque,
    instance: usize,
    procname: [*:0]const u8,
) callconv(.c) ?*const anyopaque {
    _ = context;
    const proc = glfw.getInstanceProcAddress(@ptrFromInt(instance), procname) orelse return null;
    return @ptrCast(proc);
}

fn getRequiredInstanceExtensions(
    context: *anyopaque,
    count: *u32,
) callconv(.c) ?[*]const [*:0]const u8 {
    _ = context;
    const extensions = glfw.getRequiredInstanceExtensions() orelse return null;
    count.* = @intCast(extensions.len);
    return extensions.ptr;
}

fn createSurface(
    context: *anyopaque,
    instance: usize,
    allocation_callbacks: ?*const anyopaque,
    surface: *usize,
) callconv(.c) i32 {
    const window: glfw.Window = @ptrCast(@alignCast(context));
    var glfw_surface: glfw.VulkanSurface = undefined;
    const result = glfw.createWindowSurface(
        @ptrFromInt(instance),
        window,
        castAllocationCallbacks(allocation_callbacks),
        &glfw_surface,
    );
    surface.* = if (glfw_surface) |handle| @intFromPtr(handle) else 0;
    return result;
}

fn castAllocationCallbacks(callbacks: ?*const anyopaque) ?*const glfw.VulkanAllocationCallbacks {
    const ptr = callbacks orelse return null;
    return @ptrCast(@alignCast(ptr));
}
