extends Control

var race_state = null
var player_car = null
var ai_cars: Array = []
var track_pattern: Array = []
var track_x: PackedFloat32Array = PackedFloat32Array()

func bind(state, player_ref, ais_ref: Array, pattern: Array, tx: PackedFloat32Array) -> void:
    race_state = state
    player_car = player_ref
    ai_cars = ais_ref
    track_pattern = pattern
    track_x = tx

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    if track_pattern.is_empty():
        return
    var w: float = size.x
    var h: float = size.y
    draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.10, 0.05), true)
    var min_x := 999999.0
    var max_x := -999999.0
    for x in track_x:
        min_x = minf(min_x, x)
        max_x = maxf(max_x, x)
    var span := maxf(1.0, max_x - min_x)
    var pad := 6.0
    var scale := (w - pad * 2.0) / span
    var seg_h := (h - pad * 2.0) / float(track_pattern.size())
    var prev := Vector2.ZERO
    for i in track_pattern.size():
        var px := pad + (track_x[i] - min_x) * scale
        var py := pad + float(i) * seg_h
        var pt := Vector2(px, py)
        if i > 0:
            draw_line(prev, pt, Color(0.80, 0.80, 0.85), 2.0, true)
        prev = pt
    for ai in ai_cars:
        draw_circle(_world_to_map(ai.world_x, ai.world_z, min_x, scale, pad), 2.0, Color(0.9, 0.2, 0.2))
    if player_car:
        draw_circle(_world_to_map(player_car.world_x, player_car.world_z, min_x, scale, pad), 2.5, Color.WHITE)

func _world_to_map(wx: float, wz: float, min_x: float, scale: float, pad: float) -> Vector2:
    var total_world_z := float(track_pattern.size()) * 1.8
    var t := fposmod(wz, total_world_z) / total_world_z
    return Vector2(pad + (wx - min_x) * scale, pad + t * (size.y - pad * 2.0))
