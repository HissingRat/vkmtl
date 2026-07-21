struct RtFrameData
{
    float4 camera_position_and_tan_half_fov;
    float4 camera_forward_and_aspect;
    float4 camera_right_and_max_distance;
    float4 camera_up_and_shadow_bias;
    float4 light_direction_and_strength;
    float4 light_color_and_daylight;
    float4 sky_color_and_night;
    float4 frame_index_seed_and_light_radius;
    float4 sun_direction_and_cloud_time;
    float4 material_origin_and_extent;
    float4 traced_origin_and_extent;
};

struct VisibilityPayload
{
    float3 normal;
    float distance;
    uint did_hit;
};

struct UnusedIntersectionAttributes
{
    float2 barycentrics;
};

[[vk::binding(0, 0)]]
RaytracingAccelerationStructure voxel_scene : register(t0, space0);

[[vk::binding(1, 0)]]
[[vk::image_format("rgba16f")]]
RWTexture2D<float4> output_texture : register(u1, space0);

[[vk::binding(2, 0)]]
ConstantBuffer<RtFrameData> frame_data : register(b2, space0);

[[vk::binding(3, 0)]]
Texture2D<float4> surface_gbuffer : register(t3, space0);

[[vk::binding(4, 0)]]
Texture2D<float4> block_atlas : register(t4, space0);

[[vk::binding(5, 0)]]
SamplerState block_sampler : register(s5, space0);

[[vk::binding(6, 0)]]
RWStructuredBuffer<uint4> material_columns : register(u6, space0);

[[vk::binding(7, 0)]]
Texture2D<float4> water_surface_gbuffer : register(t7, space0);

[[vk::binding(8, 0)]]
[[vk::image_format("rgba16f")]]
RWTexture2D<float4> water_reflection_target : register(u8, space0);

static const float minimum_ray_distance = 0.0001;
static const float plane_tie_epsilon = 0.0005;
static const float pi = 3.14159265358979323846;
static const float traced_scene_top = 64.0;
static const uint maximum_diffuse_bounce_count = 3u;

uint hashBits(uint value)
{
    value ^= value >> 16;
    value *= 0x7feb352d;
    value ^= value >> 15;
    value *= 0x846ca68b;
    value ^= value >> 16;
    return value;
}

float staticRandom01(uint2 pixel, uint lane)
{
    const uint seed = uint(max(frame_data.frame_index_seed_and_light_radius.y, 0.0));
    const uint bits = hashBits(
        pixel.x * 0x9e3779b9u ^
        pixel.y * 0x85ebca6bu ^
        seed ^ lane * 0x27d4eb2du
    );
    return (float(bits & 0x00ffffffu) + 0.5) / 16777216.0;
}

float2 temporalSample2D(uint2 pixel, uint first_lane)
{
    const uint frame_index = uint(max(frame_data.frame_index_seed_and_light_radius.x, 0.0));
    const float2 scramble = float2(
        staticRandom01(pixel, first_lane),
        staticRandom01(pixel, first_lane + 1u)
    );
    const float2 r2_increment = float2(0.7548776662466927, 0.5698402909980532);
    return frac(scramble + float(frame_index) * r2_increment);
}

float3 sampleCelestialDiskDirection(
    float3 center_direction,
    float light_strength,
    float angular_radius,
    float2 random_sample
)
{
    const float radius = max(abs(angular_radius), 0.0);
    if (light_strength <= 0.0 || radius <= 0.00001)
    {
        return center_direction;
    }

    const float disk_radius = sqrt(random_sample.x);
    const float disk_angle = 2.0 * pi * random_sample.y;
    const float3 helper = abs(center_direction.y) < 0.999
        ? float3(0.0, 1.0, 0.0)
        : float3(1.0, 0.0, 0.0);
    const float3 tangent = normalize(cross(helper, center_direction));
    const float3 bitangent = cross(center_direction, tangent);
    const float2 disk_sample = disk_radius * float2(cos(disk_angle), sin(disk_angle));
    const float safe_radius = min(radius, pi * 0.499);
    return normalize(
        center_direction +
        (tangent * disk_sample.x + bitangent * disk_sample.y) * tan(safe_radius)
    );
}

uint voxelPlaneAxis(float3 world_point, float3 incoming_direction)
{
    const float3 plane_distance = abs(world_point - round(world_point));
    const float nearest_distance = min(plane_distance.x, min(plane_distance.y, plane_distance.z));

    uint axis = 0;
    float best_direction = -1.0;
    if (plane_distance.x <= nearest_distance + plane_tie_epsilon)
    {
        axis = 0;
        best_direction = abs(incoming_direction.x);
    }
    if (plane_distance.y <= nearest_distance + plane_tie_epsilon &&
        abs(incoming_direction.y) > best_direction)
    {
        axis = 1;
        best_direction = abs(incoming_direction.y);
    }
    if (plane_distance.z <= nearest_distance + plane_tie_epsilon &&
        abs(incoming_direction.z) > best_direction)
    {
        axis = 2;
    }
    return axis;
}

