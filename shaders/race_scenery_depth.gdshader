shader_type spatial;
render_mode unshaded,depth_draw_always,cull_disabled,fog_disabled;
uniform vec2 logical_size=vec2(1280.0,496.0);
uniform bool ground_mesh=false;
uniform sampler2D coverage_texture : filter_linear, repeat_disable;
uniform vec3 canvas_to_viewport_x=vec3(1.0,0.0,0.0);
uniform vec3 canvas_to_viewport_y=vec3(0.0,1.0,0.0);
uniform vec4 airframe_rect=vec4(0.0,0.0,1280.0,496.0);
varying float reciprocal_depth;
varying vec4 coverage_color;
varying vec2 pixel;
void vertex() {
    reciprocal_depth=ground_mesh ? UV.y : VERTEX.z;
    coverage_color=COLOR;
    vec3 canvas=vec3(VERTEX.xy,1.0);
    pixel=vec2(dot(canvas_to_viewport_x,canvas),dot(canvas_to_viewport_y,canvas));
    vec2 ndc=vec2(pixel.x/logical_size.x*2.0-1.0,1.0-pixel.y/logical_size.y*2.0);
    ndc.y*=sign(PROJECTION_MATRIX[1][1]);
    // Hardware depth is affine in reciprocal camera depth. W=1 preserves the
    // source's already projected UV/depth interpolation in screen space.
    vec4 projected=PROJECTION_MATRIX*vec4(0.0,0.0,-(1.0/max(reciprocal_depth,0.000001)+0.05),1.0);
    POSITION=vec4(ndc,projected.z/projected.w,1.0);
}
void fragment() {
    if (reciprocal_depth<=0.0 || pixel.x<airframe_rect.x || pixel.y<airframe_rect.y || pixel.x>airframe_rect.z || pixel.y>airframe_rect.w) discard;
    if (!ground_mesh && texture(coverage_texture,UV).a*coverage_color.a<0.35) discard;
    // Preserve existing cars/colors; write only the real shared depth.
    ALBEDO=vec3(0.0);
    ALPHA=0.0;
}
