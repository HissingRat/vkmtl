# Phase 2: Metal Source Semantic Ledger

Status: complete for the macOS 26.2 Metal framework baseline.

## Source Boundary

- Use the Metal framework surface from the pinned macOS SDK recorded in the
  native semantic coverage inventory.
- Include availability-gated Metal features even when the current audit host
  cannot execute them.
- Exclude deprecated-only entry points after recording their canonical modern
  semantic.
- Exclude MetalKit, MetalFX, and Metal Performance Shaders unless a later scope
  decision admits them.

## Ledger Rules

Each row records:

- stable semantic ID and Metal protocol/type family;
- observable behavior rather than Objective-C overload spelling;
- current vkmtl owner or `missing-contract`;
- Metal and Vulkan coverage status;
- capability, limit, format, OS, GPU-family, and extension gates;
- implementation location and strongest evidence;
- exact remaining gap.

Methods may share a row only when differences are type width, language
convenience, or overload spelling. Differences in lifetime, synchronization,
resource visibility, precision, ordering, or performance guarantees require
separate rows.

## Acceptance

- Core and advanced Metal framework families are all present in the ledger.
- Missing vkmtl concepts remain visible as `missing-contract` rows.
- The ledger never derives completeness only from the current public API.

`metal-semantic-ledger.md` contains 99 semantic units.
`metal-protocol-semantic-map.tsv` maps all 78 concrete protocols from the
pinned SDK source snapshot. The 149 concrete descriptor/helper interfaces are
folded into their configuring semantic unless they change observable behavior,
in which case the ledger gives them a dedicated row.
