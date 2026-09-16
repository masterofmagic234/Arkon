shader_type spatial;
render_mode cull_back, unshaded;

uniform sampler2D wall_texture : source_color, filter_nearest, repeat_disable;

varying vec3 wall_world_pos;

void vertex() {
    wall_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Each architectural style is a single 4096x512 panorama made from
    // eight consecutive 512x512 panels. The physical wall segments must
    // reveal those panels in sequence, so the level reads as one long mural
    // instead of eight unrelated textures repeated on every wall.
    //
    // Use the original 20x14 grid coordinates to select the panel. Moving
    // one cell in either direction advances the mural by one panel. The
    // sequence is reset inside each of the six architectural districts.
    const float cell_size = 1.8;
    const float origin_x = -17.1;
    const float origin_z = -11.7;

    float grid_x = round((wall_world_pos.x - origin_x) / cell_size);
    float grid_z = round((wall_world_pos.z - origin_z) / cell_size);

    float zone_col;
    float zone_row;
    float zone_origin_x;
    float zone_origin_z;

    if (grid_x <= 6.0) {
        zone_col = 0.0;
        zone_origin_x = 0.0;
    } else if (grid_x <= 12.0) {
        zone_col = 1.0;
        zone_origin_x = 7.0;
    } else {
        zone_col = 2.0;
        zone_origin_x = 13.0;
    }

    if (grid_z <= 6.0) {
        zone_row = 0.0;
        zone_origin_z = 0.0;
    } else {
        zone_row = 1.0;
        zone_origin_z = 7.0;
    }

    float local_x = grid_x - zone_origin_x;
    float local_z = grid_z - zone_origin_z;
    float panel = mod(local_x + local_z, 8.0);
    if (panel < 0.0) {
        panel += 8.0;
    }

    // One complete 512x512 panel occupies one physical wall segment.
    // This preserves the artwork's intended panel order and makes adjacent
    // segments read as a continuous illustrated wall.
    vec2 uv = vec2(
        (panel + UV.x) / 8.0,
        UV.y
    );

    vec4 tex = texture(wall_texture, uv);
    ALBEDO = tex.rgb;
    ALPHA = tex.a;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
