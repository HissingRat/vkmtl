# Phase 5: Evidence And Closeout

Status: planned.

## Required Evidence

- Unit tests for capability gates, backend query-kind mapping, not-ready/reset,
  specialization value translation, and pipeline fingerprints.
- API guard and semantic inventory drift checks.
- Default and forced-Vulkan compilation.
- A physical query smoke on at least one backend that renders known
  visible/occluded draws and verifies visible/nonzero, empty/zero,
  readback/resolve agreement, reset/reuse, and monotonic native timestamps when
  that device exposes the complete timestamp lane. The other backend must pass
  focused deterministic tests, inspection, and forced-backend compilation;
  adding its physical rerun remains follow-up evidence, not a closure gate.
- A Metal specialization smoke in which two numeric-ID values produce
  observably different GPU output when the physical lane is available.

Physical GPU evidence on a backend is required before upgrading that executed
path beyond the code and deterministic-test evidence class. Evidence must
record the exact commit; an unsupported timestamp device is valid gate evidence
but does not prove the native timestamp execution lane. Period 46 does not
claim that both backend mappings have physical evidence when only one ran.

Run and artifact instructions are in `physical-gpu-smoke.md`.
