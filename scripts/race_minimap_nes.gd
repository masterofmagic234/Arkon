extends Control

var racers: Array = []
var track_points := PackedVector3Array()
var track_length := 0.0
var racer_progress: Dictionary = {}
var signal_bus: Node = null
var map_points := PackedVector2Array()
var map_bounds := Rect2()

func bind(
        racers_ref: Array,
        centerline: PackedVector3Array,
        path_length: float
) -> void:
    signal_bus = get_node_or_null("/root/SignalBus")
    if signal_bus == null:
        push_error(
            "[Level2] Minimap: SignalBus autoload is unavailable."
        )
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
    track_points = centerline.duplicate()
    track_length = path_length
    racer_progress.clear()

    for racer in racers:
        var movement := racer.get_node_or_null(
            "RaceMovementComponent"
        ) as RaceMovementComponent
        if movement != null:
            racer_progress[racer] = movement.progress(
                track_length
            )

    _build_map_geometry()
    signal_bus.connect(
        "racer_progress_changed",
        callback
    )
    queue_redraw()

func _build_map_geometry() -> void:
    if track_points.size() < 2:
        return

    map_points.clear()
    var min_x := INF
    var min_y := INF
    var max_x := -INF
    var max_y := -INF

    for point in track_points:
        var p := Vector2(
            point.x,
            point.z
        )
        map_points.append(p)
        min_x = minf(min_x, p.x)
        min_y = minf(min_y, p.y)
        max_x = maxf(max_x, p.x)
        max_y = maxf(max_y, p.y)

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
        progress_value: float
) -> void:
    if not racer_progress.has(racer):
        return

    racer_progress[racer] = progress_value
    queue_redraw()

func _draw() -> void:
    if map_points.is_empty() or track_length <= 0.0:
        return

    var w := size.x
    var h := size.y
    draw_rect(
        Rect2(0, 0, w, h),
        Color(0.05, 0.10, 0.05),
        true
    )

    var pad := 15.0
    var draw_w := w - pad * 2.0
    var draw_h := h - pad * 2.0

    var map_scale := minf(
        draw_w / maxf(
            1.0,
            map_bounds.size.x
        ),
        draw_h / maxf(
            1.0,
            map_bounds.size.y
        )
    )

    var center_offset := (
        Vector2(
            pad,
            pad
        )
        + (
            Vector2(
                draw_w,
                draw_h
            )
            - map_bounds.size
            * map_scale
        ) * 0.5
        - map_bounds.position
        * map_scale
    )

    for i in map_points.size():
        var a := (
            map_points[i]
            * map_scale
            + center_offset
        )
        var b := (
            map_points[
                (i + 1) % map_points.size()
            ]
            * map_scale
            + center_offset
        )
        draw_line(
            a,
            b,
            Color(0.40, 0.40, 0.45),
            6.0,
            true
        )
        draw_line(
            a,
            b,
            Color(0.80, 0.80, 0.85),
            2.0,
            true
        )

    draw_circle(
        map_points[0] * map_scale + center_offset,
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

        var distance := fposmod(
            float(racer_progress[racer]),
            track_length
        )
        var point := movement.get_track_position_at_distance(
            distance
        )
        var marker := (
            Vector2(
                point.x,
                point.z
            )
            * map_scale
            + center_offset
        )

        draw_circle(
            marker,
            4.5 if movement.is_player else 3.0,
            Color.WHITE if movement.is_player else Color(0.9, 0.2, 0.2)
        )
