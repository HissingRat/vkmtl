struct VertexOutput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

struct RayTraceUniforms {
    float4 params;
};

[[vk::binding(0, 0)]]
ConstantBuffer<RayTraceUniforms> uniforms : register(b0, space0);

[shader("vertex")]
VertexOutput vs_main(uint vertex_id : SV_VertexID) {
    float2 position;
    if (vertex_id == 0) {
        position = float2(-1.0, -1.0);
    } else if (vertex_id == 1) {
        position = float2(3.0, -1.0);
    } else {
        position = float2(-1.0, 3.0);
    }

    VertexOutput output;
    output.position = float4(position, 0.0, 1.0);
    output.uv = position * 0.5 + 0.5;
    return output;
}

float3 rotateY(float3 value, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float3(
        value.x * c + value.z * s,
        value.y,
        -value.x * s + value.z * c
    );
}

bool intersectTriangle(
    float3 ray_origin,
    float3 ray_direction,
    float3 v0,
    float3 v1,
    float3 v2,
    out float hit_t,
    out float3 barycentric
) {
    hit_t = 0.0;
    barycentric = float3(0.0, 0.0, 0.0);

    float3 edge1 = v1 - v0;
    float3 edge2 = v2 - v0;
    float3 pvec = cross(ray_direction, edge2);
    float det = dot(edge1, pvec);
    if (abs(det) < 0.00001) {
        return false;
    }

    float inv_det = 1.0 / det;
    float3 tvec = ray_origin - v0;
    float u = dot(tvec, pvec) * inv_det;
    if (u < 0.0 || u > 1.0) {
        return false;
    }

    float3 qvec = cross(tvec, edge1);
    float v = dot(ray_direction, qvec) * inv_det;
    if (v < 0.0 || u + v > 1.0) {
        return false;
    }

    float t = dot(edge2, qvec) * inv_det;
    if (t <= 0.001) {
        return false;
    }

    hit_t = t;
    barycentric = float3(1.0 - u - v, u, v);
    return true;
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0 {
    float aspect = uniforms.params.x;
    float time_seconds = uniforms.params.y;

    float2 screen = float2(input.uv.x * 2.0 - 1.0, (1.0 - input.uv.y) * 2.0 - 1.0);
    float3 ray_origin = float3(0.0, 0.0, 2.65);
    float3 ray_direction = normalize(float3(screen.x * aspect, screen.y, -1.72));

    float angle = sin(time_seconds * 0.45) * 0.28;
    float3 v0 = rotateY(float3(0.0, 0.78, 0.0), angle);
    float3 v1 = rotateY(float3(-0.92, -0.70, 0.0), angle);
    float3 v2 = rotateY(float3(0.92, -0.70, 0.0), angle);

    float t = 0.0;
    float3 bary = float3(0.0, 0.0, 0.0);
    float3 background_top = float3(0.08, 0.10, 0.16);
    float3 background_bottom = float3(0.015, 0.020, 0.034);
    float3 color = lerp(background_bottom, background_top, saturate(input.uv.y));

    float3 normal = normalize(cross(v1 - v0, v2 - v0));
    if (dot(normal, ray_direction) > 0.0) {
        normal = -normal;
    }

    bool hit = intersectTriangle(ray_origin, ray_direction, v0, v1, v2, t, bary);
    if (hit) {
        float3 hit_position = ray_origin + ray_direction * t;
        float3 light_direction = normalize(float3(cos(time_seconds * 0.9) * 0.45, 0.72, 0.62));
        float lambert = saturate(dot(normal, light_direction));
        float fresnel = pow(1.0 - saturate(dot(-ray_direction, normal)), 3.0);
        float edge = min(bary.x, min(bary.y, bary.z));
        float edge_line = 1.0 - smoothstep(0.0, 0.025, edge);
        float3 bary_color =
            bary.x * float3(1.00, 0.20, 0.16) +
            bary.y * float3(0.18, 0.88, 0.32) +
            bary.z * float3(0.22, 0.42, 1.00);
        float depth_fade = saturate(1.0 - (t - 2.0) * 0.18);
        float reflected_sky = saturate(reflect(ray_direction, normal).y * 0.5 + 0.5);

        color = bary_color * (0.25 + 0.75 * lambert) * depth_fade;
        color += float3(0.18, 0.24, 0.34) * reflected_sky * fresnel;
        color = lerp(color, float3(1.0, 0.93, 0.58), edge_line * 0.75);
        color += 0.08 * sin(float3(8.0, 11.0, 15.0) * hit_position.x + time_seconds);
    }

    return float4(saturate(color), 1.0);
}
