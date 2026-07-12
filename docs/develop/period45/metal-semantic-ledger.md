# Metal Semantic Ledger

Status: Period 47 semantic-allocation update to the macOS SDK 26.2 audited
baseline.

This ledger groups Objective-C overloads and descriptor helper classes by
observable GPU/runtime semantic. It covers the non-deprecated Metal framework
protocol families visible in the pinned SDK. A row marked `incomplete` remains
part of the audit even when vkmtl has no public contract. MetalKit, MetalFX, and
Metal Performance Shaders are outside this baseline.

The coverage vocabulary and evidence classes are defined by
`../native-semantic-coverage-inventory.md`. `owner` is a canonical vkmtl facade
or `missing-contract`; it does not admit new public API.

## Device, Allocation, And Resource Semantics

| ID | Metal source family | Semantic contract | Owner | Metal | Vulkan | Vulkan mapping / gates | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MTL-DEV-001 | `MTLDevice`, `MTLArchitecture` | Enumerate devices and report identity, location, architecture, and removable/headless state | diagnostics | native-exact | native-exact | `vkEnumeratePhysicalDevices`, properties, memory properties; core 1.0 | gpu-smoke |
| MTL-DEV-002 | `MTLDevice` feature/family queries | Query API/GPU-family feature availability without turning native facts into usable vkmtl paths | diagnostics | native-exact | composed-exact | Core/extension feature chains and format queries | unit |
| MTL-DEV-003 | `MTLDevice` execution limits | Report ordinary resource, render, and compute limits used by validation | diagnostics | incomplete | incomplete | Physical-device properties and limits; Period 47 queries buffer/texture/threadgroup bounds and validates resource creation, with remaining render/compute coverage still open | unit |
| MTL-DEV-004 | `MTLDevice` peer groups and registry identity | Identify peer devices and cross-device topology | missing-contract | incomplete | incomplete | Device groups and LUID/UUID properties where available | missing |
| MTL-DEV-005 | `MTLDevice` recommended working set and memory budget | Report native budget, usage, and working-set telemetry without substituting fallback estimates | diagnostics | incomplete | incomplete | Metal recommended working set plus `VK_EXT_memory_budget` where available | unit |
| MTL-RES-001 | `MTLAllocation`, `MTLResource` | Resource identity, labels, allocated size, ownership, and lifetime | resource | native-exact | native-exact | `VkBuffer`/`VkImage` objects plus allocation metadata | gpu-soak |
| MTL-RES-002 | Portable resource storage modes | Select automatic, shared, managed, or private storage with documented CPU visibility and automatic hazard behavior | resource | native-exact | composed-exact | Metal shared/managed/private resource modes; Vulkan host-coherent buffers and device-local/staged textures plus vkmtl hazard state. Private CPU access is rejected before backend calls | unit |
| MTL-RES-003 | `MTLBuffer` | Create GPU buffers, map allowed storage, obtain length, and use byte ranges | resource | native-exact | native-exact | `VkBuffer`, memory binding, map/unmap | gpu-pixels |
| MTL-RES-004 | `MTLBuffer` GPU address | Obtain stable shader-visible buffer address when supported and explicitly requested | resource | native-exact | native-exact | `MTLBuffer.gpuAddress`; Vulkan buffer-device-address feature, usage, allocation flags, and `vkGetBufferDeviceAddress`; Vulkan coverage is unit/inspection | gpu-smoke |
| MTL-RES-005 | `MTLTexture`, `MTLTextureDescriptor` | Create 1D/2D/3D, array, cube, and multisample textures with mip levels and usage | resource | native-exact | native-exact | `VkImage` creation and image views | gpu-pixels |
| MTL-RES-006 | `MTLTexture`, `MTLTextureViewDescriptor` | Create subresource views and compatible format/swizzle reinterpretations | resource | native-exact | native-exact | Metal pixel-format views/swizzle channels and Vulkan mutable images/`VkImageView` component mapping; only documented compatible classes are admitted | unit |
| MTL-RES-007 | `MTLPixelFormat`, `MTLTextureType`, `MTLTextureUsage` | Cover the allocated common portable texture/vertex format set and report exact capabilities | resource | composed-exact | native-exact | Period 47 finite Metal capability table plus direct pixel/vertex mappings; Vulkan format-property queries plus direct `VkFormat` mappings; formats outside the allocated set remain closed | unit |
| MTL-RES-008 | `MTLSamplerState`, `MTLSamplerDescriptor` | Filtering, addressing, LOD, compare, anisotropy, normalized coordinates, and border color | resource | composed-exact | composed-exact | `VkSampler` and `MTLSamplerDescriptor`; Period 47 validates and lowers the documented portable subset including unnormalized coordinates | unit |
| MTL-RES-009 | `MTLHeap`, `MTLHeapDescriptor` | Allocate buffers/textures from explicit heaps with placement, aliasing, and purgeability | resource | incomplete | incomplete | `VkDeviceMemory` suballocation and aliasing barriers | unit |
| MTL-RES-010 | `MTLResidencySet`, `MTLResidencySetDescriptor` | Maintain explicit resident allocation sets across queue execution | resource | incomplete | incomplete | Residency/device-group and memory-priority composition; no portable core equivalent | missing |
| MTL-RES-011 | `MTLResourceStateCommandEncoder`, `MTLResourceStatePassDescriptor` | Update sparse texture mappings and resource state | native | incomplete | incomplete | Sparse bind queues and image layout/ownership barriers | unit |
| MTL-RES-012 | `MTLResourceViewPool`, `MTLTextureViewPool` | Pool reusable resource/texture view objects | missing-contract | incomplete | incomplete | Runtime object pools over `VkImageView`/`VkBufferView` | missing |
| MTL-RES-013 | Memoryless texture storage | Attachment content exists only during the pass with hardware tile-memory intent | missing-contract | native-exact | incomplete | Transient attachment plus lazily allocated memory may approximate allocation behavior but cannot guarantee no backing allocation | inspection |
| MTL-RES-014 | Sparse buffers/textures and tile mappings | Create sparse resources and commit/decommit physical pages | resource | incomplete | incomplete | Sparse binding/residency features and `vkQueueBindSparse` | unit |
| MTL-RES-015 | `MTLTexture` shared handles and IOSurface-backed textures | Share texture storage across process/API boundaries | interop | incomplete | incomplete | External memory/image extensions and platform handles | unit |
| MTL-RES-016 | `MTLTensor`, `MTLTensorDescriptor` | Typed multidimensional tensor storage and views | missing-contract | incomplete | incomplete | Buffer/image representation or optional tensor extensions; exact contract undecided | missing |
| MTL-RES-017 | `MTLCPUCacheMode` and explicit resource cache policy | Select write-combined/default CPU cache behavior with truthful host-memory properties | resource | incomplete | incomplete | Vulkan host memory property/type selection; exact performance contract undecided | missing |
| MTL-RES-018 | `MTLHazardTrackingMode` | Select tracked, untracked, or default native hazard ownership | sync | incomplete | incomplete | Explicit vkmtl hazard state and Vulkan synchronization; caller responsibility contract undecided | missing |

