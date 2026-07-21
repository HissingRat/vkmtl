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
    float4 camera_position_and_frame;
};

[[vk::binding(0, 0)]]
ConstantBuffer<CameraUniforms> camera : register(b0, space0);

[[vk::binding(1, 0)]]
Texture2D<float4> block_atlas : register(t1, space0);

[[vk::binding(2, 0)]]
SamplerState block_sampler : register(s2, space0);

[shader("vertex")]
VertexOutput gbuffer_vs(VertexInput input)
{
    const float4 world_position = float4(input.position, 1.0);
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
    return normalize(
        normal +
        tangent * ((height_left - height_right) * 2.4) +
        bitangent * ((height_up - height_down) * 2.4)
    );
}

// Kept byte-for-byte equivalent to the water shading path so the reflection
// ray generation pass sees the same animated world-continuous surface normal.
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

struct WaterGBufferOutput
{
    float4 unused_surface : SV_Target0;
    float4 water_surface : SV_Target1;
};

[shader("fragment")]
float4 gbuffer_fs(VertexOutput input) : SV_Target0
{
    const float3 normal = detailedNormal(input.normal, input.uv);
    const float distance_to_camera = length(input.world_position - camera.camera_position_and_frame.xyz);
    return float4(normal, max(distance_to_camera, 0.0001));
}

[shader("fragment")]
WaterGBufferOutput water_gbuffer_fs(VertexOutput input)
{
    float3 normal = waterSurfaceNormal(
        input.normal,
        input.world_position,
        camera.camera_position_and_frame.xyz,
        camera.cycle_factors.w
    );
    const float3 view_direction = safeNormalize(
        camera.camera_position_and_frame.xyz - input.world_position,
        float3(0.0, 1.0, 0.0)
    );
    if (dot(normal, view_direction) < 0.0)
    {
        normal = -normal;
    }

    const float3 camera_to_surface =
        input.world_position - camera.camera_position_and_frame.xyz;
    const float distance_to_camera = sqrt(max(
        dot(camera_to_surface, camera_to_surface),
        0.0
    ));
    WaterGBufferOutput output;
    output.unused_surface = float4(0.0, 0.0, 0.0, 0.0);
    output.water_surface = float4(normal, max(distance_to_camera, 0.0001));
    return output;
}
