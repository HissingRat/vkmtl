# Phase 4: Queue Ownership And Hazards

Phase 4 defines ownership transitions across queues.

## Scope

- Lower Vulkan queue family ownership transfers.
- Map Metal ownership transfer descriptors to validation/no-op behavior.
- Integrate ownership metadata with resource usage tracking.
- Keep illegal cross-queue access errors typed.

## Validation

- Add tests for transfer-before-use and missing-transfer cases.
- Document backend differences clearly.
