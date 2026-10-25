shader_type spatial;
render_mode cull_back;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
void fragment() {
    vec4 c = texture(atlas, UV);
    ALBEDO = c.rgb * COLOR.rgb * vec3(.62, .76, .62);
    ALPHA = c.a;
    ALPHA_SCISSOR_THRESHOLD = .38;
    ROUGHNESS = .92;
    BACKLIGHT = vec3(.17, .20, .08);
}
