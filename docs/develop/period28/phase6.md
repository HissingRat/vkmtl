# Phase 6: Parity Matrix Closure

Phase 6 turns parity into a maintained product artifact.

## Scope

- List portable, Vulkan-only, Metal-only, fallback, and unsupported features.
- Decide which unsupported items become future periods.
- Keep feature reports aligned with backend reality.
- Decide whether partial mip/layer-range mipmap generation becomes a portable
  emulation path or an explicit backend-specific escape hatch.
- Decide depth/stencil and MSAA texture-copy semantics across Vulkan and Metal,
  including which cases are portable, backend-specific, or intentionally
  unsupported.
- Decide whether custom sampler border colors are worth a portable API or
  should remain a backend-specific extension path.
- Add GPU-backed resize/resource/upload soak loops once the production matrix
  identifies which backend paths are ready for long-running native execution.

## Validation

- Add matrix consistency checks where possible.
- Update docs whenever feature gates change.

## Result

- Added an authoritative ray tracing/native parity matrix in
  `tools/development_matrix.zig`.
- Added Period 29 as the executable native backend follow-up period.
- Routed native acceleration-structure builds, native ray tracing pipelines,
  native SBT/dispatch commands, Metal ray tracing execution, native advanced
  escape-hatch execution, parity semantics, stress validation, and native
  examples to specific Period 29 phases.
- Migrated older Period 28 deferred references to concrete Period 29 targets.

## Deferred

- Native acceleration-structure execution: Period 29 Phase 1.
- Native ray tracing pipelines: Period 29 Phase 2.
- Native SBT and ray dispatch commands: Period 29 Phase 3.
- Native Metal ray tracing execution mapping: Period 29 Phase 4.
- Native advanced escape-hatch execution: Period 29 Phase 5.
- Remaining parity semantics were completed in Period 29 Phase 6; GPU-backed
  soak loops are owned by Period 44.
- Native advanced examples: Period 29 Phase 7.
