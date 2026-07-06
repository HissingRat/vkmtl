struct ColorVertexInput
{
    float2 position : POSITION0;
    float3 color : COLOR0;
};

struct ColorVertexOutput
{
    float4 position : SV_Position;
    float3 color : COLOR0;
};

[shader("vertex")]
ColorVertexOutput msaa_vs(ColorVertexInput input)
{
    ColorVertexOutput output;
    output.position = float4(input.position, 0.0, 1.0);
    output.color = input.color;
    return output;
}

[shader("fragment")]
float4 msaa_fs(ColorVertexOutput input) : SV_Target0
{
    return float4(input.color, 1.0);
}

struct ScreenVertexInput
{
    float2 position : POSITION0;
    float2 uv : TEXCOORD0;
};

struct ScreenVertexOutput
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[[vk::binding(0, 0)]]
Texture2D<float4> resolved_texture : register(t0, space0);

[[vk::binding(1, 0)]]
SamplerState resolved_sampler : register(s1, space0);

[shader("vertex")]
ScreenVertexOutput screen_vs(ScreenVertexInput input)
{
    ScreenVertexOutput output;
    output.position = float4(input.position, 0.0, 1.0);
    output.uv = input.uv;
    return output;
}

[shader("fragment")]
float4 screen_fs(ScreenVertexOutput input) : SV_Target0
{
    return resolved_texture.Sample(resolved_sampler, input.uv);
}
