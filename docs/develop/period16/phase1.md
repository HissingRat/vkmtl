# Phase 1: Vulkan Tessellation Lowering

Phase 1 implements Vulkan tessellation pipeline lowering.

## Scope

- Enable tessellation features for supported Vulkan devices.
- Create pipelines with tessellation control and evaluation stages.
- Map patch control points and partitioning descriptors.
- Keep the first slice as descriptor-to-lowering metadata until native pipeline
  creation is wired.

## Validation

- Tests should validate patch-control-point limits.
- A Vulkan smoke example should render a tessellated primitive.
- Unit tests should assert Vulkan lowering preserves patch metadata.
