# Period 55 Phase 2: Native Texture Dispatch

Status: complete.

## Public Command Boundary

`CommandBuffer.dispatchRaysToTexture(...)` accepts the same pipeline, shader
binding table, dispatch descriptor, acceleration structure, and output-view
shape as the established drawable path, but has no presentation side effect.
`ray_tracing.RayTracingTextureResources` is an exact alias of the retained
`RayTracingDrawableResources` type, so the resource validation and lifetime
rules cannot drift between the two names.

Before native encoding, the runtime requires:

- a live acceleration structure and output view from the selected backend;
- the acceleration-structure kind consumed by the active native pipeline (the
  current Vulkan path uses a TLAS and the current Metal ray-generation kernel
  uses a primitive BLAS);
- a two-dimensional mip-zero/layer-zero view over a texture with exactly one
  mip, one array layer, and one sample;
- both shader-read and shader-write texture usage;
- dispatch depth one and width/height no larger than the output view.

Backend mismatch and invalid resource, usage, shape, sample-count, or extent
conditions return typed errors before driver work.

Direct RT/AS commands occupy the command buffer's one native encoding segment.
After one succeeds, the only portable next steps on that command buffer are
presentation metadata when applicable and `commit()`. A second encoder or
direct command returns `InvalidCommandBufferState`; sampling or other
composition begins on a later command buffer after the first commit. This
matches the current Vulkan recording model instead of allowing a second
`vkBeginCommandBuffer` to overwrite or invalidate the first recording.

## Metal Lowering

The Metal bridge receives the caller-owned `MTLTexture` behind the public
texture view and binds it as the ray-generation output. This command does not
ask the layer for a drawable and does not encode presentation. The caller may
sample, copy, read back, or otherwise compose the texture after submission.
The current precompiled Metal ray-generation kernel binds a
`primitive_acceleration_structure`, so a TLAS is rejected before bridge work
rather than reaching the native unsupported branch.

The existing `dispatchRaysToDrawable(...)` path is retained as legacy behavior
and still owns its established drawable/presentation flow.

## Vulkan Lowering

Vulkan updates the RT descriptor set with the caller-owned image view,
transitions the image to general layout, and executes `vkCmdTraceRaysKHR`.
After the RT write, the image transitions to
`shader_read_only_optimal`, establishing the RT-shader-write to fragment-
sampled consumer dependency used by the public fullscreen pass.

The transition is part of the texture command's postcondition. It does not
claim that arbitrary later copy/readback uses need no additional transition.
Each dispatch owns a distinct descriptor set and inline-data buffer until its
synchronous submission completes, so encoding another command buffer cannot
retarget or overwrite an earlier unsubmitted dispatch.
