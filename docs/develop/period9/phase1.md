# Phase 1: Example Gallery Cleanup

Phase 1 makes the current example set inspectable and keeps the gallery aligned
with public API boundaries.

## First Slice

- Remove ignored workspace-only files from `examples/`.
- Add example metadata for name, directory, run command, kind, backend
  expectation, deterministic output, and implementation status.
- Keep examples documented as public API consumers.

## Current Limits

- Period 9 organizes existing examples and planned cases. New rendering
  features should still land in the period that introduces the feature.
