shader_type spatial;
render_mode cull_back,vertex_lighting;
uniform vec3 tint : source_color = vec3(.45,.64,.56);
uniform bool golden=false;
uniform vec3 golden_tint : source_color = vec3(.83,.66,.42);
void vertex() { vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.x+=sin(w.x*.12+w.z*.15+TIME*.65)*.004; }
void fragment() { ALBEDO=golden ? golden_tint : tint;ROUGHNESS=1.0;SPECULAR=0.0; }
