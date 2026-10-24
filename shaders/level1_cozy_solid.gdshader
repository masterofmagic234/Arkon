shader_type spatial;
render_mode cull_back, vertex_lighting;
uniform vec4 tint : source_color = vec4(.3,.5,.5,1.0);
uniform float sway = 0.0;
void vertex() {
    vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.x+=sin(world.x*.17+world.z*.13+TIME*.75)*sway;
}
void fragment() { ALBEDO=tint.rgb*COLOR.rgb;ROUGHNESS=1.0;SPECULAR=0.0; }
