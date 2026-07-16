# Developer Documentation

`docs/develop` contains the current contracts and plans used while changing
vkmtl. It intentionally does not retain one directory per completed work
period. Detailed Period 1-56 phase notes remain available in Git at
`4ac780fced49d89ecfd4c09d519ac8dcd5fba07c`; their durable outcomes are
summarized in `history.md`.

## Documents

| Document | Purpose | Update when |
| --- | --- | --- |
| `architecture.md` | Stable module boundaries, ownership, backend interface, shader pipeline, presentation, and headless design | A subsystem boundary or ownership rule changes |
| `public-api.md` | Public API admission, compatibility, package, and release policy | Any public meaning or compatibility rule changes |
| `public-api-inventory.md` | Exact exported surface and canonical namespace allocation | A reachable declaration, method, field, tag, error, default, owner, or capability meaning changes |
| `migration.md` | Caller-facing old-to-current API migration | A supported caller must change source or build integration |
| `native-semantic-coverage-inventory.md` | Authoritative Metal/Vulkan execution and unsupported status | Native lowering, fallback, feature truth, or evidence changes |
| `validation.md` | Evidence classes, required commands, backend/device matrix, and recorded physical results | A gate, command, expectation, or physical result changes |
| `roadmap.md` | Only active work and deferred evidence | Work is allocated, reprioritized, or completed |
| `history.md` | Compact completed-work and release ledger | A bounded slice or release closes |

Machine-consumed semantic audit inputs live under `data/`. They are not a
second planning system.

## Authority Order

When documents disagree:

1. Verify implementation and focused tests.
2. Treat the exact API and native semantic inventories as the current public
   surface and backend-support snapshots.
3. Treat `public-api.md` and `architecture.md` as policy and boundary rules.
4. Treat `validation.md` as the evidence contract and record.
5. Treat `roadmap.md` as current intent only.
6. Treat `history.md` as historical evidence, never as a current support
   upgrade.

Fix drift in the same change. Planning-only, compilation-only, native-query,
and historical evidence must not be promoted to executable support.

## Maintenance Rules

- Do not add another `periodNN/` directory.
- Keep current tasks only in `roadmap.md`; remove checked implementation detail
  when the outcome moves to `history.md`.
- Keep API policy separate from the exact surface inventory.
- Keep backend support claims in the native semantic inventory and evidence in
  `validation.md`; do not repeat full matrices elsewhere.
- Link user-facing docs to stable API/usage pages first and to developer docs
  only when implementation evidence is the subject.
- Use canonical APIs and names in examples and new documentation.
- Preserve important old snapshots with a commit or release tag instead of
  keeping hundreds of inactive files in the working tree.

## Validation For Documentation Changes

Documentation-only wording changes normally need `git diff --check` and the
relevant inventory checker. Path, build metadata, or matrix changes additionally
need:

```sh
zig build run-semantic-inventory-check
zig build run-api-guard
zig build test
zig build
zig build -Dvulkan
scripts/ci/run_package_smoke.sh
```

Search for stale plain-text paths as well as Markdown links because many old
references were historically written inside backticks:

```sh
rg 'docs/develop/|period[0-9]+' AGENTS.md README.md build.zig src examples tools scripts tests docs
```
