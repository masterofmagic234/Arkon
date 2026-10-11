shader_type spatial;
render_mode cull_back;
uniform sampler2D masonry_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.82,0.87,0.89);
uniform float tile_metres = 2.8;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
    world_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    vec3 n = abs(world_normal);
    vec2 p = n.x>n.z ? world_pos.zy : world_pos.xy;
    if (n.y>max(n.x,n.z)) p=world_pos.xz;
    vec3 stone = texture(masonry_tex,p/tile_metres).rgb;
    float damp = 1.0-smoothstep(0.0,0.65,world_pos.y);
    ALBEDO = stone*tint*mix(1.0,0.70,damp);
    ROUGHNESS = mix(0.92,0.75,damp);
    SPECULAR = 0.18;
}
