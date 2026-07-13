#ifndef VKMTL_METAL_BRIDGE_H
#define VKMTL_METAL_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct vkmtl_metal_probe vkmtl_metal_probe;
typedef struct vkmtl_metal_clear_screen vkmtl_metal_clear_screen;
typedef struct vkmtl_metal_buffer vkmtl_metal_buffer;
typedef struct vkmtl_metal_texture vkmtl_metal_texture;
typedef struct vkmtl_metal_texture_view vkmtl_metal_texture_view;
typedef struct vkmtl_metal_sampler_state vkmtl_metal_sampler_state;
typedef struct vkmtl_metal_resource_table vkmtl_metal_resource_table;
typedef struct vkmtl_metal_indirect_command_buffer vkmtl_metal_indirect_command_buffer;
typedef struct vkmtl_metal_shader_module vkmtl_metal_shader_module;
typedef struct vkmtl_metal_render_pipeline_state vkmtl_metal_render_pipeline_state;
typedef struct vkmtl_metal_compute_pipeline_state vkmtl_metal_compute_pipeline_state;
typedef struct vkmtl_metal_acceleration_structure vkmtl_metal_acceleration_structure;
typedef struct vkmtl_metal_ray_tracing_pipeline_state vkmtl_metal_ray_tracing_pipeline_state;
typedef struct vkmtl_metal_query_set vkmtl_metal_query_set;
typedef struct vkmtl_metal_shared_event vkmtl_metal_shared_event;
typedef struct vkmtl_metal_heap vkmtl_metal_heap;
typedef struct vkmtl_metal_command_buffer vkmtl_metal_command_buffer;
typedef struct vkmtl_metal_render_command_encoder vkmtl_metal_render_command_encoder;
typedef struct vkmtl_metal_blit_command_encoder vkmtl_metal_blit_command_encoder;
typedef struct vkmtl_metal_compute_command_encoder vkmtl_metal_compute_command_encoder;
typedef void (*vkmtl_metal_command_buffer_lifecycle_callback)(void *context, unsigned int status);

typedef enum vkmtl_metal_status {
    VKMTL_METAL_STATUS_OK = 0,
    VKMTL_METAL_STATUS_UNSUPPORTED = 1,
    VKMTL_METAL_STATUS_NO_DEVICE = 2,
    VKMTL_METAL_STATUS_NAME_BUFFER_TOO_SMALL = 3,
    VKMTL_METAL_STATUS_INVALID_SURFACE = 4,
    VKMTL_METAL_STATUS_NO_DRAWABLE = 5,
    VKMTL_METAL_STATUS_COMMAND_FAILED = 6,
    VKMTL_METAL_STATUS_INVALID_BUFFER = 7,
    VKMTL_METAL_STATUS_INVALID_TEXTURE = 8,
    VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW = 9,
    VKMTL_METAL_STATUS_INVALID_SAMPLER = 10,
    VKMTL_METAL_STATUS_INVALID_SHADER = 11,
    VKMTL_METAL_STATUS_INVALID_PIPELINE = 12,
    VKMTL_METAL_STATUS_INVALID_COMMAND = 13,
    VKMTL_METAL_STATUS_INVALID_QUERY = 14,
    VKMTL_METAL_STATUS_QUERY_NOT_READY = 15,
} vkmtl_metal_status;

typedef enum vkmtl_metal_query_type {
    VKMTL_METAL_QUERY_TYPE_OCCLUSION = 0,
    VKMTL_METAL_QUERY_TYPE_TIMESTAMP = 1,
} vkmtl_metal_query_type;

typedef enum vkmtl_metal_storage_mode {
    VKMTL_METAL_STORAGE_MODE_AUTOMATIC = 0,
    VKMTL_METAL_STORAGE_MODE_SHARED = 1,
    VKMTL_METAL_STORAGE_MODE_MANAGED = 2,
    VKMTL_METAL_STORAGE_MODE_PRIVATE = 3,
    VKMTL_METAL_STORAGE_MODE_MEMORYLESS = 4,
} vkmtl_metal_storage_mode;

typedef enum vkmtl_metal_texture_dimension {
    VKMTL_METAL_TEXTURE_DIMENSION_1D = 1,
    VKMTL_METAL_TEXTURE_DIMENSION_2D = 2,
    VKMTL_METAL_TEXTURE_DIMENSION_3D = 3,
} vkmtl_metal_texture_dimension;

typedef enum vkmtl_metal_texture_view_dimension {
    VKMTL_METAL_TEXTURE_VIEW_DIMENSION_1D = 1,
    VKMTL_METAL_TEXTURE_VIEW_DIMENSION_1D_ARRAY = 2,
    VKMTL_METAL_TEXTURE_VIEW_DIMENSION_2D = 3,
    VKMTL_METAL_TEXTURE_VIEW_DIMENSION_2D_ARRAY = 4,
    VKMTL_METAL_TEXTURE_VIEW_DIMENSION_3D = 5,
} vkmtl_metal_texture_view_dimension;

