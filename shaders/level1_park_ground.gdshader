shader_type spatial;
render_mode cull_back,vertex_lighting;
uniform vec3 tint : source_color = vec3(.28,.44,.45);
varying float shade;
void vertex() { vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;shade=.97+.03*sin(w.x*.055+w.z*.04); }
void fragment() { ALBEDO=tint*shade;ROUGHNESS=1.0;SPECULAR=0.0; }
