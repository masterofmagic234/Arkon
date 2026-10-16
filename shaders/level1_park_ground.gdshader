shader_type spatial;
render_mode cull_back;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.73, 0.82, 0.73);
uniform float tile_metres = 2.6;
varying vec2 world_xz;
varying float meadow;
void vertex() {
    world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    meadow = sin(world_xz.x*0.21+sin(world_xz.y*0.13))*sin(world_xz.y*0.18-world_xz.x*0.07);
}
void fragment() {
    // One anisotropic mipmapped sample; slow world-space variation breaks up
    // repetition without baking a different light field into every patch.
    vec3 grass = texture(ground_tex, world_xz / tile_metres).rgb;
    ALBEDO = grass*tint*(0.96+meadow*0.07);
    ROUGHNESS = 0.96;
    SPECULAR = 0.10;
}
