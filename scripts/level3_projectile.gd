extends Area2D
class_name Level3Projectile

var target_position: Vector2
var direction: Vector2
var speed: float = 650.0
var lifetime: float = 1.0
var elapsed: float = 0.0
var on_impact: Callable = Callable()
var impact_position: Vector2
var stop_on_body_collision: bool = false

func setup(start: Vector2, target: Vector2, speed_: float, impact_callback: Callable, sprite_path: String, fps: float, sprite_scale: Vector2, body_collision: bool = false) -> void:
    global_position = start
    target_position = target
    direction = start.direction_to(target)
    speed = maxf(speed_, 1.0)
    lifetime = maxf(start.distance_to(target) / speed, 0.08) + 0.20
    elapsed = 0.0
    on_impact = impact_callback
    impact_position = target
    stop_on_body_collision = body_collision
    collision_layer = 4
    collision_mask = 2
    monitoring = true
    monitorable = false

    if body_collision:
        body_entered.connect(_on_body_entered)

    var visual := _make_visual(sprite_path, fps, sprite_scale)
    if visual != null:
        visual.rotation = direction.angle()
        visual.z_index = 1
        add_child(visual)

func _physics_process(delta: float) -> void:
    elapsed += delta
    var to_target := global_position.distance_to(target_position)
    if to_target <= 2.0 or elapsed >= lifetime:
        global_position = impact_position
        _impact_and_free()
        return
    global_position += direction * minf(speed * delta, to_target)

func _on_body_entered(body: Node) -> void:
    if not stop_on_body_collision or body == null:
        return
    global_position = body.global_position
    impact_position = global_position
    _impact_and_free()

func _impact_and_free() -> void:
    if on_impact.is_valid():
        var callback := on_impact
        on_impact = Callable()
        callback.call()
    queue_free()

func _make_visual(path: String, fps: float, sprite_scale: Vector2) -> Node2D:
    var helper_script = load("res://scripts/level3_asset_visual.gd")
    if helper_script != null:
        var visual: Node2D = helper_script.animated_strip(path, fps, sprite_scale)
        if visual != null:
            return visual
    return null
