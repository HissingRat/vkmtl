struct PresentVertexOutput
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[[vk::binding(0, 0)]]
Texture2D<float4> scene_texture : register(t0, space0);

[[vk::binding(1, 0)]]
SamplerState scene_sampler : register(s1, space0);

static const float vkmtl_exposure = 1.0;

float3 acesFitted(float3 scene_linear)
{
    if (!all(isfinite(scene_linear))) scene_linear = float3(0.0);
    float3 value = max(scene_linear * vkmtl_exposure, float3(0.0));
    float3 numerator = value * (2.51 * value + 0.03);
    float3 denominator = value * (2.43 * value + 0.59) + 0.14;
    return saturate(numerator / denominator);
}

[shader("vertex")]
PresentVertexOutput present_vs(uint vertex_id : SV_VertexID)
{
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    float2 uvs[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0)
    };

    PresentVertexOutput output;
    output.position = float4(positions[vertex_id], 0.0, 1.0);
    output.uv = uvs[vertex_id];
    return output;
}

[shader("fragment")]
float4 present_fs(PresentVertexOutput input) : SV_Target0
{
    float3 scene_linear = scene_texture.Sample(scene_sampler, input.uv).rgb;
    // Return display-linear color. The sRGB attachment owns the only OETF.
    return float4(acesFitted(scene_linear), 1.0);
}
