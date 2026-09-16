shader_type spatial;
render_mode cull_disabled, unshaded;

// Use smooth filtering: the source murals are 4096x512, but nearest-neighbour
// sampling makes every source pixel appear as a huge block on close walls.
uniform sampler2D wall_texture : source_color, filter_linear, repeat_disable;

varying vec3 wall_world_pos;
varying vec3 wall_world_normal;

void vertex() {
    wall_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    wall_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    // Each mural is a 4096x512 strip containing eight consecutive 512px
    // panels. World position selects the panel and keeps the strip continuous.
    float horizontal_axis = abs(wall_world_normal.z) > abs(wall_world_normal.x) ? wall_world_pos.x : wall_world_pos.z;
    float cell_coord = (horizontal_axis + 17.1) / 1.8;
    float cell = floor(cell_coord);

    float panel = mod(cell, 8.0);
    if (panel < 0.0) {
        panel += 8.0;
    }

    float local_u = fract(cell_coord);
    float u = (panel + local_u) / 8.0;

    // Face geometry is now oriented correctly on all four directions. Flip
    // only the negative-facing sides so artwork reads consistently from the
    // playable corridor instead of becoming mirrored around turns.
    bool negative_facing = (abs(wall_world_normal.z) > abs(wall_world_normal.x))
        ? (wall_world_normal.z < 0.0)
        : (wall_world_normal.x < 0.0);
    if (negative_facing) {
        u = 1.0 - u;
    }

    // The source strip has a small editorial title band at the top. Crop it
    // while retaining almost all of the actual illustrated wall artwork.
    const float artwork_top = 0.13;
    float v = artwork_top + (1.0 - clamp(wall_world_pos.y / 2.6, 0.0, 1.0)) * (1.0 - artwork_top);

    vec4 tex = texture(wall_texture, vec2(u, v));
    ALBEDO = tex.rgb;
    ALPHA = 1.0;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
