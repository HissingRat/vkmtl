# Period 38: Resource Tables And Pipeline Persistence

Status: completed as a portable planning and validation slice.

Goal: move large resource tables and pipeline artifact persistence from
descriptor-shape validation into explicit pressure and compatibility contracts.

## Expected Result

After Period38, descriptor indexing and Metal argument-buffer style layouts can
be summarized as resource-table pressure plans, update-after-bind and
partially-bound requirements are visible before table creation, and shader /
pipeline artifacts have deterministic compatibility checks for stale or
backend-mismatched cache entries.

This period does not claim production native persistence yet. Vulkan
`VkPipelineCache` / pipeline-library consumption, Metal `MTLBinaryArchive`
consumption, and GPU-scale table pressure evidence remain Period44 device-matrix
work once the corresponding backend lowering exists.

## Phase Plan

### Phase 1: Descriptor Indexing Pressure Planning

- Added `ResourceTablePressureDescriptor` and `ResourceTablePressurePlan`.
- Summarize descriptor indexing table size, per-resource descriptor counts,
  expected bound/unbound descriptors, update pressure, and frames in flight.
- Validate descriptor table limits through existing capability reports.

### Phase 2: Metal Argument Buffer Pressure Planning

- Reuse the same `ResourceTablePressureDescriptor` for Metal argument-buffer
  layouts.
- Keep the pressure plan backend-neutral while the selected
  `AdvancedBindingModel` records whether the layout maps toward Vulkan
  descriptor indexing or Metal argument buffers.
- Leave real GPU argument-buffer stress evidence to Period44.

### Phase 3: Update-After-Bind And Dynamic Binding Semantics

- Resource-table pressure plans expose whether a layout requires
  partially-bound or update-after-bind behavior.
- `ResourceTablePressurePlan.canCreateTable()` reports whether the caller opted
  into the required semantics.
- Existing dynamic offsets, root constants, and resource-table runtime tests
  remain the command-binding regression surface.

### Phase 4: Vulkan Pipeline Artifact Compatibility

- Added `PipelineArtifactManifestDescriptor`.
- Defined compatibility inputs: backend, shader hash, entry-point hash,
  reflection hash, format hash, schema version, and toolchain id.
- Vulkan native pipeline-cache/library consumption remains backend work.

### Phase 5: Metal Pipeline Artifact Compatibility

- The same manifest and compatibility plan applies to Metal MSL / reflection
  artifacts and future binary archive metadata.
- Metal native binary archive consumption remains backend work.

### Phase 6: Cache Compatibility Validation

- Added tests for shader hash, entry point, reflection, backend, format,
  schema, and toolchain changes.
- Added `PipelineArtifactCachePlanDescriptor` and
  `PipelineArtifactCachePlan` to report whether a cache entry should rebuild
  and whether it may be persisted.

## Acceptance

- Resource-table pressure planning passes or reports precise unsupported
  features.
- Pipeline artifact compatibility behavior is deterministic and documented.
- Native cache persistence and GPU pressure evidence are routed to Period44.
