extends Area2D
class_name Level3Pickup

signal collected(kind: StringName)

var kind: StringName = &""
var consumed: bool = false

func setup(pickup_kind: StringName, world_position: Vector2) -> void:
    kind = pickup_kind
    global_position = world_position
    collision_layer = 4
    collision_mask = 2

func _ready() -> void:
    monitoring = true
    monitorable = true
    body_entered.connect(_on_body_entered)
    var shape := CircleShape2D.new()
    shape.radius = 22.0
    var collider := CollisionShape2D.new()
    collider.shape = shape
    add_child(collider)
    queue_redraw()

func _on_body_entered(body: Node) -> void:
    if consumed:
        return
    if body is Level3Player:
        consumed = true
        collected.emit(kind)
        queue_free()

func _draw() -> void:
    var base_color := Color(0.8, 0.8, 0.8, 1.0)
    match kind:
        &"pistol":
            base_color = Color(0.30, 0.35, 0.40, 1.0)
        &"shotgun":
            base_color = Color(0.55, 0.30, 0.18, 1.0)
        &"bat":
            base_color = Color(0.68, 0.36, 0.16, 1.0)
        &"bottle":
            base_color = Color(0.25, 0.55, 0.78, 1.0)
        _:
            base_color = Color(0.85, 0.85, 0.85, 1.0)

    draw_circle(Vector2.ZERO, 17.0, Color(0.03, 0.03, 0.04, 0.55))
    if kind == &"bat":
        draw_line(Vector2(-7, 9), Vector2(8, -10), base_color, 7.0, true)
        draw_line(Vector2(-10, 12), Vector2(-4, 18), Color(0.34, 0.17, 0.08, 1.0), 4.0, true)
    elif kind == &"bottle":
        draw_rect(Rect2(-7, -7, 14, 15), base_color, true)
        draw_rect(Rect2(-4, -12, 8, 6), base_color.lightened(0.2), true)
    elif kind == &"shotgun":
        draw_line(Vector2(-11, 8), Vector2(11, -7), base_color, 8.0, true)
        draw_line(Vector2(-2, 2), Vector2(12, 13), Color(0.25, 0.14, 0.08, 1.0), 5.0, true)
    else:
        draw_line(Vector2(-9, 6), Vector2(10, -5), base_color, 6.0, true)
        draw_circle(Vector2(6, -4), 4.0, Color(0.15, 0.17, 0.20, 1.0))
