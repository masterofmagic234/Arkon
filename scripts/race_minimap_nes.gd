extends Control

const RaceMath = preload("res://scripts/race_math.gd")

var race_state = null
var player_car = null
var ai_cars: Array = []
var track_pattern: Array = []

var map_points: PackedVector2Array = PackedVector2Array()
var map_bounds: Rect2

func bind(state, player_ref, ais_ref: Array, pattern: Array, tx: PackedFloat32Array) -> void:
    race_state = state
    player_car = player_ref
    ai_cars = ais_ref
    track_pattern = pattern
    _build_map_geometry()

func _build_map_geometry() -> void:
    if track_pattern.is_empty():
        return

    map_points.clear()
    var current_pos := Vector2.ZERO
    var current_yaw := 0.0

    var min_x := 999999.0
    var min_y := 999999.0
    var max_x := -999999.0
    var max_y := -999999.0

    # Build a visual 2D projection of the same 1D segment ribbon used by the race.
    for seg in track_pattern:
        var curve: float = RaceMath.curve_of(seg)
        current_yaw += curve * 0.045

        var forward := Vector2(sin(current_yaw), -cos(current_yaw))
        current_pos += forward * 2.0
        map_points.append(current_pos)

        min_x = minf(min_x, current_pos.x)
        min_y = minf(min_y, current_pos.y)
        max_x = maxf(max_x, current_pos.x)
        max_y = maxf(max_y, current_pos.y)

    map_bounds = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    if map_points.is_empty():
        return

    var w: float = size.x
    var h: float = size.y
    draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.10, 0.05), true)

    var pad := 15.0
    var draw_w := w - pad * 2.0
    var draw_h := h - pad * 2.0

    var scale_x := draw_w / maxf(1.0, map_bounds.size.x)
    var scale_y := draw_h / maxf(1.0, map_bounds.size.y)
    var map_scale := minf(scale_x, scale_y)

    var offset_x := pad + (draw_w - map_bounds.size.x * map_scale) * 0.5
    var offset_y := pad + (draw_h - map_bounds.size.y * map_scale) * 0.5
    var center_offset := Vector2(offset_x, offset_y) - map_bounds.position * map_scale

    # Track outline.
    for i in map_points.size():
        var p1 = map_points[i] * map_scale + center_offset
        var p2 = map_points[(i + 1) % map_points.size()] * map_scale + center_offset
        draw_line(p1, p2, Color(0.40, 0.40, 0.45), 6.0, true)
        draw_line(p1, p2, Color(0.80, 0.80, 0.85), 2.0, true)

    # Start/finish marker.
    var p_start = map_points[0] * map_scale + center_offset
    draw_circle(p_start, 4.0, Color(1.0, 1.0, 0.2))

    # AI markers with smooth segment interpolation.
    for ai_ctrl in ai_cars:
        if ai_ctrl and ai_ctrl.car:
            var car = ai_ctrl.car
            var idx := car.segment_index % map_points.size()
            var next_idx := (idx + 1) % map_points.size()
            var ai_pos = map_points[idx].lerp(map_points[next_idx], car.segment_progress) * map_scale + center_offset
            draw_circle(ai_pos, 3.0, Color(0.9, 0.2, 0.2))

    # Player marker with smooth segment interpolation.
    if player_car:
        var idx := player_car.segment_index % map_points.size()
        var next_idx := (idx + 1) % map_points.size()
        var p_pos = map_points[idx].lerp(map_points[next_idx], player_car.segment_progress) * map_scale + center_offset
        draw_circle(p_pos, 4.5, Color.WHITE)