typedef enum vkmtl_metal_texture_format {
    VKMTL_METAL_TEXTURE_FORMAT_INVALID = 0,
    VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM = 1,
    VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM_SRGB = 2,
    VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UNORM = 3,
    VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UNORM_SRGB = 4,
    VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT = 5,
    VKMTL_METAL_TEXTURE_FORMAT_DEPTH32_FLOAT_STENCIL8 = 6,
    VKMTL_METAL_TEXTURE_FORMAT_R8_UNORM = 7,
    VKMTL_METAL_TEXTURE_FORMAT_RG8_UNORM = 8,
    VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UINT = 9,
    VKMTL_METAL_TEXTURE_FORMAT_RGBA8_SINT = 10,
    VKMTL_METAL_TEXTURE_FORMAT_R16_FLOAT = 11,
    VKMTL_METAL_TEXTURE_FORMAT_RG16_FLOAT = 12,
    VKMTL_METAL_TEXTURE_FORMAT_RGBA16_FLOAT = 13,
    VKMTL_METAL_TEXTURE_FORMAT_R32_FLOAT = 14,
    VKMTL_METAL_TEXTURE_FORMAT_RG32_FLOAT = 15,
    VKMTL_METAL_TEXTURE_FORMAT_RGBA32_FLOAT = 16,
    VKMTL_METAL_TEXTURE_FORMAT_R32_UINT = 17,
    VKMTL_METAL_TEXTURE_FORMAT_R32_SINT = 18,
    VKMTL_METAL_TEXTURE_FORMAT_DEPTH16_UNORM = 19,
    VKMTL_METAL_TEXTURE_FORMAT_STENCIL8 = 20,
} vkmtl_metal_texture_format;

typedef enum vkmtl_metal_compare_function {
    VKMTL_METAL_COMPARE_FUNCTION_NEVER = 0,
    VKMTL_METAL_COMPARE_FUNCTION_LESS = 1,
    VKMTL_METAL_COMPARE_FUNCTION_EQUAL = 2,
    VKMTL_METAL_COMPARE_FUNCTION_LESS_EQUAL = 3,
    VKMTL_METAL_COMPARE_FUNCTION_GREATER = 4,
    VKMTL_METAL_COMPARE_FUNCTION_NOT_EQUAL = 5,
    VKMTL_METAL_COMPARE_FUNCTION_GREATER_EQUAL = 6,
    VKMTL_METAL_COMPARE_FUNCTION_ALWAYS = 7,
} vkmtl_metal_compare_function;

typedef enum vkmtl_metal_stencil_operation {
    VKMTL_METAL_STENCIL_OPERATION_KEEP = 0,
    VKMTL_METAL_STENCIL_OPERATION_ZERO = 1,
    VKMTL_METAL_STENCIL_OPERATION_REPLACE = 2,
    VKMTL_METAL_STENCIL_OPERATION_INCREMENT_CLAMP = 3,
    VKMTL_METAL_STENCIL_OPERATION_DECREMENT_CLAMP = 4,
    VKMTL_METAL_STENCIL_OPERATION_INVERT = 5,
    VKMTL_METAL_STENCIL_OPERATION_INCREMENT_WRAP = 6,
    VKMTL_METAL_STENCIL_OPERATION_DECREMENT_WRAP = 7,
} vkmtl_metal_stencil_operation;

typedef enum vkmtl_metal_texture_usage {
    VKMTL_METAL_TEXTURE_USAGE_COPY_SOURCE = 1u << 0,
    VKMTL_METAL_TEXTURE_USAGE_COPY_DESTINATION = 1u << 1,
    VKMTL_METAL_TEXTURE_USAGE_SHADER_READ = 1u << 2,
    VKMTL_METAL_TEXTURE_USAGE_SHADER_WRITE = 1u << 3,
    VKMTL_METAL_TEXTURE_USAGE_RENDER_ATTACHMENT = 1u << 4,
    VKMTL_METAL_TEXTURE_USAGE_PIXEL_FORMAT_VIEW = 1u << 5,
} vkmtl_metal_texture_usage;

typedef enum vkmtl_metal_texture_swizzle {
    VKMTL_METAL_TEXTURE_SWIZZLE_ZERO = 0,
    VKMTL_METAL_TEXTURE_SWIZZLE_ONE = 1,
    VKMTL_METAL_TEXTURE_SWIZZLE_RED = 2,
    VKMTL_METAL_TEXTURE_SWIZZLE_GREEN = 3,
    VKMTL_METAL_TEXTURE_SWIZZLE_BLUE = 4,
    VKMTL_METAL_TEXTURE_SWIZZLE_ALPHA = 5,
} vkmtl_metal_texture_swizzle;

typedef enum vkmtl_metal_acceleration_structure_kind {
    VKMTL_METAL_ACCELERATION_STRUCTURE_KIND_BOTTOM_LEVEL = 0,
    VKMTL_METAL_ACCELERATION_STRUCTURE_KIND_TOP_LEVEL = 1,
} vkmtl_metal_acceleration_structure_kind;

typedef enum vkmtl_metal_filter {
    VKMTL_METAL_FILTER_NEAREST = 0,
    VKMTL_METAL_FILTER_LINEAR = 1,
} vkmtl_metal_filter;

typedef enum vkmtl_metal_mip_filter {
    VKMTL_METAL_MIP_FILTER_NOT_MIPMAPPED = 0,
    VKMTL_METAL_MIP_FILTER_NEAREST = 1,
    VKMTL_METAL_MIP_FILTER_LINEAR = 2,
} vkmtl_metal_mip_filter;

