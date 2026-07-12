# Period 47: Core Resource, Format, Render, And Compute Breadth

Status: in progress.

Goal: close the common-workload subset of the 15 Period 45 rows routed to P47
without treating each broad Metal protocol family as one portable promise.
Every row is split into an executable vkmtl semantic and any advanced remainder
before capability or evidence is upgraded.

## Routed Rows

| Row | Period 47 portable target | Deferred boundary |
| --- | --- | --- |
| `MTL-DEV-003` | Ordinary execution limits used by resources and compute | Native memory budget/working-set telemetry stays in Period 49. |
| `MTL-RES-002` | Current shared/managed/private storage behavior and automatic hazards | Explicit cache policy and advanced hazard modes stay with Periods 48-49. |
| `MTL-RES-004` | Capability-gated shader-visible buffer GPU address | No unconditional address support. |
| `MTL-RES-006` | Subresource views, compatible format reinterpretation, component swizzle | Incompatible reinterpretation stays typed unsupported. |
| `MTL-RES-007` | Common portable texture and vertex formats with exact capability queries | The full Metal/Vulkan format universes remain outside one closed enum. |
| `MTL-RES-008` | Filtering, addressing, LOD, compare, anisotropy, normalized coordinates, and portable border colors | Device-specific border colors and sampler extensions remain unsupported. |
| `MTL-REN-001` | MRT color/depth/stencil attachment load/store/resolve behavior | Tile-only and advanced pass attachments remain in Periods 51 and 54. |
| `MTL-REN-007` | Ordinary buffers, textures, samplers, bind groups, and root bytes | Heaps and function tables stay in Periods 50 and 52. |
| `MTL-REN-008` | Viewport, scissor, winding/cull/fill, depth bias, blend color, and stencil reference | Depth clip variants, sample positions, and advanced raster state stay in Period 51. |
| `MTL-CMP-002` | Ordinary buffers, textures, samplers, bind groups, and root bytes | Heaps and function tables stay in Periods 50 and 52. |
| `MTL-CMP-003` | Direct, indirect, and documented `dispatchThreads` composition | Backend-specific concurrent/grid scheduling is not promised. |
| `MTL-CMP-004` | Resource barriers and portable hazard ordering between dispatches | Native fences/events stay in Period 48. |
| `MTL-CMP-005` | Capability-gated shader atomics and threadgroup memory with real limits | Unsupported atomic families remain closed. |
| `MTL-XFR-004` | Exact managed/host-visible synchronization composition | Backend-specific optimization hints remain outside the portable contract. |
| `MTL-SHD-003` | Slang reflection for portable buffers, textures, samplers, arrays, access, and vertex inputs | Tensor, payload, function-table, and Metal-only reflection stay in Periods 52 and 54. |

## Phase Plan

1. Semantic splits and public allocation decisions.
2. Limits, formats, views, samplers, storage modes, and buffer addresses.
3. Render attachments, ordinary bindings, and dynamic raster state.
4. Compute dispatch/barriers/atomics/threadgroup memory and reflection.
5. Managed synchronization, evidence, inventory updates, and closeout.

See `phase1.md` through `phase5.md`.

## Compatibility Boundary

Period 47 adds no root alias and no `Device` or `WindowContext` method. Public
enum tags, descriptor fields, feature/limit fields, and specialized runtime
handle methods are allocated only in their existing domain. Because enum and
error-set growth can break exhaustive downstream code, all Period 47 public
surface changes target `v0.2.0` and require changelog, migration-guide, public
inventory, and API-guard validation in the same implementation change.

## Acceptance

- No broad source row is marked complete while a deferred sub-semantic remains
  hidden inside it.
- Usable features and format capabilities open only for executable backend
  paths.
- Existing examples keep using canonical vkmtl APIs.
- Focused deterministic tests, default and forced-Vulkan builds, API and
  semantic guards, and appropriate physical GPU evidence pass.
