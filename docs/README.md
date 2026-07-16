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

- `develop/README.md`: developer-document index, authority order, and
  maintenance rules
- `develop/architecture.md`: stable module boundaries, ownership, backend
  interface, shader pipeline, headless runtime, and presentation contract
- `develop/public-api.md`: authoritative API admission, compatibility,
  package, and release policy
- `develop/public-api-inventory.md`: current root export, owner method,
  namespace, and compatibility inventory
- `develop/migration.md`: caller migration from older namespaces, owners, and
  build integration
- `develop/native-semantic-coverage-inventory.md`: Metal/Vulkan semantic
  lowering status, unsupported behavior, and execution evidence
- `develop/validation.md`: backend/host matrix, evidence classes, required
  commands, physical results, and release decision rules
- `develop/roadmap.md`: current work only; completed task detail is removed
- `develop/history.md`: compact Period 1-56, migration, and release ledger;
  full old phase notes remain available at the recorded Git snapshot

## Releases

- `../CHANGELOG.md`: user-facing release history and migration-impact summary
- `develop/migration.md`: source and package migration reference
- `usage/en_us/compatibility.md`: English package and compatibility contract
- `usage/zh_cn/compatibility.md`: 中文 package 与兼容性契约

The usage and API documents are the current user-facing source of truth. The
period notes preserve development context and may describe temporary states from
when a phase was implemented.
