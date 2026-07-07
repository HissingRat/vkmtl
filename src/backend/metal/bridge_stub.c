#include "bridge.h"

struct vkmtl_metal_probe {
    int unused;
};

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
    unsigned int width,
    unsigned int height
) {
    (void)cocoa_window;
    (void)width;
    (void)height;
    if (out_clear_screen != NULL) {
        *out_clear_screen = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_clear_screen_destroy(vkmtl_metal_clear_screen *clear_screen) {
    (void)clear_screen;
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
    vkmtl_metal_texture_view **out_view
) {
    (void)texture;
    (void)dimension;
    (void)format;
    (void)base_mip_level;
    (void)mip_level_count;
    (void)base_array_layer;
    (void)array_layer_count;
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
    vkmtl_metal_shader_module *fragment_shader,
    const char *fragment_entry,
    size_t fragment_entry_len,
    vkmtl_metal_texture_format color_format,
    unsigned int color_write_mask,
    unsigned int blend_enabled,
    vkmtl_metal_blend_factor source_rgb_blend_factor,
    vkmtl_metal_blend_factor destination_rgb_blend_factor,
    vkmtl_metal_blend_operation rgb_blend_operation,
    vkmtl_metal_blend_factor source_alpha_blend_factor,
    vkmtl_metal_blend_factor destination_alpha_blend_factor,
    vkmtl_metal_blend_operation alpha_blend_operation,
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
    (void)owner;
    (void)vertex_shader;
    (void)vertex_entry;
    (void)vertex_entry_len;
    (void)fragment_shader;
    (void)fragment_entry;
    (void)fragment_entry_len;
    (void)color_format;
    (void)color_write_mask;
    (void)blend_enabled;
    (void)source_rgb_blend_factor;
    (void)destination_rgb_blend_factor;
    (void)rgb_blend_operation;
    (void)source_alpha_blend_factor;
    (void)destination_alpha_blend_factor;
    (void)alpha_blend_operation;
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
    vkmtl_metal_compute_pipeline_state **out_pipeline
) {
    (void)owner;
    (void)compute_shader;
    (void)compute_entry;
    (void)compute_entry_len;
    if (out_pipeline != NULL) {
        *out_pipeline = NULL;
    }
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

void vkmtl_metal_compute_pipeline_state_destroy(vkmtl_metal_compute_pipeline_state *pipeline) {
    (void)pipeline;
}

vkmtl_metal_status vkmtl_metal_command_buffer_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_command_buffer **out_command_buffer
) {
    (void)owner;
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

vkmtl_metal_status vkmtl_metal_command_buffer_commit(
    vkmtl_metal_command_buffer *command_buffer
) {
    (void)command_buffer;
    return VKMTL_METAL_STATUS_UNSUPPORTED;
}

vkmtl_metal_status vkmtl_metal_render_command_encoder_create(
    vkmtl_metal_clear_screen *owner,
    vkmtl_metal_command_buffer *command_buffer,
    float clear_red,
    float clear_green,
    float clear_blue,
    float clear_alpha,
    vkmtl_metal_texture_view *color_texture_view,
    vkmtl_metal_texture_view *resolve_texture_view,
    unsigned int use_depth,
    vkmtl_metal_texture_view *depth_texture_view,
    float clear_depth,
    vkmtl_metal_render_command_encoder **out_encoder
) {
    (void)owner;
    (void)command_buffer;
    (void)clear_red;
    (void)clear_green;
    (void)clear_blue;
    (void)clear_alpha;
    (void)color_texture_view;
    (void)resolve_texture_view;
    (void)use_depth;
    (void)depth_texture_view;
    (void)clear_depth;
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
