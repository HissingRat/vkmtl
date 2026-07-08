# Period 31+ Target: Full Parity And Production Coverage

Status: target document. Concrete periods and phases should be planned after
Period 30 is complete and its native execution results are known.

Goal: move vkmtl from "advanced engine core paths have backend-private runtime
records" to "most Vulkan and Metal workloads have either a portable vkmtl path, a
capability-gated vkmtl path, or an explicit documented reason why the native API
escape hatch is required."

Period 30 closed the backend-private runtime-record pivot. Period 31+ owns the
long tail: driver execution, semantic parity, platform coverage, pressure
testing, and production behavior.

## Expected Baseline After Period 30

Period 31+ assumes Period 30 has closed the first backend-private runtime record
slice:

- common buffer, texture, sampler, pipeline, render, compute, transfer, and
  presentation paths are usable through public vkmtl APIs
- runtime Slang compilation, reflection, bind groups, pipeline creation, and
  shader caches are connected to real backend objects
- acceleration structures, ray tracing pipelines, shader binding tables, Metal
  ray tracing tables, and ray dispatch have backend-private runtime records
- advanced native escape hatches have runtime inventory and driver-work routing
- at least one advanced example verifies backend-private runtime records through
  public vkmtl APIs

Driver-level native execution, GPU-backed soak loops, and pixel-producing ray
tracing examples are the first concrete Period31+ planning targets.

## Coverage Target

vkmtl should cover Vulkan and Metal through three explicit lanes:

- Portable lane: same public API works on both Vulkan and Metal.
- Capability-gated lane: public API exists, but creation or execution requires
  feature and limit checks.
- Native lane: backend-specific behavior is exposed only through intentional
  native handle or native command escape hatches.

The target is not to hide every native difference. The target is to make every
difference explicit, testable, and documented.

## Major Target Areas

Period 31+ should eventually close these families of work.

### Synchronization And Queues

- timeline semaphore / shared event / fence semantics
- multi-queue scheduling for graphics, compute, transfer, and presentation
- queue ownership transfers and cross-queue resource hazards
- async compute and async transfer examples
- host wait, GPU wait, and external synchronization behavior

### Memory, Heaps, And Residency

- heap-backed resource allocation and aliasing validation
- memory budget and pressure reporting
- sparse / tiled residency updates under long-running workloads
- transient allocator behavior under frame overlap
- large resource streaming and eviction stress tests

### Shader, Pipeline, And Geometry Coverage

- production-grade pipeline libraries, binary archives, and persistent caches
- specialization variants and shader cache invalidation behavior
- tessellation lowering where supported
- mesh/task or object/mesh shader paths where supported
- shader diagnostics that point back to embedded Slang source and entry points

### Resource Tables And Binding Scale

- descriptor indexing and argument buffer pressure tests
- large bindless texture/material tables
- update-after-bind or equivalent backend semantics
- dynamic offsets, root constants, and small constant update costs
- reflection-driven layout stability across shader variants

### Ray Tracing Completeness

- acceleration structure compaction, update, and refit paths
- instance buffers, masks, transforms, and multi-level scene layouts
- ray query where supported
- procedural geometry and custom intersection paths where supported
- shader binding table layout stress tests
- ray tracing examples beyond the first triangle

### External Interop And Platform Coverage

- external memory, external textures, and external synchronization objects
- platform texture sharing for UI, media, and engine integration
- Metal shared events and Vulkan external semaphores
- native command insertion boundaries
- macOS, Linux, and supported Apple platform behavior notes

### Diagnostics, Capture, And Tooling

- stable debug labels and marker scopes across backends
- GPU timestamp and pipeline statistics coverage where available
- capture-friendly command and resource naming
- validation messages that identify vkmtl object, backend object, and operation
- backend capability dump output suitable for issue reports

### Format, Copy, And Edge Semantics

- format capability matrix for sampling, storage, render target, copy, and
  presentation usage
- depth/stencil copy and resolve behavior
- MSAA copy, resolve, and readback semantics
- texture view reinterpretation rules
- mip/layer/array slice partial operations
- sampler border colors and compare modes

### Validation And CI Matrix

- GPU-backed validation for every supported backend path
- device matrix that separates portable failures from unsupported features
- smoke tests for examples on at least one Metal and one Vulkan setup
- long-run soak tests for resource churn, shader churn, and presentation churn
- regression tests for cache invalidation and runtime shader compilation

### Voxel World Pressure Test

- keep the block-world prototype as the broad render-stack pressure test
- use it to validate chunk streaming, bindless/material tables, texture
  streaming, camera/culling, frame pacing, and long-running resource churn
- avoid using it to invent missing backend fundamentals; missing fundamentals
  should become concrete Period 31+ phases first

## Planning Rules For Concrete Periods

When Period 30 is complete, split this target into concrete Period 31, Period
32, and later docs only after checking:

- which Period 30 native paths actually produce pixels
- which advanced features remain typed unsupported
- which examples fail because of missing backend lowering
- which validation tests are CPU-only and still need GPU-backed coverage
- which Vulkan/Metal differences need a portable abstraction, a capability
  gate, or a native escape hatch

Each concrete period should:

- have a small number of phases with clear deliverables
- identify backend support and unsupported semantics before implementation
- add focused tests or examples that prove execution, not only descriptors
- update public API docs if the user-facing contract changes
- avoid rewriting completed historical period docs unless the documented fact is
  wrong

## Non-Goals Before Period 30 Is Done

- Do not split Period 31+ into final phases yet.
- Do not claim near-total Vulkan/Metal parity from Period 30 alone.
- Do not make the voxel world example the next blocker for backend completion.
- Do not expose raw Vulkan or Metal details through ordinary portable APIs.
