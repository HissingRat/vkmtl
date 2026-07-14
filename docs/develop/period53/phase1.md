# Period 53 Phase 1: Contract And API Allocation

Status: complete design decision.

The six routed semantic units split into three groups:

1. `MTL-RES-015`: executable for raw same-device Metal buffers/textures and
   single-plane IOSurface textures with the existing size/format/usage shape.
2. `MTL-DEV-004`: executable as identity/topology diagnostics on both
   backends, but not as cross-device resource execution.
3. `MTL-XFR-006`, `MTL-XFR-007`, `MTL-INT-001`, and `MTL-INT-003`: missing
   observable state or handles required for exact execution and therefore
   closed unsupported in Phase 4.

`interop.ExternalMemory`, `ExternalBuffer`, and `ExternalTexture` remain the
resource owners. They may expose an internally imported ordinary resource, but
the flat root and common `Device` method set do not grow. Device identity and
peer membership are diagnostics, so `diagnostics.DeviceTopologyReport` and
`diagnostics.deviceTopology(device)` own that surface.

Borrowed imports retain the native object for the external owner's lifetime and
do not consume the caller's reference. Transferred imports consume one caller
reference on success. Deinitializing the external owner first destroys the
imported ordinary resource and then the wrapper record.
