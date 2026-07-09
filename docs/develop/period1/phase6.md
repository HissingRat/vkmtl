# Phase 6 Decisions

These decisions start shader resource binding without exposing Vulkan
descriptor sets or Metal binding calls to user code.

## Current Scope

Phase 6 starts with public binding descriptions and runtime wrappers:

- `ShaderVisibility`
- `BindingResourceKind`
- `BindGroupLayoutDescriptor`
- runtime `BindGroupLayout`
- runtime `BindGroupDescriptor`
- runtime `BindGroup`

The first supported resource classes are:

- uniform buffers
- sampled textures
- samplers

Storage buffers, storage textures, dynamic offsets, arrays, immutable samplers,
and push constants are deferred beyond Phase 6. The first uniform-buffer and
sampled-texture paths now work end to end through public bind groups.

## Model

A bind group layout describes what a shader expects at each binding index.

Each layout entry has:

- a `binding` number
- a `resource` kind
- shader `visibility`

A runtime bind group descriptor describes the entries that should satisfy that
layout using actual vkmtl resource wrappers. Creation validates layout shape,
resource class, backend match, and whether referenced resources are alive.

Vulkan descriptor set allocation and command binding are wired in. The render
command encoder exposes `setBindGroup(...)`, performs debug validation, and
lowers to `vkCmdBindDescriptorSets` on Vulkan once a pipeline has been set.

Metal resource binding is also wired in. The Metal backend expands each bind
group entry into explicit vertex or fragment resource calls based on
`ShaderVisibility`.

Buffer binding ranges use:

- `offset`: byte offset into the buffer
- `size`: optional byte size

When `size` is `null`, the binding means the remaining buffer range. A size of
zero is invalid.

## Slang Mapping

Slang remains the only shader source language. Resource declarations should use
explicit group and binding annotations so generated reflection can map them to
vkmtl layouts.

The intended mapping is:

- Slang group -> vkmtl bind group index
- Slang binding -> `BindGroupLayoutEntry.binding`
- Slang resource class -> `BindingResourceKind`
- Slang stage usage -> `ShaderVisibility`

Reflection is now an optional layout and validation source on each programmable
stage.
`ProgrammableStageDescriptor.reflection` can point at generated reflection JSON
or inline reflection data. Validation checks stage, entry point, bind group
index, binding number, resource kind, and shader visibility against the
`bind_group_layouts` supplied to the pipeline descriptor.

`ShaderReflection.deriveRenderPipelineBindGroupLayouts(...)` and
`ShaderReflection.deriveComputePipelineBindGroupLayouts(...)` can derive
contiguous bind group layout descriptors from attached stage reflection.
Manual descriptors are still allowed when examples or applications need tighter
control. All shader-backed examples attach runtime-generated reflection
artifacts, and `zig build test` covers reflection parsing plus layouts used or
derived by the examples.

## Backend Mapping

The public model is backend-neutral:

- Vulkan lowers bind groups to descriptor set layouts, per-bind-group descriptor
  pools, descriptor sets, descriptor writes, and `vkCmdBindDescriptorSets`.
- Metal lowers bind groups to explicit encoder calls such as buffers, textures,
  and samplers on the vertex or fragment stage.

Vulkan pipeline layouts need the same bind group shapes. Pipelines that use
resources should provide `RenderPipelineDescriptor.bind_group_layouts`, usually
from `BindGroupLayout.descriptor()`.

Metal uses one buffer-index namespace for vertex input buffers and shader
resource buffers on the same stage. The Metal backend therefore maps public
vertex buffer slots to higher native Metal buffer slots, leaving low native
slots for Slang resource bindings such as `buffer(0)`.

This is one of the few places where vkmtl is not a direct Metal naming mirror,
because Vulkan needs grouped descriptor state. The user-facing object creation
and command flow should still stay Metal-inspired.

## Phase 6 Examples

Phase 6 originally closed with two public examples:

- `examples/uniform_buffer` binds a uniform buffer at group 0, binding 0.
- `examples/sampled_texture` binds a sampled texture at group 0, binding 0 and
  a sampler at group 0, binding 1.

Those standalone teaching examples were retired after the first vertical slice
stabilized. The current gallery covers the same binding paths through
`examples/rainbow_cube`.

The next roadmap slice is Phase 7: depth, MSAA, and render targets.
