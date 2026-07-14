# Headless Context Design

Status: complete, 2026-07-14.

## Goal

Add a real GPU runtime owner that does not create or require a window,
surface, swapchain, drawable, or presentation queue. Compute, transfer,
resource, ray-tracing, and texture-backed offscreen render work should use the
same public `Device`, `Queue`, resource, pipeline, and command types as a
windowed context.

`WindowContext` remains source- and behavior-compatible. Headless execution is
an additive `v0.1.x` API, not a mode added to `WindowContext`.

## Public Allocation

`HeadlessContext` is one new root declaration. It satisfies the root admission
rules because backend-neutral GPU initialization is a common path and the
owner has the same lifetime contract on Vulkan and Metal.

Options are nested so no second root declaration is needed:

```zig
pub const HeadlessContext = struct {
    _state: *anyopaque,

    pub const Options = struct {
        app_name: [*:0]const u8,
        backend: BackendPreference = .auto,
        adapter_selection: AdapterSelectionDescriptor = .{},
        debug_backend_override: ?Backend = null,
    };

    pub fn init(allocator: std.mem.Allocator, options: Options) !HeadlessContext;
    pub fn deinit(self: *HeadlessContext) void;
    pub fn selectedBackend(self: HeadlessContext) Backend;
    pub fn adapterInfo(self: HeadlessContext) AdapterInfo;
    pub fn device(self: *HeadlessContext) Device;
    pub fn queue(self: *HeadlessContext) Queue;
};
```

`Device` and `Queue` are borrowed views. Every resource and submitted work item
must finish and be destroyed before `HeadlessContext.deinit()`.

The initial API does not expose `nativeHandles()` or `nativeHandleView()`.
Existing `NativeHandles` contains Vulkan surface/present-queue and Metal
layer/view fields, so returning it from a headless owner would invent invalid
sentinel semantics. A future device-only native escape hatch belongs under
`native` and requires its own allocation decision.

## Backend Contract

- Vulkan loads the Vulkan loader without a window provider, enables only
  instance and device extensions required by the selected physical device,
  does not create a `VkSurfaceKHR`, does not require `VK_KHR_swapchain`, and
  does not select a presentation queue.
- Metal creates an `MTLDevice` plus graphics/compute/transfer command queues
  without an `NSWindow`, `NSView`, `CAMetalLayer`, drawable, or presentation
  depth texture.
- Current-drawable render passes and present operations are unavailable from a
  headless owner. Texture-view-backed render passes remain valid.
- Backend selection uses device availability rather than surface-provider
  availability. `.auto` keeps the existing Darwin-first-Metal and
  non-Darwin-first-Vulkan ordering.

## Internal Ownership

`HeadlessContext` lives in `src/runtime/headless_context.zig`. It and
`WindowContext` share one private runtime state and backend execution path;
the implementation must not duplicate public resource or command wrappers.
Presentation state stays optional and backend-private. Window-only methods
continue to be reachable only through `WindowContext`, `Surface`, and
`Swapchain`.

## Executable Evidence

- `examples/compute_readback` and `examples/transfer_readback` initialize
  `HeadlessContext` directly and have no GLFW import, initialization, or link.
- Default Metal runs complete without AppKit presentation objects. Compute
  readback passes; transfer readback passes buffer/texture transfers plus a
  texture-view-backed offscreen clear/readback.
- `zig build -Dvulkan` compiles the dynamic-loader, no-surface path. This host
  has no `libvulkan` or MoltenVK loader, so Vulkan physical execution remains a
  precisely recorded device-matrix rerun rather than an inferred pass.
- `zig build run-api-guard` reports root 69, `Device` 34,
  `WindowContext` 10, `HeadlessContext` six, and 37 runtime handles.
- `zig build test --summary all` passes 626/626 tests, including current-
  drawable rejection and semantic-inventory validation (59 family rows, 110
  Metal semantic rows, 78 protocols, and 34 routed gaps).
- Formatting, default build, forced Vulkan build, external package smoke, and
  `git diff --check` pass.
