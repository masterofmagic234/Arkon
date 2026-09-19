extends Node2D

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const RaceMath = preload("res://scripts/race_math.gd")

const CAMERA_DEPTH: float = 0.84
const CAMERA_BEHIND: float = 6.0
const FAR_SEGMENTS: int = 240
const VISUAL_SUBDIVISIONS: int = 4
const HORIZON_FRACTION: float = 0.50
const ROAD_SCREEN_SCALE: float = 0.75
const ROAD_WORLD_WIDTH: float = 9.0
const RENDER_CURVE_SCALE: float = 0.16
const ROAD_CURVE_VISUAL_SCALE: float = 7.0
const CURVE_SMOOTH_RADIUS: int = 2
const PLAYER_LATERAL_SCREEN_SCALE: float = 0.42
const SEGMENT_WORLD_LEN: float = 50.0 / float(VISUAL_SUBDIVISIONS)
const ASPHALT_UV_PER_SEGMENT: float = 0.32
const GRASS_WORLD_UV_SCALE: float = 0.04
const ROAD_STEP: int = 2

const COL_SKY_TOP := Color(0.35, 0.55, 1.00)
const COL_SKY_BOTTOM := Color(0.60, 0.78, 1.00)
const COL_CITY := Color(0.28, 0.28, 0.48)
const COL_GRASS_LIGHT := Color(0.35, 0.85, 0.20)
const COL_GRASS_DARK := Color(0.20, 0.60, 0.10)
const COL_ROAD_LIGHT := Color(0.60, 0.60, 0.65)
const COL_ROAD_DARK := Color(0.45, 0.45, 0.50)
const COL_RUMBLE_LIGHT := Color(1.00, 1.00, 1.00)
const COL_RUMBLE_DARK := Color(0.90, 0.15, 0.15)
const COL_LANE := Color(0.95, 0.95, 0.95)

var race_state = null
var player_car = null
var ai_cars: Array = []
var track_pattern: Array = []
var track_x: PackedFloat32Array = PackedFloat32Array()
var track_size: int = 0

var ssx := PackedFloat32Array()
var ssy := PackedFloat32Array()
var shw := PackedFloat32Array()
var sidx := PackedInt32Array()

var _tex_cache: Dictionary = {}

var city_texture: Texture2D
var moon_texture: Texture2D
var grass_texture: Texture2D
var grass_far_texture: Texture2D
var asphalt_texture: Texture2D
var rumble_texture: Texture2D
var oak_texture: Texture2D
var pine_texture: Texture2D
var lamp_texture: Texture2D
var squirrel_mobile_texture: Texture2D
var oka_texture: Texture2D

func _tex(path: String) -> Texture2D:
    if _tex_cache.has(path):
        return _tex_cache[path] as Texture2D
    var tex: Texture2D = load(path) as Texture2D
    _tex_cache[path] = tex
    return tex

func _find_tex(paths: Array) -> Texture2D:
    for path in paths:
        var p: String = str(path)
        var tex: Texture2D = _tex(p)
        if tex != null:
            return tex
    return null

func _ready() -> void:
    # Grass/asphalt use UVs outside 0..1. Explicit repeat prevents Godot's
    # default edge-clamping from stretching the texture into horizontal bands.
    texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    # The asphalt and roadside billboards are viewed at steep angles and at
    # very different scales. Mipmaps + anisotropic filtering reduce the
    # smeared/aliased look without changing the road width or curve math.
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    ssx.resize(FAR_SEGMENTS)
    ssy.resize(FAR_SEGMENTS)
    shw.resize(FAR_SEGMENTS)
    sidx.resize(FAR_SEGMENTS)
    city_texture = _find_tex(["res://assets/city_night.png", "res://city_night.png"])
    moon_texture = _find_tex(["res://assets/moon.png", "res://moon.png"])
    grass_texture = _find_tex(["res://assets/grass_tile.png", "res://assets/grass.png"])
    grass_far_texture = _find_tex(["res://assets/grass.png", "res://assets/grass_tile.png"])
    asphalt_texture = _find_tex(["res://assets/asphalt.png", "res://asphalt.png"])
    rumble_texture = _find_tex(["res://assets/rumble.png", "res://rumble.png"])
    oak_texture = _find_tex(["res://assets/oak_tree.png", "res://oak_tree.png"])
    pine_texture = _find_tex(["res://assets/pine_tree.png", "res://pine_tree.png"])
    lamp_texture = _find_tex(["res://assets/street_lamp.png", "res://street_lamp.png"])
    squirrel_mobile_texture = _find_tex(["res://assets/squirrel_mobile.png", "res://squirrel_mobile.png"])
    oka_texture = _find_tex(["res://assets/oka.png", "res://oka.png"])
    queue_redraw()

