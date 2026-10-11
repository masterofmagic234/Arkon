shader_type spatial;
render_mode cull_back;
uniform sampler2D surface_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.80,0.87,0.80);
uniform float texture_scale = 0.36;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
    vec3 n = abs(normalize(world_normal));
    vec2 coords = n.x>n.z ? world_pos.zy : world_pos.xy;
    if (n.y>max(n.x,n.z)) coords = world_pos.xz;
    ALBEDO = texture(surface_tex,coords*texture_scale).rgb*tint;
    ROUGHNESS = 0.96;
    SPECULAR = 0.12;
}
