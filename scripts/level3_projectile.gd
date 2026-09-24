extends Area2D
class_name Level3Projectile

const HitboxComponent = preload("res://scripts/components/hitbox_component.gd")

var target_position: Vector2
var direction: Vector2
var speed: float = 650.0
var lifetime: float = 1.0
var elapsed: float = 0.0
var on_impact: Callable = Callable()
var impact_position: Vector2
var collision_enabled: bool = false
var impact_damage: int = 0
var _ignored_actor: Node = null
var _impact_started: bool = false

func setup(
    start: Vector2,
    target: Vector2,
    speed_: float,
    impact_callback: Callable,
    sprite_path: String,
    fps: float,
    sprite_scale: Vector2,
    collision_enabled_: bool = false,
    collision_mask_: int = 0,
    ignored_actor: Node = null,
    impact_damage_: int = 0
) -> void:
    global_position = start
    target_position = target
    direction = start.direction_to(target)
    speed = maxf(speed_, 1.0)
    lifetime = maxf(start.distance_to(target) / speed, 0.08) + 0.20
    elapsed = 0.0
    on_impact = impact_callback
    impact_position = target
    collision_enabled = collision_enabled_
    impact_damage = maxi(impact_damage_, 0)
    _ignored_actor = ignored_actor
    _impact_started = false

    collision_layer = 4
    collision_mask = collision_mask_ if collision_enabled_ else 0
    monitoring = collision_enabled_
    monitorable = true

    if collision_enabled_:
        area_entered.connect(_on_area_entered)

    var visual := _make_visual(sprite_path, fps, sprite_scale)
    if visual != null:
        visual.rotation = direction.angle()
        visual.z_index = 1
        add_child(visual)

func _physics_process(delta: float) -> void:
    if _impact_started:
        return

    elapsed += delta
    var to_target := global_position.distance_to(target_position)
    if to_target <= 2.0 or elapsed >= lifetime:
        global_position = impact_position
        _impact_and_free()
        return
    global_position += direction * minf(speed * delta, to_target)

func _on_area_entered(area: Area2D) -> void:
    if not collision_enabled or _impact_started or area == null:
        return
    if not area is HitboxComponent:
        return

    var hitbox := area as HitboxComponent
    var actor := hitbox.get_parent()
    if actor == null or actor == _ignored_actor:
        return

    if impact_damage > 0:
        hitbox.receive_hit(impact_damage, _ignored_actor)
    global_position = area.global_position
    impact_position = global_position
    _impact_and_free()

func _impact_and_free() -> void:
    if _impact_started:
        return
    _impact_started = true
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
