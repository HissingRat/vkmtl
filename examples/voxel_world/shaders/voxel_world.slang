struct VertexInput
{
    float3 position : POSITION0;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL0;
};

struct VertexOutput
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL0;
};

struct CameraUniforms
{
    float4 view_projection_row0;
    float4 view_projection_row1;
    float4 view_projection_row2;
    float4 view_projection_row3;
    float4 light_direction_and_ambient;
    float4 light_color_and_strength;
};

[[vk::binding(0, 0)]]
ConstantBuffer<CameraUniforms> camera : register(b0, space0);

[[vk::binding(1, 0)]]
Texture2D<float4> block_atlas : register(t1, space0);

[[vk::binding(2, 0)]]
SamplerState block_sampler : register(s2, space0);

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
    output.uv = input.uv;
    output.normal = input.normal;
    return output;
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0
{
    float3 normal = normalize(input.normal);
    float3 light_direction = normalize(camera.light_direction_and_ambient.xyz);
    float ambient = camera.light_direction_and_ambient.w;
    float directional = max(dot(normal, light_direction), 0.0);
    float3 lighting = ambient.xxx +
        camera.light_color_and_strength.rgb *
        (directional * camera.light_color_and_strength.w);
    float3 albedo = block_atlas.Sample(block_sampler, input.uv).rgb;
    return float4(albedo * lighting, 1.0);
}
