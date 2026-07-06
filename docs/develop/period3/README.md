# Period 3

Period 3 is reserved for stabilization and deeper parity after Period 2 has
covered broader application scenarios.

The long-term goal is practical parity: if Metal and Vulkan can support a
graphics or compute workload, vkmtl should either expose a backend-neutral path
for it or clearly document why the feature cannot be mapped portably.

Likely themes:

- stable `Device` and `Queue` ownership
- feature and limit queries that applications can rely on
- native-handle escape hatches for advanced users
- portability-gap cleanup discovered by Period 2 examples
- release-quality validation, packaging, and compatibility guarantees
