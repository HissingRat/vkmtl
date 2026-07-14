# Period 52 Phase 3: Ordinary Geometry And Instance Breadth

Status: complete.

Metal now lowers `AccelerationStructureGeometryKind.aabbs` through
`MTLAccelerationStructureBoundingBoxGeometryDescriptor`, retaining the caller
buffer and its offset/stride/count/opaque state for command submission.

Because AS allocation precedes command resources, Metal BLAS size queries and
allocation take the maximum native result/build/refit size of the admitted
triangle and AABB forms. Replacing the placeholder triangle descriptor with an
AABB descriptor cannot silently exceed the allocated AS or scratch contract.
The allocation also reserves the update-capable upper bound, because
`AccelerationStructureBuildFlags.allow_update` can opt in after the opaque AS
object has already been created.

Metal TLAS construction now retains an array of distinct built BLAS objects and
writes the corresponding `accelerationStructureIndex` for each instance. A
single BLAS can still be repeated across all instances through the original
single-source convenience path.

The current runtime instance resource does not carry transforms, masks, custom
indices, or SBT record offsets. Non-default instance metadata remains a
planning contract and is explicitly outside the executable claim.
