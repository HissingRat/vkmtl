# Phase 4: Sampler Border Color

Phase 4 lowers sampler border-color descriptors.

## Scope

- Map supported border colors to Vulkan sampler state.
- Map supported border colors to Metal sampler state where available.
- Keep unsupported border color values typed and feature-gated.

## Validation

- Add sampler validation tests for supported and unsupported border colors.
- Update feature and limit reporting.
