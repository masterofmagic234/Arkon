shader_type canvas_item;
render_mode unshaded;
uniform bool meadow=false;
uniform vec2 logical_size=vec2(1280.0,720.0);
uniform float horizon=248.0;
uniform float vertical_scale=1488.0;
uniform float focal=806.4;
uniform float camera_yaw=0.0;
uniform float camera_roll=0.0;
uniform vec2 origin=vec2(0.0);
uniform vec2 car_position=vec2(0.0);
uniform float car_yaw=0.0;
void fragment() {
    vec2 p=SCREEN_UV*logical_size-vec2(logical_size.x*.5,horizon);
    float cr=cos(camera_roll),sr=sin(camera_roll);
    p=mat2(vec2(cr,sr),vec2(-sr,cr))*p;
    float depth=vertical_scale/max(p.y,0.001);
    float across=p.x*depth/focal;
    float c=cos(camera_yaw),s=sin(camera_yaw);
    vec2 world=origin+vec2(across*c+depth*s,depth*c-across*s);
    float fog=smoothstep(80.0,950.0,depth);
    vec3 color;
    if (meadow) {
        color=texture(TEXTURE,world/2.6).rgb*vec3(.40,.48,.37);
        color=mix(color,vec3(.074,.12,.16),fog*.94);
    } else {
        float lateral=UV.x/max(UV.y,0.00001);
        color=texture(TEXTURE,vec2(lateral,world.y)/2.5).rgb*vec3(.43,.49,.56);
        float antialias=max(fwidth(lateral),.012);
        float edge=1.0-smoothstep(.035,.035+antialias,abs(abs(lateral)-4.34));
        float centre=1.0-smoothstep(.045,.045+antialias,abs(lateral));
        float dash=1.0-smoothstep(5.0,5.0+max(fwidth(world.y),.05),mod(world.y,16.0));
        color=mix(color,vec3(.58,.62,.60),max(edge,centre*dash));
        if (abs(lateral)>4.5) color=mix(vec3(.12,.16,.18),vec3(.34,.30,.25),step(2.5,mod(world.y,5.0)));
        vec2 delta=world-car_position;
        float forward_=dot(delta,vec2(sin(car_yaw),cos(car_yaw)));
        float sideways=dot(delta,vec2(cos(car_yaw),-sin(car_yaw)));
        float beam=exp(-pow(sideways/max(.8+forward_*.14,.5),2.0));
        beam*=smoothstep(1.4,4.0,forward_)*(1.0-smoothstep(8.0,32.0,forward_));
        color+=vec3(.17,.16,.11)*beam;
        color=mix(color,vec3(.074,.12,.16),fog*.88);
    }
    COLOR=vec4(color,1.0);
}
