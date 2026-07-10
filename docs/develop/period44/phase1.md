# Phase 1: CI Job Matrix And Feature Reporting

Status: complete for the CI contract, workflow configuration, and observed
hosted run artifacts on macOS, Linux, and Windows.

## Evidence Classes

Period 44 separates evidence by what the host can actually prove:

- `hosted_build`: format, unit tests, compilation, shader precompile, and
  deterministic planning tools on a fresh hosted runner. It is not GPU proof.
- `self_hosted_gpu`: commands executed on an identified physical GPU host with
  a working window system and native driver/runtime.
- `local_gpu`: equivalent opt-in developer-host evidence, useful before a
  self-hosted runner is registered.
- `manual_visual`: a screenshot plus success marker for examples whose drawable
  cannot yet be read back through the portable API.

Every job records host OS, target OS, architecture, backend, device class,
execution class, expected outcome, command, and whether capability-dump output
is mandatory. Unsupported and planning-only outcomes are successful only when
the expected typed gate is observed.

## CI Contract

- Hosted CI uses pinned OS labels and Zig 0.16.0, runs formatting, tests,
  builds, and the validation-plan tool, and uploads logs even on failure.
- Hosted CI never claims Metal/Vulkan GPU execution merely because backend code
  compiled.
- GPU jobs are manual/self-hosted and run `run-capability-dump` before smoke,
  pixel, or soak commands. The capability log remains an artifact if a later
  command fails.
- CI workflows do not silently accept missing GPU runners. Their evidence is
  `configured` until an uploaded artifact is referenced by the parity report.

The authoritative machine-readable rows live in
`tools/development_matrix.zig`; `zig build run-validation-plan` prints them.

Implemented by `.github/workflows/ci.yml`,
`.github/workflows/gpu-validation.yml`, the Period 44 matrix rows, and the
validation-plan tool. Workflow artifacts retain build/capability/pixel/soak
logs independently of job success.

The hosted matrix executed successfully for commit `e303a61` in GitHub Actions
run [29086828016](https://github.com/HissingRat/vkmtl/actions/runs/29086828016).
The three artifact IDs and platform summaries are recorded in
`parity-report.md`.
