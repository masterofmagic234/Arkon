// Adult garment only. The child's pajamas, skin, burgundy hair and room stay intact.
float garment_triangle151(vec2 p, vec2 a, vec2 b, vec2 c) {
    float area = (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x);
    if (abs(area) < .0000001) { return 0.0; }
    float x = (p.x-b.x)*(a.y-b.y)-(a.x-b.x)*(p.y-b.y);
    float y = (p.x-c.x)*(b.y-c.y)-(b.x-c.x)*(p.y-c.y);
    float z = (p.x-a.x)*(c.y-a.y)-(c.x-a.x)*(p.y-a.y);
    return ((x >= 0.0 && y >= 0.0 && z >= 0.0) || (x <= 0.0 && y <= 0.0 && z <= 0.0)) ? 1.0 : 0.0;
}
uniform vec2 garment_outline[12];
uniform vec2 cuff_outline[4];
uniform vec4 face_guard = vec4(0.0);
uniform vec4 arm_guard = vec4(0.0);
float garment_region151(vec2 uv, float seated) {
    bool inside = false;
    for (int i = 0; i < 12; i++) {
        vec2 a = garment_outline[i];
        vec2 b = garment_outline[(i+1)%12];
        if ((a.y > uv.y) != (b.y > uv.y)) {
            float crossing = (b.x-a.x)*(uv.y-a.y)/(b.y-a.y)+a.x;
            if (uv.x < crossing) { inside = !inside; }
        }
    }
    return inside ? 1.0 : 0.0;
}
vec3 garment_colour151(vec2 uv, vec3 colour, float seated) {
    float pink = smoothstep(.020,.065,colour.b-colour.g)
               * smoothstep(.035,.12,colour.r-colour.g)
               * smoothstep(.14,.30,max(colour.r,colour.b))
               * smoothstep(.52,.58,colour.b/max(colour.r,.001));
    float cuff = max(garment_triangle151(uv,cuff_outline[0],cuff_outline[1],cuff_outline[2]),
                     garment_triangle151(uv,cuff_outline[0],cuff_outline[2],cuff_outline[3]));
    // Lit cuff cloth has less blue than the shirt's shaded pink. Its own small
    // tracked band keeps this wider chroma range away from face and bare arms.
    float warm_cloth = smoothstep(-.06,-.032,colour.b-colour.g);
    float amount = max(garment_region151(uv,seated)*pink,cuff*warm_cloth);
    if (face_guard.z > .0001 && face_guard.w > .0001) {
        float face = length((uv-face_guard.xy)/face_guard.zw);
        amount *= smoothstep(1.0,1.06,face);
    }
    vec2 arm_start = arm_guard.xy*vec2(1280.0,720.0);
    vec2 arm_end = arm_guard.zw*vec2(1280.0,720.0);
    vec2 arm_delta = arm_end-arm_start;
    float arm_length_squared = dot(arm_delta,arm_delta);
    if (arm_length_squared > .01) {
        vec2 point = uv*vec2(1280.0,720.0);
        float along = clamp(dot(point-arm_start,arm_delta)/arm_length_squared,0.0,1.0);
        float distance_to_arm = length(point-arm_start-arm_delta*along);
        amount *= smoothstep(9.0,10.0,distance_to_arm);
    }
    float lightness = dot(colour,vec3(.2126,.7152,.0722));
    vec3 charcoal = vec3(.46,.40,.53)*lightness;
    vec2 tile = fract(uv*vec2(78.0,46.0))-.5;
    float crescent = (1.0-smoothstep(.16,.19,length(tile)))
                   * smoothstep(.14,.17,length(tile-vec2(.075,-.035)));
    charcoal += vec3(.42,.38,.48)*crescent*.075;
    return mix(colour,charcoal,amount);
}