float3 voxelFaceNormal(float3 world_point, float3 incoming_direction)
{
    const uint axis = voxelPlaneAxis(world_point, incoming_direction);
    if (axis == 0)
    {
        return float3(incoming_direction.x >= 0.0 ? -1.0 : 1.0, 0.0, 0.0);
    }
    if (axis == 1)
    {
        return float3(0.0, incoming_direction.y >= 0.0 ? -1.0 : 1.0, 0.0);
    }
    return float3(0.0, 0.0, incoming_direction.z >= 0.0 ? -1.0 : 1.0);
}

VisibilityPayload traceVoxelScene(float3 origin, float3 direction, float maximum_distance)
{
    RayDesc ray;
    ray.Origin = origin;
    ray.Direction = direction;
    ray.TMin = minimum_ray_distance;
    ray.TMax = maximum_distance;

    VisibilityPayload payload;
    payload.normal = float3(0.0, 0.0, 0.0);
    payload.distance = maximum_distance;
    payload.did_hit = 0;
    TraceRay(voxel_scene, 0, 0xff, 0, 1, 0, ray, payload);
    return payload;
}

float3 cameraRayDirection(uint2 pixel, uint2 size)
{
    const float2 uv = (float2(pixel) + 0.5) / float2(size);
    const float2 screen = float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
    const float tan_half_fov = max(abs(frame_data.camera_position_and_tan_half_fov.w), 0.0001);
    const float aspect = max(abs(frame_data.camera_forward_and_aspect.w), 0.0001);
    return normalize(
        frame_data.camera_forward_and_aspect.xyz +
        frame_data.camera_right_and_max_distance.xyz * (screen.x * aspect * tan_half_fov) +
        frame_data.camera_up_and_shadow_bias.xyz * (screen.y * tan_half_fov)
    );
}

float3 cosineHemisphere(float3 normal, float2 random_sample)
{
    const float radius = sqrt(random_sample.x);
    const float angle = 2.0 * pi * random_sample.y;
    const float3 local_direction = float3(
        radius * cos(angle),
        radius * sin(angle),
        sqrt(max(1.0 - random_sample.x, 0.0))
    );
    const float3 helper = abs(normal.y) < 0.999
        ? float3(0.0, 1.0, 0.0)
        : float3(1.0, 0.0, 0.0);
    const float3 tangent = normalize(cross(helper, normal));
    const float3 bitangent = cross(normal, tangent);
    return normalize(
        tangent * local_direction.x +
        bitangent * local_direction.y +
        normal * local_direction.z
    );
}

uint fallbackMaterialTile(float3 world_point, float3 normal)
{
    const float height = world_point.y;
    const bool top_face = normal.y > 0.5;
    const bool bottom_face = normal.y < -0.5;
    if (height <= 12.5) return 4;
    if (height >= 30.5) return top_face ? 5 : (bottom_face ? 2 : 6);
    if (top_face) return 0;
    if (bottom_face) return 2;
    return 1;
}

bool packedSpanContains(uint packed_span, int y)
{
    const uint minimum = packed_span & 0xffu;
    const uint maximum = (packed_span >> 8) & 0xffu;
    return minimum != 0xffu && y >= int(minimum) && y <= int(maximum);
}

uint materialTile(float3 world_point, float3 normal)
{
    const float3 inside_point = world_point - normal * 0.01;
    const int3 voxel_position = int3(floor(inside_point));
    const int2 origin = int2(frame_data.material_origin_and_extent.xy);
    const int2 extent = int2(frame_data.material_origin_and_extent.zw);
    const int2 local = voxel_position.xz - origin;
    if (any(local < int2(0, 0)) || any(local >= extent))
    {
        return fallbackMaterialTile(world_point, normal);
    }

    const uint4 column = material_columns[uint(local.y * extent.x + local.x)];
    const int height = asint(column.x);
    const uint surface = column.y & 0xffu;
    const uint water_level = (column.y >> 8) & 0xffu;
    uint block = 0u;
    if (voxel_position.y <= height)
    {
        block = 3u;
        if (voxel_position.y == height)
        {
            block = surface;
        }
        else if (surface == 4u && voxel_position.y >= height - 3)
        {
            block = 4u;
        }
        else if (voxel_position.y >= height - 3)
        {
            block = 2u;
        }
    }
    else if (packedSpanContains(column.z, voxel_position.y))
    {
        block = 6u;
    }
    else if (packedSpanContains(column.w, voxel_position.y))
    {
        block = 7u;
    }
    else if (water_level != 0xffu && voxel_position.y <= int(water_level))
    {
        block = 8u;
    }

    const bool top_face = normal.y > 0.5;
    const bool bottom_face = normal.y < -0.5;
    if (block == 1u) return top_face ? 0u : (bottom_face ? 2u : 1u);
    if (block == 2u) return 2u;
    if (block == 3u) return 3u;
    if (block == 4u) return 4u;
    if (block == 5u) return top_face ? 5u : (bottom_face ? 2u : 6u);
    if (block == 6u) return abs(normal.y) > 0.5 ? 7u : 8u;
    if (block == 7u) return 9u;
    if (block == 8u) return 10u;
    return fallbackMaterialTile(world_point, normal);
}