## Command, Submission, Synchronization, And Presentation

| ID | Metal source family | Semantic contract | Owner | Metal | Vulkan | Vulkan mapping / gates | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MTL-CMD-001 | `MTLCommandQueue`, `MTLCommandQueueDescriptor` | Create queues and command buffers with bounded in-flight work | command | native-exact | composed-exact | Queue selection plus command pools/buffers and vkmtl in-flight tracking | gpu-soak |
| MTL-CMD-002 | `MTLCommandBuffer`, `MTLCommandBufferDescriptor` | Encode, commit, wait, observe completion/status/error, and retain resources | command | native-exact | composed-exact | `vkBegin/EndCommandBuffer`, submit, fence completion, runtime callbacks | gpu-soak |
| MTL-CMD-003 | `MTLCommandEncoder` | Encoder labels, debug groups, end-of-encoding lifetime, and command ownership | command | native-exact | composed-exact | Command-buffer regions, debug utils, vkmtl encoder state | gpu-smoke |
| MTL-CMD-004 | `MTLParallelRenderCommandEncoder` | Encode one render pass from multiple child encoders | missing-contract | incomplete | incomplete | Secondary command buffers or parallel CPU recording | missing |
| MTL-CMD-005 | `MTLDrawable` | Present immediately or at scheduled/minimum-duration times and observe presentation | presentation | incomplete | incomplete | Swapchain present plus present-timing extensions; ordinary presentation works, timing breadth does not | gpu-soak |
| MTL-CMD-006 | `MTLFence` | Order encoder access to resources within GPU work | sync | incomplete | incomplete | Pipeline/event barriers; current vkmtl fence is a portable runtime object | unit |
| MTL-CMD-007 | `MTLEvent`, `MTLSharedEvent` | Signal/wait monotonic values on GPU submissions and share event handles | sync | incomplete | incomplete | Timeline semaphores and external semaphore handles | unit |
| MTL-CMD-008 | Command-buffer completion/scheduled handlers | Invoke lifecycle callbacks with truthful submission status | missing-contract | incomplete | incomplete | Fence polling/wait thread or application callback dispatch | missing |
| MTL-CMD-009 | Multiple Metal queues and dependency ordering | Execute independent graphics/compute/transfer work with explicit dependencies | command | incomplete | incomplete | Queue-family selection, semaphores, and ownership transfers | unit |
| MTL-CMD-010 | `MTL4CommandAllocator`, `MTL4CommandQueue` | Separate reusable command allocation from queue and command-buffer ownership | missing-contract | incomplete | incomplete | `VkCommandPool`/queue composition | missing |
| MTL-CMD-011 | `MTL4CommandBuffer`, `MTL4CommitOptions`, `MTL4CommitFeedback` | Reusable command buffers, commit options, feedback, and explicit residency | missing-contract | incomplete | incomplete | Resettable command buffers, submit structures, query feedback, residency tracking | missing |
| MTL-CMD-012 | `MTL4CommandEncoder` barriers | Encode explicit command barriers in the Metal 4 model | sync | incomplete | incomplete | Pipeline barriers and dependency info | missing |

