# Phase 2: Driver Pipeline Cache And Binary Archive

Phase 2 connects backend-native pipeline caches.

## Scope

- Integrate Vulkan pipeline cache creation, serialization, and reuse.
- Integrate Metal binary archives where available.
- Include shader, specialization, layout, and render target identity in cache
  compatibility.

## Validation

- Add cache identity tests.
- Add docs for portable and backend-specific cache behavior.
