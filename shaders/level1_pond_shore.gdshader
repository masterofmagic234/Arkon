shader_type spatial;
render_mode cull_back,vertex_lighting;
void fragment() { ALBEDO=mix(vec3(.20,.34,.34),vec3(.36,.47,.43),COLOR.r);ROUGHNESS=1.0;SPECULAR=0.0; }
