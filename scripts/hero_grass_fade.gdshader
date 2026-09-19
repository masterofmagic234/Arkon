shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float fade_inner : hint_range(0.0, 1.0) = 0.30;
uniform float fade_outer : hint_range(0.0, 1.0) = 0.85;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec2 uv = UV;
    vec4 tex = texture(albedo_tex, uv) * tint;

    // Radial distance from UV center (0.5, 0.5), normalized to 0..1.
    vec2 d = uv - vec2(0.5);
    float dist = length(d) * 1.4142;

    // Smoothstep fade: opaque inside fade_inner, transparent past fade_outer.
    float alpha = 1.0 - smoothstep(fade_inner, fade_outer, dist);

    ALBEDO = tex.rgb;
    ALPHA = tex.a * alpha;
}
