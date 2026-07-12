# Phase 1: Semantic Splits And Public Allocation

Status: in progress.

## Decisions

- Split broad Metal protocol rows by observable vkmtl behavior before changing
  support status. A portable subset may close while an advanced remainder gets
  a new ledger ID and exactly-once route.
- Keep root 68, `Device` 34 methods, `WindowContext` 10 methods, and the 35
  opaque runtime-handle shapes unchanged.
- Existing common factories remain on `Device`; specialized additions belong
  to `resource`, `render`, `compute`, `shader`, or `transfer`, or to the natural
  runtime handle that performs the operation.
- New `DeviceFeatures`, `DeviceLimits`, format/vertex enum tags, descriptor
  fields, typed errors, and runtime-handle methods are `v0.2.0` changes. They
  must be documented before their implementation commit closes.
- `native_features` continues to mean raw adapter facts. A usable feature
  requires the complete vkmtl creation, validation, command, and evidence path.

## Public Allocation Candidates

- Compatible texture-view format and component mapping stay in
  `resource.TextureViewDescriptor`.
- Normalized-coordinate sampler choice stays in `resource.SamplerDescriptor`.
- Buffer GPU address is a capability-gated `Buffer` operation with a resource
  error; it does not become a `Device` convenience method or root declaration.
- Common format and vertex-format additions remain in `resource` and `render`.
- Compute atomics/threadgroup memory use their existing `compute` descriptors
  and feature/limit fields.
- Managed synchronization belongs to `transfer` and the blit encoder only if
  automatic map/copy composition cannot preserve the documented behavior.

No candidate is admitted merely because Metal exposes a method. Phase 2-5 may
close a candidate as precisely unsupported if Vulkan composition or ownership
cannot preserve its observable contract.
