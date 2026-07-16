# Period 56 Vulkan Physical Evidence

Status: canonical and compatibility physical execution and visual orientation
accepted. Deterministic Vulkan pixel readback is not a Period 56 visual-closure
gate, but remains required release-matrix evidence.

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

## Post-Orientation-Fix Rerun

The corrected canonical `texture_composition` path subsequently completed 3000
frames on the supported Vulkan RT machine. Its log again reports BLAS/TLAS build,
518400 rays, `trace_driver_submitted=true`, `runtime_ready=true`, and visible
procedural output, with no error in the supplied output.

The new screenshot has the established top-left orientation: the blue and
yellow emissive spheres are above the central sphere, while the lobed object
and floor reflection are below it. After masking the title bar and performance
overlay, its direct mean absolute RGB difference from the accepted
compatibility screenshot is about 2.34. Vertically flipping the corrected
canonical content increases that difference to about 18.20. This closes the
canonical visual-orientation failure.

## Evidence Boundary

The supplied runs close physical execution and visible presentation for both
the canonical texture-composition and legacy raw-copy routes. The corrected
canonical result also establishes the shared top-left composition convention
on the tested Vulkan RT machine.

The asymmetric 5x2 offscreen display regression now checks top and bottom rows
separately. Physical Metal readback passes with at most one byte of channel
delta. A physical Vulkan run of that regression remains useful deterministic
byte-level evidence. It is not needed to accept the now-correct canonical scene
orientation, but `local_vulkan_pixel_regression` remains a required release
matrix lane.

Descriptor-exact Vulkan sizing for arbitrary multi-geometry arrays remains a
separate AS follow-up and did not cause the orientation failure.
