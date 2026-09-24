extends CharacterBody2D
class_name Level3Enemy

const AssetVisual = preload("res://scripts/level3_asset_visual.gd")
const HealthComponent = preload("res://scripts/components/health_component.gd")
const HitboxComponent = preload("res://scripts/components/hitbox_component.gd")

enum State {
    IDLE,
    ALERT,
    STUNNED,
    DEAD
}

signal shot_requested(shooter, origin: Vector2, direction: Vector2)
signal defeated(enemy: Level3Enemy)

@export var move_speed: float = 105.0
@export var vision_range: float = 520.0
@export var preferred_distance: float = 260.0
@export var attack_range: float = 34.0
@export var patrol_radius: float = 90.0
@export var ranged: bool = true

var target: Level3Player
var world: Node2D
var spawn_position: Vector2
var last_known_position: Vector2
var state: State = State.IDLE

var _stun_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _patrol_target: Vector2
var _enemy_kind: StringName = &"gunman"
var _visual: AnimatedSprite2D
var _weapon_visual: Sprite2D
var _health_component: HealthComponent
var _hitbox_component: HitboxComponent
var _aim_direction: Vector2 = Vector2.RIGHT
var _facing_left: bool = false

func setup(level_world: Node2D, player: Level3Player, enemy_kind: StringName, radius: float) -> void:
    world = level_world
    target = player
    _enemy_kind = enemy_kind
    ranged = enemy_kind != &"melee" and enemy_kind != &"butcher"
    patrol_radius = radius
    spawn_position = global_position
    last_known_position = global_position
    _patrol_target = global_position
    if enemy_kind == &"melee" or enemy_kind == &"butcher":
        move_speed = 104.0 if enemy_kind == &"melee" else 112.0
        vision_range = 380.0
        attack_range = 38.0
    else:
        move_speed = 82.0
        vision_range = 430.0
        preferred_distance = 230.0
    collision_layer = 2
    collision_mask = 1 | 2
    z_index = 15
    _health_component = HealthComponent.new()
    _health_component.max_health = 1
    _health_component.invulnerability_duration = 0.0
    add_child(_health_component)
    _health_component.died.connect(_on_health_died)

    _hitbox_component = HitboxComponent.new()
    add_child(_hitbox_component)

    var shape := CircleShape2D.new()
    shape.radius = 7.0
    var collider := CollisionShape2D.new()
    collider.shape = shape
    add_child(collider)
    _setup_visual()

func _physics_process(delta: float) -> void:
    if state == State.DEAD:
        return

    _attack_cooldown = maxf(0.0, _attack_cooldown - delta)

    _update_visual_facing()
    if state == State.STUNNED:
        if _visual != null:
            _visual.pause()
    else:
        _update_visual_motion()
    if state == State.STUNNED:
        if _visual != null:
            _visual.modulate = Color(1.0, 0.82, 0.25, 1.0)
        _stun_timer -= delta
        velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
        move_and_slide()
        if _stun_timer <= 0.0:
            state = State.IDLE
        queue_redraw()
        return

    if _visual != null and state != State.STUNNED:
        _visual.modulate = Color.WHITE

    if target == null or target.is_dead:
        velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
        move_and_slide()
        return

    if world != null and world.has_method("is_combat_paused") and world.is_combat_paused():
        velocity = Vector2.ZERO
        if _visual != null:
            _visual.pause()
        return

    var distance_to_target := global_position.distance_to(target.global_position)
    var sees_target: bool = distance_to_target <= vision_range and world.has_line_of_sight(global_position, target.global_position)

    if sees_target:
        state = State.ALERT
        last_known_position = target.global_position

    match state:
        State.IDLE:
            _update_idle_patrol(delta)
        State.ALERT:
            _update_alert(delta, distance_to_target)
        State.STUNNED, State.DEAD:
            pass

    move_and_slide()
    queue_redraw()

func _update_idle_patrol(delta: float) -> void:
    if global_position.distance_to(_patrol_target) < 12.0 or not world.has_line_of_sight(global_position, _patrol_target):
        if not _choose_reachable_patrol_target():
            velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
            return

    var direction := global_position.direction_to(_patrol_target)
    velocity = velocity.move_toward(direction * move_speed * 0.45, 700.0 * delta)

func _choose_reachable_patrol_target() -> bool:
    # Random patrol points can land behind a store wall. Try several candidates
    # immediately instead of freezing at an unreachable target until timeout.
    for _attempt in range(8):
        var angle := randf() * TAU
        var distance := randf_range(22.0, patrol_radius)
        var candidate := spawn_position + Vector2.from_angle(angle) * distance
        if world.has_line_of_sight(global_position, candidate):
            _patrol_target = candidate
            return true

    _patrol_target = global_position
    return false

