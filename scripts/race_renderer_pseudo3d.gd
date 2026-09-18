extends Node2D

const CAMERA_DEPTH: float = 0.84
const CAMERA_BEHIND: float = 6.0
const FAR_SEGMENTS: int = 120
const HORIZON_FRACTION: float = 0.42
const ROAD_SCREEN_SCALE: float = 1.9
const ROAD_WORLD_WIDTH: float = 9.0
const SEGMENT_WORLD_LEN: float = 1.8

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
    queue_redraw()

func _draw() -> void:
    if race_state == null or player_car == null or track_size == 0 or track_x.is_empty():
        return

    var vp: Vector2 = get_viewport_rect().size
    var w: float = vp.x
    # TODO: В будущем получать эту границу динамически от UI-слоя.
    var draw_h: float = 496.0
    var horizon_y: float = draw_h * HORIZON_FRACTION

    _draw_sky(w, horizon_y)
    _draw_road(w, draw_h, horizon_y)
    _draw_ai_cars(w, draw_h, horizon_y)
    _draw_player_car(w, draw_h)

func _draw_sky(w: float, horizon_y: float) -> void:
    const STRIPS: int = 32
    for i in range(STRIPS):
        var t: float = float(i) / float(STRIPS - 1)
        var c: Color = COL_SKY_TOP.lerp(COL_SKY_BOTTOM, t)
        var y0: float = horizon_y * float(i) / float(STRIPS)
        var y1: float = horizon_y * float(i + 1) / float(STRIPS)
        draw_rect(Rect2(0.0, y0, w, y1 - y0 + 1.0), c, true)

    var seed_value: int = 7717
    var x: float = -10.0
    while x < w + 10.0:
        seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
        var bw: float = 20.0 + float(seed_value % 40)
        var bh: float = 14.0 + float((seed_value / 7) % 55)
        draw_rect(Rect2(x, horizon_y - bh, bw, bh), COL_CITY, true)
        x += bw + 3.0

