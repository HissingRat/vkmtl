# Period 53 Closeout

Status: complete.

## Executable Outcomes

- Metal imports same-device raw `MTLBuffer` and `MTLTexture` objects with
  explicit borrowed/transferred ownership.
- Metal creates a 2D texture from a validated single-plane `IOSurfaceRef`.
- Imported resources enter ordinary vkmtl buffer/texture copy, binding, view,
  and readback paths through external-owner accessors.
- Metal reports registry/peer properties; Vulkan reports device UUID and
  selected physical-device-group membership through backend-neutral topology
  diagnostics.

## Precise Unsupported Outcomes

- Vulkan external resource imports until the descriptors carry complete memory
  type, allocation, tiling, dedicated-allocation, and handle-consumption data.
- External semaphore/event submission until waits/signals carry payload and
  import ownership rules.
- Native command insertion until the callback receives an active native
  command-buffer/encoder handle with a validated lifetime.
- Metal I/O/compressed-stream execution until vkmtl owns async file/status,
  cancellation, priority, compression format, and scratch allocation contracts.
- Peer allocation, device masks, ownership transfer, and cross-device command
  submission; topology remains diagnostic-only.

## Evidence

- `zig build test --summary all`: 630/630 tests passed; semantic inventory
  reports 67 compact IDs, 111 Metal units, 78 protocols, and 20 Period 54 gaps.
- `zig build run-api-guard`: root 69, `Device` 34, `WindowContext` 10,
  `HeadlessContext` 6, runtime handles 37.
- `zig build --summary all` and `zig build -Dvulkan --summary all`: 58/58
  steps passed in each configuration.
- `scripts/ci/run_package_smoke.sh`: external package consumer 1/1 passed.
- `MTL_DEBUG_LAYER=1 zig build run-external-import -Doptimize=Debug`: Metal API
  Validation enabled; raw buffer, raw texture, and IOSurface readbacks passed
  and topology reported `identity=metal_registry_id, peer_count=1`.
- `clang -std=c99 -fsyntax-only src/backend/metal/bridge_stub.c`: non-Metal ABI
  stub syntax passed.

Physical Vulkan topology and external-resource execution are not claimed on
this host. Vulkan topology has compile/unit coverage; Vulkan external import is
an intentional typed-unsupported outcome, not a pending executable claim.
