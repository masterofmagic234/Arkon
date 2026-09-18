extends Control

# Level 2 — ACORN GRAND PRIX.
# NES/F1-style pseudo-3D renderer. The road is projected from the
# accumulated world-space track_x data, so bends are visible in perspective.

const CAMERA_DEPTH: float = 0.84
const CAMERA_BEHIND: float = 8.0
const CAMERA_HEIGHT: float = 6.0
const FAR_SEGMENTS: int = 100
const HORIZON_FRACTION: float = 0.40
# Tuned so the road fills roughly the lower 60-70% of a 16:9 viewport
# instead of becoming an oversized full-screen trapezoid.
const ROAD_SCREEN_SCALE: float = 0.65

const ROAD_WORLD_WIDTH: float = 9.0
const SEGMENT_WORLD_LEN: float = 1.8

const COL_SKY_TOP := Color(0.35, 0.55, 1.00)
const COL_SKY_BOTTOM := Color(0.60, 0.78, 1.00)
const COL_CITY := Color(0.28, 0.28, 0.48)
const COL_WINDOW := Color(1.00, 0.85, 0.40)
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

func _ready() -> void:
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
    if race_state == null or player_car == null or track_size == 0:
        return

    var vp: Vector2 = get_viewport_rect().size
    var w: float = vp.x
    var h: float = vp.y
    var horizon_y: float = h * HORIZON_FRACTION

    _draw_sky(w, horizon_y)
    _draw_road(w, h, horizon_y)
    _draw_ai_cars(w, h, horizon_y)
    _draw_player_car(w, h)

func _draw_sky(w: float, horizon_y: float) -> void:
    const STRIPS: int = 32
    for i in range(STRIPS):
        var t: float = float(i) / float(STRIPS - 1)
        var c: Color = COL_SKY_TOP.lerp(COL_SKY_BOTTOM, t)
        var y0: float = horizon_y * float(i) / float(STRIPS)
        var y1: float = horizon_y * float(i + 1) / float(STRIPS)
        draw_rect(Rect2(0.0, y0, w, y1 - y0 + 1.0), c, true)
    _draw_city(w, horizon_y)

func _draw_city(w: float, horizon_y: float) -> void:
    var seed_value: int = 7717
    var x: float = -10.0
    while x < w + 10.0:
        seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
        var bw: float = 20.0 + float(seed_value % 40)
        var bh: float = 14.0 + float((seed_value / 7) % 55)
        draw_rect(Rect2(x, horizon_y - bh, bw, bh), COL_CITY, true)

        var wx: float = x + 3.0
        while wx < x + bw - 3.0:
            var wy: float = horizon_y - bh + 4.0
            while wy < horizon_y - 4.0:
                seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
                if seed_value % 4 == 0:
                    draw_rect(Rect2(wx, wy, 2.0, 3.0), COL_WINDOW, true)
                wy += 6.0
            wx += 5.0
        x += bw + 3.0

