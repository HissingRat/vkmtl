# Release And Compatibility Policy

This policy defines what a vkmtl version promises to applications. The public
API allocation rules remain authoritative in `public-api-rules.md`, and
user-visible changes are recorded in the repository `CHANGELOG.md`.

## Versioning During 0.x

vkmtl uses semantic-looking `0.x.y` versions while the architecture is still
evolving:

- patch releases within one minor line preserve that line's documented
  portable Zig source API;
- intentional breaking portable source changes move to the next minor version;
- therefore `v0.1.x` source breaks require `v0.2.0` or later, an updated
  changelog, and migration guidance;
- fixes may make previously accepted invalid input fail earlier or more
  precisely without being treated as a compatibility break.

The compatibility review for each release must classify changes by semantics,
not only by declaration spelling. Defaults, enum tags, errors, ownership,
lifetime, feature meanings, and limit meanings are part of the source contract
when the user-facing docs present them as supported.

## v0.1.x Compatibility Promise

The `v0.1.x` line preserves:

- canonical portable declarations reachable from the `vkmtl` module;
- documented public owner methods and descriptor defaults;
- typed error categories used by supported portable operations;
- documented ownership, destruction-order, and borrowing rules;
- capability, limit, and format-capability meanings reported as supported.

The promise applies to supported portable paths. An advanced operation is
supported only when the selected device reports its required capabilities and
the documentation identifies the path as executable. Planning-only records,
typed-unsupported paths, and unimplemented native lowering are not executable
feature claims.

## Explicit Non-Guarantees

vkmtl does not promise:

- a stable binary ABI or cross-version binary compatibility;
- the size, alignment, representation, or contents of opaque `_state` storage;
- stable raw native-handle values or object identity;
- source or semantic stability for backend-native escape hatches across `0.x`
  minor releases;
- availability of a capability that the selected adapter or device does not
  report;
- compatibility with Zig versions other than the toolchain named by the
  release line.

Applications must not construct runtime handles with struct literals, inspect
or modify `_state`, persist raw native handles as vkmtl identities, or infer
support from the operating system alone.

## Toolchain Contract

`v0.1.x` is built and tested with Zig `0.16.0`, which is also the package's
minimum Zig version. A later incompatible Zig toolchain can require a new vkmtl
release even if application-level graphics semantics are unchanged.

## Package Contract

The package exports one supported module named `vkmtl`:

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
});

exe.root_module.addImport("vkmtl", vkmtl_dep.module("vkmtl"));
```

Repository examples, their common window adapter, tools, and tests are not
package module exports and are not covered by application source compatibility.

Consumers that declare shaders pass `shader_manifest` as a source-backed
`std.Build.LazyPath`. Generated manifests are not supported because vkmtl
enumerates shader inputs while constructing the dependency build graph.
Schema version 1 contains `render_shaders`, `compute_shaders`, and
`ray_tracing_shaders`; schema version 2 retains them and adds
`tessellation_shaders` and `mesh_shaders`. Source paths are resolved relative
to the manifest file.

```json
{
  "schema_version": 1,
  "render_shaders": [
    {
      "name": "triangle",
      "source": "triangle.slang",
      "vertex_entry": "vs_main",
      "fragment_entry": "fs_main"
    }
  ],
  "compute_shaders": [],
  "ray_tracing_shaders": []
}
```

A compute entry contains `name`, `source`, and `entry`. A ray-tracing entry
contains `name`, `source`, `metal_ray_generation_source`,
`ray_generation_entry`, `miss_entry`, `closest_hit_entry`, `any_hit_entry`, and
`intersection_entry`.
Tessellation entries contain `vertex_entry`, `control_entry`,
`evaluation_entry`, and `fragment_entry`. Mesh entries contain `mesh_entry`,
optional `task_entry`, and `fragment_entry`. Schema 2 is additive and schema 1
remains accepted throughout `v0.1.x`.

Declared source paths must stay inside the LazyPath owner's logical root. The
recommended `b.path(...)` form retains the consumer build root as that owner.
A scalar command-line path becomes `cwd_relative`; for that form, the directory
where `zig build` was invoked is the logical root. Absolute, drive-relative,
UNC, and backslash paths are rejected. The build tracks the manifest and every
declared source as inputs, consumes Slang depfiles for include/import
dependencies, emits SPIR-V, MSL, and reflection blobs, and embeds them in the
consumer's `vkmtl` module. Runtime shader APIs never launch `slangc` and never
write a shader cache. On a host without a known pinned Slang package, the
consumer must pass the dependency's build-time `slangc` option explicitly. The
default `shaders/manifest.json` is for this repository's own examples; an
external application should provide its own manifest whenever it declares
shaders.

## Release Gates

A release commit must:

1. update package metadata, the changelog, compatibility docs, and migration
   guidance when applicable;
2. pass the API guard and the validation appropriate to its changes;
3. pass an external-package smoke using only the exported `vkmtl` module and a
   consumer-owned shader manifest;
4. pass hosted CI on the exact release commit;
5. record required physical Metal and Vulkan evidence against that commit;
6. create an annotated tag only after the preceding gates pass;
7. verify the tag archive from a fresh external project before publishing the
   release.

Recorded evidence from a different commit is useful history but does not
satisfy a release gate for the current commit.
