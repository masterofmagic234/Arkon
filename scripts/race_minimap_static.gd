extends Node2D

var map_points := PackedVector2Array()
var map_bounds := Rect2()
var map_size := Vector2.ZERO
var _map_scale := 1.0
var _center_offset := Vector2.ZERO

func setup(points: PackedVector2Array, bounds: Rect2, viewport_size: Vector2) -> void:
    map_points = points
    map_bounds = bounds
    set_map_size(viewport_size)

func set_map_size(viewport_size: Vector2) -> void:
    if viewport_size == map_size:
        return

    map_size = viewport_size
    var w := map_size.x
    var h := map_size.y
    var pad := 15.0
    var draw_w := w - pad * 2.0
    var draw_h := h - pad * 2.0

    var scale_x := draw_w / maxf(1.0, map_bounds.size.x)
    var scale_y := draw_h / maxf(1.0, map_bounds.size.y)
    _map_scale = minf(scale_x, scale_y)

    var offset_x := pad + (draw_w - map_bounds.size.x * _map_scale) * 0.5
    var offset_y := pad + (draw_h - map_bounds.size.y * _map_scale) * 0.5
    _center_offset = Vector2(offset_x, offset_y) - map_bounds.position * _map_scale
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.05, 0.10, 0.05), true)
    if map_points.is_empty():
        return

    var line_points := PackedVector2Array()
    line_points.resize(map_points.size() * 2)
    for i in map_points.size():
        var p1 := map_points[i] * _map_scale + _center_offset
        var p2 := map_points[(i + 1) % map_points.size()] * _map_scale + _center_offset
        line_points[i * 2] = p1
        line_points[i * 2 + 1] = p2

    draw_multiline(line_points, Color(0.40, 0.40, 0.45), 6.0, true)
    draw_multiline(line_points, Color(0.80, 0.80, 0.85), 2.0, true)

    var p_start := map_points[0] * _map_scale + _center_offset
    draw_circle(p_start, 4.0, Color(1.0, 1.0, 0.2))
