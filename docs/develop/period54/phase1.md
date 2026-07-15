# Period 54 Phase 1: Contract And API Allocation

Status: complete design decision.

The 20 routed semantic units resolve into three executable contracts and 17
precise unsupported outcomes.

## Executable Allocation

1. `MTL-BND-002` is `composed-exact` through the existing
   `binding.ResourceTable`. The admitted buffer/texture/sampler table shape,
   update validation, retained resources, pipeline-layout fingerprint, and
   Metal argument-buffer/Vulkan descriptor-indexing lowering preserve the
   observable table contract. This does not expose `MTL4ArgumentTable` native
   identity.
2. `MTL-CMD-012` is `composed-exact` through the existing portable `sync`
   barrier and resource-state contract. Metal encoder ordering plus tracked
   hazards and Vulkan pipeline barriers preserve execution ordering without a
   Metal 4 command-encoder owner.
3. `MTL-REN-019` becomes executable through
   `diagnostics.OcclusionQueryMode.counting`. Metal uses counting visibility;
   Vulkan uses the precise occlusion query flag only when the selected device
   reports it.

The counting allocation adds:

- `diagnostics.OcclusionQueryMode`;
- `QuerySetDescriptor.occlusion_mode`, defaulting to `.boolean`;
- `DeviceFeatures.occlusion_counting_queries`;
- `QueryError.UnsupportedOcclusionCountingQueries`.

The flat root, `Device`, `WindowContext`, `HeadlessContext`, and runtime-handle
allowlists remain unchanged.

## Unsupported Allocation

- `MTL-RES-012`: no lifetime-safe resource/view-pool owner or cache eviction
  contract.
- `MTL-RES-016`, `MTL-CMP-007`, `MTL-CMP-008`: no tensor data type,
  dimensions/strides/layout, view aliasing, graph, pipeline, dispatch, or
  Vulkan extension/buffer fallback contract.
- `MTL-CMD-010`, `MTL-CMD-011`: current queues own one-shot command buffers;
  there is no separate allocator, reset/reuse, residency list, commit options,
  feedback lifetime, or asynchronous feedback result.
- `MTL-REN-003`: a render pass has no query-set/index pair for begin/end
  attachments or variable counter result layout.
- `MTL-REN-017`, `MTL-REN-018`, `MTL-CMP-006`: existing fixed pipelines and
  classic encoders preserve ordinary work, but do not preserve Metal 4
  flexible linking, allocator/table/counter identity, or command-model
  ownership.
- `MTL-SHD-008`, `MTL-SHD-009`: no function-log callback/container lifetime
  and no tensor/payload/function-table/advanced-threadgroup reflection shape.
- `MTL-ARC-003`, `MTL-ARC-004`, `MTL-ARC-005`: the source-backed precompiled
  shader contract has no runtime compiler task, binary-function link unit, or
  versioned Metal 4 pipeline-dataset object graph. Ordinary driver cache
  persistence remains a separate supported contract.
- `MTL-DBG-004`, `MTL-DBG-005`: one `u64` per query cannot describe counter
  sets with multiple typed values, calibration, availability, overflow, and
  device-specific interpretation.

These rows receive typed/documented unsupported outcomes, not false usable
feature bits or placeholder values.
