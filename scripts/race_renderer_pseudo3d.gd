extends Node2D

const RaceMath = preload("res://scripts/race_math.gd")

const CAMERA_DEPTH := 0.8
const CAMERA_BEHIND := 12.0
const CAMERA_HEIGHT := 10.0
const FAR_SEGMENTS := 90
const HORIZON_FRACTION := 0.42
const ROAD_WORLD_WIDTH := 9.0
const SEGMENT_WORLD_LEN := 1.8

const COL_SKY_TOP := Color(0.30, 0.42, 0.90)
const COL_SKY_BOTTOM := Color(0.55, 0.70, 0.95)
const COL_GRASS_LIGHT := Color(0.30, 0.78, 0.28)
const COL_GRASS_DARK := Color(0.20, 0.55, 0.18)
const COL_ROAD_LIGHT := Color(0.55, 0.55, 0.58)
const COL_ROAD_DARK := Color(0.42, 0.42, 0.46)
const COL_RUMBLE_LIGHT := Color(0.95, 0.95, 0.95)
const COL_RUMBLE_DARK := Color(0.85, 0.20, 0.20)
const COL_LANE := Color(0.90, 0.90, 0.90)

var race_state = null
var player_car = null
var ai_cars: Array = []
var track_pattern: Array = []
var track_x: PackedFloat32Array = PackedFloat32Array()
var track_size: int = 0
var _draw_logged := false

func _ready() -> void:
    print("LEVEL2 RENDERER READY: viewport=", get_viewport_rect().size)
    queue_redraw()
var _draw_logged := false

func _ready() -> void:
    print("LEVEL2 RENDERER READY: viewport=", get_viewport_rect().size)
    queue_redraw()

func bind(state, player_ref, ais_ref: Array, pattern: Array, tx: PackedFloat32Array) -> void:
    race_state = state
    player_car = player_ref
    ai_cars = ais_ref
    track_pattern = pattern
    track_x = tx
    track_size = pattern.size()
    print("LEVEL2 RENDERER BIND: track_size=", track_size, " player=", player_car != null, " state=", race_state != null)
    queue_redraw()
    print("LEVEL2 RENDERER BIND: track_size=", track_size, " player=", player_car != null, " state=", race_state != null)
    queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var vp := get_viewport_rect().size
    var w: float = vp.x
    var h: float = vp.y
    if not _draw_logged:
        _draw_logged = true
        print("LEVEL2 RENDERER DRAW: viewport=", vp, " track_size=", track_size, " bound=", race_state != null and player_car != null)

    # The background is independent from race binding. This makes renderer
    # execution visually testable before race math/projection is involved.
    draw_rect(Rect2(0, 0, w, h), Color(0.06, 0.08, 0.14), true)
    _draw_sky(w, h * HORIZON_FRACTION)

    if race_state == null or player_car == null or track_size == 0:
        return

    var horizon_y: float = h * HORIZON_FRACTION
    _draw_road(w, h, horizon_y)
    _draw_ai_cars(w, h, horizon_y)
    _draw_player_car(w, h)

func _draw_sky(w: float, horizon_y: float) -> void:
    var strips := 24
    for i in strips:
        var t := float(i) / float(strips - 1)
        var c := COL_SKY_TOP.lerp(COL_SKY_BOTTOM, t)
        var y0 := horizon_y * float(i) / float(strips)
        var y1 := horizon_y * float(i + 1) / float(strips)
        draw_rect(Rect2(0, y0, w, y1 - y0 + 1), c, true)
    _draw_city(w, horizon_y)

func _draw_city(w: float, horizon_y: float) -> void:
    var city := Color(0.30, 0.30, 0.45)
    var seed_value: int = 12345
    var x: float = -20.0
    while x < w + 20.0:
        seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
        var bw := 12.0 + float(seed_value % 30)
        var bh := 8.0 + float((seed_value / 7) % 40)
        draw_rect(Rect2(x, horizon_y - bh, bw, bh), city, true)
        x += bw + 4.0

