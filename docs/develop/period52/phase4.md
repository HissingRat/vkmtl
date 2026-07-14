# Period 52 Phase 4: Advanced RT Closure Decisions

Status: complete.

## Function And Intersection Tables

Unsupported on the current executable surface. Manifest schema 2 has no linked
visible/callable Metal function units and embeds no Metal intersection-function
artifact. The existing mapping object remains a planning record; it no longer
reports backend-private tables unless a driver-bound table exists.

## Ray Query

Metal has no exact Vulkan inline ray-query contract. Vulkan native availability
is now queried through `VK_KHR_ray_query` plus its feature struct, independently
from RT-pipeline support. Usable Vulkan support remains false because ordinary
compute/render bind groups cannot bind an acceleration structure and no
precompiled ray-query shader contract exists.

## Callable And Complex SBT

Unsupported for execution. Schema 2 has no callable entry/artifact. The Vulkan
pipeline currently creates one ray-generation, miss, and hit program and no
callable region; Metal uses a compute ray-generation pipeline rather than a
driver-bound visible/callable table. Count/layout/stress plans remain useful
diagnostics but do not enable factories.

## Motion, Curves, And Metal 4

Unsupported under the current contract. Vulkan core 1.3 plus the loaded KHR/EXT
set does not provide one portable equivalent for all Metal motion/curve forms,
and vkmtl has no motion-keyframe, curve-control-point, row-major instance, or
Metal 4 descriptor resource layout. No static rebuild or triangle expansion is
used as a semantic substitute.
