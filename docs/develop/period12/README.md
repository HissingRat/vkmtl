# Period 12: Bindless / Argument Buffer Backend

Status: planned.

Goal: lower the advanced binding descriptors from Period 10 to real Vulkan
descriptor indexing and Metal argument buffers.

This period should not replace the portable bind group model. It adds a
capability-gated advanced path for workloads that need large resource arrays or
bindless-style access.

## Phase 1: Advanced Binding Layout Lowering Contract

- Define how advanced layouts interact with existing bind groups.
- Define ownership, cache keys, and validation order.

See `phase1.md`.

## Phase 2: Vulkan Descriptor Indexing Lowering

- Create descriptor set layouts with descriptor indexing flags.
- Support partially bound and runtime descriptor arrays when available.

See `phase2.md`.

## Phase 3: Metal Argument Buffer Lowering

- Generate Metal argument-buffer layouts.
- Bind argument buffers through render and compute encoders.

See `phase3.md`.

## Phase 4: Slang Reflection Bindless Mapping

- Map Slang reflection data to advanced binding layout descriptors.
- Keep explicit descriptors available for hand-authored layouts.

See `phase4.md`.

## Phase 5: Bindless Texture Example

- Add an example that samples from a large texture array through the advanced
  binding path.

See `phase5.md`.

## Phase 6: Bindless Validation Coverage

- Validate out-of-range resource access metadata, empty slots, unsupported
  stages, and descriptor count limits.

See `phase6.md`.
