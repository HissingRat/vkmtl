# Phase 4: Lifecycle And Presentation Timing

Status: complete.

## Scope

- Record scheduled/completed command milestones and invoke optional callbacks
  exactly once with truthful status.
- Keep callback context borrowed through commit completion and document thread
  and reentrancy boundaries.
- Add capability-gated immediate, scheduled-time, and minimum-duration drawable
  presentation with explicit fallback policy.
- Map Metal timed drawable presentation directly and Vulkan only through an
  enabled/queryable timing path; otherwise return typed unsupported.
- Keep presentation observation distinct from calibrated display timestamps.

## Result

Command buffers expose encoding/scheduled/completed/failed lifecycle status and
optional scheduled/completed callbacks. Metal uses native command-buffer
handlers; Vulkan composes the milestones around successful submit and the
current synchronous queue completion. Timed present maps to Metal scheduled and
minimum-duration drawable methods. Vulkan leaves both timing features closed;
caller-authorized immediate fallback is explicit.
