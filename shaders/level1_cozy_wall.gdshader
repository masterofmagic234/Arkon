shader_type spatial;
render_mode cull_back, vertex_lighting;
uniform vec4 tint : source_color = vec4(.30,.46,.47,1.0);
uniform vec4 coping : source_color = vec4(.78,.76,.63,1.0);
varying float foot;
void vertex() { float y=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;foot=mix(.82,1.0,smoothstep(0.0,.55,y)); }
void fragment() { ALBEDO=mix(tint.rgb,coping.rgb,COLOR.a)*foot;ROUGHNESS=1.0;SPECULAR=0.0; }
