# Period 52 Phase 1: Contract And Capability Allocation

Status: complete.

Period 52 owns `MTL-SHD-005` and `MTL-RT-001`, `003`, `004`, and `006`
through `009` from the Period 45 audit.

The audit found three categories:

1. Existing public shapes with missing native execution: AS build update and
   maintenance plans.
2. Ordinary native breadth fitting the existing resource contract: Metal AABB
   input and multiple BLAS sources in one TLAS.
3. Planning or native-query shapes without a complete shader/artifact/binding
   contract: function tables, ray query, callable/complex SBT, motion/curves,
   and Metal 4 descriptors.

Maintenance is allocated as a command resource bundle rather than another
`Device` factory. The operation acts on existing opaque AS/buffer handles and
therefore belongs on `CommandBuffer`, while its descriptor and resources stay
under the canonical `ray_tracing` facade.

Usable `features()` now exposes the already executable basic RT and ordinary AS
paths. Native-only callable, ray-query, and Metal custom-intersection facts
stay in `nativeFeatures()` and cannot pass executable factories.
