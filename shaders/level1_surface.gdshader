shader_type spatial;
render_mode cull_back;
uniform sampler2D detail_tex : source_color, repeat_enable;
uniform vec3 tint : source_color = vec3(0.35,0.39,0.41);
uniform bool wood = false;
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
    vec3 detail = texture(detail_tex,coords*0.32).rgb;
    float grain = dot(detail,vec3(0.30,0.59,0.11));
    vec3 color = tint*(0.55+grain*1.8);
    if (wood) {
        float groove = pow(abs(sin(UV.x*106.8+grain*2.3)),6.0);
        color *= 0.80+groove*0.35;
    } else {
        float lichen = smoothstep(0.24,0.37,grain)*0.24;
        color = mix(color,vec3(0.15,0.23,0.12),lichen);
    }
    ALBEDO = color;
    ROUGHNESS = 0.95;
}