typedef enum vkmtl_metal_address_mode {
    VKMTL_METAL_ADDRESS_MODE_CLAMP_TO_EDGE = 0,
    VKMTL_METAL_ADDRESS_MODE_CLAMP_TO_BORDER = 1,
    VKMTL_METAL_ADDRESS_MODE_REPEAT = 2,
    VKMTL_METAL_ADDRESS_MODE_MIRROR_REPEAT = 3,
} vkmtl_metal_address_mode;

typedef enum vkmtl_metal_sampler_border_color {
    VKMTL_METAL_SAMPLER_BORDER_COLOR_TRANSPARENT_BLACK = 0,
    VKMTL_METAL_SAMPLER_BORDER_COLOR_OPAQUE_BLACK = 1,
    VKMTL_METAL_SAMPLER_BORDER_COLOR_OPAQUE_WHITE = 2,
} vkmtl_metal_sampler_border_color;

typedef enum vkmtl_metal_vertex_format {
    VKMTL_METAL_VERTEX_FORMAT_FLOAT = 1,
    VKMTL_METAL_VERTEX_FORMAT_FLOAT2 = 2,
    VKMTL_METAL_VERTEX_FORMAT_FLOAT3 = 3,
    VKMTL_METAL_VERTEX_FORMAT_FLOAT4 = 4,
    VKMTL_METAL_VERTEX_FORMAT_HALF2 = 5,
    VKMTL_METAL_VERTEX_FORMAT_HALF4 = 6,
    VKMTL_METAL_VERTEX_FORMAT_UCHAR2_NORMALIZED = 7,
    VKMTL_METAL_VERTEX_FORMAT_UCHAR4_NORMALIZED = 8,
    VKMTL_METAL_VERTEX_FORMAT_CHAR2_NORMALIZED = 9,
    VKMTL_METAL_VERTEX_FORMAT_CHAR4_NORMALIZED = 10,
    VKMTL_METAL_VERTEX_FORMAT_UINT = 11,
    VKMTL_METAL_VERTEX_FORMAT_UINT2 = 12,
    VKMTL_METAL_VERTEX_FORMAT_UINT3 = 13,
    VKMTL_METAL_VERTEX_FORMAT_UINT4 = 14,
    VKMTL_METAL_VERTEX_FORMAT_INT = 15,
    VKMTL_METAL_VERTEX_FORMAT_INT2 = 16,
    VKMTL_METAL_VERTEX_FORMAT_INT3 = 17,
    VKMTL_METAL_VERTEX_FORMAT_INT4 = 18,
} vkmtl_metal_vertex_format;

typedef enum vkmtl_metal_vertex_step_function {
    VKMTL_METAL_VERTEX_STEP_FUNCTION_PER_VERTEX = 0,
    VKMTL_METAL_VERTEX_STEP_FUNCTION_PER_INSTANCE = 1,
} vkmtl_metal_vertex_step_function;

typedef enum vkmtl_metal_triangle_fill_mode {
    VKMTL_METAL_TRIANGLE_FILL_MODE_FILL = 0,
    VKMTL_METAL_TRIANGLE_FILL_MODE_LINES = 1,
} vkmtl_metal_triangle_fill_mode;

typedef enum vkmtl_metal_blend_factor {
    VKMTL_METAL_BLEND_FACTOR_ZERO = 0,
    VKMTL_METAL_BLEND_FACTOR_ONE = 1,
    VKMTL_METAL_BLEND_FACTOR_SOURCE_COLOR = 2,
    VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_SOURCE_COLOR = 3,
    VKMTL_METAL_BLEND_FACTOR_SOURCE_ALPHA = 4,
    VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_SOURCE_ALPHA = 5,
    VKMTL_METAL_BLEND_FACTOR_DESTINATION_COLOR = 6,
    VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_DESTINATION_COLOR = 7,
    VKMTL_METAL_BLEND_FACTOR_DESTINATION_ALPHA = 8,
    VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_DESTINATION_ALPHA = 9,
    VKMTL_METAL_BLEND_FACTOR_BLEND_COLOR = 10,
    VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_BLEND_COLOR = 11,
    VKMTL_METAL_BLEND_FACTOR_BLEND_ALPHA = 12,
    VKMTL_METAL_BLEND_FACTOR_ONE_MINUS_BLEND_ALPHA = 13,
} vkmtl_metal_blend_factor;

typedef enum vkmtl_metal_blend_operation {
    VKMTL_METAL_BLEND_OPERATION_ADD = 0,
    VKMTL_METAL_BLEND_OPERATION_SUBTRACT = 1,
    VKMTL_METAL_BLEND_OPERATION_REVERSE_SUBTRACT = 2,
    VKMTL_METAL_BLEND_OPERATION_MIN = 3,
    VKMTL_METAL_BLEND_OPERATION_MAX = 4,
} vkmtl_metal_blend_operation;

typedef struct vkmtl_metal_vertex_buffer_layout {
    unsigned int buffer_index;
    unsigned int stride;
    vkmtl_metal_vertex_step_function step_function;
    unsigned int step_rate;
} vkmtl_metal_vertex_buffer_layout;

typedef struct vkmtl_metal_vertex_attribute {
    unsigned int location;
    unsigned int buffer_index;
    vkmtl_metal_vertex_format format;
    unsigned int offset;
} vkmtl_metal_vertex_attribute;

