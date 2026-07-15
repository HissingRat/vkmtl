# Period 55 Phase 4: Evidence And Documentation

Status: complete.

## Deterministic Regressions

The CPU reference implements the same exposure-1 ACES-fitted curve as the
display shader. Scene-linear inputs `0.0`, `0.18`, `0.5`, and `1.0` map through
one sRGB attachment transfer to reference bytes `0`, `141`, `206`, and `232`.
Focused tests also cover negative, NaN, and infinity sanitization plus stable
display-linear points.

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

The Vulkan implementation and shader artifacts have unit and forced-build
coverage. Historical physical Vulkan RT output remains valid evidence for the
basic RT backend, but the Period 55 color-managed path has not yet been rerun
on the Vulkan RT machine. The required follow-up is:

```sh
VKMTL_BACKEND=vulkan VKMTL_RT_FRAME_LIMIT=3 \
  zig build run-ray-traced-scene -Dvulkan
```

Only a successful physical run may promote that new-path evidence.

## Documentation Closeout

The public inventory, migration guide, native inventory, source ledger,
roadmap, checklist, backend/validation matrices, changelog, and English and
Chinese API/usage documents now describe the texture command, linear color
contract, compatibility boundary, and physical-evidence limit consistently.
