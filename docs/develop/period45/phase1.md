# Phase 1: Capability Truth Audit

Status: complete. Usable occlusion queries are closed on both backends while
native API availability remains separately reported.

## Decisions

- `Device.features()` means vkmtl has an executable path on the selected
  backend; descriptor validation, deterministic planning, native availability,
  or a placeholder result is insufficient.
- `Device.nativeFeatures()` may report a driver/API fact before vkmtl has a
  usable lowering.
- A known false-positive usable feature is a correctness bug. The compatible
  `v0.1.x` repair is to report the feature as unavailable and return its
  existing typed unsupported error until execution exists.
- Occlusion queries require a native visibility result. A constant logical
  value does not satisfy the contract.

## Work

- Audit every default and backend `queryUsableFeatures` assignment.
- Disable usable occlusion queries until each backend writes and resolves a
  real visibility result.
- Preserve query descriptor validation and native feature facts independently.
- Add focused default-report, backend mapping, query creation, and capability
  inventory tests.
- Update capability docs, parity expectations, and QRY-03.

## Acceptance

- Neither backend advertises executable occlusion queries while the placeholder
  implementation remains.
- Timestamp logical-sequence behavior stays explicitly separate from GPU time.
- All capability-report tests pass without changing public declarations.

Implemented by the default/backend capability mappings, focused tests,
development matrix, API capability docs, changelog, and QRY-03 inventory row.
