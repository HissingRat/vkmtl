# Phase 2: Metal Tessellation Lowering

Phase 2 implements Metal tessellation lowering.

## Scope

- Map public tessellation descriptors to Metal tessellation pipeline state.
- Handle patch control point and partition mode differences.
- Document any Metal-specific constraints.

## Validation

- Tests should cover unsupported partition modes and patch sizes.
- A Metal smoke example should render a tessellated primitive.
