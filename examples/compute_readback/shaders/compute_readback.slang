[[vk::binding(0, 0)]]
[[vk::image_format("rgba8")]]
RWTexture2D<float4> output_texture : register(u0, space0);

[[vk::binding(1, 0)]]
RWStructuredBuffer<uint> output_values : register(u1, space0);

[shader("compute")]
[numthreads(4, 1, 1)]
void cs_main(uint3 dispatch_id: SV_DispatchThreadID)
{
    uint index = dispatch_id.x;
    output_values[index] = index * 3 + 7;

    uint2 coord = uint2(index & 1, index >> 1);
    float4 color = float4(1.0, 0.0, 0.0, 1.0);
    if (index == 1)
    {
        color = float4(0.0, 1.0, 0.0, 1.0);
    }
    else if (index == 2)
    {
        color = float4(0.0, 0.0, 1.0, 1.0);
    }
    else if (index == 3)
    {
        color = float4(1.0, 1.0, 1.0, 1.0);
    }

    output_texture[coord] = color;
}
