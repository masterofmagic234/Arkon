shader_type canvas_item;
render_mode unshaded;

uniform float hit_strength : hint_range(0.0, 1.0) = 0.0;
uniform float danger_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 edge_distance = abs(UV * 2.0 - 1.0);
    float sides = smoothstep(0.58, 0.995, max(edge_distance.x, edge_distance.y));
    float corners = smoothstep(0.68, 1.35, length(edge_distance));
    float coverage = max(sides * 0.9, corners * 0.7);
    float alpha = min(0.60, coverage * (hit_strength * 0.56 + danger_strength * 0.15));
    COLOR = vec4(0.64, 0.018, 0.03, alpha);
}
