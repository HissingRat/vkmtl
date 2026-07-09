# Phase 6: Sync And Query Validation

Phase 6 closes Period 23 with matrix and examples.

## Scope

- Update backend matrix entries for sync and query features.
- Add tests for command submission, waits, and query resolves.
- Add docs that separate portable defaults from explicit escape hatches.

## Validation

- `zig build test`
- `zig build`
- Backend matrix updated for Vulkan and Metal.

## Result

- `tools/development_matrix.zig` records the sync/query backend matrix and keeps
  the regression row tied to `zig build test`.
- `docs/develop/backend-test-matrix.md` separates portable runtime behavior
  from explicit escape hatches and deferred native lowering.
- `docs/develop/validation-matrix.md` lists fence/event, queue ownership, and
  query readback/resolve coverage.
