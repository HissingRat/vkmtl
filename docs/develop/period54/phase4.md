# Period 54 Phase 4: Precise Closure Decisions

Status: complete.

## Metal 4 Command And Pipeline Objects

Unsupported as distinct execution contracts. The current runtime has no
separate command allocator, resettable/reusable whole command buffer,
residency list, commit options, asynchronous feedback object, flexible stage
linking, or Metal 4 encoder ownership. Ordinary fixed pipelines and classic
render/compute commands remain supported through their existing rows.

## Compiler, Archive, And Pipeline Dataset

Unsupported. Consumer shaders are source-backed build inputs and become
embedded precompiled artifacts. There is no runtime compiler task/service,
binary-function link unit, install identity, complete Metal 4 pipeline object
graph, dataset schema, or cross-backend serializer compatibility contract.
Ordinary Metal binary archives and Vulkan pipeline caches remain supported
separately.

## Tensor And Machine Learning

Unsupported. A complete contract requires tensor scalar types, dimensions,
strides/layout, views and aliasing, storage/device ownership, graph/pipeline
specialization, dispatch, synchronization, and a precise Vulkan mapping.
Buffers, textures, compute shaders, or cooperative matrices are not silently
treated as equivalent ML execution.

## Counters, Statistics, Pass Attachments, And Logs

Unsupported beyond raw timestamps, Boolean visibility, and the new exact-count
visibility mode. The scalar query result cannot represent typed variable
counter sets, availability, overflow, calibration, or device-specific
interpretation. Render passes also lack begin/end query-set indices for sample
attachments. Function logs lack callback/container lifetime, source-location
identity, and severity semantics. Advanced tensor/payload/table reflection
stays outside the admitted portable binding protocols.

No usable feature bit is opened for any of these unsupported families.
