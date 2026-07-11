const core = @import("../../core.zig");
const runtime = @import("../../runtime/window_context.zig");

pub const Handles = core.VulkanNativeHandles;
pub const SurfaceProvider = core.VulkanSurfaceProvider;
pub const TessellationLowering = core.VulkanTessellationLowering;
pub const TessellationDrawLowering = core.VulkanTessellationDrawLowering;
pub const MeshPipelineLowering = core.VulkanMeshPipelineLowering;
pub const MeshDispatchLowering = core.VulkanMeshDispatchLowering;
pub const RayTracingPipelineLowering = core.VulkanRayTracingPipelineLowering;

pub const planTessellationPatchDraw = runtime.planVulkanTessellationPatchDraw;
pub const planMeshDispatch = runtime.planVulkanMeshDispatch;