## Render Pass, Pipeline, And Draw Semantics

| ID | Metal source family | Semantic contract | Owner | Metal | Vulkan | Vulkan mapping / gates | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MTL-REN-001 | Common `MTLRenderPassDescriptor` attachment families | Color/depth/stencil attachments, clear/load/store, resolve, slices, levels, and render-target extent in the portable subset | render | native-exact | native-exact | All MRT color attachments and combined depth/stencil texture actions lower natively; unsupported separate stencil/current-drawable variants and depth/stencil resolve stay typed closed | gpu-pixels |
| MTL-REN-002 | Visibility result buffer and `MTLVisibilityResultModeBoolean` | Write portable zero/nonzero visibility from rasterized samples | diagnostics | composed-exact | native-exact | Non-precise Vulkan occlusion query pools; Metal uses per-pass scratch visibility storage copied into the canonical query buffer | gpu-smoke |
| MTL-REN-003 | `MTLRenderPassSampleBufferAttachmentDescriptor` | Sample hardware counters at pass boundaries | diagnostics | incomplete | incomplete | Timestamp/statistics query pools | missing |
| MTL-REN-004 | `MTLRasterizationRateMap` | Variable rasterization rate maps and coordinate transforms | missing-contract | incomplete | incomplete | Fragment shading rate attachment/extensions | missing |
| MTL-REN-005 | `MTLRenderPipelineState`, `MTLRenderPipelineDescriptor` | Compile vertex/fragment pipelines with formats, sample count, raster state, and reflection | render | native-exact | native-exact | Graphics pipeline creation and shader modules | gpu-pixels |
| MTL-REN-006 | `MTLDepthStencilState`, descriptors | Depth/stencil compare, write, masks, and front/back operations | render | native-exact | native-exact | Depth/stencil pipeline state | gpu-pixels |
| MTL-REN-007 | Common `MTLRenderCommandEncoder` resource binding | Bind portable vertex/fragment buffers, textures, samplers, bind groups, and root bytes | binding | composed-exact | native-exact | Metal slots/resources and Vulkan descriptor sets/push constants/vertex buffers; heaps/function tables have separate rows | gpu-pixels |
| MTL-REN-008 | Common `MTLRenderCommandEncoder` raster state | Viewports, scissors, winding, cull, fill, depth bias, blend color, and stencil reference | render | native-exact | native-exact | Pipeline and dynamic encoder state; depth clip, sample positions, and advanced raster controls have separate rows | gpu-pixels |
| MTL-REN-009 | `MTLRenderCommandEncoder` direct/indexed/instanced draws | Draw primitive and indexed ranges with base vertex/instance | render | native-exact | native-exact | `vkCmdDraw`/`vkCmdDrawIndexed` | gpu-pixels |
| MTL-REN-010 | `MTLRenderCommandEncoder` indirect draws | Execute draw arguments from buffers | render | native-exact | native-exact | Indirect draw commands; count/multi behavior may be composed | unit |
| MTL-REN-011 | Tessellation draw methods and factor buffers | Compile tessellation stages and draw patches with factor ownership | render | incomplete | incomplete | Tessellation pipelines and patch lists | unit |
| MTL-REN-012 | Mesh/object shader draw methods | Dispatch object/mesh grids into rasterization | render | incomplete | incomplete | Mesh shader extension and task/mesh stages | unit |
| MTL-REN-013 | Tile shaders and imageblocks | Execute tile-local programmable work with imageblock memory | missing-contract | incomplete | incomplete | Subpasses/input attachments, compute passes, or fragment interlock cannot yet prove the full contract | missing |
| MTL-REN-014 | Raster-order groups and programmable blending | Ordered per-pixel fragment access and shader-defined blending | missing-contract | incomplete | incomplete | Fragment shader interlock or subpass/input-attachment composition, capability-gated | missing |
| MTL-REN-015 | Layered rendering and vertex amplification | Route primitives to layers/viewports and amplify views | missing-contract | incomplete | incomplete | Multiview, shader viewport/layer, and geometry/mesh composition | missing |
| MTL-REN-016 | `MTLLogicalToPhysicalColorAttachmentMap` | Remap logical shader outputs to physical attachments | missing-contract | incomplete | incomplete | Pipeline shader/output remapping or dynamic rendering location extension | missing |
| MTL-REN-017 | `MTL4RenderPipelineState`, flexible pipeline descriptors | Compile/link flexible Metal 4 render, mesh, and tile pipeline state | missing-contract | incomplete | incomplete | Graphics pipeline libraries and dynamic state extensions | missing |
| MTL-REN-018 | `MTL4RenderCommandEncoder` | Encode Metal 4 render bindings, draws, barriers, counters, and ICB execution | missing-contract | incomplete | incomplete | Existing render mappings plus argument-table/allocator model | missing |
| MTL-REN-019 | Counting visibility / precise occlusion queries | Report exact samples passed rather than Boolean visibility | missing-contract | incomplete | incomplete | `MTLVisibilityResultModeCounting` and Vulkan precise occlusion feature; no portable exact-count contract exists | missing |
| MTL-REN-020 | Depth clip modes, programmable sample positions, and advanced dynamic raster controls | Configure raster behavior beyond the common viewport/scissor/cull/fill/depth-bias subset | render | incomplete | incomplete | Depth-clip-control and sample-location extensions where available | missing |

