# Phase 5: Native Command Insertion

Phase 5 exposes an explicit advanced escape hatch.

## Scope

- Add callback descriptors for native command insertion.
- Pass scoped Vulkan or Metal command handles only through explicit APIs.
- Validate command encoder state before invoking callbacks.
- Keep the ordinary portable path free of native types.

## Validation

- Add native interop sample code.
- Add tests for invalid insertion points.
