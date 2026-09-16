shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform float wall_seed = 0.0;

varying vec3 local_pos;
varying vec3 local_normal;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float hash31(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

void vertex() {
    local_pos = VERTEX;
    local_normal = NORMAL;
}

void fragment() {
    vec3 n = normalize(local_normal);
    vec2 uv;

    if (abs(n.y) > 0.5) {
        uv = local_pos.xz;
    } else if (abs(n.x) > abs(n.z)) {
        uv = local_pos.zy;
    } else {
        uv = local_pos.xy;
    }

    uv += vec2(wall_seed * 0.37, wall_seed * 0.19);

    // Large masonry blocks: stable in object space, so they never stretch with
    // the long corridor mural planes that caused the previous artifact.
    vec2 cell_size = vec2(1.05, 0.72);
    vec2 grid = uv / cell_size;
    vec2 cell = floor(grid);
    vec2 f = fract(grid);

    // Stagger alternate rows like real brick/stone courses.
    if (mod(cell.y, 2.0) > 0.5) {
        cell.x += 0.5;
        f.x = fract(f.x + 0.5);
    }

    float mortar_x = smoothstep(0.075, 0.018, min(f.x, 1.0 - f.x));
    float mortar_y = smoothstep(0.075, 0.018, min(f.y, 1.0 - f.y));
    float mortar = max(mortar_x, mortar_y);

    float variation = hash21(cell);
    float fine = hash31(vec3(cell, floor(uv.x * 5.0 + uv.y * 7.0)));

    vec3 stone_a = vec3(0.105, 0.145, 0.175);
    vec3 stone_b = vec3(0.155, 0.185, 0.205);
    vec3 stone_c = vec3(0.205, 0.185, 0.165);
    vec3 stone = mix(stone_a, stone_b, smoothstep(0.15, 0.85, variation));
    stone = mix(stone, stone_c, step(0.88, variation) * 0.55);

    // Very subtle surface breakup; no visible texture tiling.
    stone *= 0.90 + fine * 0.16;

    vec3 mortar_color = vec3(0.028, 0.040, 0.052);
    ALBEDO = mix(stone, mortar_color, mortar * 0.92);
    ROUGHNESS = 0.94;
    SPECULAR = 0.18;
}