float2 voxelAtlasUv(float3 world_point, float3 normal, uint tile)
{
    float2 local_uv;
    if (abs(normal.y) > 0.5)
    {
        local_uv = frac(world_point.xz);
    }
    else if (abs(normal.x) > 0.5)
    {
        local_uv = frac(float2(world_point.z, world_point.y));
    }
    else
    {
        local_uv = frac(float2(world_point.x, world_point.y));
    }
    uint atlas_width;
    uint atlas_height;
    block_atlas.GetDimensions(atlas_width, atlas_height);
    const float2 pixel = float2(
        float(tile * 68u + 2u) + local_uv.x * 63.0 + 0.5,
        2.0 + (1.0 - local_uv.y) * 63.0 + 0.5
    );
    return pixel / float2(max(atlas_width, 1u), max(atlas_height, 1u));
}

float cloudLightTransmittance(
    float3 world_position,
    float3 light_direction,
    float cloud_time,
    float daylight,
    float night,
    float twilight,
    float active_light_strength
);

float3 secondarySurfaceAlbedo(
    float3 world_point,
    float3 normal
)
{
    const uint material_tile = materialTile(world_point, normal);
    const float2 atlas_uv = voxelAtlasUv(world_point, normal, material_tile);
    return block_atlas.SampleLevel(block_sampler, atlas_uv, 0.0).rgb;
}

float3 secondaryEnvironmentIllumination()
{
    const float daylight = saturate(frame_data.light_color_and_daylight.w);
    const float night = saturate(frame_data.sky_color_and_night.w);
    return frame_data.sky_color_and_night.rgb *
        lerp(0.035, 0.13, daylight) * lerp(1.0, 0.42, night);
}

float3 secondaryDirectIllumination(
    uint2 pixel,
    uint first_random_lane,
    float3 world_point,
    float3 normal,
    float maximum_distance,
    float shadow_bias
)
{
    const float3 light_direction = normalize(frame_data.light_direction_and_strength.xyz);
    const float light_strength = max(frame_data.light_direction_and_strength.w, 0.0);
    const float n_dot_l = max(dot(normal, light_direction), 0.0);
    const float daylight = saturate(frame_data.light_color_and_daylight.w);
    const float night = saturate(frame_data.sky_color_and_night.w);
    const float twilight = saturate(1.0 - daylight - night);
    float visibility = 0.0;
    if (n_dot_l > 0.0 && light_strength > 0.0)
    {
        const float3 shadow_direction = sampleCelestialDiskDirection(
            light_direction,
            light_strength,
            frame_data.frame_index_seed_and_light_radius.z,
            temporalSample2D(pixel, first_random_lane)
        );
        const VisibilityPayload shadow_hit = traceVoxelScene(
            world_point + normal * shadow_bias,
            shadow_direction,
            maximum_distance
        );
        visibility = shadow_hit.did_hit == 0
            ? cloudLightTransmittance(
                world_point,
                shadow_direction,
                frame_data.sun_direction_and_cloud_time.w,
                daylight,
                night,
                twilight,
                light_strength
            )
            : 0.0;
    }
    return frame_data.light_color_and_daylight.rgb *
        (light_strength * n_dot_l * visibility);
}

float3 secondarySurfaceRadiance(
    uint2 pixel,
    uint first_random_lane,
    float3 world_point,
    float3 normal,
    float maximum_distance,
    float shadow_bias
)
{
    const float3 albedo = secondarySurfaceAlbedo(world_point, normal);
    return albedo * (
        secondaryEnvironmentIllumination() +
        secondaryDirectIllumination(
            pixel,
            first_random_lane,
            world_point,
            normal,
            maximum_distance,
            shadow_bias
        )
    );
}

float tracedNeighborhoodWeight(float3 world_point)
{
    if (any(frame_data.traced_origin_and_extent.zw <= 0.0))
    {
        return 1.0;
    }
    const float2 origin = frame_data.traced_origin_and_extent.xy;
    const float2 limit = origin + frame_data.traced_origin_and_extent.zw;
    const float2 edge_distance = min(world_point.xz - origin, limit - world_point.xz);
    return smoothstep(0.0, 16.0, min(edge_distance.x, edge_distance.y));
}

float distanceToTracedBoundary(
    float origin,
    float direction,
    float minimum,
    float maximum,
    float maximum_distance
)
{
    if (direction > 0.000001)
    {
        return max((maximum - origin) / direction, 0.0);
    }
    if (direction < -0.000001)
    {
        return max((minimum - origin) / direction, 0.0);
    }
    return maximum_distance;
}

