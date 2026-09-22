extends CharacterBody2D
class_name Level3Player

signal fire_requested(origin: Vector2, direction: Vector2, weapon: StringName)
signal action_requested
signal throw_requested(origin: Vector2, direction: Vector2)
signal died
signal weapon_changed(weapon: StringName, ammo: int)

@export var move_speed: float = 210.0
@export var sprint_multiplier: float = 1.18
@export var acceleration: float = 1500.0
@export var friction: float = 1900.0

var current_weapon: StringName = &"pistol"
var ammo: int = 12
var throwable: StringName = &"bottle"

var is_dead: bool = false
var controls_enabled: bool = true

var _move_input: Vector2 = Vector2.ZERO
var _aim_input: Vector2 = Vector2.RIGHT
var _fire_held: bool = false
var _action_just_pressed: bool = false
var _throw_just_pressed: bool = false
var _sprint_held: bool = false

var _fire_cooldown: float = 0.0
var _damage_cooldown: float = 0.0

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1 | 2
    z_index = 20
    var shape := CircleShape2D.new()
    shape.radius = 13.0
    var collider := CollisionShape2D.new()
    collider.shape = shape
    add_child(collider)
    queue_redraw()

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
    _fire_cooldown = maxf(0.0, _fire_cooldown - delta)
    _damage_cooldown = maxf(0.0, _damage_cooldown - delta)

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
    move_and_slide()

    if _aim_input.length_squared() > 0.04:
        rotation = _aim_input.angle()

    if _fire_held and _fire_cooldown <= 0.0:
        _request_fire()

    if _action_just_pressed:
        action_requested.emit()

    if _throw_just_pressed and throwable != &"":
        var origin := global_position + _aim_input * 18.0
        throwable = &""
        throw_requested.emit(origin, _aim_input)

    _clear_edge_inputs()

func _request_fire() -> void:
    if current_weapon == &"pistol" or current_weapon == &"shotgun":
        if ammo <= 0:
            return
        ammo -= 1
        weapon_changed.emit(current_weapon, ammo)
    var cooldown := 0.18
    if current_weapon == &"shotgun":
        cooldown = 0.72
    elif current_weapon == &"bat":
        cooldown = 0.38
    _fire_cooldown = cooldown
    fire_requested.emit(global_position + _aim_input * 14.0, _aim_input, current_weapon)

func _clear_edge_inputs() -> void:
    _action_just_pressed = false
    _throw_just_pressed = false

func equip_weapon(weapon: StringName, new_ammo: int = 0) -> void:
    current_weapon = weapon
    if weapon == &"pistol":
        ammo = maxi(new_ammo, 1)
    elif weapon == &"shotgun":
        ammo = maxi(new_ammo, 1)
    elif weapon == &"bat":
        ammo = 0
    weapon_changed.emit(current_weapon, ammo)
    queue_redraw()

func give_throwable(throwable_kind: StringName) -> void:
    throwable = throwable_kind

func take_damage(_amount: int = 100) -> void:
    if is_dead or _damage_cooldown > 0.0:
        return
    _damage_cooldown = 0.15
    is_dead = true
    controls_enabled = false
    velocity = Vector2.ZERO
    died.emit()
    queue_redraw()

func get_aim_direction() -> Vector2:
    return _aim_input

func get_action_range() -> float:
    return 64.0

func _draw() -> void:
    draw_circle(Vector2.ZERO, 14.0, Color(0.95, 0.82, 0.68, 1.0))
    draw_circle(Vector2(-4.0, -3.0), 2.0, Color(0.05, 0.04, 0.04, 1.0))
    draw_circle(Vector2(4.0, -3.0), 2.0, Color(0.05, 0.04, 0.04, 1.0))
    draw_arc(Vector2.ZERO, 17.0, -0.8, 0.8, 18, Color(0.94, 0.25, 0.20, 1.0), 3.0)
    if current_weapon == &"bat":
        draw_line(Vector2.ZERO, Vector2(28, 0), Color(0.56, 0.28, 0.12, 1.0), 6.0, true)
    elif current_weapon == &"shotgun":
        draw_line(Vector2.ZERO, Vector2(30, 0), Color(0.35, 0.23, 0.15, 1.0), 5.0, true)
        draw_line(Vector2(9, -3), Vector2(30, -3), Color(0.10, 0.11, 0.12, 1.0), 3.0, true)
    else:
        draw_line(Vector2.ZERO, Vector2(24, 0), Color(0.11, 0.12, 0.14, 1.0), 5.0, true)
    if is_dead:
        draw_circle(Vector2.ZERO, 18.0, Color(0.35, 0.0, 0.0, 0.45))
