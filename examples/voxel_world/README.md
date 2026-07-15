# Voxel World Pressure Test

`voxel_world` is a bounded Minecraft-like renderer pressure test for vkmtl. It
is not a game or world-generation sample. The completed Period 19 renderer
exercises deterministic chunk data, visible-face CPU meshing, cross-chunk face
culling, indexed drawing, a generated block atlas, reflection-derived vertex
and bind group layouts, camera uniforms, depth testing, back-face culling, CPU
chunk culling, and bounded streaming through the same public API on Metal and
Vulkan.

## Workload Profiles

Every profile uses `16 x 64 x 16` chunks and processes at most two rebuilds and
8 MiB of uploads per frame.

| Profile | Radius | Resident grid | Maximum resident chunks |
| --- | ---: | ---: | ---: |
| `smoke` | 1 | 3 x 3 | 9 |
| `default` | 4 | 9 x 9 | 81 |
| `stress` | 8 | 17 x 17 | 289 |

Select a profile with `VKMTL_VOXEL_PROFILE=smoke|default|stress`. The default
when the variable is absent is `default`.

## Running

Run interactively:

```sh
zig build run-voxel-world
```

Force a backend for debugging:

```sh
VKMTL_BACKEND=metal zig build run-voxel-world
zig build run-voxel-world -Dvulkan
```

`VKMTL_VOXEL_FRAME_LIMIT=N` exits after exactly `N` presented frames.
`VKMTL_VOXEL_AUTOPILOT=1` moves the camera and periodically requests a rebuild,
which makes a finite run exercise streaming without interactive input:

```sh
VKMTL_VOXEL_PROFILE=smoke \
VKMTL_VOXEL_FRAME_LIMIT=24 \
VKMTL_VOXEL_AUTOPILOT=1 \
VKMTL_BACKEND=metal \
zig build run-voxel-world
```

A successful finite run ends with:

```text
voxel_world_pressure_test=ok backend=metal profile=smoke frames=24
```

The marker confirms that the selected profile completed its bounded render
loop. It is not pixel-readback evidence.

## Controls

- `W/A/S/D`: move horizontally.
- `Q/E`: descend/ascend.
- Mouse or arrow keys: yaw and pitch.
- Shift: move faster.
- `R`: rebuild the chunk containing the camera.
- Escape or window close: exit.

## Metrics

The renderer prints live resident/visible/culled/pending/draw/rebuild/upload
counts approximately once per second. On exit, `voxel metrics:` reports:

- resident, visible, culled, and pending chunks;
- draw calls, visible vertices, and visible indices;
- rebuilt and retired chunks, uploaded bytes, and buffer allocations;
- maximum resident chunks and rebuild-queue depth;
- total CPU meshing time and per-frame command encode/commit time; and
- CPU frame-time p50, p95, and maximum.

These are pressure-test observations, not hardware-independent performance
requirements. Correctness requires bounded resident resources and pending
work; it does not impose a universal frame-rate gate.

## Observed Metal Evidence

With Metal API Validation enabled on an Apple M4 Pro, finite runs completed for
all three profiles and printed the success marker. The smoke run also enabled
autopilot to exercise movement, retirement, and rebuild:

| Profile / frames | Final resident | Visible / culled | Rebuilt / retired | Uploaded bytes | Frame p50 / p95 / max |
| --- | ---: | ---: | ---: | ---: | ---: |
| smoke / 24 | 9 | 9 / 0 | 13 / 4 | 1,164,320 | 0.494 / 5.900 / 10.287 ms |
| default / 48 | 81 | 49 / 32 | 81 / 0 | 7,233,376 | 5.209 / 5.938 / 10.681 ms |
| stress / 160 | 289 | 121 / 168 | 289 / 0 | 25,884,992 | 5.434 / 6.036 / 10.031 ms |

The same runs reported total CPU meshing times of 27.317, 169.620, and
597.104 ms; per-frame encode times of 0.158, 0.162, and 0.209 ms; and per-frame
commit times of 0.734, 0.943, and 1.068 ms for smoke, default, and stress.

The Vulkan shader artifacts and forced Vulkan build are validated, but this
repository snapshot does not claim a physical Vulkan voxel-world run. Run the
same finite commands with `VKMTL_BACKEND=vulkan` on a configured Vulkan host
to collect that evidence.
