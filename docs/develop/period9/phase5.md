# Phase 5: Backend Test Matrix

Phase 5 defines a backend/host test matrix for examples and validation steps.

## First Slice

- Add matrix entries for macOS Metal, macOS MoltenVK testing, Linux Vulkan,
  Windows Vulkan, optional iOS Metal, and headless/offscreen expectations.
- Document commands and runtime configuration required by each entry.
- Validate matrix metadata.

## Current Limits

- Backend matrix entries are recorded in `tools/development_matrix.zig`.
- Human-readable commands live in `docs/develop/backend-test-matrix.md`.
- CI automation may use this matrix later. The first slice makes the matrix
  explicit and testable in metadata.
