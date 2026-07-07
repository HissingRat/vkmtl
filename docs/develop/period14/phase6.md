# Phase 6: External Texture Example

Phase 6 proves external resource interop in a public example.

## Scope

- Add `examples/external_texture`.
- Use a generated or platform-provided texture source.
- Sample the external texture through normal vkmtl render APIs after import.
- Print a clear unsupported-feature message when the selected backend cannot
  import the texture kind.
- Current implementation validates and wraps an explicit backend handle through
  `Device.makeExternalTexture(...)`; real imported-texture sampling remains a
  later backend-lowering step.

## Validation

- The example should import only public vkmtl APIs plus explicit platform or
  windowing packages.
- Backend-specific setup should stay isolated inside the example.
- The example should compile in the normal build and produce a clear feature
  gate message on unsupported backends.
