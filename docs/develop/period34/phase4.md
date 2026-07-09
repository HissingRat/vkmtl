# Phase 4: Shared Procedural Scene Data

Phase 4 extends the Period33 scene buffers for procedural primitives.

## Checklist

- [x] Add sphere parameter buffers or scene records through the Period35
  scene-data payload.
- [x] Link procedural primitives to material ids through the Period35 material
  records.
- [x] Preserve camera, light, and material layouts from Period33 through the
  Period35 scene-data payload.
- [x] Define primitive id and instance id semantics for procedural hits.
- [x] Add validation for procedural buffer ranges.

## Acceptance

- Vulkan procedural hits map primitive ids to sphere/material data in the
  example shader.
- Shared Vulkan/Metal procedural scene data is handled by Period35.
- Scene data remains example-local rather than backend-hardcoded.
