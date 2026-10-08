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
    // MapWall meshes are BoxMesh instances with axis-aligned face normals.
    // Pick the dominant axis directly instead of sampling all three projections.
    vec3 an = abs(n);
    if (an.y > an.x && an.y > an.z) {
        return texture(albedo_tex, p.xz).rgb;
    } else if (an.x > an.z) {
        return texture(albedo_tex, vec2(p.z, -p.y)).rgb;
    }
    return texture(albedo_tex, vec2(p.x, -p.y)).rgb;
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
