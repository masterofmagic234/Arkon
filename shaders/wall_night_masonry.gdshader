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
    // Each mural is a 4096x512 strip containing eight consecutive 512px
    // panels. World position selects the panel, while the vertical UV is
    // inverted because QuadMesh UV.y runs opposite to the source artwork.
    float horizontal_axis = abs(wall_world_normal.z) > abs(wall_world_normal.x) ? wall_world_pos.x : wall_world_pos.z;
    float cell = floor((horizontal_axis + 17.1) / 1.8);

    float panel = mod(cell, 8.0);
    if (panel < 0.0) {
        panel += 8.0;
    }

    float local_u = fract((horizontal_axis + 17.1) / 1.8);
    float u = (panel + local_u) / 8.0;

    // The source strip has a small title/editorial band at the top.
    // Keep the illustrated wall area, but flip it vertically so signs,
    // lamps, plants and architectural details are upright in-game.
    float artwork_v = 0.08 + clamp(wall_world_pos.y / 2.6, 0.0, 1.0) * 0.92;
    float v = 0.08 + (1.0 - clamp(wall_world_pos.y / 2.6, 0.0, 1.0)) * 0.92;

    vec4 tex = texture(wall_texture, vec2(u, v));
    ALBEDO = tex.rgb;
    ALPHA = 1.0;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
