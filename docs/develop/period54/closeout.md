# Period 54 Closeout

Status: complete.

## Executable Outcomes

- `diagnostics.QuerySetDescriptor` distinguishes Boolean visibility from exact
  occlusion counting through `OcclusionQueryMode` while preserving `.boolean`
  as the default.
- `DeviceFeatures.occlusion_counting_queries` independently gates exact
  counting. Metal lowers it to `MTLVisibilityResultModeCounting`; Vulkan
  queries and enables `occlusionQueryPrecise` before using the precise query
  flag.
- Metal 4 argument-table effects are admitted through the existing
  `binding.ResourceTable` compatibility layer and explicit resource residency.
- Metal 4 explicit-ordering effects are admitted through the existing `sync`
  contract, tracked Metal hazards/encoder ordering, and native Vulkan barriers.

## Precise Unsupported Outcomes

- Metal 4 resource/view pools, command allocators, reusable command buffers,
  feedback objects, and residency-set object identity.
- Flexible Metal 4 render/compute pipeline and encoder ownership, compiler and
  binary archive objects, and pipeline datasets.
- Tensor resources, tensor operations, ML pipeline states, and ML command
  encoders.
- Function logs, advanced reflection objects, counter heaps, device counters,
  pass-boundary samples, calibration, and multi-counter/pipeline-statistics
  result shapes.

These families have no broad capability bit or placeholder execution path.
They remain unsupported until vkmtl owns exact portable descriptors, result
shapes, lifetime rules, and backend lowering contracts.

## Evidence

- `zig build test --summary all`: 630/630 tests passed; semantic inventory
  reports 93 device features, 72 compact IDs, 111 Metal units, 78 protocols,
  and zero routed gaps.
- `zig build run-api-guard`: root 69, `Device` 34, `WindowContext` 10,
  `HeadlessContext` 6, runtime handles 37.
- Default and forced Vulkan builds each passed 58/58 steps; the external
  package smoke passed 10/10 steps and 1/1 tests.
- The non-Metal bridge stub passed C99 syntax validation.
- On an Apple M4 Pro, Metal API Validation was enabled and the physical pixel
  regression returned exact counts `visible=61170, empty=0` before and after
  query reset, followed by `max_channel_delta=0`.

Physical Vulkan exact-count evidence is not claimed on this host. The Vulkan
path has feature-query, device-enablement, precise-flag, unit, and forced-build
coverage and remains subject to the device-matrix runtime gate.
