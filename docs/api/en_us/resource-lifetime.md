# Resource Lifetime

vkmtl resources are explicit. Anything returned as a runtime resource should be
destroyed by calling `deinit()` before destroying its owner.

## Current Owner

`WindowContext` still owns backend presentation state and the debug tracker.
Starting in Period 2, `WindowContext.device()` returns a runtime `Device` view,
and resource creation goes through `Device`. Existing `WindowContext.make*`
methods remain as compatibility forwards.

Resources created through `Device` and tracked by the debug tracker include:

- `makeBuffer(...)`
- `makeTexture(...)`
- `makeSamplerState(...)`
- `makeShaderModule(...)`
- `makeRenderPipelineState(...)`
- `makeBindGroupLayout(...)`
- `makeBindGroup(...)`

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

## Command Objects

Command buffers, render command encoders, and blit command encoders are
short-lived recording objects. Encoders must be ended with `endEncoding()`.
A command buffer is consumed by `commit()`, which submits/presents work and
releases the native command buffer wrapper.

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
