# Phase 1: Descriptor Indexing / Argument Buffer

Phase 1 defines advanced bindless-style resource binding as an optional,
backend-gated feature.

## First Slice

- Add descriptor indexing and argument buffer feature gates.
- Add descriptor shapes for bindless ranges and advanced layout requirements.
- Validate shape and capability requirements before backend lowering.

## Current Limits

- Vulkan descriptor indexing and Metal argument buffer lowering remain future
  backend work.
