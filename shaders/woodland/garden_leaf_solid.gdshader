shader_type spatial;
render_mode cull_back;
#include "res://shaders/woodland/garden_color.gdshaderinc"
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
// Real geometry bounds the leaf/branch interior. No alpha lookup or discard:
// the GPU can reject hidden interiors before running fragment shading.
void fragment() {
    ALBEDO = texture(atlas, UV).rgb * COLOR.rgb * (OUTPUT_IS_SRGB ? vec3(1.0) : vec3(.62, .76, .62));
    ROUGHNESS = .92;
    BACKLIGHT = vec3(.17, .20, .08);
}
