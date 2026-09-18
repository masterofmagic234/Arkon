shader_type sky;

uniform sampler2D panorama : filter_linear, source_color;
uniform vec3 fog_color : source_color = vec3(0.16, 0.23, 0.34);
uniform float horizon : hint_range(0.35, 0.65, 0.01) = 0.50;
uniform float blend_width : hint_range(0.01, 0.20, 0.01) = 0.08;

void sky() {
    vec3 sky_color = texture(panorama, SKY_COORDS).rgb * 0.9;

    // The world geometry is intentionally clipped at 12m on mobile.
    // Never expose the panorama through that missing lower-world area.
    // Keep the actual starry sky above the horizon, but turn the lower
    // hemisphere into the same blue fog color used by the Level 1 cutoff.
    float lower_mask = 1.0 - smoothstep(horizon - blend_width, horizon + blend_width, SKY_COORDS.y);
    COLOR = mix(sky_color, fog_color, lower_mask);
}
