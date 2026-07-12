# v0.1.0 Release Review

Status: complete. The annotated `v0.1.0` tag and published release use commit
`96c5b08c34163a148f9811efff04a6f78936778a`.

This review records the first tagged compatibility release after the Phase 9
API migration. The release commit satisfied every gate below; evidence from
older commits was not used as a substitute for exact-commit validation.

## Compatibility Decision

- `v0.1.x` preserves the documented portable Zig source API. Intentional
  breaking source changes require `v0.2.0` or later and an updated migration
  guide.
- The compatibility promise covers canonical declarations, documented owner
  methods, descriptor defaults, typed errors, ownership rules, and capability
  meanings that are presented as supported.
- vkmtl does not promise a stable binary ABI, the size or layout of opaque
  `_state` storage, raw native-handle values, or stability of backend-native
  escape hatches across `0.x` minor releases.
- A capability-gated path is supported only when the selected device reports
  it as available. Planning-only and typed-unsupported paths remain explicitly
  outside executable feature claims.
- `v0.1.x` is tested with Zig `0.16.0`. A later incompatible Zig toolchain may
  require a new vkmtl release.

## Package And Shader Decision

- The package exports one supported module named `vkmtl`. Example support code
  is repository-private and is not a package module.
- Consumers may pass a source-backed `shader_manifest` lazy-path dependency
  option. Generated manifests are not part of the schema-v1 contract because
  the build must enumerate shader inputs while constructing the dependency
  graph. The manifest declares render, compute, and ray-tracing shader names,
  source paths, and entry points. Source paths are relative to the manifest and
  must remain inside the LazyPath owner's logical root.
- The build-time precompiler tracks the manifest and every declared source as
  build inputs, consumes Slang depfiles so include/import dependencies also
  invalidate the cache, emits SPIR-V, MSL, and reflection blobs, and embeds
  them in the consumer's `vkmtl` module.
- Runtime code never starts `slangc` and never writes a shader cache. Unknown
  build hosts still pass the dependency's `slangc` option explicitly.
- The repository keeps a built-in manifest for its own examples. An external
  package smoke must use a consumer-owned manifest and shader so a successful
  import cannot hide a broken registration path.

## Release Gates

- [x] Set package version `0.1.0` and include release records in the package.
- [x] Publish the release policy and changelog.
- [x] Keep the exact API guard baseline at root 68, `Device` 34,
  `WindowContext` 10, and 35 opaque runtime handles.
- [x] Pass an external local-path package smoke with a consumer-owned shader.
- [x] Pass formatting, API guard, all tests, default build, Vulkan build, and
  package metadata fetch from a clean worktree.
- [x] Pass hosted macOS, Linux, and Windows CI on the exact release commit.
- [x] Record physical Metal and Vulkan evidence against the release commit.
- [x] Create an annotated `v0.1.0` tag only after the preceding gates pass.
- [x] Fetch the tag archive from a fresh external project and repeat the
  package smoke before publishing the GitHub release.

## Release Result

- Release commit: `96c5b08c34163a148f9811efff04a6f78936778a`.
- Annotated tag: `v0.1.0`.
- Readiness evaluator: 9/9 observed, `release ready: true`.
- Physical Metal and Vulkan smoke/pixel/soak evidence was recorded against the
  release line, including the Vulkan/NVIDIA evidence bundle imported during
  the release review.
- The tag archive consumer smoke passed before publication.
