# Phase 4: Mip Tail And Alignment Handling

Phase 4 handles backend-specific sparse texture details.

## Scope

- Represent mip tail behavior in backend-neutral metadata.
- Validate mip-level alignment and page dimensions.
- Document differences that cannot be made fully portable.
- Track packed versus strided mip tail layouts without exposing Vulkan or Metal
  native structs.

## Validation

- Tests should cover small mip levels and format-dependent page sizes.
- Docs should include backend difference notes.
- Unit tests should validate first mip level and page-aligned offset/size.