typedef enum vkmtl_metal_function_constant_kind {
    VKMTL_METAL_FUNCTION_CONSTANT_BOOL = 0,
    VKMTL_METAL_FUNCTION_CONSTANT_I32 = 1,
    VKMTL_METAL_FUNCTION_CONSTANT_U32 = 2,
    VKMTL_METAL_FUNCTION_CONSTANT_F32 = 3,
} vkmtl_metal_function_constant_kind;

typedef struct vkmtl_metal_function_constant {
    unsigned int id;
    vkmtl_metal_function_constant_kind kind;
    uint32_t value_bits;
} vkmtl_metal_function_constant;

typedef struct vkmtl_metal_render_pipeline_color_attachment {
    vkmtl_metal_texture_format format;
    unsigned int color_write_mask;
    unsigned int blend_enabled;
    vkmtl_metal_blend_factor source_rgb_blend_factor;
    vkmtl_metal_blend_factor destination_rgb_blend_factor;
    vkmtl_metal_blend_operation rgb_blend_operation;
    vkmtl_metal_blend_factor source_alpha_blend_factor;
    vkmtl_metal_blend_factor destination_alpha_blend_factor;
    vkmtl_metal_blend_operation alpha_blend_operation;
} vkmtl_metal_render_pipeline_color_attachment;

typedef struct vkmtl_metal_render_pass_color_attachment {
    vkmtl_metal_texture_view *texture_view;
    vkmtl_metal_texture_view *resolve_texture_view;
    float clear_red;
    float clear_green;
    float clear_blue;
    float clear_alpha;
    unsigned int load_action;
    unsigned int store_action;
} vkmtl_metal_render_pass_color_attachment;

typedef struct vkmtl_metal_resource_table_range {
    unsigned int binding;
    unsigned int resource_kind;
    unsigned int descriptor_count;
    unsigned int visibility;
    unsigned int writable;
} vkmtl_metal_resource_table_range;

typedef struct vkmtl_metal_native_handles {
    void *device;
    void *command_queue;
    void *layer;
    void *view;
} vkmtl_metal_native_handles;

typedef struct vkmtl_metal_device_capabilities {
    unsigned int argument_buffers;
    unsigned int argument_buffer_tier;
    unsigned int indirect_command_buffers;
    unsigned int ray_tracing;
    unsigned int sparse_textures;
    unsigned int binary_archive;
    unsigned int function_constants;
    unsigned int timestamp_counter_set;
    unsigned int timestamp_draw_boundary;
    unsigned int timestamp_dispatch_boundary;
    unsigned int timestamp_blit_boundary;
    unsigned int timestamp_queries;
    unsigned int max_threads_per_threadgroup_width;
    unsigned int max_threads_per_threadgroup_height;
    unsigned int max_threads_per_threadgroup_depth;
    unsigned int max_threads_per_threadgroup_total;
    unsigned int max_buffer_argument_table_entries;
    unsigned int max_texture_argument_table_entries;
    unsigned int max_sampler_argument_table_entries;
    size_t max_buffer_length;
    size_t max_threadgroup_memory_length;
    unsigned int max_texture_dimension_1d;
    unsigned int max_texture_dimension_2d;
    unsigned int max_texture_dimension_3d;
    unsigned int max_texture_array_layers;
    unsigned int buffer_gpu_address;
    unsigned int shared_events;
    unsigned int scheduled_presentation;
    unsigned int minimum_duration_presentation;
    unsigned int heaps;
    unsigned int memory_budget;
    unsigned int memoryless_attachments;
    uint64_t recommended_working_set_size;
    uint64_t current_allocated_size;
} vkmtl_metal_device_capabilities;

