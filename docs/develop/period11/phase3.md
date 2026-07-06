# Phase 3: Unified Feature / Limit Fill Path

Phase 3 centralizes how backend query data becomes public capability data.

## Scope

- Add one backend-neutral fill path for `DeviceFeatures`.
- Add one backend-neutral fill path for `DeviceLimits`.
- Keep backend-native details in backend modules.
- Treat unknown or unqueried values as unsupported or conservative limits.

## Validation

- Tests should verify that default feature sets are conservative.
- Tests should verify that backend query data does not bypass public structs.
