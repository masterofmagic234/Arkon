shader_type canvas_item;
render_mode unshaded;

// The original diner art supplies a connected body and eight authored poses.
// Original pixels and authored gait remain the source. The unarmed atlas has
// very broad shoulders; narrow those while retaining the native crown size.
uniform float horizontal_frames = 8.0;
uniform bool hide_conventional_rifle = false;
uniform bool original_overhead_head = true;
uniform vec2 authored_head_center = vec2(21.5,16.0);
uniform float shoulder_width = 1.0;
varying vec4 vertex_tint;

void vertex() {
    vertex_tint = COLOR;
}

void fragment() {
    vec2 sheet_size = vec2(textureSize(TEXTURE,0));
    vec2 cell = vec2(fract(UV.x*horizontal_frames)*sheet_size.x/horizontal_frames,UV.y*sheet_size.y);
    vec2 source_uv = UV;
    if (horizontal_frames==8.0) {
        float crown = 1.0-smoothstep(4.0,6.0,length((cell-authored_head_center)*vec2(1.0,1.1)));
        float width = mix(shoulder_width,1.0,crown);
        cell.y = authored_head_center.y+(cell.y-authored_head_center.y)/width;
        source_uv.y = cell.y/sheet_size.y;
    }
    vec4 ink = texture(TEXTURE,source_uv);
    if (source_uv.y<0.0 || source_uv.y>1.0) ink.a=0.0;
    // Remove only the embedded conventional rifle's dark pixels. The painted
    // fingers/sleeves remain, and the actual cone weapon supplies the barrel.
    if (hide_conventional_rifle && cell.x>=30.0 && cell.y>=15.0 && cell.y<22.0 && max(ink.r,max(ink.g,ink.b))<0.28) ink.a=0.0;
    float lo=min(ink.r,min(ink.g,ink.b));
    float hi=max(ink.r,max(ink.g,ink.b));
    bool skin = ink.r>0.70 && ink.g>0.35 && ink.b>0.10 && ink.r>ink.g*1.05;
    vec2 head_pixel = cell-authored_head_center;
    if (original_overhead_head && skin && abs(head_pixel.x)<4.6 && abs(head_pixel.y)<3.6) {
        // Retain the actual HM head contour. The top of the head is hair, not
        // a front-facing red portrait. A small forward skin edge is the nose.
        if (!(head_pixel.x>2.6 && abs(head_pixel.y)<0.8)) {
            // Dark centre-part roots with wine-red lengths. At the production
            // zoom this has to read as red hair, not a grey/black helmet.
            ink.rgb=vec3(0.17,0.055,0.085);
            if (head_pixel.x< -1.4) ink.rgb=vec3(0.66,0.12,0.20);
            else if (head_pixel.y>0.6) ink.rgb=vec3(0.48,0.075,0.145);
            else if (head_pixel.x<0.6 && head_pixel.y< -0.8) ink.rgb=vec3(0.37,0.065,0.12);
            if (head_pixel.x< -2.4 && head_pixel.y>0.6) ink.rgb=vec3(0.82,0.23,0.28);
        }
    } else if (abs(ink.r-ink.g)<0.025 && ink.r>0.30 && ink.b<0.10) {
        ink.rgb=mix(vec3(0.07,0.055,0.07),vec3(0.19,0.12,0.15),smoothstep(0.40,0.80,ink.r));
    } else if (hi-lo<0.035 && lo>0.30) {
        // Keep a dark jacket, but its shoulders must read against the black
        // hair at actual phone scale: charcoal mids and RGB102/99/105 edges.
        ink.rgb=mix(vec3(0.24,0.23,0.27),vec3(0.40,0.39,0.41),smoothstep(0.30,1.0,lo));
    } else if (horizontal_frames==5.0 && ink.r<0.65 && ink.g>0.55 && ink.b>0.55 && ink.r<min(ink.g,ink.b)*0.8) {
        ink.rgb=mix(vec3(0.10,0.12,0.17),vec3(0.20,0.22,0.29),ink.b);
    }
    // Preserve every outer black contour, while lifting only enclosed black
    // jacket folds outside the original head. Otherwise the old thick ink
    // regions merge the torso and dark crown into one unreadable black mass.
    if (hi<0.025 && ink.a>0.9 && (abs(head_pixel.x)>5.5 || abs(head_pixel.y)>5.0)) {
        bool enclosed = texture(TEXTURE,source_uv+vec2(TEXTURE_PIXEL_SIZE.x,0.0)).a>0.9
            && texture(TEXTURE,source_uv-vec2(TEXTURE_PIXEL_SIZE.x,0.0)).a>0.9
            && texture(TEXTURE,source_uv+vec2(0.0,TEXTURE_PIXEL_SIZE.y)).a>0.9
            && texture(TEXTURE,source_uv-vec2(0.0,TEXTURE_PIXEL_SIZE.y)).a>0.9;
        if (enclosed) ink.rgb=vec3(0.17,0.16,0.20);
    }
    COLOR=ink*vertex_tint;
}