vkmtl_metal_status vkmtl_metal_indirect_command_buffer_create(
    vkmtl_metal_clear_screen *owner,
    unsigned int kind,
    unsigned int max_command_count,
    vkmtl_metal_indirect_command_buffer **out_buffer
);
void vkmtl_metal_indirect_command_buffer_destroy(vkmtl_metal_indirect_command_buffer *buffer);
vkmtl_metal_status vkmtl_metal_indirect_command_buffer_set_label(
    vkmtl_metal_indirect_command_buffer *buffer,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_indirect_command_buffer_reset(
    vkmtl_metal_indirect_command_buffer *buffer,
    unsigned int location,
    unsigned int count
);
vkmtl_metal_status vkmtl_metal_indirect_command_buffer_encode_draw(
    vkmtl_metal_indirect_command_buffer *buffer,
    unsigned int command_index,
    unsigned int primitive_type,
    unsigned int vertex_start,
    unsigned int vertex_count,
    unsigned int instance_count,
    unsigned int base_instance
);
vkmtl_metal_status vkmtl_metal_indirect_command_buffer_encode_dispatch(
    vkmtl_metal_indirect_command_buffer *buffer,
    unsigned int command_index,
    unsigned int threadgroup_count_x,
    unsigned int threadgroup_count_y,
    unsigned int threadgroup_count_z,
    unsigned int threads_per_threadgroup_x,
    unsigned int threads_per_threadgroup_y,
    unsigned int threads_per_threadgroup_z
);

typedef struct vkmtl_metal_acceleration_structure_build_sizes {
    size_t result_size;
    size_t scratch_size;
    size_t update_scratch_size;
} vkmtl_metal_acceleration_structure_build_sizes;

vkmtl_metal_status vkmtl_metal_probe_create(vkmtl_metal_probe **out_probe);
void vkmtl_metal_probe_destroy(vkmtl_metal_probe *probe);
vkmtl_metal_status vkmtl_metal_probe_copy_device_name(
    const vkmtl_metal_probe *probe,
    char *buffer,
    size_t buffer_len
);

vkmtl_metal_status vkmtl_metal_clear_screen_create(
    vkmtl_metal_clear_screen **out_clear_screen,
    void *cocoa_window,
    unsigned int width,
    unsigned int height
);
void vkmtl_metal_clear_screen_destroy(vkmtl_metal_clear_screen *clear_screen);
vkmtl_metal_status vkmtl_metal_clear_screen_resize(
    vkmtl_metal_clear_screen *clear_screen,
    unsigned int width,
    unsigned int height
);
vkmtl_metal_status vkmtl_metal_clear_screen_draw(
    vkmtl_metal_clear_screen *clear_screen,
    float red,
    float green,
    float blue,
    float alpha
);
vkmtl_metal_status vkmtl_metal_clear_screen_copy_device_name(
    const vkmtl_metal_clear_screen *clear_screen,
    char *buffer,
    size_t buffer_len
);
vkmtl_metal_status vkmtl_metal_clear_screen_get_native_handles(
    const vkmtl_metal_clear_screen *clear_screen,
    vkmtl_metal_native_handles *out_handles
);
vkmtl_metal_status vkmtl_metal_clear_screen_copy_capabilities(
    const vkmtl_metal_clear_screen *clear_screen,
    vkmtl_metal_device_capabilities *out_capabilities
);
vkmtl_metal_status vkmtl_metal_clear_screen_begin_capture(
    vkmtl_metal_clear_screen *clear_screen
);
vkmtl_metal_status vkmtl_metal_clear_screen_end_capture(
    vkmtl_metal_clear_screen *clear_screen
);

vkmtl_metal_status vkmtl_metal_buffer_create(
    vkmtl_metal_clear_screen *owner,
    size_t length,
    const void *bytes,
    size_t bytes_len,
    vkmtl_metal_storage_mode storage_mode,
    vkmtl_metal_buffer **out_buffer
);
void vkmtl_metal_buffer_destroy(vkmtl_metal_buffer *buffer);
size_t vkmtl_metal_buffer_length(const vkmtl_metal_buffer *buffer);
vkmtl_metal_status vkmtl_metal_buffer_gpu_address(
    const vkmtl_metal_buffer *buffer,
    uint64_t *out_address
);
vkmtl_metal_status vkmtl_metal_buffer_set_label(
    vkmtl_metal_buffer *buffer,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_buffer_contents(
    vkmtl_metal_buffer *buffer,
    void **out_contents
);
vkmtl_metal_status vkmtl_metal_buffer_did_modify_range(
    vkmtl_metal_buffer *buffer,
    size_t offset,
    size_t length
);
vkmtl_metal_status vkmtl_metal_buffer_replace_bytes(
    vkmtl_metal_buffer *buffer,
    size_t offset,
    const void *bytes,
    size_t bytes_len
);
vkmtl_metal_status vkmtl_metal_buffer_read_bytes(
    vkmtl_metal_buffer *buffer,
    size_t offset,
    void *destination,
    size_t destination_len
);

vkmtl_metal_status vkmtl_metal_heap_create(
    vkmtl_metal_clear_screen *owner,
    uint64_t size,
    unsigned int storage_mode,
    vkmtl_metal_heap **out_heap
);
void vkmtl_metal_heap_destroy(vkmtl_metal_heap *heap);
vkmtl_metal_status vkmtl_metal_heap_buffer_size_and_align(
    const vkmtl_metal_heap *heap,
    size_t length,
    uint64_t *out_size,
    uint64_t *out_alignment
);
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
);
vkmtl_metal_status vkmtl_metal_heap_buffer_create(
    vkmtl_metal_heap *heap,
    size_t length,
    const void *bytes,
    size_t bytes_len,
    uint64_t offset,
    vkmtl_metal_buffer **out_buffer
);
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
);

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
);
void vkmtl_metal_texture_destroy(vkmtl_metal_texture *texture);
unsigned int vkmtl_metal_texture_width(const vkmtl_metal_texture *texture);
unsigned int vkmtl_metal_texture_height(const vkmtl_metal_texture *texture);
unsigned int vkmtl_metal_texture_depth_or_array_layers(const vkmtl_metal_texture *texture);
unsigned int vkmtl_metal_texture_mip_level_count(const vkmtl_metal_texture *texture);
vkmtl_metal_status vkmtl_metal_texture_set_label(
    vkmtl_metal_texture *texture,
    const char *label,
    size_t label_len
);
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
);

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
);
void vkmtl_metal_texture_view_destroy(vkmtl_metal_texture_view *view);
vkmtl_metal_status vkmtl_metal_texture_view_set_label(
    vkmtl_metal_texture_view *view,
    const char *label,
    size_t label_len
);

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
);
void vkmtl_metal_sampler_state_destroy(vkmtl_metal_sampler_state *sampler);
vkmtl_metal_status vkmtl_metal_sampler_state_set_label(
    vkmtl_metal_sampler_state *sampler,
    const char *label,
    size_t label_len
);

