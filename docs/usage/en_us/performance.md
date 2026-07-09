# Performance Guide

vkmtl is still young, so the most important performance rule is to keep
expensive object creation out of the frame loop.

## Shader Resolution

Resolve the precompiled shader that matches embedded Slang during startup or
asset reload:

```zig
var compiled = try device.compileRenderShader("main", source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();
```

Shader artifacts are precompiled at build time and embedded into the
executable; runtime resolves them directly from memory and does not create
`vkmtl-cache`. Editing embedded Slang regenerates embedded artifacts and the
debug copy under `zig-out/shaders` on the next `zig build`.

## Object Creation

Create buffers, textures, samplers, bind group layouts, shader modules, and
pipelines during setup where possible. Period 8 exposes object-cache keys and
`objectCacheDiagnostics()` so applications can detect repeated equivalent
creation attempts before native object reuse is fully implemented.

## Resource Updates

Prefer persistent resources plus small updates:

- use `buffer.replaceBytes(...)` for CPU-visible uniform updates
- use transfer/readback paths for private resources
- keep texture uploads explicit with `replaceRegion(...)` or
  `replaceAll2D(...)`

## Commands

Keep command recording predictable. vkmtl validates command encoder ordering and
tracks resource usage transitions. Explicit `bufferBarrier(...)` and
`textureBarrier(...)` calls validate against the same state; Vulkan lowers them
to native barriers and Metal treats them as validation/no-op markers.
`fillBuffer(...)` is cheapest on Vulkan when offset and size are 4-byte aligned;
unaligned ranges use a staging-copy fallback.

## Stability Plans

Use the opt-in stability planner when checking expected long-run pressure
without opening a window:

```sh
zig build run-stability-plan -- --iterations 120
```

This command prints the planned resize, resource churn, shader artifact, upload,
and Vulkan unaligned-fill fallback counters. Full GPU soak loops remain
backend-hardening work.
