# Phase 5: Error Model / Validation Layer

Phase 5 keeps precise Zig error names while adding a public classification layer
for application-level handling.

## First Slice

- Add `ErrorCategory`.
- Add `classifyError(anyerror)`.
- Classify validation errors separately from unsupported features.
- Classify backend errors separately from device-lost and surface-lost paths.
- Keep existing exact error names for focused tests and debugging.

## Rules

- Public APIs should continue returning precise Zig errors where possible.
- Applications that need broad handling can call `vkmtl.classifyError(err)`.
- Backend code should prefer typed errors over strings.
- Future backend failures should map into `device_lost`, `surface_lost`, or
  `backend` instead of being collapsed into validation errors.
