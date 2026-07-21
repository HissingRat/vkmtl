struct SkyUniforms
{
    float4 camera_forward_and_time;
    float4 camera_horizontal_span;
    float4 camera_vertical_span;
    float4 camera_position_and_cloud_time;
    float4 sun_direction_and_radius;
    float4 moon_direction_and_radius;
    float4 cycle_blend_and_phase;
};

struct SkyVertexOutput
{
    float4 position : SV_Position;
    float2 screen_position : TEXCOORD0;
};

[[vk::binding(0, 0)]]
ConstantBuffer<SkyUniforms> sky : register(b0, space0);

float hash12(float2 value)
{
    float3 p = frac(float3(value.x, value.y, value.x) * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return frac((p.x + p.y) * p.z);
}

float2 hash22(float2 value)
{
    return float2(
        hash12(value + float2(17.17, 43.73)),
        hash12(value + float2(91.41, 11.79))
    );
}

float valueNoise2D(float2 point)
{
    const float2 cell = floor(point);
    const float2 local = frac(point);
    const float2 blend = local * local * (3.0 - 2.0 * local);
    const float lower = lerp(
        hash12(cell),
        hash12(cell + float2(1.0, 0.0)),
        blend.x
    );
    const float upper = lerp(
        hash12(cell + float2(0.0, 1.0)),
        hash12(cell + float2(1.0, 1.0)),
        blend.x
    );
    return lerp(lower, upper, blend.y);
}

float finiteNonNegative(float value)
{
    return isfinite(value) ? max(value, 0.0) : 0.0;
}

float3 finiteRadiance(float3 value)
{
    return float3(
        finiteNonNegative(value.x),
        finiteNonNegative(value.y),
        finiteNonNegative(value.z)
    );
}

float3 safeNormalize(float3 value, float3 fallback)
{
    const float length_squared = dot(value, value);
    return isfinite(length_squared) && length_squared > 0.000001
        ? value * rsqrt(length_squared)
        : fallback;
}

float starField(float3 ray_direction, float cycle_phase)
{
    const float azimuth = atan2(ray_direction.z, ray_direction.x) * 0.1591549431 + 0.5;
    const float elevation = asin(clamp(ray_direction.y, -1.0, 1.0)) * 0.3183098862 + 0.5;
    const float2 grid_size = float2(180.0, 90.0);
    const float2 grid_position = float2(azimuth, elevation) * grid_size;
    const float2 cell = floor(grid_position);
    const float2 local_position = frac(grid_position);
    const float existence = hash12(cell + float2(3.1, 7.7));
    const float2 center = 0.18 + hash22(cell) * 0.64;
    const float point = 1.0 - smoothstep(0.025, 0.105, length(local_position - center));
    const float phase = hash12(cell + float2(61.7, 29.3)) * 6.283185307;
    const float cycles_per_day = floor(lerp(8.0, 20.999, hash12(cell + float2(5.3, 83.1))));
    const float twinkle = 0.58 + 0.42 * sin(cycle_phase * 6.283185307 * cycles_per_day + phase);
    const float horizon_fade = smoothstep(0.02, 0.18, ray_direction.y);
    return step(0.982, existence) * point * twinkle * horizon_fade;
}

float miePhase(float alignment)
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
    // Preserve the bright visible horizon while preventing downward rays from
    // inheriting the same sky radiance. The transition finishes below the
    // lowest cloud-visible elevation and is fully open for ordinary sky rays.
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
    const float mie_phase = miePhase(alignment);
    const float solar_visibility = smoothstep(-0.10, 0.035, sun_direction.y);
    const float solar_energy = saturate(daylight + twilight * 0.82) * solar_visibility;

    const float3 zenith_floor = float3(0.025, 0.105, 0.38);
    const float3 horizon_floor = float3(0.22, 0.42, 0.65);
    float3 daytime = lerp(zenith_floor, horizon_floor, horizon) * daylight;
    daytime += view_scatter * sun_transmittance *
        (rayleigh_phase * 0.72 + mie_phase * 0.038) * solar_energy * 1.30;

    const float2 flat_view = safeNormalize(
        float3(ray_direction.x, 0.0, ray_direction.z),
        float3(0.0, 0.0, 1.0)
    ).xz;
    const float2 flat_sun = safeNormalize(
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
    const float3 twilight_glow = float3(1.0, 0.20, 0.035) * low_sun_band * 0.62;

    const float3 night_zenith = float3(0.002, 0.005, 0.020);
    const float3 night_horizon = float3(0.010, 0.018, 0.050);
    const float3 night_sky = lerp(night_zenith, night_horizon, horizon) * night;
    return finiteRadiance(
        daytime + twilight_base * twilight + twilight_glow + night_sky
    ) * sky_visibility;
}

float cumulusDensity(float2 world_position, float cloud_time)
{
    const float2 wind = float2(0.52, 0.18) * cloud_time;
    const float2 p = (world_position + wind) * 0.0062;
    const float broad = valueNoise2D(p * 0.43 + float2(12.7, -8.4));
    const float detail =
        valueNoise2D(p) * 0.55 +
        valueNoise2D(p * 2.07 + float2(19.4, 5.6)) * 0.28 +
        valueNoise2D(p * 4.31 + float2(-7.2, 31.8)) * 0.17;
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
        valueNoise2D(stretched * 0.55 + float2(4.3, 15.7)),
        valueNoise2D(stretched * 0.47 + float2(-9.1, 2.8))
    ) - 0.5;
    stretched += float2(warp.x * 0.85, warp.y * 0.22);
    const float bands =
        valueNoise2D(stretched) * 0.58 +
        valueNoise2D(stretched * 2.13 + float2(8.6, -6.9)) * 0.27 +
        valueNoise2D(stretched * 4.40 + float2(-3.7, 22.1)) * 0.15;
    const float ridge = 1.0 - abs(bands * 2.0 - 1.0);
    const float coverage = valueNoise2D(stretched * 0.31 + float2(27.2, 11.3));
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
    const float3 day_light = float3(1.0, 0.91, 0.74);
    const float3 twilight_light = float3(1.0, 0.36, 0.12);
    const float3 moon_light = float3(0.40, 0.53, 0.90);
    return day_light * daylight + twilight_light * twilight + moon_light * night;
}