func _draw_road(w: float, h: float, horizon_y: float) -> void:
    var cam_seg: int = player_car.segment_index
    var cam_prog: float = player_car.segment_progress
    var base_z := float(cam_seg) * SEGMENT_WORLD_LEN + cam_prog * SEGMENT_WORLD_LEN
    var segs: Array = []
    var cum_x := 0.0
    var cum_dx := 0.0

    for i in range(FAR_SEGMENTS):
        var idx := (cam_seg + i) % track_size
        var seg_curve := RaceMath.curve_of(track_pattern[idx]) * 0.02
        cum_dx += seg_curve
        cum_x += cum_dx
        var z := base_z + float(i) * SEGMENT_WORLD_LEN
        var dz := z - (base_z - CAMERA_BEHIND)
        dz = maxf(dz, 0.5)
        var scale := CAMERA_DEPTH / dz
        var sx := w * 0.5 - cum_x * w * 0.5
        var sy := horizon_y + (CAMERA_HEIGHT * h * 0.70) / dz
        var half_px := scale * (ROAD_WORLD_WIDTH * 0.5) * w * 0.5
        segs.append({"idx": idx, "sx": sx, "sy": sy, "half": half_px})

    segs.reverse()
    for s in segs:
        var sy: float = s["sy"]
        if sy < horizon_y:
            continue
        var sx: float = s["sx"]
        var half: float = s["half"]
        var idx: int = s["idx"]
        var band_h := maxf(4.0, sy * 0.02)
        var dark := (idx / 3) % 2 == 0
        draw_rect(Rect2(0, sy - band_h, w, band_h), COL_GRASS_DARK if dark else COL_GRASS_LIGHT, true)
        draw_rect(Rect2(sx - half, sy - band_h, half * 2.0, band_h), COL_ROAD_DARK if dark else COL_ROAD_LIGHT, true)
        var rumble_w := maxf(2.0, half * 0.10)
        draw_rect(Rect2(sx - half, sy - band_h, rumble_w, band_h), COL_RUMBLE_DARK if dark else COL_RUMBLE_LIGHT, true)
        draw_rect(Rect2(sx + half - rumble_w, sy - band_h, rumble_w, band_h), COL_RUMBLE_DARK if dark else COL_RUMBLE_LIGHT, true)
        if not dark:
            var lane_w := maxf(1.5, half * 0.04)
            draw_rect(Rect2(sx - lane_w * 0.5, sy - band_h, lane_w, band_h), COL_LANE, true)

func _draw_ai_cars(w: float, h: float, horizon_y: float) -> void:
    var cam_z: float = player_car.world_z
    var cam_x: float = player_car.world_x
    for ai in ai_cars:
        var dz: float = ai.world_z - cam_z
        if dz < 1.0 or dz > 60.0:
            continue
        var scale := CAMERA_DEPTH / dz
        var sx := w * 0.5 + (ai.world_x - cam_x) * scale * w * 0.5
        var sy := horizon_y + scale * CAMERA_DEPTH * CAMERA_HEIGHT * (h - horizon_y) * 0.16
        if sy < horizon_y:
            continue
        var car_w := clampf(scale * 6.0 * w * 0.5, 6.0, 90.0)
        var car_h := car_w * 0.55
        draw_rect(Rect2(sx - car_w * 0.5, sy - car_h, car_w, car_h), Color(0.75, 0.20, 0.20), true)
        draw_rect(Rect2(sx - car_w * 0.5, sy - car_h * 0.5, car_w, car_h * 0.5), Color(0.55, 0.12, 0.12), true)

func _draw_player_car(w: float, h: float) -> void:
    var base_y := h * 0.72
    var car_w := w * 0.11
    var car_h := car_w * 0.55
    var cx := w * 0.5 + player_car.steer_in * w * 0.02
    draw_rect(Rect2(cx - car_w * 0.55, base_y + car_h * 0.10, car_w * 1.10, car_h * 0.20), Color(0, 0, 0, 0.35), true)
    draw_rect(Rect2(cx - car_w * 0.5, base_y - car_h, car_w, car_h * 0.7), Color(0.85, 0.10, 0.10), true)
    draw_rect(Rect2(cx - car_w * 0.45, base_y - car_h * 1.05, car_w * 0.9, car_h * 0.15), Color(0.95, 0.95, 0.95), true)
    draw_rect(Rect2(cx - car_w * 0.55, base_y - car_h * 0.55, car_w * 0.14, car_h * 0.45), Color(0.10, 0.10, 0.10), true)
    draw_rect(Rect2(cx + car_w * 0.41, base_y - car_h * 0.55, car_w * 0.14, car_h * 0.45), Color(0.10, 0.10, 0.10), true)
