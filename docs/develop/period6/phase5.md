# Phase 5: Multi-Queue

Phase 5 defines queue capability terminology before exposing additional native
queues.

## First Slice

- Add queue kind and queue capability descriptors.
- Preserve the current single graphics queue as the default.
- Gate dedicated compute/transfer queues behind feature flags.
- Define cross-queue ownership transfer as explicit advanced behavior.

## Current Limits

- `Device.queue()` returns the default graphics queue.
- `QueueKind`, `QueueCapabilities`, `QueueDescriptor`, and
  `QueueOwnershipTransferDescriptor` define the public multi-queue vocabulary.
- `Device.queueWithDescriptor(...)` currently accepts the default graphics queue
  path and returns `UnsupportedMultiQueue` for non-graphics runtime queues.
- Dedicated compute and transfer queues are descriptor/feature shapes until
  backend selection and synchronization are implemented.
