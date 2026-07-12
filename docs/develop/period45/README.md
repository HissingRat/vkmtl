# Period 45: Native Semantic Coverage Audit

Status: planned.

Goal: turn the initial feature-family native semantic inventory into a
versioned, source-driven coverage ledger. Every in-scope Metal semantic must
map to an exact vkmtl execution path, an explicit incomplete implementation
gap, or a precise unsupported decision. Vulkan mappings may use one native
operation, several operations, hidden resources, or vkmtl state tracking.

Period 45 is an audit and truthfulness period. It does not claim to implement
every gap it discovers. Its output is the authoritative input to subsequent
backend implementation periods.

## Expected Result

After Period 45:

- usable capability reports do not advertise known placeholder paths;
- the Metal source baseline and exclusions are versioned;
- every in-scope Metal protocol/method family is represented in a semantic
  ledger;
- each semantic has a Metal and Vulkan native/composed/emulated/unsupported or
  incomplete classification;
- current vkmtl ownership, feature/limit gates, implementation location, and
  evidence are linked;
- uncovered work is ordered into implementation slices by correctness and
  dependency value.

## Phase Plan

### Phase 1: Capability Truth Audit

- Cross-check every usable `DeviceFeatures` field against executable runtime
  lowering.
- Correct the occlusion-query placeholder claim first.
- Keep native availability separate from usable vkmtl execution.
- Add tests for every corrected capability.

See `phase1.md`.

### Phase 2: Metal Source Semantic Ledger

- Pin the Metal SDK/framework source baseline and adjacent-framework scope.
- Enumerate non-deprecated device, resource, command, render, compute, blit,
  synchronization, shader, memory, advanced geometry, RT, diagnostics, and
  interop semantic families.
- Merge aliases/overloads only when their observable contract is identical.

See `phase2.md`.

### Phase 3: Vulkan And Compatibility Mapping

- Map every Metal semantic to Vulkan core/extension operations, a composed or
  emulated vkmtl path, typed unsupported, or an incomplete gap.
- Record the exact Vulkan feature/extension and limit requirements.
- Separate semantic equivalence from optional performance guarantees.

See `phase3.md`.

### Phase 4: Ownership, Evidence, And Drift Checks

- Link every ledger entry to its canonical vkmtl owner or record that no public
  contract exists.
- Link implementation files and strongest evidence without treating planning
  tests as GPU execution.
- Add deterministic checks that current feature fields and ledger IDs cannot
  silently disappear from the audit.

See `phase4.md`.

### Phase 5: Gap Priority And Closeout

- Group incomplete entries into implementation slices.
- Prioritize false capability claims, correctness gaps, common workload
  blockers, production pressure, and specialized features in that order.
- Update the roadmap, checklist, backend completion roadmap, and inventory with
  the accepted follow-up order.

See `phase5.md`.

## Acceptance

- No known placeholder execution path is reported as a usable feature.
- The source baseline and exclusions are explicit.
- Every audited Metal semantic has a stable ID and both backend outcomes.
- Current `DeviceFeatures` fields are represented by the coverage inventory.
- Unsupported decisions describe the missing semantic, not merely the backend
  name.
- A repeatable validation command checks ledger shape and feature coverage.
- Follow-up implementation slices are ordered without promoting incomplete
  rows to executable support.
