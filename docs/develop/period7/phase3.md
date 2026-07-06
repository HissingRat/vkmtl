# Phase 3: Storage Resource Rules

Phase 3 makes storage resource access intent explicit.

## First Slice

- Add read, write, and read-write storage access metadata.
- Validate that storage access metadata only applies to storage resources.
- Validate storage texture usage against read/write access intent.
- Record storage resource hazards when compute bind groups are bound.

## Current Limits

- `BindGroupLayoutEntry.storage_access` is optional and only valid for
  `storage_buffer` and `storage_texture` entries.
- Storage buffers default to read-write access; storage textures default to
  write access for compatibility with the existing compute readback example.
- Runtime bind group materialization validates storage buffer/texture usage and
  records portable storage read/write usage transitions.
- Storage buffer read/write distinction is currently metadata and hazard
  tracking; native buffer access qualifiers come from shader code.
- Storage textures remain compute-only in the portable layout model.
