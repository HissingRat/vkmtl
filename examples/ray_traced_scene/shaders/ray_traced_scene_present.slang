struct PresentVertexOutput
{
    float4 position : SV_Position;
};

[[vk::binding(0, 0)]]
Texture2D<float4> scene_texture : register(t0, space0);

[[vk::binding(1, 0)]]
SamplerState scene_sampler : register(s1, space0);

float srgbToLinearChannel(float encoded)
{
    encoded = saturate(encoded);
    if (encoded <= 0.04045) return encoded / 12.92;
    return pow((encoded + 0.055) / 1.055, 2.4);
}

float3 referenceDisplayLinear(float3 ray_color)
{
    if (!all(isfinite(ray_color))) return float3(0.0);
    ray_color = saturate(ray_color);
    return float3(
        srgbToLinearChannel(ray_color.r),
        srgbToLinearChannel(ray_color.g),
        srgbToLinearChannel(ray_color.b)
    );
}

[shader("vertex")]
PresentVertexOutput present_vs(uint vertex_id : SV_VertexID)
{
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    PresentVertexOutput output;
    output.position = float4(positions[vertex_id], 0.0, 1.0);
    return output;
}

[shader("fragment")]
float4 present_fs(PresentVertexOutput input) : SV_Target0
{
    uint width;
    uint height;
    scene_texture.GetDimensions(width, height);
    // Fragment position uses top-left framebuffer coordinates on both Metal
    // and Vulkan. Deriving UVs here avoids their opposite clip-space Y maps.
    float2 uv = input.position.xy / float2(max(width, 1), max(height, 1));
    float3 ray_color = scene_texture.Sample(scene_sampler, uv).rgb;
    // The historical scene produces display-referred RGB. Decode it before
    // the sRGB attachment so that attachment reproduces the reference bytes.
    return float4(referenceDisplayLinear(ray_color), 1.0);
}
