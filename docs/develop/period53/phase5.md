# Period 53 Phase 5: Evidence And Inventory Closeout

Status: complete.

The physical evidence target is a headless Metal example that imports a raw
Metal buffer, a raw Metal texture, and a single-plane IOSurface texture, copies
all three through ordinary vkmtl blit commands, verifies CPU readback, and
prints selected-device topology.

The completed command is:

```sh
zig build run-external-import
```

On the Apple M4 Pro host it completed all three deterministic readbacks and reported
`identity=metal_registry_id, peer_count=1`.

Vulkan receives compile/unit coverage for topology and deterministic typed
unsupported external imports. Physical Vulkan external-handle evidence is not
claimed because no Vulkan import subset is admitted by the current descriptor.