vkmtl_metal_status vkmtl_metal_resource_table_create(
    vkmtl_metal_clear_screen *owner,
    const vkmtl_metal_resource_table_range *ranges,
    size_t range_count,
    vkmtl_metal_resource_table **out_table
);
void vkmtl_metal_resource_table_destroy(vkmtl_metal_resource_table *table);
vkmtl_metal_status vkmtl_metal_resource_table_set_label(
    vkmtl_metal_resource_table *table,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_resource_table_set_buffer(
    vkmtl_metal_resource_table *table,
    unsigned int index,
    vkmtl_metal_buffer *buffer,
    size_t offset,
    unsigned int writable
);
vkmtl_metal_status vkmtl_metal_resource_table_set_texture(
    vkmtl_metal_resource_table *table,
    unsigned int index,
    vkmtl_metal_texture_view *view,
    unsigned int writable
);
vkmtl_metal_status vkmtl_metal_resource_table_set_sampler(
    vkmtl_metal_resource_table *table,
    unsigned int index,
    vkmtl_metal_sampler_state *sampler
);
vkmtl_metal_status vkmtl_metal_resource_table_clear(
    vkmtl_metal_resource_table *table,
    unsigned int index,
    unsigned int resource_kind
);

vkmtl_metal_status vkmtl_metal_shader_module_create_msl(
    vkmtl_metal_clear_screen *owner,
    const char *source,
    size_t source_len,
    vkmtl_metal_shader_module **out_shader
);
void vkmtl_metal_shader_module_destroy(vkmtl_metal_shader_module *shader);
vkmtl_metal_status vkmtl_metal_shader_module_set_label(
    vkmtl_metal_shader_module *shader,
    const char *label,
    size_t label_len
);

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
    unsigned int support_indirect_command_buffers,
    const char *cache_path,
    size_t cache_path_len,
    uint64_t cache_identity_hash,
    unsigned int cache_read_only,
    vkmtl_metal_render_pipeline_state **out_pipeline
);
void vkmtl_metal_render_pipeline_state_destroy(vkmtl_metal_render_pipeline_state *pipeline);
vkmtl_metal_status vkmtl_metal_render_pipeline_state_set_label(
    vkmtl_metal_render_pipeline_state *pipeline,
    const char *label,
    size_t label_len
);

vkmtl_metal_status vkmtl_metal_compute_pipeline_state_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_shader_module *compute_shader,
    const char *compute_entry,
    size_t compute_entry_len,
    const vkmtl_metal_function_constant *constants,
    size_t constant_count,
    unsigned int support_indirect_command_buffers,
    const char *cache_path,
    size_t cache_path_len,
    uint64_t cache_identity_hash,
    unsigned int cache_read_only,
    vkmtl_metal_compute_pipeline_state **out_pipeline
);
void vkmtl_metal_compute_pipeline_state_destroy(vkmtl_metal_compute_pipeline_state *pipeline);
vkmtl_metal_status vkmtl_metal_compute_pipeline_state_set_label(
    vkmtl_metal_compute_pipeline_state *pipeline,
    const char *label,
    size_t label_len
);

vkmtl_metal_status vkmtl_metal_query_set_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_query_type query_type,
    unsigned int count,
    vkmtl_metal_query_set **out_query_set
);
void vkmtl_metal_query_set_destroy(vkmtl_metal_query_set *query_set);
vkmtl_metal_status vkmtl_metal_query_set_set_label(
    vkmtl_metal_query_set *query_set,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_query_set_reset(vkmtl_metal_query_set *query_set);
vkmtl_metal_status vkmtl_metal_query_set_read_values(
    vkmtl_metal_query_set *query_set,
    unsigned int first_query,
    unsigned int query_count,
    uint64_t *destination
);

vkmtl_metal_status vkmtl_metal_acceleration_structure_query_sizes(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_acceleration_structure_kind kind,
    unsigned int primitive_count,
    vkmtl_metal_acceleration_structure_build_sizes *out_sizes
);
vkmtl_metal_status vkmtl_metal_acceleration_structure_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_acceleration_structure_kind kind,
    unsigned int primitive_count,
    vkmtl_metal_acceleration_structure **out_acceleration_structure
);
void vkmtl_metal_acceleration_structure_destroy(
    vkmtl_metal_acceleration_structure *acceleration_structure
);
vkmtl_metal_status vkmtl_metal_acceleration_structure_set_label(
    vkmtl_metal_acceleration_structure *acceleration_structure,
    const char *label,
    size_t label_len
);
size_t vkmtl_metal_acceleration_structure_result_size(
    const vkmtl_metal_acceleration_structure *acceleration_structure
);
size_t vkmtl_metal_acceleration_structure_scratch_size(
    const vkmtl_metal_acceleration_structure *acceleration_structure
);
size_t vkmtl_metal_acceleration_structure_update_scratch_size(
    const vkmtl_metal_acceleration_structure *acceleration_structure
);
unsigned int vkmtl_metal_acceleration_structure_has_driver_handle(
    const vkmtl_metal_acceleration_structure *acceleration_structure
);
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
);

