# Period 50 Phase 4: Persistent Driver Pipeline Artifacts

Status: complete.

## Vulkan

- Read an existing cache blob when present.
- Recover from invalid/stale native data by creating an empty
  `VkPipelineCache`.
- Pass the cache to graphics and compute pipeline creation.
- Query and replace the cache file after successful creation unless the
  descriptor is read-only.

## Metal

- Load an existing `MTLBinaryArchive` URL when valid and recover with an empty
  archive when it is not.
- Attach the archive to render/compute pipeline descriptors and add their
  functions.
- Serialize after successful pipeline creation unless read-only.

## Ownership And Failure

- Cache path and identity data are borrowed during synchronous pipeline
  creation only.
- Cache misses and stale native blobs fall back to ordinary pipeline creation.
- Native pipeline creation failures remain typed pipeline/backend errors.
  Cache read/write/serialization failures are best-effort misses and never
  become false cache-hit claims or invalidate an otherwise valid pipeline.
- Runtime shader artifacts remain embedded and read-only; driver-cache files do
  not replace the shader manifest.
