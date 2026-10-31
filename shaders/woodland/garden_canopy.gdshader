shader_type spatial;
// Binary cutouts still write real depth. Drawing canopy color after the opaque
// AO pass avoids rasterizing its overlapping cards into the normal buffer.
// A separate masked, shadow-only instance preserves every original sun shadow.
render_mode cull_back, depth_draw_always;
#include "res://shaders/woodland/garden_color.gdshaderinc"
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
// Preserve the imported alpha channel and all mip levels, but let depth and
// normal variants fetch one channel instead of decoding the color block too.
uniform sampler2D alpha_mask : filter_linear_mipmap_anisotropic;
void fragment() {
    float coverage = texture(alpha_mask, UV).r;
    if (coverage < .38) discard;
    vec4 c = texture(atlas, UV);
    ALBEDO = c.rgb * COLOR.rgb * (OUTPUT_IS_SRGB ? vec3(1.0) : vec3(.62, .76, .62));
    ALPHA = 1.0;
    ROUGHNESS = .92;
    BACKLIGHT = vec3(.17, .20, .08);
}
