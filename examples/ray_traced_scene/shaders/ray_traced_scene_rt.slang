struct RayPayload {
    float4 sphere;
    float4 color;
    float2 material;
    float distance;
    uint object_index;
    uint ignore_object_mask;
    uint ray_kind;
    uint did_hit;
};

struct RayTraceUniforms {
    float4 params;
};

struct SphereHitAttributes {
    float3 normal;
};

[[vk::binding(0, 0)]]
RaytracingAccelerationStructure scene : register(t0, space0);

[[vk::binding(1, 0)]]
RWTexture2D<float4> output_texture : register(u1, space0);

[[vk::binding(2, 0)]]
ConstantBuffer<RayTraceUniforms> uniforms : register(b2, space0);

static const int iterations = 5;
static const float max_dist = 1000.0;
static const float3 ambient_light = float3(1.0, 1.0, 1.0);
static const float eps = 0.001;

float4 baseSphere(uint index) {
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

float4 baseColor(uint index) {
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

float2 baseMaterial(uint index) {
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

float4 sceneSphere(uint index, float time_seconds) {
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

uint objectIndexFromPrimitive(uint primitive) {
    return primitive < 10 ? primitive : 9;
}

static const uint ray_kind_surface = 0;
static const uint ray_kind_shadow = 1;
static const uint no_object = 0xffffffffu;

uint objectMask(uint object_index) {
    return object_index < 32 ? (1u << object_index) : 0u;
}

bool shouldIgnoreObject(uint object_index, uint ignore_object_mask) {
    return (ignore_object_mask & objectMask(object_index)) != 0u;
}

RayPayload traceScene(float3 ray_origin, float3 ray_direction, float max_t, uint ignore_object_mask, uint ray_kind) {
    RayDesc ray;
    ray.Origin = ray_origin;
    ray.Direction = ray_direction;
    ray.TMin = eps;
    ray.TMax = max_t;

    RayPayload payload;
    payload.sphere = float4(0.0, 0.0, 0.0, 0.0);
    payload.color = float4(0.0, 0.0, 0.0, 0.0);
    payload.material = float2(0.0, 0.0);
    payload.distance = max_dist;
    payload.object_index = no_object;
    payload.ignore_object_mask = ignore_object_mask;
    payload.ray_kind = ray_kind;
    payload.did_hit = 0;
    TraceRay(scene, 0, 0xff, 0, 1, 0, ray, payload);
    return payload;
}

bool inShadow(float3 ray_origin, float3 ray_direction, float distance, uint ignore_object_mask) {
    RayPayload hit = traceScene(ray_origin, ray_direction, distance, ignore_object_mask, ray_kind_shadow);
    return hit.did_hit != 0 && hit.object_index >= 2 && hit.distance < distance;
}

bool intersectSphereRay(float3 ray_origin, float3 ray_direction, float4 sphere, float min_t, float max_t, out float hit_t, out float3 normal) {
    const float3 center = sphere.xyz;
    const float radius = sphere.w;
    const float3 oc = ray_origin - center;
    const float half_b = dot(oc, ray_direction);
    const float c = dot(oc, oc) - radius * radius;
    const float discriminant = half_b * half_b - c;
    if (discriminant < 0.0) {
        hit_t = 0.0;
        normal = float3(0.0, 1.0, 0.0);
        return false;
    }

    const float root = sqrt(discriminant);
    float candidate = -half_b - root;
    if (candidate <= min_t || candidate >= max_t) {
        candidate = -half_b + root;
    }
    if (candidate <= min_t || candidate >= max_t) {
        hit_t = 0.0;
        normal = float3(0.0, 1.0, 0.0);
        return false;
    }

    hit_t = candidate;
    normal = normalize(ray_origin + ray_direction * candidate - center);
    return true;
}

float3 calcShade(float3 point, RayPayload hit, float3 normal, float time_seconds) {
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
        if (inShadow(point, light, distance, objectMask(hit.object_index))) {
            color *= 0.7;
        }

        light = sceneSphere(1, time_seconds).xyz - point;
        distance = length(light);
        light = normalize(light);
        light_color = baseColor(1).rgb;
        diffuse = clamp(dot(normal, light), 0.0, 1.0);
        color += (ambient_color * light_color + light_color * diffuse * surface_color) / (1.0 + distance * distance);
        if (inShadow(point, light, distance, objectMask(hit.object_index))) {
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

float3 getReflection(float3 ray_origin, float3 ray_direction, float time_seconds, uint ignore_object_mask) {
    float3 color = float3(0.0, 0.0, 0.0);
    RayPayload hit = traceScene(ray_origin, ray_direction, max_dist, ignore_object_mask, ray_kind_surface);
    if (hit.did_hit != 0) {
        float3 point = ray_origin + ray_direction * hit.distance;
        float3 normal = normalize(point - hit.sphere.xyz);
        color = calcShade(point, hit, normal, time_seconds);
    }
    return color;
}

float3 traceColor(float3 ray_origin, float3 ray_direction, float time_seconds) {
    float3 mask = float3(1.0, 1.0, 1.0);
    float3 color = float3(0.0, 0.0, 0.0);
    uint ignore_object_mask = 0u;

    for (int i = 0; i < iterations; ++i) {
        const uint active_ignore_mask = ignore_object_mask;
        RayPayload hit = traceScene(ray_origin, ray_direction, max_dist, active_ignore_mask, ray_kind_surface);
        ignore_object_mask = 0u;
        if (hit.did_hit == 0) {
            break;
        }

        float3 point = ray_origin + ray_direction * hit.distance;
        float3 normal = normalize(point - hit.sphere.xyz);
        float fresnel = max(getFresnel(normal, ray_direction, hit.material.x), 0.0001);
        const uint next_ignore_mask = active_ignore_mask | objectMask(hit.object_index);
        mask *= fresnel;

        if (hit.material.y > 0.0) {
            ray_origin = point - normal * eps;
            float3 reflected = reflect(ray_direction, normal);
            color += getReflection(ray_origin, reflected, time_seconds, next_ignore_mask) * mask;
            mask = hit.color.rgb * (1.0 - fresnel) * (mask / fresnel);

            float3 refracted = refract(ray_direction, normal, hit.material.y);
            ray_direction = dot(refracted, refracted) > 0.00001 ? normalize(refracted) : reflected;
            ignore_object_mask = next_ignore_mask;
        } else if (hit.material.x > 0.0) {
            color += calcShade(point, hit, normal, time_seconds) * (1.0 - fresnel) * mask / fresnel;
            ray_origin = point + normal * eps;
            ray_direction = reflect(ray_direction, normal);
            ignore_object_mask = next_ignore_mask;
        } else {
            color += calcShade(point, hit, normal, time_seconds) * mask / fresnel;
            break;
        }
    }

    return color;
}

[shader("raygeneration")]
void raygen() {
    const uint2 pixel = DispatchRaysIndex().xy;
    const uint2 size = DispatchRaysDimensions().xy;
    const float2 uv = (float2(pixel) + 0.5) / float2(size);
    float2 p = float2(uv.x * 2.0 - 1.0, (1.0 - uv.y) * 2.0 - 1.0);
    p.x *= float(size.x) / max(float(size.y), 1.0);

    const float3 ray_origin = float3(0.0, 0.0, -0.2);
    const float3 ray_direction = normalize(float3(p.x, p.y, -1.0));
    const float time_seconds = uniforms.params.x;
    const float3 color = clamp(traceColor(ray_origin, ray_direction, time_seconds), float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));
    output_texture[pixel] = float4(color, 1.0);
}

[shader("miss")]
void miss(inout RayPayload payload) {
    payload.did_hit = 0;
    payload.distance = max_dist;
    payload.object_index = no_object;
    payload.color = float4(0.0, 0.0, 0.0, 1.0);
}

[shader("anyhit")]
void any_hit(inout RayPayload payload, SphereHitAttributes attributes) {
    const uint object_index = objectIndexFromPrimitive(PrimitiveIndex());
    if (shouldIgnoreObject(object_index, payload.ignore_object_mask)) {
        IgnoreHit();
        return;
    }
    if (payload.ray_kind == ray_kind_shadow && object_index < 2) {
        IgnoreHit();
        return;
    }
}

[shader("intersection")]
void intersect_sphere() {
    const uint object_index = objectIndexFromPrimitive(PrimitiveIndex());
    const float4 sphere = sceneSphere(object_index, uniforms.params.x);

    float hit_t;
    float3 normal;
    if (intersectSphereRay(ObjectRayOrigin(), ObjectRayDirection(), sphere, RayTMin(), RayTCurrent(), hit_t, normal)) {
        SphereHitAttributes attributes;
        attributes.normal = normal;
        ReportHit(hit_t, 0, attributes);
    }
}

[shader("closesthit")]
void closest_hit(inout RayPayload payload, SphereHitAttributes attributes) {
    const uint object_index = objectIndexFromPrimitive(PrimitiveIndex());
    payload.sphere = sceneSphere(object_index, uniforms.params.x);
    payload.color = baseColor(object_index);
    payload.material = baseMaterial(object_index);
    payload.distance = RayTCurrent();
    payload.object_index = object_index;
    payload.did_hit = 1;
}
