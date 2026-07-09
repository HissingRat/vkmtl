# Phase 3: Vulkan Ray Tracing Shader Path

Phase 3 adds the Vulkan shader path for the ray traced scene.

Status: complete for the first-scene Vulkan path.

## Scope

- Add or reuse embedded Slang shader source for ray generation, miss, and hit
  stages.
- Compile Vulkan ray tracing shaders to SPIR-V.
- Validate entry points and shader stage mapping.
- Keep shader diagnostics tied to the embedded source and entry names.

## Acceptance

- The shader artifacts needed by the Vulkan ray tracing pipeline are generated
  or loaded at runtime.
- Failure output names the missing shader stage or compiler problem.

## Completed

- Added `compileRayTracingShader(...)` to the runtime shader compiler.
- Added public `RayTracingShaderCompileOptions` and
  `CompiledRayTracingShader` exports.
- Added a dedicated embedded Slang RT shader for `examples/ray_traced_scene`.
- Verified `raygen`, `miss`, and `closest_hit` entry points compile to SPIR-V
  with the pinned Slang distribution.

## Deferred

- General shader library linking and advanced ray tracing shader model parity
  are Period32+ work.
