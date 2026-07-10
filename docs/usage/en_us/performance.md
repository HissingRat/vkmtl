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
and Vulkan unaligned-fill fallback counters without opening a window.

For opt-in physical GPU work, use:

```sh
zig build run-pixel-regression
zig build run-gpu-soak -- --iterations=120
```

The pixel step performs transfer, compute, and offscreen render readback. The
soak alternates presentation extents while churning resources, uploads,
readbacks, embedded shader resolution, and portable residency state. Native
heap/sparse/async-queue/memory-pressure behavior remains a separate capability
gate and is not inferred from the portable churn counters.

## Profiling Plans

Inspect the current profiling semantics without opening a window:

```sh
zig build run-profiling-plan
```

Current timestamp query values are logical command-order sequence numbers, not
GPU time. The default plan therefore selects application-supplied CPU wall-clock
fallback. Use `--markers-only` to disable that fallback or `--require-gpu` to
verify the typed `UnsupportedGpuTimestamps` gate.
