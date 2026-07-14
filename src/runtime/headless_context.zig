const std = @import("std");
const core = @import("../core.zig");
const runtime = @import("window_context.zig");

pub const HeadlessContext = struct {
    _state: *anyopaque,

    pub const Options = struct {
        app_name: [*:0]const u8,
        backend: core.BackendPreference = .auto,
        adapter_selection: core.AdapterSelectionDescriptor = .{},
        debug_backend_override: ?core.Backend = null,
    };

    pub fn init(allocator: std.mem.Allocator, options: Options) !HeadlessContext {
        return .{ ._state = try runtime.initHeadlessRuntime(
            allocator,
            options.app_name,
            options.backend,
            options.adapter_selection,
            options.debug_backend_override,
        ) };
    }

    pub fn deinit(self: *HeadlessContext) void {
        runtime.deinitRuntime(self._state);
        self._state = undefined;
    }

    pub fn selectedBackend(self: HeadlessContext) core.Backend {
        return runtime.runtimeSelectedBackend(self._state);
    }

    pub fn adapterInfo(self: HeadlessContext) core.AdapterInfo {
        return runtime.runtimeAdapterInfo(self._state);
    }

    pub fn device(self: *HeadlessContext) runtime.Device {
        return runtime.runtimeDevice(self._state);
    }

    pub fn queue(self: *HeadlessContext) runtime.Queue {
        return runtime.runtimeQueue(self._state);
    }
};

test "headless context public owner stays presentation-free" {
    comptime {
        if (@hasDecl(HeadlessContext, "surface")) @compileError("headless context exposes a surface");
        if (@hasDecl(HeadlessContext, "swapchain")) @compileError("headless context exposes a swapchain");
        if (@hasDecl(HeadlessContext, "nativeHandles")) @compileError("headless context exposes presentation-shaped native handles");
    }
}
