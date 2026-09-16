extends RefCounted

# Full player-side controller. The UI joystick events remain identical to the
# proven V20 path; this controller now owns their state and player movement.
const LevelData = preload("res://scripts/level_data.gd")
const MovementMath = preload("res://scripts/movement_math.gd")
const TurnMath = preload("res://scripts/turn_math.gd")
const JoystickMath = preload("res://scripts/joystick_math.gd")

var player
var joystick: Panel
var knob: Panel
var audio_controller
var move_axis := Vector2.ZERO
var joystick_touch_id := -1

func setup(player_node, joystick_node: Panel, knob_node: Panel, audio_node) -> void:
    player = player_node
    joystick = joystick_node
    knob = knob_node
    audio_controller = audio_node
    knob.position = joystick.size * 0.5 - knob.size * 0.5
    joystick.gui_input.connect(_on_joystick_gui_input)

func update(delta: float, foot_timer: float) -> float:
    if player == null:
        return foot_timer

    player.velocity = MovementMath.velocity_for_input(player.global_transform.basis, move_axis, LevelData.WALK_SPEED)
    player.move_and_slide()
    if abs(move_axis.x) > 0.04:
        player.rotate_y(TurnMath.turn_amount(move_axis.x, LevelData.TURN_SPEED, delta))

    var forward := -move_axis.y
    if abs(forward) > 0.05:
        foot_timer -= delta
        if foot_timer <= 0.0:
            if audio_controller != null:
                audio_controller.footstep()
            foot_timer = 0.30
    else:
        foot_timer = 0.0
    return foot_timer

func stop() -> void:
    move_axis = Vector2.ZERO
    _reset_joystick()
    if player != null:
        player.velocity = Vector3.ZERO

func get_move_axis() -> Vector2:
    return move_axis

func _on_joystick_gui_input(event: InputEvent) -> void:
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
    var center := joystick.size * 0.5
    var delta := JoystickMath.clamped_delta(position, center, LevelData.JOYSTICK_RADIUS)
    move_axis = JoystickMath.axis_from_delta(delta, LevelData.JOYSTICK_RADIUS)
    knob.position = center - knob.size * 0.5 + delta

func _reset_joystick() -> void:
    if joystick != null and knob != null:
        knob.position = joystick.size * 0.5 - knob.size * 0.5
