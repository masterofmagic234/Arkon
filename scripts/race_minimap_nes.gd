extends Control

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")
const StaticMapLayer = preload("res://scripts/race_minimap_static.gd")

var race_state = null
var player_car = null
var ai_cars: Array = []
var track_pattern: Array = []

var map_points: PackedVector2Array = PackedVector2Array()
var map_bounds: Rect2
var _static_layer: Node2D = null
var _map_scale: float = 1.0
var _center_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
    resized.connect(_on_minimap_resized)

func bind(state, player_ref, ais_ref: Array, pattern: Array, tx: PackedFloat32Array) -> void:
    race_state = state
    player_car = player_ref
    ai_cars = ais_ref
    track_pattern = pattern
    _build_map_geometry()
    _ensure_static_layer()
    _static_layer.call("setup", map_points, map_bounds, size)
    _update_map_transform()

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

func _ensure_static_layer() -> void:
    if _static_layer != null and is_instance_valid(_static_layer):
        return
    _static_layer = StaticMapLayer.new()
    _static_layer.name = "StaticMap"
    _static_layer.z_index = -1
    add_child(_static_layer)

func _on_minimap_resized() -> void:
    if _static_layer != null and is_instance_valid(_static_layer):
        _static_layer.call("set_map_size", size)
    _update_map_transform()
    queue_redraw()

func _update_map_transform() -> void:
    if map_points.is_empty():
        return

    var pad := 15.0
    var draw_w := size.x - pad * 2.0
    var draw_h := size.y - pad * 2.0
    var scale_x := draw_w / maxf(1.0, map_bounds.size.x)
    var scale_y := draw_h / maxf(1.0, map_bounds.size.y)
    _map_scale = minf(scale_x, scale_y)

    var offset_x := pad + (draw_w - map_bounds.size.x * _map_scale) * 0.5
    var offset_y := pad + (draw_h - map_bounds.size.y * _map_scale) * 0.5
    _center_offset = Vector2(offset_x, offset_y) - map_bounds.position * _map_scale

func _process(_delta: float) -> void:
    # Only dynamic markers need a redraw now. The track/background live in the
    # static child and repaint only when the map geometry or size changes.
    queue_redraw()

func _draw() -> void:
    if map_points.is_empty():
        return

    # The static track and dynamic markers share a cached transform. It is
    # recalculated only when the minimap binds or resizes, not on every frame.

    # AI markers with smooth segment interpolation.
    for ai_ctrl in ai_cars:
        if ai_ctrl and ai_ctrl.car:
            var car = ai_ctrl.car
            var idx: int = car.segment_index % map_points.size()
            var next_idx: int = (idx + 1) % map_points.size()
            var ai_pos = map_points[idx].lerp(map_points[next_idx], car.segment_progress) * _map_scale + _center_offset
            draw_circle(ai_pos, 3.0, Color(0.9, 0.2, 0.2))

    # Player marker with smooth segment interpolation.
    if player_car:
        var idx: int = player_car.segment_index % map_points.size()
        var next_idx: int = (idx + 1) % map_points.size()
        var p_pos = map_points[idx].lerp(map_points[next_idx], player_car.segment_progress) * _map_scale + _center_offset
        draw_circle(p_pos, 4.5, Color.WHITE)

func get_map_point_count() -> int:
    return map_points.size()