func _draw_road(w: float, h: float, horizon_y: float) -> void:
    if track_size <= 0 or track_x.is_empty():
        return

    var cam_seg: int = clampi(player_car.segment_index, 0, track_size - 1)
    var cam_prog: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var base_z: float = (float(cam_seg) + cam_prog) * SEGMENT_WORLD_LEN

    # Camera reference is the track center at the current segment.
    # Player lateral steering remains a separate offset in the car state.
    var cam_world_x: float = track_x[cam_seg]

    var segs: Array[Dictionary] = []
    for i in range(FAR_SEGMENTS):
        var idx: int = (cam_seg + i) % track_size
        var z: float = base_z + float(i) * SEGMENT_WORLD_LEN
        var dz: float = z - base_z + CAMERA_BEHIND
        dz = maxf(dz, 0.5)

        var scale: float = CAMERA_DEPTH / dz
        var seg_world_x: float = track_x[idx]

        # Unwrap the circular track when the visible window crosses segment 0.
        if idx < cam_seg:
            seg_world_x += track_x[track_size - 1]

        var rel_x: float = seg_world_x - cam_world_x
        var sx: float = w * 0.5 + scale * rel_x * w * 0.5
        # At dz == CAMERA_BEHIND the nearest road slice reaches the bottom.
        # As dz grows, every slice converges toward the horizon.
        var sy: float = horizon_y + (h - horizon_y) * CAMERA_BEHIND / dz
        var half_px: float = scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE

        segs.append({
            "idx": idx,
            "sx": sx,
            "sy": sy,
            "half": half_px
        })

    segs.reverse()

    var prev_sy: float = horizon_y
    for s in segs:
        var sy: float = float(s["sy"])
        var sx: float = float(s["sx"])
        var half: float = float(s["half"])
        var idx: int = int(s["idx"])

        var y_top: float = minf(prev_sy, sy)
        var y_bot: float = maxf(prev_sy, sy)
        var band_h: float = maxf(1.0, y_bot - y_top)
        prev_sy = sy

        var dark: bool = (idx / 3) % 2 == 0
        var grass_col: Color = COL_GRASS_DARK if dark else COL_GRASS_LIGHT
        var road_col: Color = COL_ROAD_DARK if dark else COL_ROAD_LIGHT
        var rumble_col: Color = COL_RUMBLE_DARK if dark else COL_RUMBLE_LIGHT

        draw_rect(Rect2(0.0, y_top, w, band_h), grass_col, true)
        draw_rect(Rect2(sx - half, y_top, half * 2.0, band_h), road_col, true)

        var rumble_w: float = maxf(2.0, half * 0.08)
        draw_rect(Rect2(sx - half, y_top, rumble_w, band_h), rumble_col, true)
        draw_rect(Rect2(sx + half - rumble_w, y_top, rumble_w, band_h), rumble_col, true)

        # Dashed center line, NES-style.
        if not dark:
            var lane_w: float = maxf(1.0, half * 0.03)
            draw_rect(Rect2(sx - lane_w * 0.5, y_top, lane_w, band_h), COL_LANE, true)

        # Small white roadside markers.
        if i_from_near_segment(idx, cam_seg) % 4 == 0:
            var dot_w: float = maxf(1.5, half * 0.03)
            draw_rect(Rect2(sx - half * 0.5 - dot_w, y_top, dot_w, band_h), COL_LANE, true)
            draw_rect(Rect2(sx + half * 0.5, y_top, dot_w, band_h), COL_LANE, true)

        # Larger roadside posts every 8 visible segments.
        var visible_i: int = i_from_near_segment(idx, cam_seg)
        if visible_i >= 0 and visible_i % 8 == 0:
            var post_w: float = maxf(2.0, half * 0.08)
            var post_h: float = band_h * 3.0
            draw_rect(Rect2(sx - half - post_w * 2.0, y_top - post_h, post_w, post_h), COL_LANE, true)
            draw_rect(Rect2(sx + half + post_w, y_top - post_h, post_w, post_h), COL_LANE, true)

func i_from_near_segment(idx: int, cam_seg: int) -> int:
    var d: int = idx - cam_seg
    if d < 0:
        d += track_size
    return d

func _draw_ai_cars(w: float, h: float, horizon_y: float) -> void:
    if player_car == null:
        return

    var cam_z: float = player_car.world_z
    var cam_x: float = player_car.world_x

    for ai_controller in ai_cars:
        if ai_controller == null or ai_controller.car == null:
            continue

        var ai = ai_controller.car
        var dz: float = ai.world_z - cam_z
        if dz < 1.0 or dz > 60.0:
            continue

        var scale: float = CAMERA_DEPTH / (dz + CAMERA_BEHIND)
        var sx: float = w * 0.5 + scale * (ai.world_x - cam_x) * w * 0.5
        var sy: float = horizon_y + (h - horizon_y) * CAMERA_BEHIND / (dz + CAMERA_BEHIND)

        if sy < horizon_y:
            continue

        var car_w: float = clampf(scale * 6.0 * w * 0.5, 6.0, 120.0)
        var car_h: float = car_w * 0.5
        draw_rect(Rect2(sx - car_w * 0.5, sy - car_h, car_w, car_h), Color(0.75, 0.15, 0.15), true)
        draw_rect(Rect2(sx - car_w * 0.4, sy - car_h * 0.7, car_w * 0.8, car_h * 0.3), Color(1.0, 1.0, 1.0), true)

func _draw_player_car(w: float, h: float) -> void:
    var base_y: float = h * 0.82
    var car_w: float = w * 0.13
    var car_h: float = car_w * 0.55
    var cx: float = w * 0.5 + player_car.steer_in * w * 0.03

    draw_rect(Rect2(cx - car_w * 0.55, base_y + car_h * 0.1, car_w * 1.1, car_h * 0.2), Color(0, 0, 0, 0.4), true)
    draw_rect(Rect2(cx - car_w * 0.5, base_y - car_h, car_w, car_h * 0.7), Color(0.85, 0.1, 0.1), true)
    draw_rect(Rect2(cx - car_w * 0.5, base_y - car_h * 1.05, car_w, car_h * 0.15), Color(1, 1, 1), true)
    draw_rect(Rect2(cx - car_w * 0.55, base_y - car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
    draw_rect(Rect2(cx + car_w * 0.39, base_y - car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
