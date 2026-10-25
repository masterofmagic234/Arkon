extends CharacterBody3D
class_name Level1Player

const LevelData = preload("res://scripts/level_data.gd")
const MovementMath = preload("res://scripts/movement_math.gd")
const TurnMath = preload("res://scripts/turn_math.gd")
const CombatQuery = preload("res://scripts/combat_query.gd")
const FireQuery = preload("res://scripts/fire_query.gd")
const AmmoMath = preload("res://scripts/ammo_math.gd")
const HealthComponent = preload("res://scripts/components/health_component.gd")
const Hitbox3DComponent = preload("res://scripts/components/hitbox_3d_component.gd")

const MOUSE_SENSITIVITY := 0.0032
const FIRE_COOLDOWN := 0.18
const FOOTSTEP_INTERVAL := 0.30
const DAMAGE_COOLDOWN := 0.80

@onready var camera: Camera3D = $Camera3D
@onready var health: HealthComponent = $Health

var move_axis := Vector2.ZERO
var desktop_mode := false
var input_enabled := true

var fire_cooldown := 0.0
var fire_requested := false
var damage_cooldown := 0.0
var recoil_time := 0.0
var foot_timer := 0.0
var ammo := LevelData.MAX_AMMO
var _feedback_generation := 0
var quiet_mode := false
var dash_cooldown := 0.0
var dash_time := 0.0
var dash_direction := Vector3.ZERO
var heist: Node
var eye_height := 0.0
const DASH_DURATION := 0.24
const DASH_COOLDOWN := 3.0
const DASH_SPEED := 11.5

func _ready() -> void:
    add_to_group("level1_player")
    desktop_mode = not OS.has_feature("mobile")
    health.reset(LevelData.MAX_HP)
    eye_height = camera.position.y
    SignalBus.weapon_changed.emit(self, &"l1_sidearm", ammo)

func _physics_process(delta: float) -> void:
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    damage_cooldown = maxf(0.0, damage_cooldown - delta)
    recoil_time = maxf(0.0, recoil_time - delta)
    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    dash_time = maxf(0.0, dash_time - delta)

    if not input_enabled or health.is_dead:
        fire_requested = false
        velocity = Vector3.ZERO
        return

    move_axis = _read_move_axis()
    if Input.is_action_just_pressed("l1_dash"): request_dash()
    if Input.is_action_just_pressed("l1_quiet"): toggle_quiet()

    var vertical_speed := velocity.y
    var garden_terrain := is_instance_valid(heist) and heist.has_method("ground_height_at")
    var movement_axis := move_axis
    var before_move := global_position
    velocity = MovementMath.velocity_for_input(
        global_transform.basis,
        movement_axis,
        LevelData.WALK_SPEED * (0.55 if quiet_mode else 1.0)
    )
    if dash_time > 0.0: velocity = dash_direction * DASH_SPEED
    if garden_terrain:
        floor_snap_length=.4
        floor_max_angle=deg_to_rad(52)
        velocity.y=-.5 if is_on_floor() else vertical_speed-18.0*delta
    move_and_slide()
    camera.position.y = move_toward(camera.position.y, eye_height - (0.30 if quiet_mode else 0.0), delta * 2.4)

    if fire_requested:
        fire_requested = false
        _perform_fire()

    var travelled := global_position.distance_to(before_move)
    if travelled > 0.002:
        foot_timer -= delta
        if foot_timer <= 0.0:
            SignalBus.emit_audio_event(
                &"footstep",
                Vector3(global_position.x, global_position.y, global_position.z)
            )
            foot_timer = FOOTSTEP_INTERVAL * (1.8 if quiet_mode else 1.0)
    else:
        foot_timer = 0.0

func toggle_quiet() -> void:
    if not input_enabled or health.is_dead or PauseManager.is_paused: return
    quiet_mode = not quiet_mode

func request_dash() -> bool:
    if not input_enabled or health.is_dead or PauseManager.is_paused or dash_cooldown > 0.0: return false
    var axis := _read_move_axis()
    dash_direction = MovementMath.velocity_for_input(global_basis, axis, 1.0)
    if dash_direction.length_squared() < 0.01: dash_direction = -global_basis.z
    dash_direction.y = 0.0
    dash_direction = dash_direction.normalized()
    quiet_mode = false
    dash_time = DASH_DURATION
    dash_cooldown = DASH_COOLDOWN
    if is_instance_valid(heist): heist.make_noise(global_position, 14.0, 5.0)
    return true

