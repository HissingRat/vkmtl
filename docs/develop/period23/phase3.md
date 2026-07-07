# Phase 3: Broader Texture Copy Coverage

Phase 3 expands texture copy coverage.

## Scope

- Support array-layer copies.
- Support mip-level copies.
- Support more compatible color formats.
- Keep MSAA and depth/stencil copies capability-gated until semantics are clear.

## Validation

- Add descriptor tests for layers, mips, and format mismatch behavior.
- Add readback-backed tests where possible.
