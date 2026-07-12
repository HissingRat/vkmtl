# Period 47 Closeout

Status: complete.

Implementation evidence commit:
`7d791d0ec53faa9dc604d1e6c3b6551dc9caa698`.

## Delivered

- Closed the allocated common resource limits, storage modes, sampler behavior,
  compatible texture views/swizzles, finite texture/vertex formats, and
  capability-gated buffer GPU addresses.
- Closed MRT color attachment iteration, texture-backed load/store actions,
  combined depth/stencil attachment behavior, ordinary render/compute binding,
  and the existing dynamic raster-state subset.
- Closed direct and indirect compute dispatch. `dispatchThreads` is explicitly
  a ceil-divided threadgroup composition with shader-owned logical-grid bounds.
- Opened the executable 32-bit integer storage-buffer/threadgroup atomic and
  threadgroup-memory subset on both backends, bounded by queried limits.
- Preserved fixed array counts and storage access through schema-1 Slang
  reflection, pipeline validation, and derived bind group layouts.
- Chose automatic managed synchronization: Metal publishes CPU writes with
  `didModifyRange` and synchronizes GPU writes before CPU maps/reads; Vulkan
  uses host-coherent managed buffers. No public synchronization command was
  added.
- Removed the seven final Period 47 rows from exactly-once gap routing, leaving
  66 incomplete Metal semantic units assigned to Periods 48-54.

## Public Compatibility

The guarded surface remains root 68, `Device` 34 methods, `WindowContext` 10
methods, and 35 opaque runtime handles. Period 47 targets `v0.2.0` because it
adds enum tags, descriptor/feature/limit fields, specialized handle behavior,
and public errors. The final reflection addition is optional
`ShaderReflectionBinding.storage_access`; null preserves the existing storage
defaults. `ShaderReflectionBindingAccessMismatch` is the corresponding new
`ShaderError` arm.

## Validation

- `zig fmt --check build.zig src examples tools tests/package_consumer`
- `zig build run-api-guard`: 68/34/10/35 passed.
- `zig build run-semantic-inventory-check`: 87 feature fields, 57 compact
  inventory IDs, 107 Metal semantics, 78 protocols, and 66 routed gaps passed.
- `zig build test --summary all`: 599/599 tests passed.
- `zig build --summary all`: 54/54 steps passed.
- `zig build -Dvulkan --summary all`: 54/54 steps passed.
- `git diff --check`

## Physical Metal Evidence

On 2026-07-12, implementation commit
`7d791d0ec53faa9dc604d1e6c3b6551dc9caa698` ran on macOS 15.7.3 and an Apple
M4 Pro:

- `VKMTL_BACKEND=metal zig build run-capability-dump` reported usable/native
  compute atomics and threadgroup memory as true, a 1024-thread group ceiling,
  and 32768 bytes of threadgroup memory.
- `VKMTL_BACKEND=metal zig build run-compute-readback` passed deterministic
  storage-buffer atomic, threadgroup atomic, groupshared-memory, texture, and
  buffer readback checks.
- `VKMTL_BACKEND=metal zig build run-transfer-readback` passed managed CPU
  upload plus GPU-to-CPU buffer/texture readback through the automatic
  synchronization boundary.

## Vulkan Evidence Boundary

The Vulkan paths pass focused unit tests, reflection/compiler tests, semantic
and API guards, and a complete forced-Vulkan build. Existing physical Vulkan
evidence still covers the earlier ordinary compute/transfer baseline, but no
new Period 47 atomic/threadgroup-memory or managed-mode physical Vulkan rerun is
claimed. Those backend lanes remain recorded as unit/build evidence until a
Vulkan device reruns the probes; this does not broaden the capability beyond
the Vulkan core 32-bit/workgroup subset and queried limits.

## Explicitly Unsupported Or Deferred

- Storage-texture atomics, 64-bit/floating-point atomics, subgroup-specific
  atomic guarantees, and backend-specific concurrent/grid dispatch controls.
- Native fences/events, physical queue ownership, heaps, function tables,
  tensors, payload bindings, and backend-only reflection protocols.
- Incompatible texture-view reinterpretation, depth/stencil resolve, tile-only
  attachments, sample positions, advanced raster state, and the full native
  Metal/Vulkan format universes.
- Native memory-budget telemetry, explicit cache/hazard modes, memoryless
  allocation guarantees, sparse residency, and scalable bindless tables.

Period 48 is next: native synchronization, queues, ownership, and presentation
timing.
