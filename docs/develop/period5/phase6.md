# Phase 6: Vertex Layout Completeness

Phase 6 expands vertex layout validation and names the instance-rate boundary.

## First Slice

- Validate multiple vertex buffers.
- Validate multiple attributes and duplicate locations.
- Add explicit buffer indices to vertex buffer layout descriptors.
- Add instance step-rate metadata.
- Keep index buffer formats in command descriptors.

## Current Limits

- Existing backends lower multiple buffers and attributes.
- Non-default instance step rates are validation/API shape first until backend
  lowering is completed.
- `VertexBufferLayoutDescriptor.buffer_index` is optional; when omitted, vkmtl
  preserves the existing array-index behavior.
- Duplicate resolved buffer indices and duplicate attribute locations are
  rejected during descriptor validation.
