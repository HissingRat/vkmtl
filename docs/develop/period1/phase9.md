# Phase 9: Polish And Distribution

Phase 9 closes Period 1 by turning the completed core vertical slice into a
library that is easier to consume, document, validate, and distribute.

Status: complete. The pre-tag API migration, compatibility boundary, release
documentation, and validation gates are recorded in
`../api-migration-roadmap.md`, with caller changes in
`../api-migration-guide.md`.

## Scope

- Keep docs separated by purpose:
  - `docs/usage/` for user flows
  - `docs/api/` for public API reference and rules
  - `docs/develop/` for roadmap, checklist, and phase notes
- Audit public root exports and unstable aliases before early release tags.
- Decide which temporary `WindowContext` owner APIs stay for early users.
- Add backend object debug labels where native APIs support them.
- Add CI coverage for macOS and Linux.
- Document Vulkan validation and Metal API validation setup.
- Document current limits and feature coverage.
- Review examples, run commands, and expected behavior.

## Acceptance

- `zig build test` covers pure API behavior and any available backend probes.
- Examples are documented and runnable.
- Public API names are consistent enough for early users.
- Documentation has clear entry points for roadmap, checklist, API, and usage.
