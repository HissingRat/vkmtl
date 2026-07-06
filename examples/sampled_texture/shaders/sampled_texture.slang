struct VertexInput {
    float2 position : POSITION0;
    float2 uv : TEXCOORD0;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[[vk::binding(0, 0)]]
Texture2D<float4> color_texture : register(t0, space0);

[[vk::binding(1, 0)]]
SamplerState color_sampler : register(s1, space0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    output.position = float4(input.position, 0.0, 1.0);
    output.uv = input.uv;
    return output;
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0 {
    return color_texture.Sample(color_sampler, input.uv);
}
