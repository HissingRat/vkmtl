# Phase 3: Residency Map And Page Commit API

Phase 3 tracks residency in vkmtl terms.

## Scope

- Track resident sparse buffer and texture regions.
- Batch page commit operations.
- Make residency visible to validation and diagnostics.
- Avoid backend-specific residency data leaking through the public API.

## Validation

- Tests should cover duplicate commit, duplicate uncommit, and partial overlap.
- Diagnostics should expose resident region counts.
