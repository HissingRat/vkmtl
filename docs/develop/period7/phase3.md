# Phase 3: Storage Resource Rules

Phase 3 makes storage resource access intent explicit.

## First Slice

- Add read, write, and read-write storage access metadata.
- Validate that storage access metadata only applies to storage resources.
- Validate storage texture usage against read/write access intent.
- Record storage resource hazards when compute bind groups are bound.

## Current Limits

- Storage buffer read/write distinction is currently metadata and hazard
  tracking; native buffer access qualifiers come from shader code.
- Storage textures remain compute-only in the portable layout model.
