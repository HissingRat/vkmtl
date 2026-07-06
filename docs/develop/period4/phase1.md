# Phase 1: Binding Model Implementation

Phase 1 clarifies the binding model with portable locations and layout
introspection helpers.

## First Slice

- Add `BindingLocation` for group/binding identity.
- Add binding resource classification helpers.
- Add layout helpers for entry lookup and resource counts.
- Keep Vulkan descriptor sets and Metal binding slots behind backend modules.

## Current Limits

- The existing backend descriptor-set/resource-call lowering remains unchanged.
- Argument buffers remain a future Metal backend path.
