# Period 53 Phase 2: Executable Metal Resource Imports

Status: complete.

The executable Metal subset is deliberately finite:

- `metal_buffer` imports an `id<MTLBuffer>` created by the selected device;
- `metal_texture` imports a single-mip, single-sample 2D/2D-array
  `id<MTLTexture>` created by the selected device;
- `iosurface` creates a single-plane 2D Metal texture from an `IOSurfaceRef`.

Native device identity, resource length/shape, pixel format, requested usage,
storage mode, and IOSurface plane bounds are validated before the public owner
reports an imported resource. Imported buffers/textures enter the same ordinary
copy, binding, view, and readback paths as vkmtl-created resources.

Raw handle values are native escape-hatch input: the caller must supply a live
Objective-C object of the declared protocol. vkmtl validates its properties but
cannot safely probe an arbitrary invalid pointer value. Planning examples use
synthetic values only for pure planning and never pass them to an executable
factory.

Vulkan FD/Win32 imports remain closed because the current descriptors do not
carry the exact memory type, allocation, tiling, dedicated-allocation, handle
consumption, and semaphore payload metadata required by the enabled extension
set. A native feature query is not treated as executable import support.
