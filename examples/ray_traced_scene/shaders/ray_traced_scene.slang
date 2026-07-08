struct VertexOutput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

struct RayTraceUniforms {
    float4 params;
};

struct Camera {
    float3 up;
    float3 right;
    float3 forward;
    float3 position;
};

struct HitInfo {
    float4 sphere;
    float4 color;
    float2 material;
    float distance;
};

[[vk::binding(0, 0)]]
ConstantBuffer<RayTraceUniforms> uniforms : register(b0, space0);

static const int iterations = 5;
static const float max_dist = 1000.0;
static const float3 ambient_light = float3(1.0, 1.0, 1.0);
static const float eps = 0.001;

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

Camera makeCamera() {
    Camera camera;
    camera.up = float3(0.0, 1.0, 0.0);
    camera.right = float3(1.0, 0.0, 0.0);
    camera.forward = float3(0.0, 0.0, -1.0);
    camera.position = float3(0.0, 0.0, -0.2);
    return camera;
}

float4 baseSphere(int index) {
    if (index == 0) return float4(0.0, 0.0, -1.5, 0.1);
    if (index == 1) return float4(0.0, 0.25, -1.5, 0.1);
    if (index == 2) return float4(0.0, -0.7, -1.5, 0.3);
    if (index == 3) return float4(0.0, -0.1, -1.5, 0.3);
    if (index == 4) return float4(0.0, -0.1, -1.5, 0.15);
    if (index == 5) return float4(1001.0, 0.0, 0.0, 1000.0);
    if (index == 6) return float4(-1001.0, 0.0, 0.0, 1000.0);
    if (index == 7) return float4(0.0, 1001.0, 0.0, 1000.0);
    if (index == 8) return float4(0.0, -1001.0, 0.0, 1000.0);
    return float4(0.0, 0.0, -1002.0, 1000.0);
}

float4 baseColor(int index) {
    if (index == 0) return float4(1.0, 0.8, 0.0, -1.0);
    if (index == 1) return float4(0.0, 0.0, 1.0, -1.0);
    if (index == 2) return float4(1.0, 1.0, 1.0, 1.0);
    if (index == 3) return float4(1.0, 1.0, 1.0, 1.0);
    if (index == 4) return float4(1.0, 0.0, 0.0, 1.0);
    if (index == 5) return float4(0.0, 1.0, 0.0, 0.7);
    if (index == 6) return float4(1.0, 0.0, 0.0, 0.7);
    if (index == 7) return float4(1.0, 1.0, 1.0, 0.7);
    if (index == 8) return float4(1.0, 1.0, 1.0, 0.7);
    return float4(1.0, 1.0, 1.0, 0.7);
}

float2 baseMaterial(int index) {
    if (index == 0) return float2(0.0, 0.0);
    if (index == 1) return float2(0.0, 0.0);
    if (index == 2) return float2(1.0, 0.0);
    if (index == 3) return float2(0.1, 0.8);
    if (index == 4) return float2(0.1, 0.8);
    if (index == 5) return float2(0.0, 0.0);
    if (index == 6) return float2(0.0, 0.0);
    if (index == 7) return float2(0.1, 0.0);
    if (index == 8) return float2(0.1, 0.0);
    return float2(0.1, 0.0);
}

float4 sceneSphere(int index, float time_seconds) {
    float4 sphere = baseSphere(index);
    if (index == 0) {
        sphere.x += sin(time_seconds) * 0.4;
        sphere.z += cos(time_seconds) * 0.4;
    } else if (index == 1) {
        sphere.x += sin(time_seconds) * -0.3;
        sphere.z += cos(time_seconds) * -0.3;
    }
    return sphere;
}

float3 rayDirection(float2 uv, float aspect, Camera camera) {
    float2 shadertoy_uv = uv * 2.0 - 1.0;
    shadertoy_uv.x *= aspect;
    return normalize(shadertoy_uv.x * camera.right + shadertoy_uv.y * camera.up + camera.forward);
}

