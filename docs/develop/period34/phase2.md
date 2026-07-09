# Phase 2: Vulkan AABB Geometry And Intersection Shader

Phase 2 implements the Vulkan procedural geometry path for spheres.

## Checklist

- [x] Add AABB geometry descriptors for Vulkan acceleration structure builds.
- [x] Add public ray tracing pipeline descriptors for intersection stages.
- [x] Extend Slang ray tracing shader compilation for intersection stages.
- [x] Create Vulkan shader groups that include procedural hit groups.
- [x] Materialize SBT records for procedural hit groups.
- [x] Pass sphere parameters to the intersection/closest-hit shader path.
- [x] Add validation for unsupported intersection shader features.

## Acceptance

- Vulkan can build procedural sphere geometry into a BLAS.
- Vulkan can dispatch ray tracing with intersection shader stages.
- The full scene can shade procedural sphere hits through native Vulkan RT.
