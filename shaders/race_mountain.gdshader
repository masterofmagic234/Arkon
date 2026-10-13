shader_type canvas_item;
render_mode unshaded;
uniform vec2 logical_size=vec2(1280.0,720.0);
uniform vec2 pivot=vec2(640.0,248.0);
uniform float focal=806.4;
uniform float camera_x=0.0;
uniform float camera_z=0.0;
uniform float camera_yaw=0.0;
uniform float camera_roll=0.0;
uniform sampler2D bank_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec4 rock_tint;
void vertex() { rock_tint=COLOR; }
void fragment() {
    float depth=1.0/max(UV.y,.00001);
    vec2 p=SCREEN_UV*logical_size-pivot;
    float cr=cos(camera_roll),sr=sin(camera_roll);
    p=mat2(vec2(cr,sr),vec2(-sr,cr))*p;
    float c=cos(camera_yaw),s=sin(camera_yaw);
    float across=p.x*depth/focal;
    float world_x=camera_x+across*c+depth*s;
    float world_z=camera_z+depth*c-across*s;
    float world_y=UV.x/max(UV.y,.00001);
    vec3 surface;
    if (rock_tint.g>rock_tint.r*1.25) {
        surface=texture(bank_grass,vec2(world_x,world_z)/2.6).rgb;
    } else {
        surface=texture(TEXTURE,vec2(world_x,world_y)*.16).rgb;
    }
    vec3 color=surface*rock_tint.rgb*1.65;
    float mist=smoothstep(650.0,2100.0,depth);
    COLOR=vec4(mix(color,vec3(.12,.19,.23),mist*.90),rock_tint.a);
}
