shader_type spatial;
// Real closed volumes replace dozens of overlapping alpha planes. Keeping
// ALPHA unwritten places this material in the opaque pass on GLES3 as well.
render_mode cull_back, vertex_lighting, diffuse_lambert, specular_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float grow_begin = 18.0;
uniform float grow_end = 29.0;
uniform float shrink_begin = 65.0;
uniform float shrink_end = 86.0;
void vertex() {
    vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    float range = distance(center, CAMERA_POSITION_WORLD);
    float scale = smoothstep(grow_begin, grow_end, range) * (1.0 - smoothstep(shrink_begin, shrink_end, range));
    VERTEX *= scale;
}
void fragment() {
    ALBEDO = texture(atlas, UV).rgb * COLOR.rgb * (OUTPUT_IS_SRGB ? vec3(1.0) : vec3(.62, .76, .62));
    ROUGHNESS = 1.0;
}
