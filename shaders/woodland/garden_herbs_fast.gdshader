shader_type spatial;
// Actual 3D leaves remain opaque; small triangles interpolate direct lighting
// instead of evaluating six lanterns and the moon separately per fragment.
// Shared vertices have both index windings in the fast herb meshes. Backface
// culling keeps the authored upper-leaf normal on both sides; cull_disabled
// flips it after vertex lighting and produced black seed heads/leaf undersides.
render_mode cull_back, vertex_lighting, diffuse_lambert_wrap, specular_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float fade_begin = 48.0;
uniform float fade_end = 64.0;
uniform float brightness = 1.0;
varying vec3 vertex_tint;
void vertex() {
    vec3 root = MODEL_MATRIX[3].xyz;
    float distance_ = length(root.xz - CAMERA_POSITION_WORLD.xz);
    float visible_size = 1.0 - smoothstep(fade_begin, fade_end, distance_);
    VERTEX *= visible_size;
    vertex_tint = OUTPUT_IS_SRGB
        ? max(vec3(1.055) * pow(max(COLOR.rgb, vec3(0.0)), vec3(.416666667)) - .055, vec3(0.0))
        : COLOR.rgb;
}
void fragment() {
    ALBEDO = texture(atlas, UV).rgb * vertex_tint * brightness
        * (OUTPUT_IS_SRGB ? vec3(1.0) : vec3(.62, .76, .62));
    ROUGHNESS = .96;
    SPECULAR = 0.0;
}
