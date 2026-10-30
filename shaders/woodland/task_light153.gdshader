shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
    float radius = length(UV * 2.0 - 1.0);
    float falloff = pow(max(0.0, 1.0 - radius), 2.0);
    ALBEDO = tint.rgb;
    ALPHA = tint.a * falloff;
}
