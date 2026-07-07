# Phase 6: Binding Backend Validation

Phase 6 closes Period 21 with regression coverage.

## Scope

- Update API docs for dynamic offsets, arrays, constants, and specialization.
- Update the backend matrix for binding capabilities.
- Add focused tests for binding validation and backend lowering.
- Add an example only where it proves a backend path.

## Validation

- `zig build test`
- `zig build`
- Backend matrix updated for Vulkan and Metal.

## Backend Matrix

| Capability | Vulkan | Metal | Status |
| --- | --- | --- | --- |
| Dynamic buffer offsets | Dynamic descriptor offsets | Buffer base offset plus dynamic offset | Complete |
| Resource arrays | Descriptor `descriptor_count` and array writes | Consecutive native slots | Complete |
| Dynamic buffer arrays | Deferred | Deferred | Needs per-element dynamic offset model |
| Descriptor indexing / argument buffers | Layout metadata | Layout metadata | Resource table update/bind deferred |
| Root constant pipeline layout | Runtime descriptor gate | Runtime descriptor gate | Command write/native lowering deferred |
| Shader specialization | Fingerprint identity and typed rejection | Fingerprint identity and typed rejection | Native variant lowering deferred |

## Result

- API docs cover dynamic offsets, resource arrays, advanced layouts, root-constant pipeline layouts, and specialization identity.
- Regression tests cover dynamic-offset validation, resource-array count validation, reflection array counts, root-constant layout gates, and specialization fingerprint identity.
- The completed backend paths are dynamic offsets and first-slice resource arrays.
