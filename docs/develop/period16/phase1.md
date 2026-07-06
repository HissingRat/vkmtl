# Phase 1: Vulkan Tessellation Lowering

Phase 1 implements Vulkan tessellation pipeline lowering.

## Scope

- Enable tessellation features for supported Vulkan devices.
- Create pipelines with tessellation control and evaluation stages.
- Map patch control points and partitioning descriptors.

## Validation

- Tests should validate patch-control-point limits.
- A Vulkan smoke example should render a tessellated primitive.
