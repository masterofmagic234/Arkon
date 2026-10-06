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
var _collision_mask: int = 0
var _impact_collider: Node = null

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
    _impact_collider = null
    _collision_mask = collision_mask_ if collision_enabled_ else 0

    # Projectile collision is resolved by an authoritative swept physics query.
    # The Area2D remains only as the visual/projectile container; relying on
    # area_entered alone can miss fast-moving or newly spawned obstacles.
    collision_layer = 0
    collision_mask = 0
    monitoring = false
    monitorable = false

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
        impact_position = global_position
        _impact_collider = null
        _impact_and_free()
        return

    var travel := minf(speed * delta, to_target)
    var next_position := global_position + direction * travel

    if collision_enabled and _collision_mask != 0:
        var query := PhysicsRayQueryParameters2D.create(
            global_position,
            next_position,
            _collision_mask
        )
        query.collide_with_bodies = true
        query.collide_with_areas = true
        query.exclude = _excluded_rids()

        var result := get_world_2d().direct_space_state.intersect_ray(query)
        if not result.is_empty():
            impact_position = result["position"]
            _impact_collider = result["collider"] as Node
            global_position = impact_position

            if _impact_collider is HitboxComponent and impact_damage > 0:
                (_impact_collider as HitboxComponent).receive_hit(
                    impact_damage,
                    _ignored_actor
                )

            _impact_and_free()
            return

    global_position = next_position


func _excluded_rids() -> Array[RID]:
    var result: Array[RID] = []
    if _ignored_actor is CollisionObject2D:
        result.append((_ignored_actor as CollisionObject2D).get_rid())

    if _ignored_actor != null:
        var ignored_hitbox := _ignored_actor.get_node_or_null("Hitbox") as CollisionObject2D
        if ignored_hitbox != null:
            result.append(ignored_hitbox.get_rid())

    return result

func _impact_and_free() -> void:
    if _impact_started:
        return
    _impact_started = true
    if on_impact.is_valid():
        var callback := on_impact
        on_impact = Callable()
        callback.call(impact_position, _impact_collider)
    queue_free()

func _make_visual(path: String, fps: float, sprite_scale: Vector2) -> Node2D:
    var helper_script = load("res://scripts/level3_asset_visual.gd")
    if helper_script != null:
        var visual: Node2D = helper_script.animated_strip(path, fps, sprite_scale)
        if visual != null:
            return visual
    return null
