const core = @import("../core.zig");
const runtime = @import("../runtime/window_context.zig");

pub const SurfaceProvider = core.SurfaceProvider;
pub const SurfaceSource = core.SurfaceSource;
pub const SurfaceDescriptor = core.SurfaceDescriptor;
pub const PresentMode = core.PresentMode;
pub const PresentationTimingMode = core.PresentationTimingMode;
pub const PresentDrawableDescriptor = core.PresentDrawableDescriptor;
pub const SurfaceResizePolicy = core.SurfaceResizePolicy;
pub const SurfaceState = core.SurfaceState;
pub const PresentationDescriptor = core.PresentationDescriptor;
pub const PresentModeResolution = core.PresentModeResolution;
pub const PresentModeSupport = core.PresentModeSupport;
pub const PresentationResourceState = core.PresentationResourceState;
pub const FramePacingDiagnostics = core.FramePacingDiagnostics;
pub const SurfaceError = core.SurfaceError;
pub const SurfaceHandle = core.SurfaceHandle;
pub const SurfaceInfo = core.SurfaceInfo;
pub const SurfaceCollection = core.SurfaceCollection;

pub const defaultPresentModeSupport = core.defaultPresentModeSupport;
pub const presentModeSupport = runtime.presentModeSupport;
pub const resolvePresentMode = runtime.resolvePresentMode;
pub const makeSurfaceCollection = runtime.makeSurfaceCollection;
