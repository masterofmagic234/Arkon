shader_type spatial;
render_mode cull_disabled;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 wet_color : source_color = vec3(0.095,0.13,0.085);
varying vec2 world_xz;
void vertex() { world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
    NORMAL=normalize((VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz);
    float meadow=sin(world_xz.x*0.21+sin(world_xz.y*0.13))*sin(world_xz.y*0.18-world_xz.x*0.07);
    vec3 grass=texture(ground_tex,world_xz/2.6).rgb*vec3(0.73,0.82,0.73)*(0.96+meadow*0.07);
    float grain=dot(grass,vec3(0.30,0.59,0.11));
    vec3 wet=wet_color*(0.60+grain*2.0);
    ALBEDO=mix(wet,grass,smoothstep(0.15,0.92,COLOR.r));
    ROUGHNESS=mix(0.72,0.94,COLOR.r);
    SPECULAR=0.13;
}
