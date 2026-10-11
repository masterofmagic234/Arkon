shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool golden = false;
void vertex() {
    vec3 world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    float flutter = sin(world.x*1.6+world.z*0.8+TIME*2.5);
    VERTEX.x += flutter*0.024*UV.y;
    VERTEX.z += flutter*0.016*UV.y;
}
void fragment() {
    vec4 leaf = texture(leaf_tex,UV);
    vec3 color = leaf.rgb;
    if (golden) color = vec3(0.96,0.70,0.28)*dot(color,vec3(0.30,0.59,0.11))*1.85;
    ALBEDO = color*vec3(0.92,0.98,0.91);
    ALPHA = leaf.a;
    ALPHA_SCISSOR_THRESHOLD = 0.48;
    ROUGHNESS = 0.86;
    SPECULAR = 0.18;
    BACKLIGHT = vec3(0.13);
}