bool intersectSphere(float3 ray_origin, float3 ray_direction, float4 sphere, float max_t, out float hit_t) {
    bool did_hit = false;
    float3 offset = ray_origin - sphere.xyz;
    float b = dot(offset, ray_direction);
    float c = dot(offset, offset) - sphere.w * sphere.w;
    hit_t = b * b - c;
    if (hit_t > 0.0) {
        hit_t = -b - sqrt(hit_t);
        did_hit = (hit_t > 0.0) && (hit_t < max_t);
    }
    return did_hit;
}

HitInfo calcInter(float3 ray_origin, float3 ray_direction, float time_seconds) {
    HitInfo hit;
    hit.sphere = float4(0.0, 0.0, 0.0, 0.0);
    hit.color = float4(0.0, 0.0, 0.0, 0.0);
    hit.material = float2(0.0, 0.0);
    hit.distance = max_dist;

    float t = 0.0;
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(0, time_seconds), hit.distance, t)) {
        hit.sphere = sceneSphere(0, time_seconds);
        hit.color = baseColor(0);
        hit.distance = t;
        hit.material = baseMaterial(0);
    }
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(1, time_seconds), hit.distance, t)) {
        hit.sphere = sceneSphere(1, time_seconds);
        hit.color = baseColor(1);
        hit.distance = t;
        hit.material = baseMaterial(1);
    }
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(2, time_seconds), hit.distance, t)) {
        hit.sphere = sceneSphere(2, time_seconds);
        hit.color = baseColor(2);
        hit.distance = t;
        hit.material = baseMaterial(2);
    }
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(3, time_seconds), hit.distance, t)) {
        hit.sphere = sceneSphere(3, time_seconds);
        hit.color = baseColor(3);
        hit.distance = t;
        hit.material = baseMaterial(3);
    }
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(4, time_seconds), hit.distance, t)) {
        hit.sphere = sceneSphere(4, time_seconds);
        hit.color = baseColor(4);
        hit.distance = t;
        hit.material = baseMaterial(4);
    }
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(5, time_seconds), hit.distance, t)) {
        hit.sphere = sceneSphere(5, time_seconds);
        hit.color = baseColor(5);
        hit.distance = t;
        hit.material = baseMaterial(5);
    }
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(6, time_seconds), hit.distance, t)) {
        hit.sphere = sceneSphere(6, time_seconds);
        hit.color = baseColor(6);
        hit.distance = t;
        hit.material = baseMaterial(6);
    }
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(7, time_seconds), hit.distance, t)) {
        hit.sphere = sceneSphere(7, time_seconds);
        hit.color = baseColor(7);
        hit.distance = t;
        hit.material = baseMaterial(7);
    }
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(8, time_seconds), hit.distance, t)) {
        hit.sphere = sceneSphere(8, time_seconds);
        hit.color = baseColor(8);
        hit.distance = t;
        hit.material = baseMaterial(8);
    }
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(9, time_seconds), hit.distance, t)) {
        hit.sphere = sceneSphere(9, time_seconds);
        hit.color = baseColor(9);
        hit.distance = t;
        hit.material = baseMaterial(9);
    }

    return hit;
}

bool inShadow(float3 ray_origin, float3 ray_direction, float distance, float time_seconds) {
    float t = 0.0;
    bool shadowed = false;

    if (intersectSphere(ray_origin, ray_direction, sceneSphere(2, time_seconds), distance, t)) shadowed = true;
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(3, time_seconds), distance, t)) shadowed = true;
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(4, time_seconds), distance, t)) shadowed = true;
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(5, time_seconds), distance, t)) shadowed = true;
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(6, time_seconds), distance, t)) shadowed = true;
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(7, time_seconds), distance, t)) shadowed = true;
    if (intersectSphere(ray_origin, ray_direction, sceneSphere(8, time_seconds), distance, t)) shadowed = true;

    return shadowed;
}

