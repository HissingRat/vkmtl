# Period 55 Phase 4: Evidence And Documentation

Status: complete.

## Deterministic Regressions

The CPU reference implements the same clamp and standard sRGB EOTF as the
display shader. Historical display-referred inputs
`0.0`, `0.18`, `0.5`, `0.8`, and `1.0` map through the matching final sRGB
attachment OETF to reference bytes `0`, `46`, `128`, `204`, and `255`.
Focused tests also cover negative, NaN, and infinity sanitization plus stable
decode points.

The Metal GPU regression renders a five-pixel `rgba16_float` source containing
black, `0.18`, `0.5`, yellow, and blue through the same manifest-backed
display shader into an offscreen `bgra8_unorm_srgb` target, copies the stored
BGRA8 bytes to a buffer, and accepts at most one byte of channel error. This
catches an omitted EOTF, a repeated OETF, a target-format change, and
channel-order regressions without depending on a display profile or animated
screenshot.

Focused runtime tests cover the valid resource contract, queue ownership,
missing shader-read or shader-write usage, non-2D views, dispatch depth, and
oversized extents, nonzero base subresources, multi-subresource textures, and
attempts to append a second encoding segment. The command validation also
rejects multisample output, and successful encoding records the storage write
followed by sampled use. Vulkan invariants keep descriptor and inline-data
state on each dispatch rather than on the shared pipeline.

Finite-run tests require a positive frame limit, reject early completion, and
bound a persistent zero-sized framebuffer with a five-second watchdog. The
success marker is emitted only after the requested number of rendered frames.

## Physical Evidence Boundary

On supported Metal hardware, this command completed with API Validation
enabled:

```sh
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 \
  zig build run-ray-traced-scene
```

The run reached the existing visible Metal RT marker and
`ray traced scene finite run ok: backend=metal frames=3` without acquiring a
drawable inside texture dispatch.

This physical run establishes native command validity and the separated
producer/consumer architecture; the offscreen Metal readback above supplies
the byte-level transform evidence. A separate Metal A/B places the brightness
regression before Period 55: `ab1c06b` retained the darker reference result,
while `4a93d57`, which changed `CAMetalLayer.pixelFormat` from
`BGRA8Unorm` to `BGRA8Unorm_sRGB`, became bright. That A/B establishes Metal
regression provenance only and is not Vulkan execution evidence.

The Vulkan implementation and shader artifacts have unit and forced-build
coverage. Historical physical Vulkan RT output remains valid evidence for the
basic RT backend, but the Period 55 texture-presentation path has not yet been
rerun on the Vulkan RT machine. The required follow-up is:

```sh
VKMTL_BACKEND=vulkan VKMTL_RT_FRAME_LIMIT=3 \
  zig build run-ray-traced-scene -Dvulkan
```

Only a successful physical run may promote that new-path evidence.

## Documentation Closeout

The public inventory, migration guide, native inventory, source ledger,
roadmap, checklist, backend/validation matrices, changelog, and English and
Chinese API/usage documents now describe the texture command, caller-owned
accumulation values, reference display transform, compatibility boundary, and
physical-evidence limit consistently.
