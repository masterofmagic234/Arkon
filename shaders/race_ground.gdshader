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
uniform vec4 rival_lights[3];
uniform float bridge_start=2080.0;
uniform float bridge_end=2720.0;
uniform float tunnel_start=3280.0;
uniform float tunnel_end=4080.0;
float headlamp(vec2 world,vec2 source,float yaw) {
    vec2 delta=world-source;
    float forward_=dot(delta,vec2(sin(yaw),cos(yaw)));
    float side=dot(delta,vec2(cos(yaw),-sin(yaw)));
    float beam=exp(-pow(side/max(.8+forward_*.14,.5),2.0));
    return beam*smoothstep(1.4,4.0,forward_)*(1.0-smoothstep(10.0,36.0,forward_));
}
void fragment() {
    vec2 p=SCREEN_UV*logical_size-vec2(logical_size.x*.5,horizon);
    float cr=cos(camera_roll),sr=sin(camera_roll);
    p=mat2(vec2(cr,sr),vec2(-sr,cr))*p;
    // Interpolated inverse depth remains valid on an elevated ground triangle.
    // Inverting a flat screen Y incorrectly stretches textures on hills.
    float depth=1.0/max(UV.y,0.00001);
    float across=p.x*depth/focal;
    float c=cos(camera_yaw),s=sin(camera_yaw);
    vec2 world=origin+vec2(across*c+depth*s,depth*c-across*s);
    float fog=smoothstep(80.0,950.0,depth);
    float field=smoothstep(930.0,980.0,world.y)*(1.0-smoothstep(bridge_start-30.0,bridge_start,world.y));
    float bridge=step(bridge_start,world.y)*(1.0-step(bridge_end,world.y));
    float tunnel=step(tunnel_start,world.y)*(1.0-step(tunnel_end,world.y));
    float city=smoothstep(tunnel_end,tunnel_end+130.0,world.y);
    vec3 color;
    if (meadow) {
        vec3 grass=texture(TEXTURE,world/2.6).rgb;
        color=grass*mix(vec3(.44,.60,.49),vec3(.75,.64,.34),field);
        float furrow=.82+.18*sin(world.x*3.4+sin(world.y*.009)*.25);
        color*=mix(1.0,furrow,field);
        vec3 water=vec3(.065,.145,.205);
        float ripple=sin(world.x*1.1+world.y*.28+TIME*.8)*sin(world.x*.7-world.y*.17-TIME*.5);
        float moon=pow(max(0.0,1.0-abs(world.x-11.0)/32.0),6.0);
        water+=vec3(.10,.16,.19)*moon*(.65+.35*ripple);
        water+=vec3(.035,.060,.072)*smoothstep(.6,.97,ripple);
        color=mix(color,water,bridge);
        color=mix(color,vec3(.038,.063,.073),tunnel);
        color=mix(color,grass*vec3(.40,.54,.43),city);
        color=mix(color,mix(vec3(.09,.15,.20),vec3(.018,.026,.030),tunnel),fog*.87);
    } else {
        float lateral=UV.x/max(UV.y,0.00001);
        color=texture(TEXTURE,vec2(lateral,world.y)/2.5).rgb*vec3(.43,.49,.56);
        float antialias=max(fwidth(lateral),.012);
        float edge=1.0-smoothstep(.035,.035+antialias,abs(abs(lateral)-4.34));
        float centre=1.0-smoothstep(.045,.045+antialias,abs(lateral));
        float dash=1.0-smoothstep(5.0,5.0+max(fwidth(world.y),.05),mod(world.y,16.0));
        color=mix(color,vec3(.64,.68,.63),max(edge,centre*dash));
        if (abs(lateral)>4.5) color=mix(vec3(.12,.16,.18),vec3(.34,.30,.25),step(2.5,mod(world.y,5.0)));
        float lamp=headlamp(world,car_position,car_yaw);
        for (int i=0;i<3;i++) lamp+=headlamp(world,rival_lights[i].xy,rival_lights[i].z)*rival_lights[i].w*.8;
        color+=vec3(.18,.18,.14)*min(lamp,1.6);
        float tunnel_lamp=pow(.5+.5*cos(world.y*6.283185/16.0),6.0);
        color+=vec3(.11,.078,.034)*tunnel*tunnel_lamp;
        float city_lamp=pow(.5+.5*cos(world.y*6.283185/48.0),8.0);
        color+=vec3(.04,.047,.043)*city*city_lamp;
        color=mix(color,mix(vec3(.09,.15,.20),vec3(.018,.026,.030),tunnel),fog*.88);
    }
    COLOR=vec4(color,1.0);
}
