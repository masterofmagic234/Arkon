extends Control

# Level 2 — ACORN GRAND PRIX.
# Оптимизированный Pseudo-3D рендерер.

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

# Кэшируем массивы для FPS
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
    if race_state == null or player_car == null or track_size == 0:
        return

    var vp: Vector2 = get_viewport_rect().size
    var w: float = vp.x
    # Жестко ограничиваем высоту рендера, чтобы HUD не съедал машину
    var draw_h: float = 496.0 
    var horizon_y: float = draw_h * HORIZON_FRACTION

    _draw_sky(w, horizon_y)
    _draw_road(w, draw_h, horizon_y)
    _draw_ai_cars(w, draw_h, horizon_y)
    _draw_player_car(w, draw_h)

func _draw_sky(w: float, horizon_y: float) -> void:
    var sky_points := PackedVector2Array([
        Vector2(0, 0), Vector2(w, 0),
        Vector2(w, horizon_y), Vector2(0, horizon_y)
    ])
    var sky_colors := PackedColorArray([
        COL_SKY_TOP, COL_SKY_TOP,
        COL_SKY_BOTTOM, COL_SKY_BOTTOM
    ])
    draw_polygon(sky_points, sky_colors)

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
    var cam_world_x: float = player_car.world_x
    var half_w := w * 0.5
    
    var lap_offset := player_car.lap
    var track_total_x := track_x[track_size - 1]

    for i in range(FAR_SEGMENTS):
        var idx: int = (cam_seg + i) % track_size
        
        # Плавиный сдвиг камеры (устраняет дергание)
        var dz: float = (float(i) - player_car.segment_progress) * SEGMENT_WORLD_LEN + CAMERA_BEHIND
        if dz < 0.1: dz = 0.1
        
        var scale: float = CAMERA_DEPTH / dz
        var seg_world_x: float = track_x[idx]
        
        # Бесшовный переход между кругами
        var current_lap := lap_offset
        if idx < cam_seg:
            current_lap += 1
        seg_world_x += float(current_lap) * track_total_x

        var rel_x: float = seg_world_x - cam_world_x

        ssx[i] = half_w + scale * rel_x * half_w
        ssy[i] = horizon_y + (h - horizon_y) * CAMERA_BEHIND / dz
        shw[i] = scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE
        sidx[i] = idx

    # Трава
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

    # Дорога (Алгоритм Художника: рисуем от дальнего к ближнему)
    for i in range(FAR_SEGMENTS - 2, -1, -1):
        if ssy[i] <= ssy[i + 1]:
            continue

        var l0 := Vector2(ssx[i] - shw[i], ssy[i])
        var r0 := Vector2(ssx[i] + shw[i], ssy[i])
        var l1 := Vector2(ssx[i + 1] - shw[i + 1], ssy[i + 1])
        var r1 := Vector2(ssx[i + 1] + shw[i + 1], ssy[i + 1])

        var dark: bool = (sidx[i] / 3) % 2 == 0
        var road_col: Color = COL_ROAD_DARK if dark else COL_ROAD_LIGHT

        # Основное полотно
        draw_colored_polygon(PackedVector2Array([l0, r0, r1, l1]), road_col)

        # Поребрики (полигонами в перспективе)
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

        # Разделительная полоса
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
    if player_car == null: return
    var cam_z: float = player_car.world_z
    var cam_x: float = player_car.world_x
    for ai_controller in ai_cars:
        if ai_controller == null or ai_controller.car == null: continue
        var ai = ai_controller.car
        var dz: float = ai.world_z - cam_z
        if dz < 1.0 or dz > 60.0: continue
        var scale: float = CAMERA_DEPTH / (dz + CAMERA_BEHIND)
        var sx: float = w * 0.5 + scale * (ai.world_x - cam_x) * w * 0.5
        var sy: float = horizon_y + (h - horizon_y) * CAMERA_BEHIND / (dz + CAMERA_BEHIND)
        if sy < horizon_y: continue
        var car_w: float = clampf(scale * 6.0 * w * 0.5, 6.0, 120.0)
        var car_h: float = car_w * 0.5
        draw_rect(Rect2(sx - car_w * 0.5, sy - car_h, car_w, car_h), Color(0.75, 0.15, 0.15), true)
        draw_rect(Rect2(sx - car_w * 0.4, sy - car_h * 0.7, car_w * 0.8, car_h * 0.3), Color(1.0, 1.0, 1.0), true)

func _draw_player_car(w: float, h: float) -> void:
    # Базируем кар над интерфейсом
    var base_y: float = h * 0.95 
    var car_w: float = w * 0.13
    var car_h: float = car_w * 0.55
    var cx: float = w * 0.5 + player_car.steer_in * w * 0.03
    draw_rect(Rect2(cx - car_w * 0.55, base_y + car_h * 0.1, car_w * 1.1, car_h * 0.2), Color(0, 0, 0, 0.4), true)
    draw_rect(Rect2(cx - car_w * 0.5, base_y - car_h, car_w, car_h * 0.7), Color(0.85, 0.1, 0.1), true)
    draw_rect(Rect2(cx - car_w * 0.5, base_y - car_h * 1.05, car_w, car_h * 0.15), Color(1, 1, 1), true)
    draw_rect(Rect2(cx - car_w * 0.55, base_y - car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
    draw_rect(Rect2(cx + car_w * 0.39, base_y - car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
