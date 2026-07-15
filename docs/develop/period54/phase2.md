# Period 54 Phase 2: Exact Counting Visibility

Status: complete.

`diagnostics.QuerySetDescriptor.occlusion_mode` now distinguishes the existing
`.boolean` zero/nonzero contract from `.counting` exact rasterized sample
counts. Boolean remains the default.

Counting has a separate `DeviceFeatures.occlusion_counting_queries` gate:

- Metal reports it for the native counting visibility mode and encodes
  `MTLVisibilityResultModeCounting`;
- Vulkan reports it only when `occlusionQueryPrecise` is supported and enabled,
  then begins the query with the precise flag.

Readback, GPU resolve, alignment, pass binding, availability, reset/reuse, and
command-buffer borrowing retain the existing one-`u64` query contract.
Requesting counting without the capability returns
`UnsupportedOcclusionCountingQueries` before backend work.

Physical Metal pixel/query regression produced `visible=61170`, `empty=0`
twice, then passed reset/reuse and render readback.
