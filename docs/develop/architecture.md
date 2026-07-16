# Architecture

This document is the stable architecture reference for vkmtl. It describes
the boundaries that implementation work must preserve; release status and
remaining work belong in `roadmap.md`, while exact public declarations and
backend execution claims belong in the two inventories.

## Design Goal

vkmtl is a Zig graphics abstraction with interchangeable Metal and Vulkan
backends. The public API describes vkmtl concepts. Backend modules translate
those concepts into native calls without requiring applications, examples, or
other library subsystems to understand the selected backend.

Every major subsystem must be replaceable without rewriting the rest of the
library:

```text
examples and applications
  -> public vkmtl API
    -> portable descriptors, handles, validation, capabilities
      -> backend-neutral runtime boundary
        -> backend/vulkan
        -> backend/metal
      -> platform and window integration
      -> shader build and runtime pipeline
```

Dependencies point downward in that diagram. A lower layer must not import an
example or public convenience layer to perform backend work.

## Public Concepts And Module Boundaries

The common path uses Metal-inspired object ownership where it is useful:
descriptors create state objects, queues create command buffers, command
buffers create encoders, and encoders record work. This is a usage model, not
a promise that one vkmtl operation maps to one native Metal call.

The portable API is divided into a small root and domain namespaces:

| Namespace | Responsibility |
| --- | --- |
| `resource` | buffers, textures, views, samplers, heaps, sparse descriptors, and residency plans |
| `shader` | shader declarations, compilation descriptors, reflection, and specialization |
| `binding` | bind group layouts, bind groups, resource tables, dynamic offsets, and constants |
| `render` | render passes, pipelines, attachments, raster state, tessellation, and mesh work |
| `compute` | compute pipelines, dispatch, atomics, and threadgroup memory |
| `transfer` | copy, fill, blit, mipmap, upload, and readback operations |
| `command` | command buffers, encoder state, queue selection, and lifecycle contracts |
| `sync` | barriers, fences, events, queue ownership, and synchronization capability queries |
| `presentation` | surfaces, swapchains, present modes, resize, and frame pacing |
| `ray_tracing` | acceleration structures, ray pipelines, shader binding tables, dispatch, and queries |
| `interop` | external resources and explicit platform import/export contracts |
| `diagnostics` | capability reports, cache plans, profiling, capture, and debug data |
| `native` | explicit backend handles, lowerings, and backend-specific operations |

A declaration has one canonical home. Root aliases are reserved for the
ordinary cross-backend path and are not precedent for adding more flat names.
Specialized planning, diagnostics, interop, and backend lowering stay in their
domain facades even when a common owner is passed as the first argument.

Public API modules may define backend-neutral descriptors, enums, flags,
errors, and opaque handles. They must not import Vulkan bindings, Metal bridge
headers, GLFW internals, or platform Objective-C implementation details.

`backend/vulkan` may import Vulkan bindings. `backend/metal` may import the
Metal bridge. Platform/window code owns native surface creation and must not
become the resource, pipeline, or command implementation. Shader tooling is a
separate subsystem so the compiler or source language can change without
rewriting render-command code.

## Backend Contract

Each backend implements the same conceptual services:

1. enumerate adapters and report why a backend is unavailable;
2. select a device and expose features, limits, and format capabilities;
3. create devices and graphics, compute, and transfer queues;
4. create and destroy buffers, textures, views, samplers, and heaps;
5. create shader modules, binding layouts, and pipeline states;
6. create surfaces and presentation chains for windowed runtimes;
7. encode render, compute, transfer, synchronization, and advanced commands;
8. submit work, track completion, and present frames;
9. expose explicitly gated native operations where no portable contract is
   appropriate.

The abstraction promises equivalent observable effects where a feature is
reported executable. It does not require identical call counts or identical
native object graphs. One vkmtl operation may lower to several Vulkan calls,
several Metal calls, an internal state machine, or a compatibility layer.

If one backend cannot preserve the declared semantics, it reports the feature
or format as unavailable and returns a typed unsupported error before native
work. A planning record, a native query result, or an enum tag is not evidence
that an execution path exists. The authoritative execution status is recorded
in `native-semantic-coverage-inventory.md`.

Backend selection is explicit through `.auto`, `.vulkan`, or `.metal`.
`.auto` prefers Metal first on Darwin and Vulkan first elsewhere, then follows
the documented availability result. Applications should query the selected
backend and capabilities rather than infer them from the operating system.

## Features, Limits, And Validation

`DeviceFeatures`, `DeviceLimits`, and format capabilities describe the
selected device, not the theoretical backend maximum. Advanced operations
must validate all required feature, limit, format, queue, ownership, and
lifetime conditions before encoding native work.

Feature meanings are deliberately narrow. For example, a native API having a
related extension does not make a vkmtl feature true until its public shader,
resource, binding, execution, and completion path is usable. Unsupported
native-only concepts remain false or typed unsupported rather than receiving a
weaker approximation under the same feature name.

Validation errors identify the failing operation and category. Backend errors
remain typed enough to distinguish unavailability, invalid state, unsupported
semantics, device loss, surface loss, and native execution failure. Backends
must not silently substitute a different semantic contract.

