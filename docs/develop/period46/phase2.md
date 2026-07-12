# Phase 2: Vulkan Query Pools

Status: complete.

## Mapping

- Occlusion: `VK_QUERY_TYPE_OCCLUSION`, `vkCmdBeginQuery`, `vkCmdEndQuery`.
- Timestamp: `VK_QUERY_TYPE_TIMESTAMP`, `vkCmdWriteTimestamp` at an encoder
  boundary compatible with the current command path.
- Reset: host `vkResetQueryPool` before the pool is reused. The device path
  queries and enables `hostQueryReset`; without it, reusable native pools stay
  closed because command reset cannot be inserted inside the current render
  pass.
- Timestamp capability additionally requires nonzero `timestampValidBits` on
  the selected graphics queue family.
- CPU readback: `vkGetQueryPoolResults` with 64-bit results and no implicit
  wait; `VK_NOT_READY` becomes `QueryNotReady`.
- GPU resolve: `vkCmdCopyQueryPoolResults` with 64-bit results and `WAIT` into a
  copy-destination buffer. Portable slot-state validation rejects unwritten or
  reset slots before recording the wait, avoiding an unfulfillable query wait.

Occlusion is portable visibility, not a precise sample-count query: vkmtl uses
the non-precise Vulkan query mode, so zero means occluded and any nonzero value
means visible.

Pipeline statistics stay typed unsupported in this period. A query can produce
several counters, while the current public readback shape contains one `u64`
per query; silently aggregating them would not be exact semantics.
