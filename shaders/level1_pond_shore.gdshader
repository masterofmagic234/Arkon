shader_type spatial;
render_mode cull_disabled;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 world_xz;
void vertex() { world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
    NORMAL=normalize((VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz);
    vec3 grass=texture(ground_tex,world_xz*0.14).rgb*vec3(0.74,0.82,0.72);
    float grain=dot(grass,vec3(0.30,0.59,0.11));
    vec3 wet=vec3(0.095,0.13,0.085)*(0.60+grain*2.0);
    ALBEDO=mix(wet,grass,smoothstep(0.15,0.92,COLOR.r));
    ROUGHNESS=mix(0.72,0.94,COLOR.r);
    SPECULAR=0.13;
}
