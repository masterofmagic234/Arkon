shader_type spatial;
render_mode cull_back;
varying vec2 world_xz;
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
    float ripple = sin(world_xz.x * 3.2 + TIME * 1.4) * sin(world_xz.y * 2.4 - TIME * 0.9);
    float glint = pow(max(0.0, sin(world_xz.x * 0.8 + world_xz.y * 3.4 + TIME * 0.6)), 24.0);
    ALBEDO = mix(vec3(0.025, 0.085, 0.12), vec3(0.11, 0.22, 0.29), ripple * 0.5 + 0.5);
    EMISSION = vec3(0.22, 0.36, 0.46) * glint * 0.28;
    NORMAL_MAP = normalize(vec3(ripple * 0.14 + 0.5, 0.5, 1.0));
    ROUGHNESS = 0.25;
    METALLIC = 0.32;
    SPECULAR = 0.65;
}
