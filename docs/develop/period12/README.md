# Period 12: Bindless / Argument Buffer Backend

Status: completed API, validation, reflection, and layout-metadata scaffold.
Executable table updates and command binding are tracked in Period 22.

Goal: define and validate the advanced binding descriptors from Period 10, then
record backend-aware Vulkan descriptor-indexing and Metal argument-buffer
metadata.

This period should not replace the portable bind group model. It adds a
capability-gated advanced path for workloads that need large resource arrays or
bindless-style access.

Historical note: phase titles that say "lowering" in this period refer to the
first backend-aware metadata pass. Native resource table allocation, updates,
and command binding belong to Period 22.

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

- Add an example that creates a bindless-style texture table layout through the
  advanced binding path and reports unsupported capability gates clearly.

See `phase5.md`.

## Phase 6: Bindless Validation Coverage

- Validate out-of-range resource access metadata, empty slots, unsupported
  stages, and descriptor count limits.
- Lock descriptor indexing and reflection-derived layout validation with unit
  tests before native backend lowering grows more complex.

See `phase6.md`.
