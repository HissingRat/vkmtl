# Phase 5: Capability Dump Example

Phase 5 adds a public example that shows what the selected backend can do.

## Scope

- Add `examples/capability_dump`.
- Print backend, adapter name, device type, selected features, selected limits,
  and a small format capability table.
- Support `.auto`, `.metal`, and `.vulkan` selection.

## Validation

- The example should build without backend-private imports.
- The output should be stable enough for smoke-test logs.

## Current Status

- `examples/capability_dump` prints adapter info, capability source, usable
  features, native queried features, selected limits, and representative format
  capabilities through public vkmtl APIs.
- The example is available through `zig build run-capability-dump`.
- The example uses the same external windowing adapter boundary as the other
  public examples.
