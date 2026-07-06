# Phase 8 Decisions

Phase 8 starts with explicit transfer commands before compute. The goal is to
make upload, readback, and later compute validation use the same public command
model as rendering.

## First Slice: Blit Commands

The first public shape is Metal-inspired:

```zig
var command_buffer = try context.makeCommandBuffer();
var blit = try command_buffer.makeBlitCommandEncoder();
try blit.copyBufferToBuffer(&source, &destination, .{ .size = byte_count });
try blit.copyBufferToTexture(&source, &texture, .{
    .destination_region = .{ .size = .{ .width = width, .height = height } },
});
try blit.copyTextureToBuffer(&texture, &readback, .{
    .source_region = .{ .size = .{ .width = width, .height = height } },
});
try blit.endEncoding();
try command_buffer.commit();
```

This slice supports:

- buffer-to-buffer copies
- buffer-to-texture copies
- texture-to-buffer copies
- CPU-visible `buffer.readBytes(...)` for small readbacks

Current texture copy constraints:

- color formats only
- single-sample textures only
- one region per command
- explicit `copy_source` / `copy_destination` usage on resources
- row layout controlled by `BufferTextureCopyLayout`

## Backend Mapping

Vulkan records transfer commands into the existing command buffer path:

- `vkCmdCopyBuffer`
- `vkCmdCopyBufferToImage`
- `vkCmdCopyImageToBuffer`
- image layout transitions to transfer source/destination layouts

Metal records the same public calls through `MTLBlitCommandEncoder`.

## Compute Slice

The first compute shape mirrors Metal naming:

```zig
var pipeline = try context.makeComputePipelineState(.{
    .compute = .{
        .module = .{ .source = computeShaderSource(context.selectedBackend()) },
        .stage = .compute,
        .entry_point = "cs_main",
    },
    .bind_group_layouts = bind_group_layouts,
});

var command_buffer = try context.makeCommandBuffer();
var compute = try command_buffer.makeComputeCommandEncoder();
try compute.setComputePipelineState(&pipeline);
try compute.setBindGroup(&bind_group, .{ .index = 0 });
try compute.dispatchThreadgroups(.{
    .threadgroup_count_x = 1,
    .threads_per_threadgroup_x = 4,
});
try compute.endEncoding();
try command_buffer.commit();
```

This slice supports:

- compute shader modules from runtime-cached Slang SPIR-V/MSL artifacts
- `ComputePipelineDescriptor` and `ComputePipelineState`
- `ComputeCommandEncoder`
- `dispatchThreadgroups(...)`
- storage buffer bindings through `.storage_buffer`
- compute-only storage texture bindings through `.storage_texture`

Vulkan maps this to a compute pipeline, descriptor sets, `vkCmdBindPipeline`,
`vkCmdBindDescriptorSets`, and `vkCmdDispatch`. Storage textures use storage
image descriptors and are transitioned to `VK_IMAGE_LAYOUT_GENERAL` before
dispatch. Metal maps the same public calls to `MTLComputePipelineState` and
`MTLComputeCommandEncoder` resource bindings.

## Examples

`examples/transfer_readback` validates the first slice by copying a small RGBA
payload buffer to another buffer, copying it into a texture, copying the texture
back into a CPU-visible buffer, and checking the bytes. It exits automatically
after printing `transfer readback ok`.

`examples/compute_readback` validates compute by dispatching a Slang compute
shader that writes four `u32` values into a storage buffer and a 2x2 RGBA
pattern into a storage texture. It copies both resources to CPU-visible
readback buffers, checks the bytes, and exits automatically after printing
`compute readback ok`.
