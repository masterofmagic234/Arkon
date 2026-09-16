shader_type sky;

uniform sampler2D panorama : filter_linear, source_color;
uniform float twinkle_strength : hint_range(0.0, 0.8, 0.01) = 0.48;
uniform float twinkle_speed : hint_range(0.1, 5.0, 0.1) = 1.6;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void sky() {
    vec2 uv = SKY_COORDS;
    vec2 texel = 1.0 / vec2(4096.0, 2048.0);
    vec3 base = texture(panorama, uv).rgb;

    float center_l = luminance(base);
    float neighbor_l = 0.0;
    neighbor_l += luminance(texture(panorama, uv + vec2(texel.x * 2.0, 0.0)).rgb);
    neighbor_l += luminance(texture(panorama, uv - vec2(texel.x * 2.0, 0.0)).rgb);
    neighbor_l += luminance(texture(panorama, uv + vec2(0.0, texel.y * 2.0)).rgb);
    neighbor_l += luminance(texture(panorama, uv - vec2(0.0, texel.y * 2.0)).rgb);
    neighbor_l *= 0.25;

    // Stars are the tiny bright points that stand above their local sky background.
    // Keep the original panorama completely intact everywhere else.
    float point_contrast = max(center_l - neighbor_l, 0.0);
    float star_mask = smoothstep(0.010, 0.055, point_contrast);
    star_mask *= smoothstep(0.16, 0.40, center_l);

    // The moon is baked into the panorama and must stay perfectly steady.
    float moon_dx = abs(uv.x - 0.782);
    moon_dx = min(moon_dx, 1.0 - moon_dx);
    float moon_distance = length(vec2(moon_dx, uv.y - 0.200));
    star_mask *= 1.0 - smoothstep(0.055, 0.11, moon_distance);

    // One stable phase per small star cluster. This avoids per-pixel noise while
    // making each visible star pulse independently from its neighbors.
    vec2 star_cell = floor(uv * vec2(512.0, 256.0));
    float seed = hash12(star_cell);
    float speed = twinkle_speed * mix(0.65, 1.35, hash12(star_cell + 17.13));
    float phase = hash12(star_cell + 71.37) * TAU;
    float wave = 0.5 + 0.5 * sin(TIME * speed + phase);

    // Deliberately strong enough to be visible on a phone, but never fully off.
    float twinkle = mix(1.0 - twinkle_strength, 1.0 + twinkle_strength, wave);
    twinkle *= 1.0 + (seed - 0.5) * 0.04;

    COLOR = base * mix(1.0, twinkle, clamp(star_mask, 0.0, 1.0)) * 0.9;
}
