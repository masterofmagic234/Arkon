shader_type spatial;
render_mode cull_back, unshaded, specular_disabled;
#include "res://shaders/woodland/garden_color.gdshaderinc"
uniform sampler2D panorama : filter_linear_mipmap, repeat_enable;
uniform float stream_mode=0.0;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    vec2 p=world_position.xz;
    float a=p.x*2.7+p.y*1.9+TIME*(.45+stream_mode*2.0);
    float b=p.x*-1.4+p.y*3.6-TIME*.43;
    vec3 n=normalize(vec3(-cos(a)*.045+cos(b)*.022,1.0,-cos(a)*.032-cos(b)*.057));
    vec3 view=normalize(CAMERA_POSITION_WORLD-world_position);
    vec3 ray=reflect(-view,n);
    vec3 sky=mix(vec3(.045,.067,.11),vec3(.012,.023,.058),clamp(ray.y,0.0,1.0));
    float moon=pow(max(dot(ray,normalize(vec3(-.48,.64,-.59))),0.0),170.0);
    float fresnel=pow(1.0-max(dot(n,view),0.0),5.0);
    vec3 water=mix(vec3(.012,.045,.050),sky,.18+.66*fresnel);
    water+=vec3(.10,.13,.17)*moon;
    float ripple=sin(a)*sin(b)*.5+.5;
    water+=vec3(.003,.006,.009)*ripple;
    // Narrow channels get moving pale ripples, not a flat turquoise slab.
    water+=vec3(.026,.036,.039)*stream_mode*pow(max(sin(p.y*1.8-TIME*4.2),0.0),14.0);
    ALBEDO=garden_from_linear(water);
}
