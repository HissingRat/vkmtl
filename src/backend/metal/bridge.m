#import "bridge.h"

#if defined(__APPLE__)
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <math.h>
#import <stdio.h>
#import <stdint.h>
#import <stdlib.h>
#import <string.h>

struct vkmtl_metal_probe {
    id<MTLDevice> device;
};

struct vkmtl_metal_clear_screen {
    id<MTLDevice> device;
    id<MTLCommandQueue> queue;
    id<MTLCommandQueue> compute_queue;
    id<MTLCommandQueue> transfer_queue;
    CAMetalLayer *layer;
    NSView *view;
    id<MTLTexture> depth_texture;
    unsigned int width;
    unsigned int height;
    unsigned int buffer_gpu_address;
};

struct vkmtl_metal_buffer {
    id<MTLBuffer> buffer;
    id<MTLCommandQueue> queue;
    size_t length;
    vkmtl_metal_storage_mode storage_mode;
};

struct vkmtl_metal_texture {
    id<MTLTexture> texture;
    unsigned int width;
    unsigned int height;
    unsigned int depth_or_array_layers;
    unsigned int mip_level_count;
    unsigned int sample_count;
};

struct vkmtl_metal_texture_view {
    id<MTLTexture> texture;
    unsigned int sample_count;
};

struct vkmtl_metal_sampler_state {
    id<MTLSamplerState> sampler;
};

struct vkmtl_metal_resource_table {
    id<MTLArgumentEncoder> encoder;
    id<MTLBuffer> buffer;
    id<MTLResource> *resources;
    MTLResourceUsage *usages;
    NSUInteger resource_count;
};

struct vkmtl_metal_indirect_command_buffer {
    id<MTLIndirectCommandBuffer> buffer;
    unsigned int kind;
    NSUInteger max_command_count;
};

struct vkmtl_metal_shader_module {
    id<MTLLibrary> library;
};

struct vkmtl_metal_render_pipeline_state {
    id<MTLRenderPipelineState> pipeline;
    id<MTLDepthStencilState> depth_stencil;
};

struct vkmtl_metal_compute_pipeline_state {
    id<MTLComputePipelineState> pipeline;
};

struct vkmtl_metal_query_set {
    vkmtl_metal_query_type query_type;
    NSUInteger count;
    id<MTLBuffer> result_buffer;
    id<MTLCounterSampleBuffer> counter_sample_buffer;
    id<MTLBuffer> counter_resolve_buffer;
    id<MTLCommandBuffer> *writer_command_buffers;
};

struct vkmtl_metal_shared_event {
    id<MTLSharedEvent> event;
};

struct vkmtl_metal_heap {
    id<MTLDevice> device;
    id<MTLHeap> heap;
    id<MTLCommandQueue> queue;
    MTLStorageMode storage_mode;
};

struct vkmtl_metal_acceleration_structure {
    id<MTLAccelerationStructure> acceleration_structure;
    MTLAccelerationStructureDescriptor *descriptor;
    id<MTLBuffer> geometry_buffer;
    id<MTLBuffer> index_buffer;
    id<MTLBuffer> instance_buffer;
    vkmtl_metal_acceleration_structure_kind kind;
    unsigned int primitive_count;
    size_t result_size;
    size_t scratch_size;
    size_t update_scratch_size;
    unsigned int built;
};

struct vkmtl_metal_ray_tracing_pipeline_state {
    id<MTLComputePipelineState> pipeline;
};

struct vkmtl_metal_command_buffer {
    vkmtl_metal_clear_screen *owner;
    id<MTLCommandBuffer> command_buffer;
    id<CAMetalDrawable> drawable;
};

struct vkmtl_metal_render_command_encoder {
    id<MTLRenderCommandEncoder> encoder;
    id<MTLBuffer> index_buffer;
    id<MTLCommandBuffer> command_buffer;
    id<MTLBuffer> visibility_scratch_buffer;
    id<MTLBuffer> visibility_result_buffer;
    unsigned char *visibility_slots;
    NSUInteger visibility_slot_count;
    NSUInteger active_visibility_index;
    unsigned int visibility_active;
    unsigned int ended;
};

struct vkmtl_metal_blit_command_encoder {
    id<MTLBlitCommandEncoder> encoder;
    id<MTLCommandBuffer> command_buffer;
};

struct vkmtl_metal_compute_command_encoder {
    id<MTLComputeCommandEncoder> encoder;
    id<MTLCommandBuffer> command_buffer;
};

static NSString *vkmtl_new_string_from_bytes(const char *bytes, size_t len) {
    if (bytes == NULL) {
        return nil;
    }
    if (memchr(bytes, '\0', len) != NULL) {
        return nil;
    }
    return [[NSString alloc]
        initWithBytes:bytes
               length:len
             encoding:NSUTF8StringEncoding];
}

static vkmtl_metal_status vkmtl_set_objc_label(
    id object,
    const char *label,
    size_t label_len,
    vkmtl_metal_status invalid_status
) {
    if (object == nil) {
        return invalid_status;
    }

    @autoreleasepool {
        NSString *label_string = vkmtl_new_string_from_bytes(label, label_len);
        if (label != NULL && label_string == nil) {
            return invalid_status;
        }

        if ([object respondsToSelector:@selector(setLabel:)]) {
            [object setLabel:label_string];
        }
        [label_string release];
        return VKMTL_METAL_STATUS_OK;
    }
}

static vkmtl_metal_status vkmtl_push_objc_debug_group(
    id object,
    const char *label,
    size_t label_len,
    vkmtl_metal_status invalid_status
) {
    if (object == nil || label == NULL || label_len == 0) {
        return invalid_status;
    }

    @autoreleasepool {
        NSString *label_string = vkmtl_new_string_from_bytes(label, label_len);
        if (label_string == nil) {
            return invalid_status;
        }

        if ([object respondsToSelector:@selector(pushDebugGroup:)]) {
            [object pushDebugGroup:label_string];
        }
        [label_string release];
        return VKMTL_METAL_STATUS_OK;
    }
}

static vkmtl_metal_status vkmtl_pop_objc_debug_group(
    id object,
    vkmtl_metal_status invalid_status
) {
    if (object == nil) {
        return invalid_status;
    }

    @autoreleasepool {
        if ([object respondsToSelector:@selector(popDebugGroup)]) {
            [object popDebugGroup];
        }
        return VKMTL_METAL_STATUS_OK;
    }
}

static vkmtl_metal_status vkmtl_insert_objc_debug_signpost(
    id object,
    const char *label,
    size_t label_len,
    vkmtl_metal_status invalid_status
) {
    if (object == nil || label == NULL || label_len == 0) {
        return invalid_status;
    }

    @autoreleasepool {
        NSString *label_string = vkmtl_new_string_from_bytes(label, label_len);
        if (label_string == nil) {
            return invalid_status;
        }

        if ([object respondsToSelector:@selector(insertDebugSignpost:)]) {
            [object insertDebugSignpost:label_string];
        }
        [label_string release];
        return VKMTL_METAL_STATUS_OK;
    }
}

static id<MTLTexture> vkmtl_new_depth_texture(
    id<MTLDevice> device,
    unsigned int width,
    unsigned int height
) {
    if (device == nil || width == 0 || height == 0) {
        return nil;
    }

    MTLTextureDescriptor *descriptor = [[MTLTextureDescriptor alloc] init];
    if (descriptor == nil) {
        return nil;
    }

    descriptor.textureType = MTLTextureType2D;
    descriptor.pixelFormat = MTLPixelFormatDepth32Float;
    descriptor.width = width;
    descriptor.height = height;
    descriptor.depth = 1;
    descriptor.arrayLength = 1;
    descriptor.mipmapLevelCount = 1;
    descriptor.sampleCount = 1;
    descriptor.storageMode = MTLStorageModePrivate;
    descriptor.usage = MTLTextureUsageRenderTarget;

    id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
    [descriptor release];
    return texture;
}

static BOOL vkmtl_device_supports_raytracing(id<MTLDevice> device) {
    if (device == nil || ![device respondsToSelector:@selector(supportsRaytracing)]) {
        return NO;
    }

    BOOL (*supports_raytracing)(id, SEL) =
        (BOOL (*)(id, SEL))[device methodForSelector:@selector(supportsRaytracing)];
    return supports_raytracing != NULL &&
        supports_raytracing(device, @selector(supportsRaytracing));
}

static id<MTLCounterSet> vkmtl_timestamp_counter_set(id<MTLDevice> device) {
    if (device == nil) {
        return nil;
    }

    if (@available(macOS 10.15, *)) {
        NSArray<id<MTLCounterSet>> *counter_sets = [device counterSets];
        for (id<MTLCounterSet> counter_set in counter_sets) {
            if (![[counter_set name] isEqualToString:MTLCommonCounterSetTimestamp]) {
                continue;
            }
            for (id<MTLCounter> counter in [counter_set counters]) {
                if ([[counter name] isEqualToString:MTLCommonCounterTimestamp]) {
                    return counter_set;
                }
            }
        }
    }
    return nil;
}

static void vkmtl_copy_timestamp_capabilities(
    id<MTLDevice> device,
    vkmtl_metal_device_capabilities *capabilities
) {
    if (device == nil || capabilities == NULL) {
        return;
    }

    if (@available(macOS 11.0, *)) {
        capabilities->timestamp_counter_set =
            vkmtl_timestamp_counter_set(device) != nil ? 1u : 0u;
        capabilities->timestamp_draw_boundary =
            [device supportsCounterSampling:MTLCounterSamplingPointAtDrawBoundary] ? 1u : 0u;
        capabilities->timestamp_dispatch_boundary =
            [device supportsCounterSampling:MTLCounterSamplingPointAtDispatchBoundary] ? 1u : 0u;
        capabilities->timestamp_blit_boundary =
            [device supportsCounterSampling:MTLCounterSamplingPointAtBlitBoundary] ? 1u : 0u;
        capabilities->timestamp_queries =
            capabilities->timestamp_counter_set != 0 &&
            capabilities->timestamp_draw_boundary != 0 &&
            capabilities->timestamp_dispatch_boundary != 0 &&
            capabilities->timestamp_blit_boundary != 0;
    }
}

static void vkmtl_fill_default_triangle(float *vertices, unsigned int primitive_count) {
    if (vertices == NULL || primitive_count == 0) {
        return;
    }

    const float base_vertices[9] = {
        -0.72f, -0.56f, 0.0f,
         0.72f, -0.56f, 0.0f,
         0.0f,   0.68f, 0.0f,
    };

    for (unsigned int i = 0; i < primitive_count; i += 1) {
        memcpy(vertices + i * 9, base_vertices, sizeof(base_vertices));
    }
}

static void vkmtl_fill_identity_instance(MTLAccelerationStructureInstanceDescriptor *instance) {
    if (instance == NULL) {
        return;
    }

    memset(instance, 0, sizeof(MTLAccelerationStructureInstanceDescriptor));
    instance->transformationMatrix.columns[0].x = 1.0f;
    instance->transformationMatrix.columns[1].y = 1.0f;
    instance->transformationMatrix.columns[2].z = 1.0f;
    instance->options = MTLAccelerationStructureInstanceOptionDisableTriangleCulling;
    instance->mask = 0xffu;
    instance->intersectionFunctionTableOffset = 0;
    instance->accelerationStructureIndex = 0;
}

