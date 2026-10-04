extends Control

const RaceMath = preload("res://scripts/race_math.gd")

var racers: Array = []
var track_pattern: Array = []
var racer_progress: Dictionary = {}
var signal_bus: Node = null

var map_points: PackedVector2Array = PackedVector2Array()
var map_bounds: Rect2

func bind(racers_ref: Array, pattern: Array) -> void:
    signal_bus = get_node_or_null("/root/SignalBus")
    if signal_bus == null:
        push_error("[Level2] Minimap: SignalBus autoload is unavailable.")
        return
    var callback := Callable(self, "_on_racer_progress_changed")
    if signal_bus.is_connected("racer_progress_changed", callback):
        signal_bus.disconnect("racer_progress_changed", callback)

    racers = racers_ref.duplicate()
    track_pattern = pattern.duplicate()
    racer_progress.clear()

    for racer in racers:
        var movement := racer.get_node_or_null("RaceMovementComponent") as RaceMovementComponent
        if movement != null:
            racer_progress[racer] = movement.progress(track_pattern.size())

    _build_map_geometry()
    signal_bus.connect("racer_progress_changed", Callable(self, "_on_racer_progress_changed"))
    queue_redraw()

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

    map_bounds = Rect2(
        min_x,
        min_y,
        max_x - min_x,
        max_y - min_y
    )

func _exit_tree() -> void:
    if signal_bus == null:
        return
    var callback := Callable(self, "_on_racer_progress_changed")
    if signal_bus.is_connected("racer_progress_changed", callback):
        signal_bus.disconnect("racer_progress_changed", callback)

func _on_racer_progress_changed(racer: Node, progress: float) -> void:
    if not racer_progress.has(racer):
        return
    racer_progress[racer] = progress
    queue_redraw()

func _draw() -> void:
    if map_points.is_empty():
        return

    var w: float = size.x
    var h: float = size.y
    draw_rect(
        Rect2(0, 0, w, h),
        Color(0.05, 0.10, 0.05),
        true
    )

    var pad := 15.0
    var draw_w := w - pad * 2.0
    var draw_h := h - pad * 2.0

    var scale_x := draw_w / maxf(1.0, map_bounds.size.x)
    var scale_y := draw_h / maxf(1.0, map_bounds.size.y)
    var map_scale := minf(scale_x, scale_y)

    var offset_x := pad + (
        draw_w - map_bounds.size.x * map_scale
    ) * 0.5
    var offset_y := pad + (
        draw_h - map_bounds.size.y * map_scale
    ) * 0.5
    var center_offset := (
        Vector2(offset_x, offset_y)
        - map_bounds.position * map_scale
    )

    for i in map_points.size():
        var p1 = map_points[i] * map_scale + center_offset
        var p2 = map_points[(i + 1) % map_points.size()] * map_scale + center_offset
        draw_line(p1, p2, Color(0.40, 0.40, 0.45), 6.0, true)
        draw_line(p1, p2, Color(0.80, 0.80, 0.85), 2.0, true)

    var p_start = map_points[0] * map_scale + center_offset
    draw_circle(p_start, 4.0, Color(1.0, 1.0, 0.2))

    for racer in racers:
        if not racer_progress.has(racer):
            continue
        var movement := racer.get_node_or_null("RaceMovementComponent") as RaceMovementComponent
        if movement == null:
            continue

        var progress: float = float(racer_progress[racer])
        var idx: int = posmod(int(floor(progress)), map_points.size())
        var next_idx: int = (idx + 1) % map_points.size()
        var segment_t: float = fmod(progress, 1.0)
        var marker_pos := (
            map_points[idx].lerp(map_points[next_idx], segment_t)
            * map_scale
            + center_offset
        )

        var radius := 4.5 if movement.is_player else 3.0
        var marker_color := Color.WHITE if movement.is_player else Color(0.9, 0.2, 0.2)
        draw_circle(marker_pos, radius, marker_color)