float3 cloudAmbientColor(float daylight, float night, float twilight)
{
    const float3 day_fill = float3(0.54, 0.63, 0.75);
    const float3 twilight_fill = float3(0.32, 0.17, 0.13);
    const float3 night_fill = float3(0.014, 0.022, 0.050);
    return day_fill * daylight + twilight_fill * twilight + night_fill * night;
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
    return float4(finiteRadiance(color), saturate(alpha));
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
    return float4(finiteRadiance(color), saturate(alpha));
}

[shader("vertex")]
SkyVertexOutput sky_vs(uint vertex_id : SV_VertexID)
{
    const float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };

    SkyVertexOutput output;
    output.position = float4(positions[vertex_id], 1.0, 1.0);
    output.screen_position = positions[vertex_id];
    return output;
}

[shader("fragment")]
float4 sky_fs(SkyVertexOutput input) : SV_Target0
{
    const float3 ray_direction = safeNormalize(
        sky.camera_forward_and_time.xyz +
        input.screen_position.x * sky.camera_horizontal_span.xyz +
        input.screen_position.y * sky.camera_vertical_span.xyz,
        float3(0.0, 1.0, 0.0)
    );

    const float daylight = saturate(sky.cycle_blend_and_phase.x);
    const float night = saturate(sky.cycle_blend_and_phase.y);
    const float twilight = saturate(sky.cycle_blend_and_phase.z);
    const float3 sun_direction = safeNormalize(
        sky.sun_direction_and_radius.xyz,
        float3(0.0, 1.0, 0.0)
    );
    const float3 moon_direction = safeNormalize(
        sky.moon_direction_and_radius.xyz,
        -sun_direction
    );

    float3 color = atmosphereRadiance(
        ray_direction,
        sun_direction,
        daylight,
        night,
        twilight
    );

    const float sun_radius = max(sky.sun_direction_and_radius.w, 0.001);
    const float sun_alignment = dot(ray_direction, sun_direction);
    const float sun_disk = smoothstep(cos(sun_radius), cos(sun_radius * 0.82), sun_alignment);
    const float sun_halo = smoothstep(cos(sun_radius * 8.0), 1.0, sun_alignment);
    const float sun_above_horizon = smoothstep(-0.04, 0.03, sun_direction.y);
    const float sun_visibility = saturate(daylight + twilight) * sun_above_horizon;
    color += float3(1.0, 0.30, 0.07) * sun_halo * sun_halo * twilight * 0.56;
    color += float3(1.0, 0.84, 0.58) * sun_halo * daylight * 0.22;
    color = lerp(
        color,
        lerp(float3(1.0, 0.48, 0.15), float3(1.0, 0.95, 0.78), daylight),
        sun_disk * sun_visibility
    );

    const float moon_radius = max(sky.moon_direction_and_radius.w, 0.001);
    const float moon_alignment = dot(ray_direction, moon_direction);
    const float moon_disk = smoothstep(cos(moon_radius), cos(moon_radius * 0.82), moon_alignment);
    const float moon_halo = smoothstep(cos(moon_radius * 5.0), 1.0, moon_alignment);
    const float moon_above_horizon = smoothstep(-0.04, 0.03, moon_direction.y);
    const float moon_visibility = saturate(night + twilight * 0.18) * moon_above_horizon;
    const float star_visibility = saturate(night + twilight * 0.12);
    float stars = 0.0;
    if (star_visibility > 0.001)
    {
        stars = starField(ray_direction, sky.cycle_blend_and_phase.w) *
            (1.0 - moon_disk) * star_visibility;
    }
    color += float3(0.72, 0.82, 1.0) * stars;
    color += float3(0.12, 0.18, 0.34) * moon_halo * moon_halo * 0.8 * moon_visibility;
    color = lerp(color, float3(0.82, 0.88, 1.0), moon_disk * moon_visibility);

    const float3 camera_position = sky.camera_position_and_cloud_time.xyz;
    const float cloud_time = sky.camera_position_and_cloud_time.w;
    // Match scene.celestialState exactly. The direction switches only where
    // both smooth direct strengths are zero, and every direction-dependent
    // cloud term is gated by that strength, so twilight stays continuous.
    const float sun_elevation = sun_direction.y;
    const float sun_direct = smoothstep(0.0, 0.18, sun_elevation);
    const float moon_direct = smoothstep(0.0, 0.18, -sun_elevation);
    const float active_light_strength = sun_direct * 1.20 + moon_direct * 0.72;
    const float3 cloud_light_direction = sun_elevation >= 0.0
        ? sun_direction
        : moon_direction;
    const float4 cirrus = sampleCirrus(
        ray_direction,
        cloud_light_direction,
        active_light_strength,
        camera_position,
        cloud_time,
        daylight,
        night,
        twilight
    );
    color = lerp(color, cirrus.rgb, cirrus.a);
    const float4 cumulus = sampleCumulus(
        ray_direction,
        cloud_light_direction,
        active_light_strength,
        camera_position,
        cloud_time,
        daylight,
        night,
        twilight
    );
    color = lerp(color, cumulus.rgb, cumulus.a);

    return float4(min(finiteRadiance(color), float3(16.0, 16.0, 16.0)), 1.0);
}
