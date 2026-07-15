# Phase 5: Chunk Streaming And Mesh Rebuild Loop

Status: complete.

Phase 5 turns the static field into a bounded streaming workload and records
the cost of the current submission behavior.

## Implemented Scope

- The world maintains a bounded desired square grid around the camera and
  incrementally fills it: 9, 81, or 289 maximum resident chunks.
- Desired chunks are queued center-out in rings. Leaving chunks are retired,
  and camera movement repopulates the bounded desired set.
- At most two chunks and 8 MiB of mesh data are processed per frame. Remaining
  work stays in the bounded pending queue.
- `R` rebuilds the current chunk. Automated smoke mode also moves the camera
  and requests periodic rebuilds, so finite runs cover both replacement and
  retirement.
- Diagnostics track resident, visible, culled, pending, draw, vertex, index,
  rebuilt, retired, uploaded-byte, buffer-allocation, meshing, encoding,
  commit, and frame-time values.

## Bounded-Growth Evidence

| Profile | Frames | Resident | Rebuilt | Retired | Pending at exit | Maximum resident |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| smoke autopilot | 24 | 9 | 13 | 4 | 0 | 9 |
| default | 48 | 81 | 81 | 0 | 0 | 81 |
| stress | 160 | 289 | 289 | 0 | 0 | 289 |

All three runs drained their queues and stayed inside the selected resident
bound. Smoke autopilot proves retirement plus replacement; default and stress
prove complete initial population at increasing scale.

## Submission Finding

The upload/rebuild loop is bounded, but command submission is not asynchronous.
Metal `CommandBuffer.commit()` calls `waitUntilCompleted`, so
`commit_ms_per_frame` includes a CPU wait for GPU completion and cannot be
interpreted as enqueue-only cost. Vulkan uses per-image synchronization for
presentation, but the current `commit()` still calls `queueWaitIdle` after
either submission path. Because physical Vulkan was not run for this period,
this documents the code path without making a Vulkan timing claim.

This is the main vkmtl pressure finding. Correctness does not require a new API,
so Period 19 keeps the current contract. A future explicitly allocated period
should design:

- two or three in-flight frame slots with bounded backpressure;
- completion serials, fences, or another portable submission token;
- deferred destruction of retired chunk buffers until their submission
  completes;
- per-frame uniform and upload-ring ownership;
- Metal completed-handler/shared-event and Vulkan fence/timeline lowering;
- physical measurements on both backends before changing public lifetime
  semantics.
