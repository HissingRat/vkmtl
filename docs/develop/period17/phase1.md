# Phase 1: Acceleration Structure Backend API

Phase 1 implements acceleration structure creation and lifecycle.

## Scope

- Create bottom-level and top-level acceleration structures.
- Allocate build scratch resources.
- Encode build and update commands.
- Track acceleration structure usage and deferred destruction.
- Keep the first slice as descriptor and build-size metadata until native build
  commands are wired.

## Validation

- Tests should cover invalid geometry, instance, and scratch descriptors.
- Backend smoke tests should build a minimal acceleration structure where
  supported.
- Unit tests should validate primitive/instance counts and scratch-size
  estimates.
