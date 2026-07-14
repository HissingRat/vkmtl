# Period 53: External Interop, Metal I/O, And Device Topology

Status: complete.

Goal: turn the external-resource shapes that have a complete current contract
into executable imports, publish exact selected-device identity/topology
diagnostics, and close the remaining I/O/synchronization/insertion routes where
the current public shape cannot preserve native semantics.

## Phase Plan

### Phase 1: Contract And API Allocation

- Keep external resource owners under `interop` and topology under
  `diagnostics`.
- Add no root, `Device`, `WindowContext`, or `HeadlessContext` names.
- Separate executable imports from planning/native availability.

See `phase1.md`.

### Phase 2: Executable Metal Resource Imports

- Import same-device `MTLBuffer` and `MTLTexture` objects.
- Import single-plane IOSurface-backed 2D textures.
- Expose imported ordinary `Buffer`/`Texture` resources through their external
  owners with explicit ownership and destruction rules.

See `phase2.md`.

### Phase 3: Device Identity And Peer Topology

- Query Metal registry/peer-group identity.
- Query Vulkan device UUID and selected physical-device group membership.
- Keep topology diagnostic-only until a portable multi-device execution owner
  exists.

See `phase3.md`.

### Phase 4: Precise Closure Decisions

- Close external semaphore/event execution under the value-free current
  synchronization descriptor.
- Close native command insertion under the context-handle-only callback view.
- Close Metal I/O/compression under the missing async file/status/cancel and
  compressed-stream contracts.
- Close cross-device resource execution under the single-device runtime owner.

See `phase4.md`.

### Phase 5: Evidence And Inventory Closeout

- Add a headless Metal import example with GPU buffer, raw texture, and
  IOSurface readback.
- Record topology output on the selected physical device.
- Update capability/API/semantic inventories, routing, roadmap, and validation
  evidence.

See `phase5.md` and `closeout.md`.

## Compatibility

The slice is additive and targets the `v0.2.0` surface. Existing external
wrappers retain their descriptor/plan behavior. New imported-resource accessors
return typed unsupported errors when no driver resource was imported.
