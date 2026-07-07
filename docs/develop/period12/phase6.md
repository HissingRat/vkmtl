# Phase 6: Bindless Validation Coverage

Phase 6 hardens bindless validation.

## Scope

- Validate descriptor count limits.
- Validate partially bound behavior.
- Validate empty slots, duplicate bindings, and out-of-range binding metadata.
- Validate render and compute stage visibility.
- Validate Slang reflection array metadata before deriving advanced layouts.

## Validation

- Add unit tests for invalid descriptors.
- Add backend smoke coverage for a supported device where practical.
- Keep backend smoke coverage optional when the selected device does not expose
  descriptor indexing or Metal argument buffers.
