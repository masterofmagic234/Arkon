extends CanvasLayer
class_name Level2MobileInput

const JoystickMath = preload("res://scripts/joystick_math.gd")

@onready var joystick: Panel = $Joystick
@onready var knob: Panel = $Joystick/Knob
@onready var gas_button: Button = $Gas
@onready var brake_button: Button = $Brake

var joystick_touch_id := -1

func _ready() -> void:
    if not OS.has_feature("mobile"):
        joystick.visible = false
        knob.visible = false
        gas_button.visible = false
        brake_button.visible = false
        return

    _layout_mobile_controls()
    if not get_viewport().size_changed.is_connected(_layout_mobile_controls):
        get_viewport().size_changed.connect(_layout_mobile_controls)

    if not joystick.gui_input.is_connected(_on_joystick_gui_input):
        joystick.gui_input.connect(_on_joystick_gui_input)
    if not gas_button.button_down.is_connected(_on_gas_down):
        gas_button.button_down.connect(_on_gas_down)
    if not gas_button.button_up.is_connected(_on_gas_up):
        gas_button.button_up.connect(_on_gas_up)
    if not brake_button.button_down.is_connected(_on_brake_down):
        brake_button.button_down.connect(_on_brake_down)
    if not brake_button.button_up.is_connected(_on_brake_up):
        brake_button.button_up.connect(_on_brake_up)

func _exit_tree() -> void:
    if get_viewport() != null and get_viewport().size_changed.is_connected(_layout_mobile_controls):
        get_viewport().size_changed.disconnect(_layout_mobile_controls)
    _release_steer()
    Input.action_release("race_accel")
    Input.action_release("race_brake")

func _layout_mobile_controls() -> void:
    if not OS.has_feature("mobile") or joystick == null:
        return

    var viewport_size := get_viewport().get_visible_rect().size
    var side_margin := clampf(viewport_size.x * 0.025, 24.0, 42.0)
    var bottom_margin := clampf(viewport_size.y * 0.035, 18.0, 30.0)

    joystick.size = Vector2(180.0, 180.0)
    joystick.position = Vector2(
        side_margin,
        viewport_size.y - joystick.size.y - bottom_margin
    )

    knob.size = Vector2(70.0, 70.0)
    knob.position = joystick.size * 0.5 - knob.size * 0.5

    var pedal_width := clampf(viewport_size.x * 0.16, 180.0, 224.0)
    var pedal_height := 72.0
    var pedal_x := viewport_size.x - pedal_width - side_margin

    brake_button.position = Vector2(
        pedal_x,
        viewport_size.y - pedal_height * 2.0 - bottom_margin - 8.0
    )
    brake_button.size = Vector2(pedal_width, pedal_height)

    gas_button.position = Vector2(
        pedal_x,
        viewport_size.y - pedal_height - bottom_margin
    )
    gas_button.size = Vector2(pedal_width, pedal_height)

func _on_gas_down() -> void:
    Input.action_press("race_accel", 1.0)

func _on_gas_up() -> void:
    Input.action_release("race_accel")

func _on_brake_down() -> void:
    Input.action_press("race_brake", 1.0)

func _on_brake_up() -> void:
    Input.action_release("race_brake")

func _on_joystick_gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            joystick_touch_id = event.index
            _update_joystick(event.position)
            joystick.accept_event()
        elif event.index == joystick_touch_id:
            joystick_touch_id = -1
            _release_steer()
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
            _release_steer()
            _reset_joystick()
            joystick.accept_event()

    elif event is InputEventMouseMotion and joystick_touch_id == -2:
        _update_joystick(event.position)
        joystick.accept_event()

func _update_joystick(position: Vector2) -> void:
    var center := joystick.size * 0.5
    var delta := JoystickMath.clamped_delta(position, center, 88.0)
    var axis := JoystickMath.axis_from_delta(delta, 88.0)
    _set_steer(axis.x)
    knob.position = center - knob.size * 0.5 + delta

func _set_steer(value: float) -> void:
    if value < -0.001:
        Input.action_release("race_right")
        Input.action_press("race_left", minf(-value, 1.0))
    elif value > 0.001:
        Input.action_release("race_left")
        Input.action_press("race_right", minf(value, 1.0))
    else:
        _release_steer()

func _release_steer() -> void:
    Input.action_release("race_left")
    Input.action_release("race_right")

func _reset_joystick() -> void:
    knob.position = joystick.size * 0.5 - knob.size * 0.5
