# Phase 6: Multi-Window Example

Phase 6 proves multi-surface presentation with a public example.

## Scope

- Add `examples/multi_window`.
- Use an external windowing adapter rather than adding windowing code to vkmtl
  core.
- Render a visibly different clear color or simple scene in each window.

## Validation

- The example should import only public vkmtl APIs and the external windowing
  package.
- It should run on Metal and Vulkan where the backend supports multi-surface.
