# Phase 1: Native Acceleration Structure Builds

Phase 1 turns acceleration-structure build plans into backend resources and
commands.

## Scope

- Allocate Vulkan and Metal acceleration-structure backing resources.
- Encode build/update commands from `AccelerationStructureBuildPlan`.
- Validate scratch/result resource usage, alignment, and lifetime.

## Validation

- Add backend tests for invalid scratch/result resources.
- Add feature-gated examples or smoke paths where supported.
