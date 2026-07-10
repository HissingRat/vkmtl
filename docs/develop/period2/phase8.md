# Phase 8: Debug Labels / Markers / Diagnostics

Phase 8 adds portable debug naming and marker validation without making the
public API depend on Vulkan debug-utils extensions or Metal-only calls.

## First Slice

- Add borrowed debug labels to runtime resources.
- Add borrowed labels to command buffers and command encoders.
- Add `pushDebugGroup(...)` and `popDebugGroup()` to command buffers, render
  command encoders, blit command encoders, and compute command encoders.
- Validate empty debug labels, stack overflow, stack underflow, and unclosed
  groups before `endEncoding()` / `commit()`.
- Keep resource lifetime leak checks active in debug builds.

## API Rules

- Descriptor labels are stored in runtime wrappers as borrowed string slices;
  label bytes are not copied. The caller owns the label memory.
- `setLabel(null)` clears a runtime wrapper label.
- Debug groups are portable validation state today. Backend-native object labels,
  Vulkan debug-utils markers, and Metal debug groups can be lowered from this API
  later without changing user code.
- A command encoder must pop every group it pushed before `endEncoding()`.
- A command buffer must pop every group it pushed before `commit()`.

## Limits At Completion Of This Historical Phase

- Labels are stored on vkmtl runtime wrappers; native backend objects are not yet
  named.
- Debug groups do not emit Vulkan or Metal native markers yet.
- Diagnostics are validation errors or debug-build panics; richer structured
  diagnostic reporting belongs in a later period.

Period 43 is the current source of truth for native label lowering, marker
scopes, encoding rules, and capture-friendly naming.
