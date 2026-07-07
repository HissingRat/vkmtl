# Phase 3: Residency Map And Page Commit API

Phase 3 tracks residency in vkmtl terms.

## Scope

- Track resident sparse buffer and texture regions.
- Batch page commit operations.
- Make residency visible to validation and diagnostics.
- Avoid backend-specific residency data leaking through the public API.
- Reject duplicate or overlapping resident regions before backend submission.

## Validation

- Tests should cover duplicate commit, duplicate uncommit, and partial overlap.
- Diagnostics should expose resident region counts.
- The residency map is backend-neutral and can be used by future Vulkan/Metal
  residency lowering.
