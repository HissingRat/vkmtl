# Resource Lifetime

vkmtl resources are explicit. Anything returned as a runtime resource should be
destroyed by calling `deinit()` before destroying its owner.

## Current Owner

`WindowContext` owns backend presentation state and the debug tracker.
`WindowContext.device()` returns a runtime `Device` view. Resource creation
goes through `Device`, command buffers through `Queue`, and resize/clear
operations through `Swapchain`; `WindowContext` does not forward those calls.

Resources created through `Device` and tracked by the debug tracker include:

- `makeBuffer(...)`
- `makeTexture(...)`
- `makeSamplerState(...)`
- `makeShaderModule(...)`
- `makeRenderPipelineState(...)`
- `makeBindGroupLayout(...)`
- `makeBindGroup(...)`
- `makeQuerySet(...)`

Texture views are created from textures with `texture.makeTextureView(...)` and
are tracked by the same owner.

## Destruction Order

Destroy child resources before destroying the context:

```zig
defer context.deinit();

var device = context.device();
var buffer = try device.makeBuffer(descriptor);
defer buffer.deinit();

var pipeline = try device.makeRenderPipelineState(pipeline_descriptor);
defer pipeline.deinit();
```

Zig runs defers in last-in, first-out order. Put `defer context.deinit()` before
resource defers so the later resource defers run first and the context is
destroyed last.

## Debug Checks

Debug builds track live buffers, textures, texture views, sampler states, shader
modules, render pipeline states, bind group layouts, and bind groups.
`WindowContext.deinit()` panics if any of those resources are still live.

Resource wrappers also guard against use after their own `deinit()`.

Starting in Period 2, the tracker also records submitted/completed work serials
from command-buffer `commit()`. If a resource is released while work is still
incomplete, the release is recorded as a deferred retirement. The current
Vulkan and Metal backends still wait for work to complete before `commit()`
returns, so these retirements are flushed at the end of the same commit. Later
non-idle submission can attach native destroys to the same serial model.

## Label Memory

Object labels are borrowed rather than owned. Keep descriptor or
`setLabel(...)` backing bytes alive and unchanged until the object is destroyed,
the label is replaced, or `setLabel(null)` clears it. A descriptor may itself
be temporary; only the referenced label bytes have the longer lifetime.

Debug-group and signpost labels have call-only lifetime because vkmtl stores
only marker stack depth after the native call returns.

## Command Objects

Command buffers, render command encoders, blit command encoders, and compute
command encoders are short-lived recording objects. Encoders must be ended with
`endEncoding()`. A command buffer is consumed by `commit()`, which
submits/presents work and releases the native command buffer wrapper.

Debug groups must be balanced before `endEncoding()` or `commit()`.

## Query Sets

An occlusion `QuerySet` bound through
`RenderPassDescriptor.occlusion_query_set` is borrowed by that pass and every
matching begin/end command. Timestamp sets are borrowed by each encoder write,
and all query sets are borrowed by resolve commands. Keep the set alive until
`commit()` returns; the current backends complete synchronously.

Do not reset or destroy a set from its first encoded write/begin until the
producer command buffer's synchronous `commit()` returns; ending the encoder
does not release this borrow. A slot may be written once after each reset. The
resolve destination is also borrowed through completion and must have
`copy_destination` usage.

## Owner Migration Direction

The target ownership tree is:

```text
Context
  -> Adapter
    -> Device
      -> Queue
      -> Surface
      -> resources and pipelines
```

`Device` and `Queue` are now exposed as views. Later Period 2 phases should add
explicit `Surface` / `Swapchain` owners and decide which `WindowContext` helpers
remain long term.
