const core = @import("../../core.zig");
const runtime = @import("../../runtime/window_context.zig");

pub const Handles = core.MetalNativeHandles;
pub const TessellationLowering = core.MetalTessellationLowering;
pub const TessellationFactorBufferOwnership = core.MetalTessellationFactorBufferOwnership;
pub const TessellationDrawLowering = core.MetalTessellationDrawLowering;
pub const MeshPipelineLowering = core.MetalMeshPipelineLowering;
pub const MeshDispatchLowering = core.MetalMeshDispatchLowering;
pub const IntersectionFunctionDescriptor = core.MetalIntersectionFunctionDescriptor;
pub const RayTracingLowering = core.MetalRayTracingLowering;
pub const RayTracingMappingDescriptor = core.MetalRayTracingMappingDescriptor;
pub const RayTracingMappingPlan = core.MetalRayTracingMappingPlan;
pub const RayTracingExecutionMapping = runtime.MetalRayTracingExecutionMapping;

pub const planTessellationPatchDraw = runtime.planMetalTessellationPatchDraw;
pub const planMeshDispatch = runtime.planMetalMeshDispatch;
pub const planRayTracingMapping = runtime.planMetalRayTracingMapping;
pub const makeRayTracingExecutionMapping = runtime.makeMetalRayTracingExecutionMapping;