vkmtl_metal_status vkmtl_metal_ray_tracing_pipeline_state_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_shader_module *ray_generation_shader,
    const char *ray_generation_entry,
    size_t ray_generation_entry_len,
    vkmtl_metal_ray_tracing_pipeline_state **out_pipeline
);
void vkmtl_metal_ray_tracing_pipeline_state_destroy(
    vkmtl_metal_ray_tracing_pipeline_state *pipeline
);
vkmtl_metal_status vkmtl_metal_ray_tracing_pipeline_state_set_label(
    vkmtl_metal_ray_tracing_pipeline_state *pipeline,
    const char *label,
    size_t label_len
);
unsigned int vkmtl_metal_ray_tracing_pipeline_state_has_driver_handle(
    const vkmtl_metal_ray_tracing_pipeline_state *pipeline
);

vkmtl_metal_status vkmtl_metal_shared_event_create(
    vkmtl_metal_clear_screen *owner,
    uint64_t initial_value,
    vkmtl_metal_shared_event **out_event
);
void vkmtl_metal_shared_event_destroy(vkmtl_metal_shared_event *event);
vkmtl_metal_status vkmtl_metal_shared_event_get_value(
    const vkmtl_metal_shared_event *event,
    uint64_t *out_value
);
vkmtl_metal_status vkmtl_metal_shared_event_signal(
    vkmtl_metal_shared_event *event,
    uint64_t value
);
vkmtl_metal_status vkmtl_metal_shared_event_wait(
    const vkmtl_metal_shared_event *event,
    uint64_t value,
    uint64_t timeout_ns
);