float3 calcShade(float3 point, HitInfo hit, float3 normal, float time_seconds) {
    float3 color = float3(0.0, 0.0, 0.0);
    float3 ambient_color = ambient_light * (1.0 - hit.color.w) * hit.color.rgb;
    float3 surface_color = hit.color.w * hit.color.rgb;

    if (hit.color.w > 0.0) {
        float3 light = sceneSphere(0, time_seconds).xyz - point;
        float distance = length(light);
        light = normalize(light);
        float3 light_color = baseColor(0).rgb;
        float diffuse = clamp(dot(normal, light), 0.0, 1.0);
        color += (ambient_color * light_color + light_color * diffuse * surface_color) / (1.0 + distance * distance);
        if (inShadow(point, light, distance, time_seconds)) {
            color *= 0.7;
        }

        light = sceneSphere(1, time_seconds).xyz - point;
        distance = length(light);
        light = normalize(light);
        light_color = baseColor(1).rgb;
        diffuse = clamp(dot(normal, light), 0.0, 1.0);
        color += (ambient_color * light_color + light_color * diffuse * surface_color) / (1.0 + distance * distance);
        if (inShadow(point, light, distance, time_seconds)) {
            color *= 0.7;
        }
    } else {
        color = hit.color.rgb;
    }

    return color;
}

float getFresnel(float3 normal, float3 ray_direction, float r0) {
    float ndotv = clamp(dot(normal, -ray_direction), 0.0, 1.0);
    return r0 + (1.0 - r0) * pow(1.0 - ndotv, 5.0);
}

float3 getReflection(float3 ray_origin, float3 ray_direction, float time_seconds) {
    float3 color = float3(0.0, 0.0, 0.0);
    HitInfo hit = calcInter(ray_origin, ray_direction, time_seconds);
    if (hit.distance < max_dist) {
        float3 point = ray_origin + ray_direction * hit.distance;
        float3 normal = normalize(point - hit.sphere.xyz);
        color = calcShade(point, hit, normal, time_seconds);
    }
    return color;
}

float3 traceColor(float3 ray_origin, float3 ray_direction, float time_seconds) {
    float3 mask = float3(1.0, 1.0, 1.0);
    float3 color = float3(0.0, 0.0, 0.0);

    for (int i = 0; i < iterations; ++i) {
        HitInfo hit = calcInter(ray_origin, ray_direction, time_seconds);
        if (hit.distance < max_dist) {
            float3 point = ray_origin + ray_direction * hit.distance;
            float3 normal = normalize(point - hit.sphere.xyz);
            float fresnel = getFresnel(normal, ray_direction, hit.material.x);
            mask *= fresnel;

            if (hit.material.y > 0.0) {
                ray_origin = point - normal * eps;
                float3 reflected = reflect(ray_direction, normal);
                float3 reflected_color = getReflection(ray_origin, reflected, time_seconds);
                color += reflected_color * mask;
                mask = hit.color.rgb * (1.0 - fresnel) * (mask / fresnel);
                ray_direction = refract(ray_direction, normal, hit.material.y);
            } else if (hit.material.x > 0.0) {
                color += calcShade(point, hit, normal, time_seconds) * (1.0 - fresnel) * mask / fresnel;
                ray_origin = point + normal * eps;
                ray_direction = reflect(ray_direction, normal);
            } else {
                color += calcShade(point, hit, normal, time_seconds) * mask / fresnel;
                break;
            }
        }
    }

    return color;
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0 {
    Camera camera = makeCamera();
    float aspect = uniforms.params.x;
    float time_seconds = uniforms.params.y;
    float3 ray_origin = camera.position;
    float3 ray_direction = rayDirection(input.uv, aspect, camera);
    float3 color = traceColor(ray_origin, ray_direction, time_seconds);
    return float4(color, 1.0);
}
