# Period 50 Phase 3: Reusable Indirect Command Lists

Status: complete.

## Contract

`IndirectCommandBuffer` owns a fixed number of CPU-authored render or compute
command slots. Commands inherit pipeline and resource state from the executing
encoder. The first exact command subset is non-indexed draw and threadgroup
dispatch; reset and range execution are explicit.

The contract excludes:

- shader/GPU writes to command slots;
- backend-native command handles;
- non-inherited pipeline, vertex/index buffer, bind-group, table, or constant
  state;
- simultaneous mutation and execution.

## Lowering

- Metal allocates `MTLIndirectCommandBuffer`, writes native render/compute
  command slots, resets native ranges, and executes ranges on the appropriate
  encoder.
- Vulkan expands the immutable CPU slot range into ordinary `vkCmdDraw` or
  `vkCmdDispatch` commands in the active primary encoder. This preserves the
  complete documented observable contract without claiming Vulkan
  device-generated commands.

## Validation

- Validate kind, capacity, slot/range bounds, command shape, backend, encoder
  type, and resource lifetime.
- Add deterministic slot/reset tests and use the render path in the large-table
  GPU example.
