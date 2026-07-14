# Period 51 Phase 2: Executable Vulkan Tessellation

Status: complete.

## Target

- Embed four SPIR-V stages from a schema-2 tessellation declaration.
- Enable the Vulkan tessellation device feature only with the complete runtime
  path.
- Build a patch-list graphics pipeline with validated control-point count and
  issue native patch draws.
- Reuse ordinary pass attachments, fragment-visible layouts/resource tables,
  caches, viewports, scissors, and dynamic raster state. Advanced-stage
  bindings remain outside the current `ShaderVisibility` contract.

## Metal Boundary

Metal exposes tessellation pipeline and encoder APIs, but the pinned Slang
target cannot produce the corresponding hull/domain artifacts. The usable
feature stays false and attempts return the typed unsupported result.

## Evidence

- Deterministic descriptor, feature, stage, and patch-count tests.
- A visible tessellation example prepared for a capable Vulkan device. The
  current Metal host supplies forced-build evidence only; physical Vulkan
  execution remains a follow-up evidence run and is not claimed here.
