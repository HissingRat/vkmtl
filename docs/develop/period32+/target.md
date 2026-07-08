# Period 32+ Target: Full Parity And Production Coverage

Status: target document. Period 31 and Period 32 are split out as concrete
driver-execution periods for the first Metal and Vulkan ray traced triangles.
Broader parity periods should be planned after both paths are visible or after a
platform is explicitly documented as unsupported.

Goal: move vkmtl from "first Metal and Vulkan ray traced triangle paths are
visible on supported devices" to "most Vulkan and Metal workloads have either a
portable vkmtl path, a capability-gated vkmtl path, or an explicit documented
reason why the native API escape hatch is required."

Period 30 closed backend-private runtime records. Period 31 targets Metal ray
tracing pixels. Period 32 targets Vulkan ray tracing pixels. Period 32+ owns the
long tail: semantic parity, platform coverage, pressure testing, production
behavior, and deeper ray tracing coverage.

## Expected Baseline After Period 32

Period32+ assumes:

- common buffer, texture, sampler, pipeline, render, compute, transfer, and
  presentation paths are usable through public vkmtl APIs
- runtime Slang compilation, reflection, bind groups, pipeline creation, and
  shader caches are connected to real backend objects
- Period31 has made the Metal ray traced triangle visible on supported Metal
  devices
- Period32 has made the Vulkan ray traced triangle visible on supported Vulkan
  RT devices, or has documented a specific unsupported-runtime reason for a
  given platform
- advanced native escape hatches have runtime inventory and driver-work routing

After that, Period32+ should continue with broader ray tracing completeness,
GPU-backed soak loops, Vulkan/Metal semantic parity, external interop, resource
residency, and production coverage.

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

Period32+ should eventually close these families of work.

### Ray Tracing Completeness

- acceleration structure compaction, update, and refit paths
- top-level acceleration structures with many instances
- instance masks, transforms, and multi-level scene layouts
- ray query where supported
- procedural geometry and custom intersection paths where supported
- callable shaders and larger SBT layouts
- ray tracing examples beyond the first triangles

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
  should become concrete Period32+ phases first

## Planning Rules For Concrete Periods

After Period31 and Period32 close, split the remaining target into concrete
Period33, Period34, and later docs after checking:

- which native paths actually produce pixels on supported devices
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

## Non-Goals Before Period 32 Is Done

- Do not claim complete ray tracing parity from the first two triangles alone.
- Do not claim near-total Vulkan/Metal parity from Period31 or Period32 alone.
- Do not make the voxel world example the next blocker for backend completion.
- Do not expose raw Vulkan or Metal details through ordinary portable APIs.