func _update_alert(delta: float, distance_to_target: float) -> void:
    var direction := global_position.direction_to(last_known_position)
    if ranged:
        if distance_to_target > preferred_distance + 50.0:
            velocity = velocity.move_toward(direction * move_speed, 850.0 * delta)
        elif distance_to_target < preferred_distance - 60.0:
            velocity = velocity.move_toward(-direction * move_speed, 850.0 * delta)
        else:
            velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)

        if distance_to_target <= vision_range and world.has_line_of_sight(global_position, target.global_position) and _attack_cooldown <= 0.0:
            _attack_cooldown = 1.20
            var shot_direction := global_position.direction_to(target.global_position)
            shot_requested.emit(self, global_position + shot_direction * 15.0, shot_direction)
    else:
        velocity = velocity.move_toward(direction * move_speed, 1000.0 * delta)
        if distance_to_target <= attack_range and _attack_cooldown <= 0.0:
            _attack_cooldown = 1.10
            if world.has_line_of_sight(global_position, target.global_position):
                if not world.has_method("is_combat_paused") or not world.is_combat_paused():
                    target.take_damage(25)

func hear_noise(noise_position: Vector2) -> void:
    if state == State.DEAD:
        return
    if global_position.distance_to(noise_position) <= 520.0:
        state = State.ALERT
        last_known_position = noise_position

func stun(duration: float = 3.2, knockback_velocity: Vector2 = Vector2.ZERO) -> void:
    if state == State.DEAD:
        return
    state = State.STUNNED
    _stun_timer = duration
    velocity = knockback_velocity if knockback_velocity.length_squared() > 0.001 else Vector2.ZERO
    if _visual != null:
        _visual.modulate = Color(1.0, 0.82, 0.25, 1.0)

func receive_hit(amount: int = 1, source: Node = null) -> void:
    if state == State.DEAD or _hitbox_component == null:
        return
    _hitbox_component.receive_hit(amount, source)

func take_damage(amount: int = 1, source: Node = null) -> void:
    if state == State.DEAD or _health_component == null:
        return
    _health_component.apply_damage(amount, source)

func kill() -> void:
    if state == State.DEAD:
        return
    # Set the gameplay state before notifying HealthComponent so its died
    # callback cannot recursively enter this method.
    state = State.DEAD
    if _health_component != null and not _health_component.is_dead:
        _health_component.force_kill()
    velocity = Vector2.ZERO
    set_physics_process(false)
    var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
    if collision_shape != null:
        # kill() may be called from a RayCast2D during a physics query flush.
        # Defer the collision mutation until the query step has finished.
        collision_shape.set_deferred("disabled", true)
    defeated.emit(self)
    var bus := get_node_or_null("/root/SignalBus")
    if bus != null and bus.has_signal("enemy_defeated"):
        bus.enemy_defeated.emit(StringName(name))
    if _visual != null:
        _visual.modulate = Color(0.55, 0.55, 0.55, 0.92)
        _visual.stop()
    if _weapon_visual != null:
        _weapon_visual.modulate = Color(0.55, 0.55, 0.55, 0.92)
    var death_tween := create_tween()
    if _visual != null:
        death_tween.tween_property(_visual, "rotation", _visual.rotation + (-0.22 if _facing_left else 0.22), 0.18)
    if _weapon_visual != null:
        death_tween.parallel().tween_property(_weapon_visual, "rotation", _weapon_visual.rotation + (-0.22 if _facing_left else 0.22), 0.18)
    death_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.32)
    death_tween.tween_callback(queue_free)

func is_stunned() -> bool:
    return state == State.STUNNED

func _on_health_died() -> void:
    if state != State.DEAD:
        kill()

func _setup_visual() -> void:
    var path := "res://assets/level3/source/NPCs/sprSwatWalkM16_strip8.png"
    if _enemy_kind == &"melee":
        path = "res://assets/level3/source/NPCs/sprBodyGuard1_strip6.png"
    elif _enemy_kind == &"butcher":
        path = "res://assets/level3/source/Player/sprPigButcher_strip8.png"

    _visual = AssetVisual.animated_strip(path, 8.0, Vector2(1.0, 1.0))
    if _visual == null:
        return
    _visual.position = Vector2(0.0, -3.0)
    _visual.z_index = 1
    add_child(_visual)

    if not ranged:
        _weapon_visual = AssetVisual.static_sprite(
            "res://assets/level3/source/Weapons/sprCleaver.png",
            Vector2(1.0, 1.0)
        )
        if _weapon_visual != null:
            _weapon_visual.position = Vector2(5.0, -2.0)
            _weapon_visual.rotation = deg_to_rad(-18.0)
            _weapon_visual.z_index = 2
            add_child(_weapon_visual)

func _update_visual_facing() -> void:
    if target == null:
        return

    var to_target := global_position.direction_to(target.global_position)
    if to_target.length_squared() <= 0.001:
        return

    # Keep the gameplay aim vector at full precision, but keep 3/4-view art upright.
    _aim_direction = to_target
    _facing_left = to_target.x < 0.0
    if _visual != null:
        _visual.flip_h = _facing_left
    if _weapon_visual != null:
        _weapon_visual.flip_h = _facing_left
        _weapon_visual.position.x = -5.0 if _facing_left else 5.0
        _weapon_visual.rotation = deg_to_rad(18.0 if _facing_left else -18.0)

func _update_visual_motion() -> void:
    if _visual == null or state == State.STUNNED or state == State.DEAD:
        return
    if velocity.length_squared() > 16.0:
        _visual.play()
    else:
        _visual.pause()

func _draw() -> void:
    # Enemy visuals come from the supplied sprite pack.
    pass
