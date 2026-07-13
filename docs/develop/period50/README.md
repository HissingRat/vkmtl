# Period 50: Binding Tables, Indirect Commands, And Pipeline Persistence

Status: complete.

Goal: turn scalable binding, reusable indirect command lists, and driver
pipeline artifacts into executable backend paths while closing dynamic-linking
and generated-command claims that cannot be represented exactly by the current
shader and command contracts.

Period 50 starts from the 13 semantic rows routed by the Period 45 audit. It is
an implementation slice, not permission to expose every Metal source type.
Rows may close through exact execution, an explicit unsupported decision, or a
dependency-correct reroute when a later command model owns the required
execution context.

## Phase Plan

### Phase 1: Contract Allocation And Dependency Audit

- Split CPU-authored reusable command lists from GPU-authored generated
  commands.
- Allocate resource-table pipeline compatibility without enlarging the flat
  root or the guarded `Device` and `WindowContext` method sets.
- Keep Metal 4 argument tables/resource-view pools with the Period 54 command
  model and RT function tables with Period 52.
- Decide linked functions, stitching, dynamic libraries, and parallel render
  encoding against the current shader-manifest and command ownership rules.

See `phase1.md`.

### Phase 2: Native Scalable Resource Tables

- Allocate/update/bind Metal argument buffers.
- Enable and query the complete Vulkan descriptor-indexing feature bundle,
  allocate indexed descriptor sets, and bind them through compatible pipeline
  layouts.
- Prove a large sampled-texture table with real GPU work.

See `phase2.md`.

### Phase 3: Reusable Indirect Command Lists

- Add a capability-gated CPU-authored render/compute command-list contract.
- Lower it to Metal indirect command buffers and an exact Vulkan direct-command
  expansion.
- Keep GPU mutation/device-generated command semantics explicitly separate and
  unsupported under the current Vulkan baseline.

See `phase3.md`.

### Phase 4: Persistent Driver Pipeline Artifacts

- Consume and update `VkPipelineCache` data during render/compute pipeline
  creation.
- Consume, populate, and serialize `MTLBinaryArchive` objects.
- Keep archive/cache identity, read-only behavior, invalid-data recovery, and
  path ownership explicit.

See `phase4.md`.

### Phase 5: Evidence And Semantic Closeout

- Add focused unit/build coverage and physical Metal evidence where the host
  exposes the feature.
- Update both semantic inventories, gap routing, public API inventory,
  compatibility docs, matrices, and examples.
- Publish an exact-commit closeout without upgrading unsupported GPU-generated,
  Metal 4, or RT function-table semantics.

See `phase5.md`.

## Public API Allocation

- No new root declaration, public `Device` method, or `WindowContext` method.
- `RenderPipelineDescriptor` and `ComputePipelineDescriptor` gain default-empty
  resource-table layout lists and an optional driver-cache descriptor. Ordinary
  pipelines remain source-compatible.
- `command` owns the new indirect command descriptor, range, runtime handle,
  and creation facade. Render and compute encoders own execution methods.
- The opaque runtime-handle allowlist grows by one for
  `IndirectCommandBuffer`; it retains the required single `_state` field.
- Capability, limit, descriptor-field, handle, method, and error additions
  target `v0.2.0`. No `v0.1.x` declaration is removed or renamed.

## Explicit Boundaries

- The resource-table pipeline layouts are appended after ordinary bind-group
  layouts. `ResourceTableBinding.index` must name that final pipeline-layout
  slot.
- Resource-table resources must remain alive through every command that uses
  the table. Table updates do not transfer resource ownership.
- Resource-table mutation must not race in-flight work, and a changed table is
  rebound before later commands use replacement resources. Vulkan post-bind
  clear remains closed without null-descriptor support.
- CPU-authored indirect command lists may inherit pipeline/resource state from
  the executing encoder. They do not claim shader/GPU mutation of command
  slots.
- Driver-cache paths and identity slices are borrowed only during synchronous
  pipeline creation. A read-only descriptor never writes the cache file.
- Runtime Slang compilation, runtime shader-cache files, and manifest schema 1
  changes remain out of scope.
