struct RayPayload {
    float4 color;
};

[[vk::binding(0, 0)]]
RaytracingAccelerationStructure scene : register(t0, space0);

[[vk::binding(1, 0)]]
RWTexture2D<float4> output_texture : register(u1, space0);

[shader("raygeneration")]
void raygen() {
    const uint2 pixel = DispatchRaysIndex().xy;
    const uint2 size = DispatchRaysDimensions().xy;
    const float2 uv = ((float2(pixel) + 0.5) / float2(size)) * 2.0 - 1.0;

    RayDesc ray;
    ray.Origin = float3(0.0, 0.0, -2.0);
    ray.Direction = normalize(float3(uv.x, -uv.y, 1.5));
    ray.TMin = 0.001;
    ray.TMax = 100.0;

    RayPayload payload;
    payload.color = float4(0.015, 0.02, 0.034, 1.0);
    TraceRay(scene, 0, 0xff, 0, 1, 0, ray, payload);
    output_texture[pixel] = payload.color;
}

[shader("miss")]
void miss(inout RayPayload payload) {
    payload.color = float4(0.02, 0.025, 0.035, 1.0);
}

[shader("closesthit")]
void closest_hit(inout RayPayload payload, BuiltInTriangleIntersectionAttributes attributes) {
    const float3 barycentric = float3(
        1.0 - attributes.barycentrics.x - attributes.barycentrics.y,
        attributes.barycentrics.x,
        attributes.barycentrics.y
    );
    payload.color = float4(barycentric.z, barycentric.y, barycentric.x, 1.0);
}
