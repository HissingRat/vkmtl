# Phase 5: Native Command Insertion Hooks

Phase 5 adds controlled backend-native command insertion.

## Scope

- Define command insertion points for render, compute, and blit encoders.
- Expose backend-native command handles through explicit callback descriptors.
- Mark resource usage boundaries around native command insertion.

## Validation

- Tests should verify hooks are unavailable without the required feature gate.
- Docs should explain synchronization responsibility around native commands.
