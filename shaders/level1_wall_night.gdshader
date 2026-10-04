shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 emission_tint = vec3(0.72, 0.80, 1.0);
uniform float emission_energy = 1.15;
uniform float ao_strength = 0.58;
uniform float ao_height = 0.72;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Keep the BoxMesh's authored UVs. The previous hand-built triplanar
    // projection changed the wall texture orientation; AO must not change UVs.
    vec4 texel = texture(albedo_tex, UV);

    // Artistic contact AO: darken only the lowest part of the wall where it
    // meets the floor, then fade smoothly into the original wall texture.
    float wall_from_floor = smoothstep(0.0, ao_height, max(world_pos.y, 0.0));
    float ao_factor = mix(1.0 - ao_strength, 1.0, wall_from_floor);

    ALBEDO = texel.rgb * ao_factor;
    ROUGHNESS = 1.0;

    // Feed the same authored bright pixels into the global Level 1 glow.
    EMISSION = texel.rgb * emission_tint * emission_energy;
}
