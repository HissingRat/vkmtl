# Phase 1: Debug Label And Marker Contract

Status: complete.

## Object Label Lifetime

- Object, command-buffer, and command-encoder labels are optional borrowed UTF-8
  slices. The portable wrapper does not allocate or copy label bytes.
- The caller must keep the backing bytes alive and unchanged until the object
  is destroyed or `setLabel(...)` replaces or clears the label.
- Descriptor lifetime is not label lifetime. A temporary descriptor is fine,
  but the memory referenced by its `label` field must follow the borrowed-label
  rule after object creation.
- `setLabel(null)` clears both the portable wrapper label and the native label
  where native naming is available. Replacing a label ends the previous borrow.
- `null` is the canonical unset value. Empty object labels remain accepted for
  compatibility but are discouraged; marker and capture-name components are
  required to be non-empty.
- Labels are diagnostics only. They do not affect object identity, cache keys,
  synchronization, or command ordering.
- Public object setters remain infallible for compatibility. Callers must pass
  valid UTF-8 without embedded NUL bytes. Invalid labels remain visible only as
  borrowed wrapper data and are not forwarded to native naming APIs.

This keeps the disabled path cheap: `null` labels require no label allocation,
borrowed labels require no portable copy, and native work only runs on backends
that expose the corresponding naming path.

## Marker Label Lifetime

- Debug-group and signpost labels are borrowed only for the duration of the
  `pushDebugGroup(...)` or `insertDebugSignpost(...)` call. vkmtl stores stack
  depth, not marker strings.
- Marker labels must be non-empty valid UTF-8 without embedded NUL bytes.
  Invalid labels return `EmptyDebugGroupLabel` or
  `InvalidDebugLabelEncoding` before native commands are called.
- The portable debug-group stack has a maximum depth of 64 unless a validation
  test explicitly constructs a smaller stack.

## Marker Scopes

- A command-buffer debug group may surround one or more complete command
  encoders. Its push and pop operations occur only while the command buffer is
  in the ready state.
- Command-buffer groups cannot be pushed or popped while a render, blit, or
  compute encoder is active. Command-buffer signposts are likewise ready-state
  markers and cannot be inserted inside an encoder.
- Encoder debug groups are local to that encoder. They cannot cross into a
  different encoder or command buffer and must be closed before
  `endEncoding()`.
- Every command-buffer group must be closed before `commit()`. Validation runs
  before native end/commit calls so a failed close check leaves the object
  available for the caller to repair.
- Stack underflow, overflow, invalid encoding, invalid command-buffer state,
  and unclosed groups use typed `CommandEncodingError` values.

## Naming Rules

- Prefer stable role names such as `scene:opaque-pass`, `upload:staging`, or
  `frame:main-pass`; do not use native handles or pointer addresses as names.
- Use `CaptureNameDescriptor` when backend or frame context is useful. Its
  canonical format is `scope:name`, followed by optional `backend=<name>` and
  `frame=<index>` fields.
- Scope and name components must be non-empty valid UTF-8 without embedded NUL
  bytes. The formatter reports its exact required byte length and writes into a
  caller-owned buffer.
- Labels need not be globally unique. They should be deterministic enough that
  repeated objects and command scopes can be compared across captures.

## Validation

- Core tests cover empty, invalid UTF-8, embedded-NUL, nesting, exact capture
  name length, underflow, overflow, and unclosed groups.
- Runtime tests cover a command-buffer group spanning a complete encoder,
  rejection of command-buffer marker mutation while that encoder is active,
  encoder-local balance, and repair after a failed commit.
- Vulkan and Metal native label bridges ignore invalid object-label encoding so
  native tools do not receive backend-divergent truncated strings.
