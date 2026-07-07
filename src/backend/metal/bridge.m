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
    CAMetalLayer *layer;
    NSView *view;
    id<MTLTexture> depth_texture;
    unsigned int width;
    unsigned int height;
};

struct vkmtl_metal_buffer {
    id<MTLBuffer> buffer;
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

struct vkmtl_metal_command_buffer {
    id<MTLCommandBuffer> command_buffer;
    id<CAMetalDrawable> drawable;
};

struct vkmtl_metal_render_command_encoder {
    id<MTLRenderCommandEncoder> encoder;
    id<MTLBuffer> index_buffer;
};

struct vkmtl_metal_blit_command_encoder {
    id<MTLBlitCommandEncoder> encoder;
};

struct vkmtl_metal_compute_command_encoder {
    id<MTLComputeCommandEncoder> encoder;
};

static NSString *vkmtl_new_string_from_bytes(const char *bytes, size_t len) {
    if (bytes == NULL) {
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
        if (queue == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        CAMetalLayer *layer = [CAMetalLayer layer];
        if (layer == nil) {
            [queue release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        layer.device = device;
        layer.pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
        layer.framebufferOnly = YES;
        layer.opaque = YES;
        layer.contentsScale = [window backingScaleFactor];
        layer.drawableSize = CGSizeMake(width, height);

        [view setWantsLayer:YES];
        [view setLayer:layer];

        vkmtl_metal_clear_screen *clear_screen = calloc(1, sizeof(vkmtl_metal_clear_screen));
        if (clear_screen == NULL) {
            [queue release];
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        clear_screen->device = [device retain];
        clear_screen->queue = queue;
        clear_screen->layer = [layer retain];
        clear_screen->view = [view retain];
        clear_screen->width = width;
        clear_screen->height = height;
        clear_screen->depth_texture = vkmtl_new_depth_texture(clear_screen->device, width, height);
        if (clear_screen->depth_texture == nil) {
            [clear_screen->view release];
            [clear_screen->layer release];
            [clear_screen->queue release];
            [clear_screen->device release];
            free(clear_screen);
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
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

static MTLResourceOptions vkmtl_storage_options(vkmtl_metal_storage_mode storage_mode) {
    switch (storage_mode) {
        case VKMTL_METAL_STORAGE_MODE_MANAGED:
            return MTLResourceStorageModeManaged;
        case VKMTL_METAL_STORAGE_MODE_PRIVATE:
            return MTLResourceStorageModePrivate;
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
        case VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM:
            return MTLPixelFormatBGRA8Unorm;
        case VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM_SRGB:
            return MTLPixelFormatBGRA8Unorm_sRGB;
        case VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UNORM:
            return MTLPixelFormatRGBA8Unorm;
        case VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UNORM_SRGB:
            return MTLPixelFormatRGBA8Unorm_sRGB;
        case VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT:
            return MTLPixelFormatDepth32Float;
        case VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT_STENCIL8:
            return MTLPixelFormatDepth32Float_Stencil8;
        case VKMTL_METAL_TEXTURE_FORMAT_INVALID:
        default:
            return MTLPixelFormatInvalid;
    }
}

static BOOL vkmtl_texture_format_has_stencil(vkmtl_metal_texture_format format) {
    return format == VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT_STENCIL8;
}

static BOOL vkmtl_texture_format_has_depth(vkmtl_metal_texture_format format) {
    return format == VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT ||
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
        case VKMTL_METAL_ADDRESS_MODE_REPEAT:
            return MTLSamplerAddressModeRepeat;
        case VKMTL_METAL_ADDRESS_MODE_MIRROR_REPEAT:
            return MTLSamplerAddressModeMirrorRepeat;
        case VKMTL_METAL_ADDRESS_MODE_CLAMP_TO_EDGE:
        default:
            return MTLSamplerAddressModeClampToEdge;
    }
}

static MTLVertexFormat vkmtl_vertex_format(vkmtl_metal_vertex_format format) {
    switch (format) {
        case VKMTL_METAL_VERTEX_FORMAT_FLOAT:
            return MTLVertexFormatFloat;
        case VKMTL_METAL_VERTEX_FORMAT_FLOAT2:
            return MTLVertexFormatFloat2;
        case VKMTL_METAL_VERTEX_FORMAT_FLOAT3:
            return MTLVertexFormatFloat3;
        case VKMTL_METAL_VERTEX_FORMAT_FLOAT4:
            return MTLVertexFormatFloat4;
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
    return usage;
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
        out_capabilities->max_threads_per_threadgroup_total =
            (unsigned int)(max_threads.width * max_threads.height * max_threads.depth);

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

        if ([device respondsToSelector:@selector(supportsRaytracing)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            NSNumber *value = [device performSelector:@selector(supportsRaytracing)];
#pragma clang diagnostic pop
            out_capabilities->ray_tracing = [value boolValue] ? 1u : 0u;
        }

        if ([device respondsToSelector:@selector(newBinaryArchiveWithDescriptor:error:)]) {
            out_capabilities->binary_archive = 1;
        }

        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_buffer_destroy(vkmtl_metal_buffer *buffer) {
    if (buffer == NULL) {
        return;
    }

    @autoreleasepool {
        [buffer->buffer release];
        free(buffer);
    }
}

size_t vkmtl_metal_buffer_length(const vkmtl_metal_buffer *buffer) {
    if (buffer == NULL) {
        return 0;
    }
    return buffer->length;
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
        void *contents = [buffer->buffer contents];
        if (contents == NULL) {
            return VKMTL_METAL_STATUS_INVALID_BUFFER;
        }

        memcpy(destination, (const unsigned char *)contents + offset, destination_len);
        return VKMTL_METAL_STATUS_OK;
    }
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
        MTLTextureDescriptor *descriptor = [[MTLTextureDescriptor alloc] init];
        if (descriptor == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        descriptor.textureType = vkmtl_texture_type(dimension, depth_or_array_layers, sample_count);
        descriptor.pixelFormat = vkmtl_texture_pixel_format(format);
        descriptor.width = width;
        descriptor.height = height;
        descriptor.depth = dimension == VKMTL_METAL_TEXTURE_DIMENSION_3D ? depth_or_array_layers : 1;
        descriptor.arrayLength = dimension == VKMTL_METAL_TEXTURE_DIMENSION_3D ? 1 : depth_or_array_layers;
        descriptor.mipmapLevelCount = mip_level_count;
        descriptor.sampleCount = sample_count;
        descriptor.storageMode = sample_count > 1 ? MTLStorageModePrivate : vkmtl_texture_storage_mode(storage_mode);
        descriptor.usage = vkmtl_texture_usage(usage_flags);

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
            view_texture = [texture->texture
                newTextureViewWithPixelFormat:vkmtl_texture_pixel_format(format)
                textureType:vkmtl_texture_view_type(dimension)
                levels:NSMakeRange(base_mip_level, mip_level_count)
                slices:NSMakeRange(base_array_layer, array_layer_count)];
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

vkmtl_metal_status vkmtl_metal_render_pipeline_state_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_shader_module *vertex_shader,
    const char *vertex_entry,
    size_t vertex_entry_len,
    vkmtl_metal_shader_module *fragment_shader,
    const char *fragment_entry,
    size_t fragment_entry_len,
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

        id<MTLFunction> vertex_function = [vertex_shader->library newFunctionWithName:vertex_name];
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

            fragment_function = [fragment_shader->library newFunctionWithName:fragment_name];
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

        NSError *error = nil;
        id<MTLRenderPipelineState> pipeline =
            [owner->device newRenderPipelineStateWithDescriptor:descriptor error:&error];
        [descriptor release];
        [fragment_function release];
        [vertex_function release];
        if (pipeline == nil) {
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
        compute_entry_len == 0) {
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

        id<MTLFunction> compute_function = [compute_shader->library newFunctionWithName:compute_name];
        [compute_name release];
        if (compute_function == nil) {
            return VKMTL_METAL_STATUS_INVALID_PIPELINE;
        }

        NSError *error = nil;
        id<MTLComputePipelineState> pipeline =
            [owner->device newComputePipelineStateWithFunction:compute_function error:&error];
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

vkmtl_metal_status vkmtl_metal_command_buffer_create(
    vkmtl_metal_clear_screen *owner,
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
        id<MTLCommandBuffer> metal_command_buffer = [owner->queue commandBuffer];
        if (metal_command_buffer == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        vkmtl_metal_command_buffer *command_buffer =
            calloc(1, sizeof(vkmtl_metal_command_buffer));
        if (command_buffer == NULL) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

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

vkmtl_metal_status vkmtl_metal_command_buffer_commit(
    vkmtl_metal_command_buffer *command_buffer
) {
    if (command_buffer == NULL || command_buffer->command_buffer == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [command_buffer->command_buffer commit];
        [command_buffer->command_buffer waitUntilCompleted];
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
        color_attachment_count > 4) {
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
            descriptor.colorAttachments[i].loadAction = MTLLoadActionClear;
            if (attachment.resolve_texture_view != NULL) {
                if (attachment.texture_view == NULL ||
                    attachment.texture_view->sample_count <= 1 ||
                    attachment.resolve_texture_view->texture == nil ||
                    attachment.resolve_texture_view->sample_count != 1) {
                    return VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW;
                }
                descriptor.colorAttachments[i].resolveTexture = attachment.resolve_texture_view->texture;
                descriptor.colorAttachments[i].storeAction = MTLStoreActionMultisampleResolve;
            } else {
                descriptor.colorAttachments[i].storeAction = MTLStoreActionStore;
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
            descriptor.depthAttachment.loadAction = MTLLoadActionClear;
            descriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
            descriptor.depthAttachment.clearDepth = clear_depth;
            if (depth_texture.pixelFormat == MTLPixelFormatDepth32Float_Stencil8) {
                descriptor.stencilAttachment.texture = depth_texture;
                descriptor.stencilAttachment.loadAction = MTLLoadActionClear;
                descriptor.stencilAttachment.storeAction = MTLStoreActionDontCare;
                descriptor.stencilAttachment.clearStencil = 0;
            }
        }

        id<MTLRenderCommandEncoder> encoder =
            [command_buffer->command_buffer renderCommandEncoderWithDescriptor:descriptor];
        if (encoder == nil) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        [command_buffer->drawable release];
        command_buffer->drawable = drawable != nil ? [drawable retain] : nil;

        vkmtl_metal_render_command_encoder *render_encoder =
            calloc(1, sizeof(vkmtl_metal_render_command_encoder));
        if (render_encoder == NULL) {
            return VKMTL_METAL_STATUS_COMMAND_FAILED;
        }

        render_encoder->encoder = [encoder retain];
        *out_encoder = render_encoder;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_render_command_encoder_destroy(vkmtl_metal_render_command_encoder *encoder) {
    if (encoder == NULL) {
        return;
    }

    @autoreleasepool {
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
    if (encoder == NULL || encoder->encoder == nil) {
        return VKMTL_METAL_STATUS_INVALID_COMMAND;
    }

    @autoreleasepool {
        [encoder->encoder endEncoding];
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
        *out_encoder = compute_encoder;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_compute_command_encoder_destroy(vkmtl_metal_compute_command_encoder *encoder) {
    if (encoder == NULL) {
        return;
    }

    @autoreleasepool {
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
        *out_encoder = blit_encoder;
        return VKMTL_METAL_STATUS_OK;
    }
}

void vkmtl_metal_blit_command_encoder_destroy(vkmtl_metal_blit_command_encoder *encoder) {
    if (encoder == NULL) {
        return;
    }

    @autoreleasepool {
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
