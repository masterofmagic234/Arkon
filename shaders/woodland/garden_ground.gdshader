shader_type spatial;
#include "res://shaders/woodland/garden_color.gdshaderinc"
uniform sampler2D grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec3 g = garden_to_linear(texture(grass, world_position.xz * .28).rgb);
    vec3 s = garden_to_linear(texture(soil, world_position.xz * .18).rgb);
    float n = sin(world_position.x * .13) * cos(world_position.z * .17) * .06 + .14;
    ALBEDO = garden_from_linear(mix(g, s, n) * COLOR.rgb);
    ROUGHNESS = .96;
}
