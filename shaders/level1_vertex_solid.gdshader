shader_type spatial;
render_mode cull_back, vertex_lighting;
// Alpha is immutable emission strength, not transparency. All triangles use
// the opaque depth path and share the same shader/material.
void fragment() {
    ALBEDO=COLOR.rgb;
    EMISSION=COLOR.rgb*COLOR.a*4.0;
    ROUGHNESS=.88;SPECULAR=.18;
}
