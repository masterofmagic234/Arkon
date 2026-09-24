extends CharacterBody2D
class_name Level3Player

const AssetVisual = preload("res://scripts/level3_asset_visual.gd")
const HealthComponent = preload("res://scripts/components/health_component.gd")
const HitboxComponent = preload("res://scripts/components/hitbox_component.gd")
const WeaponComponent = preload("res://scripts/components/weapon_component.gd")
const WeaponData = preload("res://scripts/weapon_data.gd")

signal fire_requested(origin: Vector2, direction: Vector2, weapon: StringName)
signal action_requested
signal throw_requested(origin: Vector2, direction: Vector2)
signal died
signal weapon_changed(weapon: StringName, ammo: int)

@export var move_speed: float = 120.0
@export var sprint_multiplier: float = 1.18
@export var acceleration: float = 900.0
@export var friction: float = 1100.0
@export var max_health: int = 100

var current_weapon: StringName = &"pistol"
var ammo: int = 12
var health: int = 100
var throwable: StringName = &"bottle"

var is_dead: bool = false
var controls_enabled: bool = true

var _move_input: Vector2 = Vector2.ZERO
var _aim_input: Vector2 = Vector2.RIGHT
var _fire_held: bool = false
var _action_just_pressed: bool = false
var _throw_just_pressed: bool = false
var _sprint_held: bool = false

var _damage_cooldown: float = 0.0
var _visual: AnimatedSprite2D
var _weapon_overlay: Sprite2D
var _visual_animation_busy: bool = false
var _health_component: HealthComponent
var _weapon_component: WeaponComponent
var _hitbox_component: HitboxComponent

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1 | 2
    z_index = 20
    var shape := CircleShape2D.new()
    shape.radius = 7.0
    var collider := CollisionShape2D.new()
    collider.shape = shape
    add_child(collider)
    _health_component = HealthComponent.new()
    _health_component.max_health = max_health
    _health_component.invulnerability_duration = 0.24
    add_child(_health_component)
    _health_component.health_changed.connect(_on_health_changed)
    _health_component.died.connect(_on_health_component_died)

    _hitbox_component = HitboxComponent.new()
    # Player hitboxes use their own layer so enemy projectiles cannot hit
    # other enemies in the same collision group.
    _hitbox_component.hit_layer = 8
    add_child(_hitbox_component)

    _weapon_component = WeaponComponent.new()
    _weapon_component.initial_weapon = &"pistol"
    _weapon_component.initial_ammo = ammo
    add_child(_weapon_component)
    _weapon_component.weapon_changed.connect(_on_weapon_component_changed)

    health = max_health
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _setup_visual()

func set_input(
    movement: Vector2,
    aim: Vector2,
    fire_held: bool,
    action_just_pressed: bool,
    throw_just_pressed: bool,
    sprint_held: bool
) -> void:
    _move_input = movement.limit_length(1.0)
    if aim.length_squared() > 0.04:
        _aim_input = aim.normalized()
    _fire_held = fire_held
    _action_just_pressed = action_just_pressed
    _throw_just_pressed = throw_just_pressed
    _sprint_held = sprint_held

func _physics_process(delta: float) -> void:
    if _weapon_component != null:
        _weapon_component.tick(delta)
    var damage_was_active := _damage_cooldown > 0.0
    _damage_cooldown = maxf(0.0, _damage_cooldown - delta)
    if damage_was_active and _damage_cooldown <= 0.0 and not is_dead and _visual != null:
        _visual.modulate = Color.WHITE

    if not controls_enabled or is_dead:
        velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
        move_and_slide()
        _clear_edge_inputs()
        return

    var target_speed := move_speed
    if _sprint_held:
        target_speed *= sprint_multiplier

    var desired_velocity := _move_input * target_speed
    var response := acceleration if _move_input.length_squared() > 0.01 else friction
    velocity = velocity.move_toward(desired_velocity, response * delta)
    var impact_speed := velocity.length()
    move_and_slide()
    _check_door_slam(impact_speed)

    if _aim_input.length_squared() > 0.04:
        rotation = _aim_input.angle()

    _update_visual_motion()

    if _fire_held and _weapon_component != null and _weapon_component.can_fire():
        _request_fire()

    if _action_just_pressed:
        action_requested.emit()

    if _throw_just_pressed and throwable != &"":
        var origin := global_position + _aim_input * 12.0
        throwable = &""
        throw_requested.emit(origin, _aim_input)

    _clear_edge_inputs()

func _check_door_slam(impact_speed: float) -> void:
    if impact_speed < move_speed * 0.70:
        return

    for index in range(get_slide_collision_count()):
        var collision := get_slide_collision(index)
        var collider := collision.get_collider()
        if collider is AnimatableBody2D:
            var door_node: Node = collider.get_parent()
            if door_node is Level3Door:
                (door_node as Level3Door).interact(global_position, true)
                return