func _draw_road(w: float, h: float, horizon_y: float) -> void:
    var cam_seg: int = player_car.segment_index % track_size
    var cam_progress: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var half_w: float = w * 0.5

    # track_x is a lateral road-center coordinate, not a longitudinal lap distance.
    # Interpolate the camera center so the road does not jump at segment boundaries.
    var next_cam_seg: int = (cam_seg + 1) % track_size
    var current_track_x: float = lerpf(
        track_x[cam_seg],
        track_x[next_cam_seg],
        cam_progress
    )

    # Build a connected perspective strip from near to far.
    for i in range(FAR_SEGMENTS):
        var idx: int = (cam_seg + i) % track_size
        var next_idx: int = (idx + 1) % track_size

        var dz: float = (float(i) - cam_progress) * SEGMENT_WORLD_LEN + CAMERA_BEHIND
        dz = maxf(1.0, dz)

        var next_dz: float = (float(i + 1) - cam_progress) * SEGMENT_WORLD_LEN + CAMERA_BEHIND
        next_dz = maxf(1.0, next_dz)

        var scale: float = CAMERA_DEPTH / dz
        var next_scale: float = CAMERA_DEPTH / next_dz

        var rel_x: float = track_x[idx] - current_track_x
        var next_rel_x: float = track_x[next_idx] - current_track_x

        ssx[i] = half_w + scale * rel_x * half_w
        ssy[i] = horizon_y + (h - horizon_y) * CAMERA_BEHIND / dz
        shw[i] = scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE
        sidx[i] = idx

        # Keep the next point available for the connected quad.
        if i + 1 < FAR_SEGMENTS:
            ssx[i + 1] = half_w + next_scale * next_rel_x * half_w
            ssy[i + 1] = horizon_y + (h - horizon_y) * CAMERA_BEHIND / next_dz
            shw[i + 1] = next_scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE

    var prev_y: float = h
    for i in range(FAR_SEGMENTS):
        var sy: float = ssy[i]
        if prev_y > sy:
            var dark: bool = (sidx[i] / 3) % 2 == 0
            var grass_col: Color = COL_GRASS_DARK if dark else COL_GRASS_LIGHT
            draw_rect(Rect2(0.0, sy, w, prev_y - sy), grass_col, true)
        prev_y = sy

    if prev_y > horizon_y:
        draw_rect(Rect2(0.0, horizon_y, w, prev_y - horizon_y), COL_GRASS_DARK, true)

    for i in range(FAR_SEGMENTS - 2, -1, -1):
        if ssy[i] <= ssy[i + 1]:
            continue

        var l0 := Vector2(ssx[i] - shw[i], ssy[i])
        var r0 := Vector2(ssx[i] + shw[i], ssy[i])
        var l1 := Vector2(ssx[i + 1] - shw[i + 1], ssy[i + 1])
        var r1 := Vector2(ssx[i + 1] + shw[i + 1], ssy[i + 1])

        var dark: bool = (sidx[i] / 3) % 2 == 0
        var road_col: Color = COL_ROAD_DARK if dark else COL_ROAD_LIGHT
        draw_colored_polygon(PackedVector2Array([l0, r0, r1, l1]), road_col)

        if sidx[i] == 0:
            var m0 = l0.lerp(r0, 0.5)
            var m1 = l1.lerp(r1, 0.5)
            draw_colored_polygon(PackedVector2Array([l0, m0, m1, l1]), Color.WHITE)
            draw_colored_polygon(PackedVector2Array([m0, r0, r1, m1]), Color.BLACK)


        var rw0: float = maxf(2.0, shw[i] * 0.12)
        var rw1: float = maxf(2.0, shw[i + 1] * 0.12)
        var rumb_col: Color = COL_RUMBLE_DARK if dark else COL_RUMBLE_LIGHT

        draw_colored_polygon(PackedVector2Array([
            l0, Vector2(l0.x + rw0, l0.y),
            Vector2(l1.x + rw1, l1.y), l1
        ]), rumb_col)

        draw_colored_polygon(PackedVector2Array([
            Vector2(r0.x - rw0, r0.y), r0,
            r1, Vector2(r1.x - rw1, r1.y)
        ]), rumb_col)

        if not dark:
            var lw0: float = maxf(2.0, shw[i] * 0.04)
            var lw1: float = maxf(2.0, shw[i + 1] * 0.04)
            var cx0: float = ssx[i]
            var cx1: float = ssx[i + 1]

            draw_colored_polygon(PackedVector2Array([
                Vector2(cx0 - lw0 * 0.5, ssy[i]),
                Vector2(cx0 + lw0 * 0.5, ssy[i]),
                Vector2(cx1 + lw1 * 0.5, ssy[i + 1]),
                Vector2(cx1 - lw1 * 0.5, ssy[i + 1])
            ]), COL_LANE)

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

        # Only draw cars that are ahead and inside the visible perspective strip.
        if delta_segments < 0.5 or delta_segments >= float(FAR_SEGMENTS - 2):
            continue

        var i_fl: int = int(floor(delta_segments))
        if i_fl < 0 or i_fl + 1 >= ssx.size():
            continue

        var t: float = delta_segments - float(i_fl)

        # track_x is the physical lateral center of the road at the AI's segment.
        # world_x is the AI's lateral coordinate.
        var ai_seg: int = ai.segment_index % track_size
        var ai_track_center: float = track_x[ai_seg]
        var norm_offset: float = (ai.world_x - ai_track_center) / half_road
        norm_offset = clampf(norm_offset, -1.25, 1.25)

        # Use the exact road geometry already projected by _draw_road.
        var road_cx: float = lerpf(ssx[i_fl], ssx[i_fl + 1], t)
        var current_shw: float = lerpf(shw[i_fl], shw[i_fl + 1], t)

        var dz: float = delta_segments * SEGMENT_WORLD_LEN + CAMERA_BEHIND
        dz = maxf(1.0, dz)

        var scale: float = CAMERA_DEPTH / dz
        var sy: float = horizon_y + (h - horizon_y) * CAMERA_BEHIND / dz

        if sy < horizon_y or sy > h:
            continue

        var sx: float = road_cx + norm_offset * current_shw

        var car_w: float = clampf(scale * ROAD_WORLD_WIDTH * w * 0.35, 6.0, 180.0)
        var car_h: float = car_w * 0.5

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
    var cx: float = w * 0.5 + player_car.steer_in * w * 0.03

    draw_rect(Rect2(cx - car_w * 0.55, base_y + car_h * 0.1, car_w * 1.1, car_h * 0.2), Color(0, 0, 0, 0.4), true)
    draw_rect(Rect2(cx - car_w * 0.5, base_y - car_h, car_w, car_h * 0.7), Color(0.85, 0.1, 0.1), true)
    draw_rect(Rect2(cx - car_w * 0.5, base_y - car_h * 1.05, car_w, car_h * 0.15), Color(1, 1, 1), true)
    draw_rect(Rect2(cx - car_w * 0.55, base_y - car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
    draw_rect(Rect2(cx + car_w * 0.39, base_y - car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
