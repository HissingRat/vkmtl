# Period 56 Vulkan Physical Evidence

Status: compatibility route accepted; canonical orientation rerun pending.

## 2026-07-16 Post-AS-Sizing Run

The user reran commit `ee720dc` on a supported Windows Vulkan RT machine after
the Vulkan acceleration-structure sizing fix. The supplied stderr logs contain
no device or driver identity, so this record does not infer that metadata from
an older run.

The canonical command selected `texture_composition`, loaded both precompiled
RT and presentation shaders, and reported:

```text
blas_size=2560
tlas_size=2048
scratch_size=2048
blas_built=true
tlas_built=true
trace_driver_submitted=true
runtime_ready=true
driver_pixels=visible_vulkan_procedural_rt_scene
ray traced scene finite run ok: backend=vulkan frames=3
```

The compatibility command selected `legacy_drawable_raw_copy` and reported the
same sizes, build/submission/runtime markers, 518400 rays, and three-frame
finite-run success. Neither six-line stderr log contains an error, warning, or
VUID. They also contain no positive marker proving that
`VK_LAYER_KHRONOS_validation` was available and enabled, so this is physical
execution evidence, not a validation-layer-clean claim.

## Visual Review

Both 962x579 screenshots visibly contain the complete procedural room, colored
walls, emissive spheres, reflective/refractive objects, and presented Vulkan
output. The compatibility screenshot has the established top-left orientation.

The canonical screenshot is the same scene vertically flipped. After removing
the title bar and performance overlay, the direct mean absolute RGB difference
over the common content is about 23; vertically flipping the canonical content
reduces it to about 2.15. Static wall regions then match nearly exactly. The
542 and 613 FPS overlays come from separate runs and are not performance
evidence.

The cause is the fullscreen presentation shader deriving UV Y from clip-space
interpolation. Metal and the current positive-height Vulkan viewport map
clip-space Y oppositely. The compatibility raw copy preserves texture rows and
therefore exposed the canonical double flip. The fix derives 1:1 sampling UVs
from fragment `SV_Position.xy` and the source texture dimensions, whose
top-left framebuffer convention is shared by Metal and Vulkan.

## Evidence Boundary

This run closes physical execution and visible presentation for the legacy
raw-copy compatibility route. It proves that the canonical route builds AS
objects, submits native RT work, executes composition, presents, and completes
three frames, but its visual orientation is not accepted. A fresh canonical
Vulkan screenshot plus finite-run log is required after the orientation fix.

The asymmetric 5x2 offscreen display regression now checks top and bottom rows
separately. Physical Metal readback passes with at most one byte of channel
delta. Physical Vulkan readback and the corrected canonical screenshot remain
the final orientation evidence.

Descriptor-exact Vulkan sizing for arbitrary multi-geometry arrays remains a
separate AS follow-up and did not cause the orientation failure.
