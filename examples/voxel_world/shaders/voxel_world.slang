struct VertexInput
{
    float3 position : POSITION0;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL0;
};

struct VertexOutput
{
    float4 position : SV_Position;
    float3 world_position : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float3 normal : TEXCOORD2;
};

struct CameraUniforms
{
    float4 view_projection_row0;
    float4 view_projection_row1;
    float4 view_projection_row2;
    float4 view_projection_row3;
    float4 light_direction_and_ambient;
    float4 light_color_and_strength;
    float4 cycle_factors;
    float4 camera_position_and_ptgi;
};

[[vk::binding(0, 0)]]
ConstantBuffer<CameraUniforms> camera : register(b0, space0);

[[vk::binding(1, 0)]]
Texture2D<float4> block_atlas : register(t1, space0);

[[vk::binding(2, 0)]]
SamplerState block_sampler : register(s2, space0);

[[vk::binding(3, 0)]]
Texture2D<float4> ray_traced_visibility : register(t3, space0);

[[vk::binding(4, 0)]]
Texture2D<float4> ray_traced_indirect : register(t4, space0);

[[vk::binding(5, 0)]]
Texture2D<float4> opaque_hdr : register(t5, space0);

[[vk::binding(6, 0)]]
Texture2D<float4> opaque_surface_gbuffer : register(t6, space0);

[[vk::binding(7, 0)]]
Texture2D<float4> ray_traced_water_reflection : register(t7, space0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input)
{
    float4 world_position = float4(input.position, 1.0);

    VertexOutput output;
    output.position = float4(
        dot(camera.view_projection_row0, world_position),
        dot(camera.view_projection_row1, world_position),
        dot(camera.view_projection_row2, world_position),
        dot(camera.view_projection_row3, world_position)
    );
    output.world_position = input.position;
    output.uv = input.uv;
    output.normal = input.normal;
    return output;
}

float3 detailedNormal(float3 geometric_normal, float2 uv)
{
    uint atlas_width;
    uint atlas_height;
    block_atlas.GetDimensions(atlas_width, atlas_height);
    const float2 texel = 1.0 / float2(max(atlas_width, 1), max(atlas_height, 1));
    const float height_left = block_atlas.Sample(block_sampler, uv - float2(texel.x, 0.0)).a;
    const float height_right = block_atlas.Sample(block_sampler, uv + float2(texel.x, 0.0)).a;
    const float height_up = block_atlas.Sample(block_sampler, uv - float2(0.0, texel.y)).a;
    const float height_down = block_atlas.Sample(block_sampler, uv + float2(0.0, texel.y)).a;

    const float3 normal = normalize(geometric_normal);
    float3 tangent;
    float3 bitangent;
    if (abs(normal.y) > 0.5)
    {
        tangent = float3(1.0, 0.0, 0.0);
        bitangent = float3(0.0, 0.0, normal.y);
    }
    else if (abs(normal.x) > 0.5)
    {
        tangent = float3(0.0, 0.0, -normal.x);
        bitangent = float3(0.0, 1.0, 0.0);
    }
    else
    {
        tangent = float3(normal.z, 0.0, 0.0);
        bitangent = float3(0.0, 1.0, 0.0);
    }

    const float detail_strength = 2.4;
    return normalize(
        normal +
        tangent * ((height_left - height_right) * detail_strength) +
        bitangent * ((height_up - height_down) * detail_strength)
    );
}

// A band is a sinusoid plus a small second harmonic. The analytic derivative
// keeps shading stable while the harmonic sharpens crests without a texture or
// chunk-local coordinate system.
float3 waterWaveBand(
    float2 world_xz,
    float2 direction,
    float wave_number,
    float amplitude,
    float temporal_speed,
    float phase_offset,
    float harmonic_weight,
    float harmonic_offset,
    float time
)
{
    const float angle = dot(world_xz, direction) * wave_number +
        time * temporal_speed + phase_offset;
    const float harmonic_angle = angle * 2.0 + harmonic_offset;
    const float height_shape = sin(angle) + harmonic_weight * sin(harmonic_angle);
    const float slope_shape = cos(angle) +
        harmonic_weight * 2.0 * cos(harmonic_angle);
    return float3(
        direction * (amplitude * wave_number * slope_shape),
        amplitude * height_shape
    );
}

