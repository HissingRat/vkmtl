# Validation Matrix

The authoritative validation case metadata lives in
`src/development_matrix.zig`.

Current cases:

- `invalid_bind_group`: layout entry mismatch, missing/extra entries, duplicate
  entries, and resource kind mismatch.
- `invalid_texture_format`: automatic or unsupported texture formats fail
  before backend creation.
- `invalid_barrier`: redundant or mismatched explicit barriers report command
  encoding errors.
- `resource_destroyed_while_in_use`: resource tracker defers retirements until
  submitted work completes. This still needs backend integration coverage.
- `unsupported_feature`: feature-gated APIs return typed unsupported errors.
- `shader_reflection_mismatch`: reflection layout, kind, visibility, and stage
  mismatches are reported before pipeline creation.

The matrix is intentionally tied to unit-test names until backend CI can run
the same cases through native Vulkan and Metal devices.
