# Backend Test Matrix

The authoritative matrix metadata lives in `src/development_matrix.zig`.

## Required Rows

- `macos_metal_default`: `zig build test && zig build`
- `linux_vulkan`: `zig build test && zig build -Dvulkan`
- `windows_vulkan`: `zig build test && zig build -Dvulkan`
- `headless_deterministic`: `zig build run-transfer-readback && zig build run-compute-readback`

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