func bind(state, player_ref, ais_ref: Array, pattern: Array, tx: PackedFloat32Array) -> void:
    race_state = state
    player_car = player_ref
    ai_cars = ais_ref
    track_pattern = pattern
    track_x = tx
    track_size = pattern.size()
    queue_redraw()

func _process(_delta: float) -> void:
    # Forward motion is already represented by the player's segment_progress.
    # A second scrolling clock would double-count motion and introduce jumps.
    queue_redraw()

func _smooth_track_x(position: float) -> float:
    # The raw track_x values are control points. Linear interpolation makes
    # every physical segment a straight chord, which is exactly the visual
    # problem we are avoiding: straight -> small step -> straight.
    # Catmull-Rom interpolation keeps the tangent continuous between points,
    # producing one actual sweeping arc.
    if track_size < 4:
        return track_x[posmod(int(floor(position)), track_size)]

    var base: int = int(floor(position))
    var t: float = position - floor(position)
    var p0: float = track_x[posmod(base - 1, track_size)]
    var p1: float = track_x[posmod(base, track_size)]
    var p2: float = track_x[posmod(base + 1, track_size)]
    var p3: float = track_x[posmod(base + 2, track_size)]

    var t2: float = t * t
    var t3: float = t2 * t
    return 0.5 * (
        (2.0 * p1)
        + (-p0 + p2) * t
        + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
        + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    )

func _render_curve_for_segment(seg: int) -> float:
    # Classic NES/OutRun-style curve profile: the road is controlled by a
    # per-segment curve value, not by a world-space centerline alone.
    # A small weighted neighborhood smooths the entry/exit of a corner.
    var total := 0.0
    var weight_total := 0.0
    for k in range(-CURVE_SMOOTH_RADIUS, CURVE_SMOOTH_RADIUS + 1):
        var weight: float = float(CURVE_SMOOTH_RADIUS + 1 - abs(k))
        var idx: int = posmod(seg + k, track_size)
        total += RaceMath.curve_of(track_pattern[idx]) * weight
        weight_total += weight
    return total / weight_total

func _render_curve_at(position: float) -> float:
    var base: int = int(floor(position))
    var t: float = position - floor(position)
    var c0: float = _render_curve_for_segment(base)
    var c1: float = _render_curve_for_segment(base + 1)
    var eased_t: float = t * t * (3.0 - 2.0 * t)
    return lerpf(c0, c1, eased_t)

func _draw() -> void:
    if race_state == null or player_car == null or track_size == 0 or track_x.is_empty():
        return

    var vp: Vector2 = get_viewport_rect().size
    var w: float = vp.x
    # Keep the existing Level 2 drawing boundary. HUD/layout owns the rest.
    var draw_h: float = 496.0
    var horizon_y: float = draw_h * HORIZON_FRACTION

    _draw_sky(w, horizon_y)
    _draw_road(w, draw_h, horizon_y)
    _draw_props(w, draw_h, horizon_y)
    _draw_ai_cars(w, draw_h, horizon_y)
    _draw_player_car(w, draw_h)

