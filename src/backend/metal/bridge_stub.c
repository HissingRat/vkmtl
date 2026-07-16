#include "bridge.h"

struct vkmtl_metal_probe {
    int unused;
};

struct vkmtl_metal_query_set {
    int unused;
};

struct vkmtl_metal_resource_table {
    int unused;
};

struct vkmtl_metal_indirect_command_buffer { int unused; };

vkmtl_metal_status vkmtl_metal_indirect_command_buffer_create(vkmtl_metal_clear_screen *owner, unsigned int kind, unsigned int max_command_count, vkmtl_metal_indirect_command_buffer **out_buffer) {
    (void)owner; (void)kind; (void)max_command_count; if (out_buffer != NULL) *out_buffer = NULL; return VKMTL_METAL_STATUS_UNSUPPORTED;
}
void vkmtl_metal_indirect_command_buffer_destroy(vkmtl_metal_indirect_command_buffer *buffer) { (void)buffer; }
vkmtl_metal_status vkmtl_metal_indirect_command_buffer_set_label(vkmtl_metal_indirect_command_buffer *buffer, const char *label, size_t label_len) {
    (void)buffer; (void)label; (void)label_len; return VKMTL_METAL_STATUS_UNSUPPORTED;
}
vkmtl_metal_status vkmtl_metal_indirect_command_buffer_reset(vkmtl_metal_indirect_command_buffer *buffer, unsigned int location, unsigned int count) {
    (void)buffer; (void)location; (void)count; return VKMTL_METAL_STATUS_UNSUPPORTED;
}
vkmtl_metal_status vkmtl_metal_indirect_command_buffer_encode_draw(vkmtl_metal_indirect_command_buffer *buffer, unsigned int command_index, unsigned int primitive_type, unsigned int vertex_start, unsigned int vertex_count, unsigned int instance_count, unsigned int base_instance) {
    (void)buffer; (void)command_index; (void)primitive_type; (void)vertex_start; (void)vertex_count; (void)instance_count; (void)base_instance; return VKMTL_METAL_STATUS_UNSUPPORTED;
}
vkmtl_metal_status vkmtl_metal_indirect_command_buffer_encode_dispatch(vkmtl_metal_indirect_command_buffer *buffer, unsigned int command_index, unsigned int threadgroup_count_x, unsigned int threadgroup_count_y, unsigned int threadgroup_count_z, unsigned int threads_per_threadgroup_x, unsigned int threads_per_threadgroup_y, unsigned int threads_per_threadgroup_z) {
    (void)buffer; (void)command_index; (void)threadgroup_count_x; (void)threadgroup_count_y; (void)threadgroup_count_z; (void)threads_per_threadgroup_x; (void)threads_per_threadgroup_y; (void)threads_per_threadgroup_z; return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_resource_table_create(
    vkmtl_metal_clear_screen *owner,
    const vkmtl_metal_resource_table_range *ranges,
    size_t range_count,
    vkmtl_metal_resource_table **out_table
) {
    (void)owner;
    (void)ranges;
    (void)range_count;
    if (out_table != NULL) *out_table = NULL;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_resource_table_destroy(vkmtl_metal_resource_table *table) { (void)table; }
vkmtl_metal_status vkmtl_metal_resource_table_set_label(vkmtl_metal_resource_table *table, const char *label, size_t label_len) {
    (void)table; (void)label; (void)label_len; return VKMTL_METAL_STATUS_UNSUPPORTED;
}
vkmtl_metal_status vkmtl_metal_resource_table_set_buffer(vkmtl_metal_resource_table *table, unsigned int index, vkmtl_metal_buffer *buffer, size_t offset, unsigned int writable) {
    (void)table; (void)index; (void)buffer; (void)offset; (void)writable; return VKMTL_METAL_STATUS_UNSUPPORTED;
}
vkmtl_metal_status vkmtl_metal_resource_table_set_texture(vkmtl_metal_resource_table *table, unsigned int index, vkmtl_metal_texture_view *view, unsigned int writable) {
    (void)table; (void)index; (void)view; (void)writable; return VKMTL_METAL_STATUS_UNSUPPORTED;
}
vkmtl_metal_status vkmtl_metal_resource_table_set_sampler(vkmtl_metal_resource_table *table, unsigned int index, vkmtl_metal_sampler_state *sampler) {
    (void)table; (void)index; (void)sampler; return VKMTL_METAL_STATUS_UNSUPPORTED;
}
vkmtl_metal_status vkmtl_metal_resource_table_clear(vkmtl_metal_resource_table *table, unsigned int index, unsigned int resource_kind) {
    (void)table; (void)index; (void)resource_kind; return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_resource_table(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_resource_table *table,
    unsigned int index,
    unsigned int visibility
) {
    (void)encoder; (void)table; (void)index; (void)visibility; return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_resource_table(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_resource_table *table,
    unsigned int index
) {
    (void)encoder; (void)table; (void)index; return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_execute_indirect_commands(vkmtl_metal_render_command_encoder *encoder, vkmtl_metal_indirect_command_buffer *buffer, unsigned int location, unsigned int count) {
    (void)encoder; (void)buffer; (void)location; (void)count; return VKMTL_METAL_STATUS_UNSUPPORTED;
}
vkmtl_metal_status vkmtl_metal_compute_command_encoder_execute_indirect_commands(vkmtl_metal_compute_command_encoder *encoder, vkmtl_metal_indirect_command_buffer *buffer, unsigned int location, unsigned int count) {
    (void)encoder; (void)buffer; (void)location; (void)count; return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_probe_create(vkmtl_metal_probe **out_probe) {
    if (out_probe != NULL) {
        *out_probe = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_probe_destroy(vkmtl_metal_probe *probe) {
    (void)probe;
}

vkmtl_metal_status vkmtl_metal_probe_copy_device_name(
    const vkmtl_metal_probe *probe,
    char *buffer,
    size_t buffer_len
) {
    (void)probe;
    (void)buffer;
    (void)buffer_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_clear_screen_create(
    vkmtl_metal_clear_screen **out_clear_screen,
    void *cocoa_window,
    vkmtl_metal_texture_format format,
    unsigned int width,
    unsigned int height
) {
    (void)cocoa_window;
    (void)format;
    (void)width;
    (void)height;
    if (out_clear_screen != NULL) {
        *out_clear_screen = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_clear_screen_create_headless(
    vkmtl_metal_clear_screen **out_clear_screen
) {
    if (out_clear_screen != NULL) {
        *out_clear_screen = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_clear_screen_destroy(vkmtl_metal_clear_screen *clear_screen) {
    (void)clear_screen;
}

vkmtl_metal_status vkmtl_metal_clear_screen_get_presentation_format(
    const vkmtl_metal_clear_screen *clear_screen,
    vkmtl_metal_texture_format *out_format
) {
    (void)clear_screen;
    if (out_format != NULL) {
        *out_format = VKMTL_METAL_TEXTURE_FORMAT_INVALID;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_clear_screen_copy_device_topology(
    const vkmtl_metal_clear_screen *clear_screen,
    vkmtl_metal_device_topology *out_topology
) {
    (void)clear_screen;
    if (out_topology != NULL) {
        *out_topology = (vkmtl_metal_device_topology){0};
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_buffer_import(
    vkmtl_metal_clear_screen *owner,
    void *native_buffer,
    size_t required_length,
    vkmtl_metal_storage_mode storage_mode,
    unsigned int transferred,
    vkmtl_metal_buffer **out_buffer
) {
    (void)owner;
    (void)native_buffer;
    (void)required_length;
    (void)storage_mode;
    (void)transferred;
    if (out_buffer != NULL) *out_buffer = NULL;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_storage_mode vkmtl_metal_buffer_storage_mode(const vkmtl_metal_buffer *buffer) {
    (void)buffer;
    return VKMTL_METAL_STORAGE_MODE_AUTOMATIC;
}

vkmtl_metal_status vkmtl_metal_texture_import(
    vkmtl_metal_clear_screen *owner,
    unsigned int external_kind,
    void *external_handle,
    vkmtl_metal_texture_format format,
    unsigned int width,
    unsigned int height,
    unsigned int depth_or_array_layers,
    unsigned int usage_flags,
    vkmtl_metal_storage_mode storage_mode,
    unsigned int iosurface_plane,
    unsigned int transferred,
    vkmtl_metal_texture **out_texture
) {
    (void)owner;
    (void)external_kind;
    (void)external_handle;
    (void)format;
    (void)width;
    (void)height;
    (void)depth_or_array_layers;
    (void)usage_flags;
    (void)storage_mode;
    (void)iosurface_plane;
    (void)transferred;
    if (out_texture != NULL) *out_texture = NULL;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_storage_mode vkmtl_metal_texture_storage_mode(const vkmtl_metal_texture *texture) {
    (void)texture;
    return VKMTL_METAL_STORAGE_MODE_AUTOMATIC;
}

vkmtl_metal_status vkmtl_metal_clear_screen_resize(
    vkmtl_metal_clear_screen *clear_screen,
    unsigned int width,
    unsigned int height
) {
    (void)clear_screen;
    (void)width;
    (void)height;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_clear_screen_draw(
    vkmtl_metal_clear_screen *clear_screen,
    float red,
    float green,
    float blue,
    float alpha
) {
    (void)clear_screen;
    (void)red;
    (void)green;
    (void)blue;
    (void)alpha;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_clear_screen_copy_device_name(
    const vkmtl_metal_clear_screen *clear_screen,
    char *buffer,
    size_t buffer_len
) {
    (void)clear_screen;
    (void)buffer;
    (void)buffer_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_clear_screen_get_native_handles(
    const vkmtl_metal_clear_screen *clear_screen,
    vkmtl_metal_native_handles *out_handles
) {
    (void)clear_screen;
    (void)out_handles;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_clear_screen_copy_capabilities(
    const vkmtl_metal_clear_screen *clear_screen,
    vkmtl_metal_device_capabilities *out_capabilities
) {
    (void)clear_screen;
    if (out_capabilities != NULL) {
        *out_capabilities = (vkmtl_metal_device_capabilities){0};
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_clear_screen_begin_capture(
    vkmtl_metal_clear_screen *clear_screen
) {
    (void)clear_screen;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_clear_screen_end_capture(
    vkmtl_metal_clear_screen *clear_screen
) {
    (void)clear_screen;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_buffer_create(
    vkmtl_metal_clear_screen *owner,
    size_t length,
    const void *bytes,
    size_t bytes_len,
    vkmtl_metal_storage_mode storage_mode,
    vkmtl_metal_buffer **out_buffer
) {
    (void)owner;
    (void)length;
    (void)bytes;
    (void)bytes_len;
    (void)storage_mode;
    if (out_buffer != NULL) {
        *out_buffer = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_buffer_destroy(vkmtl_metal_buffer *buffer) {
    (void)buffer;
}

size_t vkmtl_metal_buffer_length(const vkmtl_metal_buffer *buffer) {
    (void)buffer;
    return 0;
}

vkmtl_metal_status vkmtl_metal_buffer_gpu_address(
    const vkmtl_metal_buffer *buffer,
    uint64_t *out_address
) {
    (void)buffer;
    if (out_address != NULL) {
        *out_address = 0;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_buffer_contents(
    vkmtl_metal_buffer *buffer,
    void **out_contents
) {
    (void)buffer;
    if (out_contents != NULL) {
        *out_contents = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_buffer_did_modify_range(
    vkmtl_metal_buffer *buffer,
    size_t offset,
    size_t length
) {
    (void)buffer;
    (void)offset;
    (void)length;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_buffer_replace_bytes(
    vkmtl_metal_buffer *buffer,
    size_t offset,
    const void *bytes,
    size_t bytes_len
) {
    (void)buffer;
    (void)offset;
    (void)bytes;
    (void)bytes_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_buffer_read_bytes(
    vkmtl_metal_buffer *buffer,
    size_t offset,
    void *destination,
    size_t destination_len
) {
    (void)buffer;
    (void)offset;
    (void)destination;
    (void)destination_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_heap_create(
    vkmtl_metal_clear_screen *owner,
    uint64_t size,
    unsigned int storage_mode,
    vkmtl_metal_heap **out_heap
) {
    (void)owner;
    (void)size;
    (void)storage_mode;
    if (out_heap != NULL) *out_heap = NULL;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_heap_destroy(vkmtl_metal_heap *heap) {
    (void)heap;
}

vkmtl_metal_status vkmtl_metal_heap_buffer_size_and_align(
    const vkmtl_metal_heap *heap,
    size_t length,
    uint64_t *out_size,
    uint64_t *out_alignment
) {
    (void)heap;
    (void)length;
    if (out_size != NULL) *out_size = 0;
    if (out_alignment != NULL) *out_alignment = 0;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
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
    (void)heap;
    (void)dimension;
    (void)format;
    (void)width;
    (void)height;
    (void)depth_or_array_layers;
    (void)mip_level_count;
    (void)sample_count;
    (void)usage_flags;
    if (out_size != NULL) *out_size = 0;
    if (out_alignment != NULL) *out_alignment = 0;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_heap_buffer_create(
    vkmtl_metal_heap *heap,
    size_t length,
    const void *bytes,
    size_t bytes_len,
    uint64_t offset,
    vkmtl_metal_buffer **out_buffer
) {
    (void)heap;
    (void)length;
    (void)bytes;
    (void)bytes_len;
    (void)offset;
    if (out_buffer != NULL) *out_buffer = NULL;
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
    (void)heap;
    (void)dimension;
    (void)format;
    (void)width;
    (void)height;
    (void)depth_or_array_layers;
    (void)mip_level_count;
    (void)sample_count;
    (void)usage_flags;
    (void)offset;
    if (out_texture != NULL) *out_texture = NULL;
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
    (void)owner;
    (void)dimension;
    (void)format;
    (void)width;
    (void)height;
    (void)depth_or_array_layers;
    (void)mip_level_count;
    (void)sample_count;
    (void)usage_flags;
    (void)storage_mode;
    if (out_texture != NULL) {
        *out_texture = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_texture_destroy(vkmtl_metal_texture *texture) {
    (void)texture;
}

unsigned int vkmtl_metal_texture_width(const vkmtl_metal_texture *texture) {
    (void)texture;
    return 0;
}

unsigned int vkmtl_metal_texture_height(const vkmtl_metal_texture *texture) {
    (void)texture;
    return 0;
}

unsigned int vkmtl_metal_texture_depth_or_array_layers(const vkmtl_metal_texture *texture) {
    (void)texture;
    return 0;
}

unsigned int vkmtl_metal_texture_mip_level_count(const vkmtl_metal_texture *texture) {
    (void)texture;
    return 0;
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
    (void)texture;
    (void)x;
    (void)y;
    (void)z;
    (void)width;
    (void)height;
    (void)depth;
    (void)mip_level;
    (void)slice;
    (void)bytes;
    (void)bytes_len;
    (void)bytes_per_row;
    (void)bytes_per_image;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
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
    (void)texture;
    (void)dimension;
    (void)format;
    (void)base_mip_level;
    (void)mip_level_count;
    (void)base_array_layer;
    (void)array_layer_count;
    (void)swizzle_red;
    (void)swizzle_green;
    (void)swizzle_blue;
    (void)swizzle_alpha;
    if (out_view != NULL) {
        *out_view = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_texture_view_destroy(vkmtl_metal_texture_view *view) {
    (void)view;
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
    (void)owner;
    (void)min_filter;
    (void)mag_filter;
    (void)mip_filter;
    (void)address_mode_u;
    (void)address_mode_v;
    (void)address_mode_w;
    (void)lod_min_clamp;
    (void)lod_max_clamp;
    (void)compare_enabled;
    (void)compare_function;
    (void)max_anisotropy;
    (void)border_color;
    (void)normalized_coordinates;
    if (out_sampler != NULL) {
        *out_sampler = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_sampler_state_destroy(vkmtl_metal_sampler_state *sampler) {
    (void)sampler;
}

vkmtl_metal_status vkmtl_metal_shader_module_create_msl(
    vkmtl_metal_clear_screen *owner,
    const char *source,
    size_t source_len,
    vkmtl_metal_shader_module **out_shader
) {
    (void)owner;
    (void)source;
    (void)source_len;
    if (out_shader != NULL) {
        *out_shader = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_shader_module_destroy(vkmtl_metal_shader_module *shader) {
    (void)shader;
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
    unsigned int support_indirect_command_buffers,
    const char *cache_path,
    size_t cache_path_len,
    uint64_t cache_identity_hash,
    unsigned int cache_read_only,
    vkmtl_metal_render_pipeline_state **out_pipeline
) {
    (void)owner;
    (void)vertex_shader;
    (void)vertex_entry;
    (void)vertex_entry_len;
    (void)vertex_constants;
    (void)vertex_constant_count;
    (void)fragment_shader;
    (void)fragment_entry;
    (void)fragment_entry_len;
    (void)fragment_constants;
    (void)fragment_constant_count;
    (void)color_attachments;
    (void)color_attachment_count;
    (void)depth_format;
    (void)depth_compare_function;
    (void)depth_write_enabled;
    (void)stencil_enabled;
    (void)front_stencil_fail_operation;
    (void)front_depth_fail_operation;
    (void)front_depth_stencil_pass_operation;
    (void)front_stencil_compare_function;
    (void)back_stencil_fail_operation;
    (void)back_depth_fail_operation;
    (void)back_depth_stencil_pass_operation;
    (void)back_stencil_compare_function;
    (void)stencil_read_mask;
    (void)stencil_write_mask;
    (void)sample_count;
    (void)vertex_buffers;
    (void)vertex_buffer_count;
    (void)vertex_attributes;
    (void)vertex_attribute_count;
    (void)support_indirect_command_buffers;
    (void)cache_path;
    (void)cache_path_len;
    (void)cache_identity_hash;
    (void)cache_read_only;
    if (out_pipeline != NULL) {
        *out_pipeline = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_mesh_render_pipeline_state_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_shader_module *mesh_shader,
    const char *mesh_entry,
    size_t mesh_entry_len,
    const vkmtl_metal_function_constant *mesh_constants,
    size_t mesh_constant_count,
    vkmtl_metal_shader_module *object_shader,
    const char *object_entry,
    size_t object_entry_len,
    const vkmtl_metal_function_constant *object_constants,
    size_t object_constant_count,
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
    unsigned int mesh_threads_per_threadgroup,
    unsigned int object_threads_per_threadgroup,
    const char *cache_path,
    size_t cache_path_len,
    uint64_t cache_identity_hash,
    unsigned int cache_read_only,
    vkmtl_metal_render_pipeline_state **out_pipeline
) {
    (void)owner;
    (void)mesh_shader;
    (void)mesh_entry;
    (void)mesh_entry_len;
    (void)mesh_constants;
    (void)mesh_constant_count;
    (void)object_shader;
    (void)object_entry;
    (void)object_entry_len;
    (void)object_constants;
    (void)object_constant_count;
    (void)fragment_shader;
    (void)fragment_entry;
    (void)fragment_entry_len;
    (void)fragment_constants;
    (void)fragment_constant_count;
    (void)color_attachments;
    (void)color_attachment_count;
    (void)depth_format;
    (void)depth_compare_function;
    (void)depth_write_enabled;
    (void)stencil_enabled;
    (void)front_stencil_fail_operation;
    (void)front_depth_fail_operation;
    (void)front_depth_stencil_pass_operation;
    (void)front_stencil_compare_function;
    (void)back_stencil_fail_operation;
    (void)back_depth_fail_operation;
    (void)back_depth_stencil_pass_operation;
    (void)back_stencil_compare_function;
    (void)stencil_read_mask;
    (void)stencil_write_mask;
    (void)sample_count;
    (void)mesh_threads_per_threadgroup;
    (void)object_threads_per_threadgroup;
    (void)cache_path;
    (void)cache_path_len;
    (void)cache_identity_hash;
    (void)cache_read_only;
    if (out_pipeline != NULL) {
        *out_pipeline = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_render_pipeline_state_destroy(vkmtl_metal_render_pipeline_state *pipeline) {
    (void)pipeline;
}

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
) {
    (void)owner;
    (void)compute_shader;
    (void)compute_entry;
    (void)compute_entry_len;
    (void)constants;
    (void)constant_count;
    (void)support_indirect_command_buffers;
    (void)cache_path;
    (void)cache_path_len;
    (void)cache_identity_hash;
    (void)cache_read_only;
    if (out_pipeline != NULL) {
        *out_pipeline = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_compute_pipeline_state_destroy(vkmtl_metal_compute_pipeline_state *pipeline) {
    (void)pipeline;
}

vkmtl_metal_status vkmtl_metal_query_set_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_query_type query_type,
    unsigned int count,
    vkmtl_metal_query_set **out_query_set
) {
    (void)owner;
    (void)query_type;
    (void)count;
    if (out_query_set != NULL) {
        *out_query_set = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_query_set_destroy(vkmtl_metal_query_set *query_set) {
    (void)query_set;
}

vkmtl_metal_status vkmtl_metal_query_set_set_label(
    vkmtl_metal_query_set *query_set,
    const char *label,
    size_t label_len
) {
    (void)query_set;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_query_set_reset(vkmtl_metal_query_set *query_set) {
    (void)query_set;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_query_set_read_values(
    vkmtl_metal_query_set *query_set,
    unsigned int first_query,
    unsigned int query_count,
    uint64_t *destination
) {
    (void)query_set;
    (void)first_query;
    (void)query_count;
    (void)destination;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_create(
    vkmtl_metal_clear_screen *owner,
    unsigned int queue_kind,
    vkmtl_metal_command_buffer **out_command_buffer
) {
    (void)owner;
    (void)queue_kind;
    if (out_command_buffer != NULL) {
        *out_command_buffer = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_command_buffer_destroy(vkmtl_metal_command_buffer *command_buffer) {
    (void)command_buffer;
}

vkmtl_metal_status vkmtl_metal_command_buffer_present_drawable(
    vkmtl_metal_command_buffer *command_buffer
) {
    (void)command_buffer;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_present_drawable_timed(
    vkmtl_metal_command_buffer *command_buffer,
    unsigned int timing_mode,
    uint64_t value_ns
) {
    (void)command_buffer;
    (void)timing_mode;
    (void)value_ns;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_wait_shared_event(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_shared_event *event,
    uint64_t value
) {
    (void)command_buffer;
    (void)event;
    (void)value;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_signal_shared_event(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_shared_event *event,
    uint64_t value
) {
    (void)command_buffer;
    (void)event;
    (void)value;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_commit(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_command_buffer_lifecycle_callback callback,
    void *callback_context
) {
    (void)command_buffer;
    (void)callback;
    (void)callback_context;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
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
    (void)owner;
    (void)command_buffer;
    (void)color_attachments;
    (void)color_attachment_count;
    (void)use_depth;
    (void)depth_texture_view;
    (void)clear_depth;
    (void)depth_load_action;
    (void)depth_store_action;
    (void)use_stencil;
    (void)clear_stencil;
    (void)stencil_load_action;
    (void)stencil_store_action;
    (void)occlusion_query_set;
    if (out_encoder != NULL) {
        *out_encoder = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_render_command_encoder_destroy(vkmtl_metal_render_command_encoder *encoder) {
    (void)encoder;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_pipeline(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_render_pipeline_state *pipeline
) {
    (void)encoder;
    (void)pipeline;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_triangle_fill_mode(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_triangle_fill_mode fill_mode
) {
    (void)encoder;
    (void)fill_mode;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_front_facing_winding(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_winding winding
) {
    (void)encoder;
    (void)winding;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_cull_mode(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_cull_mode cull_mode
) {
    (void)encoder;
    (void)cull_mode;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_vertex_buffer(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_buffer *buffer,
    unsigned int index,
    size_t offset
) {
    (void)encoder;
    (void)buffer;
    (void)index;
    (void)offset;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_vertex_bytes(
    vkmtl_metal_render_command_encoder *encoder,
    const void *bytes,
    size_t byte_count,
    unsigned int index
) {
    (void)encoder;
    (void)bytes;
    (void)byte_count;
    (void)index;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_fragment_buffer(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_buffer *buffer,
    unsigned int index,
    size_t offset
) {
    (void)encoder;
    (void)buffer;
    (void)index;
    (void)offset;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_fragment_bytes(
    vkmtl_metal_render_command_encoder *encoder,
    const void *bytes,
    size_t byte_count,
    unsigned int index
) {
    (void)encoder;
    (void)bytes;
    (void)byte_count;
    (void)index;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_index_buffer(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_buffer *buffer
) {
    (void)encoder;
    (void)buffer;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_vertex_texture(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_texture_view *texture_view,
    unsigned int index
) {
    (void)encoder;
    (void)texture_view;
    (void)index;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_fragment_texture(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_texture_view *texture_view,
    unsigned int index
) {
    (void)encoder;
    (void)texture_view;
    (void)index;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_vertex_sampler_state(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_sampler_state *sampler,
    unsigned int index
) {
    (void)encoder;
    (void)sampler;
    (void)index;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_fragment_sampler_state(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_sampler_state *sampler,
    unsigned int index
) {
    (void)encoder;
    (void)sampler;
    (void)index;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
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
    (void)encoder;
    (void)x;
    (void)y;
    (void)width;
    (void)height;
    (void)near_z;
    (void)far_z;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_scissor_rect(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int x,
    unsigned int y,
    unsigned int width,
    unsigned int height
) {
    (void)encoder;
    (void)x;
    (void)y;
    (void)width;
    (void)height;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_blend_color(
    vkmtl_metal_render_command_encoder *encoder,
    float red,
    float green,
    float blue,
    float alpha
) {
    (void)encoder;
    (void)red;
    (void)green;
    (void)blue;
    (void)alpha;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_stencil_reference(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int reference
) {
    (void)encoder;
    (void)reference;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_depth_bias(
    vkmtl_metal_render_command_encoder *encoder,
    float constant,
    float slope,
    float clamp
) {
    (void)encoder;
    (void)constant;
    (void)slope;
    (void)clamp;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_begin_occlusion_query(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int query_index,
    unsigned int counting
) {
    (void)encoder;
    (void)query_set;
    (void)query_index;
    (void)counting;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_end_occlusion_query(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_query_set *query_set
) {
    (void)encoder;
    (void)query_set;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_write_timestamp(
    vkmtl_metal_render_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int query_index
) {
    (void)encoder;
    (void)query_set;
    (void)query_index;
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
    (void)encoder;
    (void)primitive_type;
    (void)vertex_start;
    (void)vertex_count;
    (void)instance_count;
    (void)base_instance;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_draw_mesh_threadgroups(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int threadgroup_count_x,
    unsigned int threadgroup_count_y,
    unsigned int threadgroup_count_z,
    unsigned int object_threads_per_threadgroup,
    unsigned int mesh_threads_per_threadgroup
) {
    (void)encoder;
    (void)threadgroup_count_x;
    (void)threadgroup_count_y;
    (void)threadgroup_count_z;
    (void)object_threads_per_threadgroup;
    (void)mesh_threads_per_threadgroup;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
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
    (void)encoder;
    (void)primitive_type;
    (void)index_type;
    (void)index_count;
    (void)index_buffer_offset;
    (void)instance_count;
    (void)base_vertex;
    (void)base_instance;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_draw_primitives_indirect(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int primitive_type,
    vkmtl_metal_buffer *indirect_buffer,
    size_t indirect_buffer_offset
) {
    (void)encoder;
    (void)primitive_type;
    (void)indirect_buffer;
    (void)indirect_buffer_offset;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_draw_indexed_primitives_indirect(
    vkmtl_metal_render_command_encoder *encoder,
    unsigned int primitive_type,
    unsigned int index_type,
    vkmtl_metal_buffer *indirect_buffer,
    size_t indirect_buffer_offset
) {
    (void)encoder;
    (void)primitive_type;
    (void)index_type;
    (void)indirect_buffer;
    (void)indirect_buffer_offset;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_end_encoding(
    vkmtl_metal_render_command_encoder *encoder
) {
    (void)encoder;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_create(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_compute_command_encoder **out_encoder
) {
    (void)command_buffer;
    if (out_encoder != NULL) {
        *out_encoder = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_compute_command_encoder_destroy(vkmtl_metal_compute_command_encoder *encoder) {
    (void)encoder;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_pipeline(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_compute_pipeline_state *pipeline
) {
    (void)encoder;
    (void)pipeline;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_buffer(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_buffer *buffer,
    unsigned int index,
    size_t offset
) {
    (void)encoder;
    (void)buffer;
    (void)index;
    (void)offset;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_bytes(
    vkmtl_metal_compute_command_encoder *encoder,
    const void *bytes,
    size_t byte_count,
    unsigned int index
) {
    (void)encoder;
    (void)bytes;
    (void)byte_count;
    (void)index;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_texture(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_texture_view *texture_view,
    unsigned int index
) {
    (void)encoder;
    (void)texture_view;
    (void)index;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_sampler_state(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_sampler_state *sampler,
    unsigned int index
) {
    (void)encoder;
    (void)sampler;
    (void)index;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
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
    (void)encoder;
    (void)threadgroup_count_x;
    (void)threadgroup_count_y;
    (void)threadgroup_count_z;
    (void)threads_per_threadgroup_x;
    (void)threads_per_threadgroup_y;
    (void)threads_per_threadgroup_z;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_dispatch_threadgroups_indirect(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_buffer *indirect_buffer,
    size_t indirect_buffer_offset,
    unsigned int threads_per_threadgroup_x,
    unsigned int threads_per_threadgroup_y,
    unsigned int threads_per_threadgroup_z
) {
    (void)encoder;
    (void)indirect_buffer;
    (void)indirect_buffer_offset;
    (void)threads_per_threadgroup_x;
    (void)threads_per_threadgroup_y;
    (void)threads_per_threadgroup_z;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_write_timestamp(
    vkmtl_metal_compute_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int query_index
) {
    (void)encoder;
    (void)query_set;
    (void)query_index;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_end_encoding(
    vkmtl_metal_compute_command_encoder *encoder
) {
    (void)encoder;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_create(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_blit_command_encoder **out_encoder
) {
    (void)command_buffer;
    if (out_encoder != NULL) {
        *out_encoder = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_blit_command_encoder_destroy(vkmtl_metal_blit_command_encoder *encoder) {
    (void)encoder;
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_copy_buffer_to_buffer(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_buffer *source,
    vkmtl_metal_buffer *destination,
    size_t source_offset,
    size_t destination_offset,
    size_t size
) {
    (void)encoder;
    (void)source;
    (void)destination;
    (void)source_offset;
    (void)destination_offset;
    (void)size;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_write_timestamp(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_query_set *query_set,
    unsigned int query_index
) {
    (void)encoder;
    (void)query_set;
    (void)query_index;
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
    (void)encoder;
    (void)query_set;
    (void)first_query;
    (void)query_count;
    (void)destination;
    (void)destination_offset;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
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
    (void)encoder;
    (void)source;
    (void)destination;
    (void)buffer_offset;
    (void)bytes_per_row;
    (void)bytes_per_image;
    (void)x;
    (void)y;
    (void)z;
    (void)width;
    (void)height;
    (void)depth;
    (void)mip_level;
    (void)slice;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
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
    (void)encoder;
    (void)source;
    (void)destination;
    (void)buffer_offset;
    (void)bytes_per_row;
    (void)bytes_per_image;
    (void)x;
    (void)y;
    (void)z;
    (void)width;
    (void)height;
    (void)depth;
    (void)mip_level;
    (void)slice;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
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
    (void)encoder;
    (void)source;
    (void)destination;
    (void)source_x;
    (void)source_y;
    (void)source_z;
    (void)width;
    (void)height;
    (void)depth;
    (void)source_mip_level;
    (void)source_slice;
    (void)destination_x;
    (void)destination_y;
    (void)destination_z;
    (void)destination_mip_level;
    (void)destination_slice;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_fill_buffer(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_buffer *buffer,
    size_t offset,
    size_t size,
    unsigned int value
) {
    (void)encoder;
    (void)buffer;
    (void)offset;
    (void)size;
    (void)value;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_generate_mipmaps(
    vkmtl_metal_blit_command_encoder *encoder,
    vkmtl_metal_texture *texture
) {
    (void)encoder;
    (void)texture;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_end_encoding(
    vkmtl_metal_blit_command_encoder *encoder
) {
    (void)encoder;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_buffer_set_label(
    vkmtl_metal_buffer *buffer,
    const char *label,
    size_t label_len
) {
    (void)buffer;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_texture_set_label(
    vkmtl_metal_texture *texture,
    const char *label,
    size_t label_len
) {
    (void)texture;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_texture_view_set_label(
    vkmtl_metal_texture_view *view,
    const char *label,
    size_t label_len
) {
    (void)view;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_sampler_state_set_label(
    vkmtl_metal_sampler_state *sampler,
    const char *label,
    size_t label_len
) {
    (void)sampler;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_shader_module_set_label(
    vkmtl_metal_shader_module *shader,
    const char *label,
    size_t label_len
) {
    (void)shader;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_pipeline_state_set_label(
    vkmtl_metal_render_pipeline_state *pipeline,
    const char *label,
    size_t label_len
) {
    (void)pipeline;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_pipeline_state_set_label(
    vkmtl_metal_compute_pipeline_state *pipeline,
    const char *label,
    size_t label_len
) {
    (void)pipeline;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_set_label(
    vkmtl_metal_command_buffer *command_buffer,
    const char *label,
    size_t label_len
) {
    (void)command_buffer;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_push_debug_group(
    vkmtl_metal_command_buffer *command_buffer,
    const char *label,
    size_t label_len
) {
    (void)command_buffer;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_pop_debug_group(
    vkmtl_metal_command_buffer *command_buffer
) {
    (void)command_buffer;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_insert_debug_signpost(
    vkmtl_metal_command_buffer *command_buffer,
    const char *label,
    size_t label_len
) {
    (void)command_buffer;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_set_label(
    vkmtl_metal_render_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    (void)encoder;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_push_debug_group(
    vkmtl_metal_render_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    (void)encoder;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_pop_debug_group(
    vkmtl_metal_render_command_encoder *encoder
) {
    (void)encoder;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_insert_debug_signpost(
    vkmtl_metal_render_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    (void)encoder;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_set_label(
    vkmtl_metal_compute_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    (void)encoder;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_push_debug_group(
    vkmtl_metal_compute_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    (void)encoder;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_pop_debug_group(
    vkmtl_metal_compute_command_encoder *encoder
) {
    (void)encoder;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_compute_command_encoder_insert_debug_signpost(
    vkmtl_metal_compute_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    (void)encoder;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_set_label(
    vkmtl_metal_blit_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    (void)encoder;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_push_debug_group(
    vkmtl_metal_blit_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    (void)encoder;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_pop_debug_group(
    vkmtl_metal_blit_command_encoder *encoder
) {
    (void)encoder;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_blit_command_encoder_insert_debug_signpost(
    vkmtl_metal_blit_command_encoder *encoder,
    const char *label,
    size_t label_len
) {
    (void)encoder;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_acceleration_structure_query_sizes(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_acceleration_structure_kind kind,
    unsigned int primitive_count,
    unsigned int allow_update,
    vkmtl_metal_acceleration_structure_build_sizes *out_sizes
) {
    (void)owner;
    (void)kind;
    (void)primitive_count;
    (void)allow_update;
    if (out_sizes != NULL) {
        *out_sizes = (vkmtl_metal_acceleration_structure_build_sizes){0};
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_acceleration_structure_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_acceleration_structure_kind kind,
    unsigned int primitive_count,
    unsigned int allow_update,
    vkmtl_metal_acceleration_structure **out_acceleration_structure
) {
    (void)owner;
    (void)kind;
    (void)primitive_count;
    (void)allow_update;
    if (out_acceleration_structure != NULL) {
        *out_acceleration_structure = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_acceleration_structure_destroy(
    vkmtl_metal_acceleration_structure *acceleration_structure
) {
    (void)acceleration_structure;
}

vkmtl_metal_status vkmtl_metal_acceleration_structure_set_label(
    vkmtl_metal_acceleration_structure *acceleration_structure,
    const char *label,
    size_t label_len
) {
    (void)acceleration_structure;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

size_t vkmtl_metal_acceleration_structure_result_size(
    const vkmtl_metal_acceleration_structure *acceleration_structure
) {
    (void)acceleration_structure;
    return 0;
}

size_t vkmtl_metal_acceleration_structure_scratch_size(
    const vkmtl_metal_acceleration_structure *acceleration_structure
) {
    (void)acceleration_structure;
    return 0;
}

size_t vkmtl_metal_acceleration_structure_update_scratch_size(
    const vkmtl_metal_acceleration_structure *acceleration_structure
) {
    (void)acceleration_structure;
    return 0;
}

unsigned int vkmtl_metal_acceleration_structure_has_driver_handle(
    const vkmtl_metal_acceleration_structure *acceleration_structure
) {
    (void)acceleration_structure;
    return 0;
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
    (void)acceleration_structure;
    (void)vertex_buffer;
    (void)vertex_buffer_offset;
    (void)vertex_stride;
    (void)vertex_count;
    (void)index_buffer;
    (void)index_buffer_offset;
    (void)index_type;
    (void)primitive_count;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_acceleration_structure_set_aabb_geometry(
    vkmtl_metal_acceleration_structure *acceleration_structure,
    vkmtl_metal_buffer *bounding_box_buffer,
    size_t bounding_box_buffer_offset,
    unsigned int bounding_box_stride,
    unsigned int bounding_box_count,
    unsigned int opaque
) {
    (void)acceleration_structure;
    (void)bounding_box_buffer;
    (void)bounding_box_buffer_offset;
    (void)bounding_box_stride;
    (void)bounding_box_count;
    (void)opaque;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_ray_tracing_pipeline_state_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_shader_module *ray_generation_shader,
    const char *ray_generation_entry,
    size_t ray_generation_entry_len,
    vkmtl_metal_ray_tracing_pipeline_state **out_pipeline
) {
    (void)owner;
    (void)ray_generation_shader;
    (void)ray_generation_entry;
    (void)ray_generation_entry_len;
    if (out_pipeline != NULL) {
        *out_pipeline = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_ray_tracing_pipeline_state_destroy(
    vkmtl_metal_ray_tracing_pipeline_state *pipeline
) {
    (void)pipeline;
}

vkmtl_metal_status vkmtl_metal_ray_tracing_pipeline_state_set_label(
    vkmtl_metal_ray_tracing_pipeline_state *pipeline,
    const char *label,
    size_t label_len
) {
    (void)pipeline;
    (void)label;
    (void)label_len;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

unsigned int vkmtl_metal_ray_tracing_pipeline_state_has_driver_handle(
    const vkmtl_metal_ray_tracing_pipeline_state *pipeline
) {
    (void)pipeline;
    return 0;
}

vkmtl_metal_status vkmtl_metal_shared_event_create(
    vkmtl_metal_clear_screen *owner,
    uint64_t initial_value,
    vkmtl_metal_shared_event **out_event
) {
    (void)owner;
    (void)initial_value;
    if (out_event != NULL) *out_event = NULL;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_shared_event_destroy(vkmtl_metal_shared_event *event) {
    (void)event;
}

vkmtl_metal_status vkmtl_metal_shared_event_get_value(
    const vkmtl_metal_shared_event *event,
    uint64_t *out_value
) {
    (void)event;
    if (out_value != NULL) *out_value = 0;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_shared_event_signal(
    vkmtl_metal_shared_event *event,
    uint64_t value
) {
    (void)event;
    (void)value;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_shared_event_wait(
    const vkmtl_metal_shared_event *event,
    uint64_t value,
    uint64_t timeout_ns
) {
    (void)event;
    (void)value;
    (void)timeout_ns;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_build_acceleration_structure(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_acceleration_structure *acceleration_structure,
    vkmtl_metal_buffer *scratch_buffer,
    size_t scratch_offset,
    size_t required_scratch_size,
    vkmtl_metal_acceleration_structure *update_source,
    vkmtl_metal_acceleration_structure *const *instance_sources,
    size_t instance_source_count,
    unsigned int allow_update,
    unsigned int update
) {
    (void)command_buffer;
    (void)acceleration_structure;
    (void)scratch_buffer;
    (void)scratch_offset;
    (void)required_scratch_size;
    (void)update_source;
    (void)instance_sources;
    (void)instance_source_count;
    (void)allow_update;
    (void)update;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_maintain_acceleration_structure(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_acceleration_structure *source,
    vkmtl_metal_acceleration_structure *destination,
    vkmtl_metal_buffer *scratch_buffer,
    size_t scratch_offset,
    unsigned int operation
) {
    (void)command_buffer;
    (void)source;
    (void)destination;
    (void)scratch_buffer;
    (void)scratch_offset;
    (void)operation;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_dispatch_rays_to_drawable(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_ray_tracing_pipeline_state *pipeline,
    vkmtl_metal_acceleration_structure *acceleration_structure,
    vkmtl_metal_texture_view *output_texture_view,
    unsigned int width,
    unsigned int height,
    const void *inline_data,
    size_t inline_data_len,
    unsigned int inline_data_index
) {
    (void)command_buffer;
    (void)pipeline;
    (void)acceleration_structure;
    (void)output_texture_view;
    (void)width;
    (void)height;
    (void)inline_data;
    (void)inline_data_len;
    (void)inline_data_index;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_command_buffer_dispatch_rays_to_texture(
    vkmtl_metal_command_buffer *command_buffer,
    vkmtl_metal_ray_tracing_pipeline_state *pipeline,
    vkmtl_metal_acceleration_structure *acceleration_structure,
    vkmtl_metal_texture_view *output_texture_view,
    unsigned int width,
    unsigned int height,
    const void *inline_data,
    size_t inline_data_len,
    unsigned int inline_data_index
) {
    (void)command_buffer;
    (void)pipeline;
    (void)acceleration_structure;
    (void)output_texture_view;
    (void)width;
    (void)height;
    (void)inline_data;
    (void)inline_data_len;
    (void)inline_data_index;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}
