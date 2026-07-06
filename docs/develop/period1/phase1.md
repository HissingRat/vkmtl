# Phase 1 Decisions

These decisions define the first public vkmtl API shape. They are intentionally
small so later rendering work can replace placeholders with real backend state.

## Backend Dispatch Model

Use a private tagged-union style model for the first runtime backend dispatch.

Reasoning:

- `.auto` requires runtime backend selection.
- Zig switches over a small enum are explicit and easy to audit.
- Backend state can remain private and move behind richer structs later.
- Comptime specialization is useful for examples or advanced builds later, but
  it should not be the only public path.

Function tables can be introduced later if the switch sites become noisy.

## API Style

The public API should be Metal-inspired.

Preferred naming and usage shape:

- `Device`
- `CommandQueue`
- `CommandBuffer`
- `RenderCommandEncoder`
- `RenderPipelineDescriptor`
- `RenderPipelineState`
- `TextureDescriptor`
- `Buffer`
- `Texture`
- `SamplerState`

vkmtl does not need to copy Metal exactly. Names and descriptors can change when
Vulkan portability requires a clearer abstraction, but the user experience
should stay closer to Metal's object-oriented command recording model than to
Vulkan's explicit descriptor/synchronization-heavy model.

## Public Handle Model

Public objects start as opaque structs with a selected `Backend` tag:

- `Context`
- `Adapter`
- `Device`
- `Queue`
- `Surface`

Phase 1 only makes these shapes available. They do not yet create real GPU
resources. Later phases will add private backend payloads and constructors.

## Ownership And Lifetime

The intended ownership tree is:

```text
Context
  -> Adapter
    -> Device
      -> Queue
      -> Surface
      -> resources and pipelines
```

Children must be destroyed before their parent. Phase 1 does not yet enforce
resource lifetimes because it has no real backend resources. Later debug builds
should track live children and report invalid destruction order.

## Backend Selection Precedence

Selection is pure logic in Phase 1:

1. An explicit `.vulkan` or `.metal` preference wins.
2. An environment/debug override only applies when preference is `.auto`.
3. `.auto` prefers Metal on Apple platforms and Vulkan elsewhere.
4. `.auto` may fall back to the other available backend.
5. If no requested or fallback backend is available, selection returns a typed
   error.

Environment reading is not wired into `Context.init` yet. Tests pass an override
explicitly to keep selection deterministic.

## Native Handle Escape Hatches

Native handles are allowed only through explicit advanced/debug APIs. The normal
public API should not expose Vulkan or Metal types.

Naming convention for future work:

- `nativeVulkan()` for Vulkan-specific handles
- `nativeMetal()` for Metal-specific handles

These APIs are not part of Phase 1. When added, they should document whether
the returned handle is borrowed, how long it stays valid, and whether users may
call mutating native API functions on it.

## Example Layout

The first public example target is `examples/triangle`.

Current layout:

```text
examples/
  common/
    window.zig
  triangle/
    main.zig
    shaders/
      triangle.slang
```

`examples/triangle/main.zig` is now the public triangle sample and must import
only the public `vkmtl` module plus approved public example/window helpers.

The public triangle build step is `run-triangle`; the generic `run` aliases the
same public example.
