const vk = @import("vulkan");
const std = @import("std");
const GraphicsContext = @import("graphics_context.zig");

pub const TimelineSemaphore = struct {
    gc: *const GraphicsContext,
    handle: vk.Semaphore,

    pub fn init(gc: *const GraphicsContext, initial_value: u64) !TimelineSemaphore {
        var type_info = vk.SemaphoreTypeCreateInfo{
            .semaphore_type = .timeline,
            .initial_value = initial_value,
        };
        const handle = try gc.dev.createSemaphore(&.{ .p_next = &type_info }, null);
        return .{ .gc = gc, .handle = handle };
    }

    pub fn deinit(self: *TimelineSemaphore) void {
        self.gc.dev.destroySemaphore(self.handle, null);
        self.handle = .null_handle;
    }

    pub fn currentValue(self: TimelineSemaphore) !u64 {
        return try self.gc.dev.getSemaphoreCounterValue(self.handle);
    }

    pub fn signal(self: TimelineSemaphore, value: u64) !void {
        try self.gc.dev.signalSemaphore(&.{
            .semaphore = self.handle,
            .value = value,
        });
    }

    pub fn wait(self: TimelineSemaphore, value: u64, timeout_ns: ?u64) !bool {
        const semaphores = [_]vk.Semaphore{self.handle};
        const values = [_]u64{value};
        const result = try self.gc.dev.waitSemaphores(&.{
            .semaphore_count = 1,
            .p_semaphores = &semaphores,
            .p_values = &values,
        }, timeout_ns orelse std.math.maxInt(u64));
        return result == .success;
    }
};

pub const TimelinePoint = struct {
    semaphore: *const TimelineSemaphore,
    value: u64,
};
