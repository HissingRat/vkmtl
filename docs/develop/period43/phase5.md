# Phase 5: Diagnostics For Issue Reports

Status: complete.

## Issue Snapshot

`vkmtl.diagnostics.issueReport(device, descriptor)` produces a borrowed
`IssueReportSnapshot` containing:

- selected backend, adapter name, and capability source;
- operation, object kind, optional object label, exact failure name, and broad
  error category;
- usable features, native queried features, and device limits;
- debug-marker, capture, and profiling capability reports;
- live resource, pending retirement, work serial, and object-cache diagnostics.

Descriptor strings follow the same non-empty UTF-8/no-NUL rule used for marker
labels. The snapshot borrows descriptor and device strings and must not outlive
their owners.

## Tools And Documentation

`run-capability-dump` now prints diagnostics capabilities, the selected
profiling plan, and a representative typed failing operation in addition to
adapter, feature, limit, ray-tracing, and format data.

The recommended issue-report bundle is documented in:

- `docs/usage/en_us/diagnostics.md`
- `docs/usage/zh_cn/diagnostics.md`

The bundle keeps exact error names and capability evidence together so an
unsupported feature is distinguishable from validation, backend, device-loss,
and surface-loss failures.
