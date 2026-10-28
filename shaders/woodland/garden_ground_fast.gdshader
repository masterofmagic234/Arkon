shader_type spatial;
// Terrain already has baked indirect light. Its two-metre grid is fine enough
// for broad moon/lantern gradients; avoid full PBR lighting for every grass pixel.
render_mode vertex_lighting, diffuse_lambert, specular_disabled;
uniform sampler2D grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil : source_color, filter_linear_mipmap, repeat_enable;
varying vec2 world_uv;
varying float soil_blend;
void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_uv = p.xz;
    soil_blend = sin(p.x * .13) * cos(p.z * .17) * .06 + .14;
}
void fragment() {
    // The night garden permits a cheap colour-space blend instead of two
    // gamma decodes and a fragment pow. Authored textures and scale stay intact.
    ALBEDO = mix(texture(grass, world_uv * .28).rgb,
        texture(soil, world_uv * .18).rgb, soil_blend) * COLOR.rgb;
    ROUGHNESS = .96;
    SPECULAR = 0.0;
}
