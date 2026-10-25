shader_type spatial;
// Binary cutouts still write real depth. Drawing canopy color after the opaque
// AO pass avoids rasterizing its overlapping cards into the normal buffer.
// A separate masked, shadow-only instance preserves every original sun shadow.
render_mode cull_back, depth_draw_always;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
void fragment() {
    vec4 c = texture(atlas, UV);
    if (c.a < .38) discard;
    ALBEDO = c.rgb * COLOR.rgb * vec3(.62, .76, .62);
    ALPHA = 1.0;
    ROUGHNESS = .92;
    BACKLIGHT = vec3(.17, .20, .08);
}
