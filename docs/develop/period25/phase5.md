# Phase 5: Native Command Insertion

Phase 5 exposes an explicit advanced escape hatch.

## Scope

- Add callback descriptors for native command insertion.
- Pass scoped Vulkan or Metal command handles only through explicit APIs.
- Validate command encoder state before invoking callbacks.
- Keep the ordinary portable path free of native types.

## Validation

- Add native interop sample code.
- Add tests for invalid insertion points.

## Result

- `RenderCommandEncoder.insertNativeCommands(...)`,
  `ComputeCommandEncoder.insertNativeCommands(...)`, and
  `BlitCommandEncoder.insertNativeCommands(...)` expose the explicit advanced
  escape hatch.
- `NativeCommandInsertionDescriptor.validateForEncoder(...)` checks the feature
  gate, callback presence, and encoder kind before a callback can run.
- Runtime tests cover callback invocation through a borrowed native handle view,
  feature-gated rejection, and encoder-kind mismatch.
- Ordinary portable command APIs still expose no Vulkan or Metal types.
- Real backend command-buffer / command-encoder handle views and native command
  insertion lowering remain deferred to Period 28 Phase 5.
