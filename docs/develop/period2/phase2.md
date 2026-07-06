# Phase 2: Adapter Selection And Capabilities

Phase 2 starts capability discovery with a conservative public shape. Backend
queries can become more precise over time.

## First Slice

- Add `AdapterInfo` for the selected backend adapter.
- Add conservative public adapter enumeration using backend availability.
- Add `AdapterSelectionDescriptor` for explicit backend/name selection.
- Fill selected-adapter name/vendor/type from backend runtime queries where
  available.
- Add `DeviceFeatures` for portable feature gates.
- Add `DeviceLimits` for known public limits.
- Add `FormatCapabilities` and `Device.getFormatCaps(format)`.
- Expose `device.features()`, `device.limits()`, and `device.adapterInfo()`.
- Query selected-runtime limits where the backend already exposes them.

## First-Slice Limits

- Enumeration returns one conservative `AdapterInfo` per available backend
  instead of backend-native physical devices.
- Explicit selection currently supports backend forcing and exact runtime
  adapter-name validation. Backend-native physical-device selection can refine
  this without changing the public descriptor.
- Backend-native format capability queries can refine the conservative defaults
  later.

## Capability Rules

- User-facing code should query optional features before relying on them.
- Format capability queries should answer whether a format can be sampled,
  copied, used as a storage target, or used as an attachment.
- Unsupported capability use should become a clear validation or unsupported
  feature error.
