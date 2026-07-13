struct VertexOutput
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

struct TextureTable
{
    Texture2D<float4> textures[64];
    SamplerState table_sampler;
};

[[vk::binding(0, 0)]]
ParameterBlock<TextureTable> texture_table : register(b0, space0);

[shader("vertex")]
VertexOutput vs_main(uint vertex_id : SV_VertexID)
{
    float2 positions[3] = {
        float2(-0.8, -0.8),
        float2( 0.0,  0.8),
        float2( 0.8, -0.8)
    };
    float2 uvs[3] = {
        float2(0.0, 1.0),
        float2(0.5, 0.0),
        float2(1.0, 1.0)
    };
    VertexOutput output;
    output.position = float4(positions[vertex_id], 0.0, 1.0);
    output.uv = uvs[vertex_id];
    return output;
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0
{
    return texture_table.textures[63].Sample(texture_table.table_sampler, input.uv);
}