static vkmtl_metal_status vkmtl_make_acceleration_structure_descriptor(
    id<MTLDevice> device,
    vkmtl_metal_acceleration_structure_kind kind,
    unsigned int primitive_count,
    MTLAccelerationStructureDescriptor **out_descriptor,
    id<MTLBuffer> *out_auxiliary_buffer
) {
    if (out_descriptor == NULL || out_auxiliary_buffer == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    *out_descriptor = nil;
    *out_auxiliary_buffer = nil;

    if (device == nil || !vkmtl_device_supports_raytracing(device) || primitive_count == 0) {
        return VKMTL_METAL_STATUS_UNSUPPORTED;
    }

    if (kind == VKMTL_METAL_ACCELERATION_STRUCTURE_KIND_BOTTOM_LEVEL) {
        const NSUInteger vertex_count = (NSUInteger)primitive_count * 3u;
        const NSUInteger vertex_buffer_len = vertex_count * 3u * sizeof(float);
        id<MTLBuffer> vertex_buffer =
            [device newBufferWithLength:vertex_buffer_len options:MTLResourceStorageModeShared];
        if (vertex_buffer == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        vkmtl_fill_default_triangle((float *)[vertex_buffer contents], primitive_count);
        if ([vertex_buffer storageMode] == MTLStorageModeManaged) {
            [vertex_buffer didModifyRange:NSMakeRange(0, vertex_buffer_len)];
        }

        MTLAccelerationStructureTriangleGeometryDescriptor *geometry =
            [MTLAccelerationStructureTriangleGeometryDescriptor descriptor];
        if (geometry == nil) {
            [vertex_buffer release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }
        geometry.vertexBuffer = vertex_buffer;
        geometry.vertexBufferOffset = 0;
        if ([geometry respondsToSelector:@selector(setVertexFormat:)]) {
            geometry.vertexFormat = MTLAttributeFormatFloat3;
        }
        geometry.vertexStride = 3u * sizeof(float);
        geometry.triangleCount = primitive_count;
        geometry.opaque = YES;

        MTLPrimitiveAccelerationStructureDescriptor *descriptor =
            [MTLPrimitiveAccelerationStructureDescriptor descriptor];
        if (descriptor == nil) {
            [vertex_buffer release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }
        descriptor.geometryDescriptors = @[geometry];
        descriptor.usage = MTLAccelerationStructureUsageNone;

        *out_descriptor = [descriptor retain];
        *out_auxiliary_buffer = vertex_buffer;
        return VKMTL_METAL_STATUS_OK;
    }

    const NSUInteger instance_buffer_len =
        (NSUInteger)primitive_count * sizeof(MTLAccelerationStructureInstanceDescriptor);
    id<MTLBuffer> instance_buffer =
        [device newBufferWithLength:instance_buffer_len options:MTLResourceStorageModeShared];
    if (instance_buffer == nil) {
        return VKMTL_METAL_STATUS_COMMAND_FAILED;
    }

    MTLAccelerationStructureInstanceDescriptor *instances =
        (MTLAccelerationStructureInstanceDescriptor *)[instance_buffer contents];
    for (unsigned int i = 0; i < primitive_count; i += 1) {
        vkmtl_fill_identity_instance(&instances[i]);
    }
    if ([instance_buffer storageMode] == MTLStorageModeManaged) {
        [instance_buffer didModifyRange:NSMakeRange(0, instance_buffer_len)];
    }

    MTLInstanceAccelerationStructureDescriptor *descriptor =
        [MTLInstanceAccelerationStructureDescriptor descriptor];
    if (descriptor == nil) {
        [instance_buffer release];
        return VKMTL_METAL_STATUS_COMMAND_FAILED;
    }
    descriptor.instanceDescriptorBuffer = instance_buffer;
    descriptor.instanceDescriptorBufferOffset = 0;
    descriptor.instanceDescriptorStride = sizeof(MTLAccelerationStructureInstanceDescriptor);
    descriptor.instanceCount = primitive_count;
    descriptor.usage = MTLAccelerationStructureUsageNone;
    if ([descriptor respondsToSelector:@selector(setInstanceDescriptorType:)]) {
        descriptor.instanceDescriptorType = MTLAccelerationStructureInstanceDescriptorTypeDefault;
    }

    *out_descriptor = [descriptor retain];
    *out_auxiliary_buffer = instance_buffer;
    return VKMTL_METAL_STATUS_OK;
}

static vkmtl_metal_status vkmtl_query_acceleration_structure_sizes(
    id<MTLDevice> device,
    vkmtl_metal_acceleration_structure_kind kind,
    unsigned int primitive_count,
    MTLAccelerationStructureSizes *out_sizes
) {
    if (out_sizes == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    memset(out_sizes, 0, sizeof(MTLAccelerationStructureSizes));

    MTLAccelerationStructureDescriptor *descriptor = nil;
    id<MTLBuffer> auxiliary_buffer = nil;
    vkmtl_metal_status status = vkmtl_make_acceleration_structure_descriptor(
        device,
        kind,
        primitive_count,
        &descriptor,
        &auxiliary_buffer
    );
    if (status != VKMTL_METAL_STATUS_OK) {
        return status;
    }

    *out_sizes = [device accelerationStructureSizesWithDescriptor:descriptor];
    [descriptor release];
    [auxiliary_buffer release];
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_probe_create(vkmtl_metal_probe **out_probe) {
    if (out_probe == NULL) {
        return VKMTL_METAL_STATUS_NO_DEVICE;
    }

    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            *out_probe = NULL;
            return VKMTL_METAL_STATUS_NO_DEVICE;
        }

        vkmtl_metal_probe *probe = calloc(1, sizeof(vkmtl_metal_probe));
        if (probe == NULL) {
            *out_probe = NULL;
            return VKMTL_METAL_STATUS_NO_DEVICE;
        }

        probe->device = [device retain];
        *out_probe = probe;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_probe_destroy(vkmtl_metal_probe *probe) {
    if (probe == NULL) {
        return;
    }

    @autoreleasepool {
        [probe->device release];
        free(probe);
    }
}

vkmtl_metal_status vkmtl_metal_probe_copy_device_name(
    const vkmtl_metal_probe *probe,
    char *buffer,
    size_t buffer_len
) {
    if (probe == NULL || probe->device == nil) {
        return VKMTL_METAL_STATUS_NO_DEVICE;
    }
    if (buffer == NULL || buffer_len == 0) {
        return VKMTL_METAL_STATUS_NAME_BUFFER_TOO_SMALL;
    }

    @autoreleasepool {
        const char *name = [[probe->device name] UTF8String];
        if (name == NULL) {
            return VKMTL_METAL_STATUS_NO_DEVICE;
        }

        const size_t name_len = strlen(name);
        if (name_len + 1 > buffer_len) {
            return VKMTL_METAL_STATUS_NAME_BUFFER_TOO_SMALL;
        }

        memcpy(buffer, name, name_len + 1);
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_clear_screen_create(
    vkmtl_metal_clear_screen **out_clear_screen,
    void *cocoa_window,
    unsigned int width,
    unsigned int height
) {
    if (out_clear_screen == NULL) {
        return VKMTL_METAL_STATUS_INVALID_SURFACE;
    }
    *out_clear_screen = NULL;

    if (cocoa_window == NULL || width == 0 || height == 0) {
        return VKMTL_METAL_STATUS_INVALID_SURFACE;
    }

    @autoreleasepool {
        NSWindow *window = (NSWindow *)cocoa_window;
        NSView *view = [window contentView];
        if (view == nil) {
            return VKMTL_METAL_STATUS_INVALID_SURFACE;
        }

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            return VKMTL_METAL_STATUS_NO_DEVICE;
        }

        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLCommandQueue> compute_queue = [device newCommandQueue];
        id<MTLCommandQueue> transfer_queue = [device newCommandQueue];
        if (queue == nil || compute_queue == nil || transfer_queue == nil) {
            [queue release];
            [compute_queue release];
            [transfer_queue release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        CAMetalLayer *layer = [CAMetalLayer layer];
        if (layer == nil) {
            [queue release];
            [compute_queue release];
            [transfer_queue release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        layer.device = device;
        layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        layer.framebufferOnly = NO;
        layer.opaque = YES;
        layer.contentsScale = [window backingScaleFactor];
        layer.drawableSize = CGSizeMake(width, height);

        [view setWantsLayer:YES];
        [view setLayer:layer];

        vkmtl_metal_clear_screen *clear_screen = calloc(1, sizeof(vkmtl_metal_clear_screen));
        if (clear_screen == NULL) {
            [queue release];
            [compute_queue release];
            [transfer_queue release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        clear_screen->device = [device retain];
        clear_screen->queue = queue;
        clear_screen->compute_queue = compute_queue;
        clear_screen->transfer_queue = transfer_queue;
        clear_screen->layer = [layer retain];
        clear_screen->view = [view retain];
        clear_screen->width = width;
        clear_screen->height = height;
        clear_screen->depth_texture = vkmtl_new_depth_texture(clear_screen->device, width, height);
        if (clear_screen->depth_texture == nil) {
            [clear_screen->view release];
            [clear_screen->layer release];
            [clear_screen->queue release];
            [clear_screen->compute_queue release];
            [clear_screen->transfer_queue release];
            [clear_screen->device release];
            free(clear_screen);
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }
        if (@available(macOS 10.13, *)) {
            id<MTLBuffer> address_probe = [device newBufferWithLength:4 options:MTLResourceStorageModePrivate];
            if (address_probe != nil &&
                [address_probe respondsToSelector:@selector(gpuAddress)] &&
                [address_probe gpuAddress] != 0) {
                clear_screen->buffer_gpu_address = 1;
            }
            [address_probe release];
        }
        *out_clear_screen = clear_screen;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_clear_screen_destroy(vkmtl_metal_clear_screen *clear_screen) {
    if (clear_screen == NULL) {
        return;
    }

    @autoreleasepool {
        if (clear_screen->view != nil && [clear_screen->view layer] == clear_screen->layer) {
            [clear_screen->view setLayer:nil];
        }
        [clear_screen->depth_texture release];
        [clear_screen->view release];
        [clear_screen->layer release];
        [clear_screen->queue release];
        [clear_screen->compute_queue release];
        [clear_screen->transfer_queue release];
        [clear_screen->device release];
        free(clear_screen);
    }
}

vkmtl_metal_status vkmtl_metal_clear_screen_resize(
    vkmtl_metal_clear_screen *clear_screen,
    unsigned int width,
    unsigned int height
) {
    if (clear_screen == NULL || clear_screen->layer == nil || width == 0 || height == 0) {
        return VKMTL_METAL_STATUS_INVALID_SURFACE;
    }

    @autoreleasepool {
        clear_screen->layer.drawableSize = CGSizeMake(width, height);
        id<MTLTexture> depth_texture =
            vkmtl_new_depth_texture(clear_screen->device, width, height);
        if (depth_texture == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }
        [clear_screen->depth_texture release];
        clear_screen->depth_texture = depth_texture;
        clear_screen->width = width;
        clear_screen->height = height;
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_clear_screen_draw(
    vkmtl_metal_clear_screen *clear_screen,
    float red,
    float green,
    float blue,
    float alpha
) {
    if (clear_screen == NULL || clear_screen->layer == nil || clear_screen->queue == nil) {
        return VKMTL_METAL_STATUS_INVALID_SURFACE;
    }

    @autoreleasepool {
        id<CAMetalDrawable> drawable = [clear_screen->layer nextDrawable];
        if (drawable == nil) {
            return VKMTL_METAL_STATUS_NO_DRAWABLE;
        }

        MTLRenderPassDescriptor *descriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        if (descriptor == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        descriptor.colorAttachments[0].texture = drawable.texture;
        descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(red, green, blue, alpha);

        id<MTLCommandBuffer> command_buffer = [clear_screen->queue commandBuffer];
        if (command_buffer == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        id<MTLRenderCommandEncoder> encoder = [command_buffer renderCommandEncoderWithDescriptor:descriptor];
        if (encoder == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        [encoder endEncoding];
        [command_buffer presentDrawable:drawable];
        [command_buffer commit];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_clear_screen_copy_device_name(
    const vkmtl_metal_clear_screen *clear_screen,
    char *buffer,
    size_t buffer_len
) {
    if (clear_screen == NULL || clear_screen->device == nil) {
        return VKMTL_METAL_STATUS_NO_DEVICE;
    }
    if (buffer == NULL || buffer_len == 0) {
        return VKMTL_METAL_STATUS_NAME_BUFFER_TOO_SMALL;
    }

    @autoreleasepool {
        const char *name = [[clear_screen->device name] UTF8String];
        if (name == NULL) {
            return VKMTL_METAL_STATUS_NO_DEVICE;
        }

        const size_t name_len = strlen(name);
        if (name_len + 1 > buffer_len) {
            return VKMTL_METAL_STATUS_NAME_BUFFER_TOO_SMALL;
        }

        memcpy(buffer, name, name_len + 1);
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_clear_screen_get_native_handles(
    const vkmtl_metal_clear_screen *clear_screen,
    vkmtl_metal_native_handles *out_handles
) {
    if (clear_screen == NULL || out_handles == NULL) {
        return VKMTL_METAL_STATUS_INVALID_SURFACE;
    }
    if (clear_screen->device == nil || clear_screen->queue == nil ||
        clear_screen->layer == nil || clear_screen->view == nil) {
        return VKMTL_METAL_STATUS_INVALID_SURFACE;
    }

    out_handles->device = (void *)clear_screen->device;
    out_handles->command_queue = (void *)clear_screen->queue;
    out_handles->layer = (void *)clear_screen->layer;
    out_handles->view = (void *)clear_screen->view;
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_clear_screen_begin_capture(
    vkmtl_metal_clear_screen *clear_screen
) {
    if (clear_screen == NULL || clear_screen->device == nil) {
        return VKMTL_METAL_STATUS_NO_DEVICE;
    }

    @autoreleasepool {
        MTLCaptureManager *manager = [MTLCaptureManager sharedCaptureManager];
        if (manager == nil || [manager isCapturing]) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        MTLCaptureDescriptor *descriptor = [[MTLCaptureDescriptor alloc] init];
        if (descriptor == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }
        descriptor.captureObject = clear_screen->device;
        descriptor.destination = MTLCaptureDestinationDeveloperTools;

        NSError *error = nil;
        BOOL started = [manager startCaptureWithDescriptor:descriptor error:&error];
        [descriptor release];
        return started ? VKMTL_METAL_STATUS_OK : VKMTL_METAL_STATUS_COMMAND_FAILED;
    }
}

vkmtl_metal_status vkmtl_metal_clear_screen_end_capture(
    vkmtl_metal_clear_screen *clear_screen
) {
    if (clear_screen == NULL || clear_screen->device == nil) {
        return VKMTL_METAL_STATUS_NO_DEVICE;
    }

    @autoreleasepool {
        MTLCaptureManager *manager = [MTLCaptureManager sharedCaptureManager];
        if (manager == nil || ![manager isCapturing]) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }
        [manager stopCapture];
        return VKMTL_METAL_STATUS_OK;
    }
}

static MTLResourceOptions vkmtl_storage_options(vkmtl_metal_storage_mode storage_mode) {
    switch (storage_mode) {
        case VKMTL_METAL_STORAGE_MODE_MANAGED:
            return MTLResourceStorageModeManaged;
        case VKMTL_METAL_STORAGE_MODE_PRIVATE:
            return MTLResourceStorageModePrivate;
        case VKMTL_METAL_STORAGE_MODE_MEMORYLESS:
            return MTLResourceStorageModeMemoryless;
        case VKMTL_METAL_STORAGE_MODE_AUTOMATIC:
        case VKMTL_METAL_STORAGE_MODE_SHARED:
        default:
            return MTLResourceStorageModeShared;
    }
}

static MTLStorageMode vkmtl_texture_storage_mode(vkmtl_metal_storage_mode storage_mode) {
    switch (storage_mode) {
        case VKMTL_METAL_STORAGE_MODE_AUTOMATIC:
        case VKMTL_METAL_STORAGE_MODE_SHARED:
            return MTLStorageModeShared;
        case VKMTL_METAL_STORAGE_MODE_MANAGED:
            return MTLStorageModeManaged;
        case VKMTL_METAL_STORAGE_MODE_PRIVATE:
            return MTLStorageModePrivate;
        case VKMTL_METAL_STORAGE_MODE_MEMORYLESS:
            return MTLStorageModeMemoryless;
        default:
            return MTLStorageModePrivate;
    }
}

static MTLStorageMode vkmtl_heap_storage_mode(unsigned int storage_mode) {
    switch (storage_mode) {
        case 2:
            return MTLStorageModeShared;
        case 0:
        case 1:
        default:
            return MTLStorageModePrivate;
    }
}

static MTLTextureType vkmtl_texture_type(
    vkmtl_metal_texture_dimension dimension,
    unsigned int depth_or_array_layers,
    unsigned int sample_count
) {
    if (sample_count > 1) {
        return MTLTextureType2DMultisample;
    }

    switch (dimension) {
        case VKMTL_METAL_TEXTURE_DIMENSION_1D:
            return depth_or_array_layers > 1 ? MTLTextureType1DArray : MTLTextureType1D;
        case VKMTL_METAL_TEXTURE_DIMENSION_2D:
            return depth_or_array_layers > 1 ? MTLTextureType2DArray : MTLTextureType2D;
        case VKMTL_METAL_TEXTURE_DIMENSION_3D:
            return MTLTextureType3D;
        default:
            return MTLTextureType2D;
    }
}

static MTLPixelFormat vkmtl_texture_pixel_format(vkmtl_metal_texture_format format) {
    switch (format) {
        case VKMTL_METAL_TEXTURE_FORMAT_R8_UNORM:
            return MTLPixelFormatR8Unorm;
        case VKMTL_METAL_TEXTURE_FORMAT_RG8_UNORM:
            return MTLPixelFormatRG8Unorm;
        case VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM:
            return MTLPixelFormatBGRA8Unorm;
        case VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM_SRGB:
            return MTLPixelFormatBGRA8Unorm_sRGB;
        case VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UNORM:
            return MTLPixelFormatRGBA8Unorm;
        case VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UNORM_SRGB:
            return MTLPixelFormatRGBA8Unorm_sRGB;
        case VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UINT:
            return MTLPixelFormatRGBA8Uint;
        case VKMTL_METAL_TEXTURE_FORMAT_RGBA8_SINT:
            return MTLPixelFormatRGBA8Sint;
        case VKMTL_METAL_TEXTURE_FORMAT_R16_FLOAT:
            return MTLPixelFormatR16Float;
        case VKMTL_METAL_TEXTURE_FORMAT_RG16_FLOAT:
            return MTLPixelFormatRG16Float;
        case VKMTL_METAL_TEXTURE_FORMAT_RGBA16_FLOAT:
            return MTLPixelFormatRGBA16Float;
        case VKMTL_METAL_TEXTURE_FORMAT_R32_FLOAT:
            return MTLPixelFormatR32Float;
        case VKMTL_METAL_TEXTURE_FORMAT_RG32_FLOAT:
            return MTLPixelFormatRG32Float;
        case VKMTL_METAL_TEXTURE_FORMAT_RGBA32_FLOAT:
            return MTLPixelFormatRGBA32Float;
        case VKMTL_METAL_TEXTURE_FORMAT_R32_UINT:
            return MTLPixelFormatR32Uint;
        case VKMTL_METAL_TEXTURE_FORMAT_R32_SINT:
            return MTLPixelFormatR32Sint;
        case VKMTL_METAL_TEXTURE_FORMAT_DEPTH16_UNORM:
            return MTLPixelFormatDepth16Unorm;
        case VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT:
            return MTLPixelFormatDepth32Float;
        case VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT_STENCIL8:
            return MTLPixelFormatDepth32Float_Stencil8;
        case VKMTL_METAL_TEXTURE_FORMAT_STENCIL8:
            return MTLPixelFormatStencil8;
        case VKMTL_METAL_TEXTURE_FORMAT_INVALID:
        default:
            return MTLPixelFormatInvalid;
    }
}

static BOOL vkmtl_texture_format_has_stencil(vkmtl_metal_texture_format format) {
    return format == VKMTL_METAL_TEXTURE_FORMAT_STENCIL8 ||
        format == VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT_STENCIL8;
}

static BOOL vkmtl_texture_format_has_depth(vkmtl_metal_texture_format format) {
    return format == VKMTL_METAL_TEXTURE_FORMAT_DEPTH16_UNORM ||
        format == VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT ||
        format == VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT_STENCIL8;
}

static MTLCompareFunction vkmtl_compare_function(vkmtl_metal_compare_function function) {
    switch (function) {
        case VKMTL_METAL_COMPARE_FUNCTION_NEVER:
            return MTLCompareFunctionNever;
        case VKMTL_METAL_COMPARE_FUNCTION_LESS:
            return MTLCompareFunctionLess;
        case VKMTL_METAL_COMPARE_FUNCTION_EQUAL:
            return MTLCompareFunctionEqual;
        case VKMTL_METAL_COMPARE_FUNCTION_LESS_EQUAL:
            return MTLCompareFunctionLessEqual;
        case VKMTL_METAL_COMPARE_FUNCTION_GREATER:
            return MTLCompareFunctionGreater;
        case VKMTL_METAL_COMPARE_FUNCTION_NOT_EQUAL:
            return MTLCompareFunctionNotEqual;
        case VKMTL_METAL_COMPARE_FUNCTION_GREATER_EQUAL:
            return MTLCompareFunctionGreaterEqual;
        case VKMTL_METAL_COMPARE_FUNCTION_ALWAYS:
        default:
            return MTLCompareFunctionAlways;
    }
}

static MTLStencilOperation vkmtl_stencil_operation(vkmtl_metal_stencil_operation operation) {
    switch (operation) {
        case VKMTL_METAL_STENCIL_OPERATION_ZERO:
            return MTLStencilOperationZero;
        case VKMTL_METAL_STENCIL_OPERATION_REPLACE:
            return MTLStencilOperationReplace;
        case VKMTL_METAL_STENCIL_OPERATION_INCREMENT_CLAMP:
            return MTLStencilOperationIncrementClamp;
        case VKMTL_METAL_STENCIL_OPERATION_DECREMENT_CLAMP:
            return MTLStencilOperationDecrementClamp;
        case VKMTL_METAL_STENCIL_OPERATION_INVERT:
            return MTLStencilOperationInvert;
        case VKMTL_METAL_STENCIL_OPERATION_INCREMENT_WRAP:
            return MTLStencilOperationIncrementWrap;
        case VKMTL_METAL_STENCIL_OPERATION_DECREMENT_WRAP:
            return MTLStencilOperationDecrementWrap;
        case VKMTL_METAL_STENCIL_OPERATION_KEEP:
        default:
            return MTLStencilOperationKeep;
    }
}

static MTLTextureType vkmtl_texture_view_type(vkmtl_metal_texture_view_dimension dimension) {
    switch (dimension) {
        case VKMTL_METAL_TEXTURE_VIEW_DIMENSION_1D:
            return MTLTextureType1D;
        case VKMTL_METAL_TEXTURE_VIEW_DIMENSION_1D_ARRAY:
            return MTLTextureType1DArray;
        case VKMTL_METAL_TEXTURE_VIEW_DIMENSION_2D:
            return MTLTextureType2D;
        case VKMTL_METAL_TEXTURE_VIEW_DIMENSION_2D_ARRAY:
            return MTLTextureType2DArray;
        case VKMTL_METAL_TEXTURE_VIEW_DIMENSION_3D:
            return MTLTextureType3D;
        default:
            return MTLTextureType2D;
    }
}

static MTLTextureSwizzle vkmtl_texture_swizzle(vkmtl_metal_texture_swizzle swizzle) {
    switch (swizzle) {
        case VKMTL_METAL_TEXTURE_SWIZZLE_ZERO:
            return MTLTextureSwizzleZero;
        case VKMTL_METAL_TEXTURE_SWIZZLE_ONE:
            return MTLTextureSwizzleOne;
        case VKMTL_METAL_TEXTURE_SWIZZLE_GREEN:
            return MTLTextureSwizzleGreen;
        case VKMTL_METAL_TEXTURE_SWIZZLE_BLUE:
            return MTLTextureSwizzleBlue;
        case VKMTL_METAL_TEXTURE_SWIZZLE_ALPHA:
            return MTLTextureSwizzleAlpha;
        case VKMTL_METAL_TEXTURE_SWIZZLE_RED:
        default:
            return MTLTextureSwizzleRed;
    }
}

static MTLSamplerMinMagFilter vkmtl_sampler_filter(vkmtl_metal_filter filter) {
    switch (filter) {
        case VKMTL_METAL_FILTER_LINEAR:
            return MTLSamplerMinMagFilterLinear;
        case VKMTL_METAL_FILTER_NEAREST:
        default:
            return MTLSamplerMinMagFilterNearest;
    }
}

static MTLSamplerMipFilter vkmtl_sampler_mip_filter(vkmtl_metal_mip_filter filter) {
    switch (filter) {
        case VKMTL_METAL_MIP_FILTER_LINEAR:
            return MTLSamplerMipFilterLinear;
        case VKMTL_METAL_MIP_FILTER_NEAREST:
            return MTLSamplerMipFilterNearest;
        case VKMTL_METAL_MIP_FILTER_NOT_MIPMAPPED:
        default:
            return MTLSamplerMipFilterNotMipmapped;
    }
}

static MTLSamplerAddressMode vkmtl_sampler_address_mode(vkmtl_metal_address_mode mode) {
    switch (mode) {
        case VKMTL_METAL_ADDRESS_MODE_CLAMP_TO_BORDER:
            return MTLSamplerAddressModeClampToBorderColor;
        case VKMTL_METAL_ADDRESS_MODE_REPEAT:
            return MTLSamplerAddressModeRepeat;
        case VKMTL_METAL_ADDRESS_MODE_MIRROR_REPEAT:
            return MTLSamplerAddressModeMirrorRepeat;
        case VKMTL_METAL_ADDRESS_MODE_CLAMP_TO_EDGE:
        default:
            return MTLSamplerAddressModeClampToEdge;
    }
}

static MTLSamplerBorderColor vkmtl_sampler_border_color(vkmtl_metal_sampler_border_color color) {
    switch (color) {
        case VKMTL_METAL_SAMPLER_BORDER_COLOR_OPAQUE_BLACK:
            return MTLSamplerBorderColorOpaqueBlack;
        case VKMTL_METAL_SAMPLER_BORDER_COLOR_OPAQUE_WHITE:
            return MTLSamplerBorderColorOpaqueWhite;
        case VKMTL_METAL_SAMPLER_BORDER_COLOR_TRANSPARENT_BLACK:
        default:
            return MTLSamplerBorderColorTransparentBlack;
    }
}

static MTLVertexFormat vkmtl_vertex_format(vkmtl_metal_vertex_format format) {
    switch (format) {
        case VKMTL_METAL_VERTEX_FORMAT_HALF2:
            return MTLVertexFormatHalf2;
        case VKMTL_METAL_VERTEX_FORMAT_HALF4:
            return MTLVertexFormatHalf4;
        case VKMTL_METAL_VERTEX_FORMAT_FLOAT:
            return MTLVertexFormatFloat;
        case VKMTL_METAL_VERTEX_FORMAT_FLOAT2:
            return MTLVertexFormatFloat2;
        case VKMTL_METAL_VERTEX_FORMAT_FLOAT3:
            return MTLVertexFormatFloat3;
        case VKMTL_METAL_VERTEX_FORMAT_FLOAT4:
            return MTLVertexFormatFloat4;
        case VKMTL_METAL_VERTEX_FORMAT_UCHAR2_NORMALIZED:
            return MTLVertexFormatUChar2Normalized;
        case VKMTL_METAL_VERTEX_FORMAT_UCHAR4_NORMALIZED:
            return MTLVertexFormatUChar4Normalized;
        case VKMTL_METAL_VERTEX_FORMAT_CHAR2_NORMALIZED:
            return MTLVertexFormatChar2Normalized;
        case VKMTL_METAL_VERTEX_FORMAT_CHAR4_NORMALIZED:
            return MTLVertexFormatChar4Normalized;
        case VKMTL_METAL_VERTEX_FORMAT_UINT:
            return MTLVertexFormatUInt;
        case VKMTL_METAL_VERTEX_FORMAT_UINT2:
            return MTLVertexFormatUInt2;
        case VKMTL_METAL_VERTEX_FORMAT_UINT3:
            return MTLVertexFormatUInt3;
        case VKMTL_METAL_VERTEX_FORMAT_UINT4:
            return MTLVertexFormatUInt4;
        case VKMTL_METAL_VERTEX_FORMAT_INT:
            return MTLVertexFormatInt;
        case VKMTL_METAL_VERTEX_FORMAT_INT2:
            return MTLVertexFormatInt2;
        case VKMTL_METAL_VERTEX_FORMAT_INT3:
            return MTLVertexFormatInt3;
        case VKMTL_METAL_VERTEX_FORMAT_INT4:
            return MTLVertexFormatInt4;
        default:
            return MTLVertexFormatInvalid;
    }
}

static MTLVertexStepFunction vkmtl_vertex_step_function(vkmtl_metal_vertex_step_function step_function) {
    switch (step_function) {
        case VKMTL_METAL_VERTEX_STEP_FUNCTION_PER_INSTANCE:
            return MTLVertexStepFunctionPerInstance;
        case VKMTL_METAL_VERTEX_STEP_FUNCTION_PER_VERTEX:
        default:
            return MTLVertexStepFunctionPerVertex;
    }
}

static MTLTriangleFillMode vkmtl_triangle_fill_mode(vkmtl_metal_triangle_fill_mode fill_mode) {
    switch (fill_mode) {
        case VKMTL_METAL_TRIANGLE_FILL_MODE_LINES:
            return MTLTriangleFillModeLines;
        case VKMTL_METAL_TRIANGLE_FILL_MODE_FILL:
        default:
            return MTLTriangleFillModeFill;
    }
}

static MTLBlendFactor vkmtl_blend_factor(vkmtl_metal_blend_factor factor) {
    switch (factor) {
        case VKMTL_METAL_BLEND_FACTOR_ZERO:
            return MTLBlendFactorZero;
        case VKMTL_METAL_BLEND_FACTOR_ONE:
            return MTLBlendFactorOne;
        case VKMTL_METAL_BLEND_FACTOR_SOURCE_COLOR:
            return MTLBlendFactorSourceColor;
        case VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_SOURCE_COLOR:
            return MTLBlendFactorOneMinusSourceColor;
        case VKMTL_METAL_BLEND_FACTOR_SOURCE_ALPHA:
            return MTLBlendFactorSourceAlpha;
        case VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_SOURCE_ALPHA:
            return MTLBlendFactorOneMinusSourceAlpha;
        case VKMTL_METAL_BLEND_FACTOR_DESTINATION_COLOR:
            return MTLBlendFactorDestinationColor;
        case VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_DESTINATION_COLOR:
            return MTLBlendFactorOneMinusDestinationColor;
        case VKMTL_METAL_BLEND_FACTOR_DESTINATION_ALPHA:
            return MTLBlendFactorDestinationAlpha;
        case VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_DESTINATION_ALPHA:
            return MTLBlendFactorOneMinusDestinationAlpha;
        case VKMTL_METAL_BLEND_FACTOR_BLEND_COLOR:
            return MTLBlendFactorBlendColor;
        case VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_BLEND_COLOR:
            return MTLBlendFactorOneMinusBlendColor;
        case VKMTL_METAL_BLEND_FACTOR_BLEND_ALPHA:
            return MTLBlendFactorBlendAlpha;
        case VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_BLEND_ALPHA:
            return MTLBlendFactorOneMinusBlendAlpha;
    }
    return MTLBlendFactorOne;
}

static MTLBlendOperation vkmtl_blend_operation(vkmtl_metal_blend_operation operation) {
    switch (operation) {
        case VKMTL_METAL_BLEND_OPERATION_ADD:
            return MTLBlendOperationAdd;
        case VKMTL_METAL_BLEND_OPERATION_SUBTRACT:
            return MTLBlendOperationSubtract;
        case VKMTL_METAL_BLEND_OPERATION_REVERSE_SUBTRACT:
            return MTLBlendOperationReverseSubtract;
        case VKMTL_METAL_BLEND_OPERATION_MIN:
            return MTLBlendOperationMin;
        case VKMTL_METAL_BLEND_OPERATION_MAX:
            return MTLBlendOperationMax;
    }
    return MTLBlendOperationAdd;
}

static MTLColorWriteMask vkmtl_color_write_mask(unsigned int mask) {
    MTLColorWriteMask out = 0;
    if ((mask & (1u << 0)) != 0) {
        out |= MTLColorWriteMaskRed;
    }
    if ((mask & (1u << 1)) != 0) {
        out |= MTLColorWriteMaskGreen;
    }
    if ((mask & (1u << 2)) != 0) {
        out |= MTLColorWriteMaskBlue;
    }
    if ((mask & (1u << 3)) != 0) {
        out |= MTLColorWriteMaskAlpha;
    }
    return out;
}

static MTLPrimitiveType vkmtl_primitive_type(unsigned int primitive_type) {
    switch (primitive_type) {
        case 1:
            return MTLPrimitiveTypeLine;
        case 2:
            return MTLPrimitiveTypePoint;
        case 0:
        default:
            return MTLPrimitiveTypeTriangle;
    }
}

static MTLTextureUsage vkmtl_texture_usage(unsigned int usage_flags) {
    if (usage_flags == 0) {
        return MTLTextureUsageShaderRead;
    }

    MTLTextureUsage usage = 0;
    if ((usage_flags & VKMTL_METAL_TEXTURE_USAGE_SHADER_READ) != 0) {
        usage |= MTLTextureUsageShaderRead;
    }
    if ((usage_flags & VKMTL_METAL_TEXTURE_USAGE_SHADER_WRITE) != 0) {
        usage |= MTLTextureUsageShaderWrite;
    }
    if ((usage_flags & VKMTL_METAL_TEXTURE_USAGE_RENDER_ATTACHMENT) != 0) {
        usage |= MTLTextureUsageRenderTarget;
    }
    if ((usage_flags & VKMTL_METAL_TEXTURE_USAGE_PIXEL_FORMAT_VIEW) != 0) {
        usage |= MTLTextureUsagePixelFormatView;
    }
    return usage;
}

static MTLTextureDescriptor *vkmtl_new_texture_descriptor(
    vkmtl_metal_texture_dimension dimension,
    vkmtl_metal_texture_format format,
    unsigned int width,
    unsigned int height,
    unsigned int depth_or_array_layers,
    unsigned int mip_level_count,
    unsigned int sample_count,
    unsigned int usage_flags,
    MTLStorageMode storage_mode
) {
    MTLTextureDescriptor *descriptor = [[MTLTextureDescriptor alloc] init];
    if (descriptor == nil) {
        return nil;
    }
    descriptor.textureType = vkmtl_texture_type(dimension, depth_or_array_layers, sample_count);
    descriptor.pixelFormat = vkmtl_texture_pixel_format(format);
    descriptor.width = width;
    descriptor.height = height;
    descriptor.depth = dimension == VKMTL_METAL_TEXTURE_DIMENSION_3D ? depth_or_array_layers : 1;
    descriptor.arrayLength = dimension == VKMTL_METAL_TEXTURE_DIMENSION_3D ? 1 : depth_or_array_layers;
    descriptor.mipmapLevelCount = mip_level_count;
    descriptor.sampleCount = sample_count;
    descriptor.storageMode = storage_mode;
    descriptor.usage = vkmtl_texture_usage(usage_flags);
    return descriptor;
}

static MTLLoadAction vkmtl_load_action(unsigned int action) {
    switch (action) {
        case 1:
            return MTLLoadActionLoad;
        case 2:
            return MTLLoadActionClear;
        default:
            return MTLLoadActionDontCare;
    }
}

static MTLStoreAction vkmtl_store_action(unsigned int action) {
    return action == 1 ? MTLStoreActionStore : MTLStoreActionDontCare;
}

vkmtl_metal_status vkmtl_metal_buffer_create(
    vkmtl_metal_clear_screen *owner,
    size_t length,
    const void *bytes,
    size_t bytes_len,
    vkmtl_metal_storage_mode storage_mode,
    vkmtl_metal_buffer **out_buffer
) {
    if (out_buffer == NULL) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }
    *out_buffer = NULL;

    if (owner == NULL || owner->device == nil || length == 0 || bytes_len > length) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }

    @autoreleasepool {
        id<MTLBuffer> metal_buffer = nil;
        MTLResourceOptions options = vkmtl_storage_options(storage_mode);

        if (bytes != NULL && bytes_len > 0) {
            metal_buffer = [owner->device newBufferWithBytes:bytes length:length options:options];
        } else {
            metal_buffer = [owner->device newBufferWithLength:length options:options];
        }

        if (metal_buffer == nil) {
            return VKMTL_METAL_STATUS_INVALID_BUFFER;
        }

        vkmtl_metal_buffer *buffer = calloc(1, sizeof(vkmtl_metal_buffer));
        if (buffer == NULL) {
            [metal_buffer release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        buffer->buffer = metal_buffer;
        buffer->queue = [owner->queue retain];
        buffer->length = length;
        buffer->storage_mode = storage_mode;
        *out_buffer = buffer;
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_clear_screen_copy_capabilities(
    const vkmtl_metal_clear_screen *clear_screen,
    vkmtl_metal_device_capabilities *out_capabilities
) {
    if (clear_screen == NULL || clear_screen->device == nil || out_capabilities == NULL) {
        return VKMTL_METAL_STATUS_NO_DEVICE;
    }

    @autoreleasepool {
        memset(out_capabilities, 0, sizeof(vkmtl_metal_device_capabilities));

        id<MTLDevice> device = clear_screen->device;
        MTLSize max_threads = [device maxThreadsPerThreadgroup];
        out_capabilities->max_threads_per_threadgroup_width = (unsigned int)max_threads.width;
        out_capabilities->max_threads_per_threadgroup_height = (unsigned int)max_threads.height;
        out_capabilities->max_threads_per_threadgroup_depth = (unsigned int)max_threads.depth;
        // These are independent per-axis ceilings, so their product is not a
        // valid threadgroup size. The exact total is pipeline-specific; before
        // a pipeline exists, report the largest guaranteed one-axis group.
        out_capabilities->max_threads_per_threadgroup_total =
            (unsigned int)MAX(max_threads.width, MAX(max_threads.height, max_threads.depth));
        if ([device respondsToSelector:@selector(maxBufferLength)]) {
            out_capabilities->max_buffer_length = [device maxBufferLength];
        }
        if ([device respondsToSelector:@selector(maxThreadgroupMemoryLength)]) {
            out_capabilities->max_threadgroup_memory_length = [device maxThreadgroupMemoryLength];
        }
        out_capabilities->buffer_gpu_address = clear_screen->buffer_gpu_address;
        if (@available(macOS 10.14, *)) {
            out_capabilities->shared_events =
                [device respondsToSelector:@selector(newSharedEvent)] ? 1u : 0u;
        }
        if (@available(macOS 10.13, *)) {
            out_capabilities->scheduled_presentation = 1u;
        }
        if (@available(macOS 10.15.4, *)) {
            out_capabilities->minimum_duration_presentation = 1u;
        }
        if (@available(macOS 10.15, *)) {
            if ([device respondsToSelector:@selector(newHeapWithDescriptor:)]) {
                MTLSizeAndAlign heap_probe_requirements =
                    [device heapBufferSizeAndAlignWithLength:4 options:MTLResourceStorageModePrivate];
                MTLHeapDescriptor *heap_probe_descriptor = [[MTLHeapDescriptor alloc] init];
                heap_probe_descriptor.type = MTLHeapTypePlacement;
                heap_probe_descriptor.storageMode = MTLStorageModePrivate;
                heap_probe_descriptor.size = heap_probe_requirements.size;
                id<MTLHeap> heap_probe = [device newHeapWithDescriptor:heap_probe_descriptor];
                id<MTLBuffer> heap_buffer_probe =
                    [heap_probe newBufferWithLength:4 options:MTLResourceStorageModePrivate offset:0];
                if (heap_probe != nil && heap_buffer_probe != nil) {
                    out_capabilities->heaps = 1u;
                }
                [heap_buffer_probe release];
                [heap_probe release];
                [heap_probe_descriptor release];
            }
        }
        if ([device respondsToSelector:@selector(recommendedMaxWorkingSetSize)] &&
            [device respondsToSelector:@selector(currentAllocatedSize)]) {
            out_capabilities->recommended_working_set_size =
                (uint64_t)device.recommendedMaxWorkingSetSize;
            out_capabilities->current_allocated_size =
                (uint64_t)device.currentAllocatedSize;
            out_capabilities->memory_budget =
                out_capabilities->recommended_working_set_size != 0 ? 1u : 0u;
        }
        if (@available(macOS 11.0, *)) {
            MTLTextureDescriptor *memoryless_probe =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                    width:1
                                                                   height:1
                                                                mipmapped:NO];
            memoryless_probe.storageMode = MTLStorageModeMemoryless;
            memoryless_probe.usage = MTLTextureUsageRenderTarget;
            id<MTLTexture> probe_texture = [device newTextureWithDescriptor:memoryless_probe];
            if (probe_texture != nil) {
                out_capabilities->memoryless_attachments = 1u;
                [probe_texture release];
            }
        }

        // Metal exposes texture limits by GPU family rather than individual
        // device properties. Start with the portable family floor and raise
        // only when the queried family guarantees the larger limit.
        out_capabilities->max_texture_dimension_1d = 8192;
        out_capabilities->max_texture_dimension_2d = 8192;
        out_capabilities->max_texture_dimension_3d = 2048;
        out_capabilities->max_texture_array_layers = 256;
        if (@available(macOS 10.15, *)) {
            if ([device supportsFamily:MTLGPUFamilyMac1] ||
                [device supportsFamily:MTLGPUFamilyApple3]) {
                out_capabilities->max_texture_dimension_1d = 16384;
                out_capabilities->max_texture_dimension_2d = 16384;
                out_capabilities->max_texture_array_layers = 2048;
            }
        }

        if ([device respondsToSelector:@selector(argumentBuffersSupport)]) {
            MTLArgumentBuffersTier tier = [device argumentBuffersSupport];
            out_capabilities->argument_buffers = 1;
            out_capabilities->argument_buffer_tier = (unsigned int)tier;
            if (tier == MTLArgumentBuffersTier2) {
                out_capabilities->max_buffer_argument_table_entries = 500000;
                out_capabilities->max_texture_argument_table_entries = 500000;
                out_capabilities->max_sampler_argument_table_entries = 1024;
            } else {
                out_capabilities->max_buffer_argument_table_entries = 31;
                out_capabilities->max_texture_argument_table_entries = 31;
                out_capabilities->max_sampler_argument_table_entries = 16;
            }
        }

        if (@available(macOS 11.0, *)) {
            MTLIndirectCommandBufferDescriptor *render_descriptor = [[MTLIndirectCommandBufferDescriptor alloc] init];
            render_descriptor.commandTypes = MTLIndirectCommandTypeDraw;
            render_descriptor.inheritPipelineState = YES;
            render_descriptor.inheritBuffers = YES;
            id<MTLIndirectCommandBuffer> render_probe = [device
                newIndirectCommandBufferWithDescriptor:render_descriptor
                                maxCommandCount:1
                                         options:0];
            MTLIndirectCommandBufferDescriptor *compute_descriptor = [[MTLIndirectCommandBufferDescriptor alloc] init];
            compute_descriptor.commandTypes = MTLIndirectCommandTypeConcurrentDispatch;
            compute_descriptor.inheritPipelineState = YES;
            compute_descriptor.inheritBuffers = YES;
            id<MTLIndirectCommandBuffer> compute_probe = [device
                newIndirectCommandBufferWithDescriptor:compute_descriptor
                                maxCommandCount:1
                                         options:0];
            if (render_probe != nil && compute_probe != nil) {
                out_capabilities->indirect_command_buffers = 1u;
            }
            [render_probe release];
            [compute_probe release];
            [render_descriptor release];
            [compute_descriptor release];
        }

        out_capabilities->ray_tracing = vkmtl_device_supports_raytracing(device) ? 1u : 0u;

        if ([device respondsToSelector:@selector(newBinaryArchiveWithDescriptor:error:)]) {
            out_capabilities->binary_archive = 1;
        }

        if (@available(macOS 10.12, *)) {
            out_capabilities->function_constants = 1;
        }
        vkmtl_copy_timestamp_capabilities(device, out_capabilities);

        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_buffer_destroy(vkmtl_metal_buffer *buffer) {
    if (buffer == NULL) {
        return;
    }

    @autoreleasepool {
        [buffer->buffer release];
        [buffer->queue release];
        free(buffer);
    }
}

size_t vkmtl_metal_buffer_length(const vkmtl_metal_buffer *buffer) {
    if (buffer == NULL) {
        return 0;
    }
    return buffer->length;
}

vkmtl_metal_status vkmtl_metal_buffer_gpu_address(
    const vkmtl_metal_buffer *buffer,
    uint64_t *out_address
) {
    if (buffer == NULL || buffer->buffer == nil || out_address == NULL) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }
    *out_address = 0;
    if (@available(macOS 10.13, *)) {
        if (![buffer->buffer respondsToSelector:@selector(gpuAddress)]) {
            return VKMTL_METAL_STATUS_UNSUPPORTED;
        }
        *out_address = (uint64_t)[buffer->buffer gpuAddress];
        return *out_address == 0 ? VKMTL_METAL_STATUS_UNSUPPORTED : VKMTL_METAL_STATUS_OK;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_buffer_set_label(
    vkmtl_metal_buffer *buffer,
    const char *label,
    size_t label_len
) {
    if (buffer == NULL) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }
    return vkmtl_set_objc_label(
        buffer->buffer,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_BUFFER
    );
}

vkmtl_metal_status vkmtl_metal_buffer_contents(
    vkmtl_metal_buffer *buffer,
    void **out_contents
) {
    if (out_contents == NULL) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }
    *out_contents = NULL;

    if (buffer == NULL ||
        buffer->buffer == nil ||
        buffer->storage_mode == VKMTL_METAL_STORAGE_MODE_PRIVATE) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }

    @autoreleasepool {
        if (buffer->storage_mode == VKMTL_METAL_STORAGE_MODE_MANAGED) {
            if (buffer->queue == nil) {
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
            id<MTLCommandBuffer> command_buffer = [buffer->queue commandBuffer];
            id<MTLBlitCommandEncoder> encoder = [command_buffer blitCommandEncoder];
            if (command_buffer == nil || encoder == nil) {
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
            [encoder synchronizeResource:buffer->buffer];
            [encoder endEncoding];
            [command_buffer commit];
            [command_buffer waitUntilCompleted];
            if ([command_buffer status] == MTLCommandBufferStatusError) {
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
        }

        void *contents = [buffer->buffer contents];
        if (contents == NULL) {
            return VKMTL_METAL_STATUS_INVALID_BUFFER;
        }
        *out_contents = contents;
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_buffer_did_modify_range(
    vkmtl_metal_buffer *buffer,
    size_t offset,
    size_t length
) {
    if (buffer == NULL ||
        buffer->buffer == nil ||
        length == 0 ||
        offset > buffer->length ||
        length > buffer->length - offset ||
        buffer->storage_mode == VKMTL_METAL_STORAGE_MODE_PRIVATE) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }

    @autoreleasepool {
        if (buffer->storage_mode == VKMTL_METAL_STORAGE_MODE_MANAGED) {
            [buffer->buffer didModifyRange:NSMakeRange(offset, length)];
        }
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_buffer_replace_bytes(
    vkmtl_metal_buffer *buffer,
    size_t offset,
    const void *bytes,
    size_t bytes_len
) {
    if (buffer == NULL ||
        buffer->buffer == nil ||
        bytes == NULL ||
        bytes_len == 0 ||
        offset > buffer->length ||
        bytes_len > buffer->length - offset ||
        buffer->storage_mode == VKMTL_METAL_STORAGE_MODE_PRIVATE) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }

    @autoreleasepool {
        void *contents = [buffer->buffer contents];
        if (contents == NULL) {
            return VKMTL_METAL_STATUS_INVALID_BUFFER;
        }

        memcpy((unsigned char *)contents + offset, bytes, bytes_len);
        if (buffer->storage_mode == VKMTL_METAL_STORAGE_MODE_MANAGED) {
            [buffer->buffer didModifyRange:NSMakeRange(offset, bytes_len)];
        }
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_buffer_read_bytes(
    vkmtl_metal_buffer *buffer,
    size_t offset,
    void *destination,
    size_t destination_len
) {
    if (buffer == NULL ||
        buffer->buffer == nil ||
        destination == NULL ||
        destination_len == 0 ||
        offset > buffer->length ||
        destination_len > buffer->length - offset ||
        buffer->storage_mode == VKMTL_METAL_STORAGE_MODE_PRIVATE) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }

    @autoreleasepool {
        if (buffer->storage_mode == VKMTL_METAL_STORAGE_MODE_MANAGED) {
            if (buffer->queue == nil) {
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
            id<MTLCommandBuffer> command_buffer = [buffer->queue commandBuffer];
            id<MTLBlitCommandEncoder> encoder = [command_buffer blitCommandEncoder];
            if (command_buffer == nil || encoder == nil) {
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
            [encoder synchronizeResource:buffer->buffer];
            [encoder endEncoding];
            [command_buffer commit];
            [command_buffer waitUntilCompleted];
            if ([command_buffer status] == MTLCommandBufferStatusError) {
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
        }

        void *contents = [buffer->buffer contents];
        if (contents == NULL) {
            return VKMTL_METAL_STATUS_INVALID_BUFFER;
        }

        memcpy(destination, (const unsigned char *)contents + offset, destination_len);
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_heap_create(
    vkmtl_metal_clear_screen *owner,
    uint64_t size,
    unsigned int storage_mode,
    vkmtl_metal_heap **out_heap
) {
    if (owner == NULL || owner->device == nil || size == 0 || out_heap == NULL) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }
    *out_heap = NULL;
    if (@available(macOS 10.15, *)) {
        @autoreleasepool {
            MTLHeapDescriptor *descriptor = [[MTLHeapDescriptor alloc] init];
            if (descriptor == nil) return VKMTL_METAL_STATUS_COMMAND_FAILED;
            descriptor.size = (NSUInteger)size;
            descriptor.storageMode = vkmtl_heap_storage_mode(storage_mode);
            descriptor.type = MTLHeapTypePlacement;
            id<MTLHeap> native_heap = [owner->device newHeapWithDescriptor:descriptor];
            [descriptor release];
            if (native_heap == nil) return VKMTL_METAL_STATUS_UNSUPPORTED;

            vkmtl_metal_heap *heap = calloc(1, sizeof(vkmtl_metal_heap));
            if (heap == NULL) {
                [native_heap release];
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
            heap->device = [owner->device retain];
            heap->heap = native_heap;
            heap->queue = [owner->queue retain];
            heap->storage_mode = vkmtl_heap_storage_mode(storage_mode);
            *out_heap = heap;
            return VKMTL_METAL_STATUS_OK;
        }
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_heap_destroy(vkmtl_metal_heap *heap) {
    if (heap == NULL) return;
    @autoreleasepool {
        [heap->queue release];
        [heap->heap release];
        [heap->device release];
        free(heap);
    }
}

vkmtl_metal_status vkmtl_metal_heap_buffer_size_and_align(
    const vkmtl_metal_heap *heap,
    size_t length,
    uint64_t *out_size,
    uint64_t *out_alignment
) {
    if (heap == NULL || heap->device == nil || length == 0 ||
        out_size == NULL || out_alignment == NULL) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }
    MTLResourceOptions options = heap->storage_mode == MTLStorageModeShared
        ? MTLResourceStorageModeShared
        : MTLResourceStorageModePrivate;
    MTLSizeAndAlign requirements = [heap->device heapBufferSizeAndAlignWithLength:length options:options];
    if (requirements.size == 0 || requirements.align == 0) {
        return VKMTL_METAL_STATUS_UNSUPPORTED;
    }
    *out_size = (uint64_t)requirements.size;
    *out_alignment = (uint64_t)requirements.align;
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_heap_texture_size_and_align(
    const vkmtl_metal_heap *heap,
    vkmtl_metal_texture_dimension dimension,
    vkmtl_metal_texture_format format,
    unsigned int width,
    unsigned int height,
    unsigned int depth_or_array_layers,
    unsigned int mip_level_count,
    unsigned int sample_count,
    unsigned int usage_flags,
    uint64_t *out_size,
    uint64_t *out_alignment
) {
    if (heap == NULL || heap->device == nil || format == VKMTL_METAL_TEXTURE_FORMAT_INVALID ||
        out_size == NULL || out_alignment == NULL) {
        return VKMTL_METAL_STATUS_INVALID_TEXTURE;
    }
    @autoreleasepool {
        MTLTextureDescriptor *descriptor = vkmtl_new_texture_descriptor(
            dimension, format, width, height, depth_or_array_layers,
            mip_level_count, sample_count, usage_flags, heap->storage_mode
        );
        if (descriptor == nil) return VKMTL_METAL_STATUS_COMMAND_FAILED;
        MTLSizeAndAlign requirements = [heap->device heapTextureSizeAndAlignWithDescriptor:descriptor];
        [descriptor release];
        if (requirements.size == 0 || requirements.align == 0) {
            return VKMTL_METAL_STATUS_UNSUPPORTED;
        }
        *out_size = (uint64_t)requirements.size;
        *out_alignment = (uint64_t)requirements.align;
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_heap_buffer_create(
    vkmtl_metal_heap *heap,
    size_t length,
    const void *bytes,
    size_t bytes_len,
    uint64_t offset,
    vkmtl_metal_buffer **out_buffer
) {
    if (heap == NULL || heap->heap == nil || length == 0 || bytes_len > length || out_buffer == NULL) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }
    *out_buffer = NULL;
    if (bytes_len != 0 && (bytes == NULL || heap->storage_mode != MTLStorageModeShared)) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }
    if (@available(macOS 10.15, *)) {
        @autoreleasepool {
            MTLResourceOptions options = heap->storage_mode == MTLStorageModeShared
                ? MTLResourceStorageModeShared
                : MTLResourceStorageModePrivate;
            id<MTLBuffer> native_buffer = [heap->heap newBufferWithLength:length options:options offset:(NSUInteger)offset];
            if (native_buffer == nil) return VKMTL_METAL_STATUS_INVALID_BUFFER;
            if (bytes_len != 0) memcpy([native_buffer contents], bytes, bytes_len);

            vkmtl_metal_buffer *buffer = calloc(1, sizeof(vkmtl_metal_buffer));
            if (buffer == NULL) {
                [native_buffer release];
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
            buffer->buffer = native_buffer;
            buffer->queue = [heap->queue retain];
            buffer->length = length;
            buffer->storage_mode = heap->storage_mode == MTLStorageModeShared
                ? VKMTL_METAL_STORAGE_MODE_SHARED
                : VKMTL_METAL_STORAGE_MODE_PRIVATE;
            *out_buffer = buffer;
            return VKMTL_METAL_STATUS_OK;
        }
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_heap_texture_create(
    vkmtl_metal_heap *heap,
    vkmtl_metal_texture_dimension dimension,
    vkmtl_metal_texture_format format,
    unsigned int width,
    unsigned int height,
    unsigned int depth_or_array_layers,
    unsigned int mip_level_count,
    unsigned int sample_count,
    unsigned int usage_flags,
    uint64_t offset,
    vkmtl_metal_texture **out_texture
) {
    if (heap == NULL || heap->heap == nil || out_texture == NULL ||
        format == VKMTL_METAL_TEXTURE_FORMAT_INVALID) {
        return VKMTL_METAL_STATUS_INVALID_TEXTURE;
    }
    *out_texture = NULL;
    if (@available(macOS 10.15, *)) {
        @autoreleasepool {
            MTLTextureDescriptor *descriptor = vkmtl_new_texture_descriptor(
                dimension, format, width, height, depth_or_array_layers,
                mip_level_count, sample_count, usage_flags, heap->storage_mode
            );
            if (descriptor == nil) return VKMTL_METAL_STATUS_COMMAND_FAILED;
            id<MTLTexture> native_texture = [heap->heap newTextureWithDescriptor:descriptor offset:(NSUInteger)offset];
            [descriptor release];
            if (native_texture == nil) return VKMTL_METAL_STATUS_INVALID_TEXTURE;

            vkmtl_metal_texture *texture = calloc(1, sizeof(vkmtl_metal_texture));
            if (texture == NULL) {
                [native_texture release];
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
            texture->texture = native_texture;
            texture->width = width;
            texture->height = height;
            texture->depth_or_array_layers = depth_or_array_layers;
            texture->mip_level_count = mip_level_count;
            texture->sample_count = sample_count;
            *out_texture = texture;
            return VKMTL_METAL_STATUS_OK;
        }
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_texture_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_texture_dimension dimension,
    vkmtl_metal_texture_format format,
    unsigned int width,
    unsigned int height,
    unsigned int depth_or_array_layers,
    unsigned int mip_level_count,
    unsigned int sample_count,
    unsigned int usage_flags,
    vkmtl_metal_storage_mode storage_mode,
    vkmtl_metal_texture **out_texture
) {
    if (out_texture == NULL) {
        return VKMTL_METAL_STATUS_INVALID_TEXTURE;
    }
    *out_texture = NULL;

    if (owner == NULL ||
        owner->device == nil ||
        width == 0 ||
        height == 0 ||
        depth_or_array_layers == 0 ||
        mip_level_count == 0 ||
        sample_count == 0 ||
        format == VKMTL_METAL_TEXTURE_FORMAT_INVALID) {
        return VKMTL_METAL_STATUS_INVALID_TEXTURE;
    }
    if (sample_count != 1 &&
        (dimension != VKMTL_METAL_TEXTURE_DIMENSION_2D ||
         depth_or_array_layers != 1 ||
         mip_level_count != 1 ||
         (usage_flags & VKMTL_METAL_TEXTURE_USAGE_RENDER_ATTACHMENT) == 0)) {
        return VKMTL_METAL_STATUS_INVALID_TEXTURE;
    }
    if (![owner->device supportsTextureSampleCount:sample_count]) {
        return VKMTL_METAL_STATUS_INVALID_TEXTURE;
    }

    @autoreleasepool {
        MTLStorageMode resolved_storage_mode = vkmtl_texture_storage_mode(storage_mode);
        if (sample_count > 1 && storage_mode != VKMTL_METAL_STORAGE_MODE_MEMORYLESS) {
            resolved_storage_mode = MTLStorageModePrivate;
        }
        MTLTextureDescriptor *descriptor = vkmtl_new_texture_descriptor(
            dimension,
            format,
            width,
            height,
            depth_or_array_layers,
            mip_level_count,
            sample_count,
            usage_flags,
            resolved_storage_mode
        );
        if (descriptor == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        id<MTLTexture> metal_texture = [owner->device newTextureWithDescriptor:descriptor];
        [descriptor release];
        if (metal_texture == nil) {
            return VKMTL_METAL_STATUS_INVALID_TEXTURE;
        }

        vkmtl_metal_texture *texture = calloc(1, sizeof(vkmtl_metal_texture));
        if (texture == NULL) {
            [metal_texture release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        texture->texture = metal_texture;
        texture->width = width;
        texture->height = height;
        texture->depth_or_array_layers = depth_or_array_layers;
        texture->mip_level_count = mip_level_count;
        texture->sample_count = sample_count;
        *out_texture = texture;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_texture_destroy(vkmtl_metal_texture *texture) {
    if (texture == NULL) {
        return;
    }

    @autoreleasepool {
        [texture->texture release];
        free(texture);
    }
}

unsigned int vkmtl_metal_texture_width(const vkmtl_metal_texture *texture) {
    if (texture == NULL) {
        return 0;
    }
    return texture->width;
}

unsigned int vkmtl_metal_texture_height(const vkmtl_metal_texture *texture) {
    if (texture == NULL) {
        return 0;
    }
    return texture->height;
}

unsigned int vkmtl_metal_texture_depth_or_array_layers(const vkmtl_metal_texture *texture) {
    if (texture == NULL) {
        return 0;
    }
    return texture->depth_or_array_layers;
}

unsigned int vkmtl_metal_texture_mip_level_count(const vkmtl_metal_texture *texture) {
    if (texture == NULL) {
        return 0;
    }
    return texture->mip_level_count;
}

vkmtl_metal_status vkmtl_metal_texture_set_label(
    vkmtl_metal_texture *texture,
    const char *label,
    size_t label_len
) {
    if (texture == NULL) {
        return VKMTL_METAL_STATUS_INVALID_TEXTURE;
    }
    return vkmtl_set_objc_label(
        texture->texture,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_TEXTURE
    );
}

vkmtl_metal_status vkmtl_metal_texture_replace_region(
    vkmtl_metal_texture *texture,
    unsigned int x,
    unsigned int y,
    unsigned int z,
    unsigned int width,
    unsigned int height,
    unsigned int depth,
    unsigned int mip_level,
    unsigned int slice,
    const void *bytes,
    size_t bytes_len,
    size_t bytes_per_row,
    size_t bytes_per_image
) {
    if (texture == NULL ||
        texture->texture == nil ||
        width == 0 ||
        height == 0 ||
        depth == 0 ||
        bytes == NULL ||
        bytes_len == 0 ||
        bytes_per_row == 0 ||
        bytes_per_image == 0) {
        return VKMTL_METAL_STATUS_INVALID_TEXTURE;
    }

    @autoreleasepool {
        MTLRegion region = MTLRegionMake3D(x, y, z, width, height, depth);
        [texture->texture
            replaceRegion:region
            mipmapLevel:mip_level
            slice:slice
            withBytes:bytes
            bytesPerRow:bytes_per_row
            bytesPerImage:bytes_per_image];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_texture_view_create(
    vkmtl_metal_texture *texture,
    vkmtl_metal_texture_view_dimension dimension,
    vkmtl_metal_texture_format format,
    unsigned int base_mip_level,
    unsigned int mip_level_count,
    unsigned int base_array_layer,
    unsigned int array_layer_count,
    vkmtl_metal_texture_swizzle swizzle_red,
    vkmtl_metal_texture_swizzle swizzle_green,
    vkmtl_metal_texture_swizzle swizzle_blue,
    vkmtl_metal_texture_swizzle swizzle_alpha,
    vkmtl_metal_texture_view **out_view
) {
    if (out_view == NULL) {
        return VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW;
    }
    *out_view = NULL;

    if (texture == NULL ||
        texture->texture == nil ||
        format == VKMTL_METAL_TEXTURE_FORMAT_INVALID ||
        mip_level_count == 0 ||
        array_layer_count == 0) {
        return VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW;
    }

    @autoreleasepool {
        id<MTLTexture> view_texture = nil;
        if (texture->sample_count > 1) {
            if (base_mip_level != 0 ||
                mip_level_count != 1 ||
                base_array_layer != 0 ||
                array_layer_count != 1 ||
                dimension != VKMTL_METAL_TEXTURE_VIEW_DIMENSION_2D) {
                return VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW;
            }
            view_texture = [texture->texture retain];
        } else {
            BOOL identity_swizzle =
                swizzle_red == VKMTL_METAL_TEXTURE_SWIZZLE_RED &&
                swizzle_green == VKMTL_METAL_TEXTURE_SWIZZLE_GREEN &&
                swizzle_blue == VKMTL_METAL_TEXTURE_SWIZZLE_BLUE &&
                swizzle_alpha == VKMTL_METAL_TEXTURE_SWIZZLE_ALPHA;
            if (identity_swizzle) {
                view_texture = [texture->texture
                    newTextureViewWithPixelFormat:vkmtl_texture_pixel_format(format)
                    textureType:vkmtl_texture_view_type(dimension)
                    levels:NSMakeRange(base_mip_level, mip_level_count)
                    slices:NSMakeRange(base_array_layer, array_layer_count)];
            } else if (@available(macOS 10.15, *)) {
                MTLTextureSwizzleChannels swizzle = MTLTextureSwizzleChannelsMake(
                    vkmtl_texture_swizzle(swizzle_red),
                    vkmtl_texture_swizzle(swizzle_green),
                    vkmtl_texture_swizzle(swizzle_blue),
                    vkmtl_texture_swizzle(swizzle_alpha));
                view_texture = [texture->texture
                    newTextureViewWithPixelFormat:vkmtl_texture_pixel_format(format)
                    textureType:vkmtl_texture_view_type(dimension)
                    levels:NSMakeRange(base_mip_level, mip_level_count)
                    slices:NSMakeRange(base_array_layer, array_layer_count)
                    swizzle:swizzle];
            } else {
                return VKMTL_METAL_STATUS_UNSUPPORTED;
            }
        }
        if (view_texture == nil) {
            return VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW;
        }

        vkmtl_metal_texture_view *view = calloc(1, sizeof(vkmtl_metal_texture_view));
        if (view == NULL) {
            [view_texture release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        view->texture = view_texture;
        view->sample_count = texture->sample_count;
        *out_view = view;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_texture_view_destroy(vkmtl_metal_texture_view *view) {
    if (view == NULL) {
        return;
    }

    @autoreleasepool {
        [view->texture release];
        free(view);
    }
}

vkmtl_metal_status vkmtl_metal_texture_view_set_label(
    vkmtl_metal_texture_view *view,
    const char *label,
    size_t label_len
) {
    if (view == NULL) {
        return VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW;
    }
    return vkmtl_set_objc_label(
        view->texture,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW
    );
}

vkmtl_metal_status vkmtl_metal_sampler_state_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_filter min_filter,
    vkmtl_metal_filter mag_filter,
    vkmtl_metal_mip_filter mip_filter,
    vkmtl_metal_address_mode address_mode_u,
    vkmtl_metal_address_mode address_mode_v,
    vkmtl_metal_address_mode address_mode_w,
    float lod_min_clamp,
    float lod_max_clamp,
    unsigned int compare_enabled,
    vkmtl_metal_compare_function compare_function,
    float max_anisotropy,
    vkmtl_metal_sampler_border_color border_color,
    unsigned int normalized_coordinates,
    vkmtl_metal_sampler_state **out_sampler
) {
    if (out_sampler == NULL) {
        return VKMTL_METAL_STATUS_INVALID_SAMPLER;
    }
    *out_sampler = NULL;

    if (owner == NULL || owner->device == nil || lod_min_clamp > lod_max_clamp) {
        return VKMTL_METAL_STATUS_INVALID_SAMPLER;
    }

    @autoreleasepool {
        MTLSamplerDescriptor *descriptor = [[MTLSamplerDescriptor alloc] init];
        if (descriptor == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        descriptor.minFilter = vkmtl_sampler_filter(min_filter);
        descriptor.magFilter = vkmtl_sampler_filter(mag_filter);
        descriptor.mipFilter = vkmtl_sampler_mip_filter(mip_filter);
        descriptor.sAddressMode = vkmtl_sampler_address_mode(address_mode_u);
        descriptor.tAddressMode = vkmtl_sampler_address_mode(address_mode_v);
        descriptor.rAddressMode = vkmtl_sampler_address_mode(address_mode_w);
        descriptor.lodMinClamp = lod_min_clamp;
        descriptor.lodMaxClamp = lod_max_clamp;
        descriptor.borderColor = vkmtl_sampler_border_color(border_color);
        descriptor.normalizedCoordinates = normalized_coordinates != 0;
        if (compare_enabled != 0) {
            descriptor.compareFunction = vkmtl_compare_function(compare_function);
        }
        descriptor.maxAnisotropy = (NSUInteger)fmaxf(1.0f, floorf(max_anisotropy));

        id<MTLSamplerState> metal_sampler = [owner->device newSamplerStateWithDescriptor:descriptor];
        [descriptor release];
        if (metal_sampler == nil) {
            return VKMTL_METAL_STATUS_INVALID_SAMPLER;
        }

        vkmtl_metal_sampler_state *sampler = calloc(1, sizeof(vkmtl_metal_sampler_state));
        if (sampler == NULL) {
            [metal_sampler release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        sampler->sampler = metal_sampler;
        *out_sampler = sampler;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_sampler_state_destroy(vkmtl_metal_sampler_state *sampler) {
    if (sampler == NULL) {
        return;
    }

    @autoreleasepool {
        [sampler->sampler release];
        free(sampler);
    }
}

vkmtl_metal_status vkmtl_metal_sampler_state_set_label(
    vkmtl_metal_sampler_state *sampler,
    const char *label,
    size_t label_len
) {
    if (sampler == NULL) {
        return VKMTL_METAL_STATUS_INVALID_SAMPLER;
    }
    return vkmtl_set_objc_label(
        sampler->sampler,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_SAMPLER
    );
}

vkmtl_metal_status vkmtl_metal_resource_table_create(
    vkmtl_metal_clear_screen *owner,
    const vkmtl_metal_resource_table_range *ranges,
    size_t range_count,
    vkmtl_metal_resource_table **out_table
) {
    if (out_table == NULL) return VKMTL_METAL_STATUS_INVALID_BUFFER;
    *out_table = NULL;
    if (owner == NULL || owner->device == nil || ranges == NULL || range_count == 0) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }

    @autoreleasepool {
        NSMutableArray<MTLArgumentDescriptor *> *arguments = [[NSMutableArray alloc] initWithCapacity:range_count];
        NSUInteger resource_count = 0;
        for (size_t i = 0; i < range_count; ++i) {
            const vkmtl_metal_resource_table_range range = ranges[i];
            if (range.descriptor_count == 0) {
                [arguments release];
                return VKMTL_METAL_STATUS_INVALID_BUFFER;
            }
            MTLArgumentDescriptor *descriptor = [[MTLArgumentDescriptor alloc] init];
            descriptor.index = range.binding;
            descriptor.arrayLength = range.descriptor_count;
            descriptor.access = range.writable ? MTLArgumentAccessReadWrite : MTLArgumentAccessReadOnly;
            switch (range.resource_kind) {
                case 0:
                case 1:
                    descriptor.dataType = MTLDataTypePointer;
                    break;
                case 2:
                case 3:
                    descriptor.dataType = MTLDataTypeTexture;
                    descriptor.textureType = MTLTextureType2D;
                    break;
                case 4:
                case 5:
                    descriptor.dataType = MTLDataTypeSampler;
                    break;
                default:
                    [descriptor release];
                    [arguments release];
                    return VKMTL_METAL_STATUS_INVALID_BUFFER;
            }
            [arguments addObject:descriptor];
            [descriptor release];
            const NSUInteger end = (NSUInteger)range.binding + (NSUInteger)range.descriptor_count;
            if (end > resource_count) resource_count = end;
        }

        id<MTLArgumentEncoder> encoder = [owner->device newArgumentEncoderWithArguments:arguments];
        [arguments release];
        if (encoder == nil || encoder.encodedLength == 0) {
            [encoder release];
            return VKMTL_METAL_STATUS_UNSUPPORTED;
        }
        id<MTLBuffer> buffer = [owner->device newBufferWithLength:encoder.encodedLength options:MTLResourceStorageModeShared];
        if (buffer == nil) {
            [encoder release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }
        [encoder setArgumentBuffer:buffer offset:0];

        vkmtl_metal_resource_table *table = calloc(1, sizeof(*table));
        if (table == NULL) {
            [buffer release];
            [encoder release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }
        table->resources = calloc(resource_count, sizeof(*table->resources));
        table->usages = calloc(resource_count, sizeof(*table->usages));
        if (table->resources == NULL || table->usages == NULL) {
            free(table->resources);
            free(table->usages);
            free(table);
            [buffer release];
            [encoder release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }
        table->encoder = encoder;
        table->buffer = buffer;
        table->resource_count = resource_count;
        *out_table = table;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_resource_table_destroy(vkmtl_metal_resource_table *table) {
    if (table == NULL) return;
    [table->buffer release];
    [table->encoder release];
    free(table->resources);
    free(table->usages);
    free(table);
}

vkmtl_metal_status vkmtl_metal_resource_table_set_label(
    vkmtl_metal_resource_table *table,
    const char *label,
    size_t label_len
) {
    if (table == NULL) return VKMTL_METAL_STATUS_INVALID_BUFFER;
    return vkmtl_set_objc_label(table->buffer, label, label_len, VKMTL_METAL_STATUS_INVALID_BUFFER);
}

vkmtl_metal_status vkmtl_metal_resource_table_set_buffer(
    vkmtl_metal_resource_table *table,
    unsigned int index,
    vkmtl_metal_buffer *buffer,
    size_t offset,
    unsigned int writable
) {
    if (table == NULL || buffer == NULL || buffer->buffer == nil || index >= table->resource_count || offset > buffer->length) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }
    [table->encoder setBuffer:buffer->buffer offset:offset atIndex:index];
    table->resources[index] = buffer->buffer;
    table->usages[index] = MTLResourceUsageRead | (writable ? MTLResourceUsageWrite : 0);
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_resource_table_set_texture(
    vkmtl_metal_resource_table *table,
    unsigned int index,
    vkmtl_metal_texture_view *view,
    unsigned int writable
) {
    if (table == NULL || view == NULL || view->texture == nil || index >= table->resource_count) {
        return VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW;
    }
    [table->encoder setTexture:view->texture atIndex:index];
    table->resources[index] = view->texture;
    table->usages[index] = MTLResourceUsageRead | (writable ? MTLResourceUsageWrite : 0);
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_resource_table_set_sampler(
    vkmtl_metal_resource_table *table,
    unsigned int index,
    vkmtl_metal_sampler_state *sampler
) {
    if (table == NULL || sampler == NULL || sampler->sampler == nil || index >= table->resource_count) {
        return VKMTL_METAL_STATUS_INVALID_SAMPLER;
    }
    [table->encoder setSamplerState:sampler->sampler atIndex:index];
    table->resources[index] = nil;
    table->usages[index] = 0;
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_resource_table_clear(
    vkmtl_metal_resource_table *table,
    unsigned int index,
    unsigned int resource_kind
) {
    if (table == NULL || index >= table->resource_count) return VKMTL_METAL_STATUS_INVALID_BUFFER;
    switch (resource_kind) {
        case 0:
        case 1:
            [table->encoder setBuffer:nil offset:0 atIndex:index];
            break;
        case 2:
        case 3:
            [table->encoder setTexture:nil atIndex:index];
            break;
        case 4:
        case 5:
            [table->encoder setSamplerState:nil atIndex:index];
            break;
        default:
            return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }
    table->resources[index] = nil;
    table->usages[index] = 0;
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_indirect_command_buffer_create(
    vkmtl_metal_clear_screen *owner,
    unsigned int kind,
    unsigned int max_command_count,
    vkmtl_metal_indirect_command_buffer **out_buffer
) {
    if (out_buffer == NULL) return VKMTL_METAL_STATUS_INVALID_COMMAND;
    *out_buffer = NULL;
    if (owner == NULL || owner->device == nil || kind > 1 || max_command_count == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    if (@available(macOS 11.0, *)) {
        MTLIndirectCommandBufferDescriptor *descriptor = [[MTLIndirectCommandBufferDescriptor alloc] init];
        descriptor.commandTypes = kind == 0 ? MTLIndirectCommandTypeDraw : MTLIndirectCommandTypeConcurrentDispatch;
        descriptor.inheritPipelineState = YES;
        descriptor.inheritBuffers = YES;
        id<MTLIndirectCommandBuffer> native = [owner->device
            newIndirectCommandBufferWithDescriptor:descriptor
                            maxCommandCount:max_command_count
                                     options:0];
        [descriptor release];
        if (native == nil) return VKMTL_METAL_STATUS_UNSUPPORTED;
        vkmtl_metal_indirect_command_buffer *buffer = calloc(1, sizeof(*buffer));
        if (buffer == NULL) {
            [native release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }
        buffer->buffer = native;
        buffer->kind = kind;
        buffer->max_command_count = max_command_count;
        *out_buffer = buffer;
        return VKMTL_METAL_STATUS_OK;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_indirect_command_buffer_destroy(vkmtl_metal_indirect_command_buffer *buffer) {
    if (buffer == NULL) return;
    [buffer->buffer release];
    free(buffer);
}

vkmtl_metal_status vkmtl_metal_indirect_command_buffer_set_label(
    vkmtl_metal_indirect_command_buffer *buffer,
    const char *label,
    size_t label_len
) {
    if (buffer == NULL) return VKMTL_METAL_STATUS_INVALID_COMMAND;
    return vkmtl_set_objc_label(buffer->buffer, label, label_len, VKMTL_METAL_STATUS_INVALID_COMMAND);
}

vkmtl_metal_status vkmtl_metal_indirect_command_buffer_reset(
    vkmtl_metal_indirect_command_buffer *buffer,
    unsigned int location,
    unsigned int count
) {
    if (buffer == NULL || count == 0 || (NSUInteger)location + count > buffer->max_command_count) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    [buffer->buffer resetWithRange:NSMakeRange(location, count)];
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_indirect_command_buffer_encode_draw(
    vkmtl_metal_indirect_command_buffer *buffer,
    unsigned int command_index,
    unsigned int primitive_type,
    unsigned int vertex_start,
    unsigned int vertex_count,
    unsigned int instance_count,
    unsigned int base_instance
) {
    if (buffer == NULL || buffer->kind != 0 || command_index >= buffer->max_command_count || vertex_count == 0 || instance_count == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    id<MTLIndirectRenderCommand> command = [buffer->buffer indirectRenderCommandAtIndex:command_index];
    MTLPrimitiveType native_type = primitive_type == 0 ? MTLPrimitiveTypeTriangle :
        (primitive_type == 1 ? MTLPrimitiveTypeLine : MTLPrimitiveTypePoint);
    [command drawPrimitives:native_type
                vertexStart:vertex_start
                vertexCount:vertex_count
              instanceCount:instance_count
               baseInstance:base_instance];
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_indirect_command_buffer_encode_dispatch(
    vkmtl_metal_indirect_command_buffer *buffer,
    unsigned int command_index,
    unsigned int threadgroup_count_x,
    unsigned int threadgroup_count_y,
    unsigned int threadgroup_count_z,
    unsigned int threads_per_threadgroup_x,
    unsigned int threads_per_threadgroup_y,
    unsigned int threads_per_threadgroup_z
) {
    if (buffer == NULL || buffer->kind != 1 || command_index >= buffer->max_command_count) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    id<MTLIndirectComputeCommand> command = [buffer->buffer indirectComputeCommandAtIndex:command_index];
    [command concurrentDispatchThreadgroups:MTLSizeMake(threadgroup_count_x, threadgroup_count_y, threadgroup_count_z)
                        threadsPerThreadgroup:MTLSizeMake(threads_per_threadgroup_x, threads_per_threadgroup_y, threads_per_threadgroup_z)];
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_shader_module_create_msl(
    vkmtl_metal_clear_screen *owner,
    const char *source,
    size_t source_len,
    vkmtl_metal_shader_module **out_shader
) {
    if (out_shader == NULL) {
        return VKMTL_METAL_STATUS_INVALID_SHADER;
    }
    *out_shader = NULL;

    if (owner == NULL || owner->device == nil || source == NULL || source_len == 0) {
        return VKMTL_METAL_STATUS_INVALID_SHADER;
    }

    @autoreleasepool {
        NSString *source_string = [[NSString alloc]
            initWithBytes:source
                   length:source_len
                 encoding:NSUTF8StringEncoding];
        if (source_string == nil) {
            return VKMTL_METAL_STATUS_INVALID_SHADER;
        }

        NSError *error = nil;
        id<MTLLibrary> library = [owner->device newLibraryWithSource:source_string options:nil error:&error];
        [source_string release];
        if (library == nil) {
            const char *message = error != nil ? [[error localizedDescription] UTF8String] : NULL;
            if (message != NULL) {
                fprintf(stderr, "vkmtl metal shader compile failed: %s\n", message);
            }
            return VKMTL_METAL_STATUS_INVALID_SHADER;
        }

        vkmtl_metal_shader_module *shader = calloc(1, sizeof(vkmtl_metal_shader_module));
        if (shader == NULL) {
            [library release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        shader->library = library;
        *out_shader = shader;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_shader_module_destroy(vkmtl_metal_shader_module *shader) {
    if (shader == NULL) {
        return;
    }

    @autoreleasepool {
        [shader->library release];
        free(shader);
    }
}

vkmtl_metal_status vkmtl_metal_shader_module_set_label(
    vkmtl_metal_shader_module *shader,
    const char *label,
    size_t label_len
) {
    if (shader == NULL) {
        return VKMTL_METAL_STATUS_INVALID_SHADER;
    }
    return vkmtl_set_objc_label(
        shader->library,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_SHADER
    );
}

static id<MTLFunction> vkmtl_new_function_with_constants(
    id<MTLLibrary> library,
    NSString *name,
    const vkmtl_metal_function_constant *constants,
    size_t constant_count
) {
    if (library == nil || name == nil || (constant_count != 0 && constants == NULL)) {
        return nil;
    }
    if (constant_count == 0) {
        return [library newFunctionWithName:name];
    }

    MTLFunctionConstantValues *values = [[MTLFunctionConstantValues alloc] init];
    if (values == nil) {
        return nil;
    }

    for (size_t i = 0; i < constant_count; i += 1) {
        const vkmtl_metal_function_constant constant = constants[i];
        MTLDataType data_type = MTLDataTypeNone;
        const void *value = NULL;
        bool bool_value = constant.value_bits != 0;
        int32_t i32_value = 0;
        uint32_t u32_value = constant.value_bits;
        float f32_value = 0.0f;
        memcpy(&i32_value, &constant.value_bits, sizeof(i32_value));
        memcpy(&f32_value, &constant.value_bits, sizeof(f32_value));

        switch (constant.kind) {
            case VKMTL_METAL_FUNCTION_CONSTANT_BOOL:
                data_type = MTLDataTypeBool;
                value = &bool_value;
                break;
            case VKMTL_METAL_FUNCTION_CONSTANT_I32:
                data_type = MTLDataTypeInt;
                value = &i32_value;
                break;
            case VKMTL_METAL_FUNCTION_CONSTANT_U32:
                data_type = MTLDataTypeUInt;
                value = &u32_value;
                break;
            case VKMTL_METAL_FUNCTION_CONSTANT_F32:
                data_type = MTLDataTypeFloat;
                value = &f32_value;
                break;
            default:
                [values release];
                return nil;
        }

        [values setConstantValue:value type:data_type atIndex:constant.id];
    }

    NSError *error = nil;
    id<MTLFunction> function = [library newFunctionWithName:name constantValues:values error:&error];
    [values release];
    if (function == nil && error != nil) {
        const char *message = [[error localizedDescription] UTF8String];
        if (message != NULL) {
            fprintf(stderr, "vkmtl metal function specialization failed: %s\n", message);
        }
    }
    return function;
}

typedef struct vkmtl_binary_archive_session {
    id<MTLBinaryArchive> archive;
    NSURL *url;
    NSString *identity_path;
    uint64_t identity_hash;
    unsigned int read_only;
} vkmtl_binary_archive_session;

static vkmtl_binary_archive_session vkmtl_binary_archive_begin(
    id<MTLDevice> device,
    const char *path,
    size_t path_len,
    uint64_t identity_hash,
    unsigned int read_only
) {
    vkmtl_binary_archive_session session = {0};
    if (path == NULL || path_len == 0) return session;
    if (@available(macOS 11.0, *)) {
        NSString *path_string = [[NSString alloc] initWithBytes:path length:path_len encoding:NSUTF8StringEncoding];
        if (path_string == nil) return session;
        NSString *parent = [path_string stringByDeletingLastPathComponent];
        if (parent.length != 0) {
            [[NSFileManager defaultManager] createDirectoryAtPath:parent
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
        }
        NSString *identity_path = [path_string stringByAppendingString:@".identity"];
        NSData *stored_identity = [NSData dataWithContentsOfFile:identity_path];
        uint64_t stored_hash = 0;
        BOOL identity_matches = stored_identity.length == sizeof(stored_hash);
        if (identity_matches) memcpy(&stored_hash, stored_identity.bytes, sizeof(stored_hash));
        identity_matches = identity_matches && stored_hash == identity_hash;
        if (!identity_matches) {
            [[NSFileManager defaultManager] removeItemAtPath:path_string error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:identity_path error:nil];
        }

        NSURL *url = [NSURL fileURLWithPath:path_string];
        MTLBinaryArchiveDescriptor *descriptor = [[MTLBinaryArchiveDescriptor alloc] init];
        if (identity_matches && [[NSFileManager defaultManager] fileExistsAtPath:path_string]) {
            descriptor.url = url;
        }
        NSError *error = nil;
        id<MTLBinaryArchive> archive = [device newBinaryArchiveWithDescriptor:descriptor error:&error];
        if (archive == nil && descriptor.url != nil) {
            descriptor.url = nil;
            [[NSFileManager defaultManager] removeItemAtPath:path_string error:nil];
            archive = [device newBinaryArchiveWithDescriptor:descriptor error:&error];
        }
        [descriptor release];
        if (archive != nil) {
            session.archive = archive;
            session.url = [url retain];
            session.identity_path = [identity_path copy];
            session.identity_hash = identity_hash;
            session.read_only = read_only;
        }
        [path_string release];
    }
    return session;
}

static void vkmtl_binary_archive_finish(vkmtl_binary_archive_session *session, BOOL pipeline_created) {
    if (session == NULL || session->archive == nil) return;
    if (@available(macOS 11.0, *)) {
        if (pipeline_created && !session->read_only) {
            NSError *error = nil;
            if ([session->archive serializeToURL:session->url error:&error]) {
                NSData *identity = [NSData dataWithBytes:&session->identity_hash length:sizeof(session->identity_hash)];
                [identity writeToFile:session->identity_path options:NSDataWritingAtomic error:nil];
            }
        }
        [session->identity_path release];
        [session->url release];
        [session->archive release];
        session->archive = nil;
    }
}

vkmtl_metal_status vkmtl_metal_render_pipeline_state_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_shader_module *vertex_shader,
    const char *vertex_entry,
    size_t vertex_entry_len,
    const vkmtl_metal_function_constant *vertex_constants,
    size_t vertex_constant_count,
    vkmtl_metal_shader_module *fragment_shader,
    const char *fragment_entry,
    size_t fragment_entry_len,
    const vkmtl_metal_function_constant *fragment_constants,
    size_t fragment_constant_count,
    const vkmtl_metal_render_pipeline_color_attachment *color_attachments,
    size_t color_attachment_count,
    vkmtl_metal_texture_format depth_format,
    vkmtl_metal_compare_function depth_compare_function,
    unsigned int depth_write_enabled,
    unsigned int stencil_enabled,
    vkmtl_metal_stencil_operation front_stencil_fail_operation,
    vkmtl_metal_stencil_operation front_depth_fail_operation,
    vkmtl_metal_stencil_operation front_depth_stencil_pass_operation,
    vkmtl_metal_compare_function front_stencil_compare_function,
    vkmtl_metal_stencil_operation back_stencil_fail_operation,
    vkmtl_metal_stencil_operation back_depth_fail_operation,
    vkmtl_metal_stencil_operation back_depth_stencil_pass_operation,
    vkmtl_metal_compare_function back_stencil_compare_function,
    unsigned int stencil_read_mask,
    unsigned int stencil_write_mask,
    unsigned int sample_count,
    const vkmtl_metal_vertex_buffer_layout *vertex_buffers,
    size_t vertex_buffer_count,
    const vkmtl_metal_vertex_attribute *vertex_attributes,
    size_t vertex_attribute_count,
    const char *cache_path,
    size_t cache_path_len,
    uint64_t cache_identity_hash,
    unsigned int cache_read_only,
    vkmtl_metal_render_pipeline_state **out_pipeline
) {
    if (out_pipeline == NULL) {
        return VKMTL_METAL_STATUS_INVALID_PIPELINE;
    }
    *out_pipeline = NULL;

    if (owner == NULL ||
        owner->device == nil ||
        vertex_shader == NULL ||
        vertex_shader->library == nil ||
        vertex_entry == NULL ||
        vertex_entry_len == 0 ||
        (vertex_constant_count != 0 && vertex_constants == NULL) ||
        (fragment_constant_count != 0 && fragment_constants == NULL) ||
        sample_count == 0 ||
        color_attachments == NULL ||
        color_attachment_count == 0 ||
        color_attachment_count > 4) {
        return VKMTL_METAL_STATUS_INVALID_PIPELINE;
    }
    if (![owner->device supportsTextureSampleCount:sample_count]) {
        return VKMTL_METAL_STATUS_INVALID_PIPELINE;
    }

    @autoreleasepool {
        NSString *vertex_name = [[NSString alloc]
            initWithBytes:vertex_entry
                   length:vertex_entry_len
                 encoding:NSUTF8StringEncoding];
        if (vertex_name == nil) {
            return VKMTL_METAL_STATUS_INVALID_PIPELINE;
        }

        id<MTLFunction> vertex_function = vkmtl_new_function_with_constants(
            vertex_shader->library,
            vertex_name,
            vertex_constants,
            vertex_constant_count
        );
        [vertex_name release];
        if (vertex_function == nil) {
            return VKMTL_METAL_STATUS_INVALID_PIPELINE;
        }

        id<MTLFunction> fragment_function = nil;
        if (fragment_shader != NULL && fragment_shader->library != nil) {
            if (fragment_entry == NULL || fragment_entry_len == 0) {
                [vertex_function release];
                return VKMTL_METAL_STATUS_INVALID_PIPELINE;
            }

            NSString *fragment_name = [[NSString alloc]
                initWithBytes:fragment_entry
                       length:fragment_entry_len
                     encoding:NSUTF8StringEncoding];
            if (fragment_name == nil) {
                [vertex_function release];
                return VKMTL_METAL_STATUS_INVALID_PIPELINE;
            }

            fragment_function = vkmtl_new_function_with_constants(
                fragment_shader->library,
                fragment_name,
                fragment_constants,
                fragment_constant_count
            );
            [fragment_name release];
            if (fragment_function == nil) {
                [vertex_function release];
                return VKMTL_METAL_STATUS_INVALID_PIPELINE;
            }
        }

        MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
        if (descriptor == nil) {
            [fragment_function release];
            [vertex_function release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        descriptor.vertexFunction = vertex_function;
        descriptor.fragmentFunction = fragment_function;
        if (@available(macOS 10.14, *)) {
            descriptor.supportIndirectCommandBuffers = YES;
        }
        for (size_t i = 0; i < color_attachment_count; i += 1) {
            const vkmtl_metal_render_pipeline_color_attachment attachment = color_attachments[i];
            if (attachment.format == VKMTL_METAL_TEXTURE_FORMAT_INVALID) {
                [descriptor release];
                [fragment_function release];
                [vertex_function release];
                return VKMTL_METAL_STATUS_INVALID_PIPELINE;
            }
            descriptor.colorAttachments[i].pixelFormat = vkmtl_texture_pixel_format(attachment.format);
            descriptor.colorAttachments[i].writeMask = vkmtl_color_write_mask(attachment.color_write_mask);
            if (attachment.blend_enabled != 0) {
                descriptor.colorAttachments[i].blendingEnabled = YES;
                descriptor.colorAttachments[i].sourceRGBBlendFactor =
                    vkmtl_blend_factor(attachment.source_rgb_blend_factor);
                descriptor.colorAttachments[i].destinationRGBBlendFactor =
                    vkmtl_blend_factor(attachment.destination_rgb_blend_factor);
                descriptor.colorAttachments[i].rgbBlendOperation =
                    vkmtl_blend_operation(attachment.rgb_blend_operation);
                descriptor.colorAttachments[i].sourceAlphaBlendFactor =
                    vkmtl_blend_factor(attachment.source_alpha_blend_factor);
                descriptor.colorAttachments[i].destinationAlphaBlendFactor =
                    vkmtl_blend_factor(attachment.destination_alpha_blend_factor);
                descriptor.colorAttachments[i].alphaBlendOperation =
                    vkmtl_blend_operation(attachment.alpha_blend_operation);
            }
        }
        descriptor.sampleCount = sample_count;
        if (vkmtl_texture_format_has_depth(depth_format)) {
            descriptor.depthAttachmentPixelFormat = vkmtl_texture_pixel_format(depth_format);
        }
        if (vkmtl_texture_format_has_stencil(depth_format)) {
            descriptor.stencilAttachmentPixelFormat = vkmtl_texture_pixel_format(depth_format);
        }

        if (vertex_buffer_count > 0 || vertex_attribute_count > 0) {
            MTLVertexDescriptor *vertex_descriptor = [[MTLVertexDescriptor alloc] init];
            if (vertex_descriptor == nil) {
                [descriptor release];
                [fragment_function release];
                [vertex_function release];
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }

            for (size_t i = 0; i < vertex_buffer_count; i += 1) {
                const vkmtl_metal_vertex_buffer_layout layout = vertex_buffers[i];
                vertex_descriptor.layouts[layout.buffer_index].stride = layout.stride;
                vertex_descriptor.layouts[layout.buffer_index].stepFunction =
                    vkmtl_vertex_step_function(layout.step_function);
                vertex_descriptor.layouts[layout.buffer_index].stepRate = layout.step_rate;
            }

            for (size_t i = 0; i < vertex_attribute_count; i += 1) {
                const vkmtl_metal_vertex_attribute attribute = vertex_attributes[i];
                vertex_descriptor.attributes[attribute.location].format =
                    vkmtl_vertex_format(attribute.format);
                vertex_descriptor.attributes[attribute.location].offset = attribute.offset;
                vertex_descriptor.attributes[attribute.location].bufferIndex = attribute.buffer_index;
            }

            descriptor.vertexDescriptor = vertex_descriptor;
            [vertex_descriptor release];
        }

        vkmtl_binary_archive_session archive = vkmtl_binary_archive_begin(
            owner->device,
            cache_path,
            cache_path_len,
            cache_identity_hash,
            cache_read_only
        );
        if (@available(macOS 11.0, *)) {
            if (archive.archive != nil) {
                NSError *archive_error = nil;
                [archive.archive addRenderPipelineFunctionsWithDescriptor:descriptor error:&archive_error];
                descriptor.binaryArchives = @[archive.archive];
            }
        }

        NSError *error = nil;
        id<MTLRenderPipelineState> pipeline =
            [owner->device newRenderPipelineStateWithDescriptor:descriptor error:&error];
        vkmtl_binary_archive_finish(&archive, pipeline != nil);
        [descriptor release];
        [fragment_function release];
        [vertex_function release];
        if (pipeline == nil) {
            if (error != nil) {
                fprintf(stderr, "vkmtl Metal render pipeline error: %s\n", error.localizedDescription.UTF8String);
            }
            return VKMTL_METAL_STATUS_INVALID_PIPELINE;
        }

        id<MTLDepthStencilState> depth_stencil = nil;
        if (depth_format != VKMTL_METAL_TEXTURE_FORMAT_INVALID || stencil_enabled != 0) {
            MTLDepthStencilDescriptor *depth_descriptor =
                [[MTLDepthStencilDescriptor alloc] init];
            if (depth_descriptor == nil) {
                [pipeline release];
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }

            depth_descriptor.depthCompareFunction =
                vkmtl_compare_function(depth_compare_function);
            depth_descriptor.depthWriteEnabled = depth_write_enabled != 0;
            if (stencil_enabled != 0) {
                MTLStencilDescriptor *front = [[MTLStencilDescriptor alloc] init];
                MTLStencilDescriptor *back = [[MTLStencilDescriptor alloc] init];
                if (front == nil || back == nil) {
                    [front release];
                    [back release];
                    [depth_descriptor release];
                    [pipeline release];
                    return VKMTL_METAL_STATUS_COMMAND_FAILED;
                }

                front.stencilFailureOperation = vkmtl_stencil_operation(front_stencil_fail_operation);
                front.depthFailureOperation = vkmtl_stencil_operation(front_depth_fail_operation);
                front.depthStencilPassOperation =
                    vkmtl_stencil_operation(front_depth_stencil_pass_operation);
                front.stencilCompareFunction = vkmtl_compare_function(front_stencil_compare_function);
                front.readMask = stencil_read_mask;
                front.writeMask = stencil_write_mask;

                back.stencilFailureOperation = vkmtl_stencil_operation(back_stencil_fail_operation);
                back.depthFailureOperation = vkmtl_stencil_operation(back_depth_fail_operation);
                back.depthStencilPassOperation =
                    vkmtl_stencil_operation(back_depth_stencil_pass_operation);
                back.stencilCompareFunction = vkmtl_compare_function(back_stencil_compare_function);
                back.readMask = stencil_read_mask;
                back.writeMask = stencil_write_mask;

                depth_descriptor.frontFaceStencil = front;
                depth_descriptor.backFaceStencil = back;
                [front release];
                [back release];
            }

            depth_stencil = [owner->device newDepthStencilStateWithDescriptor:depth_descriptor];
            [depth_descriptor release];
            if (depth_stencil == nil) {
                [pipeline release];
                return VKMTL_METAL_STATUS_INVALID_PIPELINE;
            }
        }

        vkmtl_metal_render_pipeline_state *state =
            calloc(1, sizeof(vkmtl_metal_render_pipeline_state));
        if (state == NULL) {
            [depth_stencil release];
            [pipeline release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        state->pipeline = pipeline;
        state->depth_stencil = depth_stencil;
        *out_pipeline = state;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_render_pipeline_state_destroy(vkmtl_metal_render_pipeline_state *pipeline) {
    if (pipeline == NULL) {
        return;
    }

    @autoreleasepool {
        [pipeline->depth_stencil release];
        [pipeline->pipeline release];
        free(pipeline);
    }
}

vkmtl_metal_status vkmtl_metal_render_pipeline_state_set_label(
    vkmtl_metal_render_pipeline_state *pipeline,
    const char *label,
    size_t label_len
) {
    if (pipeline == NULL) {
        return VKMTL_METAL_STATUS_INVALID_PIPELINE;
    }
    return vkmtl_set_objc_label(
        pipeline->pipeline,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_PIPELINE
    );
}

vkmtl_metal_status vkmtl_metal_compute_pipeline_state_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_shader_module *compute_shader,
    const char *compute_entry,
    size_t compute_entry_len,
    const vkmtl_metal_function_constant *constants,
    size_t constant_count,
    const char *cache_path,
    size_t cache_path_len,
    uint64_t cache_identity_hash,
    unsigned int cache_read_only,
    vkmtl_metal_compute_pipeline_state **out_pipeline
) {
    if (out_pipeline == NULL) {
        return VKMTL_METAL_STATUS_INVALID_PIPELINE;
    }
    *out_pipeline = NULL;

    if (owner == NULL ||
        owner->device == nil ||
        compute_shader == NULL ||
        compute_shader->library == nil ||
        compute_entry == NULL ||
        compute_entry_len == 0 ||
        (constant_count != 0 && constants == NULL)) {
        return VKMTL_METAL_STATUS_INVALID_PIPELINE;
    }

    @autoreleasepool {
        NSString *compute_name = [[NSString alloc]
            initWithBytes:compute_entry
                   length:compute_entry_len
                 encoding:NSUTF8StringEncoding];
        if (compute_name == nil) {
            return VKMTL_METAL_STATUS_INVALID_PIPELINE;
        }

        id<MTLFunction> compute_function = vkmtl_new_function_with_constants(
            compute_shader->library,
            compute_name,
            constants,
            constant_count
        );
        [compute_name release];
        if (compute_function == nil) {
            return VKMTL_METAL_STATUS_INVALID_PIPELINE;
        }

        vkmtl_binary_archive_session archive = vkmtl_binary_archive_begin(
            owner->device,
            cache_path,
            cache_path_len,
            cache_identity_hash,
            cache_read_only
        );
        NSError *error = nil;
        id<MTLComputePipelineState> pipeline = nil;
        MTLComputePipelineDescriptor *descriptor = [[MTLComputePipelineDescriptor alloc] init];
        descriptor.computeFunction = compute_function;
        if (@available(macOS 10.14, *)) {
            descriptor.supportIndirectCommandBuffers = YES;
        }
        if (@available(macOS 11.0, *)) {
            if (archive.archive != nil) {
                NSError *archive_error = nil;
                [archive.archive addComputePipelineFunctionsWithDescriptor:descriptor error:&archive_error];
                descriptor.binaryArchives = @[archive.archive];
            }
        }
        pipeline = [owner->device newComputePipelineStateWithDescriptor:descriptor
                                                                options:MTLPipelineOptionNone
                                                             reflection:nil
                                                                  error:&error];
        [descriptor release];
        vkmtl_binary_archive_finish(&archive, pipeline != nil);
        [compute_function release];
        if (pipeline == nil) {
            return VKMTL_METAL_STATUS_INVALID_PIPELINE;
        }

        vkmtl_metal_compute_pipeline_state *state =
            calloc(1, sizeof(vkmtl_metal_compute_pipeline_state));
        if (state == NULL) {
            [pipeline release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        state->pipeline = pipeline;
        *out_pipeline = state;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_compute_pipeline_state_destroy(vkmtl_metal_compute_pipeline_state *pipeline) {
    if (pipeline == NULL) {
        return;
    }

    @autoreleasepool {
        [pipeline->pipeline release];
        free(pipeline);
    }
}

vkmtl_metal_status vkmtl_metal_compute_pipeline_state_set_label(
    vkmtl_metal_compute_pipeline_state *pipeline,
    const char *label,
    size_t label_len
) {
    if (pipeline == NULL) {
        return VKMTL_METAL_STATUS_INVALID_PIPELINE;
    }
    return vkmtl_set_objc_label(
        pipeline->pipeline,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_PIPELINE
    );
}

static BOOL vkmtl_query_range_is_valid(
    const vkmtl_metal_query_set *query_set,
    unsigned int first_query,
    unsigned int query_count
) {
    if (query_set == NULL || query_count == 0) {
        return NO;
    }
    const NSUInteger first = (NSUInteger)first_query;
    const NSUInteger count = (NSUInteger)query_count;
    return first <= query_set->count && count <= query_set->count - first;
}

static BOOL vkmtl_timestamp_query_is_valid(
    const vkmtl_metal_query_set *query_set,
    unsigned int query_index
) {
    return query_set != NULL &&
        query_set->query_type == VKMTL_METAL_QUERY_TYPE_TIMESTAMP &&
        query_set->counter_sample_buffer != nil &&
        (NSUInteger)query_index < query_set->count;
}

static void vkmtl_query_set_record_writer(
    vkmtl_metal_query_set *query_set,
    NSUInteger query_index,
    id<MTLCommandBuffer> command_buffer
) {
    if (query_set == NULL || query_set->writer_command_buffers == NULL ||
        query_index >= query_set->count || command_buffer == nil) {
        return;
    }
    [query_set->writer_command_buffers[query_index] release];
    query_set->writer_command_buffers[query_index] = [command_buffer retain];
}

static void vkmtl_query_set_release_writers(vkmtl_metal_query_set *query_set) {
    if (query_set == NULL || query_set->writer_command_buffers == NULL) {
        return;
    }
    for (NSUInteger i = 0; i < query_set->count; i += 1) {
        [query_set->writer_command_buffers[i] release];
        query_set->writer_command_buffers[i] = nil;
    }
}

static vkmtl_metal_status vkmtl_query_set_require_ready(
    const vkmtl_metal_query_set *query_set,
    NSUInteger first_query,
    NSUInteger query_count
) {
    if (query_set == NULL || query_set->writer_command_buffers == NULL) {
        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }
    for (NSUInteger i = first_query; i < first_query + query_count; i += 1) {
        id<MTLCommandBuffer> writer = query_set->writer_command_buffers[i];
        if (writer == nil) {
            continue;
        }
        switch ([writer status]) {
            case MTLCommandBufferStatusCompleted:
                break;
            case MTLCommandBufferStatusError:
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            default:
                return VKMTL_METAL_STATUS_QUERY_NOT_READY;
        }
    }
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_query_set_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_query_type query_type,
    unsigned int count,
    vkmtl_metal_query_set **out_query_set
) {
    if (out_query_set == NULL) {
        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }
    *out_query_set = NULL;

    if (owner == NULL || owner->device == nil || count == 0 ||
        (NSUInteger)count > NSUIntegerMax / sizeof(uint64_t)) {
        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }

    @autoreleasepool {
        const NSUInteger byte_count = (NSUInteger)count * sizeof(uint64_t);
        id<MTLBuffer> result_buffer = nil;
        id<MTLCounterSampleBuffer> counter_sample_buffer = nil;
        id<MTLBuffer> counter_resolve_buffer = nil;
        id<MTLCommandBuffer> *writer_command_buffers =
            calloc(count, sizeof(id<MTLCommandBuffer>));
        if (writer_command_buffers == NULL) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        switch (query_type) {
            case VKMTL_METAL_QUERY_TYPE_OCCLUSION:
                result_buffer = [owner->device
                    newBufferWithLength:byte_count
                              options:MTLResourceStorageModeShared];
                if (result_buffer == nil) {
                    free(writer_command_buffers);
                    return VKMTL_METAL_STATUS_COMMAND_FAILED;
                }
                memset([result_buffer contents], 0, byte_count);
                break;

            case VKMTL_METAL_QUERY_TYPE_TIMESTAMP: {
                vkmtl_metal_device_capabilities capabilities;
                memset(&capabilities, 0, sizeof(capabilities));
                vkmtl_copy_timestamp_capabilities(owner->device, &capabilities);
                if (capabilities.timestamp_queries == 0) {
                    free(writer_command_buffers);
                    return VKMTL_METAL_STATUS_UNSUPPORTED;
                }

                if (@available(macOS 11.0, *)) {
                    id<MTLCounterSet> counter_set = vkmtl_timestamp_counter_set(owner->device);
                    if (counter_set == nil) {
                        free(writer_command_buffers);
                        return VKMTL_METAL_STATUS_UNSUPPORTED;
                    }
                    MTLCounterSampleBufferDescriptor *descriptor =
                        [[MTLCounterSampleBufferDescriptor alloc] init];
                    if (descriptor == nil) {
                        free(writer_command_buffers);
                        return VKMTL_METAL_STATUS_COMMAND_FAILED;
                    }
                    descriptor.counterSet = counter_set;
                    descriptor.storageMode = MTLStorageModeShared;
                    descriptor.sampleCount = count;
                    NSError *error = nil;
                    counter_sample_buffer =
                        [owner->device newCounterSampleBufferWithDescriptor:descriptor error:&error];
                    [descriptor release];
                    if (counter_sample_buffer == nil) {
                        free(writer_command_buffers);
                        return VKMTL_METAL_STATUS_COMMAND_FAILED;
                    }
                    counter_resolve_buffer = [owner->device
                        newBufferWithLength:byte_count
                                  options:MTLResourceStorageModePrivate];
                    if (counter_resolve_buffer == nil) {
                        [counter_sample_buffer release];
                        free(writer_command_buffers);
                        return VKMTL_METAL_STATUS_COMMAND_FAILED;
                    }
                } else {
                    free(writer_command_buffers);
                    return VKMTL_METAL_STATUS_UNSUPPORTED;
                }
                break;
            }

            default:
                free(writer_command_buffers);
                return VKMTL_METAL_STATUS_INVALID_QUERY;
        }

        vkmtl_metal_query_set *query_set = calloc(1, sizeof(vkmtl_metal_query_set));
        if (query_set == NULL) {
            [counter_resolve_buffer release];
            [counter_sample_buffer release];
            [result_buffer release];
            free(writer_command_buffers);
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        query_set->query_type = query_type;
        query_set->count = count;
        query_set->result_buffer = result_buffer;
        query_set->counter_sample_buffer = counter_sample_buffer;
        query_set->counter_resolve_buffer = counter_resolve_buffer;
        query_set->writer_command_buffers = writer_command_buffers;
        *out_query_set = query_set;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_query_set_destroy(vkmtl_metal_query_set *query_set) {
    if (query_set == NULL) {
        return;
    }

    @autoreleasepool {
        vkmtl_query_set_release_writers(query_set);
        free(query_set->writer_command_buffers);
        [query_set->counter_resolve_buffer release];
        [query_set->counter_sample_buffer release];
        [query_set->result_buffer release];
        free(query_set);
    }
}

vkmtl_metal_status vkmtl_metal_query_set_set_label(
    vkmtl_metal_query_set *query_set,
    const char *label,
    size_t label_len
) {
    if (query_set == NULL) {
        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }

    @autoreleasepool {
        NSString *string = label == NULL ? nil : vkmtl_new_string_from_bytes(label, label_len);
        if (label != NULL && string == nil) {
            return VKMTL_METAL_STATUS_INVALID_QUERY;
        }
        query_set->result_buffer.label = string;
        query_set->counter_resolve_buffer.label = string;
        [string release];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_query_set_reset(vkmtl_metal_query_set *query_set) {
    if (query_set == NULL) {
        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }

    vkmtl_query_set_release_writers(query_set);
    if (query_set->query_type == VKMTL_METAL_QUERY_TYPE_OCCLUSION) {
        if (query_set->result_buffer == nil || [query_set->result_buffer contents] == NULL) {
            return VKMTL_METAL_STATUS_INVALID_QUERY;
        }
        memset(
            [query_set->result_buffer contents],
            0,
            query_set->count * sizeof(uint64_t)
        );
    }
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_query_set_read_values(
    vkmtl_metal_query_set *query_set,
    unsigned int first_query,
    unsigned int query_count,
    uint64_t *destination
) {
    if (!vkmtl_query_range_is_valid(query_set, first_query, query_count) ||
        destination == NULL) {
        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }

    @autoreleasepool {
        const NSUInteger first = first_query;
        const NSUInteger count = query_count;
        const NSUInteger byte_count = count * sizeof(uint64_t);
        const vkmtl_metal_status ready =
            vkmtl_query_set_require_ready(query_set, first, count);
        if (ready != VKMTL_METAL_STATUS_OK) {
            return ready;
        }
        if (query_set->query_type == VKMTL_METAL_QUERY_TYPE_OCCLUSION) {
            if (query_set->result_buffer == nil || [query_set->result_buffer contents] == NULL) {
                return VKMTL_METAL_STATUS_INVALID_QUERY;
            }
            const uint64_t *values = (const uint64_t *)[query_set->result_buffer contents];
            memcpy(destination, values + first, byte_count);
            return VKMTL_METAL_STATUS_OK;
        }

        if (query_set->query_type == VKMTL_METAL_QUERY_TYPE_TIMESTAMP) {
            if (@available(macOS 10.15, *)) {
                if (query_set->counter_sample_buffer == nil) {
                    return VKMTL_METAL_STATUS_INVALID_QUERY;
                }
                NSData *resolved = [query_set->counter_sample_buffer
                    resolveCounterRange:NSMakeRange(first, count)];
                if (resolved == nil || [resolved length] < byte_count) {
                    return VKMTL_METAL_STATUS_COMMAND_FAILED;
                }
                const MTLCounterResultTimestamp *timestamps =
                    (const MTLCounterResultTimestamp *)[resolved bytes];
                for (NSUInteger i = 0; i < count; i += 1) {
                    if (timestamps[i].timestamp == MTLCounterErrorValue) {
                        return VKMTL_METAL_STATUS_COMMAND_FAILED;
                    }
                    destination[i] = timestamps[i].timestamp;
                }
                return VKMTL_METAL_STATUS_OK;
            }
            return VKMTL_METAL_STATUS_UNSUPPORTED;
        }

        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }
}

vkmtl_metal_status vkmtl_metal_acceleration_structure_query_sizes(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_acceleration_structure_kind kind,
    unsigned int primitive_count,
    vkmtl_metal_acceleration_structure_build_sizes *out_sizes
) {
    if (out_sizes == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    memset(out_sizes, 0, sizeof(vkmtl_metal_acceleration_structure_build_sizes));

    if (owner == NULL || owner->device == nil) {
        return VKMTL_METAL_STATUS_NO_DEVICE;
    }

    @autoreleasepool {
        MTLAccelerationStructureSizes sizes;
        vkmtl_metal_status status = vkmtl_query_acceleration_structure_sizes(
            owner->device,
            kind,
            primitive_count,
            &sizes
        );
        if (status != VKMTL_METAL_STATUS_OK) {
            return status;
        }

        out_sizes->result_size = sizes.accelerationStructureSize;
        out_sizes->scratch_size = sizes.buildScratchBufferSize;
        out_sizes->update_scratch_size = sizes.refitScratchBufferSize;
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_acceleration_structure_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_acceleration_structure_kind kind,
    unsigned int primitive_count,
    vkmtl_metal_acceleration_structure **out_acceleration_structure
) {
    if (out_acceleration_structure == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    *out_acceleration_structure = NULL;

    if (owner == NULL || owner->device == nil) {
        return VKMTL_METAL_STATUS_NO_DEVICE;
    }

    @autoreleasepool {
        MTLAccelerationStructureDescriptor *descriptor = nil;
        id<MTLBuffer> auxiliary_buffer = nil;
        vkmtl_metal_status status = vkmtl_make_acceleration_structure_descriptor(
            owner->device,
            kind,
            primitive_count,
            &descriptor,
            &auxiliary_buffer
        );
        if (status != VKMTL_METAL_STATUS_OK) {
            return status;
        }

        MTLAccelerationStructureSizes sizes =
            [owner->device accelerationStructureSizesWithDescriptor:descriptor];
        id<MTLAccelerationStructure> acceleration_structure =
            [owner->device newAccelerationStructureWithSize:sizes.accelerationStructureSize];
        if (acceleration_structure == nil) {
            [descriptor release];
            [auxiliary_buffer release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        vkmtl_metal_acceleration_structure *result =
            calloc(1, sizeof(vkmtl_metal_acceleration_structure));
        if (result == NULL) {
            [acceleration_structure release];
            [descriptor release];
            [auxiliary_buffer release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        result->acceleration_structure = acceleration_structure;
        result->descriptor = descriptor;
        result->kind = kind;
        result->primitive_count = primitive_count;
        result->result_size = sizes.accelerationStructureSize;
        result->scratch_size = sizes.buildScratchBufferSize;
        result->update_scratch_size = sizes.refitScratchBufferSize;
        if (kind == VKMTL_METAL_ACCELERATION_STRUCTURE_KIND_BOTTOM_LEVEL) {
            result->geometry_buffer = auxiliary_buffer;
        } else {
            result->instance_buffer = auxiliary_buffer;
        }

        *out_acceleration_structure = result;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_acceleration_structure_destroy(
    vkmtl_metal_acceleration_structure *acceleration_structure
) {
    if (acceleration_structure == NULL) {
        return;
    }

    @autoreleasepool {
        [acceleration_structure->instance_buffer release];
        [acceleration_structure->geometry_buffer release];
        [acceleration_structure->index_buffer release];
        [acceleration_structure->descriptor release];
        [acceleration_structure->acceleration_structure release];
        free(acceleration_structure);
    }
}

vkmtl_metal_status vkmtl_metal_acceleration_structure_set_label(
    vkmtl_metal_acceleration_structure *acceleration_structure,
    const char *label,
    size_t label_len
) {
    if (acceleration_structure == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_set_objc_label(
        acceleration_structure->acceleration_structure,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

size_t vkmtl_metal_acceleration_structure_result_size(
    const vkmtl_metal_acceleration_structure *acceleration_structure
) {
    return acceleration_structure != NULL ? acceleration_structure->result_size : 0;
}

size_t vkmtl_metal_acceleration_structure_scratch_size(
    const vkmtl_metal_acceleration_structure *acceleration_structure
) {
    return acceleration_structure != NULL ? acceleration_structure->scratch_size : 0;
}

size_t vkmtl_metal_acceleration_structure_update_scratch_size(
    const vkmtl_metal_acceleration_structure *acceleration_structure
) {
    return acceleration_structure != NULL ? acceleration_structure->update_scratch_size : 0;
}

unsigned int vkmtl_metal_acceleration_structure_has_driver_handle(
    const vkmtl_metal_acceleration_structure *acceleration_structure
) {
    return acceleration_structure != NULL &&
        acceleration_structure->acceleration_structure != nil ? 1u : 0u;
}

vkmtl_metal_status vkmtl_metal_acceleration_structure_set_triangle_geometry(
    vkmtl_metal_acceleration_structure *acceleration_structure,
    vkmtl_metal_buffer *vertex_buffer,
    size_t vertex_buffer_offset,
    unsigned int vertex_stride,
    unsigned int vertex_count,
    vkmtl_metal_buffer *index_buffer,
    size_t index_buffer_offset,
    unsigned int index_type,
    unsigned int primitive_count
) {
    if (acceleration_structure == NULL ||
        acceleration_structure->kind != VKMTL_METAL_ACCELERATION_STRUCTURE_KIND_BOTTOM_LEVEL ||
        acceleration_structure->acceleration_structure == nil ||
        vertex_buffer == NULL ||
        vertex_buffer->buffer == nil ||
        vertex_stride == 0 ||
        vertex_count == 0 ||
        primitive_count == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    const size_t vertex_bytes = (size_t)vertex_stride * (size_t)vertex_count;
    if (vertex_buffer_offset > vertex_buffer->length ||
        vertex_bytes > vertex_buffer->length - vertex_buffer_offset) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }

    MTLIndexType metal_index_type = MTLIndexTypeUInt16;
    BOOL uses_indices = NO;
    if (index_type == 1u) {
        uses_indices = YES;
        metal_index_type = MTLIndexTypeUInt16;
    } else if (index_type == 2u) {
        uses_indices = YES;
        metal_index_type = MTLIndexTypeUInt32;
    } else if (index_type != 0u) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    if (uses_indices) {
        if (index_buffer == NULL || index_buffer->buffer == nil) {
            return VKMTL_METAL_STATUS_INVALID_BUFFER;
        }
        const size_t index_size = index_type == 1u ? sizeof(uint16_t) : sizeof(uint32_t);
        const size_t index_bytes = (size_t)primitive_count * 3u * index_size;
        if (index_buffer_offset > index_buffer->length ||
            index_bytes > index_buffer->length - index_buffer_offset) {
            return VKMTL_METAL_STATUS_INVALID_BUFFER;
        }
    }

    @autoreleasepool {
        MTLAccelerationStructureTriangleGeometryDescriptor *geometry =
            [MTLAccelerationStructureTriangleGeometryDescriptor descriptor];
        if (geometry == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }
        geometry.vertexBuffer = vertex_buffer->buffer;
        geometry.vertexBufferOffset = vertex_buffer_offset;
        if ([geometry respondsToSelector:@selector(setVertexFormat:)]) {
            geometry.vertexFormat = MTLAttributeFormatFloat3;
        }
        geometry.vertexStride = vertex_stride;
        geometry.triangleCount = primitive_count;
        geometry.opaque = YES;
        if (uses_indices) {
            geometry.indexBuffer = index_buffer->buffer;
            geometry.indexBufferOffset = index_buffer_offset;
            geometry.indexType = metal_index_type;
        }

        MTLPrimitiveAccelerationStructureDescriptor *descriptor =
            [MTLPrimitiveAccelerationStructureDescriptor descriptor];
        if (descriptor == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }
        descriptor.geometryDescriptors = @[geometry];
        descriptor.usage = MTLAccelerationStructureUsageNone;

        MTLAccelerationStructureDescriptor *retained_descriptor = [descriptor retain];
        [acceleration_structure->descriptor release];
        acceleration_structure->descriptor = retained_descriptor;

        [acceleration_structure->geometry_buffer release];
        acceleration_structure->geometry_buffer = [vertex_buffer->buffer retain];
        [acceleration_structure->index_buffer release];
        acceleration_structure->index_buffer = uses_indices ? [index_buffer->buffer retain] : nil;
        acceleration_structure->primitive_count = primitive_count;
        acceleration_structure->built = 0u;
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_ray_tracing_pipeline_state_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_shader_module *ray_generation_shader,
    const char *ray_generation_entry,
    size_t ray_generation_entry_len,
    vkmtl_metal_ray_tracing_pipeline_state **out_pipeline
) {
    if (out_pipeline == NULL) {
        return VKMTL_METAL_STATUS_INVALID_PIPELINE;
    }
    *out_pipeline = NULL;

    if (owner == NULL || owner->device == nil) {
        return VKMTL_METAL_STATUS_NO_DEVICE;
    }
    if (ray_generation_shader == NULL ||
        ray_generation_shader->library == nil ||
        ray_generation_entry == NULL ||
        ray_generation_entry_len == 0) {
        return VKMTL_METAL_STATUS_INVALID_SHADER;
    }
    if (!vkmtl_device_supports_raytracing(owner->device)) {
        return VKMTL_METAL_STATUS_UNSUPPORTED;
    }

    @autoreleasepool {
        NSError *error = nil;
        NSString *function_name = vkmtl_new_string_from_bytes(ray_generation_entry, ray_generation_entry_len);
        if (function_name == nil) {
            return VKMTL_METAL_STATUS_INVALID_SHADER;
        }

        id<MTLFunction> function = [ray_generation_shader->library newFunctionWithName:function_name];
        [function_name release];
        if (function == nil) {
            return VKMTL_METAL_STATUS_INVALID_SHADER;
        }

        id<MTLComputePipelineState> pipeline =
            [owner->device newComputePipelineStateWithFunction:function error:&error];
        [function release];
        if (pipeline == nil) {
            return VKMTL_METAL_STATUS_INVALID_PIPELINE;
        }

        vkmtl_metal_ray_tracing_pipeline_state *state =
            calloc(1, sizeof(vkmtl_metal_ray_tracing_pipeline_state));
        if (state == NULL) {
            [pipeline release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        state->pipeline = pipeline;
        *out_pipeline = state;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_ray_tracing_pipeline_state_destroy(
    vkmtl_metal_ray_tracing_pipeline_state *pipeline
) {
    if (pipeline == NULL) {
        return;
    }

    @autoreleasepool {
        [pipeline->pipeline release];
        free(pipeline);
    }
}

vkmtl_metal_status vkmtl_metal_ray_tracing_pipeline_state_set_label(
    vkmtl_metal_ray_tracing_pipeline_state *pipeline,
    const char *label,
    size_t label_len
) {
    if (pipeline == NULL) {
        return VKMTL_METAL_STATUS_INVALID_PIPELINE;
    }
    return vkmtl_set_objc_label(
        pipeline->pipeline,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_PIPELINE
    );
}

unsigned int vkmtl_metal_ray_tracing_pipeline_state_has_driver_handle(
    const vkmtl_metal_ray_tracing_pipeline_state *pipeline
) {
    return pipeline != NULL && pipeline->pipeline != nil ? 1u : 0u;
}

vkmtl_metal_status vkmtl_metal_shared_event_create(
    vkmtl_metal_clear_screen *owner,
    uint64_t initial_value,
    vkmtl_metal_shared_event **out_event
) {
    if (owner == NULL || owner->device == nil || out_event == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    *out_event = NULL;

    @autoreleasepool {
        if (@available(macOS 10.14, *)) {
            if (![owner->device respondsToSelector:@selector(newSharedEvent)]) {
                return VKMTL_METAL_STATUS_UNSUPPORTED;
            }
            id<MTLSharedEvent> native_event = [owner->device newSharedEvent];
            if (native_event == nil) {
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
            native_event.signaledValue = initial_value;

            vkmtl_metal_shared_event *event = calloc(1, sizeof(vkmtl_metal_shared_event));
            if (event == NULL) {
                [native_event release];
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
            event->event = native_event;
            *out_event = event;
            return VKMTL_METAL_STATUS_OK;
        }
        return VKMTL_METAL_STATUS_UNSUPPORTED;
    }
}

void vkmtl_metal_shared_event_destroy(vkmtl_metal_shared_event *event) {
    if (event == NULL) {
        return;
    }
    @autoreleasepool {
        [event->event release];
        free(event);
    }
}

vkmtl_metal_status vkmtl_metal_shared_event_get_value(
    const vkmtl_metal_shared_event *event,
    uint64_t *out_value
) {
    if (event == NULL || event->event == nil || out_value == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    if (@available(macOS 10.14, *)) {
        *out_value = event->event.signaledValue;
        return VKMTL_METAL_STATUS_OK;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_shared_event_signal(
    vkmtl_metal_shared_event *event,
    uint64_t value
) {
    if (event == NULL || event->event == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    if (@available(macOS 10.14, *)) {
        if (value < event->event.signaledValue) {
            return VKMTL_METAL_STATUS_INVALID_COMMAND;
        }
        event->event.signaledValue = value;
        return VKMTL_METAL_STATUS_OK;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_shared_event_wait(
    const vkmtl_metal_shared_event *event,
    uint64_t value,
    uint64_t timeout_ns
) {
    if (event == NULL || event->event == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    if (@available(macOS 10.14, *)) {
        const NSTimeInterval timeout_seconds = (NSTimeInterval)timeout_ns / 1000000000.0;
        const NSTimeInterval deadline = [NSDate timeIntervalSinceReferenceDate] + timeout_seconds;
        while (event->event.signaledValue < value) {
            if ([NSDate timeIntervalSinceReferenceDate] >= deadline) {
                return VKMTL_METAL_STATUS_QUERY_NOT_READY;
            }
            [NSThread sleepForTimeInterval:0.0001];
        }
        return VKMTL_METAL_STATUS_OK;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_create(
    vkmtl_metal_clear_screen *owner,
    unsigned int queue_kind,
    vkmtl_metal_command_buffer **out_command_buffer
) {
    if (out_command_buffer == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    *out_command_buffer = NULL;

    if (owner == NULL || owner->queue == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        id<MTLCommandQueue> selected_queue = owner->queue;
        if (queue_kind == 1) selected_queue = owner->compute_queue;
        if (queue_kind == 2) selected_queue = owner->transfer_queue;
        if (selected_queue == nil || queue_kind > 2) {
            return VKMTL_METAL_STATUS_INVALID_COMMAND;
        }
        id<MTLCommandBuffer> metal_command_buffer = [selected_queue commandBuffer];
        if (metal_command_buffer == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        vkmtl_metal_command_buffer *command_buffer =
            calloc(1, sizeof(vkmtl_metal_command_buffer));
        if (command_buffer == NULL) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        command_buffer->owner = owner;
        command_buffer->command_buffer = [metal_command_buffer retain];
        *out_command_buffer = command_buffer;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_command_buffer_destroy(vkmtl_metal_command_buffer *command_buffer) {
    if (command_buffer == NULL) {
        return;
    }

    @autoreleasepool {
        [command_buffer->drawable release];
        [command_buffer->command_buffer release];
        free(command_buffer);
    }
}

vkmtl_metal_status vkmtl_metal_command_buffer_set_label(
    vkmtl_metal_command_buffer *command_buffer,
    const char *label,
    size_t label_len
) {
    if (command_buffer == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_set_objc_label(
        command_buffer->command_buffer,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_command_buffer_push_debug_group(
    vkmtl_metal_command_buffer *command_buffer,
    const char *label,
    size_t label_len
) {
    if (command_buffer == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_push_objc_debug_group(
        command_buffer->command_buffer,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_command_buffer_pop_debug_group(
    vkmtl_metal_command_buffer *command_buffer
) {
    if (command_buffer == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_pop_objc_debug_group(
        command_buffer->command_buffer,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_command_buffer_insert_debug_signpost(
    vkmtl_metal_command_buffer *command_buffer,
    const char *label,
    size_t label_len
) {
    if (command_buffer == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_insert_objc_debug_signpost(
        command_buffer->command_buffer,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_command_buffer_present_drawable(
    vkmtl_metal_command_buffer *command_buffer
) {
    if (command_buffer == NULL ||
        command_buffer->command_buffer == nil ||
        command_buffer->drawable == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [command_buffer->command_buffer presentDrawable:command_buffer->drawable];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_command_buffer_present_drawable_timed(
    vkmtl_metal_command_buffer *command_buffer,
    unsigned int timing_mode,
    uint64_t value_ns
) {
    if (command_buffer == NULL || command_buffer->command_buffer == nil ||
        command_buffer->drawable == nil || value_ns == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    const NSTimeInterval value_seconds = (NSTimeInterval)value_ns / 1000000000.0;
    @autoreleasepool {
        if (timing_mode == 1) {
            if (@available(macOS 10.13, *)) {
                [command_buffer->command_buffer presentDrawable:command_buffer->drawable atTime:value_seconds];
                return VKMTL_METAL_STATUS_OK;
            }
            return VKMTL_METAL_STATUS_UNSUPPORTED;
        }
        if (timing_mode == 2) {
            if (@available(macOS 10.15.4, *)) {
                [command_buffer->command_buffer presentDrawable:command_buffer->drawable afterMinimumDuration:value_seconds];
                return VKMTL_METAL_STATUS_OK;
            }
            return VKMTL_METAL_STATUS_UNSUPPORTED;
        }
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
}

vkmtl_metal_status vkmtl_metal_command_buffer_wait_shared_event(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_shared_event *event,
    uint64_t value
) {
    if (command_buffer == NULL || command_buffer->command_buffer == nil ||
        event == NULL || event->event == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    if (@available(macOS 10.14, *)) {
        [command_buffer->command_buffer encodeWaitForEvent:event->event value:value];
        return VKMTL_METAL_STATUS_OK;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_signal_shared_event(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_shared_event *event,
    uint64_t value
) {
    if (command_buffer == NULL || command_buffer->command_buffer == nil ||
        event == NULL || event->event == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    if (@available(macOS 10.14, *)) {
        [command_buffer->command_buffer encodeSignalEvent:event->event value:value];
        return VKMTL_METAL_STATUS_OK;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_commit(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_command_buffer_lifecycle_callback callback,
    void *callback_context
) {
    if (command_buffer == NULL || command_buffer->command_buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        if (callback != NULL) {
            [command_buffer->command_buffer addScheduledHandler:^(id<MTLCommandBuffer> buffer) {
                (void)buffer;
                callback(callback_context, 1u);
            }];
            [command_buffer->command_buffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
                callback(callback_context, buffer.status == MTLCommandBufferStatusError ? 3u : 2u);
            }];
        }
        [command_buffer->command_buffer commit];
        [command_buffer->command_buffer waitUntilCompleted];
        return command_buffer->command_buffer.status == MTLCommandBufferStatusError
            ? VKMTL_METAL_STATUS_COMMAND_FAILED
            : VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_command_buffer_build_acceleration_structure(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_acceleration_structure *acceleration_structure,
    vkmtl_metal_buffer *scratch_buffer,
    size_t scratch_offset,
    vkmtl_metal_acceleration_structure *instance_source
) {
    if (command_buffer == NULL ||
        command_buffer->command_buffer == nil ||
        acceleration_structure == NULL ||
        acceleration_structure->acceleration_structure == nil ||
        acceleration_structure->descriptor == nil ||
        scratch_buffer == NULL ||
        scratch_buffer->buffer == nil ||
        scratch_offset > scratch_buffer->length ||
        acceleration_structure->scratch_size > scratch_buffer->length - scratch_offset) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        if (acceleration_structure->kind == VKMTL_METAL_ACCELERATION_STRUCTURE_KIND_TOP_LEVEL) {
            if (instance_source == NULL ||
                instance_source->acceleration_structure == nil ||
                instance_source->built == 0 ||
                acceleration_structure->instance_buffer == nil) {
                return VKMTL_METAL_STATUS_INVALID_COMMAND;
            }

            MTLInstanceAccelerationStructureDescriptor *descriptor =
                (MTLInstanceAccelerationStructureDescriptor *)acceleration_structure->descriptor;
            descriptor.instancedAccelerationStructures = @[instance_source->acceleration_structure];

            MTLAccelerationStructureInstanceDescriptor *instances =
                (MTLAccelerationStructureInstanceDescriptor *)[acceleration_structure->instance_buffer contents];
            for (unsigned int i = 0; i < acceleration_structure->primitive_count; i += 1) {
                vkmtl_fill_identity_instance(&instances[i]);
            }
            if ([acceleration_structure->instance_buffer storageMode] == MTLStorageModeManaged) {
                [acceleration_structure->instance_buffer didModifyRange:
                    NSMakeRange(
                        0,
                        (NSUInteger)acceleration_structure->primitive_count *
                            sizeof(MTLAccelerationStructureInstanceDescriptor)
                    )];
            }
        }

        id<MTLAccelerationStructureCommandEncoder> encoder =
            [command_buffer->command_buffer accelerationStructureCommandEncoder];
        if (encoder == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        [encoder buildAccelerationStructure:acceleration_structure->acceleration_structure
                                 descriptor:acceleration_structure->descriptor
                              scratchBuffer:scratch_buffer->buffer
                        scratchBufferOffset:scratch_offset];
        [encoder endEncoding];
        acceleration_structure->built = 1u;
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_command_buffer_dispatch_rays_to_drawable(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_ray_tracing_pipeline_state *pipeline,
    vkmtl_metal_acceleration_structure *acceleration_structure,
    unsigned int width,
    unsigned int height,
    const void *inline_data,
    size_t inline_data_len,
    unsigned int inline_data_index
) {
    if (command_buffer == NULL ||
        command_buffer->command_buffer == nil ||
        command_buffer->owner == NULL ||
        command_buffer->owner->layer == nil ||
        pipeline == NULL ||
        pipeline->pipeline == nil ||
        acceleration_structure == NULL ||
        acceleration_structure->acceleration_structure == nil ||
        acceleration_structure->built == 0 ||
        width == 0 ||
        height == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    if (acceleration_structure->kind != VKMTL_METAL_ACCELERATION_STRUCTURE_KIND_BOTTOM_LEVEL) {
        return VKMTL_METAL_STATUS_UNSUPPORTED;
    }

    @autoreleasepool {
        id<CAMetalDrawable> drawable = [command_buffer->owner->layer nextDrawable];
        if (drawable == nil || drawable.texture == nil) {
            return VKMTL_METAL_STATUS_NO_DRAWABLE;
        }

        id<MTLComputeCommandEncoder> encoder =
            [command_buffer->command_buffer computeCommandEncoder];
        if (encoder == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        [encoder setComputePipelineState:pipeline->pipeline];
        [encoder setTexture:drawable.texture atIndex:0];
        if (![encoder respondsToSelector:@selector(setAccelerationStructure:atBufferIndex:)]) {
            [encoder endEncoding];
            return VKMTL_METAL_STATUS_UNSUPPORTED;
        }
        [encoder setAccelerationStructure:acceleration_structure->acceleration_structure atBufferIndex:0];
        if (inline_data != NULL && inline_data_len != 0) {
            [encoder setBytes:inline_data length:inline_data_len atIndex:inline_data_index];
        }

        const NSUInteger threadgroup_width = 8;
        const NSUInteger threadgroup_height = 8;
        MTLSize grid_size = MTLSizeMake(width, height, 1);
        MTLSize threadgroup_size = MTLSizeMake(threadgroup_width, threadgroup_height, 1);
        [encoder dispatchThreads:grid_size threadsPerThreadgroup:threadgroup_size];
        [encoder endEncoding];

        [command_buffer->drawable release];
        command_buffer->drawable = [drawable retain];
        [command_buffer->command_buffer presentDrawable:drawable];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_command_buffer *command_buffer,
    const vkmtl_metal_render_pass_color_attachment *color_attachments,
    size_t color_attachment_count,
    unsigned int use_depth,
    vkmtl_metal_texture_view *depth_texture_view,
    float clear_depth,
    unsigned int depth_load_action,
    unsigned int depth_store_action,
    unsigned int use_stencil,
    unsigned int clear_stencil,
    unsigned int stencil_load_action,
    unsigned int stencil_store_action,
    vkmtl_metal_query_set *occlusion_query_set,
    vkmtl_metal_render_command_encoder **out_encoder
) {
    if (out_encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    *out_encoder = NULL;

    if (owner == NULL ||
        owner->layer == nil ||
        command_buffer == NULL ||
        command_buffer->command_buffer == nil ||
        color_attachments == NULL ||
        color_attachment_count == 0 ||
        color_attachment_count > 4 ||
        (occlusion_query_set != NULL &&
            (occlusion_query_set->query_type != VKMTL_METAL_QUERY_TYPE_OCCLUSION ||
             occlusion_query_set->result_buffer == nil ||
             occlusion_query_set->count == 0))) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        id<CAMetalDrawable> drawable = nil;
        MTLRenderPassDescriptor *descriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        if (descriptor == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        for (size_t i = 0; i < color_attachment_count; i += 1) {
            const vkmtl_metal_render_pass_color_attachment attachment = color_attachments[i];
            id<MTLTexture> color_texture = nil;
            if (attachment.texture_view != NULL) {
                color_texture = attachment.texture_view->texture;
                if (color_texture == nil) {
                    return VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW;
                }
            } else {
                if (i != 0 || color_attachment_count != 1) {
                    return VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW;
                }
                drawable = [owner->layer nextDrawable];
                if (drawable == nil) {
                    return VKMTL_METAL_STATUS_NO_DRAWABLE;
                }
                color_texture = drawable.texture;
            }

            descriptor.colorAttachments[i].texture = color_texture;
            descriptor.colorAttachments[i].loadAction = vkmtl_load_action(attachment.load_action);
            if (attachment.resolve_texture_view != NULL) {
                if (attachment.texture_view == NULL ||
                    attachment.texture_view->sample_count <= 1 ||
                    attachment.resolve_texture_view->texture == nil ||
                    attachment.resolve_texture_view->sample_count != 1) {
                    return VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW;
                }
                descriptor.colorAttachments[i].resolveTexture = attachment.resolve_texture_view->texture;
                descriptor.colorAttachments[i].storeAction = attachment.store_action == 1
                    ? MTLStoreActionStoreAndMultisampleResolve
                    : MTLStoreActionMultisampleResolve;
            } else {
                descriptor.colorAttachments[i].storeAction = vkmtl_store_action(attachment.store_action);
            }
            descriptor.colorAttachments[i].clearColor =
                MTLClearColorMake(
                    attachment.clear_red,
                    attachment.clear_green,
                    attachment.clear_blue,
                    attachment.clear_alpha
                );
        }

        if (use_depth != 0) {
            id<MTLTexture> depth_texture =
                depth_texture_view != NULL ? depth_texture_view->texture : owner->depth_texture;
            if (depth_texture == nil) {
                return VKMTL_METAL_STATUS_INVALID_COMMAND;
            }
            descriptor.depthAttachment.texture = depth_texture;
            descriptor.depthAttachment.loadAction = vkmtl_load_action(depth_load_action);
            descriptor.depthAttachment.storeAction = vkmtl_store_action(depth_store_action);
            descriptor.depthAttachment.clearDepth = clear_depth;
            if (use_stencil != 0) {
                if (depth_texture.pixelFormat != MTLPixelFormatDepth32Float_Stencil8) {
                    return VKMTL_METAL_STATUS_INVALID_COMMAND;
                }
                descriptor.stencilAttachment.texture = depth_texture;
                descriptor.stencilAttachment.loadAction = vkmtl_load_action(stencil_load_action);
                descriptor.stencilAttachment.storeAction = vkmtl_store_action(stencil_store_action);
                descriptor.stencilAttachment.clearStencil = clear_stencil;
            }
        }

        id<MTLBuffer> visibility_scratch_buffer = nil;
        unsigned char *visibility_slots = NULL;
        if (occlusion_query_set != NULL) {
            const NSUInteger visibility_byte_count =
                occlusion_query_set->count * sizeof(uint64_t);
            visibility_scratch_buffer = [owner->device
                newBufferWithLength:visibility_byte_count
                          options:MTLResourceStorageModeShared];
            if (visibility_scratch_buffer == nil) {
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
            memset([visibility_scratch_buffer contents], 0, visibility_byte_count);
            visibility_slots = calloc(occlusion_query_set->count, sizeof(unsigned char));
            if (visibility_slots == NULL) {
                [visibility_scratch_buffer release];
                return VKMTL_METAL_STATUS_COMMAND_FAILED;
            }
            descriptor.visibilityResultBuffer = visibility_scratch_buffer;
            if (@available(macOS 26.0, *)) {
                descriptor.visibilityResultType = MTLVisibilityResultTypeReset;
            }
        }

        id<MTLRenderCommandEncoder> encoder =
            [command_buffer->command_buffer renderCommandEncoderWithDescriptor:descriptor];
        if (encoder == nil) {
            free(visibility_slots);
            [visibility_scratch_buffer release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        [command_buffer->drawable release];
        command_buffer->drawable = drawable != nil ? [drawable retain] : nil;

        vkmtl_metal_render_command_encoder *render_encoder =
            calloc(1, sizeof(vkmtl_metal_render_command_encoder));
        if (render_encoder == NULL) {
            [encoder endEncoding];
            free(visibility_slots);
            [visibility_scratch_buffer release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        render_encoder->encoder = [encoder retain];
        render_encoder->command_buffer = [command_buffer->command_buffer retain];
        render_encoder->visibility_scratch_buffer = visibility_scratch_buffer;
        render_encoder->visibility_result_buffer =
            occlusion_query_set != NULL ? [occlusion_query_set->result_buffer retain] : nil;
        render_encoder->visibility_slots = visibility_slots;
        render_encoder->visibility_slot_count =
            occlusion_query_set != NULL ? occlusion_query_set->count : 0;
        *out_encoder = render_encoder;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_render_command_encoder_destroy(vkmtl_metal_render_command_encoder *encoder) {
    if (encoder == NULL) {
        return;
    }

    @autoreleasepool {
        [encoder->visibility_result_buffer release];
        [encoder->visibility_scratch_buffer release];
        [encoder->command_buffer release];
        free(encoder->visibility_slots);
        [encoder->index_buffer release];
        [encoder->encoder release];
        free(encoder);
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_label(
    vkmtl_metal_render_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    if (encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_set_objc_label(
        encoder->encoder,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_push_debug_group(
    vkmtl_metal_render_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    if (encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_push_objc_debug_group(
        encoder->encoder,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_pop_debug_group(
    vkmtl_metal_render_command_encoder *encoder
) {
    if (encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_pop_objc_debug_group(
        encoder->encoder,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_insert_debug_signpost(
    vkmtl_metal_render_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    if (encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_insert_objc_debug_signpost(
        encoder->encoder,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_pipeline(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_render_pipeline_state *pipeline
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        pipeline == NULL ||
        pipeline->pipeline == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setRenderPipelineState:pipeline->pipeline];
        if (pipeline->depth_stencil != nil) {
            [encoder->encoder setDepthStencilState:pipeline->depth_stencil];
        }
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_triangle_fill_mode(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_triangle_fill_mode fill_mode
) {
    if (encoder == NULL || encoder->encoder == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setTriangleFillMode:vkmtl_triangle_fill_mode(fill_mode)];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_vertex_buffer(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_buffer *buffer,
    unsigned int index,
    size_t offset
) {
    if (encoder == NULL || encoder->encoder == nil || buffer == NULL || buffer->buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setVertexBuffer:buffer->buffer offset:offset atIndex:index];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_vertex_bytes(
    vkmtl_metal_render_command_encoder *encoder,
    const void *bytes,
    size_t byte_count,
    unsigned int index
) {
    if (encoder == NULL || encoder->encoder == nil || bytes == NULL || byte_count == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setVertexBytes:bytes length:byte_count atIndex:index];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_fragment_buffer(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_buffer *buffer,
    unsigned int index,
    size_t offset
) {
    if (encoder == NULL || encoder->encoder == nil || buffer == NULL || buffer->buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setFragmentBuffer:buffer->buffer offset:offset atIndex:index];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_fragment_bytes(
    vkmtl_metal_render_command_encoder *encoder,
    const void *bytes,
    size_t byte_count,
    unsigned int index
) {
    if (encoder == NULL || encoder->encoder == nil || bytes == NULL || byte_count == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setFragmentBytes:bytes length:byte_count atIndex:index];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_index_buffer(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_buffer *buffer
) {
    if (encoder == NULL || encoder->encoder == nil || buffer == NULL || buffer->buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->index_buffer release];
        encoder->index_buffer = [buffer->buffer retain];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_vertex_texture(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_texture_view *texture_view,
    unsigned int index
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        texture_view == NULL ||
        texture_view->texture == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setVertexTexture:texture_view->texture atIndex:index];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_fragment_texture(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_texture_view *texture_view,
    unsigned int index
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        texture_view == NULL ||
        texture_view->texture == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setFragmentTexture:texture_view->texture atIndex:index];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_vertex_sampler_state(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_sampler_state *sampler,
    unsigned int index
) {
    if (encoder == NULL || encoder->encoder == nil || sampler == NULL || sampler->sampler == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setVertexSamplerState:sampler->sampler atIndex:index];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_fragment_sampler_state(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_sampler_state *sampler,
    unsigned int index
) {
    if (encoder == NULL || encoder->encoder == nil || sampler == NULL || sampler->sampler == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setFragmentSamplerState:sampler->sampler atIndex:index];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_resource_table(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_resource_table *table,
    unsigned int index,
    unsigned int visibility
) {
    if (encoder == NULL || encoder->encoder == nil || encoder->ended || table == NULL || table->buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    if ((visibility & 1u) != 0) [encoder->encoder setVertexBuffer:table->buffer offset:0 atIndex:index];
    if ((visibility & 2u) != 0) [encoder->encoder setFragmentBuffer:table->buffer offset:0 atIndex:index];

    MTLRenderStages stages = 0;
    if ((visibility & 1u) != 0) stages |= MTLRenderStageVertex;
    if ((visibility & 2u) != 0) stages |= MTLRenderStageFragment;
    for (NSUInteger i = 0; i < table->resource_count; ++i) {
        if (table->resources[i] == nil) continue;
        [encoder->encoder useResource:table->resources[i] usage:table->usages[i] stages:stages];
    }
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_execute_indirect_commands(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_indirect_command_buffer *buffer,
    unsigned int location,
    unsigned int count
) {
    if (encoder == NULL || encoder->encoder == nil || encoder->ended || buffer == NULL || buffer->kind != 0 ||
        count == 0 || (NSUInteger)location + count > buffer->max_command_count) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    [encoder->encoder executeCommandsInBuffer:buffer->buffer withRange:NSMakeRange(location, count)];
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_viewport(
    vkmtl_metal_render_command_encoder *encoder,
    double x,
    double y,
    double width,
    double height,
    double near_z,
    double far_z
) {
    if (encoder == NULL || encoder->encoder == nil || width <= 0 || height <= 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        MTLViewport viewport = {
            .originX = x,
            .originY = y,
            .width = width,
            .height = height,
            .znear = near_z,
            .zfar = far_z,
        };
        [encoder->encoder setViewport:viewport];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_scissor_rect(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int x,
    unsigned int y,
    unsigned int width,
    unsigned int height
) {
    if (encoder == NULL || encoder->encoder == nil || width == 0 || height == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        MTLScissorRect rect = {
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
        [encoder->encoder setScissorRect:rect];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_blend_color(
    vkmtl_metal_render_command_encoder *encoder,
    float red,
    float green,
    float blue,
    float alpha
) {
    if (encoder == NULL || encoder->encoder == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setBlendColorRed:red green:green blue:blue alpha:alpha];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_stencil_reference(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int reference
) {
    if (encoder == NULL || encoder->encoder == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setStencilReferenceValue:reference];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_depth_bias(
    vkmtl_metal_render_command_encoder *encoder,
    float constant,
    float slope,
    float clamp
) {
    if (encoder == NULL || encoder->encoder == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setDepthBias:constant slopeScale:slope clamp:clamp];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_begin_occlusion_query(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int query_index
) {
    if (encoder == NULL || encoder->encoder == nil || encoder->ended != 0 ||
        query_set == NULL ||
        query_set->query_type != VKMTL_METAL_QUERY_TYPE_OCCLUSION ||
        query_set->result_buffer == nil ||
        query_set->result_buffer != encoder->visibility_result_buffer ||
        encoder->visibility_scratch_buffer == nil ||
        encoder->visibility_slots == NULL ||
        (NSUInteger)query_index >= encoder->visibility_slot_count ||
        encoder->visibility_active != 0) {
        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }

    @autoreleasepool {
        [encoder->encoder
            setVisibilityResultMode:MTLVisibilityResultModeBoolean
                              offset:(NSUInteger)query_index * sizeof(uint64_t)];
        encoder->visibility_slots[query_index] = 1;
        encoder->active_visibility_index = query_index;
        encoder->visibility_active = 1;
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_end_occlusion_query(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_query_set *query_set
) {
    if (encoder == NULL || encoder->encoder == nil || encoder->ended != 0 ||
        query_set == NULL ||
        query_set->query_type != VKMTL_METAL_QUERY_TYPE_OCCLUSION ||
        query_set->result_buffer != encoder->visibility_result_buffer ||
        encoder->visibility_active == 0) {
        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }

    @autoreleasepool {
        [encoder->encoder setVisibilityResultMode:MTLVisibilityResultModeDisabled offset:0];
        vkmtl_query_set_record_writer(
            query_set,
            encoder->active_visibility_index,
            encoder->command_buffer
        );
        encoder->visibility_active = 0;
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_write_timestamp(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int query_index
) {
    if (encoder == NULL || encoder->encoder == nil || encoder->ended != 0 ||
        !vkmtl_timestamp_query_is_valid(query_set, query_index)) {
        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }

    if (@available(macOS 10.15, *)) {
        [encoder->encoder
            sampleCountersInBuffer:query_set->counter_sample_buffer
                    atSampleIndex:query_index
                       withBarrier:YES];
        vkmtl_query_set_record_writer(query_set, query_index, encoder->command_buffer);
        return VKMTL_METAL_STATUS_OK;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_draw_primitives(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int primitive_type,
    unsigned int vertex_start,
    unsigned int vertex_count,
    unsigned int instance_count,
    unsigned int base_instance
) {
    if (encoder == NULL || encoder->encoder == nil || vertex_count == 0 || instance_count == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        if (base_instance == 0) {
            [encoder->encoder
                drawPrimitives:vkmtl_primitive_type(primitive_type)
                  vertexStart:vertex_start
                  vertexCount:vertex_count
                instanceCount:instance_count];
        } else {
            [encoder->encoder
                drawPrimitives:vkmtl_primitive_type(primitive_type)
                  vertexStart:vertex_start
                  vertexCount:vertex_count
                instanceCount:instance_count
                 baseInstance:base_instance];
        }
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_draw_indexed_primitives(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int primitive_type,
    unsigned int index_type,
    unsigned int index_count,
    size_t index_buffer_offset,
    unsigned int instance_count,
    int base_vertex,
    unsigned int base_instance
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        encoder->index_buffer == nil ||
        index_count == 0 ||
        instance_count == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    MTLIndexType metal_index_type = index_type == 32 ? MTLIndexTypeUInt32 : MTLIndexTypeUInt16;

    @autoreleasepool {
        if (base_vertex == 0 && base_instance == 0) {
            [encoder->encoder
                drawIndexedPrimitives:vkmtl_primitive_type(primitive_type)
                           indexCount:index_count
                            indexType:metal_index_type
                          indexBuffer:encoder->index_buffer
                    indexBufferOffset:index_buffer_offset
                        instanceCount:instance_count];
        } else {
            [encoder->encoder
                drawIndexedPrimitives:vkmtl_primitive_type(primitive_type)
                           indexCount:index_count
                            indexType:metal_index_type
                          indexBuffer:encoder->index_buffer
                    indexBufferOffset:index_buffer_offset
                        instanceCount:instance_count
                          baseVertex:base_vertex
                        baseInstance:base_instance];
        }
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_draw_primitives_indirect(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int primitive_type,
    vkmtl_metal_buffer *indirect_buffer,
    size_t indirect_buffer_offset
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        indirect_buffer == NULL ||
        indirect_buffer->buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder
            drawPrimitives:vkmtl_primitive_type(primitive_type)
            indirectBuffer:indirect_buffer->buffer
      indirectBufferOffset:indirect_buffer_offset];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_draw_indexed_primitives_indirect(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int primitive_type,
    unsigned int index_type,
    vkmtl_metal_buffer *indirect_buffer,
    size_t indirect_buffer_offset
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        encoder->index_buffer == nil ||
        indirect_buffer == NULL ||
        indirect_buffer->buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    MTLIndexType metal_index_type = index_type == 32 ? MTLIndexTypeUInt32 : MTLIndexTypeUInt16;

    @autoreleasepool {
        [encoder->encoder
            drawIndexedPrimitives:vkmtl_primitive_type(primitive_type)
                        indexType:metal_index_type
                      indexBuffer:encoder->index_buffer
                indexBufferOffset:0
                   indirectBuffer:indirect_buffer->buffer
             indirectBufferOffset:indirect_buffer_offset];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_end_encoding(
    vkmtl_metal_render_command_encoder *encoder
) {
    if (encoder == NULL || encoder->encoder == nil || encoder->ended != 0 ||
        encoder->visibility_active != 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder endEncoding];
        encoder->ended = 1;

        if (encoder->visibility_slots == NULL ||
            encoder->visibility_scratch_buffer == nil ||
            encoder->visibility_result_buffer == nil) {
            return VKMTL_METAL_STATUS_OK;
        }

        NSUInteger first_used = encoder->visibility_slot_count;
        for (NSUInteger i = 0; i < encoder->visibility_slot_count; i += 1) {
            if (encoder->visibility_slots[i] != 0) {
                first_used = i;
                break;
            }
        }
        if (first_used == encoder->visibility_slot_count) {
            return VKMTL_METAL_STATUS_OK;
        }

        id<MTLBlitCommandEncoder> blit = [encoder->command_buffer blitCommandEncoder];
        if (blit == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        NSUInteger range_start = first_used;
        NSUInteger i = first_used;
        while (i < encoder->visibility_slot_count) {
            while (i < encoder->visibility_slot_count && encoder->visibility_slots[i] != 0) {
                i += 1;
            }
            const NSUInteger byte_offset = range_start * sizeof(uint64_t);
            const NSUInteger byte_count = (i - range_start) * sizeof(uint64_t);
            [blit copyFromBuffer:encoder->visibility_scratch_buffer
                    sourceOffset:byte_offset
                        toBuffer:encoder->visibility_result_buffer
               destinationOffset:byte_offset
                            size:byte_count];
            while (i < encoder->visibility_slot_count && encoder->visibility_slots[i] == 0) {
                i += 1;
            }
            range_start = i;
        }
        [blit endEncoding];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_create(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_compute_command_encoder **out_encoder
) {
    if (out_encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    *out_encoder = NULL;

    if (command_buffer == NULL || command_buffer->command_buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        id<MTLComputeCommandEncoder> encoder = [command_buffer->command_buffer computeCommandEncoder];
        if (encoder == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        vkmtl_metal_compute_command_encoder *compute_encoder =
            calloc(1, sizeof(vkmtl_metal_compute_command_encoder));
        if (compute_encoder == NULL) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        compute_encoder->encoder = [encoder retain];
        compute_encoder->command_buffer = [command_buffer->command_buffer retain];
        *out_encoder = compute_encoder;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_compute_command_encoder_destroy(vkmtl_metal_compute_command_encoder *encoder) {
    if (encoder == NULL) {
        return;
    }

    @autoreleasepool {
        [encoder->command_buffer release];
        [encoder->encoder release];
        free(encoder);
    }
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_label(
    vkmtl_metal_compute_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    if (encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_set_objc_label(
        encoder->encoder,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_push_debug_group(
    vkmtl_metal_compute_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    if (encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_push_objc_debug_group(
        encoder->encoder,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_pop_debug_group(
    vkmtl_metal_compute_command_encoder *encoder
) {
    if (encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_pop_objc_debug_group(
        encoder->encoder,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_insert_debug_signpost(
    vkmtl_metal_compute_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    if (encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_insert_objc_debug_signpost(
        encoder->encoder,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_pipeline(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_compute_pipeline_state *pipeline
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        pipeline == NULL ||
        pipeline->pipeline == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setComputePipelineState:pipeline->pipeline];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_buffer(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_buffer *buffer,
    unsigned int index,
    size_t offset
) {
    if (encoder == NULL || encoder->encoder == nil || buffer == NULL || buffer->buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setBuffer:buffer->buffer offset:offset atIndex:index];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_bytes(
    vkmtl_metal_compute_command_encoder *encoder,
    const void *bytes,
    size_t byte_count,
    unsigned int index
) {
    if (encoder == NULL || encoder->encoder == nil || bytes == NULL || byte_count == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setBytes:bytes length:byte_count atIndex:index];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_texture(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_texture_view *texture_view,
    unsigned int index
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        texture_view == NULL ||
        texture_view->texture == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setTexture:texture_view->texture atIndex:index];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_sampler_state(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_sampler_state *sampler,
    unsigned int index
) {
    if (encoder == NULL || encoder->encoder == nil || sampler == NULL || sampler->sampler == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder setSamplerState:sampler->sampler atIndex:index];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_resource_table(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_resource_table *table,
    unsigned int index
) {
    if (encoder == NULL || encoder->encoder == nil || table == NULL || table->buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    [encoder->encoder setBuffer:table->buffer offset:0 atIndex:index];
    for (NSUInteger i = 0; i < table->resource_count; ++i) {
        if (table->resources[i] == nil) continue;
        [encoder->encoder useResource:table->resources[i] usage:table->usages[i]];
    }
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_execute_indirect_commands(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_indirect_command_buffer *buffer,
    unsigned int location,
    unsigned int count
) {
    if (encoder == NULL || encoder->encoder == nil || buffer == NULL || buffer->kind != 1 ||
        count == 0 || (NSUInteger)location + count > buffer->max_command_count) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    [encoder->encoder executeCommandsInBuffer:buffer->buffer withRange:NSMakeRange(location, count)];
    return VKMTL_METAL_STATUS_OK;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_dispatch_threadgroups(
    vkmtl_metal_compute_command_encoder *encoder,
    unsigned int threadgroup_count_x,
    unsigned int threadgroup_count_y,
    unsigned int threadgroup_count_z,
    unsigned int threads_per_threadgroup_x,
    unsigned int threads_per_threadgroup_y,
    unsigned int threads_per_threadgroup_z
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        threadgroup_count_x == 0 ||
        threadgroup_count_y == 0 ||
        threadgroup_count_z == 0 ||
        threads_per_threadgroup_x == 0 ||
        threads_per_threadgroup_y == 0 ||
        threads_per_threadgroup_z == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        MTLSize threadgroups =
            MTLSizeMake(threadgroup_count_x, threadgroup_count_y, threadgroup_count_z);
        MTLSize threads_per_threadgroup =
            MTLSizeMake(threads_per_threadgroup_x, threads_per_threadgroup_y, threads_per_threadgroup_z);
        [encoder->encoder dispatchThreadgroups:threadgroups threadsPerThreadgroup:threads_per_threadgroup];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_dispatch_threadgroups_indirect(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_buffer *indirect_buffer,
    size_t indirect_buffer_offset,
    unsigned int threads_per_threadgroup_x,
    unsigned int threads_per_threadgroup_y,
    unsigned int threads_per_threadgroup_z
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        indirect_buffer == NULL ||
        indirect_buffer->buffer == nil ||
        threads_per_threadgroup_x == 0 ||
        threads_per_threadgroup_y == 0 ||
        threads_per_threadgroup_z == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        MTLSize threads_per_threadgroup =
            MTLSizeMake(threads_per_threadgroup_x, threads_per_threadgroup_y, threads_per_threadgroup_z);
        [encoder->encoder dispatchThreadgroupsWithIndirectBuffer:indirect_buffer->buffer
                                            indirectBufferOffset:indirect_buffer_offset
                                           threadsPerThreadgroup:threads_per_threadgroup];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_write_timestamp(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int query_index
) {
    if (encoder == NULL || encoder->encoder == nil ||
        !vkmtl_timestamp_query_is_valid(query_set, query_index)) {
        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }

    if (@available(macOS 10.15, *)) {
        [encoder->encoder
            sampleCountersInBuffer:query_set->counter_sample_buffer
                    atSampleIndex:query_index
                       withBarrier:YES];
        vkmtl_query_set_record_writer(query_set, query_index, encoder->command_buffer);
        return VKMTL_METAL_STATUS_OK;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_end_encoding(
    vkmtl_metal_compute_command_encoder *encoder
) {
    if (encoder == NULL || encoder->encoder == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder endEncoding];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_create(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_blit_command_encoder **out_encoder
) {
    if (out_encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    *out_encoder = NULL;

    if (command_buffer == NULL || command_buffer->command_buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        id<MTLBlitCommandEncoder> encoder = [command_buffer->command_buffer blitCommandEncoder];
        if (encoder == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        vkmtl_metal_blit_command_encoder *blit_encoder =
            calloc(1, sizeof(vkmtl_metal_blit_command_encoder));
        if (blit_encoder == NULL) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        blit_encoder->encoder = [encoder retain];
        blit_encoder->command_buffer = [command_buffer->command_buffer retain];
        *out_encoder = blit_encoder;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_blit_command_encoder_destroy(vkmtl_metal_blit_command_encoder *encoder) {
    if (encoder == NULL) {
        return;
    }

    @autoreleasepool {
        [encoder->command_buffer release];
        [encoder->encoder release];
        free(encoder);
    }
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_set_label(
    vkmtl_metal_blit_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    if (encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_set_objc_label(
        encoder->encoder,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_push_debug_group(
    vkmtl_metal_blit_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    if (encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_push_objc_debug_group(
        encoder->encoder,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_pop_debug_group(
    vkmtl_metal_blit_command_encoder *encoder
) {
    if (encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_pop_objc_debug_group(
        encoder->encoder,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_insert_debug_signpost(
    vkmtl_metal_blit_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    if (encoder == NULL) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }
    return vkmtl_insert_objc_debug_signpost(
        encoder->encoder,
        label,
        label_len,
        VKMTL_METAL_STATUS_INVALID_COMMAND
    );
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_copy_buffer_to_buffer(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_buffer *source,
    vkmtl_metal_buffer *destination,
    size_t source_offset,
    size_t destination_offset,
    size_t size
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        source == NULL ||
        source->buffer == nil ||
        destination == NULL ||
        destination->buffer == nil ||
        size == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder
              copyFromBuffer:source->buffer
                sourceOffset:source_offset
                    toBuffer:destination->buffer
           destinationOffset:destination_offset
                        size:size];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_write_timestamp(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int query_index
) {
    if (encoder == NULL || encoder->encoder == nil ||
        !vkmtl_timestamp_query_is_valid(query_set, query_index)) {
        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }

    if (@available(macOS 10.15, *)) {
        [encoder->encoder
            sampleCountersInBuffer:query_set->counter_sample_buffer
                    atSampleIndex:query_index
                       withBarrier:YES];
        vkmtl_query_set_record_writer(query_set, query_index, encoder->command_buffer);
        return VKMTL_METAL_STATUS_OK;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_resolve_query_set(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int first_query,
    unsigned int query_count,
    vkmtl_metal_buffer *destination,
    size_t destination_offset
) {
    if (encoder == NULL || encoder->encoder == nil ||
        !vkmtl_query_range_is_valid(query_set, first_query, query_count) ||
        destination == NULL || destination->buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }

    const NSUInteger byte_count = (NSUInteger)query_count * sizeof(uint64_t);
    if (destination_offset > destination->length ||
        byte_count > destination->length - destination_offset) {
        return VKMTL_METAL_STATUS_INVALID_BUFFER;
    }

    @autoreleasepool {
        if (query_set->query_type == VKMTL_METAL_QUERY_TYPE_OCCLUSION) {
            if (query_set->result_buffer == nil) {
                return VKMTL_METAL_STATUS_INVALID_QUERY;
            }
            [encoder->encoder
                  copyFromBuffer:query_set->result_buffer
                    sourceOffset:(NSUInteger)first_query * sizeof(uint64_t)
                        toBuffer:destination->buffer
               destinationOffset:destination_offset
                            size:byte_count];
            return VKMTL_METAL_STATUS_OK;
        }

        if (query_set->query_type == VKMTL_METAL_QUERY_TYPE_TIMESTAMP) {
            if (@available(macOS 10.15, *)) {
                if (query_set->counter_sample_buffer == nil ||
                    query_set->counter_resolve_buffer == nil) {
                    return VKMTL_METAL_STATUS_INVALID_QUERY;
                }
                [encoder->encoder
                    resolveCounters:query_set->counter_sample_buffer
                            inRange:NSMakeRange(first_query, query_count)
                  destinationBuffer:query_set->counter_resolve_buffer
                  destinationOffset:0];
                [encoder->encoder
                      copyFromBuffer:query_set->counter_resolve_buffer
                        sourceOffset:0
                            toBuffer:destination->buffer
                   destinationOffset:destination_offset
                                size:byte_count];
                return VKMTL_METAL_STATUS_OK;
            }
            return VKMTL_METAL_STATUS_UNSUPPORTED;
        }

        return VKMTL_METAL_STATUS_INVALID_QUERY;
    }
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_copy_buffer_to_texture(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_buffer *source,
    vkmtl_metal_texture *destination,
    size_t buffer_offset,
    size_t bytes_per_row,
    size_t bytes_per_image,
    unsigned int x,
    unsigned int y,
    unsigned int z,
    unsigned int width,
    unsigned int height,
    unsigned int depth,
    unsigned int mip_level,
    unsigned int slice
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        source == NULL ||
        source->buffer == nil ||
        destination == NULL ||
        destination->texture == nil ||
        width == 0 ||
        height == 0 ||
        depth == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder
             copyFromBuffer:source->buffer
               sourceOffset:buffer_offset
          sourceBytesPerRow:bytes_per_row
        sourceBytesPerImage:bytes_per_image
                 sourceSize:MTLSizeMake(width, height, depth)
                  toTexture:destination->texture
           destinationSlice:slice
           destinationLevel:mip_level
          destinationOrigin:MTLOriginMake(x, y, z)];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_copy_texture_to_buffer(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_texture *source,
    vkmtl_metal_buffer *destination,
    size_t buffer_offset,
    size_t bytes_per_row,
    size_t bytes_per_image,
    unsigned int x,
    unsigned int y,
    unsigned int z,
    unsigned int width,
    unsigned int height,
    unsigned int depth,
    unsigned int mip_level,
    unsigned int slice
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        source == NULL ||
        source->texture == nil ||
        destination == NULL ||
        destination->buffer == nil ||
        width == 0 ||
        height == 0 ||
        depth == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder
            copyFromTexture:source->texture
                sourceSlice:slice
                sourceLevel:mip_level
               sourceOrigin:MTLOriginMake(x, y, z)
                 sourceSize:MTLSizeMake(width, height, depth)
                   toBuffer:destination->buffer
          destinationOffset:buffer_offset
     destinationBytesPerRow:bytes_per_row
   destinationBytesPerImage:bytes_per_image];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_copy_texture_to_texture(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_texture *source,
    vkmtl_metal_texture *destination,
    unsigned int source_x,
    unsigned int source_y,
    unsigned int source_z,
    unsigned int width,
    unsigned int height,
    unsigned int depth,
    unsigned int source_mip_level,
    unsigned int source_slice,
    unsigned int destination_x,
    unsigned int destination_y,
    unsigned int destination_z,
    unsigned int destination_mip_level,
    unsigned int destination_slice
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        source == NULL ||
        source->texture == nil ||
        destination == NULL ||
        destination->texture == nil ||
        width == 0 ||
        height == 0 ||
        depth == 0) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder
            copyFromTexture:source->texture
                sourceSlice:source_slice
                sourceLevel:source_mip_level
               sourceOrigin:MTLOriginMake(source_x, source_y, source_z)
                 sourceSize:MTLSizeMake(width, height, depth)
                  toTexture:destination->texture
           destinationSlice:destination_slice
           destinationLevel:destination_mip_level
          destinationOrigin:MTLOriginMake(destination_x, destination_y, destination_z)];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_fill_buffer(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_buffer *buffer,
    size_t offset,
    size_t size,
    unsigned int value
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        buffer == NULL ||
        buffer->buffer == nil ||
        size == 0 ||
        offset > buffer->length ||
        size > buffer->length - offset ||
        value > 0xffu) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder
            fillBuffer:buffer->buffer
                 range:NSMakeRange(offset, size)
                 value:(uint8_t)value];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_generate_mipmaps(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_texture *texture
) {
    if (encoder == NULL ||
        encoder->encoder == nil ||
        texture == NULL ||
        texture->texture == nil ||
        texture->mip_level_count < 2) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder generateMipmapsForTexture:texture->texture];
        return VKMTL_METAL_STATUS_OK;
    }
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_end_encoding(
    vkmtl_metal_blit_command_encoder *encoder
) {
    if (encoder == NULL || encoder->encoder == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder endEncoding];
        return VKMTL_METAL_STATUS_OK;
    }
}

#endif
