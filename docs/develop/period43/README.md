# Period 43: Profiling, Capture, And Debug Markers

Status: active. Phase 1 label lifetime and naming rules are the current
implementation priority.

Goal: make vkmtl debuggable in native tools by providing stable labels,
markers, capture scopes, timestamps, and issue-report diagnostics.

## Expected Result

After Period43, vkmtl command streams and resources should be easy to inspect
in native Vulkan and Metal tooling. Debug labels, marker scopes, capture hooks,
timestamps, and profiling output should identify both the vkmtl object and the
backend operation.

## Phase Plan

### Phase 1: Debug Label And Marker Contract

- Define label lifetime and naming rules for public objects.
- Define command encoder marker scopes.
- Keep labels optional and low overhead.

### Phase 2: Vulkan Debug Utils Integration

- Lower object labels and command markers to Vulkan debug utils where
  available.
- Validate marker nesting and command buffer boundaries.
- Report unsupported debug utils behavior cleanly.

### Phase 3: Metal Debug Groups And Capture Integration

- Lower labels and command groups to Metal debug APIs.
- Add opt-in Metal capture scope helpers where practical.
- Preserve capture integration behind public diagnostics APIs.

### Phase 4: Timestamp, Query, And Profiling Support

- Add timestamp/query APIs where supported.
- Define fallback behavior when profiling queries are unavailable.
- Add simple profiling examples or tools.

### Phase 5: Diagnostics For Issue Reports

- Expand capability dump and diagnostics output.
- Include backend object names, feature gates, and failing operations.
- Document recommended issue-report bundle contents.

## Acceptance

- Native debug tools show vkmtl labels/markers on supported backends.
- Profiling queries work or report typed unsupported reasons.
- Diagnostics are useful enough to debug backend-specific failures.