bool diffuseMissReachesEnvironment(
    float3 ray_origin,
    float3 ray_direction,
    float maximum_distance
)
{
    const float2 traced_origin = frame_data.traced_origin_and_extent.xy;
    const float2 traced_extent = frame_data.traced_origin_and_extent.zw;
    const float2 traced_limit = traced_origin + traced_extent;
    if (any(traced_extent <= 0.0) ||
        any(ray_origin.xz < traced_origin) || any(ray_origin.xz > traced_limit) ||
        ray_direction.y <= 0.000001)
    {
        return false;
    }

    const float x_exit = distanceToTracedBoundary(
        ray_origin.x,
        ray_direction.x,
        traced_origin.x,
        traced_limit.x,
        maximum_distance
    );
    const float z_exit = distanceToTracedBoundary(
        ray_origin.z,
        ray_direction.z,
        traced_origin.y,
        traced_limit.y,
        maximum_distance
    );
    const float horizontal_exit = min(maximum_distance, min(x_exit, z_exit));
    const float top_exit = (traced_scene_top - ray_origin.y) / ray_direction.y;
    return top_exit >= 0.0 &&
        top_exit <= maximum_distance &&
        top_exit <= horizontal_exit + 0.0001;
}

float cloudHash12(float2 value)
{
    float3 p = frac(float3(value.x, value.y, value.x) * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return frac((p.x + p.y) * p.z);
}

float cloudValueNoise2D(float2 point)
{
    const float2 cell = floor(point);
    const float2 local = frac(point);
    const float2 blend = local * local * (3.0 - 2.0 * local);
    const float lower = lerp(
        cloudHash12(cell),
        cloudHash12(cell + float2(1.0, 0.0)),
        blend.x
    );
    const float upper = lerp(
        cloudHash12(cell + float2(0.0, 1.0)),
        cloudHash12(cell + float2(1.0, 1.0)),
        blend.x
    );
    return lerp(lower, upper, blend.y);
}

float3 cloudSafeNormalize(float3 value, float3 fallback)
{
    const float length_squared = dot(value, value);
    return isfinite(length_squared) && length_squared > 0.000001
        ? value * rsqrt(length_squared)
        : fallback;
}

float3 cloudFiniteRadiance(float3 value)
{
    return float3(
        isfinite(value.x) ? max(value.x, 0.0) : 0.0,
        isfinite(value.y) ? max(value.y, 0.0) : 0.0,
        isfinite(value.z) ? max(value.z, 0.0) : 0.0
    );
}

float cloudMiePhase(float alignment)
{
    const float anisotropy = 0.72;
    const float denominator = max(
        1.0 + anisotropy * anisotropy - 2.0 * anisotropy * alignment,
        0.04
    );
    return min(
        (1.0 - anisotropy * anisotropy) / pow(denominator, 1.5),
        12.0
    );
}

float3 atmosphereRadiance(
    float3 ray_direction,
    float3 sun_direction,
    float daylight,
    float night,
    float twilight
)
{
    const float sky_visibility = smoothstep(-0.035, 0.012, ray_direction.y);
    const float view_height = saturate(ray_direction.y);
    const float horizon = exp(-view_height * 5.2);
    const float view_airmass = 1.0 / (0.18 + view_height * 2.65);
    const float sun_airmass = 1.0 / (0.14 + saturate(sun_direction.y) * 3.8);
    const float3 spectral_scatter = float3(0.18, 0.43, 1.0);
    const float3 sun_transmittance = exp(-spectral_scatter * sun_airmass * 0.32);
    const float3 view_scatter = 1.0 - exp(-spectral_scatter * view_airmass * 0.70);
    const float alignment = clamp(dot(ray_direction, sun_direction), -1.0, 1.0);
    const float rayleigh_phase = 0.75 * (1.0 + alignment * alignment);
    const float mie_phase = cloudMiePhase(alignment);
    const float solar_visibility = smoothstep(-0.10, 0.035, sun_direction.y);
    const float solar_energy = saturate(daylight + twilight * 0.82) * solar_visibility;

    const float3 zenith_floor = float3(0.025, 0.105, 0.38);
    const float3 horizon_floor = float3(0.22, 0.42, 0.65);
    float3 daytime = lerp(zenith_floor, horizon_floor, horizon) * daylight;
    daytime += view_scatter * sun_transmittance *
        (rayleigh_phase * 0.72 + mie_phase * 0.038) * solar_energy * 1.30;

    const float2 flat_view = cloudSafeNormalize(
        float3(ray_direction.x, 0.0, ray_direction.z),
        float3(0.0, 0.0, 1.0)
    ).xz;
    const float2 flat_sun = cloudSafeNormalize(
        float3(sun_direction.x, 0.0, sun_direction.z),
        float3(0.0, 0.0, 1.0)
    ).xz;
    const float sun_side = saturate(dot(flat_view, flat_sun));
    const float low_sun_band = exp(-abs(ray_direction.y) * 8.5) *
        pow(sun_side, 5.0) * twilight;
    const float3 twilight_base = lerp(
        float3(0.018, 0.026, 0.095),
        float3(0.30, 0.095, 0.028),
        horizon * (0.30 + 0.70 * sun_side)
    );
    const float3 twilight_glow = float3(1.0, 0.20, 0.035) *
        low_sun_band * 0.62;

    const float3 night_zenith = float3(0.002, 0.005, 0.020);
    const float3 night_horizon = float3(0.010, 0.018, 0.050);
    const float3 night_sky = lerp(night_zenith, night_horizon, horizon) * night;
    return cloudFiniteRadiance(
        daytime + twilight_base * twilight + twilight_glow + night_sky
    ) * sky_visibility;
}

float cumulusDensity(float2 world_position, float cloud_time)
{
    const float2 wind = float2(0.52, 0.18) * cloud_time;
    const float2 p = (world_position + wind) * 0.0062;
    const float broad = cloudValueNoise2D(p * 0.43 + float2(12.7, -8.4));
    const float detail =
        cloudValueNoise2D(p) * 0.55 +
        cloudValueNoise2D(p * 2.07 + float2(19.4, 5.6)) * 0.28 +
        cloudValueNoise2D(p * 4.31 + float2(-7.2, 31.8)) * 0.17;
    return smoothstep(0.50, 0.72, detail + broad * 0.20);
}

float cirrusDensity(float2 world_position, float cloud_time)
{
    const float2 wind = float2(-0.22, 0.31) * cloud_time;
    const float2 p = (world_position + wind) * 0.0037;
    float2 stretched = float2(
        p.x * 0.62 + p.y * 0.18,
        p.y * 2.60 - p.x * 0.08
    );
    const float2 warp = float2(
        cloudValueNoise2D(stretched * 0.55 + float2(4.3, 15.7)),
        cloudValueNoise2D(stretched * 0.47 + float2(-9.1, 2.8))
    ) - 0.5;
    stretched += float2(warp.x * 0.85, warp.y * 0.22);
    const float bands =
        cloudValueNoise2D(stretched) * 0.58 +
        cloudValueNoise2D(stretched * 2.13 + float2(8.6, -6.9)) * 0.27 +
        cloudValueNoise2D(stretched * 4.40 + float2(-3.7, 22.1)) * 0.15;
    const float ridge = 1.0 - abs(bands * 2.0 - 1.0);
    const float coverage = cloudValueNoise2D(stretched * 0.31 + float2(27.2, 11.3));
    return smoothstep(0.58, 0.78, ridge * 0.78 + coverage * 0.22);
}

float cloudViewFade(float ray_height, float distance_to_cloud)
{
    const float horizon_fade = smoothstep(0.018, 0.095, ray_height);
    const float distance_fade = 1.0 - smoothstep(2600.0, 5200.0, distance_to_cloud);
    return horizon_fade * distance_fade;
}

float3 cloudLightColor(float daylight, float night, float twilight)
{
    return float3(1.0, 0.91, 0.74) * daylight +
        float3(1.0, 0.36, 0.12) * twilight +
        float3(0.40, 0.53, 0.90) * night;
}

float3 cloudAmbientColor(float daylight, float night, float twilight)
{
    return float3(0.54, 0.63, 0.75) * daylight +
        float3(0.32, 0.17, 0.13) * twilight +
        float3(0.014, 0.022, 0.050) * night;
}

float4 sampleCumulus(
    float3 ray_direction,
    float3 light_direction,
    float active_light_strength,
    float3 camera_position,
    float cloud_time,
    float daylight,
    float night,
    float twilight
)
{
    const float altitude = 145.0;
    if (ray_direction.y <= 0.018)
    {
        return float4(0.0, 0.0, 0.0, 0.0);
    }
    const float distance_to_cloud = (altitude - camera_position.y) / ray_direction.y;
    if (distance_to_cloud <= 0.0)
    {
        return float4(0.0, 0.0, 0.0, 0.0);
    }

    const float2 world_position = (camera_position + ray_direction * distance_to_cloud).xz;
    const float density = cumulusDensity(world_position, cloud_time);
    if (density <= 0.001)
    {
        return float4(0.0, 0.0, 0.0, 0.0);
    }

    const float light_slope = 1.0 / max(abs(light_direction.y), 0.22);
    const float2 light_step = light_direction.xz * light_slope * 24.0;
    const float near_probe = cumulusDensity(world_position + light_step, cloud_time);
    const float far_probe = cumulusDensity(world_position + light_step * 2.4, cloud_time);
    const float optical_shadow = near_probe * 0.68 + far_probe * 0.32;
    const float direct_transmittance = exp(-optical_shadow * 2.65);
    const float directional_gate = saturate(active_light_strength);
    const float gated_transmittance = lerp(
        1.0,
        direct_transmittance,
        directional_gate
    );
    const float forward = pow(saturate(dot(ray_direction, light_direction)), 18.0);
    const float edge = smoothstep(0.06, 0.62, density) * (1.0 - density);

    const float3 ambient_color = cloudAmbientColor(daylight, night, twilight);
    const float3 light_color = cloudLightColor(daylight, night, twilight);
    const float direct_weight = daylight * 0.58 + twilight * 0.42 + night * 0.10;
    float3 color = ambient_color * (0.46 + gated_transmittance * 0.40);
    color += light_color * direct_transmittance * direct_weight * 0.42 *
        active_light_strength;
    color += light_color * forward * edge *
        (daylight * 1.20 + twilight * 1.55 + night * 0.20) *
        active_light_strength;

    const float alpha = density * cloudViewFade(ray_direction.y, distance_to_cloud) * 0.94;
    return float4(cloudFiniteRadiance(color), saturate(alpha));
}

float4 sampleCirrus(
    float3 ray_direction,
    float3 light_direction,
    float active_light_strength,
    float3 camera_position,
    float cloud_time,
    float daylight,
    float night,
    float twilight
)
{
    const float altitude = 225.0;
    if (ray_direction.y <= 0.018)
    {
        return float4(0.0, 0.0, 0.0, 0.0);
    }
    const float distance_to_cloud = (altitude - camera_position.y) / ray_direction.y;
    if (distance_to_cloud <= 0.0)
    {
        return float4(0.0, 0.0, 0.0, 0.0);
    }

    const float2 world_position = (camera_position + ray_direction * distance_to_cloud).xz;
    const float density = cirrusDensity(world_position, cloud_time);
    const float forward = pow(saturate(dot(ray_direction, light_direction)), 10.0);
    const float3 ambient_color = cloudAmbientColor(daylight, night, twilight);
    const float3 light_color = cloudLightColor(daylight, night, twilight);
    float3 color = ambient_color * 0.78;
    color += light_color * (daylight * 0.16 + twilight * 0.22 + night * 0.035) *
        active_light_strength;
    color += light_color * forward *
        (daylight * 0.42 + twilight * 0.58 + night * 0.08) *
        active_light_strength;

    const float alpha = density * cloudViewFade(ray_direction.y, distance_to_cloud) * 0.46;
    return float4(cloudFiniteRadiance(color), saturate(alpha));
}

float3 compositeCloudLayers(
    float3 background,
    float3 ray_direction,
    float3 cloud_light_direction,
    float active_light_strength,
    float3 ray_origin,
    float cloud_time,
    float daylight,
    float night,
    float twilight
)
{
    const float4 cirrus = sampleCirrus(
        ray_direction,
        cloud_light_direction,
        active_light_strength,
        ray_origin,
        cloud_time,
        daylight,
        night,
        twilight
    );
    float3 radiance = lerp(background, cirrus.rgb, cirrus.a);
    const float4 cumulus = sampleCumulus(
        ray_direction,
        cloud_light_direction,
        active_light_strength,
        ray_origin,
        cloud_time,
        daylight,
        night,
        twilight
    );
    radiance = lerp(radiance, cumulus.rgb, cumulus.a);
    return min(cloudFiniteRadiance(radiance), float3(16.0, 16.0, 16.0));
}

float cloudLightTransmittance(
    float3 world_position,
    float3 light_direction,
    float cloud_time,
    float daylight,
    float night,
    float twilight,
    float active_light_strength
)
{
    if (light_direction.y <= 0.018)
    {
        return 1.0;
    }
    const float cumulus_distance = (145.0 - world_position.y) / light_direction.y;
    const float cumulus_density = cumulus_distance > 0.0
        ? cumulusDensity((world_position + light_direction * cumulus_distance).xz, cloud_time)
        : 0.0;
    // The thin cirrus layer remains visible in the environment but does not
    // pay for a second high-frequency ground-shadow lookup. The denser lower
    // layer owns the slow, soft direct-light modulation.
    const float optical_depth = cumulus_density * 1.55;
    const float covered_transmittance = exp(-optical_depth);
    const float directional_gate = saturate(active_light_strength);
    const float shadow_strength = saturate(
        (daylight * 0.62 + twilight * 0.30 + night * 0.14) * directional_gate
    );
    return lerp(1.0, covered_transmittance, shadow_strength);
}

float3 ptgiEnvironmentRadiance(float3 direction, float3 ray_origin)
{
    const float3 ray_direction = cloudSafeNormalize(direction, float3(0.0, 1.0, 0.0));
    const float daylight = saturate(frame_data.light_color_and_daylight.w);
    const float night = saturate(frame_data.sky_color_and_night.w);
    const float twilight = saturate(1.0 - daylight - night);
    const float3 sun_direction = cloudSafeNormalize(
        frame_data.sun_direction_and_cloud_time.xyz,
        float3(0.0, 1.0, 0.0)
    );
    const float3 cloud_light_direction = cloudSafeNormalize(
        frame_data.light_direction_and_strength.xyz,
        sun_direction
    );
    const float active_light_strength = max(
        frame_data.light_direction_and_strength.w,
        0.0
    );
    float3 radiance = atmosphereRadiance(
        ray_direction,
        sun_direction,
        daylight,
        night,
        twilight
    );
    radiance = compositeCloudLayers(
        radiance,
        ray_direction,
        cloud_light_direction,
        active_light_strength,
        ray_origin,
        frame_data.sun_direction_and_cloud_time.w,
        daylight,
        night,
        twilight
    );
    return radiance * lerp(0.35, 0.56, daylight);
}

float3 traceDiffuseIndirectRadiance(
    uint2 pixel,
    float3 primary_point,
    float3 primary_normal,
    float maximum_distance,
    float shadow_bias
)
{
    const uint requested_bounces = uint(max(
        frame_data.frame_index_seed_and_light_radius.w,
        1.0
    ));
    const uint bounce_count = min(
        requested_bounces,
        maximum_diffuse_bounce_count
    );
    float3 radiance = float3(0.0, 0.0, 0.0);
    float3 throughput = float3(1.0, 1.0, 1.0);
    float3 bounce_point = primary_point;
    float3 bounce_normal = primary_normal;
    float3 first_direction = primary_normal;
    bool path_reached_environment = false;

    for (uint bounce_index = 0u;
        bounce_index < maximum_diffuse_bounce_count;
        ++bounce_index)
    {
        if (bounce_index >= bounce_count)
        {
            break;
        }

        const uint first_random_lane = bounce_index * 4u;
        const float3 bounce_direction = cosineHemisphere(
            bounce_normal,
            temporalSample2D(pixel, first_random_lane)
        );
        const float3 bounce_origin = bounce_point + bounce_normal * shadow_bias;
        if (bounce_index == 0u)
        {
            first_direction = bounce_direction;
        }

        const VisibilityPayload bounce_hit = traceVoxelScene(
            bounce_origin,
            bounce_direction,
            maximum_distance
        );
        if (bounce_hit.did_hit == 0)
        {
            if (diffuseMissReachesEnvironment(
                bounce_origin,
                bounce_direction,
                maximum_distance
            ))
            {
                path_reached_environment = true;
                radiance += throughput * ptgiEnvironmentRadiance(
                    bounce_direction,
                    bounce_origin
                );
            }
            break;
        }

        bounce_point = bounce_origin + bounce_direction * bounce_hit.distance;
        bounce_normal = normalize(bounce_hit.normal);
        const float3 albedo = secondarySurfaceAlbedo(bounce_point, bounce_normal);
        const float3 direct = secondaryDirectIllumination(
            pixel,
            first_random_lane + 2u,
            bounce_point,
            bounce_normal,
            maximum_distance,
            shadow_bias
        );
        radiance += throughput * albedo * direct;
        throughput *= albedo;

        if (bounce_index + 1u >= bounce_count)
        {
            // The old one-bounce path terminated with this low residual
            // environment term. Keeping it only at the final configured hit
            // preserves that baseline without counting it once per bounce.
            radiance += throughput * secondaryEnvironmentIllumination();
            break;
        }
    }

    const float neighborhood_weight = tracedNeighborhoodWeight(primary_point);
    if (path_reached_environment && neighborhood_weight < 1.0)
    {
        const float3 edge_environment = ptgiEnvironmentRadiance(
            first_direction,
            primary_point + primary_normal * shadow_bias
        );
        radiance = lerp(edge_environment, radiance, neighborhood_weight);
    }
    return radiance;
}

float3 waterReflectionSkyRadiance(float3 direction, float3 ray_origin)
{
    const float3 ray_direction = cloudSafeNormalize(direction, float3(0.0, 1.0, 0.0));
    const float daylight = saturate(frame_data.light_color_and_daylight.w);
    const float night = saturate(frame_data.sky_color_and_night.w);
    const float twilight = saturate(1.0 - daylight - night);
    const float3 sun_direction = cloudSafeNormalize(
        frame_data.sun_direction_and_cloud_time.xyz,
        float3(0.0, 1.0, 0.0)
    );
    const float3 moon_direction = -sun_direction;
    const float3 cloud_light_direction = cloudSafeNormalize(
        frame_data.light_direction_and_strength.xyz,
        sun_direction
    );
    const float active_light_strength = max(
        frame_data.light_direction_and_strength.w,
        0.0
    );
    float3 radiance = atmosphereRadiance(
        ray_direction,
        sun_direction,
        daylight,
        night,
        twilight
    );

    const float sun_alignment = dot(ray_direction, sun_direction);
    const float sun_disk = smoothstep(cos(0.045), cos(0.045 * 0.82), sun_alignment);
    const float sun_halo = smoothstep(cos(0.045 * 8.0), 1.0, sun_alignment);
    const float sun_visibility = saturate(daylight + twilight) *
        smoothstep(-0.04, 0.03, sun_direction.y);
    radiance += float3(1.0, 0.30, 0.07) * sun_halo * sun_halo *
        twilight * 0.56;
    radiance += float3(1.0, 0.84, 0.58) * sun_halo * daylight * 0.22;
    radiance = lerp(
        radiance,
        lerp(float3(1.0, 0.48, 0.15), float3(1.0, 0.95, 0.78), daylight),
        sun_disk * sun_visibility
    );

    const float moon_alignment = dot(ray_direction, moon_direction);
    const float moon_disk = smoothstep(cos(0.055), cos(0.055 * 0.82), moon_alignment);
    const float moon_halo = smoothstep(cos(0.055 * 5.0), 1.0, moon_alignment);
    const float moon_visibility = saturate(night + twilight * 0.18) *
        smoothstep(-0.04, 0.03, moon_direction.y);
    radiance += float3(0.12, 0.18, 0.34) * moon_halo * moon_halo *
        0.8 * moon_visibility;
    radiance = lerp(
        radiance,
        float3(0.82, 0.88, 1.0),
        moon_disk * moon_visibility
    );

    return compositeCloudLayers(
        radiance,
        ray_direction,
        cloud_light_direction,
        active_light_strength,
        ray_origin,
        frame_data.sun_direction_and_cloud_time.w,
        daylight,
        night,
        twilight
    );
}

[shader("raygeneration")]
void raygen()
{
    const uint2 pixel = DispatchRaysIndex().xy;
    const uint2 size = DispatchRaysDimensions().xy;
    water_reflection_target[pixel] = float4(0.0, 0.0, 0.0, 0.0);

    const float maximum_distance = max(
        abs(frame_data.camera_right_and_max_distance.w),
        minimum_ray_distance * 2.0
    );
    const float water_reflection_maximum_distance = min(maximum_distance, 96.0);
    const float shadow_bias = max(abs(frame_data.camera_up_and_shadow_bias.w), minimum_ray_distance);
    const float3 ray_origin = frame_data.camera_position_and_tan_half_fov.xyz;
    const float3 primary_direction = cameraRayDirection(pixel, size);
    const float4 water_surface = water_surface_gbuffer.Load(int3(pixel, 0));
    if (water_surface.w > 0.0 &&
        all(isfinite(water_surface)) &&
        dot(water_surface.xyz, water_surface.xyz) > 0.000001)
    {
        const float3 water_point = ray_origin + primary_direction * water_surface.w;
        float3 water_normal = normalize(water_surface.xyz);
        if (dot(water_normal, -primary_direction) < 0.0)
        {
            water_normal = -water_normal;
        }
        const float3 reflection_direction = reflect(primary_direction, water_normal);
        const float3 reflection_origin = water_point + water_normal * shadow_bias;
        const VisibilityPayload reflection_hit = traceVoxelScene(
            reflection_origin,
            reflection_direction,
            water_reflection_maximum_distance
        );
        float3 reflection_radiance;
        if (reflection_hit.did_hit != 0)
        {
            const float3 reflection_point = reflection_origin +
                reflection_direction * reflection_hit.distance;
            reflection_radiance = secondarySurfaceRadiance(
                pixel,
                14u,
                reflection_point,
                reflection_hit.normal,
                maximum_distance,
                shadow_bias
            );
        }
        else
        {
            reflection_radiance = waterReflectionSkyRadiance(
                reflection_direction,
                reflection_origin
            );
        }
        if (!all(isfinite(reflection_radiance)))
        {
            reflection_radiance = float3(0.0, 0.0, 0.0);
        }
        water_reflection_target[pixel] = float4(
            min(max(reflection_radiance, 0.0), 4.0),
            1.0
        );
    }

    const float4 surface = surface_gbuffer.Load(int3(pixel, 0));
    if (surface.w <= 0.0)
    {
        output_texture[pixel] = float4(0.0, 0.0, 0.0, -1.0);
        return;
    }

    const float3 hit_point = ray_origin + primary_direction * surface.w;
    const float3 normal = normalize(surface.xyz);
    const float3 secondary_origin = hit_point + normal * shadow_bias;

    const float3 light_direction = normalize(frame_data.light_direction_and_strength.xyz);
    const float n_dot_l = max(dot(normal, light_direction), 0.0);
    const float daylight = saturate(frame_data.light_color_and_daylight.w);
    const float night = saturate(frame_data.sky_color_and_night.w);
    const float twilight = saturate(1.0 - daylight - night);
    float directional_visibility = 0.0;
    if (n_dot_l > 0.0 && frame_data.light_direction_and_strength.w > 0.0)
    {
        const float3 shadow_direction = sampleCelestialDiskDirection(
            light_direction,
            frame_data.light_direction_and_strength.w,
            frame_data.frame_index_seed_and_light_radius.z,
            temporalSample2D(pixel, 12u)
        );
        const VisibilityPayload light_hit = traceVoxelScene(
            secondary_origin,
            shadow_direction,
            maximum_distance
        );
        directional_visibility = light_hit.did_hit == 0
            ? cloudLightTransmittance(
                hit_point,
                shadow_direction,
                frame_data.sun_direction_and_cloud_time.w,
                daylight,
                night,
                twilight,
                frame_data.light_direction_and_strength.w
            )
            : 0.0;
    }

    float3 indirect_radiance = traceDiffuseIndirectRadiance(
        pixel,
        hit_point,
        normal,
        maximum_distance,
        shadow_bias
    );
    if (!all(isfinite(indirect_radiance)))
    {
        indirect_radiance = float3(0.0, 0.0, 0.0);
    }

    output_texture[pixel] = float4(
        min(max(indirect_radiance, 0.0), 4.0),
        directional_visibility
    );
}

[shader("miss")]
void miss(inout VisibilityPayload payload)
{
    payload.normal = float3(0.0, 0.0, 0.0);
    payload.did_hit = 0;
}

[shader("closesthit")]
void closest_hit(
    inout VisibilityPayload payload,
    BuiltInTriangleIntersectionAttributes attributes
)
{
    const float distance = RayTCurrent();
    const float3 direction = WorldRayDirection();
    const float3 world_point = WorldRayOrigin() + direction * distance;
    payload.normal = voxelFaceNormal(world_point, direction);
    payload.distance = distance;
    payload.did_hit = 1;
}

[shader("anyhit")]
void any_hit(
    inout VisibilityPayload payload,
    BuiltInTriangleIntersectionAttributes attributes
)
{
}

[shader("intersection")]
void unused_intersection()
{
}
