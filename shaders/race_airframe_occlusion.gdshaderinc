uniform sampler2D scenery_depth : filter_nearest, repeat_disable;
uniform bool scenery_depth_enabled=false;
uniform vec2 logical_size=vec2(1280.0,496.0);
uniform vec3 viewport_to_canvas_x=vec3(1.0,0.0,0.0);
uniform vec3 viewport_to_canvas_y=vec3(0.0,1.0,0.0);
bool scenery_hides_airframe(vec2 uv,float camera_depth) {
    if (!scenery_depth_enabled || camera_depth<=0.0) return false;
    vec3 pixel=vec3(uv*logical_size,1.0);
    vec2 canvas=vec2(dot(viewport_to_canvas_x,pixel),dot(viewport_to_canvas_y,pixel))/logical_size;
    if (any(lessThan(canvas,vec2(0.0))) || any(greaterThan(canvas,vec2(1.0)))) return false;
    vec3 bytes=floor(texture(scenery_depth,canvas).rgb*255.0+0.5);
    float foreground=dot(bytes,vec3(65536.0,256.0,1.0))/16777215.0;
    return foreground>0.8/max(camera_depth-0.05,0.01);
}
