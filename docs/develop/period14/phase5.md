# Phase 5: Native Command Insertion Hooks

Phase 5 adds controlled backend-native command insertion.

## Scope

- Define command insertion points for render, compute, and blit encoders.
- Expose backend-native command handles through explicit callback descriptors.
- Mark resource usage boundaries around native command insertion.
- Gate command mutation separately from read-only native handle views through
  `DeviceFeatures.native_command_insertion`.

## Validation

- Tests should verify hooks are unavailable without the required feature gate.
- Docs should explain synchronization responsibility around native commands.
- Descriptor tests should require an explicit callback before backend command
  mutation is allowed.