func _draw_sky(w: float, horizon_y: float) -> void:
    # Level 2 is a night race: the city is the entire distant backdrop.
    # There is deliberately no separate daytime/blue sky layer.
    if city_texture != null:
        draw_texture_rect(city_texture, Rect2(0.0, 0.0, w, horizon_y), true)
    else:
        draw_rect(Rect2(0.0, 0.0, w, horizon_y), Color(0.035, 0.07, 0.13), true)

    # The moon is a separate foreground layer: it remains visible in front
    # of the city image instead of being baked into the skyline.
    if moon_texture != null:
        var moon_size: float = minf(horizon_y * 0.46, w * 0.16)
        draw_texture_rect(
            moon_texture,
            Rect2(w * 0.72, horizon_y * 0.10, moon_size, moon_size),
            false,
            Color(1.0, 1.0, 1.0, 0.96)
        )

func _draw_road(w: float, h: float, horizon_y: float) -> void:
    var cam_seg: int = player_car.segment_index % track_size
    var cam_progress: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var half_w: float = w * 0.5
    var camera_track_x: float = _smooth_track_x(float(cam_seg) + cam_progress)

    for i in range(FAR_SEGMENTS):
        var raw_dist: float = float(i) / float(VISUAL_SUBDIVISIONS) - cam_progress
        var visible_dist: float = maxf(0.0, raw_dist)
        var absolute_seg: float = float(cam_seg) + cam_progress + raw_dist
        var road_center_x: float = _smooth_track_x(absolute_seg) - camera_track_x

        var raw_next_dist: float = float(i + 1) / float(VISUAL_SUBDIVISIONS) - cam_progress
        var visible_next_dist: float = maxf(0.0, raw_next_dist)
        var dz: float = visible_dist * RaceLevelData.SEGMENT_HEIGHT + CAMERA_BEHIND
        var next_dz: float = visible_next_dist * RaceLevelData.SEGMENT_HEIGHT + CAMERA_BEHIND
        dz = maxf(1.0, dz)
        next_dz = maxf(1.0, next_dz)

        var scale: float = CAMERA_DEPTH / dz
        var next_scale: float = CAMERA_DEPTH / next_dz

        ssx[i] = half_w + scale * road_center_x * half_w
        ssy[i] = horizon_y + (h - horizon_y) * CAMERA_BEHIND / dz
        shw[i] = scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE
        sidx[i] = posmod(int(floor(absolute_seg)), track_size)

        if i + 1 < FAR_SEGMENTS:
            var next_absolute_seg: float = float(cam_seg) + cam_progress + raw_next_dist
            var next_center_x: float = _smooth_track_x(next_absolute_seg) - camera_track_x
            ssx[i + 1] = half_w + next_scale * next_center_x * half_w
            ssy[i + 1] = horizon_y + (h - horizon_y) * CAMERA_BEHIND / next_dz
            shw[i + 1] = next_scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE


    # Grass is mapped in world coordinates, not per-render-segment UVs.
    # Each thin trapezoid receives UVs from the inverse of the exact screen
    # projection used for the road. ROAD_STEP subdivision keeps the affine
    # interpolation inside each quad visually close to perspective-correct.
    var gi: int = FAR_SEGMENTS - 2
    while gi >= 0:
        var gj: int = min(gi + ROAD_STEP, FAR_SEGMENTS - 1)
        if ssy[gi] > ssy[gj]:
            var gl0 := Vector2(0.0, ssy[gi])
            var gr0 := Vector2(w, ssy[gi])
            var gl1 := Vector2(0.0, ssy[gj])
            var gr1 := Vector2(w, ssy[gj])

            var road_l0 := Vector2(ssx[gi] - shw[gi], ssy[gi])
            var road_r0 := Vector2(ssx[gi] + shw[gi], ssy[gi])
            var road_l1 := Vector2(ssx[gj] - shw[gj], ssy[gj])
            var road_r1 := Vector2(ssx[gj] + shw[gj], ssy[gj])

            var absolute_seg_i: float = float(cam_seg) + float(gi) / float(VISUAL_SUBDIVISIONS)
            var absolute_seg_j: float = float(cam_seg) + float(gj) / float(VISUAL_SUBDIVISIONS)
            var grass_band: int = int(floor(absolute_seg_i))
            var grass_tint: Color = COL_GRASS_LIGHT if posmod(grass_band, 2) == 0 else COL_GRASS_DARK

            var left_points := PackedVector2Array([gl0, road_l0, road_l1, gl1])
            var right_points := PackedVector2Array([road_r0, gr0, gr1, road_r1])

            if grass_texture != null:
                var raw_dist_i: float = float(gi) / float(VISUAL_SUBDIVISIONS) - cam_progress
                var raw_dist_j: float = float(gj) / float(VISUAL_SUBDIVISIONS) - cam_progress
                var visible_dist_i: float = maxf(0.0, raw_dist_i)
                var visible_dist_j: float = maxf(0.0, raw_dist_j)
                var dz_i: float = visible_dist_i * RaceLevelData.SEGMENT_HEIGHT + CAMERA_BEHIND
                var dz_j: float = visible_dist_j * RaceLevelData.SEGMENT_HEIGHT + CAMERA_BEHIND
                var center_x_i: float = _smooth_track_x(absolute_seg_i) - camera_track_x
                var center_x_j: float = _smooth_track_x(absolute_seg_j) - camera_track_x
                var half_road: float = ROAD_WORLD_WIDTH * 0.5
                var world_dx_per_px_i: float = half_road * ROAD_SCREEN_SCALE / maxf(shw[gi], 0.001)
                var world_dx_per_px_j: float = half_road * ROAD_SCREEN_SCALE / maxf(shw[gj], 0.001)
                var world_x_left_i: float = center_x_i + (0.0 - ssx[gi]) * world_dx_per_px_i
                var world_x_right_i: float = center_x_i + (w - ssx[gi]) * world_dx_per_px_i
                var world_x_left_j: float = center_x_j + (0.0 - ssx[gj]) * world_dx_per_px_j
                var world_x_right_j: float = center_x_j + (w - ssx[gj]) * world_dx_per_px_j
                var world_x_road_l_i: float = center_x_i - half_road
                var world_x_road_l_j: float = center_x_j - half_road
                var world_x_road_r_i: float = center_x_i + half_road
                var world_x_road_r_j: float = center_x_j + half_road
                var uv_y_i: float = -dz_i * GRASS_WORLD_UV_SCALE
                var uv_y_j: float = -dz_j * GRASS_WORLD_UV_SCALE
                var left_uvs := PackedVector2Array([
                    Vector2(world_x_left_i * GRASS_WORLD_UV_SCALE, uv_y_i),
                    Vector2(world_x_road_l_i * GRASS_WORLD_UV_SCALE, uv_y_i),
                    Vector2(world_x_road_l_j * GRASS_WORLD_UV_SCALE, uv_y_j),
                    Vector2(world_x_left_j * GRASS_WORLD_UV_SCALE, uv_y_j)
                ])
                var right_uvs := PackedVector2Array([
                    Vector2(world_x_road_r_i * GRASS_WORLD_UV_SCALE, uv_y_i),
                    Vector2(world_x_right_i * GRASS_WORLD_UV_SCALE, uv_y_i),
                    Vector2(world_x_right_j * GRASS_WORLD_UV_SCALE, uv_y_j),
                    Vector2(world_x_road_r_j * GRASS_WORLD_UV_SCALE, uv_y_j)
                ])
                var grass_cols := PackedColorArray([grass_tint, grass_tint, grass_tint, grass_tint])
                draw_polygon(left_points, grass_cols, left_uvs, grass_texture)
                draw_polygon(right_points, grass_cols, right_uvs, grass_texture)
            else:
                draw_colored_polygon(left_points, grass_tint)
                draw_colored_polygon(right_points, grass_tint)
        gi -= ROAD_STEP

    # Draw paired visual subdivisions. This keeps the road curved while
    # cutting textured-road draw calls roughly in half on mobile.
    var i: int = FAR_SEGMENTS - 2
    while i >= 0:
        var j: int = min(i + ROAD_STEP, FAR_SEGMENTS - 1)
        var absolute_seg: float = float(cam_seg) + float(i) / float(VISUAL_SUBDIVISIONS)
        if ssy[i] > ssy[j]:
            var l0 := Vector2(ssx[i] - shw[i], ssy[i])
            var r0 := Vector2(ssx[i] + shw[i], ssy[i])
            var l1 := Vector2(ssx[j] - shw[j], ssy[j])
            var r1 := Vector2(ssx[j] + shw[j], ssy[j])

            var road_band: int = int(floor(
                (float(cam_seg) + float(i) / float(VISUAL_SUBDIVISIONS))
                * float(VISUAL_SUBDIVISIONS)
            ))

            var road_dark: bool = posmod(road_band / 4, 2) == 0
            var road_col: Color = COL_ROAD_DARK if road_dark else COL_ROAD_LIGHT
            var road_points := PackedVector2Array([l0, r0, r1, l1])
            var road_uvs := PackedVector2Array([
                Vector2(0.0, 1.0),
                Vector2(1.0, 1.0),
                Vector2(1.0, 0.0),
                Vector2(0.0, 0.0)
            ])

            if asphalt_texture != null:
                # Continuous V coordinates keep the asphalt texture flowing
                # along the road instead of restarting on every trapezoid.
                var uv_v0: float = absolute_seg * ASPHALT_UV_PER_SEGMENT
                var uv_step: float = float(j - i) / float(VISUAL_SUBDIVISIONS)
                var uv_v1: float = uv_v0 + uv_step * ASPHALT_UV_PER_SEGMENT
                var asphalt_uvs := PackedVector2Array([
                    Vector2(0.0, uv_v0),
                    Vector2(1.0, uv_v0),
                    Vector2(1.0, uv_v1),
                    Vector2(0.0, uv_v1)
                ])
                var asphalt_cols := PackedColorArray([
                    Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE
                ])
                draw_polygon(road_points, asphalt_cols, asphalt_uvs, asphalt_texture)
            else:
                draw_colored_polygon(road_points, road_col)

            var rw0: float = maxf(2.0, shw[i] * 0.12)
            var rw1: float = maxf(2.0, shw[j] * 0.12)

            var left_rumble := PackedVector2Array([
                l0,
                Vector2(l0.x + rw0, l0.y),
                Vector2(l1.x + rw1, l1.y),
                l1
            ])
            var right_rumble := PackedVector2Array([
                Vector2(r0.x - rw0, r0.y),
                r0,
                r1,
                Vector2(r1.x - rw1, r1.y)
            ])

            if rumble_texture != null:
                draw_colored_polygon(left_rumble, Color.WHITE, road_uvs, rumble_texture)
                draw_colored_polygon(right_rumble, Color.WHITE, road_uvs, rumble_texture)
            else:
                var rumb_col: Color = COL_RUMBLE_LIGHT if posmod(road_band, 2) == 0 else Color.BLACK
                draw_colored_polygon(left_rumble, rumb_col)
                draw_colored_polygon(right_rumble, rumb_col)

            if road_dark:
                var lw0: float = maxf(2.0, shw[i] * 0.035)
                var lw1: float = maxf(2.0, shw[j] * 0.035)
                var cx0: float = ssx[i]
                var cx1: float = ssx[j]
                draw_colored_polygon(PackedVector2Array([
                    Vector2(cx0 - lw0 * 0.5, ssy[i]),
                    Vector2(cx0 + lw0 * 0.5, ssy[i]),
                    Vector2(cx1 + lw1 * 0.5, ssy[j]),
                    Vector2(cx1 - lw1 * 0.5, ssy[j])
                ]), COL_LANE)

        i -= ROAD_STEP

