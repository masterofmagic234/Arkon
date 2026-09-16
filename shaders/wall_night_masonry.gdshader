shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform sampler2D wall_texture : source_color;
uniform float wall_segment = 0.0;

void fragment() {
    // Each 4096x512 wall illustration is an eight-panel strip. A physical
    // 1.8 x 2.6 wall box receives one 512x512 panel, avoiding the old
    // corridor-wide stretch while preserving the original pixel artwork.
    vec2 uv = UV;
    uv.x = uv.x / 8.0 + wall_segment / 8.0;
    vec4 tex = texture(wall_texture, uv);

    ALBEDO = tex.rgb;
    ALPHA = tex.a;
    ROUGHNESS = 0.94;
    SPECULAR = 0.12;
}
