shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.23,0.31,0.28,1.0);
varying vec3 world;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world.xz;
 float grain=noise(p*3.8)+noise(p*11.0)*.22;
 float strata=noise(vec2(p.x*.42+p.y*.3,world.y*1.9));
 float moss=smoothstep(1.1,2.8,world.y+noise(p*.55)*.8);
 vec3 rock=tint.rgb*(.68+grain*.43+strata*.12);
 vec3 green=tint.rgb*vec3(.69,1.06,.72)*(1.0+grain*.18);
 ALBEDO=mix(rock,green,moss*.8);
 ROUGHNESS=.98;SPECULAR=.08;
}
