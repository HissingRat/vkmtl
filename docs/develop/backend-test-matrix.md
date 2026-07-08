# Backend Test Matrix

The authoritative matrix metadata lives in `src/development_matrix.zig`.

## Required Rows

- `macos_metal_default`: `zig build test && zig build && zig build run-capability-dump`
- `linux_vulkan`: `zig build test && zig build -Dvulkan && zig build run-capability-dump -Dvulkan`
- `windows_vulkan`: `zig build test && zig build -Dvulkan && zig build run-capability-dump -Dvulkan`
- `headless_deterministic`: `zig build run-transfer-readback && zig build run-compute-readback`
- `presentation_feature_gates`: `zig build run-bindless-textures && zig build run-multi-window && zig build run-external-texture && zig build run-streaming-texture`
- `binding_variant_regression`: covered by `zig build test`; includes dynamic buffer array offsets, resource tables, root constant writes, and specialization variant fingerprints.
- `sync_query_regression`: covered by `zig build test`; includes explicit barriers, fences/events, logical queues, ownership transfer validation, and query readback/resolve validation.
- `advanced_geometry_feature_gates`: `zig build run-tessellation && zig build run-mesh-shader`
- `ray_tracing_feature_gates`: `zig build run-ray-traced-triangle`

## Optional Rows

- `macos_moltenvk_forced`:

```sh
zig build -Dvulkan \
  -Dvulkan-loader-dir=/path/to/vulkan/lib \
  -Dvulkan-icd=/path/to/MoltenVK_icd.json
```

- `ios_metal_optional`:

```sh
zig build -Dtarget=aarch64-ios
```

The iOS row is planning metadata until platform surface packaging is designed.
The MoltenVK row is explicit because macOS Vulkan is for backend testing, not a
default release target.

## Capability Expectations

`run-capability-dump` is the smoke target for device capability reporting. The
output should include:

- selected backend and adapter identity
- capability source
- usable vkmtl features
- native queried backend features
- selected limits
- representative format capabilities

Advanced native features may appear in the native queried section before vkmtl
exposes usable lowering for them. The usable feature section must stay
conservative until the relevant backend period lands.

## Period 23 Sync And Query Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Explicit buffer/texture barriers | Native barrier commands | Validation/no-op markers | Advanced escape hatch, feature-gated |
| Binary fences | Portable runtime object | Portable runtime object | Available by default |
| Timeline fences | Capability-gated | Capability-gated | Deferred native submit integration |
| Events | Portable runtime object | Portable runtime object | Available by default |
| Shared events | Capability-gated | Capability-gated | Deferred native/shared-handle integration |
| Logical compute/transfer queues | Portable fallback until native queue families are exposed | Portable fallback until dedicated queue use is exposed | Queue descriptors are public |
| Queue ownership transfers | Deferred native queue-family lowering | Validation/no-op markers | Advanced escape hatch, feature-gated |
| Timestamp queries | Portable runtime query set | Portable runtime query set | Available by default |
| Occlusion queries | Portable runtime query set | Portable runtime query set | Available by default |
| Pipeline statistics queries | Capability-gated | Capability-gated | Deferred native query lowering |