func request_fire() -> void:
    if not input_enabled or health.is_dead or fire_requested:
        return

    if not FireQuery.can_fire(false, false, fire_cooldown, ammo):
        if ammo <= 0 and fire_cooldown <= 0.0:
            SignalBus.show_message.emit("Пусто. Даже белки в шоке.", 1.2)
        return

    fire_requested = true

func _perform_fire() -> void:
    if not input_enabled or health.is_dead:
        return

    if not FireQuery.can_fire(false, false, fire_cooldown, ammo):
        return

    ammo = AmmoMath.consume_one(ammo)
    _feedback_generation += 1
    fire_cooldown = FIRE_COOLDOWN
    recoil_time = 0.10

    SignalBus.weapon_changed.emit(self, &"l1_sidearm", ammo)
    SignalBus.combat_event.emit(
        &"weapon_fired",
        Vector2(global_position.x, global_position.z)
    )
    SignalBus.emit_audio_event(
        &"shoot",
        Vector3(global_position.x, global_position.y, global_position.z)
    )

    var hit := CombatQuery.raycast(get_world_3d(), camera)
    if hit.is_empty():
        _show_miss_feedback()
        return

    var hitbox := hit.get("collider") as Hitbox3DComponent
    if hitbox == null or hitbox.get_parent() == null:
        _show_miss_feedback()
        return

    var target := hitbox.get_parent()
    if not target.is_in_group("level1_enemy") and not target.is_in_group("woodland_target"):
        _show_miss_feedback()
        return

    var applied := hitbox.receive_hit(1, self)
    if not applied:
        _show_miss_feedback()
        return

    SignalBus.combat_event.emit(
        &"weapon_hit",
        Vector2(global_position.x, global_position.z)
    )

    _clear_weapon_feedback_later(0.35)

func _show_miss_feedback() -> void:
    SignalBus.combat_event.emit(
        &"weapon_missed",
        Vector2(global_position.x, global_position.z)
    )
    SignalBus.show_message.emit(
        "Мимо. Белки делают вид, что ничего не заметили.",
        1.1
    )
    _clear_weapon_feedback_later(0.22)

func _clear_weapon_feedback_later(delay: float) -> void:
    var generation := _feedback_generation
    await get_tree().create_timer(delay).timeout
    if generation == _feedback_generation and is_inside_tree() and input_enabled and not health.is_dead:
        SignalBus.combat_event.emit(
            &"weapon_feedback_clear",
            Vector2(global_position.x, global_position.z)
        )

func take_damage(amount: int, source: Node = null) -> bool:
    if not input_enabled or health.is_dead or damage_cooldown > 0.0:
        return false

    var applied := health.apply_damage(amount, source)
    if applied:
        damage_cooldown = DAMAGE_COOLDOWN
    return applied

func get_hp() -> int:
    return health.current_health if health != null else 0

func get_max_hp() -> int:
    return health.max_health if health != null else LevelData.MAX_HP

func get_ammo() -> int:
    return ammo

func stop() -> void:
    input_enabled = false
    fire_requested = false
    move_axis = Vector2.ZERO
    velocity = Vector3.ZERO
    dash_time = 0.0
    quiet_mode = false

func resume() -> void:
    if not health.is_dead:
        input_enabled = true

func is_level1_player() -> bool:
    return true

func handle_mouse_motion(relative: Vector2) -> void:
    if not desktop_mode or not input_enabled or health.is_dead:
        return
    rotate_y(-relative.x * MOUSE_SENSITIVITY)
    camera.rotation.x = clampf(camera.rotation.x-relative.y*MOUSE_SENSITIVITY,deg_to_rad(-48.0),deg_to_rad(60.0))

func handle_touch_look(relative: Vector2) -> void:
    if input_enabled and not health.is_dead:
        rotate_y(-relative.x * 0.005)
        camera.rotation.x = clampf(camera.rotation.x-relative.y*0.004,deg_to_rad(-48.0),deg_to_rad(60.0))

func _read_move_axis() -> Vector2:
    var axis := Input.get_vector(
        "l1_move_left",
        "l1_move_right",
        "l1_move_forward",
        "l1_move_backward"
    )
    return axis.normalized() if axis.length_squared() > 1.0 else axis