func _request_fire() -> void:
    if _weapon_component == null or not _weapon_component.consume_shot():
        return
    current_weapon = _weapon_component.current_weapon
    ammo = _weapon_component.ammo
    _play_fire_animation()
    fire_requested.emit(global_position + _aim_input * 18.0, _aim_input, current_weapon)

func _clear_edge_inputs() -> void:
    _action_just_pressed = false
    _throw_just_pressed = false

func equip_weapon(weapon: StringName, new_ammo: int = 0) -> void:
    if _weapon_component == null:
        return
    _weapon_component.equip(weapon, new_ammo)
    current_weapon = _weapon_component.current_weapon
    ammo = _weapon_component.ammo
    _refresh_visual()
    _update_weapon_overlay()

func _visual_path_for_weapon() -> String:
    var data := get_weapon_data()
    if data != null and not data.movement_sprite.is_empty():
        return data.movement_sprite
    return "res://assets/level3/source/Player/sprPWalkUnarmed_strip8.png"

func _attack_path_for_weapon() -> String:
    var data := get_weapon_data()
    return data.attack_sprite if data != null else ""

func _setup_visual() -> void:
    _visual = AssetVisual.animated_strip(
        _visual_path_for_weapon(),
        9.0,
        Vector2(1.0, 1.0)
    )
    if _visual == null:
        return
    _visual.position = Vector2(0.0, -3.0)
    _visual.z_index = 1
    add_child(_visual)

    _setup_weapon_overlay()
    _update_visual_motion()

func _setup_weapon_overlay() -> void:
    var data := get_weapon_data()
    if data == null or data.overlay_texture.is_empty():
        return
    _weapon_overlay = AssetVisual.static_sprite(data.overlay_texture, Vector2(1.0, 1.0))
    if _weapon_overlay == null:
        return
    _weapon_overlay.position = Vector2(5.0, -2.0)
    _weapon_overlay.z_index = 3
    add_child(_weapon_overlay)

func _update_weapon_overlay() -> void:
    if _weapon_overlay == null:
        return
    var data := get_weapon_data()
    _weapon_overlay.visible = data != null and not data.overlay_texture.is_empty()

func _update_visual_motion() -> void:
    if _visual == null or _visual_animation_busy:
        return
    if velocity.length_squared() > 16.0:
        _visual.play()
    else:
        _visual.pause()

func _refresh_visual() -> void:
    if _visual == null or _visual_animation_busy:
        return

    var replacement := AssetVisual.animated_strip(
        _visual_path_for_weapon(),
        9.0,
        Vector2(1.0, 1.0)
    )
    if replacement == null:
        return
    replacement.position = Vector2(0.0, -6.0)
    replacement.z_index = 1
    _visual.queue_free()
    _visual = replacement
    add_child(_visual)
    _update_weapon_overlay()
    _update_visual_motion()

func _play_fire_animation() -> void:
    if _visual == null or _visual_animation_busy:
        return

    var attack_path := _attack_path_for_weapon()
    if attack_path.is_empty():
        return

    _visual_animation_busy = true
    var attack_visual := AssetVisual.animated_strip(
        attack_path,
        18.0,
        Vector2(1.0, 1.0),
        false
    )
    if attack_visual == null:
        _visual_animation_busy = false
        return

    attack_visual.position = Vector2(0.0, -6.0)
    attack_visual.z_index = 2
    _visual.queue_free()
    _visual = attack_visual
    add_child(_visual)
    _visual.animation_finished.connect(_on_fire_animation_finished, CONNECT_ONE_SHOT)
    _visual.play()

func _on_fire_animation_finished() -> void:
    _visual_animation_busy = false
    _refresh_visual()

func give_throwable(throwable_kind: StringName) -> void:
    throwable = throwable_kind

func take_damage(amount: int = 100) -> void:
    if _health_component == null or not _health_component.apply_damage(amount, null):
        return
    _damage_cooldown = 0.24
    health = _health_component.current_health
    if health > 0:
        if _visual != null:
            _visual.modulate = Color(1.0, 0.50, 0.50, 1.0)
        return
    _on_health_component_died()

func get_aim_direction() -> Vector2:
    return _aim_input

func get_action_range() -> float:
    var data := get_weapon_data()
    return data.action_range if data != null else 32.0

func get_weapon_data() -> WeaponData:
    if _weapon_component == null:
        return null
    return _weapon_component.current_data

func _on_health_changed(current: int, maximum: int) -> void:
    health = current
    max_health = maximum

func _on_health_component_died() -> void:
    if is_dead:
        return
    health = 0
    is_dead = true
    controls_enabled = false
    velocity = Vector2.ZERO
    died.emit()
    if _visual != null:
        _visual.modulate = Color(0.65, 0.20, 0.20, 1.0)

func _on_weapon_component_changed(weapon: StringName, current_ammo: int) -> void:
    current_weapon = weapon
    ammo = current_ammo
    weapon_changed.emit(current_weapon, ammo)

func _draw() -> void:
    # Player visuals come from the supplied sprite pack.
    pass
