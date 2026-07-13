# Period 50 Phase 2: Native Scalable Resource Tables

Status: complete.

## Metal

- Build an `MTLArgumentEncoder` from the backend-neutral table ranges.
- Allocate shared argument-buffer storage using the encoder's exact encoded
  length and alignment.
- Apply buffer, texture, and sampler updates to the requested array element.
- Bind the argument buffer at the appended pipeline-layout index for every
  visible render/compute stage and declare referenced resources to Metal.
- Open `argument_buffers` only when the complete allocation/update/bind path is
  available.

## Vulkan

- Query and enable runtime descriptor arrays, non-uniform resource indexing,
  partially-bound descriptors, and the update-after-bind features required by
  the supported resource classes.
- Create descriptor-set layouts with per-binding flags and matching pool
  flags.
- Allocate/update descriptor sets and bind them at the appended pipeline-layout
  index.
- Query conservative descriptor-count limits and keep the usable feature closed
  unless the entire required feature bundle is enabled.

## Validation

- Reject overlapping binding/array ranges.
- Revalidate resource liveness before command binding.
- Keep table layout and pipeline layout backend/model compatible.
- Permit Vulkan update-after-bind replacement only; reject post-bind clear
  because null descriptors are outside the enabled baseline.
- Exercise a 64-entry sampled-texture table and sample a nonzero array element.
