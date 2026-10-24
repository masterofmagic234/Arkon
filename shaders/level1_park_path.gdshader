shader_type spatial;
render_mode cull_back,vertex_lighting;
uniform vec3 sett_color : source_color = vec3(.75,.61,.43);
uniform vec3 joint_color : source_color = vec3(.39,.51,.48);
void fragment() { float edge=smoothstep(0.0,.08,UV.x)*smoothstep(0.0,.08,1.0-UV.x);ALBEDO=mix(joint_color,sett_color,edge);ROUGHNESS=1.0;SPECULAR=0.0; }