## Runtime Ownership Model

### Runtime Owners

`WindowContext` and `HeadlessContext` are heap-runtime owners. Their `Device`
and primary `Queue` values are borrowed views into the owned runtime. A
`Surface` and `Swapchain` borrowed from `WindowContext` are views into that
same windowed runtime.

Borrowed views must not outlive their owner. Every resource, pipeline,
command buffer, encoder, submission, and callback that uses the runtime must
finish and be destroyed before the owning context is deinitialized.

Factories express natural ownership:

- `Device` creates resources, shaders, pipelines, synchronization objects, and
  queues;
- `Queue` creates command buffers;
- `Surface` exposes its presentation chain;
- `Swapchain` owns resize, clear, selected-format, extent, and presentation
  state;
- domain facades own specialized validation and planning operations.

`WindowContext` is not a forwarding collection for all device operations.

### Runtime Handles

Exported runtime handles expose one implementation-storage field named
`_state`. It is either inline opaque bytes for a value-owned handle or an
opaque pointer for a heap-owned or borrowed view. The field is an
implementation boundary, not an application extension point.

Applications must not:

- construct a runtime handle with a struct literal;
- read, write, copy assumptions from, or persist `_state`;
- depend on its size, alignment, layout, or backend record;
- use a raw native handle as a stable vkmtl identity.

Use documented factories, public methods, and `deinit`. No public handle may
expose a backend union, resource tracker, debug record, or private state type.

### Destruction And Submission

Destroy children before their owning storage or runtime. In particular:

- destroy or complete submitted work before destroying referenced resources;
- destroy heap-backed resources before their `Heap`;
- destroy work borrowing an imported resource before its external owner;
- keep acceleration-structure build inputs and referenced child structures
  alive for every submission that reuses them;
- destroy all context-dependent objects before `WindowContext.deinit()` or
  `HeadlessContext.deinit()`.

Command buffers are one-shot runtime objects. A successful commit completes
the current synchronous contract. A backend commit failure terminally
consumes that command buffer, releases runtime borrows, retires submitted work,
and reports a failed lifecycle state. Retrying the same object is unsupported.

## Windowed And Headless Runtime Owners

### WindowContext

`WindowContext` owns a window-integrated runtime. It creates or consumes the
platform surface source, selects presentation support, and owns the state
needed for current drawables and presentation.

Its stable owner responsibilities are:

```text
init
deinit
selectedBackend
adapterInfo
nativeHandles
nativeHandleView
device
queue
surface
swapchain
```

Window-specific work remains reachable through `Surface`, `Swapchain`, and
current-drawable command operations. Resource and pipeline creation belongs to
the borrowed `Device`; command-buffer creation belongs to the borrowed
`Queue`.

### HeadlessContext

`HeadlessContext` is a distinct additive owner rather than a mode on
`WindowContext`:

```zig
var context = try vkmtl.HeadlessContext.init(allocator, .{
    .app_name = "compute-worker",
    .backend = .auto,
});
defer context.deinit();

var device = context.device();
var queue = context.queue();
```

It creates a device/queue runtime without a window, surface, swapchain,
drawable, or presentation queue. Compute, transfer, resource, ray-tracing,
and texture-backed offscreen render work use the same public `Device`,
`Queue`, resource, pipeline, and command types as windowed work.

The Vulkan headless path loads the Vulkan loader without a window provider,
does not create `VkSurfaceKHR`, does not require `VK_KHR_swapchain`, and does
not select a presentation queue. The Metal path creates `MTLDevice` and
command queues without `NSWindow`, `NSView`, `CAMetalLayer`, drawable, or
presentation depth state.

Current-drawable passes and present operations are unavailable. Texture-view
attachments remain valid. Headless adapter selection is based on device
availability, not surface-provider availability.

`HeadlessContext` intentionally has no `Surface`, `Swapchain`, current
drawable, or presentation-shaped native-handle view. The existing native
handle bundle includes windowed fields, so returning it would require invalid
sentinels. Any future device-only escape hatch belongs under `native` and
requires an explicit public allocation decision.

`HeadlessContext` and `WindowContext` share the private runtime and backend
execution implementation. Headless support must not duplicate the public
resource or command wrappers.

## Shader Architecture

Slang is the source language. Consumer shaders are declared at build time and
embedded in the `vkmtl` module:

```text
Slang source and includes
  -> pinned build-time slangc
    -> SPIR-V for Vulkan
    -> MSL plus reflection for Metal
      -> generated embedded shader blobs
        -> public runtime shader facade
```

The build owns the pinned compiler version and download metadata. Setup
command bodies live under `scripts/`, not as large inline shell fragments in
`build.zig`. Known embedded shader declarations are precompiled by `zig
build`; inspection copies belong under `zig-out/shaders/<shader-name>/`.

Applications register shaders with the dependency's source-backed
`shader_manifest` `std.Build.LazyPath` option. The manifest, declared sources,
and Slang include/import dependencies reported through depfiles are build
inputs. Paths are relative to the manifest and must remain inside the
LazyPath owner's logical root.

