# Phase 2: Shader Library / Module Manager

Phase 2 adds public shader-library/module-manager shapes for applications that
compile more than one entry point from one Slang source.

## First Slice

- Add shader compile profile/options shapes.
- Add shader library descriptor and entry-point descriptors.
- Define cache-key inputs for later Period 8 cache integration.
- Keep actual runtime compilation through current `Device.compile*` entry
  points for now.
- Implemented as `ShaderCompileProfile`, `ShaderLibraryEntryDescriptor`,
  `ShaderLibraryDescriptor`, and `ShaderLibraryCacheKeyDescriptor`.

## Current Limits

- The manager shape validates inputs but does not yet own compiled native
  modules.
