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
const ASPHALT_UV_PER_SEGMENT: float = 1.25
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
        var distance_segments: float = float(i) / float(VISUAL_SUBDIVISIONS)
        var absolute_seg: float = float(cam_seg) + distance_segments
        var road_center_x: float = _smooth_track_x(absolute_seg) - camera_track_x

        var dz: float = (distance_segments - cam_progress) * RaceLevelData.SEGMENT_HEIGHT + CAMERA_BEHIND
        var next_dz: float = (float(i + 1) / float(VISUAL_SUBDIVISIONS) - cam_progress) * RaceLevelData.SEGMENT_HEIGHT + CAMERA_BEHIND
        dz = maxf(1.0, dz)
        next_dz = maxf(1.0, next_dz)

        var scale: float = CAMERA_DEPTH / dz
        var next_scale: float = CAMERA_DEPTH / next_dz

        ssx[i] = half_w + scale * road_center_x * half_w
        ssy[i] = horizon_y + (h - horizon_y) * CAMERA_BEHIND / dz
        shw[i] = scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE
        sidx[i] = posmod(int(floor(absolute_seg)), track_size)

        if i + 1 < FAR_SEGMENTS:
            var next_absolute_seg: float = absolute_seg + 1.0 / float(VISUAL_SUBDIVISIONS)
            var next_center_x: float = _smooth_track_x(next_absolute_seg) - camera_track_x
            ssx[i + 1] = half_w + next_scale * next_center_x * half_w
            ssy[i + 1] = horizon_y + (h - horizon_y) * CAMERA_BEHIND / next_dz
            shw[i + 1] = next_scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE


    # Grass follows the same perspective bands as the old speed simulation.
    # Each side is a trapezoid per road step, so the texture never sits as a
    # flat full-screen overlay on top of the race surface.
    const GRASS_UV_PER_SEGMENT: float = 0.90
    const GRASS_UV_ACROSS: float = 4.0

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

            var grass_band: int = int(floor(float(cam_seg) + float(gi) / float(VISUAL_SUBDIVISIONS)))
            var grass_tint: Color = COL_GRASS_LIGHT if posmod(grass_band, 2) == 0 else COL_GRASS_DARK
            var v0: float = float(grass_band) * GRASS_UV_PER_SEGMENT
            var v1: float = v0 + GRASS_UV_PER_SEGMENT * float(gj - gi) / float(VISUAL_SUBDIVISIONS)

            var left_points := PackedVector2Array([gl0, road_l0, road_l1, gl1])
            var right_points := PackedVector2Array([road_r0, gr0, gr1, road_r1])
            var grass_uvs := PackedVector2Array([
                Vector2(0.0, v0),
                Vector2(GRASS_UV_ACROSS, v0),
                Vector2(GRASS_UV_ACROSS, v1),
                Vector2(0.0, v1)
            ])

            if grass_texture != null:
                var grass_cols := PackedColorArray([grass_tint, grass_tint, grass_tint, grass_tint])
                draw_polygon(left_points, grass_cols, grass_uvs, grass_texture)
                draw_polygon(right_points, grass_cols, grass_uvs, grass_texture)
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

func _draw_props(w: float, _h: float, horizon_y: float) -> void:
    if oak_texture == null and pine_texture == null and lamp_texture == null:
        return

    # Sparse roadside props: enough to establish the NES roadside silhouette
    # without turning every segment into a transparent-texture draw call.
    var i: int = FAR_SEGMENTS - 6
    while i >= 0:
        if ssy[i] > horizon_y + 2.0:
            var road_cx: float = ssx[i]
            var road_half: float = shw[i]
            var prop_scale: float = clampf(road_half / 70.0, 0.12, 1.8)
            var side: float = -1.0 if posmod(sidx[i], 2) == 0 else 1.0
            # Keep roadside objects just outside the road edge. The old 1.55
            # multiplier pushed close props outside the viewport as the road
            # widened toward the camera, making them appear to vanish.
            var outer_x: float = road_cx + side * road_half * 1.05

            if posmod(sidx[i], 6) == 0 and lamp_texture != null:
                _draw_billboard(lamp_texture, outer_x, ssy[i], 34.0 * prop_scale, 92.0 * prop_scale)
            elif posmod(sidx[i], 3) == 0:
                var tree_tex: Texture2D = pine_texture if (posmod(sidx[i] / 3, 2) == 0 and pine_texture != null) else oak_texture
                if tree_tex != null:
                    _draw_billboard(tree_tex, outer_x, ssy[i], 110.0 * prop_scale, 150.0 * prop_scale)
        i -= 8

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
    var cx: float = w * 0.5 + lateral * w * PLAYER_LATERAL_SCREEN_SCALE

    if oka_texture != null:
        _draw_billboard(oka_texture, cx, base_y, car_w * 1.55, car_h * 1.75)
    else:
        draw_rect(Rect2(cx - car_w * 0.55, base_y + car_h * 0.1, car_w * 1.1, car_h * 0.2), Color(0, 0, 0, 0.4), true)
        draw_rect(Rect2(cx - car_w * 0.5, base_y - car_h, car_w, car_h * 0.7), Color(0.85, 0.1, 0.1), true)
        draw_rect(Rect2(cx - car_w * 0.5, base_y - car_h * 1.05, car_w, car_h * 0.15), Color(1, 1, 1), true)
        draw_rect(Rect2(cx - car_w * 0.55, base_y - car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
        draw_rect(Rect2(cx + car_w * 0.39, base_y - car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
