struct TemporalData
{
    float4 current_camera_position_and_tan_half_fov;
    float4 current_camera_forward_and_aspect;
    float4 current_camera_right_and_reset;
    float4 current_camera_up_and_history_limit;
    float4 previous_camera_position_and_valid;
    float4 previous_view_projection_row0;
    float4 previous_view_projection_row1;
    float4 previous_view_projection_row2;
    float4 previous_view_projection_row3;
    float4 filter_mode_and_weights;
};

struct AtrousData
{
    float4 step_and_extent;
    float4 filter_parameters;
};

[[vk::binding(0, 0)]]
ConstantBuffer<TemporalData> temporal_data : register(b0, space0);
[[vk::binding(1, 0)]]
Texture2D<float4> temporal_current : register(t1, space0);
[[vk::binding(2, 0)]]
Texture2D<float4> temporal_gbuffer : register(t2, space0);
[[vk::binding(3, 0)]]
Texture2D<float4> temporal_previous : register(t3, space0);
[[vk::binding(4, 0)]]
Texture2D<float4> temporal_previous_gbuffer : register(t4, space0);
[[vk::binding(5, 0)]]
SamplerState temporal_sampler : register(s5, space0);
[[vk::binding(6, 0)]]
[[vk::image_format("rgba16f")]]
RWTexture2D<float4> temporal_output : register(u6, space0);

float3 currentRayDirection(uint2 pixel, uint2 size)
{
    const float2 uv = (float2(pixel) + 0.5) / float2(size);
    const float2 screen = float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
    const float tan_half_fov = max(abs(temporal_data.current_camera_position_and_tan_half_fov.w), 0.0001);
    const float aspect = max(abs(temporal_data.current_camera_forward_and_aspect.w), 0.0001);
    return normalize(
        temporal_data.current_camera_forward_and_aspect.xyz +
        temporal_data.current_camera_right_and_reset.xyz * (screen.x * aspect * tan_half_fov) +
        temporal_data.current_camera_up_and_history_limit.xyz * (screen.y * tan_half_fov)
    );
}

float4 projectPrevious(float3 world_position)
{
    const float4 point = float4(world_position, 1.0);
    return float4(
        dot(temporal_data.previous_view_projection_row0, point),
        dot(temporal_data.previous_view_projection_row1, point),
        dot(temporal_data.previous_view_projection_row2, point),
        dot(temporal_data.previous_view_projection_row3, point)
    );
}