func _draw_billboard(texture: Texture2D, center_x: float, bottom_y: float, width: float, height: float, modulate := Color.WHITE) -> void:
    if texture == null or width <= 1.0 or height <= 1.0:
        return
    draw_texture_rect(
        texture,
        Rect2(center_x - width * 0.5, bottom_y - height, width, height),
        false,
        modulate
    )

func _draw_props(w: float, h: float, horizon_y: float) -> void:
    if oak_texture == null and pine_texture == null and lamp_texture == null:
        return

    var cam_seg: int = player_car.segment_index % track_size
    var cam_progress: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var max_visible_segments: int = int(ceil(float(FAR_SEGMENTS) / float(VISUAL_SUBDIVISIONS))) - 1

    # Draw far-to-near so close billboards correctly occlude distant ones.
    for ahead in range(max_visible_segments, -1, -1):
        var world_seg: int = posmod(cam_seg + ahead, track_size)

        # Deterministic roadside density: one prop every two world segments.
        if posmod(world_seg, 2) != 0:
            continue

        var distance_segments: float = float(ahead) - cam_progress
        if distance_segments <= 0.01:
            continue

        # Snap each world-anchored prop to the nearest rendered road sample.
        # The road samples are built from:
        #   raw_dist = i / VISUAL_SUBDIVISIONS - cam_progress
        # so the prop must use the same camera-relative sample coordinate.
        # This keeps X, Y and perspective scale locked to one exact road slice.
        var visual_pos: float = distance_segments * float(VISUAL_SUBDIVISIONS)
        var vi: int = clampi(int(round(visual_pos)), 0, FAR_SEGMENTS - 1)

        var road_cx: float = ssx[vi]
        var road_half: float = shw[vi]
        var screen_y: float = ssy[vi]

        if screen_y <= horizon_y or screen_y > h + 400.0:
            continue

        # Match the depth formula used by _draw_road for this exact sample.
        # IMPORTANT: vi/4 alone would lose cam_progress and make the billboard
        # scale drift while the car moves through a segment.
        var sample_dist: float = float(vi) / float(VISUAL_SUBDIVISIONS) - cam_progress
        var dz: float = sample_dist * RaceLevelData.SEGMENT_HEIGHT + CAMERA_BEHIND
        dz = maxf(1.0, dz)

        var scale: float = CAMERA_DEPTH / dz
        var px_per_meter: float = scale * w * ROAD_SCREEN_SCALE
        var gap_world: float = 2.5
        var gap_screen: float = gap_world * px_per_meter

        # Alternate sides in world space, so the layout stays fixed for the
        # whole lap and never teleports when the camera crosses a sample.
        var side: float = -1.0 if posmod(world_seg / 2, 2) == 0 else 1.0
        var sx: float = road_cx + side * (road_half + gap_screen)

        if posmod(world_seg, 12) == 0 and lamp_texture != null:
            var prop_w: float = clampf(2.0 * px_per_meter, 4.0, 300.0)
            var prop_h: float = clampf(8.0 * px_per_meter, 16.0, 800.0)
            _draw_billboard(lamp_texture, sx, screen_y, prop_w, prop_h)
        else:
            var tree_tex: Texture2D = pine_texture if (posmod(world_seg / 4, 2) == 0 and pine_texture != null) else oak_texture
            if tree_tex != null:
                var prop_w: float = clampf(14.0 * px_per_meter, 8.0, 900.0)
                var prop_h: float = clampf(18.0 * px_per_meter, 10.0, 1100.0)
                _draw_billboard(tree_tex, sx, screen_y, prop_w, prop_h)

