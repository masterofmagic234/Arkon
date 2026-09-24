shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float fade_inner : hint_range(0.0, 1.0) = 0.30;
uniform float fade_outer : hint_range(0.0, 1.0) = 0.85;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float mushroom_glow_threshold : hint_range(0.0, 1.0) = 0.72;
uniform float mushroom_glow_strength : hint_range(0.0, 3.0) = 0.9;

void fragment() {
    vec2 uv = UV;
    vec4 tex = texture(albedo_tex, uv) * tint;

    // Radial distance from UV center (0.5, 0.5), normalized to 0..1.
    vec2 d = uv - vec2(0.5);
    float dist = length(d) * 1.4142;

    // Smoothstep fade: opaque inside fade_inner, transparent past fade_outer.
    float alpha = 1.0 - smoothstep(fade_inner, fade_outer, dist);

    ALBEDO = tex.rgb;

    // Only the brightest parts of the hero-grass texture (the mushrooms and
    // other intentionally bright accents) become emissive. The grass itself
    // stays dark so the whole tile does not turn into a glowing square.
    float brightness = max(max(tex.r, tex.g), tex.b);
    float glow_mask = smoothstep(mushroom_glow_threshold, 1.0, brightness);
    EMISSION = tex.rgb * glow_mask * mushroom_glow_strength;

    ALPHA = tex.a * alpha;
}
