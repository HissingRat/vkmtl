# Period 35: RT Scene Data And Metal Procedural Parity

Status: planned after Period34 Vulkan procedural validation.

Goal: turn the Period33/34 ray traced scene from example-local shader constants
into shared scene data, and close Metal procedural/custom-intersection parity
without leaking Metal handles into the public API.

## Phase Plan

### Phase 1: Shared RT Scene Data Layout

- Define camera, material, light, primitive, and instance scene records.
- Keep layouts backend-neutral and inspectable.
- Replace example-local hardcoded scene constants with buffers where practical.

### Phase 2: Mixed Mesh And Procedural Scene Assembly

- Keep room walls as mesh geometry.
- Keep spheres as procedural primitives.
- Support mixed BLAS inputs and TLAS instances for the full scene.

### Phase 3: Metal Procedural Function Tables

- Add backend-private Metal intersection function table creation.
- Bind procedural sphere intersection functions during dispatch.
- Report precise unsupported reasons when Metal procedural RT is unavailable.

### Phase 4: Cross-Backend Scene Binding

- Bind the same logical scene buffers on Vulkan and Metal.
- Preserve public/backend boundaries for native tables and AS handles.
- Document primitive id, instance id, and material lookup semantics.

### Phase 5: Visual Parity And Validation

- Tighten Vulkan/Metal image parity for the reference-inspired scene.
- Validate supported Vulkan and Metal procedural paths.
- Record remaining quality gaps with concrete follow-up ownership.