[numthreads(8, 8, 1)]
void temporal_cs(uint3 dispatch_thread_id : SV_DispatchThreadID)
{
    uint width;
    uint height;
    temporal_output.GetDimensions(width, height);
    const uint2 pixel = dispatch_thread_id.xy;
    if (pixel.x >= width || pixel.y >= height) return;

    const float4 gbuffer = temporal_gbuffer.Load(int3(pixel, 0));
    const float4 current = temporal_current.Load(int3(pixel, 0));
    const bool visibility_mode = temporal_data.filter_mode_and_weights.x > 0.5;
    if (gbuffer.w <= 0.0 || current.w < 0.0)
    {
        temporal_output[pixel] = float4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    float3 neighborhood_min = current.rgb;
    float3 neighborhood_max = current.rgb;
    const float current_visibility = saturate(current.w);
    if (!visibility_mode)
    {
        for (int y = -1; y <= 1; ++y)
        {
            for (int x = -1; x <= 1; ++x)
            {
                const int2 sample_pixel = clamp(
                    int2(pixel) + int2(x, y),
                    int2(0, 0),
                    int2(int(width) - 1, int(height) - 1)
                );
                const float3 sample_value = temporal_current.Load(int3(sample_pixel, 0)).rgb;
                neighborhood_min = min(neighborhood_min, sample_value);
                neighborhood_max = max(neighborhood_max, sample_value);
            }
        }
    }

    const bool reset = temporal_data.current_camera_right_and_reset.w > 0.5;
    const bool previous_valid = temporal_data.previous_camera_position_and_valid.w > 0.5;
    bool accept_history = !reset && previous_valid;
    float2 previous_uv = float2(0.0, 0.0);
    float predicted_previous_distance = 0.0;
    if (accept_history)
    {
        const float3 world_position = temporal_data.current_camera_position_and_tan_half_fov.xyz +
            currentRayDirection(pixel, uint2(width, height)) * gbuffer.w;
        const float4 previous_clip = projectPrevious(world_position);
        accept_history = previous_clip.w > 0.0001;
        if (accept_history)
        {
            const float2 previous_ndc = previous_clip.xy / previous_clip.w;
            previous_uv = float2(
                previous_ndc.x * 0.5 + 0.5,
                0.5 - previous_ndc.y * 0.5
            );
            accept_history = all(previous_uv >= 0.0) && all(previous_uv <= 1.0);
            predicted_previous_distance = length(
                world_position - temporal_data.previous_camera_position_and_valid.xyz
            );
        }
    }

    float4 previous = float4(0.0, 0.0, 0.0, 0.0);
    if (accept_history)
    {
        const float4 previous_gbuffer = temporal_previous_gbuffer.SampleLevel(
            temporal_sampler,
            previous_uv,
            0.0
        );
        previous = temporal_previous.SampleLevel(temporal_sampler, previous_uv, 0.0);
        const float depth_tolerance = 0.18 + predicted_previous_distance * 0.025;
        accept_history = previous_gbuffer.w > 0.0 &&
            abs(previous_gbuffer.w - predicted_previous_distance) <= depth_tolerance &&
            dot(normalize(previous_gbuffer.xyz), normalize(gbuffer.xyz)) >= 0.82 &&
            previous.w >= 1.0 &&
            (!visibility_mode || previous.b > 0.5);
    }

    const float history_limit = max(temporal_data.current_camera_up_and_history_limit.w, 1.0);
    if (visibility_mode)
    {
        float resolved_mean = current_visibility;
        float resolved_second_moment = current_visibility * current_visibility;
        float history_length = 1.0;
        if (accept_history)
        {
            history_length = min(previous.w + 1.0, history_limit);
            const float minimum_current_weight = max(
                temporal_data.filter_mode_and_weights.y,
                0.001
            );
            const float current_weight = max(1.0 / history_length, minimum_current_weight);
            const float history_mean = saturate(previous.r);
            const float history_second_moment = saturate(previous.g);
            resolved_mean = lerp(history_mean, current_visibility, current_weight);
            resolved_second_moment = lerp(
                history_second_moment,
                current_visibility * current_visibility,
                current_weight
            );
        }
        resolved_mean = saturate(resolved_mean);
        resolved_second_moment = saturate(max(
            resolved_second_moment,
            resolved_mean * resolved_mean
        ));
        temporal_output[pixel] = float4(
            resolved_mean,
            resolved_second_moment,
            1.0,
            history_length
        );
        return;
    }

    float3 resolved = current.rgb;
    float history_length = 1.0;
    if (accept_history)
    {
        const float3 clamped_history = clamp(previous.rgb, neighborhood_min, neighborhood_max);
        history_length = min(previous.w + 1.0, history_limit);
        const float current_weight = max(1.0 / history_length, 0.045);
        resolved = lerp(clamped_history, current.rgb, current_weight);
    }
    temporal_output[pixel] = float4(resolved, history_length);
}

[[vk::binding(7, 0)]]
ConstantBuffer<AtrousData> atrous_data : register(b7, space0);
[[vk::binding(8, 0)]]
Texture2D<float4> atrous_input : register(t8, space0);
[[vk::binding(9, 0)]]
Texture2D<float4> atrous_gbuffer : register(t9, space0);
[[vk::binding(11, 0)]]
[[vk::image_format("rgba16f")]]
RWTexture2D<float4> atrous_output : register(u11, space0);

[numthreads(8, 8, 1)]
void atrous_cs(uint3 dispatch_thread_id : SV_DispatchThreadID)
{
    uint width;
    uint height;
    atrous_output.GetDimensions(width, height);
    const uint2 pixel = dispatch_thread_id.xy;
    if (pixel.x >= width || pixel.y >= height) return;

    const bool visibility_mode = atrous_data.step_and_extent.w > 0.5;
    const float4 center_surface = atrous_gbuffer.Load(int3(pixel, 0));
    const float4 center_value = atrous_input.Load(int3(pixel, 0));
    if (center_surface.w <= 0.0)
    {
        atrous_output[pixel] = visibility_mode
            ? float4(0.0, 0.0, 0.0, -1.0)
            : center_value;
        return;
    }

    const int step_width = max(int(atrous_data.step_and_extent.x), 1);
    const float normal_sigma = max(atrous_data.filter_parameters.x, 1.0);
    const float depth_sigma = max(atrous_data.filter_parameters.y, 0.0001);
    const float luminance_sigma = max(atrous_data.filter_parameters.z, 0.0001);
    const float kernel[5] = { 1.0, 4.0, 6.0, 4.0, 1.0 };
    const float center_luminance = dot(center_value.rgb, float3(0.2126, 0.7152, 0.0722));
    float3 sum = float3(0.0, 0.0, 0.0);
    float2 visibility_sum = float2(0.0, 0.0);
    float weight_sum = 0.0;

    for (int y = -2; y <= 2; ++y)
    {
        for (int x = -2; x <= 2; ++x)
        {
            const int2 sample_pixel = clamp(
                int2(pixel) + int2(x, y) * step_width,
                int2(0, 0),
                int2(int(width) - 1, int(height) - 1)
            );
            const float4 sample_surface = atrous_gbuffer.Load(int3(sample_pixel, 0));
            const float4 sample_value = atrous_input.Load(int3(sample_pixel, 0));
            if (sample_surface.w <= 0.0) continue;

            const float normal_weight = pow(
                saturate(dot(normalize(center_surface.xyz), normalize(sample_surface.xyz))),
                normal_sigma
            );
            const float depth_delta = abs(sample_surface.w - center_surface.w) /
                max(center_surface.w, 1.0);
            const float depth_weight = exp(-depth_delta / depth_sigma);
            const float spatial_weight = kernel[x + 2] * kernel[y + 2];
            float weight = spatial_weight * normal_weight * depth_weight;
            if (!visibility_mode)
            {
                const float sample_luminance = dot(sample_value.rgb, float3(0.2126, 0.7152, 0.0722));
                const float luminance_weight = exp(
                    -abs(sample_luminance - center_luminance) /
                    (luminance_sigma * (0.25 + center_luminance))
                );
                weight *= luminance_weight;
            }
            if (visibility_mode)
            {
                visibility_sum += sample_value.rg * weight;
            }
            else
            {
                sum += sample_value.rgb * weight;
            }
            weight_sum += weight;
        }
    }
    if (visibility_mode)
    {
        float2 filtered_visibility = weight_sum > 0.0001
            ? visibility_sum / weight_sum
            : center_value.rg;
        filtered_visibility.x = saturate(filtered_visibility.x);
        filtered_visibility.y = saturate(max(
            filtered_visibility.y,
            filtered_visibility.x * filtered_visibility.x
        ));
        atrous_output[pixel] = float4(
            filtered_visibility.x,
            filtered_visibility.y,
            1.0,
            filtered_visibility.x
        );
        return;
    }
    const float3 filtered = weight_sum > 0.0001 ? sum / weight_sum : center_value.rgb;
    atrous_output[pixel] = float4(filtered, center_value.w);
}
