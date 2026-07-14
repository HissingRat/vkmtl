#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>
#import <Metal/Metal.h>

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void *vkmtl_example_metal_buffer_create(size_t length, uint8_t value) {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil || length == 0) return NULL;
        id<MTLBuffer> buffer = [device newBufferWithLength:length
                                                   options:MTLResourceStorageModeShared];
        if (buffer == nil) return NULL;
        memset(buffer.contents, value, length);
        return (void *)buffer;
    }
}

void vkmtl_example_objc_release(void *object) {
    if (object == NULL) return;
    @autoreleasepool {
        [(id)object release];
    }
}

void *vkmtl_example_metal_texture_create(uint32_t width, uint32_t height, uint8_t value) {
    if (width == 0 || height == 0) return NULL;
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) return NULL;
        MTLTextureDescriptor *descriptor =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                               width:width
                                                              height:height
                                                           mipmapped:NO];
        descriptor.storageMode = MTLStorageModeShared;
        descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsagePixelFormatView;
        id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
        if (texture == nil) return NULL;

        const size_t bytes_per_row = (size_t)width * 4;
        const size_t byte_count = bytes_per_row * height;
        void *bytes = malloc(byte_count);
        if (bytes == NULL) {
            [texture release];
            return NULL;
        }
        memset(bytes, value, byte_count);
        [texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
                   mipmapLevel:0
                     withBytes:bytes
                   bytesPerRow:bytes_per_row];
        free(bytes);
        return (void *)texture;
    }
}

void *vkmtl_example_iosurface_create(uint32_t width, uint32_t height, uint8_t value) {
    if (width == 0 || height == 0) return NULL;
    @autoreleasepool {
        const size_t bytes_per_row = (size_t)width * 4;
        NSDictionary *properties = @{
            (NSString *)kIOSurfaceWidth: @(width),
            (NSString *)kIOSurfaceHeight: @(height),
            (NSString *)kIOSurfaceBytesPerElement: @4,
            (NSString *)kIOSurfaceBytesPerRow: @(bytes_per_row),
            (NSString *)kIOSurfacePixelFormat: @(0x42475241u),
        };
        IOSurfaceRef surface = IOSurfaceCreate((CFDictionaryRef)properties);
        if (surface == NULL) return NULL;
        if (IOSurfaceLock(surface, 0, NULL) != kIOReturnSuccess) {
            CFRelease(surface);
            return NULL;
        }
        memset(IOSurfaceGetBaseAddress(surface), value, IOSurfaceGetAllocSize(surface));
        IOSurfaceUnlock(surface, 0, NULL);
        return (void *)surface;
    }
}

void vkmtl_example_iosurface_release(void *surface) {
    if (surface != NULL) CFRelease((IOSurfaceRef)surface);
}
