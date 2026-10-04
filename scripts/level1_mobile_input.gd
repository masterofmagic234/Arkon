extends CanvasLayer
class_name Level1MobileInput

const LevelData = preload("res://scripts/level_data.gd")
const JoystickMath = preload("res://scripts/joystick_math.gd")

const BASE_VIEWPORT_SIZE := Vector2(1280.0, 720.0)

@onready var top_panel: Panel = $Top
@onready var count_label: Label = $Count
@onready var carolina: TextureRect = $Carolina
@onready var hp_ammo_label: Label = $HPAmmo
@onready var mute_button: Button = $Mute
@onready var crosshair: Label = $Crosshair
@onready var hit_marker: Label = $HitMarker
@onready var message_label: Label = $Message
@onready var joystick: Panel = $Joystick
@onready var knob: Panel = $Joystick/Knob
@onready var fire_button: Button = $Fire
@onready var weapon: TextureRect = $Weapon
@onready var minimap: Control = $Minimap
@onready var mission: Panel = $Mission
@onready var player: Level1Player = get_parent().get_node_or_null("Player") as Level1Player

var joystick_touch_id := -1
var ui_scale := 1.0

func _ready() -> void:
    if not get_viewport().size_changed.is_connected(_layout_responsive_ui):
        get_viewport().size_changed.connect(_layout_responsive_ui)

    _layout_responsive_ui()

    if not joystick.gui_input.is_connected(_on_joystick_gui_input):
        joystick.gui_input.connect(_on_joystick_gui_input)

    if not fire_button.button_down.is_connected(_on_fire_button_down):
        fire_button.button_down.connect(_on_fire_button_down)

    if not fire_button.button_up.is_connected(_on_fire_button_up):
        fire_button.button_up.connect(_on_fire_button_up)

func _exit_tree() -> void:
    if get_viewport().size_changed.is_connected(_layout_responsive_ui):
        get_viewport().size_changed.disconnect(_layout_responsive_ui)

    _release_move_actions()

func _on_fire_button_down() -> void:
    # Mobile fire is explicit. Do not synthesize the l1_fire InputMap action:
    # the project emulates mouse events from touch, and a touch on the movement
    # stick would otherwise look like a left mouse click.
    if player != null:
        player.request_fire()

func _on_fire_button_up() -> void:
    pass

func _layout_responsive_ui() -> void:
    var viewport_size := get_viewport_rect().size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return

    ui_scale = clampf(
        minf(
            viewport_size.x / BASE_VIEWPORT_SIZE.x,
            viewport_size.y / BASE_VIEWPORT_SIZE.y
        ),
        0.72,
        1.35
    )
    var margin := clampf(
        minf(viewport_size.x, viewport_size.y) * 0.026,
        16.0,
        32.0
    )

    top_panel.position = Vector2(margin, margin)
    top_panel.size = Vector2(460.0, 78.0) * ui_scale

    var count_size := Vector2(265.0, 35.0) * ui_scale
    count_label.position = Vector2(
        viewport_size.x * 0.5 - count_size.x * 0.5,
        margin + 10.0 * ui_scale
    )
    count_label.size = count_size

    var mute_size := Vector2(60.0, 50.0) * ui_scale
    mute_button.size = mute_size
    mute_button.position = Vector2(
        viewport_size.x - margin - mute_size.x,
        margin
    )

    var hp_size := Vector2(185.0, 41.0) * ui_scale
    hp_ammo_label.size = hp_size
    hp_ammo_label.position = Vector2(
        mute_button.position.x - 12.0 * ui_scale - hp_size.x,
        margin + 7.0 * ui_scale
    )

    var portrait_size := Vector2(60.0, 60.0) * ui_scale
    carolina.size = portrait_size
    carolina.position = Vector2(
        hp_ammo_label.position.x - 12.0 * ui_scale - portrait_size.x,
        margin
    )

    var cross_size := Vector2(40.0, 50.0) * ui_scale
    crosshair.size = cross_size
    crosshair.position = Vector2(
        viewport_size.x * 0.5 - cross_size.x * 0.5,
        viewport_size.y * 0.5 - cross_size.y * 0.5
    )

    var hit_size := Vector2(40.0, 40.0) * ui_scale
    hit_marker.size = hit_size
    hit_marker.position = Vector2(
        viewport_size.x * 0.5 - hit_size.x * 0.5,
        viewport_size.y * 0.5 - 44.0 * ui_scale
    )

    var message_size := Vector2(860.0, 50.0) * ui_scale
    message_label.size = message_size
    message_label.position = Vector2(
        viewport_size.x * 0.5 - message_size.x * 0.5,
        viewport_size.y * 0.72 - message_size.y * 0.5
    )

    var joystick_size := Vector2(176.0, 176.0) * ui_scale
    joystick.position = Vector2(
        margin,
        viewport_size.y - margin - joystick_size.y
    )
    joystick.size = joystick_size

    var knob_size := Vector2(70.0, 70.0) * ui_scale
    knob.size = knob_size
    knob.position = joystick.size * 0.5 - knob.size * 0.5

    var fire_size := Vector2(150.0, 150.0) * ui_scale
    fire_button.size = fire_size
    fire_button.position = Vector2(
        viewport_size.x - margin - fire_size.x,
        viewport_size.y - margin - fire_size.y
    )

    var weapon_size := Vector2(350.0, 250.0) * ui_scale
    weapon.size = weapon_size
    weapon.position = Vector2(
        viewport_size.x - margin - weapon_size.x,
        viewport_size.y - margin - weapon_size.y
    )

    var minimap_size := Vector2(185.0, 135.0) * ui_scale
    minimap.size = minimap_size
    minimap.position = Vector2(
        viewport_size.x - margin - minimap_size.x,
        margin + 84.0 * ui_scale
    )

    var mission_size := Vector2(
        minf(640.0 * ui_scale, viewport_size.x - margin * 2.0),
        minf(380.0 * ui_scale, viewport_size.y - margin * 2.0)
    )
    mission.size = mission_size
    mission.position = Vector2(
        viewport_size.x * 0.5 - mission_size.x * 0.5,
        viewport_size.y * 0.5 - mission_size.y * 0.5
    )

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
    var radius := LevelData.JOYSTICK_RADIUS * ui_scale
    var delta := JoystickMath.clamped_delta(position, center, radius)
    var axis := JoystickMath.axis_from_delta(delta, radius)

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
