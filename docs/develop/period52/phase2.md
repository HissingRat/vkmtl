# Period 52 Phase 2: Native AS Maintenance

Status: complete.

Vulkan build update now sets `VK_BUILD_ACCELERATION_STRUCTURE_MODE_UPDATE_KHR`,
uses the explicit source AS, preserves `ALLOW_UPDATE`/`ALLOW_COMPACTION`, and
uses the queried update scratch size. Maintenance update/refit executes an
in-place native update and compact executes
`vkCmdCopyAccelerationStructureKHR` with compact mode.

Metal creation and geometry descriptors preserve
`MTLAccelerationStructureUsageRefit`. Build update and maintenance update/refit
encode `refitAccelerationStructure`, while compact encodes
`copyAndCompactAccelerationStructure` into an explicit destination.

The public resource validator rejects:

- unbuilt, foreign-backend, wrong-kind, or wrong-count sources;
- update/refit on a source not created with `allow_update`;
- compact on a source not built with `allow_compaction`;
- missing, misaligned, wrong-usage, or undersized scratch buffers;
- compact without a distinct compatible destination;
- scratch/destination resources that do not belong to the selected operation.

Build and update scratch sizes remain native device queries. A post-build
compacted-size query is not exposed and is closed separately.

The source keeps native geometry addresses/descriptors for maintenance. Caller
owned build-input buffers and TLAS instance-source AS objects therefore remain
alive through each update/refit submission; supplied source, destination, and
scratch handles are checked directly at encode time.
