struct MeshVertex
{
    float4 position : SV_Position;
    float3 color : COLOR;
};

[shader("mesh")]
[outputtopology("triangle")]
[numthreads(1, 1, 1)]
void mesh_main(
    out indices uint3 triangles[1],
    out vertices MeshVertex vertices[3])
{
    SetMeshOutputCounts(3, 1);
    triangles[0] = uint3(0, 1, 2);
    vertices[0] = {
        float4(-0.65, -0.55, 0.0, 1.0),
        float3(1.0, 0.0, 0.0),
    };
    vertices[1] = {
        float4(0.65, -0.55, 0.0, 1.0),
        float3(0.0, 1.0, 0.0),
    };
    vertices[2] = {
        float4(0.0, 0.65, 0.0, 1.0),
        float3(0.0, 0.0, 1.0),
    };
}

[shader("fragment")]
float4 fs_main(MeshVertex input) : SV_Target0
{
    return float4(input.color, 1.0);
}
