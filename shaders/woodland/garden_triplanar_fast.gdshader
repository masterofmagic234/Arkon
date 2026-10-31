shader_type spatial;
// Keep near-camera normal detail, the authored mapping, and real baked light.
// Roughness/specular texture work is a poor use of bandwidth on matte night stone.
render_mode depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform float roughness = .85;
uniform float normal_scale = 1.0;
uniform vec3 uv_scale = vec3(1.0);
uniform float blend_sharpness = 1.0;
uniform float normal_detail_distance = 14.0;
varying vec3 weights;
varying vec3 position_uv;
varying float view_distance;
void vertex() {
    vec3 n = MODEL_NORMAL_MATRIX * NORMAL;
    TANGENT = inverse(MODEL_NORMAL_MATRIX) * normalize(vec3(abs(n.y) + abs(n.z), 0.0, -abs(n.x)));
    BINORMAL = inverse(MODEL_NORMAL_MATRIX) * normalize(vec3(0.0, abs(n.x) + abs(n.z), -abs(n.y)));
    weights = pow(abs(n), vec3(blend_sharpness));
    weights /= dot(weights, vec3(1.0));
    position_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * uv_scale * vec3(1.0, -1.0, 1.0);
    view_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
vec4 projected(sampler2D tex, vec3 dx, vec3 dy) {
    vec4 value = vec4(0.0);
    if (weights.z > 0.0) value += textureGrad(tex, position_uv.xy, dx.xy, dy.xy) * weights.z;
    if (weights.y > 0.0) value += textureGrad(tex, position_uv.xz, dx.xz, dy.xz) * weights.y;
    if (weights.x > 0.0) value += textureGrad(tex, position_uv.zy * vec2(-1.0, 1.0), dx.zy * vec2(-1.0, 1.0), dy.zy * vec2(-1.0, 1.0)) * weights.x;
    return value;
}
void fragment() {
    vec3 dx = dFdx(position_uv);
    vec3 dy = dFdy(position_uv);
    ALBEDO = albedo.rgb * projected(texture_albedo, dx, dy).rgb;
    ROUGHNESS = roughness;
    SPECULAR = 0.0;
    if (has_normal && view_distance < normal_detail_distance) {
        NORMAL_MAP = projected(texture_normal, dx, dy).rgb;
        NORMAL_MAP_DEPTH = normal_scale;
    }
}
