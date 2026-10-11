shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D floor_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 albedo_tint : source_color = vec3(0.82, 0.88, 0.98);
uniform vec3 emission_color : source_color = vec3(0.42, 0.52, 0.72);
uniform float emission_energy = 0.62;
uniform float uv_scale = 0.22;

varying vec2 world_xz;

void vertex() {
    world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    vec3 tex = texture(floor_tex, world_xz * uv_scale).rgb;
    ALBEDO = tex * albedo_tint;
    EMISSION = tex * emission_color * emission_energy;
}
