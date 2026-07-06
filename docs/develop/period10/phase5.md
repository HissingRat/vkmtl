# Phase 5: Mesh Shader Gated

Phase 5 defines mesh/task shader pipeline metadata as an optional module.

## First Slice

- Add mesh shader feature gates.
- Add mesh pipeline descriptor shapes.
- Validate task/mesh stage requirements and workgroup limits.

## Current Limits

- Vulkan mesh shader and Metal object/mesh-like paths are backend-specific and
  remain future lowering work.
