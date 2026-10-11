shader_type spatial;
render_mode cull_back;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.35,0.57,0.38);
uniform bool golden = false;
varying float variation;
void vertex() {
    float a = sin(VERTEX.x*14.0+VERTEX.z*9.0)*cos(VERTEX.y*11.0-VERTEX.x*8.0);
    VERTEX += NORMAL*a*0.075;
    variation = 0.88+a*0.14;
}
void fragment() {
    // Sample only the original oak's crown, excluding its trunk and roots.
    vec4 paint = texture(leaf_tex,vec2(mix(0.07,0.93,UV.x),mix(0.04,0.54,UV.y)));
    vec3 leaves = mix(vec3(0.07,0.15,0.09),paint.rgb,paint.a);
    if (golden) {
        float lightness = dot(leaves,vec3(0.30,0.59,0.11));
        leaves = mix(leaves,vec3(lightness*1.65,lightness*1.02,lightness*0.27),0.90);
    }
    ALBEDO = leaves*tint*variation;
    ROUGHNESS = 1.0;
    SPECULAR = 0.1;
}