func _draw_ai_cars(w: float, h: float, horizon_y: float) -> void:
    if player_car == null:
        return

    var p_prog: float = player_car.progress(track_size)
    var half_road: float = ROAD_WORLD_WIDTH * 0.5
    for ai_controller in ai_cars:
        if ai_controller == null or ai_controller.car == null:
            continue

        var ai = ai_controller.car
        var ai_prog: float = ai.progress(track_size)
        var delta_segments: float = ai_prog - p_prog

        if delta_segments < 0.5 or delta_segments >= float(FAR_SEGMENTS) / float(VISUAL_SUBDIVISIONS) - 2.0:
            continue

        var visual_distance: float = delta_segments * float(VISUAL_SUBDIVISIONS)
        var i_fl: int = int(floor(visual_distance))
        if i_fl < 0 or i_fl + 1 >= ssx.size():
            continue

        var t: float = visual_distance - float(i_fl)
        var ai_seg: int = ai.segment_index % track_size
        var ai_track_center: float = lerpf(
            track_x[ai_seg],
            track_x[(ai_seg + 1) % track_size],
            ai.segment_progress
        )
        var norm_offset: float = (ai.world_x - ai_track_center) / half_road
        norm_offset = clampf(norm_offset, -1.25, 1.25)

        var road_cx: float = lerpf(ssx[i_fl], ssx[i_fl + 1], t)
        var current_shw: float = lerpf(shw[i_fl], shw[i_fl + 1], t)

        var dz: float = delta_segments * RaceLevelData.SEGMENT_HEIGHT + CAMERA_BEHIND
        dz = maxf(1.0, dz)
        var scale: float = CAMERA_DEPTH / dz
        var sy: float = horizon_y + (h - horizon_y) * CAMERA_BEHIND / dz

        if sy < horizon_y or sy > h:
            continue

        var sx: float = road_cx + norm_offset * current_shw
        var car_w: float = clampf(scale * ROAD_WORLD_WIDTH * w * 0.35, 8.0, 190.0)
        var car_h: float = car_w * 0.56

        if squirrel_mobile_texture != null:
            _draw_billboard(squirrel_mobile_texture, sx, sy, car_w * 1.25, car_h * 1.55)
        else:
            draw_rect(
                Rect2(sx - car_w * 0.5, sy - car_h, car_w, car_h),
                Color(0.75, 0.15, 0.15),
                true
            )
            draw_rect(
                Rect2(sx - car_w * 0.4, sy - car_h * 0.7, car_w * 0.8, car_h * 0.3),
                Color(1.0, 1.0, 1.0),
                true
            )