// Returns dH/dx, dH/dz, and height for a deterministic six-band surface.
// Integer temporal speeds make phase 0 and 1 identical. The octave spacing is
// deliberately irregular so the surface reads as continuous wind-driven chop
// rather than a repeating interference grid.
float3 waterWaveData(float2 world_xz, float water_phase)
{
    const float tau = 6.283185307;
    const float time = frac(water_phase) * tau;
    float3 wave = waterWaveBand(
        world_xz, normalize(float2(0.94, 0.34)),
        0.32, 0.052, 1.0, 0.37, 0.09, 1.13, time
    );
    wave += waterWaveBand(
        world_xz, normalize(float2(-0.29, 0.96)),
        0.56, 0.033, -2.0, 1.91, 0.11, 2.47, time
    );
    wave += waterWaveBand(
        world_xz, normalize(float2(0.67, -0.74)),
        0.93, 0.019, 3.0, 3.28, 0.14, 0.73, time
    );
    wave += waterWaveBand(
        world_xz, normalize(float2(-0.86, -0.51)),
        1.48, 0.0105, -4.0, 4.66, 0.16, 3.39, time
    );
    wave += waterWaveBand(
        world_xz, normalize(float2(0.43, 0.90)),
        2.30, 0.0055, 5.0, 5.74, 0.18, 1.82, time
    );
    wave += waterWaveBand(
        world_xz, normalize(float2(-0.72, 0.69)),
        3.55, 0.0027, -7.0, 2.62, 0.20, 4.51, time
    );
    return wave;
}

float3 safeNormalize(float3 value, float3 fallback)
{
    const float length_squared = dot(value, value);
    if (length_squared <= 0.0000001)
    {
        return fallback;
    }
    return value * rsqrt(length_squared);
}

float3 waterSurfaceNormal(
    float3 geometric_normal,
    float3 world_position,
    float3 camera_position,
    float water_phase
)
{
    const float3 normal = safeNormalize(geometric_normal, float3(0.0, 1.0, 0.0));
    if (abs(normal.y) <= 0.5)
    {
        return normal;
    }

    const float3 wave = waterWaveData(world_position.xz, water_phase);
    const float3 to_camera = camera_position - world_position;
    const float camera_distance = sqrt(max(dot(to_camera, to_camera), 0.0));
    const float3 view_direction = safeNormalize(to_camera, normal);
    const float grazing = saturate(1.0 - abs(dot(normal, view_direction)));
    const float distance_stability = lerp(
        1.0,
        0.48,
        smoothstep(22.0, 112.0, camera_distance)
    );
    const float grazing_stability = lerp(
        1.0,
        0.68,
        smoothstep(0.72, 0.985, grazing)
    );
    const float slope_scale = distance_stability * grazing_stability;
    return safeNormalize(
        float3(-wave.x * slope_scale, normal.y, -wave.y * slope_scale),
        normal
    );
}

float4 projectWorldPosition(float3 world_position)
{
    const float4 homogeneous_position = float4(world_position, 1.0);
    return float4(
        dot(camera.view_projection_row0, homogeneous_position),
        dot(camera.view_projection_row1, homogeneous_position),
        dot(camera.view_projection_row2, homogeneous_position),
        dot(camera.view_projection_row3, homogeneous_position)
    );
}

float2 projectedUv(float3 world_position)
{
    const float4 clip_position = projectWorldPosition(world_position);
    const float inverse_w = 1.0 / max(abs(clip_position.w), 0.0001);
    const float2 ndc = clip_position.xy * inverse_w * sign(clip_position.w);
    return float2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
}

