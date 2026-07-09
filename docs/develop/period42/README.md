# Period 42: Format, Copy, Layout, And Attachment Edge Semantics

Status: planned after Period41.

Goal: close the edge cases that decide whether vkmtl behaves like a serious
graphics abstraction: format capabilities, layout/state transitions,
depth-stencil behavior, MSAA resolve/copy, mips, layers, and slices.

## Expected Result

After Period42, vkmtl should have a tested matrix for common format, copy,
layout/state, depth-stencil, MSAA, mip, layer, and slice semantics across
Vulkan and Metal.

## Phase Plan

### Phase 1: Format Capability Matrix

- Expand format capability queries for sampling, storage, render target, copy,
  depth/stencil, blend, and presentation usage.
- Add docs for backend-specific format limitations.
- Keep capability reports suitable for issue reports.

### Phase 2: Copy And Blit Edge Semantics

- Validate buffer/texture copy alignment and row-pitch rules.
- Validate mip, layer, and slice partial copies.
- Define blit/filtering behavior where supported.

### Phase 3: Resource State And Layout Transition Validation

- Tighten resource usage transition tracking.
- Validate implicit and explicit barriers across queues and passes.
- Keep Vulkan layouts and Metal usage/state hidden behind public states.

### Phase 4: Depth-Stencil Copy, Resolve, And Readback

- Define depth and stencil copy/readback support.
- Define depth resolve and stencil resolve behavior where supported.
- Add focused tests for unsupported combinations.

### Phase 5: MSAA, Mip, Layer, And Slice Regression Coverage

- Add MSAA resolve/copy/readback regression cases.
- Add mip/layer/slice texture view and copy cases.
- Add format reinterpretation validation where supported.

## Acceptance

- Format and copy edge cases are represented in tests or explicit unsupported
  diagnostics.
- Depth-stencil and MSAA semantics are documented.
- Backend differences stay behind public capability and state models.
