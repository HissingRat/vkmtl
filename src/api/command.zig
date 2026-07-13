const core = @import("../core.zig");
const runtime = @import("../runtime/window_context.zig");

pub const CommandBufferDescriptor = core.CommandBufferDescriptor;
pub const CommandBufferLifecycleStatus = core.CommandBufferLifecycleStatus;
pub const CommandBufferLifecycleCallback = core.CommandBufferLifecycleCallback;
pub const CommandBufferState = core.CommandBufferState;
pub const RenderCommandEncoderState = core.RenderCommandEncoderState;
pub const BlitCommandEncoderState = core.BlitCommandEncoderState;
pub const ComputeCommandEncoderState = core.ComputeCommandEncoderState;
pub const DebugLabelTarget = core.DebugLabelTarget;
pub const DebugLabelDescriptor = core.DebugLabelDescriptor;
pub const DebugSignpostDescriptor = core.DebugSignpostDescriptor;
pub const DebugGroupStack = core.DebugGroupStack;
pub const CommandEncodingError = core.CommandEncodingError;
pub const IndirectCommandKind = core.IndirectCommandKind;
pub const IndirectCommandBufferDescriptor = core.IndirectCommandBufferDescriptor;
pub const IndirectCommandRange = core.IndirectCommandRange;
pub const IndirectCommandBuffer = runtime.IndirectCommandBuffer;
pub const CommandBuffer = runtime.CommandBuffer;
pub const BlitCommandEncoder = runtime.BlitCommandEncoder;
pub const RenderCommandEncoder = runtime.RenderCommandEncoder;
pub const ComputeCommandEncoder = runtime.ComputeCommandEncoder;

pub const queueCapabilities = runtime.queueCapabilities;
pub const planQueue = runtime.planQueue;
pub const makeIndirectCommandBuffer = runtime.makeIndirectCommandBuffer;
