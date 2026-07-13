# Period 50 Closeout

Status: complete.

Implementation evidence commit:
`25da0d1e5fdb275b044be1e1cff2269bbcfda035`.

## Delivered

- Replaced resource-table metadata with native execution. Metal allocates and
  updates `MTLArgumentEncoder` storage; Vulkan enables the complete admitted
  descriptor-indexing feature bundle and allocates/updates/binds indexed
  descriptor sets.
- Added resource-table layouts to render/compute pipeline descriptors and
  rejects a table whose absolute slot or complete layout fingerprint does not
  match the active pipeline.
- Added CPU-authored reusable render/compute command lists with fixed slots,
  reset, range execution, labels, typed kind/range validation, and tracked
  lifetime.
- Metal executes reusable lists through native render/compute ICBs when the
  device exposes them. Vulkan and native-unavailable Metal preserve the same
  observable contract through exact direct draw/dispatch expansion.
- Added render/compute driver artifact persistence. Vulkan consumes and stores
  identity-gated `VkPipelineCache` blobs; Metal consumes, populates, and
  serializes identity-gated `MTLBinaryArchive` files.
- Reworked `examples/bindless_textures` into a real 65-slot table, reusable ICB
  draw, and persistent-cache GPU path using an embedded Slang shader.
- Closed parallel child render encoders, manifest-schema-1 linked functions,
  stitching graphs, dynamic libraries, and GPU-authored command mutation as
  unsupported rather than approximating them.
- Rerouted RT function tables to Period 52 and Metal 4 argument tables plus
  resource/view pools to Period 54.
- Split CPU-authored command semantics from GPU mutation, growing the Metal
  ledger from 107 to 109 units, and reduced exactly-once incomplete routing
  from 52 to 42 units assigned to Periods 51-54.

## Public Compatibility

The guarded root 68, `Device` 34, and `WindowContext` 10 baselines remain
unchanged. The runtime handle allowlist grows from 35 to 36 through the
canonical `command.IndirectCommandBuffer`, which retains the required single
opaque `_state` field.

The `command` facade reaches 23 declarations and three operations; all 13
facades total 517 declarations and 88 operation aliases. Render and compute
encoders gain one execution method each. `RenderPipelineDescriptor` and
`ComputePipelineDescriptor` gain default-empty resource-table layouts and a
default-null driver-cache descriptor. `DeviceFeatures` reaches 92 fields with
`indirect_command_buffers`; `DeviceLimits` gains
`max_indirect_command_count`.

The descriptor, feature, limit, handle, method, enum, and error-set additions
target `v0.2.0`. Existing ordinary pipeline literals preserve their behavior.

## Validation

- `zig fmt --check build.zig src examples tools tests/package_consumer` passed.
- `zig build run-api-guard` passed: root 68, `Device` 34,
  `WindowContext` 10, and 36 runtime handles.
- `zig build run-semantic-inventory-check` passed: 92 feature fields, 58
  compact inventory IDs, 109 Metal semantics, 78 protocols, and 42 routed
  gaps.
- `zig build test --summary all` passed 614/614 tests.
- `zig build` passed.
- `zig build -Dvulkan` passed.
- `scripts/ci/run_package_smoke.sh` passed.
- `git diff --check` passed before the implementation commit.

## Physical Metal Evidence

On 2026-07-13, implementation commit
`25da0d1e5fdb275b044be1e1cff2269bbcfda035` ran on macOS 15.7.3, arm64, and an
Apple M4 Pro:

- `VKMTL_BACKEND=metal zig build run-capability-dump` reported native and
  usable argument buffers and indirect command buffers, usable Metal binary
  archives, 500000 descriptors per admitted table range, and 4096 reusable
  commands per list.
- `VKMTL_BACKEND=metal VKMTL_PIXEL_REGRESSION=1 zig build
  run-bindless-textures` created and bound 64 textures plus one sampler,
  compiled an ICB-capable pipeline, executed one native inherited ICB draw, and
  completed the frame successfully.
- Repeated example runs consumed the persisted binary archive and its identity
  sidecar under `zig-out/cache/`, then serialized the successful pipeline
  functions again without a runtime shader compiler or shader-cache write.

## Vulkan Evidence Boundary

Vulkan descriptor-indexing feature query/enablement, layout/pool/set creation,
resource updates, compatible pipeline layouts, direct-command expansion, and
pipeline-cache consumption pass focused tests and the complete forced-Vulkan
build. No new physical Vulkan Period 50 run is claimed. The scalable-table
feature remains closed unless the selected driver exposes the complete enabled
feature bundle and conservative limits.

## Explicitly Unsupported Or Deferred

- Shader/GPU mutation of indirect command slots and Vulkan
  device-generated-command extensions. The portable list is CPU-authored and
  immutable while executing.
- `MTLParallelRenderCommandEncoder`; there is no public thread-safe child
  encoder ownership contract.
- Dynamic shader libraries, linked function sets, and function stitching under
  shader manifest schema 1.
- RT visible/intersection function tables, routed to Period 52.
- Metal 4 argument tables and resource/view pools, routed to Period 54.
- Lifetime-safe native object pooling, Vulkan pipeline libraries, Metal 4
  pipeline datasets, and runtime cache-manifest I/O.
- Post-bind Vulkan slot clear without null-descriptor support. Replacement
  updates may use explicitly admitted update-after-bind ranges; mutations must
  not race in-flight work and tables must be rebound before later use.
- Cache I/O/serialization success as a pipeline correctness requirement.
  Missing, stale, or unwritable cache data remains a best-effort miss and does
  not turn a valid native pipeline into a failure or a false cache hit.
- Physical Vulkan large-table/cache evidence beyond forced-build and unit
  coverage.

Period 51 is next: executable tessellation and mesh/object/task geometry plus
precise decisions for variable-rate, layered, tile/imageblock, raster-order,
and programmable-blend semantics.
