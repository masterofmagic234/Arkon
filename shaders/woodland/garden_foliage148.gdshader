shader_type spatial;
// One texture fetch and per-vertex diffuse lighting. No metallic/specular or
// second alpha texture. The trimmed geometry is a single, two-sided surface.
render_mode cull_back, vertex_lighting, diffuse_lambert, specular_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float detail_fade_begin = 23.0;
uniform float detail_fade_end = 36.0;
varying float detail_strength;
void vertex() {
    vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    detail_strength = 1.0 - smoothstep(detail_fade_begin, detail_fade_end, distance(world_vertex, CAMERA_POSITION_WORLD));
}
void fragment() {
    vec4 sample_color = texture(atlas, UV);
    if (sample_color.a * detail_strength < 0.42) discard;
    ALBEDO = sample_color.rgb * COLOR.rgb * (OUTPUT_IS_SRGB ? vec3(1.0) : vec3(.62, .76, .62));
    // A restrained transmission floor replaces the old per-fragment BACKLIGHT
    // term, which vertex lighting cannot evaluate on the back of a thin leaf.
    EMISSION = ALBEDO * 0.10;
    ROUGHNESS = 1.0;
}
