# Period 56 Phase 1: Contract And API Allocation

Status: complete.

## Request And Selection Contract

`PresentationDescriptor.format` is a request. It is never rewritten with a
backend choice.

Resolution is bounded and deterministic:

| Request | Selected result |
| --- | --- |
| `.automatic` | `.bgra8_unorm_srgb` when available; otherwise `.bgra8_unorm`; otherwise a typed unsupported error |
| `.bgra8_unorm_srgb` | Exactly `.bgra8_unorm_srgb`, or a typed unsupported error |
| `.bgra8_unorm` | Exactly `.bgra8_unorm`, or a typed unsupported error |
| Any other format | A typed unsupported error before native swapchain creation |

Native enumeration order must not affect `.automatic`. Both admitted formats
use the backend's standard SDR presentation color space. A surface that cannot
provide either admitted SDR mapping is unsupported for this contract.

## Public API Allocation

The existing `presentation.PresentationDescriptor` remains canonical, with its
existing root alias and unchanged fields and defaults.

`Swapchain.presentationDescriptor()` keeps its signature and returns the
current requested descriptor. Resize may update its requested extent, but its
`format` remains the application request, including `.automatic`.

Its `extent` also remains the requested extent. The existing
`Swapchain.extent()` query is the selected counterpart: it returns the actual
native presentation extent after surface constraints. Vulkan may clamp a
request; callers must use `extent()` for drawable-sized resources and the
descriptor only when they need to inspect the request.

The one new query is:

```zig
pub fn selectedFormat(self: Swapchain) TextureFormat
```

`Swapchain.selectedFormat()` is the canonical presentation-owned query. It
returns a concrete admitted format after successful initialization and never
returns `.automatic`. No root alias, facade free function, `Device` method,
`WindowContext` forward, or `HeadlessContext` declaration is added.

The implementation must expose typed `UnsupportedPresentationFormat` and
`PresentationFormatMismatch` outcomes. The former belongs to portable
surface/presentation initialization; the latter belongs to runtime command and
attachment validation. Backend-native creation failures remain distinct from
portable unsupported or mismatch validation.

## Color Boundary

This period supports only SDR `bgra8_unorm_srgb` and `bgra8_unorm`. The format
resolver does not inspect scene content and vkmtl does not apply HDR mapping,
exposure, tone mapping, gamma correction, gamut conversion, or any other hidden
color transform. The selected format controls native attachment interpretation;
applications remain responsible for the bytes or linear values they render.

## Compatibility Decision

The additive `Swapchain` query and any added typed error tags target `v0.2.0`.
No existing method or descriptor signature changes. Explicit no-fallback
enforcement is also a `v0.2.0` semantic change because an unavailable explicit
request that was previously ignored or substituted will fail before native
work. `dispatchRaysToDrawable(...)` remains callable; Phase 4 narrows its
implementation to its documented compatibility behavior without deleting or
renaming it.
