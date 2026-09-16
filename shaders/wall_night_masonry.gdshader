shader_type spatial;
render_mode cull_disabled, unshaded;

uniform sampler2D wall_texture : source_color, filter_nearest, repeat_disable;

varying vec3 wall_world_pos;
varying vec3 wall_world_normal;

void vertex() {
    wall_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    wall_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    // The mural source is a single 4096x512 strip containing eight 512px
    // panels. Each canonical wall cell is exactly one panel wide. The panel
    // index comes from the cell's world coordinate, so neighbouring cells
    // form one continuous strip instead of each cell repeating panel zero.
    float horizontal_axis = abs(wall_world_normal.z) > abs(wall_world_normal.x) ? wall_world_pos.x : wall_world_pos.z;
    float cell = floor((horizontal_axis + 17.1) / 1.8);

    float panel = mod(cell, 8.0);
    if (panel < 0.0) {
        panel += 8.0;
    }

    float local_u = fract((horizontal_axis + 17.1) / 1.8);
    float u = (panel + local_u) / 8.0;

    // Remove the small editorial title band at the top of the source strip;
    // the actual illustrated wall artwork fills the game wall instead.
    float v = 0.08 + clamp(wall_world_pos.y / 2.6, 0.0, 1.0) * 0.92;

    vec4 tex = texture(wall_texture, vec2(u, v));
    ALBEDO = tex.rgb;
    ALPHA = 1.0;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
