# Performance Guide

vkmtl is still young, so the most important performance rule is to keep
expensive object creation out of the frame loop.

## Shader Compilation

Compile embedded Slang once during startup or asset reload:

```zig
var compiled = try device.compileRenderShader("main", source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();
```

Runtime shader artifacts are cached under `vkmtl-cache` by default. Source
hashes are part of the cache identity, so editing embedded Slang recompiles the
right artifacts automatically.

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
