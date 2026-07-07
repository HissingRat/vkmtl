# Phase 3: Vertex Instance Step Rate

Phase 3 finishes vertex-layout lowering for non-default instance stepping.

## Scope

- Lower `VertexBufferLayout.instance_step_rate` to Vulkan vertex input binding
  divisors where available.
- Lower `instance_step_rate` to Metal vertex descriptor step rate.
- Keep missing backend support behind precise feature gates.

## Status

Completed.

## Backend Notes

- Metal lowers `instance_step_rate` to `MTLVertexBufferLayoutDescriptor.stepRate`.
- Vulkan lowers non-default per-instance step rates through
  `VK_KHR_vertex_attribute_divisor` or `VK_EXT_vertex_attribute_divisor` when
  the selected device exposes the divisor feature.
- `instance_step_rate != 1` is valid only for `.per_instance` vertex buffers.

## Validation

- Add validation coverage for step-rate feature gates.
- Add or update an instancing example once the native path is available.
