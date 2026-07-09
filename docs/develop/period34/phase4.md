# Phase 4: Shared Procedural Scene Data

Phase 4 extends the Period33 scene buffers for procedural primitives.

## Checklist

- [ ] Add sphere parameter buffers or scene records. Deferred to Period35
  Phase 1.
- [ ] Link procedural primitives to material ids. Deferred to Period35 Phase 1.
- [ ] Preserve camera, light, and material layouts from Period33. Deferred to
  Period35 Phase 1.
- [x] Define primitive id and instance id semantics for procedural hits.
- [x] Add validation for procedural buffer ranges.

## Acceptance

- Vulkan procedural hits map primitive ids to sphere/material data in the
  example shader.
- Shared Vulkan/Metal procedural scene buffers are deferred to Period35.
- Scene data remains example-local rather than backend-hardcoded.
