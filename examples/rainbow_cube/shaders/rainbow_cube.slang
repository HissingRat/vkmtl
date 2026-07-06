struct VertexInput
{
    float3 position : POSITION0;
    float2 uv : TEXCOORD0;
    float3 color : COLOR0;
};

struct VertexOutput
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float3 color : COLOR0;
};

struct Uniforms
{
    float4 mvp_row0;
    float4 mvp_row1;
    float4 mvp_row2;
    float4 mvp_row3;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> uniforms : register(b0, space0);

[[vk::binding(1, 0)]]
Texture2D<float4> rainbow_texture : register(t1, space0);

[[vk::binding(2, 0)]]
SamplerState rainbow_sampler : register(s2, space0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input)
{
    float4 local = float4(input.position, 1.0);

    VertexOutput output;
    output.position = float4(
        dot(uniforms.mvp_row0, local),
        dot(uniforms.mvp_row1, local),
        dot(uniforms.mvp_row2, local),
        dot(uniforms.mvp_row3, local)
    );
    output.uv = input.uv;
    output.color = input.color;
    return output;
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0
{
    float4 texel = rainbow_texture.Sample(rainbow_sampler, input.uv);
    return float4(texel.rgb * input.color, texel.a);
}
