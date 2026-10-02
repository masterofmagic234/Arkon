extends CharacterBody3D
class_name Level1Player

const LevelData = preload("res://scripts/level_data.gd")
const MovementMath = preload("res://scripts/movement_math.gd")
const TurnMath = preload("res://scripts/turn_math.gd")
const JoystickMath = preload("res://scripts/joystick_math.gd")
const CombatQuery = preload("res://scripts/combat_query.gd")
const FireQuery = preload("res://scripts/fire_query.gd")
const AmmoMath = preload("res://scripts/ammo_math.gd")
const HealthComponent = preload("res://scripts/components/health_component.gd")

const MOUSE_SENSITIVITY := 0.0032
const FIRE_COOLDOWN := 0.18
const FOOTSTEP_INTERVAL := 0.30
const DAMAGE_COOLDOWN := 0.80

@onready var camera: Camera3D = $Camera3D
@onready var health: HealthComponent = $Health

var joystick: Panel
var knob: Panel
var move_axis := Vector2.ZERO
var joystick_touch_id := -1
var desktop_mode := false
var input_enabled := true

var fire_cooldown := 0.0
var damage_cooldown := 0.0
var recoil_time := 0.0
var foot_timer := 0.0
var ammo := LevelData.MAX_AMMO

func _ready() -> void:
    add_to_group("level1_player")
    desktop_mode = not OS.has_feature("mobile")
    health.reset(LevelData.MAX_HP)
    SignalBus.weapon_changed.emit(self, &"l1_sidearm", ammo)

func setup_input(joystick_node: Panel, knob_node: Panel) -> void:
    joystick = joystick_node
    knob = knob_node

    if joystick != null and knob != null:
        knob.position = joystick.size * 0.5 - knob.size * 0.5
        if not joystick.gui_input.is_connected(_on_joystick_gui_input):
            joystick.gui_input.connect(_on_joystick_gui_input)

    input_enabled = true

func _physics_process(delta: float) -> void:
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    damage_cooldown = maxf(0.0, damage_cooldown - delta)
    recoil_time = maxf(0.0, recoil_time - delta)

    if not input_enabled or health.is_dead:
        velocity = Vector3.ZERO
        return

    if desktop_mode:
        move_axis = _desktop_move_axis()

    velocity = MovementMath.velocity_for_input(
        global_transform.basis,
        move_axis,
        LevelData.WALK_SPEED
    )
    move_and_slide()

    if desktop_mode:
        var turn_axis := Input.get_axis("l1_turn_left", "l1_turn_right")
        if abs(turn_axis) > 0.0:
            rotate_y(TurnMath.turn_amount(turn_axis, LevelData.TURN_SPEED, delta))
    elif abs(move_axis.x) > 0.04:
        rotate_y(TurnMath.turn_amount(move_axis.x, LevelData.TURN_SPEED, delta))

    var forward := -move_axis.y
    if abs(forward) > 0.05:
        foot_timer -= delta
        if foot_timer <= 0.0:
            SignalBus.emit_audio_event(
                &"footstep",
                Vector3(global_position.x, global_position.y, global_position.z)
            )
            foot_timer = FOOTSTEP_INTERVAL
    else:
        foot_timer = 0.0

func request_fire() -> void:
    if not input_enabled or health.is_dead:
        return

    if not FireQuery.can_fire(false, false, fire_cooldown, ammo):
        if ammo <= 0 and fire_cooldown <= 0.0:
            SignalBus.show_message.emit("Пусто. Даже белки в шоке.", 1.2)
        return

    ammo = AmmoMath.consume_one(ammo)
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
        await _show_miss_feedback()
        return

    var hitbox := hit.get("collider") as Hitbox3DComponent
    if hitbox == null or hitbox.get_parent() == null:
        await _show_miss_feedback()
        return

    var target := hitbox.get_parent()
    if not target.is_in_group("level1_enemy"):
        await _show_miss_feedback()
        return

    hitbox.receive_hit(1, self)
    SignalBus.combat_event.emit(
        &"weapon_hit",
        Vector2(global_position.x, global_position.z)
    )

    await get_tree().create_timer(0.35).timeout
    if is_inside_tree() and input_enabled and not health.is_dead:
        SignalBus.combat_event.emit(
            &"weapon_feedback_clear",
            Vector2(global_position.x, global_position.z)
        )

func _show_miss_feedback() -> void:
    SignalBus.combat_event.emit(
        &"weapon_missed",
        Vector2(global_position.x, global_position.z)
    )
    SignalBus.show_message.emit(
        "Мимо. Белки делают вид, что ничего не заметили.",
        1.1
    )

    await get_tree().create_timer(0.22).timeout
    if is_inside_tree() and input_enabled and not health.is_dead:
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
    move_axis = Vector2.ZERO
    velocity = Vector3.ZERO
    _reset_joystick()

func resume() -> void:
    if not health.is_dead:
        input_enabled = true

func is_level1_player() -> bool:
    return true

func handle_mouse_motion(relative: Vector2) -> void:
    if not desktop_mode or not input_enabled or health.is_dead:
        return
    rotate_y(-relative.x * MOUSE_SENSITIVITY)

func _desktop_move_axis() -> Vector2:
    var axis := Vector2(
        Input.get_axis("l1_move_left", "l1_move_right"),
        Input.get_axis("l1_move_forward", "l1_move_backward")
    )
    return axis.normalized() if axis.length_squared() > 1.0 else axis

func _on_joystick_gui_input(event: InputEvent) -> void:
    if desktop_mode or not input_enabled:
        return

    if event is InputEventScreenTouch:
        if event.pressed:
            joystick_touch_id = event.index
            _update_joystick(event.position)
            joystick.accept_event()
        elif event.index == joystick_touch_id:
            joystick_touch_id = -1
            move_axis = Vector2.ZERO
            _reset_joystick()
            joystick.accept_event()

    elif event is InputEventScreenDrag and event.index == joystick_touch_id:
        _update_joystick(event.position)
        joystick.accept_event()

    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            joystick_touch_id = -2
            _update_joystick(event.position)
            joystick.accept_event()
        elif joystick_touch_id == -2:
            joystick_touch_id = -1
            move_axis = Vector2.ZERO
            _reset_joystick()
            joystick.accept_event()

    elif event is InputEventMouseMotion and joystick_touch_id == -2:
        _update_joystick(event.position)
        joystick.accept_event()

func _update_joystick(position: Vector2) -> void:
    if joystick == null or knob == null:
        return

    var center := joystick.size * 0.5
    var delta := JoystickMath.clamped_delta(
        position,
        center,
        LevelData.JOYSTICK_RADIUS
    )
    move_axis = JoystickMath.axis_from_delta(
        delta,
        LevelData.JOYSTICK_RADIUS
    )
    knob.position = center - knob.size * 0.5 + delta

func _reset_joystick() -> void:
    if joystick != null and knob != null:
        knob.position = joystick.size * 0.5 - knob.size * 0.5