## Compute, Machine Learning, And Transfer Semantics

| ID | Metal source family | Semantic contract | Owner | Metal | Vulkan | Vulkan mapping / gates | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MTL-CMP-001 | `MTLComputePipelineState`, descriptor/reflection | Compile compute functions and report thread execution limits | compute | native-exact | native-exact | Compute pipeline and device limits | gpu-pixels |
| MTL-CMP-002 | Common `MTLComputeCommandEncoder` binding | Bind portable buffers, textures, samplers, bind groups, and root bytes | binding | incomplete | incomplete | Descriptor sets/push constants; heaps/function tables have separate rows | gpu-pixels |
| MTL-CMP-003 | `MTLComputeCommandEncoder` dispatch | Direct, indirect, exact/nonuniform thread/grid dispatch | compute | incomplete | incomplete | Direct/indirect dispatch; nonuniform/exact grid semantics require capability audit | gpu-pixels |
| MTL-CMP-004 | Compute resource barriers and usage | Order portable buffer/texture access within and across dispatches | sync | incomplete | incomplete | Compute pipeline barriers and vkmtl hazard state; native fences/events have separate rows | unit |
| MTL-CMP-005 | Compute atomics and threadgroup memory | Execute shader atomic and shared-memory semantics | compute | incomplete | incomplete | SPIR-V capabilities and device limits | unit |
| MTL-CMP-006 | `MTL4ComputeCommandEncoder` | Encode Metal 4 argument tables, dispatches, barriers, counters, and ICB execution | missing-contract | incomplete | incomplete | Compute commands plus Metal 4 resource model composition | missing |
| MTL-CMP-007 | `MTL4MachineLearningPipelineState`, descriptor/reflection | Compile machine-learning pipeline state and tensor bindings | missing-contract | incomplete | incomplete | Compute/cooperative-matrix or tensor extension mapping undecided | missing |
| MTL-CMP-008 | `MTL4MachineLearningCommandEncoder` | Dispatch machine-learning networks with tensor resources | missing-contract | incomplete | incomplete | Compute graph/dispatch compatibility layer undecided | missing |
| MTL-XFR-001 | `MTLBlitCommandEncoder` buffer copies/fills | Copy and fill byte ranges | transfer | native-exact | composed-exact | Copy/fill commands; unaligned fill uses staging fallback | gpu-pixels |
| MTL-XFR-002 | `MTLBlitCommandEncoder` texture copies | Copy texture subresources and buffer/texture layouts | transfer | composed-exact | native-exact | Copy commands with per-slice Metal loops and Vulkan alignment validation | gpu-pixels |
| MTL-XFR-003 | `MTLBlitCommandEncoder` mipmap generation | Generate a complete mip chain | transfer | native-exact | native-exact | Metal mip generation and Vulkan image blits | unit |
| MTL-XFR-004 | Managed/host-visible resource synchronization | Make CPU and GPU writes visible across documented transfer/map boundaries | transfer | incomplete | incomplete | Metal managed-resource synchronization plus Vulkan flush/invalidate composition | missing |
| MTL-XFR-005 | `MTLBlitCommandEncoder` query/counter resolve | Resolve Boolean visibility or timestamp samples into buffers | diagnostics | native-exact | native-exact | Vulkan query-pool result copies; Metal resolves counters to aligned internal storage before copying to the portable destination offset | gpu-smoke |
| MTL-XFR-006 | `MTLIOFileHandle`, `MTLIOCommandQueue`, `MTLIOCommandBuffer` | Load file ranges asynchronously into buffers/textures with queue status | missing-contract | incomplete | incomplete | OS async I/O plus staging/transfer queue composition | missing |
| MTL-XFR-007 | `MTLIOScratchBuffer`, allocator, compressor | Manage scratch storage and Metal I/O compressed streams | missing-contract | incomplete | incomplete | Application decompression plus transfer composition | missing |
| MTL-XFR-008 | `MTLBlitCommandEncoder` CPU/GPU content optimization hints | Preserve explicit resource-content optimization intent where it has a truthful backend effect | missing-contract | incomplete | incomplete | Vulkan memory/layout hints do not expose an exact direct equivalent | missing |

