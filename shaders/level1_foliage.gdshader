shader_type spatial;
render_mode cull_back;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.35,0.57,0.38);
varying float variation;
void vertex() {
    float a = sin(VERTEX.x*14.0+VERTEX.z*9.0)*cos(VERTEX.y*11.0-VERTEX.x*8.0);
    VERTEX += NORMAL*a*0.075;
    variation = 0.88+a*0.14;
}
void fragment() {
    vec3 texture_color = texture(leaf_tex,UV*2.0).rgb;
    ALBEDO = mix(tint,tint*texture_color*2.3,0.65)*variation;
    ROUGHNESS = 1.0;
    SPECULAR = 0.1;
}