const PLAYER_STEER_SHIFT: float = 0.075
const PLAYER_STEER_TILT_DEG: float = 5.0

func _draw_player_car(w: float, h: float) -> void:
    var base_y: float = h * 0.985
    var car_w: float = w * 0.14
    var car_h: float = car_w * 0.55

    var cam_seg: int = player_car.segment_index % track_size
    var cam_progress: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var camera_track_x: float = _smooth_track_x(float(cam_seg) + cam_progress)
    var half_road: float = ROAD_WORLD_WIDTH * 0.5
    var lateral: float = 0.0
    if half_road > 0.0:
        lateral = clampf((player_car.world_x - camera_track_x) / half_road, -1.0, 1.0)

    # Keep Oka's real road position and add only a small visual steering
    # response. Steering is input feedback, not a replacement for physics.
    var steer: float = clampf(player_car.steer_in, -1.0, 1.0)
    var steer_shift_x: float = -steer * w * PLAYER_STEER_SHIFT
    var cx: float = w * 0.5 + lateral * w * PLAYER_LATERAL_SCREEN_SCALE + steer_shift_x
    var tilt_rad: float = steer * deg_to_rad(PLAYER_STEER_TILT_DEG)

    if oka_texture != null:
        draw_set_transform(Vector2(cx, base_y), tilt_rad, Vector2.ONE)
        draw_texture_rect(
            oka_texture,
            Rect2(-car_w * 0.775, -car_h * 1.75, car_w * 1.55, car_h * 1.75),
            false
        )
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    else:
        draw_set_transform(Vector2(cx, base_y), tilt_rad, Vector2.ONE)
        draw_rect(Rect2(-car_w * 0.55, car_h * 0.1, car_w * 1.1, car_h * 0.2), Color(0, 0, 0, 0.4), true)
        draw_rect(Rect2(-car_w * 0.5, -car_h, car_w, car_h * 0.7), Color(0.85, 0.1, 0.1), true)
        draw_rect(Rect2(-car_w * 0.5, -car_h * 1.05, car_w, car_h * 0.15), Color(1, 1, 1), true)
        draw_rect(Rect2(-car_w * 0.55, -car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
        draw_rect(Rect2(car_w * 0.39, -car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
