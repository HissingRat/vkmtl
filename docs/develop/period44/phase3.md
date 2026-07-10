# Phase 3: Screenshot And Pixel Regression Harness

Status: complete. The Metal and Windows/NVIDIA Vulkan runs passed all three
automated cases. The configured Linux self-hosted Vulkan lane remains
unexecuted.

## Automated Pixel Cases

`zig build run-pixel-regression` runs three GPU-backed readback cases:

- transfer buffer and 2D texture copy: exact bytes, per-channel tolerance 0;
- compute storage buffer and storage texture output: exact values/pixels,
  per-channel tolerance 0;
- offscreen render triangle: clear sample tolerance 2 and interpolated center
  sample tolerance 12.

The render case copies the offscreen `rgba8_unorm` target into a CPU-visible
buffer, checks a known clear pixel and the triangle center, prints the maximum
observed channel delta, and exits after one frame. This avoids screenshot color
management and drawable timing differences while still proving the native
render pipeline produced pixels.

## Manual Visual Cases

Drawable-only examples such as the rotating cube and native ray-traced scene
remain manual-visual evidence. Their artifact bundle must include backend and
adapter identity, capability dump, screenshot, command, and the example's
success marker. Manual screenshots do not replace automated offscreen/readback
coverage.

Tolerance changes require a documented backend reason and must never be widened
only to make a failing device pass.

Observed Metal result: `render pixel regression ok backend=metal
max_channel_delta=0`.

Observed Vulkan result at commit `e2a7362f` on Windows 10 build 19045 x86_64,
an NVIDIA GeForce RTX 5080, NVIDIA driver 610.62, and Vulkan API 1.4.341:
transfer and compute readbacks were exact, and
`render pixel regression ok backend=vulkan max_channel_delta=1`. The existing
render tolerances were not widened for this result.
