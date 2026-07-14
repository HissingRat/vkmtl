#include <stddef.h>
#include <stdint.h>

void *vkmtl_example_metal_buffer_create(size_t length, uint8_t value) {
    (void)length;
    (void)value;
    return NULL;
}

void vkmtl_example_objc_release(void *object) {
    (void)object;
}

void *vkmtl_example_metal_texture_create(uint32_t width, uint32_t height, uint8_t value) {
    (void)width;
    (void)height;
    (void)value;
    return NULL;
}

void *vkmtl_example_iosurface_create(uint32_t width, uint32_t height, uint8_t value) {
    (void)width;
    (void)height;
    (void)value;
    return NULL;
}

void vkmtl_example_iosurface_release(void *surface) {
    (void)surface;
}
