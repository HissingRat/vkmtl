const builtin = @import("builtin");
const std = @import("std");

const VulkanLoader = @This();

const Impl = if (builtin.os.tag == .windows) WindowsLoader else std.DynLib;

impl: Impl,

pub fn open() error{VulkanUnavailable}!VulkanLoader {
    if (comptime builtin.os.tag == .windows) {
        return .{ .impl = try WindowsLoader.open() };
    } else {
        const primary: [*:0]const u8 = switch (builtin.os.tag) {
            .macos => "libvulkan.1.dylib",
            else => "libvulkan.so.1",
        };
        const fallback: [*:0]const u8 = switch (builtin.os.tag) {
            .macos => "libvulkan.dylib",
            else => "libvulkan.so",
        };
        const library = std.DynLib.openZ(primary) catch
            std.DynLib.openZ(fallback) catch return error.VulkanUnavailable;
        return .{ .impl = library };
    }
}

pub fn close(self: *VulkanLoader) void {
    self.impl.close();
}

pub fn lookup(self: *VulkanLoader, comptime T: type, name: [:0]const u8) ?T {
    return self.impl.lookup(T, name);
}

const WindowsLoader = struct {
    const windows = std.os.windows;

    handle: ?windows.HMODULE,

    fn open() error{VulkanUnavailable}!WindowsLoader {
        return .{
            .handle = LoadLibraryA("vulkan-1.dll") orelse
                return error.VulkanUnavailable,
        };
    }

    fn close(self: *WindowsLoader) void {
        const handle = self.handle orelse return;
        _ = FreeLibrary(handle);
        self.handle = null;
    }

    fn lookup(self: *WindowsLoader, comptime T: type, name: [:0]const u8) ?T {
        const handle = self.handle orelse return null;
        const procedure = GetProcAddress(handle, name.ptr) orelse return null;
        return @ptrCast(@alignCast(procedure));
    }

    extern "kernel32" fn LoadLibraryA(
        file_name: windows.LPCSTR,
    ) callconv(.winapi) ?windows.HMODULE;

    extern "kernel32" fn GetProcAddress(
        module: windows.HMODULE,
        procedure_name: windows.LPCSTR,
    ) callconv(.winapi) ?windows.FARPROC;

    extern "kernel32" fn FreeLibrary(
        module: windows.HMODULE,
    ) callconv(.winapi) windows.BOOL;
};
