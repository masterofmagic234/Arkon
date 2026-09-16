shader_type spatial;
render_mode cull_disabled, unshaded;

// Each wall face receives one complete texture. There is no atlas/panel
// selection and no world-position sampling, so corners cannot split artwork.
uniform sampler2D wall_texture : source_color, filter_linear, repeat_enable;

void fragment() {
    // QuadMesh UVs cover the complete generated texture from 0..1.
    // Flip vertically so the texture reads upright on the wall.
    vec2 uv = vec2(UV.x, 1.0 - UV.y);
    vec4 tex = texture(wall_texture, uv);

    ALBEDO = tex.rgb;
    ALPHA = 1.0;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