## Shader, Binding, Indirect Command, And Pipeline Persistence

| ID | Metal source family | Semantic contract | Owner | Metal | Vulkan | Vulkan mapping / gates | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MTL-SHD-001 | `MTLLibrary`, `MTLFunction`, compile options | Create libraries/functions from precompiled or source artifacts | shader | composed-exact | composed-exact | vkmtl build-time Slang produces embedded MSL/SPIR-V | gpu-pixels |
| MTL-SHD-002 | `MTLFunctionConstantValues` | Specialize vertex, fragment, and compute functions by stable numeric typed constant IDs | shader | native-exact | native-exact | Metal `setConstantValue:type:atIndex:` and specialized function creation; Vulkan specialization info uses the same IDs | gpu-pixels |
| MTL-SHD-003 | Portable function reflection and binding protocols | Reflect buffers, textures, samplers, arrays, access, and vertex inputs used by portable layouts | shader | incomplete | incomplete | Slang reflection covers the portable subset on both generated backends | unit |
| MTL-SHD-004 | `MTLFunctionDescriptor`, linked functions | Compose visible/private functions and linked function sets | shader | incomplete | incomplete | SPIR-V/library linking or multiple module composition | missing |
| MTL-SHD-005 | `MTLFunctionHandle`, visible/intersection function tables | Obtain callable handles and populate GPU function tables | ray_tracing | incomplete | incomplete | SBT/callable shader records and descriptor buffers/sets | unit |
| MTL-SHD-006 | Function stitching graph/node protocols | Build specialized functions by stitching callable graph nodes | missing-contract | incomplete | incomplete | Shader generation/link-time composition | missing |
| MTL-SHD-007 | `MTLDynamicLibrary` | Load/install dynamic shader libraries and resolve functions | missing-contract | incomplete | incomplete | Pipeline library/shader object composition where available | missing |
| MTL-SHD-008 | Function logs and `MTLLogState` | Capture shader compilation/execution log messages and locations | diagnostics | incomplete | incomplete | Debug printf/validation tooling; no portable exact path defined | missing |
| MTL-SHD-009 | Tensor, payload, function-table, and advanced threadgroup reflection | Reflect Metal-only or advanced shader binding protocols outside portable layouts | missing-contract | incomplete | incomplete | Requires tensor, callable/function-table, payload, and advanced shared-memory contracts | missing |
| MTL-BND-001 | `MTLArgumentEncoder` | Encode buffers, textures, samplers, constants, and nested argument buffers | binding | incomplete | incomplete | Descriptor sets/indexing and CPU table encoding | unit |
| MTL-BND-002 | `MTL4ArgumentTable` | Allocate/update Metal 4 argument tables with residency semantics | binding | incomplete | incomplete | Descriptor sets/buffers and update-after-bind | missing |
| MTL-IND-001 | `MTLIndirectCommandBuffer`, descriptor | Allocate/reset command slots and inherit pipeline/buffer state | missing-contract | incomplete | incomplete | Secondary/generated command buffers; device-generated commands extensions | missing |
| MTL-IND-002 | `MTLIndirectRenderCommand` | GPU/CPU encode indirect render state and draw commands | missing-contract | incomplete | incomplete | Device-generated commands or argument-buffer-driven draw expansion | missing |
| MTL-IND-003 | `MTLIndirectComputeCommand` | GPU/CPU encode indirect compute state and dispatch commands | missing-contract | incomplete | incomplete | Device-generated commands or indirect dispatch composition | missing |
| MTL-ARC-001 | `MTLBinaryArchive` | Add pipeline functions and serialize reusable pipeline artifacts | diagnostics | incomplete | not-applicable | Metal-specific archive; Vulkan uses separate cache semantic | unit |
| MTL-ARC-002 | Vulkan pipeline cache counterpart | Reuse driver pipeline artifacts across runs | diagnostics | not-applicable | incomplete | `VkPipelineCache` creation/data/merge and compatibility identity | unit |
| MTL-ARC-003 | `MTL4Archive`, binary functions | Store/load Metal 4 binary functions and link pipeline stages | missing-contract | incomplete | incomplete | Pipeline libraries/cache plus shader-module identity | missing |
| MTL-ARC-004 | `MTL4Compiler`, task/options | Compile libraries and pipelines through dedicated compiler contexts | missing-contract | incomplete | incomplete | Application/compiler service plus Vulkan pipeline compilation controls | missing |
| MTL-ARC-005 | `MTL4PipelineDataSetSerializer` | Serialize versioned pipeline datasets | diagnostics | incomplete | incomplete | Pipeline-cache data plus vkmtl compatibility manifest | missing |

