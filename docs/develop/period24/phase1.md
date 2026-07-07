# Phase 1: Multi-Surface Runtime

Phase 1 lets one device manage more than one presentation target.

## Scope

- Add device-owned surface registry.
- Support multiple Vulkan swapchains.
- Support multiple Metal drawable/layer states.
- Handle independent resize/minimize/surface-loss events.

## Validation

- Add a multi-window example.
- Add resize and close-order tests where possible.
