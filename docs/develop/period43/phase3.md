# Phase 3: Metal Debug Groups And Capture Integration

Status: complete.

## Native Debug Integration

Metal resource, pipeline, command-buffer, and encoder labels/groups lower to
the matching Metal debug APIs. The public borrowed-label and call-only marker
lifetime rules from Phase 1 remain unchanged.

## Capture Scope Contract

Metal capture is opt-in through
`vkmtl.diagnostics.beginCaptureScope(&device, descriptor)`.

- `CaptureScopeDescriptor.label` is a borrowed valid UTF-8 label without an
  embedded NUL byte.
- The initial destination is `developer_tools`; file capture is not advertised.
- Only one capture may be active on the backend owner. Re-entry returns
  `CaptureAlreadyActive`.
- `CaptureScope.end()` explicitly stops capture. `deinit()` is a best-effort
  cleanup path, and `WindowContext.deinit()` also stops a still-active Metal
  capture before destroying the native device.
- Vulkan returns `UnsupportedCapture` before backend work.
- Tool startup or capture-manager failures return `CaptureFailed`; ending an
  inactive scope returns `CaptureNotActive`.

`CaptureCapabilities` reports native/scoped/destination support explicitly.
The public scope keeps the backend owner borrowed, so it must end before its
`WindowContext` is destroyed.

Capture declarations and functions live only in `vkmtl.diagnostics`; no flat
root aliases or compatibility forwards were added.
