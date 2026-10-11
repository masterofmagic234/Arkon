shader_type spatial;
render_mode cull_back;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 world_xz;
void vertex() { world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
    vec3 detail=texture(ground_tex,world_xz*0.14).rgb;
    float grain=dot(detail,vec3(0.30,0.59,0.11));
    float edge=smoothstep(0.0,0.13,UV.x)*smoothstep(0.0,0.13,1.0-UV.x);
    vec3 gravel=vec3(0.34,0.295,0.225)*(0.58+grain*1.7);
    ALBEDO=mix(detail*vec3(0.74,0.82,0.72),gravel,edge);
    ROUGHNESS=0.96;
    SPECULAR=0.12;
}
