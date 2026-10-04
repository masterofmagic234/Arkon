shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 triplanar_scale = vec3(0.4);
uniform vec3 emission_tint = vec3(0.72, 0.80, 1.0);
uniform float emission_energy = 1.15;
uniform float ao_strength = 0.58;
uniform float ao_height = 0.72;

varying vec3 world_pos;
varying vec3 world_normal;

vec3 sample_triplanar(vec3 p, vec3 n) {
    vec3 weights = pow(abs(n), vec3(4.0));
    weights /= max(dot(weights, vec3(1.0)), 0.0001);

    vec2 uv_x = p.zy;
    vec2 uv_y = p.xz;
    vec2 uv_z = p.xy;

    vec3 sample_x = texture(albedo_tex, uv_x).rgb;
    vec3 sample_y = texture(albedo_tex, uv_y).rgb;
    vec3 sample_z = texture(albedo_tex, uv_z).rgb;

    return sample_x * weights.x + sample_y * weights.y + sample_z * weights.z;
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec3 base = sample_triplanar(world_pos * triplanar_scale, world_normal);

    // Artistic contact AO: the wall darkens into the floor over its lowest
    // 72 cm, softening the hard 90-degree floor/wall junction.
    float base_fade = smoothstep(0.0, ao_height, max(world_pos.y, 0.0));
    float ao_factor = mix(1.0 - ao_strength, 1.0, base_fade);

    ALBEDO = base * ao_factor;
    ROUGHNESS = 1.0;
    EMISSION = base * emission_tint * emission_energy * ao_factor;
}
