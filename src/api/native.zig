const core = @import("../core.zig");
const runtime = @import("../runtime/window_context.zig");

pub const vulkan = @import("native/vulkan.zig");
pub const metal = @import("native/metal.zig");

pub const Handles = core.NativeHandles;
pub const HandleLifetime = core.NativeHandleLifetime;
pub const HandleView = core.NativeHandleView;
pub const CommandEncoderKind = core.NativeCommandEncoderKind;
pub const CommandInsertionPoint = core.NativeCommandInsertionPoint;
pub const CommandCallback = core.NativeCommandCallback;
pub const CommandInsertionDescriptor = core.NativeCommandInsertionDescriptor;
pub const TessellationLowering = core.TessellationLowering;
pub const MeshPipelineLowering = core.MeshPipelineLowering;
pub const RayTracingPipelineLowering = core.RayTracingPipelineLowering;
pub const SparseBufferLoweringMode = core.SparseBufferLoweringMode;
pub const SparseBufferLowering = core.SparseBufferLowering;
pub const SparseTextureLoweringMode = core.SparseTextureLoweringMode;
pub const SparseTextureLowering = core.SparseTextureLowering;

pub const handleView = core.nativeHandleView;
pub const validateCommandInsertionDescriptor = runtime.validateNativeCommandInsertionDescriptor;
pub const planSparseBufferLowering = runtime.planSparseBufferLowering;
pub const planSparseTextureLowering = runtime.planSparseTextureLowering;
