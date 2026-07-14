# Period 51 Phase 1: Contract Allocation And Compiler Audit

Status: complete.

## Routed Rows

Period 51 owns:

- `MTL-REN-004`
- `MTL-REN-011` through `MTL-REN-016`
- `MTL-REN-020`

## Compiler Evidence

The repository-pinned Slang 2026.12.2 compiler was exercised directly before
the API allocation was accepted.

- A mesh entry compiled to `VK_EXT_mesh_shader` SPIR-V and to a Metal
  `[[mesh]]` function from the same Slang source.
- Vertex and fragment entries compiled for both targets.
- Hull and domain entries compiled to SPIR-V.
- The Metal target rejected hull and domain entry points as unavailable
  features. Native `MTLRenderPipelineDescriptor` tessellation fields and patch
  draw methods alone therefore do not constitute an executable vkmtl path.
- The task/amplification probe crashed Slang with status 139 for both targets
  after diagnosing the payload form. Native task/object bits therefore remain
  diagnostics-only until a stable pinned compiler artifact is available.

The build contract stays Slang-only. Period 51 does not add an unversioned
handwritten-MSL escape hatch simply to turn on a Metal feature bit.

## Decisions

1. Manifest schema 2 adds explicit tessellation and mesh declaration arrays.
   Schema 1 remains a valid complete manifest and retains its existing three
   arrays and behavior.
2. Advanced compilation and pipeline creation are canonical domain-facade free
   functions. They do not consume guarded `Device` method slots.
3. Tessellation execution opens on Vulkan when the full vertex/hull/domain/
   fragment pipeline and patch draw path is enabled. Metal remains precisely
   unsupported under the current shader-artifact contract.
4. Mesh execution opens independently on Metal and Vulkan. Optional Metal
   object/amplification and Vulkan task stages share one portable optional
   `task_entry`, but the current compiler audit keeps both usable gates false.
5. The existing planning descriptors remain useful validation inputs. Runtime
   advanced pipeline descriptors add shader artifacts and ordinary attachment,
   binding-layout, and raster state without exporting native handles.
6. Tile/imageblock and ordered programmable blend need shader-language and
   render-pass memory contracts that schema 2 does not add. They close as
   unsupported in this period.
7. Layered/view amplification, logical attachment remapping, rasterization-rate
   coordinate transforms, programmable sample positions, and depth-clip
   control remain separate semantics. No one feature is used as an
   approximation for another.

## Compatibility

All additions are targeted at `v0.2.0`. The public root and common-owner
allowlists stay fixed, and the existing `RenderPipelineState` handle layout is
unchanged.
