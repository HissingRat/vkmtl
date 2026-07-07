# Phase 3: Descriptor Table Command Binding

Phase 3 makes advanced resource tables executable.

## Scope

- Lower Vulkan descriptor-indexing table binding through descriptor sets and
  descriptor update flags.
- Lower Metal argument-buffer binding through render and compute encoders.
- Add render and compute encoder entry points for advanced resource tables.
- Keep ordinary `setBindGroup(...)` behavior unchanged.
- Define visibility, stage, and pipeline-layout compatibility checks.

## Validation

- Add command-ordering tests for missing table binding, wrong layout, wrong
  encoder type, and unsupported feature gates.
- Add a bindless texture or material-table example that actually samples from
  the table when the selected backend supports it.

## Result

- Descriptor indexing and argument buffers move from layout metadata to native
  command execution.
