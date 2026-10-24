shader_type spatial;
render_mode cull_back,vertex_lighting;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float wave=sin(world_position.x*3.5+world_position.z*2.7+TIME*.7)*.5+.5;ALBEDO=mix(vec3(.12,.23,.22),vec3(.29,.38,.30),wave*.18);ROUGHNESS=.29;SPECULAR=.55;METALLIC=.08;}
