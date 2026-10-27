shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
varying vec3 vertex_tint;
void vertex() {
    vertex_tint = OUTPUT_IS_SRGB ? max(vec3(1.055)*pow(max(COLOR.rgb,vec3(0.0)),vec3(.416666667))-.055,vec3(0.0)) : COLOR.rgb;
}
void fragment() {
    vec3 color=texture(atlas,UV).rgb;
    ALBEDO=color*vertex_tint*(OUTPUT_IS_SRGB?vec3(1.0):vec3(.62,.76,.62));
    ROUGHNESS=.96;
    SPECULAR=0.0;
    BACKLIGHT=vec3(.19,.23,.10);
}
