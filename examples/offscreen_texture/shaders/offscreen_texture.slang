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

[vk::constant_id(7)]
const float color_scale = 0.0;

[shader("vertex")]
ColorVertexOutput offscreen_vs(ColorVertexInput input)
{
    ColorVertexOutput output;
    output.position = float4(input.position, 0.0, 1.0);
    output.color = input.color;
    return output;
}

[shader("fragment")]
float4 offscreen_fs(ColorVertexOutput input) : SV_Target0
{
    return float4(input.color * color_scale, 1.0);
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
Texture2D<float4> color_texture : register(t0, space0);

[[vk::binding(1, 0)]]
SamplerState color_sampler : register(s1, space0);

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
    return color_texture.Sample(color_sampler, input.uv);
}
