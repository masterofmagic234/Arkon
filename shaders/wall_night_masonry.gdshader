shader_type spatial;
render_mode cull_back, unshaded;

uniform sampler2D wall_texture : source_color, filter_nearest, repeat_disable;
uniform float strip_repeat = 1.0;

void fragment() {
    // One QuadMesh represents a complete straight wall run. Map the entire
    // 4096x512 mural across that run; longer runs repeat the complete mural,
    // never a single 512px panel.
    float repeat_count = max(strip_repeat, 0.125);
    vec2 uv = vec2(fract(UV.x * repeat_count), clamp(UV.y, 0.0, 1.0));
    vec4 tex = texture(wall_texture, uv);
    ALBEDO = tex.rgb;
    ALPHA = tex.a;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
