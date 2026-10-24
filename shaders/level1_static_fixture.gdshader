shader_type spatial;
render_mode cull_back,vertex_lighting;
void fragment() { ALBEDO=COLOR.rgb;ROUGHNESS=1.0;SPECULAR=0.0; }
