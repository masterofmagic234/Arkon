shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color;
uniform float alpha_scissor_threshold = 0.46;
uniform float wind_strength = 0.085;
uniform float wind_speed = 1.25;
uniform float wind_scale = 0.19;

void vertex() {
    float height_mask = clamp(VERTEX.y / 1.35, 0.0, 1.0);
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    float phase = world_pos.x * wind_scale + world_pos.z * (wind_scale * 0.73);
    float gust = sin(TIME * wind_speed + phase);
    float gust2 = sin(TIME * (wind_speed * 0.61) - phase * 1.7);
    float bend = (gust * 0.70 + gust2 * 0.30) * wind_strength * height_mask * height_mask;

    VERTEX.x += bend;
    VERTEX.z += bend * 0.42;
}

void fragment() {
    vec4 tex = texture(albedo_tex, UV);
    ALBEDO = tex.rgb;
    ALPHA = tex.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}