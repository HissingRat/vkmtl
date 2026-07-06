# Phase 0: Shader And Binding Contract

Period 4 expands Slang, reflection, and bind-group APIs without making backend
descriptor models leak into public vkmtl code.

## Decisions

- Slang remains the only public shader source language.
- Reflection data is normalized into a vkmtl schema before pipeline validation
  consumes it.
- Binding groups remain the portable resource-binding unit.
- Dynamic offsets, small constants, push constants, and specialization are
  capability-gated shapes until backend lowering is implemented.
- Pipeline/object caching requirements can be described here; shared caches are
  implemented in Period 8.

## First-Slice Scope

- Public helpers for binding locations and layout introspection.
- Shader library/module-manager descriptor shapes.
- Versioned reflection schema metadata.
- Bind group layout entries for arrays and dynamic buffer bindings.
- Dynamic offset and small-constant validation shapes.
- Push/root constant and specialization descriptor shapes.
