# Phase 6: Validation On Supported Vulkan Hardware

Phase 6 proves the Vulkan ray tracing output path with real hardware or a real
Vulkan RT-capable runtime.

Status: completed on the recorded Windows/NVIDIA hardware. The supported path
is physically observed; the unsupported path is contract- and unit-validated
because this host has no non-ray-tracing Vulkan ICD.

## Scope

- Keep `zig build test` passing.
- Keep `zig build` passing.
- Run `zig build run-ray-traced-scene -Dvulkan` on a supported Vulkan ray
  tracing setup.
- Document the visible result, GPU/runtime, and output-image presentation path.
- Document unsupported behavior for runtimes without required extensions.

## Acceptance

- The validation notes name the GPU/runtime used.
- The visible window result, `trace_driver_submitted` status, and
  Vulkan ray tracing success marker are captured or manually documented.
- Unsupported-runtime behavior is deterministic and actionable.

## Validation Result

Validated on 2026-07-10 at commit `e2a7362f` with:

- Windows 10 build 19045, x86_64
- NVIDIA GeForce RTX 5080
- NVIDIA driver 610.62
- Vulkan API 1.4.341
- Zig 0.16.0

The build gates passed:

```text
zig build test --summary all
Build Summary: 16/16 steps succeeded; 550/550 tests passed

zig build -Dvulkan
Build Summary: 54/54 steps succeeded
```

The physical Vulkan command was:

```text
zig build run-ray-traced-scene -Dvulkan
```

The window visibly presented the ray traced scene. The observed runtime record
reported `blas_built=true`, `tlas_built=true`,
`trace_driver_submitted=true`, `runtime_ready=true`, and
`driver_pixels=visible_vulkan_procedural_rt_scene`. The local screenshot is
`artifacts/period32-vulkan-rt/ray-traced-scene.png`; the artifact directory is
intentionally ignored by git.

Period32 originally accepted
`driver_pixels=visible_vulkan_rt_output`. Period34 later upgraded the same
acceptance example to procedural sphere AABBs and custom intersection, so the
current `visible_vulkan_procedural_rt_scene` marker supersedes the old marker.
It is stronger evidence: the current path still creates and builds native BLAS
and TLAS objects, binds the native pipeline and SBT, submits
`vkCmdTraceRaysKHR`, and presents its output.

## Unsupported Runtime Contract

This machine exposes only a ray-tracing-capable Vulkan ICD, so no physical
unsupported-device run is claimed. The unsupported lane is documented from
the capability diagnostics contract and its passing unit coverage. Missing
required KHR extensions, feature bits, limits, or device procedures produce a
`RayTracingCapabilityDiagnostics` blocker. The example exits before native ray
tracing setup and prints an actionable line of this form:

```text
vulkan ray tracing unsupported: blocker=<blocker>, requirement=<requirement>, details=<details>
```

The test suite includes the deterministic first-missing-extension gate and was
part of the observed 550/550 passing tests. This evidence verifies the message
contract without representing it as a non-RT hardware observation.

## Deferred

- Automated Vulkan RT CI coverage is Period32+ work.
