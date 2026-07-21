struct UiVertexInput
{
    float2 position : POSITION0;
    float4 color : COLOR0;
};

struct UiVertexOutput
{
    float4 position : SV_Position;
    float4 color : COLOR0;
};

[shader("vertex")]
UiVertexOutput vs_main(UiVertexInput input)
{
    UiVertexOutput output;
    output.position = float4(input.position, 0.0, 1.0);
    output.color = input.color;
    return output;
}

[shader("fragment")]
float4 fs_main(UiVertexOutput input) : SV_Target0
{
    return input.color;
}
