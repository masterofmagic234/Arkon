shader_type spatial;
render_mode cull_back;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.74, 0.82, 0.72);
varying vec2 world_xz;
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
    ALBEDO = texture(ground_tex, world_xz * 0.14).rgb * tint;
    ROUGHNESS = 0.94;
    SPECULAR = 0.16;
}
