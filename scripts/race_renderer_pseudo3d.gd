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
    ssx.resize(FAR_SEGMENTS)
    ssy.resize(FAR_SEGMENTS)
    shw.resize(FAR_SEGMENTS)
    sidx.resize(FAR_SEGMENTS)
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
    const STRIPS: int = 32
    var sky_top := COL_SKY_TOP
    var sky_bottom := COL_SKY_BOTTOM

    for i in range(STRIPS):
        var t: float = float(i) / float(STRIPS - 1)
        var c: Color = sky_top.lerp(sky_bottom, t)
        var y0: float = horizon_y * float(i) / float(STRIPS)
        var y1: float = horizon_y * float(i + 1) / float(STRIPS)
        draw_rect(Rect2(0.0, y0, w, y1 - y0 + 1.0), c, true)

    var city: Texture2D = _find_tex([
        "res://assets/city_night.png",
        "res://city_night.png"
    ])
    if city != null:
        draw_texture_rect(city, Rect2(0.0, horizon_y * 0.42, w, horizon_y * 0.58), false)
    else:
        var seed_value: int = 7717
        var x: float = -10.0
        while x < w + 10.0:
            seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
            var bw: float = 20.0 + float(seed_value % 40)
            var bh: float = 14.0 + float((seed_value / 7) % 55)
            draw_rect(Rect2(x, horizon_y - bh, bw, bh), COL_CITY, true)
            x += bw + 3.0

    var moon: Texture2D = _find_tex([
        "res://assets/moon.png",
        "res://moon.png"
    ])
    if moon != null:
        var moon_size := minf(horizon_y * 0.38, w * 0.20)
        draw_texture_rect(
            moon,
            Rect2(w * 0.72, horizon_y * 0.08, moon_size, moon_size),
            false,
            Color(1.0, 1.0, 1.0, 0.92)
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

    var grass: Texture2D = _find_tex([
        "res://assets/grass_tile.png",
        "res://assets/grass.png"
    ])
    if grass != null:
        draw_texture_rect(grass, Rect2(0.0, horizon_y, w, h - horizon_y), true)
    else:
        draw_rect(Rect2(0.0, horizon_y, w, h - horizon_y), COL_GRASS_DARK, true)

    var asphalt: Texture2D = _find_tex([
        "res://assets/asphalt.png",
        "res://asphalt.png"
    ])
    var rumble: Texture2D = _find_tex([
        "res://assets/rumble.png",
        "res://rumble.png"
    ])

    # Draw paired visual subdivisions. This keeps the road curved while
    # cutting textured-road draw calls roughly in half on mobile.
    const ROAD_STEP: int = 2
    var i: int = FAR_SEGMENTS - 2
    while i >= 0:
        var j: int = min(i + ROAD_STEP, FAR_SEGMENTS - 1)
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

            if asphalt != null:
                draw_colored_polygon(road_points, Color.WHITE, road_uvs, asphalt)
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

            if rumble != null:
                draw_colored_polygon(left_rumble, Color.WHITE, road_uvs, rumble)
                draw_colored_polygon(right_rumble, Color.WHITE, road_uvs, rumble)
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
    var oak: Texture2D = _find_tex([
        "res://assets/oak_tree.png",
        "res://oak_tree.png"
    ])
    var pine: Texture2D = _find_tex([
        "res://assets/pine_tree.png",
        "res://pine_tree.png"
    ])
    var lamp: Texture2D = _find_tex([
        "res://assets/street_lamp.png",
        "res://street_lamp.png"
    ])

    if oak == null and pine == null and lamp == null:
        return

    # Sparse roadside props: enough to establish the NES roadside silhouette
    # without turning every segment into a transparent-texture draw call.
    var i: int = FAR_SEGMENTS - 8
    while i >= 8:
        if ssy[i] > horizon_y + 2.0:
            var road_cx: float = ssx[i]
            var road_half: float = shw[i]
            var prop_scale: float = clampf(road_half / 70.0, 0.16, 2.6)
            var side: float = -1.0 if posmod(sidx[i], 2) == 0 else 1.0
            var outer_x: float = road_cx + side * road_half * 1.55

            if posmod(sidx[i], 6) == 0 and lamp != null:
                _draw_billboard(lamp, outer_x, ssy[i], 34.0 * prop_scale, 92.0 * prop_scale)
            elif posmod(sidx[i], 3) == 0:
                var tree_tex: Texture2D = pine if (posmod(sidx[i] / 3, 2) == 0 and pine != null) else oak
                if tree_tex != null:
                    _draw_billboard(tree_tex, outer_x, ssy[i], 110.0 * prop_scale, 150.0 * prop_scale)
        i -= 24

func _draw_ai_cars(w: float, h: float, horizon_y: float) -> void:
    if player_car == null:
        return

    var p_prog: float = player_car.progress(track_size)
    var half_road: float = ROAD_WORLD_WIDTH * 0.5
    var squirrel_mobile: Texture2D = _find_tex([
        "res://assets/squirrel_mobile.png",
        "res://squirrel_mobile.png"
    ])

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

        if squirrel_mobile != null:
            _draw_billboard(squirrel_mobile, sx, sy, car_w * 1.25, car_h * 1.55)
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
    var base_y: float = h * 0.96
    var car_w: float = w * 0.13
    var car_h: float = car_w * 0.55

    var cam_seg: int = player_car.segment_index % track_size
    var cam_progress: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var camera_track_x: float = _smooth_track_x(float(cam_seg) + cam_progress)
    var half_road: float = ROAD_WORLD_WIDTH * 0.5
    var lateral: float = 0.0
    if half_road > 0.0:
        lateral = clampf((player_car.world_x - camera_track_x) / half_road, -1.0, 1.0)
    var cx: float = w * 0.5 + lateral * w * PLAYER_LATERAL_SCREEN_SCALE

    var oka: Texture2D = _find_tex([
        "res://assets/oka.png",
        "res://oka.png"
    ])
    if oka != null:
        _draw_billboard(oka, cx, base_y, car_w * 1.55, car_h * 1.75)
    else:
        draw_rect(Rect2(cx - car_w * 0.55, base_y + car_h * 0.1, car_w * 1.1, car_h * 0.2), Color(0, 0, 0, 0.4), true)
        draw_rect(Rect2(cx - car_w * 0.5, base_y - car_h, car_w, car_h * 0.7), Color(0.85, 0.1, 0.1), true)
        draw_rect(Rect2(cx - car_w * 0.5, base_y - car_h * 1.05, car_w, car_h * 0.15), Color(1, 1, 1), true)
        draw_rect(Rect2(cx - car_w * 0.55, base_y - car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
        draw_rect(Rect2(cx + car_w * 0.39, base_y - car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
