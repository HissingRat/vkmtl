# Period 41: External Interop Matrix

Status: Phase 2 complete.

Goal: make external memory, external textures, and external synchronization
usable through an explicit platform matrix instead of descriptor-only probes.

## Expected Result

After Period41, external interop should have real import/export paths on
supported platform combinations, documented handle types, lifetime rules, and
validation examples for shared textures and synchronization.

## Phase Plan

### Phase 1: Interop Capability Matrix

- List supported Vulkan handle types by platform.
- List supported Metal shared texture/event paths by platform.
- Distinguish portable, capability-gated, and native-only lanes.

Phase 1 result:

- `ExternalInteropCapabilityMatrix` reports the selected backend, platform,
  usable feature gates, native feature gates, and static capability entries.
- Vulkan entries distinguish Linux `opaque_fd`, Windows `win32_handle`, and
  backend-native Vulkan object handles.
- Metal entries distinguish Apple `IOSurface`, Metal buffer/texture objects,
  and Metal shared events on macOS/iOS.
- Each entry is classified as `portable`, `capability_gated`, `native_only`,
  or `unsupported`, so diagnostics can describe why an import path is missing
  before native import code runs.

### Phase 2: Vulkan External Memory/Image/Semaphore Import

- Implement external memory and image import planning where supported.
- Implement external semaphore wait/signal import planning where supported.
- Validate handle ownership and lifetime before backend import hooks run.

Phase 2 result:

- `ExternalInteropImportPlan` records backend, platform, resource kind, handle
  kind, interop lane, feature gate, ownership, and whether the import requires
  native backend work.
- Vulkan import planning now distinguishes Linux `opaque_fd`, Windows
  `win32_handle`, and backend-native Vulkan handles for memory, texture/image,
  and semaphore resources.
- `Device.planExternal*Import(...)` and `Device.makeExternal*(...)` validate
  native feature gates and attach the resolved import plan to runtime wrappers.
- Missing native support returns the resource-specific typed error
  (`UnsupportedExternalMemory`, `UnsupportedExternalTextures`, or
  `UnsupportedExternalSemaphores`) instead of silently creating an unusable
  wrapper.
- The real OS/Vulkan handle import calls remain behind backend hooks; the
  public contract and diagnostics are now stable enough for those hooks to use.

### Phase 3: Metal Shared Texture/Event Import

- Implement shared texture and shared event import where supported.
- Define process/device compatibility constraints.
- Preserve native objects behind explicit interop wrappers.

### Phase 4: External Texture Sampling And Presentation Examples

- Turn `examples/external_texture` from a wrapper probe into a real interop
  sample where a supported external texture is available.
- Validate sampling, copy, and presentation usage.

### Phase 5: External Synchronization Validation

- Add examples/tests for external wait/signal paths.
- Validate ordering across imported objects and vkmtl command submission.
- Report unsupported platform combinations precisely.

### Phase 6: Safety, Lifetime, And Platform Docs

- Document imported object ownership.
- Document cross-process and cross-API caveats.
- Add issue-report diagnostics for failed imports.

## Acceptance

- Real external texture/sync paths work on at least one supported platform
  combination.
- Unsupported combinations are documented in a matrix.
- Interop wrappers do not leak raw native handles through ordinary APIs.
