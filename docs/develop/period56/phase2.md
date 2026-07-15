# Period 56 Phase 2: Backend Resolution And Resize

Status: complete.

## Shared Resolution Rules

Both backends implement the Phase 1 table, not separate preference policies.
The resolver first limits native candidates to the standard SDR mappings for
`bgra8_unorm_srgb` and `bgra8_unorm`, then applies this stable order:

1. an explicit request matches only the same portable format;
2. `.automatic` chooses `bgra8_unorm_srgb` when available;
3. otherwise `.automatic` chooses `bgra8_unorm`;
4. no admitted candidate produces a typed unsupported result.

The result is independent of the order returned by a Vulkan driver. Vulkan's
undefined-format sentinel may advertise that the application can choose a
format, but it does not change the portable preference order or admit a
non-SDR color space.

## Metal Mapping

Metal must configure `CAMetalLayer.pixelFormat` from the selected portable
format: `MTLPixelFormatBGRA8Unorm_sRGB` for `bgra8_unorm_srgb` and
`MTLPixelFormatBGRA8Unorm` for `bgra8_unorm`. The layer format, current drawable
texture, reported format capability, and `Swapchain.selectedFormat()` must
agree. Metal does not silently force the sRGB default over an explicit linear
request.

Metal resize allocates the replacement depth texture before publishing the new
`CAMetalLayer.drawableSize` or cached drawable extent. An allocation failure
therefore leaves the last successful Metal presentation extent unchanged.

## Vulkan Mapping

Vulkan must enumerate the surface formats and choose the exact native BGRA8
format plus standard SDR color-space mapping corresponding to the portable
selection. It must not select `formats[0]` as an unobservable fallback. An
explicit portable request either receives its exact native mapping or fails
before `vkCreateSwapchainKHR`.

Vulkan recreation must destroy framebuffer and other render-target dependents
before destroying the old swapchain image views. When resolution selects a
different format, recreation must also rebuild the color and depth render-pass
state against that new selected format before publishing success.

## Runtime State And Resize

Runtime state stores the requested descriptor and selected format separately.
Initialization and every actual native recreation run resolution.
`Swapchain.resize(...)` preserves the requested `format`, updates the requested
extent after success, and publishes both the selected format and actual backend
extent before returning. `Swapchain.presentationDescriptor().extent` is the
request passed to resize; `Swapchain.extent()` is the actual selected extent
and may differ when Vulkan surface constraints clamp the request.

A healthy Vulkan resize to the same requested extent is a cheap no-op without a
surface query. Queue-present or next-image-acquire `SUBOPTIMAL`/`OUT_OF_DATE`
marks recovery required, so the next resize rebuilds even when the requested
extent is unchanged. A changed requested extent re-queries the complete native
presentation state. If that resolved format, color space, present mode, actual
extent, image count, and transform are unchanged and recovery is not required,
the runtime records the new request without rebuilding native resources.

With `suspend_when_zero`, a zero-sized suspension preserves both the request
and the last successful selected format and actual extent. Resuming at a
non-zero extent follows the normal decision: an unchanged healthy request is a
cheap no-query no-op, while a changed request or recovery-required state
re-queries and resolves native presentation state. A changed surface capability
set may therefore change `.automatic` when resolution runs; explicit requests
never silently change selection and instead fail if no longer available.

Focused tests cover candidate order, the Vulkan undefined sentinel, missing
preferred and missing-all cases, both explicit requests, render-pass rebuild
selection, the same-request fast path, recovery-forced recreation, changed
requests that resolve to unchanged native state, and request-versus-selection
state. The selected backend owns native recreation; after every successful
non-zero resize the runtime publishes the backend's concrete selected format
without rewriting the stored format request.

## Vulkan Recreation Safety

A non-zero Vulkan resize and `Swapchain.clear(...)` both require zero
uncommitted backend command buffers from the window runtime. Otherwise they
return `InvalidCommandBufferState` before querying, mutating, or destroying
native presentation state. Callers must finish and commit command buffers
first; the resize guard applies even if the requested extent equals the
previous request. The clear helper records through its own command pool and
resets only that pool, never a pool that owns caller command buffers.

After destructive recreation starts, any failure destroys the remaining
presentation resources and marks that Vulkan presentation runtime lost. The
failing call returns its original error; later resize (including zero), clear,
or command-buffer creation returns `SurfaceLost`. Cached request/selection queries
describe the last successful state but are no longer usable for rendering; the
application must recreate `WindowContext`.

Normal teardown and this poisoned teardown both wait graphics fences and the
presentation queue before destroying swapchain images, presentation
semaphores, or the swapchain handle. A graphics fence alone only proves the
render submission finished; it does not prove `vkQueuePresentKHR` has consumed
its wait semaphore and image.

A failed public `CommandBuffer.commit()` is terminal for that one-shot command
buffer. The runtime deinitializes its backend command buffer, releases the
active-command count and query-set resolve borrows, retires its submitted work
serial, marks it dead, and reports the failed lifecycle state before returning
the original error. On Vulkan, if native work was submitted before a later
commit step failed, the backend waits that submitted queue before destroying
temporary render, blit, or ray-dispatch resources.
