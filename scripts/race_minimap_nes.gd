extends Control

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")

var racers: Array = []
var track_pattern: Array = []
var track_x := PackedFloat32Array()
var racer_progress: Dictionary = {}
var signal_bus: Node = null

var map_points: PackedVector2Array = PackedVector2Array()
var map_bounds: Rect2

func bind(racers_ref: Array, pattern: Array) -> void:
    signal_bus = get_node_or_null("/root/SignalBus")
    if signal_bus == null:
        push_error("[Level2] Minimap: SignalBus autoload is unavailable.")
        return

    var callback := Callable(
        self,
        "_on_racer_progress_changed"
    )
    if signal_bus.is_connected(
        "racer_progress_changed",
        callback
    ):
        signal_bus.disconnect(
            "racer_progress_changed",
            callback
        )

    racers = racers_ref.duplicate()
    track_pattern = pattern.duplicate()
    track_x = RaceMath.accumulate_track_x(track_pattern)
    racer_progress.clear()

    for racer in racers:
        var movement := racer.get_node_or_null(
            "RaceMovementComponent"
        ) as RaceMovementComponent
        if movement != null:
            racer_progress[racer] = movement.progress(
                track_pattern.size()
            )

    _build_map_geometry()
    signal_bus.connect(
        "racer_progress_changed",
        Callable(
            self,
            "_on_racer_progress_changed"
        )
    )
    queue_redraw()

func _build_map_geometry() -> void:
    if track_pattern.is_empty():
        return

    map_points.clear()

    var min_x := INF
    var min_y := INF
    var max_x := -INF
    var max_y := -INF

    for i in track_pattern.size():
        var world_point := RaceMath.track_world_position(
            float(i),
            track_x,
            track_pattern.size(),
            RaceLevelData.SEGMENT_HEIGHT
        )
        var point := Vector2(
            world_point.x,
            world_point.z
        )
        map_points.append(point)

        min_x = minf(min_x, point.x)
        min_y = minf(min_y, point.y)
        max_x = maxf(max_x, point.x)
        max_y = maxf(max_y, point.y)

    map_bounds = Rect2(
        min_x,
        min_y,
        max_x - min_x,
        max_y - min_y
    )

func _exit_tree() -> void:
    if signal_bus == null:
        return

    var callback := Callable(
        self,
        "_on_racer_progress_changed"
    )
    if signal_bus.is_connected(
        "racer_progress_changed",
        callback
    ):
        signal_bus.disconnect(
            "racer_progress_changed",
            callback
        )

func _on_racer_progress_changed(
        racer: Node,
        progress: float
) -> void:
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

    var scale_x := draw_w / maxf(
        1.0,
        map_bounds.size.x
    )
    var scale_y := draw_h / maxf(
        1.0,
        map_bounds.size.y
    )
    var map_scale := minf(
        scale_x,
        scale_y
    )

    var offset_x := pad + (
        draw_w
        - map_bounds.size.x * map_scale
    ) * 0.5
    var offset_y := pad + (
        draw_h
        - map_bounds.size.y * map_scale
    ) * 0.5

    var center_offset := (
        Vector2(offset_x, offset_y)
        - map_bounds.position * map_scale
    )

    for i in map_points.size():
        var p1 := (
            map_points[i] * map_scale
            + center_offset
        )
        var p2 := (
            map_points[(i + 1) % map_points.size()]
            * map_scale
            + center_offset
        )

        draw_line(
            p1,
            p2,
            Color(0.40, 0.40, 0.45),
            6.0,
            true
        )
        draw_line(
            p1,
            p2,
            Color(0.80, 0.80, 0.85),
            2.0,
            true
        )

    var start_point := (
        map_points[0] * map_scale
        + center_offset
    )
    draw_circle(
        start_point,
        4.0,
        Color(1.0, 1.0, 0.2)
    )

    for racer in racers:
        if not racer_progress.has(racer):
            continue

        var movement := racer.get_node_or_null(
            "RaceMovementComponent"
        ) as RaceMovementComponent
        if movement == null:
            continue

        var loop_progress := fposmod(
            float(racer_progress[racer]),
            float(map_points.size())
        )
        var map_idx := int(
            floor(loop_progress)
        )
        var next_idx := (
            map_idx + 1
        ) % map_points.size()
        var segment_t := fmod(
            loop_progress,
            1.0
        )

        var marker_world := RaceMath.track_world_position(
            loop_progress,
            track_x,
            track_pattern.size(),
            RaceLevelData.SEGMENT_HEIGHT
        )
        var marker_pos := (
            Vector2(
                marker_world.x,
                marker_world.z
            )
            * map_scale
            + center_offset
        )

        # Keep the segment interpolation visually smooth even though progress
        # is emitted at a low fixed rate.
        var p_a := (
            map_points[map_idx]
            .lerp(
                map_points[next_idx],
                segment_t
            )
        )
        marker_pos = p_a * map_scale + center_offset

        var radius := (
            4.5
            if movement.is_player
            else 3.0
        )
        var marker_color := (
            Color.WHITE
            if movement.is_player
            else Color(0.9, 0.2, 0.2)
        )
        draw_circle(
            marker_pos,
            radius,
            marker_color
        )
