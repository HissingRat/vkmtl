struct FullscreenVertex
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[[vk::binding(0, 0)]]
Texture2D<float4> hdr_scene : register(t0, space0);

[[vk::binding(1, 0)]]
SamplerState hdr_sampler : register(s1, space0);

struct PresentationData
{
    float4 manual_output_transfer_and_padding;
};

[[vk::binding(2, 0)]]
ConstantBuffer<PresentationData> presentation : register(b2, space0);

[[vk::binding(3, 0)]]
Texture2D<float4> water_overlay : register(t3, space0);

[shader("vertex")]
FullscreenVertex present_vs(uint vertex_id : SV_VertexID)
{
    const float2 positions[3] = {
        float2(-1.0, -1.0),
        float2(3.0, -1.0),
        float2(-1.0, 3.0)
    };
    const float2 uvs[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0)
    };
    FullscreenVertex output;
    output.position = float4(positions[vertex_id], 0.0, 1.0);
    output.uv = uvs[vertex_id];
    return output;
}

float luminance(float3 color)
{
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

float3 filmicCurve(float3 color)
{
    const float curve = 2.5;
    const float3 shoulder = 1.0 - exp(-max(color, 0.0) * curve);
    const float3 toe = color * color / (color * color + 0.055);
    return lerp(toe, shoulder, 0.62);
}

float hashNoise(float2 pixel)
{
    return frac(sin(dot(pixel, float2(12.9898, 78.233))) * 43758.5453);
}

float3 linearToSrgb(float3 color)
{
    const float3 low = color * 12.92;
    const float3 high = 1.055 * pow(max(color, 0.0), 1.0 / 2.4) - 0.055;
    return float3(
        color.x <= 0.0031308 ? low.x : high.x,
        color.y <= 0.0031308 ? low.y : high.y,
        color.z <= 0.0031308 ? low.z : high.z
    );
}

[shader("fragment")]
float4 present_fs(FullscreenVertex input) : SV_Target0
{
    uint width;
    uint height;
    hdr_scene.GetDimensions(width, height);
    const float2 texel = 1.0 / float2(max(width, 1u), max(height, 1u));
    const float4 center_hdr = hdr_scene.SampleLevel(hdr_sampler, input.uv, 0.0);
    const float4 center_overlay = water_overlay.SampleLevel(hdr_sampler, input.uv, 0.0);
    const float3 center = max(
        center_overlay.rgb + center_hdr.rgb * (1.0 - saturate(center_overlay.a)),
        0.0
    );

    float3 neighborhood = float3(0.0, 0.0, 0.0);
    const float2 bloom_offsets[8] = {
        float2(-2.0, 0.0), float2(2.0, 0.0),
        float2(0.0, -2.0), float2(0.0, 2.0),
        float2(-1.5, -1.5), float2(1.5, -1.5),
        float2(-1.5, 1.5), float2(1.5, 1.5)
    };
    for (uint index = 0; index < 8; ++index)
    {
        const float2 sample_uv = input.uv + bloom_offsets[index] * texel;
        const float4 sample_hdr = hdr_scene.SampleLevel(hdr_sampler, sample_uv, 0.0);
        const float4 sample_overlay = water_overlay.SampleLevel(hdr_sampler, sample_uv, 0.0);
        neighborhood += max(
            sample_overlay.rgb + sample_hdr.rgb * (1.0 - saturate(sample_overlay.a)),
            0.0
        );
    }
    neighborhood *= 0.125;
    const float bloom_gate = saturate((luminance(neighborhood) - 0.72) * 1.6);
    const float3 bloom = neighborhood * bloom_gate * 0.085;
    const float3 sharpened = max(center + (center - neighborhood) * 0.12, 0.0);

    float3 mapped = filmicCurve(sharpened + bloom);
    const float grey = luminance(mapped);
    mapped = lerp(float3(grey, grey, grey), mapped, 1.04);
    const float2 centered_uv = input.uv * 2.0 - 1.0;
    const float vignette = 1.0 - smoothstep(0.34, 1.35, dot(centered_uv, centered_uv));
    mapped *= lerp(0.79, 1.0, vignette);
    mapped = saturate(mapped);
    if (presentation.manual_output_transfer_and_padding.x > 0.5)
    {
        mapped = linearToSrgb(mapped);
    }
    const float dither = (hashNoise(input.position.xy) - 0.5) / 255.0;
    return float4(saturate(mapped + dither), 1.0);
}
