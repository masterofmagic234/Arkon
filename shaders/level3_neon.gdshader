shader_type canvas_item;
render_mode unshaded;
uniform vec4 neon_color : source_color = vec4(0.30,0.90,1.0,1.0);
uniform float phase = 0.0;
void fragment(){
    float pulse = 0.92+0.06*sin(TIME*1.4+phase)+0.02*sin(TIME*8.1+phase);
    COLOR *= neon_color*vec4(vec3(pulse),1.0);
}