Runtime shader APIs consume embedded blobs directly from memory. They do not
spawn `slangc`, search for it beside the executable, parse a runtime cache
directory, or write SPIR-V, MSL, reflection JSON, or `vkmtl-cache` beside the
application. A missing name/entry/source-hash match returns a typed missing
precompiled shader error.

Reflection drives bind-group layout derivation, vertex descriptor derivation,
and binding validation. Applications may still provide explicit descriptors
when they need direct control. Public examples use `@embedFile(...)`, the
canonical `shader` facade, and the `Device` borrowed from either context.

Shader compilation is replaceable: public render, compute, and ray-tracing
commands depend on vkmtl shader artifacts and reflection, not on Slang process
details or backend compiler types.

## Presentation Architecture

Presentation is owned by `Surface` and `Swapchain`, not by ordinary resources.
`PresentationDescriptor` records an application request. The swapchain
reports concrete native state:

- `presentationDescriptor()` returns the retained request;
- `selectedFormat()` returns the concrete drawable format;
- `extent()` returns the current actual native extent.

The actual extent may differ from the request because of Vulkan surface
constraints. A pipeline targeting the current drawable must use the selected
format. A mismatch returns `PresentationFormatMismatch`; vkmtl does not
silently rebuild or rewrite the pipeline.

The portable SDR format policy admits `bgra8_unorm_srgb` and `bgra8_unorm`.
`.automatic` prefers sRGB, then linear. An explicit admitted request is exact;
if unavailable, it returns `UnsupportedPresentationFormat` rather than
selecting an unrelated native format.

Resize is transactional where native APIs permit it. A healthy zero-size
resize preserves the last successful request, actual extent, and selected
format. Vulkan refuses non-zero resize and clear while an uncommitted backend
command buffer exists. Once native recreation or dependent rebuilding starts,
a failure permanently loses that presentation runtime; later presentation
operations return `SurfaceLost`, and the caller recreates `WindowContext`.

The preferred ray-tracing presentation route is:

1. dispatch into an application-owned texture with
   `dispatchRaysToTexture(...)`;
2. commit the producing command buffer;
3. sample or otherwise compose that texture in a later pass;
4. render to a pipeline using `Swapchain.selectedFormat()`;
5. present the drawable.

`dispatchRaysToDrawable(...)` is a compatibility route with an implicit
presentation side effect. It copies a validated whole `bgra8_unorm` output to
the selected BGRA8 drawable and must not be followed by a duplicate present on
the same command buffer.

## Color Boundary

vkmtl transports numeric resource values and selects declared attachment and
presentation formats. It does not inspect scene content or define an
application's lighting or display transform.

The presentation layer does not perform:

- HDR mapping or exposure;
- tone mapping;
- gamma policy beyond the declared format's native transfer behavior;
- gamut or color-space conversion;
- artistic brightness, contrast, or environment-light adjustment.

An sRGB attachment applies the transfer behavior defined by that format. A
raw copy preserves bytes; it does not decode or encode them. Ray generation
does not assign a color space to its output texture. Applications that store
display-referred values, scene-linear HDR values, or another encoding must
provide the matching composition shader and select an appropriate final
format.

This boundary keeps Metal and Vulkan semantics aligned without turning vkmtl
into a color-management or rendering-engine layer.

## Native Escape Hatches

Backend-specific handles and operations live under `native`,
`native.vulkan`, or `native.metal`. Entering a backend namespace removes a
redundant backend prefix; portable descriptors do not contain raw Vulkan or
Metal types.

Native handle views are intentional, borrowed escape hatches. Their lifetime
is bounded by the owning vkmtl object and any documented command-encoding
scope. They are not stable across devices, processes, vkmtl versions, or
backend recreation. Backend-native source and semantic compatibility is not
part of the portable `0.x` promise.

`presentation.SurfaceSource.vulkan` is the sole approved callback exception in
portable presentation integration. Its `native.vulkan.SurfaceProvider` shape
creates a Vulkan surface without leaking generated binding types into the
portable descriptor. It is not precedent for more native fields.

Portable sparse descriptors and residency plans stay under `resource`.
Backend-selection results such as sparse lowering modes and planners belong
under `native`. The same distinction applies to tessellation, mesh, ray
tracing, and other advanced native lowerings.

Adding a native exception requires an explicit design decision, capability and
lifetime contract, inventory update, and API-guard change. When portable
equivalence cannot be preserved, expose the native route honestly or mark the
portable feature unsupported; do not hide a weaker substitute behind the same
name.

## Architectural Invariants

Changes preserve these invariants:

1. Examples and applications import only the public `vkmtl` module.
2. Public concepts do not depend on concrete backend implementation types.
3. Natural owners create and destroy objects; contexts do not accumulate
   compatibility forwards.
4. Capabilities describe executable paths on the selected device.
5. Unsupported semantics fail with a typed error before native work.
6. Runtime implementation state remains opaque.
7. Windowed and headless owners share resource and command implementations.
8. Runtime shader compilation never depends on a subprocess or writable
   cache.
9. Presentation selection is explicit, while content color transforms remain
   application policy.
10. Native access is isolated, lifetime-bounded, and never implied to be
    portable.
