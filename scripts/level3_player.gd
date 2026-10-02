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
@onready var _visual: AnimatedSprite2D = %Visual
@onready var _weapon_overlay: Sprite2D = %WeaponOverlay
@onready var _health_component: HealthComponent = %Health
@onready var _weapon_component: WeaponComponent = %WeaponComponent
@onready var _hitbox_component: HitboxComponent = %Hitbox
var _visual_animation_busy: bool = false
var _movement_frames: SpriteFrames

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1 | 2
    z_index = 20
    if _health_component != null:
        _health_component.health_changed.connect(_on_health_changed)
        _health_component.died.connect(_on_health_component_died)
        health = _health_component.current_health
        max_health = _health_component.max_health
    if _weapon_component != null:
        _weapon_component.weapon_changed.connect(_on_weapon_component_changed)
        current_weapon = _weapon_component.current_weapon
        ammo = _weapon_component.ammo
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
        var bus := get_node_or_null("/root/SignalBus")
        if bus != null and bus.has_signal("level3_player_action_requested"):
            bus.level3_player_action_requested.emit(self)

    if _throw_just_pressed and throwable != &"":
        var origin := global_position + _aim_input * 12.0
        throwable = &""
        throw_requested.emit(origin, _aim_input)
        var bus := get_node_or_null("/root/SignalBus")
        if bus != null and bus.has_signal("level3_player_throw_requested"):
            bus.level3_player_throw_requested.emit(self, origin, _aim_input)

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
    var origin := global_position + _aim_input * 18.0
    fire_requested.emit(origin, _aim_input, current_weapon)
    var bus := get_node_or_null("/root/SignalBus")
    if bus != null and bus.has_signal("level3_player_fire_requested"):
        bus.level3_player_fire_requested.emit(self, origin, _aim_input, current_weapon)

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
    if _visual == null:
        return
    _movement_frames = AssetVisual.sprite_frames_from_strip(_visual_path_for_weapon(), 9.0, true)
    _visual.sprite_frames = _movement_frames
    _visual.animation = &"default"
    _visual.position = Vector2(0.0, -3.0)
    _visual.z_index = 1
    _visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _visual.play(&"default")
    _setup_weapon_overlay()
    _update_visual_motion()

func _setup_weapon_overlay() -> void:
    var data := get_weapon_data()
    if _weapon_overlay == null:
        return
    _weapon_overlay.position = Vector2(5.0, -2.0)
    _weapon_overlay.z_index = 3
    _weapon_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _weapon_overlay.texture = AssetVisual.first_frame_texture(data.overlay_texture) if data != null and not data.overlay_texture.is_empty() else null
    _weapon_overlay.visible = _weapon_overlay.texture != null

func _update_weapon_overlay() -> void:
    _setup_weapon_overlay()

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
    _movement_frames = AssetVisual.sprite_frames_from_strip(_visual_path_for_weapon(), 9.0, true)
    _visual.sprite_frames = _movement_frames
    _visual.animation = &"default"
    _visual.play(&"default")
    _update_weapon_overlay()
    _update_visual_motion()

func _play_fire_animation() -> void:
    if _visual == null or _visual_animation_busy:
        return
    var attack_path := _attack_path_for_weapon()
    if attack_path.is_empty():
        return
    var attack_frames := AssetVisual.sprite_frames_from_strip(attack_path, 18.0, false)
    if attack_frames == null:
        return
    _visual_animation_busy = true
    _visual.sprite_frames = attack_frames
    _visual.animation = &"default"
    _visual.play(&"default")
    _visual.animation_finished.connect(_on_fire_animation_finished, CONNECT_ONE_SHOT)

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
    var bus := get_node_or_null("/root/SignalBus")
    if bus != null and bus.has_signal("level3_player_died"):
        bus.level3_player_died.emit(self)
    if _visual != null:
        _visual.modulate = Color(0.65, 0.20, 0.20, 1.0)

func _on_weapon_component_changed(weapon: StringName, current_ammo: int) -> void:
    current_weapon = weapon
    ammo = current_ammo
    weapon_changed.emit(current_weapon, ammo)
    var bus := get_node_or_null("/root/SignalBus")
    if bus != null and bus.has_signal("level3_player_weapon_changed"):
        bus.level3_player_weapon_changed.emit(self, current_weapon, ammo)

func _draw() -> void:
    # Player visuals come from the supplied sprite pack.
    pass