## Ray Tracing, Diagnostics, Capture, And Native Interop

| ID | Metal source family | Semantic contract | Owner | Metal | Vulkan | Vulkan mapping / gates | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MTL-RT-001 | `MTLAccelerationStructure`, descriptors | Create triangle, curve, bounding-box, motion, primitive, and instance AS descriptions | ray_tracing | incomplete | incomplete | KHR acceleration structures; current mesh/AABB subset is executable | gpu-smoke |
| MTL-RT-002 | `MTLAccelerationStructureCommandEncoder` build | Build BLAS/TLAS from application buffers | ray_tracing | native-exact | native-exact | KHR AS build commands | gpu-smoke |
| MTL-RT-003 | AS refit/copy/compact/size queries | Maintain and compact acceleration structures | ray_tracing | incomplete | incomplete | KHR update/copy/query commands | unit |
| MTL-RT-004 | `MTLIntersectionFunctionTable` | Bind custom intersection, visible functions, buffers, and acceleration structures | ray_tracing | incomplete | incomplete | RT shader groups, SBT records, descriptor bindings | unit |
| MTL-RT-005 | Ray dispatch through compute/render pipelines | Trace and shade rays into resources or render output | ray_tracing | native-exact | native-exact | Metal intersection functions and `vkCmdTraceRaysKHR` | gpu-pixels |
| MTL-RT-006 | Ray query from ordinary shader stages | Inline traversal and candidate intersection control | ray_tracing | unsupported | incomplete | Vulkan ray query extension; vkmtl Vulkan usable path remains closed | unit |
| MTL-RT-007 | Callable shaders and complex function-table/SBT layouts | Invoke callable records and multiple hit/miss groups | ray_tracing | incomplete | incomplete | Callable shader groups and SBT layouts | unit |
| MTL-RT-008 | Motion transforms and advanced AS geometry | Trace motion/curve/row-major advanced geometry | ray_tracing | incomplete | incomplete | Motion blur/curve extensions where available | missing |
| MTL-RT-009 | Metal 4 acceleration structure descriptors | Express Metal 4 AS geometry and instance families | ray_tracing | incomplete | incomplete | KHR/extension AS descriptors | missing |
| MTL-DBG-001 | Labels and command/encoder debug groups | Name objects and nest diagnostic regions | command | native-exact | native-exact | Debug utils when enabled | gpu-smoke |
| MTL-DBG-002 | `MTLCaptureScope`, `MTLCaptureManager` | Start/end developer-tools GPU capture scopes | diagnostics | native-exact | unsupported | Vulkan capture remains external-tool-specific | gpu-smoke |
| MTL-DBG-003 | Common timestamp counter set and sample buffers | Discover the timestamp counter, sample at draw/dispatch/blit boundaries, and report raw GPU ticks | diagnostics | native-exact | native-exact | Capability-gated Metal counter sample buffers and Vulkan timestamp query pools; duration calibration is not part of this row | unit |
| MTL-DBG-004 | `MTL4CounterHeap` | Allocate and sample Metal 4 counter storage | diagnostics | incomplete | incomplete | Query pools and performance counters | missing |
| MTL-DBG-005 | Non-timestamp and device-specific counter/statistics families | Discover, sample, resolve, and interpret counter sets beyond raw timestamps | missing-contract | incomplete | incomplete | Metal device counter sets and Vulkan pipeline/performance queries require result-shape and calibration contracts | missing |
| MTL-INT-001 | Shared event/texture handles | Export/import cross-process resource and synchronization handles | interop | incomplete | incomplete | External memory/semaphore platform extensions | unit |
| MTL-INT-002 | Native object escape hatches | Borrow tagged native devices, queues, resources, and drawables | native | native-exact | native-exact | Explicit backend-tagged borrowed handles | inspection |
| MTL-INT-003 | Native command insertion | Insert backend-specific commands while preserving encoder ownership/lifetime | native | incomplete | incomplete | Raw command handles plus validated callback scope | unit |

## Source Declaration Coverage

Descriptor/helper classes inherit the semantic row of the protocol or pipeline
family they configure. The audited protocol set contains 78 concrete Metal
protocols from SDK 26.2, including all `MTL4*`, allocation/resource, queue and
encoder, render/compute/blit, indirect command, shader/function, heap/residency,
I/O, tensor/ML, counter/debug, and acceleration-structure/function-table
families represented above. Forward declarations are not counted separately.

The source audit found 149 concrete `MTL*` descriptor/helper interfaces. They
are covered by the matching rows above; interfaces that change observable
semantics, including memoryless storage, rasterization-rate maps, logical color
attachment maps, tensor descriptors, pipeline linking, motion geometry, and
Metal 4 pipeline datasets, have dedicated rows rather than being hidden under
generic object creation.

`metal-protocol-semantic-map.tsv` records the complete 78-protocol source
snapshot and maps every protocol to one or more ledger IDs. The semantic
inventory check rejects duplicate protocols, unknown ledger IDs, or a changed
protocol count. A future SDK baseline update must regenerate and review this
map instead of silently inheriting the old count.
