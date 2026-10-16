shader_type spatial;
render_mode cull_back, unshaded;
void fragment() {
    ALBEDO = COLOR.rgb;
    EMISSION = COLOR.rgb * 0.45;
}
