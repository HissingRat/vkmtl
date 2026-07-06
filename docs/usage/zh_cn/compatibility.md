# Compatibility

vkmtl 优先覆盖 portable Vulkan 和 Metal workflow；高级能力放在显式 capability gate 后面。

## 当前后端预期

| Platform | Preferred Backend | Notes |
| --- | --- | --- |
| macOS | Metal | Metal 可用时 `.auto` 默认走这条路径。 |
| macOS | Vulkan via MoltenVK | 只用于 backend testing；需要显式 loader 和 ICD path。 |
| Linux | Vulkan | Apple 以外平台的主要 portable backend。 |
| Windows | Vulkan | Apple 以外平台的主要 portable backend。 |
| iOS | Metal | Planned；surface packaging 尚未完成。 |

## Capability Gates

使用 `device.features()`、`device.limits()` 和 `device.getFormatCaps(...)`，不要靠平台假设。
不支持的 optional behavior 应该返回 typed error，而不是静默改变语义。

## Advanced Features

Period 10 的 advanced features 先提供 descriptor/API shape。Descriptor indexing、sparse
resources、external texture interop、tessellation、mesh shader、ray tracing 和 driver-level
pipeline cache 都会保持 gated，直到 backend lowering 实现。
