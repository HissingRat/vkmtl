# Phase 1: Driver Pipeline Cache Persistence

Phase 1 persists native driver-level pipeline caches.

## Scope

- Save and load Vulkan pipeline cache blobs.
- Save and load Metal binary archives where supported.
- Validate backend, device, driver, shader, and vkmtl cache identity.
- Keep invalidation explicit and inspectable.
- Represent persistence as an inspectable plan before backend file I/O is wired.

## Validation

- Tests should cover identity mismatch and cache invalidation.
- Backend smoke tests should show a warm-cache path.
- Unit tests should validate load/store decisions.
