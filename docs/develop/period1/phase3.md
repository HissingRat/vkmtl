# Phase 3 Decisions

These decisions start the resource phase while keeping the public API
Metal-inspired.

## Resource API Style

Resource creation should use Metal-like naming and descriptors:

- `makeBuffer`
- `BufferDescriptor`
- `BufferUsage`
- `ResourceStorageMode`
- `TextureDescriptor`
- `Texture`
- `SamplerDescriptor`
- `SamplerState`
- `texture.replaceRegion(...)`

vkmtl can still choose backend-neutral field names where Metal and Vulkan need
different information, but ordinary user code should feel closer to Metal than
Vulkan.

## First Slices

Phase 3 is growing through narrow resource slices.

`WindowContext.makeBuffer(...)` is a temporary owner-facing entry point because
vkmtl does not yet expose a fully backed runtime `Device`. Once runtime `Device`
exists, this API should move to `Device.makeBuffer(...)` without changing
`BufferDescriptor`.

`WindowContext.makeTexture(...)` follows the same temporary pattern. Once
runtime `Device` exists, texture creation should move to `Device.makeTexture(...)`
without changing `TextureDescriptor`.

`texture.makeTextureView(...)` is the public entry point for texture views.
`WindowContext.makeSamplerState(...)` is temporary for the same reason as
buffers and textures: once runtime `Device` exists, sampler state creation
should move to `Device.makeSamplerState(...)` without changing
`SamplerDescriptor`.

`texture.replaceAll2D(...)` is the first example-friendly upload helper. It
uses `TextureUpload2DDescriptor`, infers the full 2D mip extent from the
texture, and forwards to `texture.replaceRegion(...)`.

## Buffer Storage

`ResourceStorageMode` starts with:

- `.automatic`
- `.shared`
- `.managed`
- `.private`

For the first buffer slice, initial bytes require CPU-visible storage. Hidden
staging for private buffers is deferred to upload helpers. Texture upload now
uses `texture.replaceRegion(...)`.

CPU-visible buffers also support `buffer.replaceBytes(...)` for small dynamic
updates such as per-frame uniform data. Private buffer updates still need a
future staging/upload helper.

## Backend Mapping

Metal:

- `Buffer` maps to `MTLBuffer`.
- `Texture` maps to `MTLTexture`.
- `TextureView` maps to an `MTLTexture` view.
- `SamplerState` maps to `MTLSamplerState`.
- Buffer `.automatic` maps to shared storage in this first slice.
- Buffer `.shared`, `.managed`, and `.private` map to Metal storage modes where
  supported by the platform.
- Texture `.automatic` storage currently maps to shared storage so
  `texture.replaceRegion(...)` can use Metal's direct replacement API.
- Explicit Metal `.private` texture uploads are deferred until a Metal staging
  blit path exists.

Vulkan:

- `Buffer` maps to `VkBuffer + VkDeviceMemory`.
- `Texture` maps to `VkImage + VkDeviceMemory`.
- `TextureView` maps to `VkImageView`.
- `SamplerState` maps to `VkSampler`.
- Buffer usage flags map to `VkBufferUsageFlags`.
- Buffer CPU-visible modes use host-visible, host-coherent memory.
- Buffer `.private` maps to device-local memory when no initial bytes are
  provided.
- Texture usage flags map to `VkImageUsageFlags`.
- Textures are created as optimal, device-local images. `replaceRegion(...)`
  creates a CPU-visible staging buffer, transitions the image to transfer
  destination, copies pixels, transitions it to shader-read layout, and waits
  for the graphics queue to finish.

## Lifetime

Buffers, textures, texture views, and sampler states are explicit resources.
Users must call `deinit()` on resources before destroying the owning
context/device.

The temporary `WindowContext` owner now has debug lifetime tracking for runtime
resources created through it. In Debug builds, `WindowContext.deinit()` panics if
any tracked buffers, textures, texture views, or sampler states are still live.
Resource wrappers also guard against direct use after their own `deinit()`.
Stricter parent-child ordering diagnostics can grow with the future runtime
`Device` owner.

## Current Phase 3 Slice

Completed so far:

- public `BufferDescriptor`, `BufferUsage`, and `ResourceStorageMode`
- temporary `WindowContext.makeBuffer(...)`
- runtime `Buffer`
- Metal `MTLBuffer` creation/destruction through the bridge
- Vulkan `VkBuffer + VkDeviceMemory` creation/destruction
- public `TextureDescriptor`, `TextureDimension`, and `TextureUsage`
- temporary `WindowContext.makeTexture(...)`
- runtime `Texture`
- Metal `MTLTexture` creation/destruction through the bridge
- Vulkan `VkImage + VkDeviceMemory` creation/destruction
- public `TextureViewDescriptor`, `TextureViewDimension`,
  `SamplerDescriptor`, and sampler enums
- `texture.makeTextureView(...)`
- temporary `WindowContext.makeSamplerState(...)`
- runtime `TextureView` and `SamplerState`
- Metal texture view and `MTLSamplerState` creation/destruction through the
  bridge
- Vulkan `VkImageView` and `VkSampler` creation/destruction
- public `Region3D` / `TextureRegion` and `TextureReplaceRegionDescriptor`
- `texture.replaceRegion(...)`
- Metal direct texture region replacement through the bridge
- Vulkan staging buffer upload with layout transitions
- public `TextureUpload2DDescriptor`
- `texture.replaceAll2D(...)` as a small example helper over
  `replaceRegion(...)`
- public `BufferWriteDescriptor`
- `buffer.replaceBytes(...)` for CPU-visible buffer updates
- debug lifetime tracking for leaked runtime buffers, textures, texture views,
  and sampler states

The clear-screen example uses the texture upload path as an offscreen resource
smoke test only. It does not present the uploaded texture because vkmtl does not
yet expose a public blit, render pipeline, or textured draw command path.

More upload helper ergonomics, shader binding, batched/asynchronous uploads,
and stricter parent-child lifetime diagnostics are still open.
