# Phase 1: Acceleration Structure Backend API

Phase 1 implements acceleration structure creation and lifecycle.

## Scope

- Create bottom-level and top-level acceleration structures.
- Allocate build scratch resources.
- Encode build and update commands.
- Track acceleration structure usage and deferred destruction.

## Validation

- Tests should cover invalid geometry, instance, and scratch descriptors.
- Backend smoke tests should build a minimal acceleration structure where
  supported.
