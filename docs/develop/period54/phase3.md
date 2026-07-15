# Period 54 Phase 3: Exact Compositions

Status: complete.

## Argument Tables

The admitted `MTL4ArgumentTable` observable contract is composed through the
existing `binding.ResourceTable` rather than a second public table owner.
Metal uses scalable argument-buffer slots, retains resources, and emits
`useResource` declarations when the table is bound. Vulkan uses descriptor
indexing and update-after-bind validation. Pipeline-layout fingerprints and
slot kinds remain identical across both paths.

This claim is limited to vkmtl's existing buffer, texture, and sampler table
shape. It does not promise raw `MTL4ArgumentTable` identity or unallocated
Metal-only entry kinds.

## Explicit Barriers

The existing buffer/texture barrier contract preserves the observable Metal 4
ordering semantic. Metal combines encoder ordering with vkmtl tracked hazards;
Vulkan emits native pipeline barriers. A new Metal 4 command-encoder owner is
not needed to preserve that portable effect.
