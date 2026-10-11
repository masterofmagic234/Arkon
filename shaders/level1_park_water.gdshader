shader_type spatial;
render_mode cull_disabled;
uniform sampler2D panorama : source_color, filter_linear_mipmap;
uniform vec3 moon_direction = vec3(-0.40,0.40,-0.825);
uniform vec3 lantern_positions[4];
varying vec3 world_pos;
void vertex() {
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.y+=sin(world_pos.x*2.1+TIME*0.72)*sin(world_pos.z*1.7-TIME*0.51)*0.009;
}
void fragment() {
    vec2 p=world_pos.xz;
    float a=p.x*2.1+TIME*0.72;
    float b=p.y*1.7-TIME*0.51;
    float dx=cos(a)*sin(b)*0.040+cos(p.x*5.2+p.y*3.8-TIME)*0.018;
    float dz=sin(a)*cos(b)*0.032+cos(p.x*5.2+p.y*3.8-TIME)*0.013;
    vec3 normal_world=normalize(vec3(-dx,1.0,-dz));
    vec3 eye=normalize(INV_VIEW_MATRIX[3].xyz-world_pos);
    vec3 reflected=reflect(-eye,normal_world);
    vec2 sky_uv=vec2(atan(reflected.x,reflected.z)/6.2831853+0.5,acos(clamp(reflected.y,-1.0,1.0))/3.1415927);
    vec3 sky=texture(panorama,sky_uv).rgb;
    float fresnel=pow(1.0-max(dot(eye,normal_world),0.0),3.0);
    float alignment=max(dot(reflected,normalize(moon_direction)),0.0);
    float moon=pow(alignment,180.0)+pow(alignment,42.0)*0.13;
    float shimmer=0.86+0.14*sin(p.x*9.5+p.y*14.0+TIME*1.3);
    float shore=pow(1.0-COLOR.r,15.0);
    vec3 depth=mix(vec3(0.028,0.092,0.135),vec3(0.045,0.105,0.098),shore);
    ALBEDO=depth;
    float lamplight=0.0;
    for (int i=0;i<4;i++) {
        vec3 to_lamp=lantern_positions[i]-world_pos;
        float highlight=max(dot(reflected,normalize(to_lamp)),0.0);
        lamplight+=pow(highlight,220.0)*max(1.0-length(to_lamp)/18.0,0.0);
    }
    EMISSION=depth*0.22+sky*(0.12+fresnel*0.36)+vec3(0.65,0.76,0.94)*moon*shimmer*1.65+vec3(1.0,0.63,0.25)*lamplight*shimmer*1.4;
    NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
    ROUGHNESS=0.19+shore*0.12;
    METALLIC=0.18;
    SPECULAR=0.7;
}
