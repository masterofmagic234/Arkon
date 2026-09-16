shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform sampler2D wall_texture : source_color, filter_nearest;
uniform float wall_segment = 0.0;

void fragment() {
    // The wall artwork is a 4096x512 strip made of eight 512px panels.
    // Its top band contains the old presentation/title text. Never map that
    // band onto the physical wall: use only the actual illustrated masonry
    // area below it. This keeps each 1.8 x 2.6 wall box visually clean.
    vec2 uv = UV;
    uv.x = uv.x / 8.0 + wall_segment / 8.0;
    uv.y = mix(0.20, 1.0, UV.y);

    vec4 tex = texture(wall_texture, uv);
    ALBEDO = tex.rgb;
    ALPHA = tex.a;
    ROUGHNESS = 0.94;
    SPECULAR = 0.12;
}
