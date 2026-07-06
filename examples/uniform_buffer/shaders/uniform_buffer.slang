struct VertexInput {
    float2 position : POSITION0;
    float3 color : COLOR0;
};

struct VertexOutput {
    float4 position : SV_Position;
    float3 color : COLOR0;
};

struct Uniforms {
    float4 tint;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> uniforms : register(b0, space0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    output.position = float4(input.position, 0.0, 1.0);
    output.color = input.color;
    return output;
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0 {
    return float4(input.color * uniforms.tint.rgb, uniforms.tint.a);
}
