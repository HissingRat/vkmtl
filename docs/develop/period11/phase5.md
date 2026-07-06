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
