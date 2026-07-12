# Phase 3: Vulkan And Compatibility Mapping

Status: planned.

## Mapping Rules

For each Metal semantic, Vulkan receives one of:

- a direct core or extension lowering (`native-exact`);
- several Vulkan operations plus vkmtl state (`composed-exact`);
- a compatibility implementation that preserves the complete observable
  contract (`emulated-exact`);
- typed `unsupported` when the contract cannot be preserved;
- `incomplete` when a possible mapping is not implemented or proven.

Every native/composed Vulkan mapping records the minimum core version or exact
extension/feature query and all relevant limits. A driver version or vendor
name is not a capability gate.

## Semantic Versus Performance Equivalence

- Hidden allocations and extra passes are allowed only when the public
  contract does not guarantee their absence.
- Transient attachment lifetime and hardware memoryless allocation are
  separate semantics.
- A Vulkan lazily allocated image may satisfy a capability-gated allocation
  strategy, but cannot promise that the implementation never allocates backing
  memory.
- A fallback that changes visible precision, ordering, synchronization, or
  resource lifetime is not exact emulation.

## Acceptance

- Every Metal ledger row has a Vulkan outcome and reason.
- Required core/extension/feature/limit gates are explicit.
- Unsupported and incomplete are distinguishable.
