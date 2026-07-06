# Phase 7: Driver-Level Pipeline Cache / Binary Archive

Phase 7 defines driver-level pipeline cache and Metal binary archive metadata.

## First Slice

- Add driver pipeline cache and binary archive feature gates.
- Add cache identity and invalidation descriptor shapes.
- Validate backend, device, driver, shader, and version identity.

## Current Limits

- This is separate from the Period 8 object-cache diagnostics layer. Native
  driver cache persistence remains future backend work.
