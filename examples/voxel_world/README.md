# Voxel World Pressure Test

`voxel_world` is a Minecraft-like renderer pressure test for vkmtl. It is not a
game or world-generation sample. The final example will exercise chunk mesh
uploads, indexed drawing, a texture atlas, camera uniforms, depth, culling, and
bounded chunk streaming through the same public API on Metal and Vulkan.

Period 19 Phase 1 currently provides the window/presentation scaffold. It
shows a sky-colored drawable and prints the selected backend plus the default
`16 x 64 x 16` chunk and `9 x 9` resident-grid contract. Chunk geometry begins
in Phase 2.

Run interactively:

```sh
zig build run-voxel-world
```

Force a backend for debugging:

```sh
VKMTL_BACKEND=metal zig build run-voxel-world
zig build run-voxel-world -Dvulkan
```

Run an automated finite-frame scaffold smoke:

```sh
VKMTL_VOXEL_FRAME_LIMIT=2 zig build run-voxel-world
```

The completed camera contract will use `W/A/S/D`, `Q/E`, mouse or arrow-key
look, Shift for faster motion, `R` for a nearby chunk rebuild, and Escape to
exit. Those controls arrive with Period 19 Phase 4; they are not implemented by
the Phase 1 scaffold.
