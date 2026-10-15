shader_type spatial;
render_mode cull_back, vertex_lighting;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D baked_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint : source_color = vec3(0.82,0.93,0.83);
uniform bool golden = false;
uniform vec3 golden_tint : source_color = vec3(0.95,0.66,0.23);
varying vec3 leaf_position;
varying vec3 leaf_normal;
varying float variation;
varying float detail_fade;
void vertex() {
    vec3 world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    float sway = sin(dot(world.xz,vec2(0.14,0.19))+TIME*1.15);
    VERTEX.x += sway*0.003;
    VERTEX.z += sway*0.002;
    // World-space triplanar leaves keep a physical scale and remove the
    // pinched UV poles visible when looking up into an oak crown.
    leaf_position = world/1.25;
    leaf_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
    detail_fade=smoothstep(9.0,18.0,length(world-INV_VIEW_MATRIX[3].xyz));
    variation = 0.93+0.055*sin(world.x*1.9+world.z*1.4)+0.07*NORMAL.y;
}
void fragment() {
    vec3 leaf;
    if (detail_fade>.995) {
        leaf=texture(baked_tex,UV).rgb;
    } else {
        vec3 weights=abs(leaf_normal);
        weights*=weights;weights*=weights;
        weights/=max(dot(weights,vec3(1.0)),.0001);
        leaf=texture(leaf_tex,leaf_position.zy).rgb*weights.x;
        leaf+=texture(leaf_tex,leaf_position.xz).rgb*weights.y;
        leaf+=texture(leaf_tex,leaf_position.xy).rgb*weights.z;
        if (detail_fade>.005) leaf=mix(leaf,texture(baked_tex,UV).rgb,detail_fade);
    }
    if (golden) leaf = golden_tint*dot(leaf,vec3(0.30,0.59,0.11))*1.8;
    ALBEDO = leaf*tint*variation;
    ROUGHNESS = 0.88;
    SPECULAR = 0.16;
    BACKLIGHT = vec3(0.08);
}
