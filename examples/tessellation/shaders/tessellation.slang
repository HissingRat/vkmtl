struct ControlPoint
{
    float4 position : SV_Position;
    float3 color : COLOR0;
};

[shader("vertex")]
ControlPoint vs_main(uint vertex_id : SV_VertexID)
{
    ControlPoint output;
    const float2 positions[3] = {
        float2(-0.7, -0.6),
        float2(0.7, -0.6),
        float2(0.0, 0.7),
    };
    const float3 colors[3] = {
        float3(1.0, 0.0, 0.0),
        float3(0.0, 1.0, 0.0),
        float3(0.0, 0.0, 1.0),
    };
    output.position = float4(positions[vertex_id], 0.0, 1.0);
    output.color = colors[vertex_id];
    return output;
}

struct PatchFactors
{
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

PatchFactors patch_factors(InputPatch<ControlPoint, 3> patch)
{
    PatchFactors factors;
    factors.edge[0] = 8.0;
    factors.edge[1] = 8.0;
    factors.edge[2] = 8.0;
    factors.inside = 8.0;
    return factors;
}

[shader("hull")]
[domain("tri")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(3)]
[patchconstantfunc("patch_factors")]
ControlPoint hs_main(
    InputPatch<ControlPoint, 3> patch,
    uint point_id : SV_OutputControlPointID)
{
    return patch[point_id];
}

[shader("domain")]
[domain("tri")]
ControlPoint ds_main(
    PatchFactors factors,
    float3 barycentric : SV_DomainLocation,
    const OutputPatch<ControlPoint, 3> patch)
{
    ControlPoint output;
    output.position =
        patch[0].position * barycentric.x +
        patch[1].position * barycentric.y +
        patch[2].position * barycentric.z;
    output.color =
        patch[0].color * barycentric.x +
        patch[1].color * barycentric.y +
        patch[2].color * barycentric.z;
    return output;
}

[shader("fragment")]
float4 fs_main(ControlPoint input) : SV_Target0
{
    return float4(input.color, 1.0);
}
