extends CanvasLayer
class_name Level1MobileInput

const LevelData = preload("res://scripts/level_data.gd")
const JoystickMath = preload("res://scripts/joystick_math.gd")

@onready var joystick: Panel = $Joystick
@onready var knob: Panel = $Joystick/Knob
@onready var fire_button: Button = $Fire

var joystick_touch_id := -1

func _ready() -> void:
    knob.position = joystick.size * 0.5 - knob.size * 0.5

    if not joystick.gui_input.is_connected(_on_joystick_gui_input):
        joystick.gui_input.connect(_on_joystick_gui_input)

    if not fire_button.button_down.is_connected(_on_fire_button_down):
        fire_button.button_down.connect(_on_fire_button_down)

    if not fire_button.button_up.is_connected(_on_fire_button_up):
        fire_button.button_up.connect(_on_fire_button_up)

func _exit_tree() -> void:
    _release_move_actions()
    Input.action_release("l1_fire")

func _on_fire_button_down() -> void:
    Input.action_press("l1_fire", 1.0)

func _on_fire_button_up() -> void:
    Input.action_release("l1_fire")

func _on_joystick_gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            joystick_touch_id = event.index
            _update_joystick(event.position)
            joystick.accept_event()
        elif event.index == joystick_touch_id:
            joystick_touch_id = -1
            _release_move_actions()
            _reset_knob()
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
            _release_move_actions()
            _reset_knob()
            joystick.accept_event()

    elif event is InputEventMouseMotion and joystick_touch_id == -2:
        _update_joystick(event.position)
        joystick.accept_event()

func _update_joystick(position: Vector2) -> void:
    var center := joystick.size * 0.5
    var delta := JoystickMath.clamped_delta(
        position,
        center,
        LevelData.JOYSTICK_RADIUS
    )
    var axis := JoystickMath.axis_from_delta(
        delta,
        LevelData.JOYSTICK_RADIUS
    )

    _set_axis_actions(axis)
    knob.position = center - knob.size * 0.5 + delta

func _set_axis_actions(axis: Vector2) -> void:
    _set_action("l1_move_left", -axis.x)
    _set_action("l1_move_right", axis.x)
    _set_action("l1_move_forward", -axis.y)
    _set_action("l1_move_backward", axis.y)

func _release_move_actions() -> void:
    for action in [
        "l1_move_left",
        "l1_move_right",
        "l1_move_forward",
        "l1_move_backward"
    ]:
        Input.action_release(action)

func _set_action(action: StringName, strength: float) -> void:
    if strength > 0.001:
        Input.action_press(action, minf(strength, 1.0))
    else:
        Input.action_release(action)

func _reset_knob() -> void:
    knob.position = joystick.size * 0.5 - knob.size * 0.5
