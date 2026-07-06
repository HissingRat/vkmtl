# Phase 8: Query Support

Phase 8 defines portable query descriptors before native query pools/counters
are introduced.

## First Slice

- Add query types for occlusion and timestamps.
- Add pipeline statistics query shape behind a feature gate.
- Add query set, resolve, and readback descriptor shapes.
- Document Metal and Vulkan support differences clearly.

## Current Limits

- Query support is descriptor/validation shape only in this period.
