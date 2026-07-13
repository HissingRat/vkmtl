# Documentation

vkmtl documentation is organized by audience and purpose.

## Usage

- `usage/zh_cn/quick-start.md`: 中文快速开始
- `usage/zh_cn/configuration.md`: 中文配置项
- `usage/zh_cn/examples.md`: 中文示例目录
- `usage/zh_cn/performance.md`: 中文性能指南
- `usage/zh_cn/diagnostics.md`: 中文 diagnostics 与 issue-report 指南
- `usage/zh_cn/validation.md`: 中文 Vulkan/Metal native API validation 设置
- `usage/zh_cn/compatibility.md`: 中文兼容性说明
- `usage/en_us/quick-start.md`: English quick start
- `usage/en_us/configuration.md`: English configuration
- `usage/en_us/examples.md`: English examples
- `usage/en_us/performance.md`: English performance guide
- `usage/en_us/diagnostics.md`: English diagnostics and issue-report guide
- `usage/en_us/validation.md`: English Vulkan/Metal native API validation setup
- `usage/en_us/compatibility.md`: English compatibility notes

## API

- `api/zh_cn/core.md`: 中文核心 API
- `api/zh_cn/shaders.md`: 中文 shader 规则
- `api/zh_cn/resource-lifetime.md`: 中文资源生命周期
- `api/zh_cn/features-and-limits.md`: 中文 features、limits 与 format
  capability reference
- `api/en_us/core.md`: English core API
- `api/en_us/shaders.md`: English shader authoring
- `api/en_us/resource-lifetime.md`: English resource lifetime
- `api/en_us/features-and-limits.md`: English features, limits, and format
  capability reference

## Development

- `develop/release-policy.md`: release versioning, compatibility, package,
  toolchain, capability, and release-gate contract
- `develop/release-review-v0.1.0.md`: completed record for the first tagged
  compatibility release
- `develop/public-api-rules.md`: authoritative public API evolution,
  namespacing, compatibility, and removal rules
- `develop/public-api-inventory.md`: current root export, owner method,
  namespace, and compatibility inventory
- `develop/native-semantic-coverage-inventory.md`: Metal/Vulkan semantic
  lowering status, unsupported behavior, and execution evidence
- `develop/api-migration-roadmap.md`: completed staged plan for canonical
  facades, caller migration, owner convergence, and pre-tag cleanup
- `develop/api-migration-map.md`: implemented final root, namespace,
  native-name, and runtime-owner allocation
- `develop/api-migration-guide.md`: caller migration from the prototype API to
  the completed pre-tag surface
- `develop/roadmap.md`: route, stages, and what comes next
- `develop/checklist.md`: checkable tasks and phase gates
- `develop/period1/`: core library slice, phases 0 through 9
- `develop/period2/`: runtime architecture and specs
- `develop/period3/`: resource coverage
- `develop/period4/`: shader and binding
- `develop/period5/`: render pipeline
- `develop/period6/`: command, sync, and transfer
- `develop/period7/`: compute
- `develop/period8/`: pipeline and object cache
- `develop/period9/`: examples, test matrix, and documentation
- `develop/period10/`: advanced backend-gated features
- `develop/period11/`: backend capability reality
- `develop/period12/`: bindless and argument buffer backend lowering
- `develop/period13/`: multi-surface and presentation backend work
- `develop/period14/`: native interop and external resources
- `develop/period15/`: sparse and tiled resource backend lowering
- `develop/period16/`: tessellation and mesh pipeline backend lowering
- `develop/period17/`: ray tracing backend lowering
- `develop/period18/`: production hardening and performance
- `develop/period19/`: voxel world pressure-test example
- `develop/period43/`: profiling, capture, and debug-marker diagnostics
- `develop/period44/`: CI/device evidence, pixel regression, GPU soak, and
  current parity report
- `develop/period45/`: native semantic source audit, backend mappings, and gap
  priority
- `develop/period46/`: native queries, GPU counters, and Metal specialization
- `develop/period47/`: common resource, format, render, compute, and reflection
  breadth
- `develop/period48/`: native synchronization, physical queues, command
  lifecycle, and presentation timing
- `develop/period49/`: native heaps, memory telemetry, hardware memoryless
  attachments, and sparse/residency support boundaries
- `develop/backend-test-matrix.md`: backend/host validation matrix
- `develop/validation-matrix.md`: validation coverage inventory

## Releases

- `../CHANGELOG.md`: user-facing release history and migration-impact summary
- `develop/api-migration-guide.md`: prototype-to-`v0.1.0` source migration
- `usage/en_us/compatibility.md`: English package and compatibility contract
- `usage/zh_cn/compatibility.md`: 中文 package 与兼容性契约

The usage and API documents are the current user-facing source of truth. The
period notes preserve development context and may describe temporary states from
when a phase was implemented.
