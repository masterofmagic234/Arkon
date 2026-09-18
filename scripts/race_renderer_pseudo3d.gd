extends Node2D

const RaceMath = preload("res://scripts/race_math.gd")

const CAMERA_DEPTH := 0.84
const CAMERA_BEHIND := 6.0
const CAMERA_HEIGHT := 6.0
const FAR_SEGMENTS := 120
const HORIZON_FRACTION := 0.42
const ROAD_SCREEN_SCALE := 1.9
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

func bind(state, player_ref, ais_ref: Array, pattern: Array, tx: PackedFloat32Array) -> void:
    race_state = state
    player_car = player_ref
    ai_cars = ais_ref
    track_pattern = pattern
    track_x = tx
    track_size = pattern.size()
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
    if track_size <= 0 or track_x.is_empty():
        return

    var cam_seg: int = clampi(player_car.segment_index, 0, track_size - 1)
    var cam_world_x: float = track_x[cam_seg]

    var ssx: PackedFloat32Array = PackedFloat32Array()
    var ssy: PackedFloat32Array = PackedFloat32Array()
    var shw: PackedFloat32Array = PackedFloat32Array()
    var sidx: PackedInt32Array = PackedInt32Array()

    for i in range(FAR_SEGMENTS):
        var idx: int = (cam_seg + i) % track_size
        var dz: float = float(i) * SEGMENT_WORLD_LEN + CAMERA_BEHIND
        var scale: float = CAMERA_DEPTH / dz

        var seg_world_x: float = track_x[idx]
        # Unwrap the circular track when the visible window crosses segment 0.
        if idx < cam_seg:
            seg_world_x += track_x[track_size - 1]

        var rel_x: float = seg_world_x - cam_world_x
        var sx: float = w * 0.5 + scale * rel_x * w * 0.5
        var sy: float = horizon_y + (h - horizon_y) * CAMERA_BEHIND / dz
        var half: float = scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE

        ssx.append(sx)
        ssy.append(sy)
        shw.append(half)
        sidx.append(idx)

    # Fill the grass first, then connect adjacent road slices into perspective quads.
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

    for i in range(FAR_SEGMENTS - 1):
        var l0: Vector2 = Vector2(ssx[i] - shw[i], ssy[i])
        var r0: Vector2 = Vector2(ssx[i] + shw[i], ssy[i])
        var l1: Vector2 = Vector2(ssx[i + 1] - shw[i + 1], ssy[i + 1])
        var r1: Vector2 = Vector2(ssx[i + 1] + shw[i + 1], ssy[i + 1])
        var dark: bool = (sidx[i] / 3) % 2 == 0
        var road_col: Color = COL_ROAD_DARK if dark else COL_ROAD_LIGHT
        draw_colored_polygon(PackedVector2Array([l0, r0, r1, l1]), road_col)

    # Dashed center line.
    for i in range(FAR_SEGMENTS - 1):
        if (sidx[i] / 3) % 2 == 0:
            continue

        var sx: float = ssx[i]
        var half: float = shw[i]
        var y0: float = ssy[i + 1]
        var y1: float = ssy[i]

        if y1 > y0:
            var lane_w: float = maxf(1.0, half * 0.03)
            draw_rect(Rect2(sx - lane_w * 0.5, y0, lane_w, y1 - y0), COL_LANE, true)

    # Rumble strips.
    for i in range(FAR_SEGMENTS - 1):
        var sx: float = ssx[i]
        var half: float = shw[i]
        var y0: float = ssy[i + 1]
        var y1: float = ssy[i]

        if y1 <= y0:
            continue

        var rumble_w: float = maxf(1.5, half * 0.07)
        var dark: bool = (sidx[i] / 3) % 2 == 0
        var rumble_col: Color = COL_RUMBLE_DARK if dark else COL_RUMBLE_LIGHT
        draw_rect(Rect2(sx - half, y0, rumble_w, y1 - y0), rumble_col, true)
        draw_rect(Rect2(sx + half - rumble_w, y0, rumble_w, y1 - y0), rumble_col, true)