bool validScreenUv(float2 uv)
{
    // The comparisons are also false for NaNs, which keeps invalid projected
    // coordinates away from sampled texture addressing.
    return uv.x >= 0.001 && uv.x <= 0.999 && uv.y >= 0.001 && uv.y <= 0.999;
}

float finiteNonNegative(float value)
{
    // NaN fails both comparisons. The upper bound also catches infinities and
    // keeps the rgba16f overlay representable.
    if (!(value >= 0.0 || value <= 0.0) || value > 65504.0)
    {
        return 0.0;
    }
    return max(value, 0.0);
}

float3 finiteRadiance(float3 value)
{
    return float3(
        finiteNonNegative(value.x),
        finiteNonNegative(value.y),
        finiteNonNegative(value.z)
    );
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0
{
    float3 normal = detailedNormal(input.normal, input.uv);
    float3 light_direction = normalize(camera.light_direction_and_ambient.xyz);
    float ambient = camera.light_direction_and_ambient.w;
    float directional = max(dot(normal, light_direction), 0.0);

    uint lighting_width;
    uint lighting_height;
    ray_traced_visibility.GetDimensions(lighting_width, lighting_height);
    const uint2 lighting_pixel = min(
        uint2(input.position.xy),
        uint2(max(lighting_width, 1) - 1, max(lighting_height, 1) - 1)
    );
    const float4 traced_sample = ray_traced_visibility.Load(int3(lighting_pixel, 0));
    const float3 indirect_radiance = max(
        ray_traced_indirect.Load(int3(lighting_pixel, 0)).rgb,
        0.0
    );
    const float directional_visibility = traced_sample.a < 0.0
        ? 1.0
        : saturate(traced_sample.a);
    const float daylight = saturate(camera.cycle_factors.x);
    const float night = saturate(camera.cycle_factors.y);
    const float twilight = saturate(camera.cycle_factors.z);

    const float3 night_sky_tint = float3(0.035, 0.055, 0.13);
    const float3 day_sky_tint = float3(0.50, 0.66, 0.92);
    float3 sky_tint = lerp(night_sky_tint, day_sky_tint, daylight);
    sky_tint = lerp(
        sky_tint,
        float3(0.86, 0.48, 0.25),
        twilight * 0.18
    );
    const float ptgi_enabled = camera.camera_position_and_ptgi.w > 0.5 ? 1.0 : 0.0;
    const float ptgi_environment_weight = lerp(0.20, 0.14, daylight);
    const float raster_environment_weight = lerp(
        1.0,
        ptgi_environment_weight,
        ptgi_enabled
    );
    const float3 environment = sky_tint * ambient * lerp(1.0, 0.35, night) *
        raster_environment_weight;
    const float3 direct = camera.light_color_and_strength.rgb *
        (directional * camera.light_color_and_strength.w * directional_visibility);
    const float3 albedo = block_atlas.Sample(block_sampler, input.uv).rgb;
    const float3 surface_radiance = albedo * (environment + direct + indirect_radiance);
    return float4(surface_radiance, 1.0);
}

[shader("fragment")]
float4 water_fs(VertexOutput input) : SV_Target0
{
    const float daylight = saturate(camera.cycle_factors.x);
    const float night = saturate(camera.cycle_factors.y);
    const float twilight = saturate(camera.cycle_factors.z);
    const float water_phase = camera.cycle_factors.w;
    const float3 camera_position = camera.camera_position_and_ptgi.xyz;
    const float3 wave = waterWaveData(input.world_position.xz, water_phase);

    float3 normal = waterSurfaceNormal(
        input.normal,
        input.world_position,
        camera_position,
        water_phase
    );
    const float3 view_direction = safeNormalize(
        camera_position - input.world_position,
        float3(0.0, 1.0, 0.0)
    );
    if (dot(normal, view_direction) < 0.0)
    {
        normal = -normal;
    }

    uint lighting_width;
    uint lighting_height;
    ray_traced_visibility.GetDimensions(lighting_width, lighting_height);
    const uint2 lighting_pixel = min(
        uint2(input.position.xy),
        uint2(max(lighting_width, 1) - 1, max(lighting_height, 1) - 1)
    );
    const float4 traced_sample = ray_traced_visibility.Load(int3(lighting_pixel, 0));
    const float3 indirect_radiance = finiteRadiance(
        ray_traced_indirect.Load(int3(lighting_pixel, 0)).rgb
    );
    const float directional_visibility = traced_sample.a < 0.0
        ? 1.0
        : saturate(traced_sample.a);

    uint hdr_width;
    uint hdr_height;
    opaque_hdr.GetDimensions(hdr_width, hdr_height);
    const float2 hdr_extent = float2(max(hdr_width, 1), max(hdr_height, 1));
    const float2 screen_uv = input.position.xy / hdr_extent;
    const uint2 last_hdr_pixel = uint2(max(hdr_width, 1) - 1, max(hdr_height, 1) - 1);
    const uint2 surface_pixel = min(uint2(input.position.xy), last_hdr_pixel);
    const float3 camera_to_surface = input.world_position - camera_position;
    const float water_surface_distance = sqrt(max(
        dot(camera_to_surface, camera_to_surface),
        0.0
    ));

    // Start with the undistorted depth. It gives a conservative thickness for
    // scaling refraction before the displaced sample is known. Thin water is
    // nearly undistorted, and distant detail is damped to avoid subpixel swim.
    const float4 direct_surface = opaque_surface_gbuffer.Load(int3(surface_pixel, 0));
    const bool direct_depth_valid = direct_surface.w > water_surface_distance + 0.01 &&
        direct_surface.w < 10000.0;
    const float direct_thickness = direct_depth_valid
        ? clamp(direct_surface.w - water_surface_distance, 0.0, 32.0)
        : 0.0;

    // Project straight and refracted segments into screen space. The segment
    // length and displacement both depend on the conservative depth estimate,
    // while distance attenuation stabilizes grazing and horizon pixels.
    const float3 incident_direction = -view_direction;
    float3 refracted_direction = refract(incident_direction, normal, 0.75019);
    if (dot(refracted_direction, refracted_direction) < 0.0001)
    {
        refracted_direction = incident_direction;
    }
    const float thickness_response = 1.0 - exp(-direct_thickness * 0.62);
    const float distance_response = lerp(
        1.0,
        0.30,
        smoothstep(18.0, 112.0, water_surface_distance)
    );
    const float refraction_path = lerp(
        0.28,
        1.20,
        saturate(direct_thickness * 0.16)
    );
    const float2 straight_uv = projectedUv(
        input.world_position + incident_direction * refraction_path
    );
    const float2 bent_uv = projectedUv(
        input.world_position + refracted_direction * refraction_path
    );
    const float refraction_strength = thickness_response * distance_response * 0.82;
    const float2 candidate_uv = screen_uv +
        (bent_uv - straight_uv) * refraction_strength;

    // Surface distance and validity are discontinuous data. Point-load them
    // so shoreline/background texels cannot manufacture a false thickness.
    const bool candidate_uv_valid = validScreenUv(candidate_uv);
    const float2 clamped_candidate_uv = candidate_uv_valid
        ? candidate_uv
        : saturate(screen_uv);
    const uint2 candidate_pixel = min(
        uint2(saturate(clamped_candidate_uv) * hdr_extent),
        last_hdr_pixel
    );
    const float4 candidate_surface = opaque_surface_gbuffer.Load(int3(candidate_pixel, 0));
    const bool candidate_depth_valid = candidate_uv_valid &&
        candidate_surface.w > water_surface_distance + 0.01 &&
        candidate_surface.w < 10000.0;
    const float2 refracted_uv = candidate_depth_valid ? candidate_uv : screen_uv;
    const float opaque_distance = candidate_depth_valid
        ? candidate_surface.w
        : (direct_depth_valid ? direct_surface.w : water_surface_distance);
    const float water_thickness = clamp(
        opaque_distance - water_surface_distance,
        0.0,
        32.0
    );

    const float3 opaque_radiance = finiteRadiance(
        opaque_hdr.SampleLevel(block_sampler, saturate(refracted_uv), 0.0).rgb
    );
    const float3 sigma_a = float3(0.240, 0.062, 0.014);
    const float sigma_s = 0.070;
    const float3 sigma_t = sigma_a + float3(sigma_s, sigma_s, sigma_s);
    const float3 transmittance = exp(-sigma_t * water_thickness);

    const float3 night_sky_tint = float3(0.025, 0.045, 0.12);
    const float3 day_sky_tint = float3(0.46, 0.67, 0.94);
    float3 sky_tint = lerp(night_sky_tint, day_sky_tint, daylight);
    sky_tint = lerp(sky_tint, float3(0.92, 0.44, 0.20), twilight * 0.24);
    sky_tint *= lerp(1.0, 0.62, night);

    const float3 light_direction = safeNormalize(
        camera.light_direction_and_ambient.xyz,
        float3(0.0, 1.0, 0.0)
    );
    const float3 half_direction = safeNormalize(
        light_direction + view_direction,
        normal
    );
    const float half_alignment = max(dot(normal, half_direction), 0.0);
    const float n_dot_v = saturate(dot(normal, view_direction));
    const float one_minus_n_dot_v = 1.0 - n_dot_v;
    const float fresnel = 0.02 + 0.98 *
        one_minus_n_dot_v * one_minus_n_dot_v * one_minus_n_dot_v *
        one_minus_n_dot_v * one_minus_n_dot_v;

    // Homogeneous single scattering. The medium itself has no painted blue
    // albedo: its blue-green appearance emerges from spectral extinction and
    // the relative scattering albedo over a real water path length.
    const float forward_alignment = saturate(dot(light_direction, view_direction));
    const float phase_weight = lerp(0.62, 1.12, pow(forward_alignment, 4.0));
    const float3 environment_illumination = sky_tint * (
        0.12 + camera.light_direction_and_ambient.w * lerp(0.64, 0.38, night)
    );
    const float3 directional_illumination =
        camera.light_color_and_strength.rgb *
        camera.light_color_and_strength.w * directional_visibility *
        (0.075 + forward_alignment * 0.16);
    const float3 volume_illumination = finiteRadiance(
        environment_illumination +
        directional_illumination +
        indirect_radiance * 0.10
    );
    const float3 scattering_albedo = float3(sigma_s, sigma_s, sigma_s) / sigma_t;
    const float3 in_scattering = volume_illumination * scattering_albedo *
        (1.0 - transmittance) * phase_weight;
    const float3 transmitted_radiance = opaque_radiance * transmittance +
        in_scattering;

    // A smooth surface produces a tight sun/moon streak. Avoid the old broad
    // cyan lobe, which read as an opaque plastic coating on shallow water.
    const float glint_exponent = 420.0;
    const float glint = pow(half_alignment, glint_exponent) *
        camera.light_color_and_strength.w * directional_visibility;
    const float crest_focus = lerp(
        0.86,
        1.08,
        smoothstep(-0.015, 0.075, wave.z)
    );
    const float3 glint_radiance = camera.light_color_and_strength.rgb *
        glint * crest_focus * lerp(0.32, 1.0, fresnel);
    const float3 sky_reflection = sky_tint * lerp(0.60, 1.0, daylight);
    const float4 rt_reflection = ray_traced_water_reflection.Load(int3(surface_pixel, 0));
    const float reflection_validity = saturate(rt_reflection.a);
    const float3 reflection_radiance = lerp(
        sky_reflection,
        finiteRadiance(rt_reflection.rgb),
        reflection_validity
    );

    const float3 water_radiance = finiteRadiance(lerp(
        transmitted_radiance,
        reflection_radiance,
        fresnel
    ) + glint_radiance);
    // Water is composed into an independent overlay target. Alpha therefore
    // marks full pixel coverage instead of carrying transparency for blending.
    return float4(water_radiance, 1.0);
}
