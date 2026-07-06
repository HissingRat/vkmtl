# Phase 2: Metal Capability Query

Phase 2 makes Metal feature reporting backend-native instead of static.

## Scope

- Query device families and platform availability.
- Detect argument-buffer tier and resource binding limits.
- Detect sparse/tiled texture support, ray tracing support, and binary archive
  support where available.
- Fill Metal-specific limits without leaking Metal names into the portable API.

## Validation

- Unit tests should cover conservative defaults for non-Apple targets.
- macOS smoke tests should report the selected Metal device and feature gates.