vkmtl_metal_status vkmtl_metal_command_buffer_create(
    vkmtl_metal_clear_screen *owner,
    unsigned int queue_kind,
    vkmtl_metal_command_buffer **out_command_buffer
);
void vkmtl_metal_command_buffer_destroy(vkmtl_metal_command_buffer *command_buffer);
vkmtl_metal_status vkmtl_metal_command_buffer_set_label(
    vkmtl_metal_command_buffer *command_buffer,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_command_buffer_push_debug_group(
    vkmtl_metal_command_buffer *command_buffer,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_command_buffer_pop_debug_group(
    vkmtl_metal_command_buffer *command_buffer
);
vkmtl_metal_status vkmtl_metal_command_buffer_insert_debug_signpost(
    vkmtl_metal_command_buffer *command_buffer,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_command_buffer_present_drawable(
    vkmtl_metal_command_buffer *command_buffer
);
vkmtl_metal_status vkmtl_metal_command_buffer_present_drawable_timed(
    vkmtl_metal_command_buffer *command_buffer,
    unsigned int timing_mode,
    uint64_t value_ns
);
vkmtl_metal_status vkmtl_metal_command_buffer_wait_shared_event(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_shared_event *event,
    uint64_t value
);
vkmtl_metal_status vkmtl_metal_command_buffer_signal_shared_event(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_shared_event *event,
    uint64_t value
);
vkmtl_metal_status vkmtl_metal_command_buffer_commit(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_command_buffer_lifecycle_callback callback,
    void *callback_context
);
vkmtl_metal_status vkmtl_metal_command_buffer_build_acceleration_structure(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_acceleration_structure *acceleration_structure,
    vkmtl_metal_buffer *scratch_buffer,
    size_t scratch_offset,
    vkmtl_metal_acceleration_structure *instance_source
);
vkmtl_metal_status vkmtl_metal_command_buffer_dispatch_rays_to_drawable(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_ray_tracing_pipeline_state *pipeline,
    vkmtl_metal_acceleration_structure *acceleration_structure,
    unsigned int width,
    unsigned int height,
    const void *inline_data,
    size_t inline_data_len,
    unsigned int inline_data_index
);

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
);
void vkmtl_metal_render_command_encoder_destroy(vkmtl_metal_render_command_encoder *encoder);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_label(
    vkmtl_metal_render_command_encoder *encoder,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_push_debug_group(
    vkmtl_metal_render_command_encoder *encoder,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_pop_debug_group(
    vkmtl_metal_render_command_encoder *encoder
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_insert_debug_signpost(
    vkmtl_metal_render_command_encoder *encoder,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_pipeline(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_render_pipeline_state *pipeline
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_triangle_fill_mode(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_triangle_fill_mode fill_mode
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_vertex_buffer(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_buffer *buffer,
    unsigned int index,
    size_t offset
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_vertex_bytes(
    vkmtl_metal_render_command_encoder *encoder,
    const void *bytes,
    size_t byte_count,
    unsigned int index
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_fragment_buffer(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_buffer *buffer,
    unsigned int index,
    size_t offset
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_fragment_bytes(
    vkmtl_metal_render_command_encoder *encoder,
    const void *bytes,
    size_t byte_count,
    unsigned int index
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_index_buffer(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_buffer *buffer
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_vertex_texture(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_texture_view *texture_view,
    unsigned int index
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_fragment_texture(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_texture_view *texture_view,
    unsigned int index
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_vertex_sampler_state(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_sampler_state *sampler,
    unsigned int index
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_fragment_sampler_state(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_sampler_state *sampler,
    unsigned int index
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_resource_table(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_resource_table *table,
    unsigned int index,
    unsigned int visibility
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_execute_indirect_commands(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_indirect_command_buffer *buffer,
    unsigned int location,
    unsigned int count
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_viewport(
    vkmtl_metal_render_command_encoder *encoder,
    double x,
    double y,
    double width,
    double height,
    double near_z,
    double far_z
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_scissor_rect(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int x,
    unsigned int y,
    unsigned int width,
    unsigned int height
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_blend_color(
    vkmtl_metal_render_command_encoder *encoder,
    float red,
    float green,
    float blue,
    float alpha
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_stencil_reference(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int reference
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_set_depth_bias(
    vkmtl_metal_render_command_encoder *encoder,
    float constant,
    float slope,
    float clamp
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_begin_occlusion_query(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int query_index
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_end_occlusion_query(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_query_set *query_set
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_write_timestamp(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int query_index
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_draw_primitives(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int primitive_type,
    unsigned int vertex_start,
    unsigned int vertex_count,
    unsigned int instance_count,
    unsigned int base_instance
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_draw_indexed_primitives(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int primitive_type,
    unsigned int index_type,
    unsigned int index_count,
    size_t index_buffer_offset,
    unsigned int instance_count,
    int base_vertex,
    unsigned int base_instance
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_draw_primitives_indirect(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int primitive_type,
    vkmtl_metal_buffer *indirect_buffer,
    size_t indirect_buffer_offset
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_draw_indexed_primitives_indirect(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int primitive_type,
    unsigned int index_type,
    vkmtl_metal_buffer *indirect_buffer,
    size_t indirect_buffer_offset
);
vkmtl_metal_status vkmtl_metal_render_command_encoder_end_encoding(
    vkmtl_metal_render_command_encoder *encoder
);

vkmtl_metal_status vkmtl_metal_compute_command_encoder_create(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_compute_command_encoder **out_encoder
);
void vkmtl_metal_compute_command_encoder_destroy(vkmtl_metal_compute_command_encoder *encoder);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_label(
    vkmtl_metal_compute_command_encoder *encoder,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_push_debug_group(
    vkmtl_metal_compute_command_encoder *encoder,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_pop_debug_group(
    vkmtl_metal_compute_command_encoder *encoder
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_insert_debug_signpost(
    vkmtl_metal_compute_command_encoder *encoder,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_pipeline(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_compute_pipeline_state *pipeline
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_buffer(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_buffer *buffer,
    unsigned int index,
    size_t offset
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_bytes(
    vkmtl_metal_compute_command_encoder *encoder,
    const void *bytes,
    size_t byte_count,
    unsigned int index
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_texture(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_texture_view *texture_view,
    unsigned int index
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_sampler_state(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_sampler_state *sampler,
    unsigned int index
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_resource_table(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_resource_table *table,
    unsigned int index
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_execute_indirect_commands(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_indirect_command_buffer *buffer,
    unsigned int location,
    unsigned int count
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_dispatch_threadgroups(
    vkmtl_metal_compute_command_encoder *encoder,
    unsigned int threadgroup_count_x,
    unsigned int threadgroup_count_y,
    unsigned int threadgroup_count_z,
    unsigned int threads_per_threadgroup_x,
    unsigned int threads_per_threadgroup_y,
    unsigned int threads_per_threadgroup_z
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_dispatch_threadgroups_indirect(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_buffer *indirect_buffer,
    size_t indirect_buffer_offset,
    unsigned int threads_per_threadgroup_x,
    unsigned int threads_per_threadgroup_y,
    unsigned int threads_per_threadgroup_z
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_write_timestamp(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int query_index
);
vkmtl_metal_status vkmtl_metal_compute_command_encoder_end_encoding(
    vkmtl_metal_compute_command_encoder *encoder
);

vkmtl_metal_status vkmtl_metal_blit_command_encoder_create(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_blit_command_encoder **out_encoder
);
void vkmtl_metal_blit_command_encoder_destroy(vkmtl_metal_blit_command_encoder *encoder);
vkmtl_metal_status vkmtl_metal_blit_command_encoder_set_label(
    vkmtl_metal_blit_command_encoder *encoder,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_blit_command_encoder_push_debug_group(
    vkmtl_metal_blit_command_encoder *encoder,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_blit_command_encoder_pop_debug_group(
    vkmtl_metal_blit_command_encoder *encoder
);
vkmtl_metal_status vkmtl_metal_blit_command_encoder_insert_debug_signpost(
    vkmtl_metal_blit_command_encoder *encoder,
    const char *label,
    size_t label_len
);
vkmtl_metal_status vkmtl_metal_blit_command_encoder_copy_buffer_to_buffer(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_buffer *source,
    vkmtl_metal_buffer *destination,
    size_t source_offset,
    size_t destination_offset,
    size_t size
);
vkmtl_metal_status vkmtl_metal_blit_command_encoder_write_timestamp(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int query_index
);
vkmtl_metal_status vkmtl_metal_blit_command_encoder_resolve_query_set(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int first_query,
    unsigned int query_count,
    vkmtl_metal_buffer *destination,
    size_t destination_offset
);
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
);
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
);
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
);
vkmtl_metal_status vkmtl_metal_blit_command_encoder_fill_buffer(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_buffer *buffer,
    size_t offset,
    size_t size,
    unsigned int value
);
vkmtl_metal_status vkmtl_metal_blit_command_encoder_generate_mipmaps(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_texture *texture
);
vkmtl_metal_status vkmtl_metal_blit_command_encoder_end_encoding(
    vkmtl_metal_blit_command_encoder *encoder
);

#ifdef __cplusplus
}
#endif

#endif
