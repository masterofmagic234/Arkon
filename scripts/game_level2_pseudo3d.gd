extends Node2D

const RaceState = preload("res://scripts/race_state.gd")
const RaceController = preload("res://scripts/race_controller.gd")
const RaceInput = preload("res://scripts/race_input.gd")
const RaceCameraState = preload("res://scripts/race_camera_state.gd")

const HUD_TOP_FRACTION: float = 505.0 / 720.0
const BASE_VIEWPORT_SIZE := Vector2(1280.0, 720.0)

@onready var renderer: Node2D = $Renderer
@onready var hud_panel: Node = $HUD/HUDRoot
@onready var hud_background: Panel = $HUD/Panel
@onready var minimap: Control = $HUD/Minimap
@onready var joystick: Panel = $HUD/Joystick
@onready var joystick_knob: Panel = $HUD/Joystick/Knob
@onready var gas_button: Button = $HUD/Gas
@onready var brake_button: Button = $HUD/Brake
@onready var message_label: Label = $HUD/Message
@onready var countdown_label: Label = $HUD/Panel/Countdown
@onready var car_3d_overlay: Control = $Car3DOverlay

var state
var controller
var race_input
var race_music: AudioStreamPlayer
var camera_state

func _force_level3_dev_mode() -> bool:
    if not bool(ProjectSettings.get_setting("run/dev_force_level3", false)):
        return false
    get_tree().change_scene_to_file("res://scenes/level3_store.tscn")
    return true

func _ready() -> void:
    if _force_level3_dev_mode():
        return

    get_viewport().size_changed.connect(_layout_responsive_ui)
    _layout_responsive_ui()
    state = RaceState.new()
    race_input = RaceInput.new()
    race_input.setup(joystick, joystick_knob, gas_button, brake_button)
    controller = RaceController.new()
    controller.setup(self, null, [], null, hud_panel, null, null, null, state, Callable(self, "_on_mission_end"))
    controller.start()
    camera_state = RaceCameraState.new()
    camera_state.reset(controller.player)
    _start_race_music()
    print("Level 2 track size: ", controller.track_pattern.size())
    renderer.bind(
        state,
        controller.player,
        controller.ais,
        controller.track_pattern,
        controller.track_x,
        camera_state
    )
    if car_3d_overlay != null and car_3d_overlay.has_method("bind_camera_state"):
        car_3d_overlay.call("bind_camera_state", camera_state)
    hud_panel.bind(controller.player)
    minimap.bind(state, controller.player, controller.ais, controller.track_pattern, controller.track_x)

func _layout_responsive_ui() -> void:
    if not is_instance_valid(hud_background):
        return

    var viewport_size := get_viewport_rect().size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return

    var scale_factor: float = clampf(
        minf(viewport_size.x / BASE_VIEWPORT_SIZE.x, viewport_size.y / BASE_VIEWPORT_SIZE.y),
        0.65,
        1.20
    )
    var panel_top: float = viewport_size.y * HUD_TOP_FRACTION
    hud_background.offset_left = 0.0
    hud_background.offset_top = panel_top
    hud_background.offset_right = viewport_size.x
    hud_background.offset_bottom = viewport_size.y

    var joystick_size := Vector2(150.0, 150.0) * scale_factor
    joystick.position = Vector2(24.0 * scale_factor, panel_top + 20.0 * scale_factor)
    joystick.size = joystick_size
    joystick_knob.size = Vector2(60.0, 60.0) * scale_factor
    joystick_knob.position = joystick.size * 0.5 - joystick_knob.size * 0.5

    var button_size := Vector2(185.0, 65.0) * scale_factor
    var right_margin := 85.0 * scale_factor
    brake_button.position = Vector2(
        viewport_size.x - right_margin - button_size.x,
        panel_top + 20.0 * scale_factor
    )
    brake_button.size = button_size
    gas_button.position = Vector2(
        viewport_size.x - right_margin - button_size.x,
        panel_top + 95.0 * scale_factor
    )
    gas_button.size = button_size

    var minimap_size := Vector2(260.0, 200.0) * scale_factor
    minimap.position = Vector2(
        viewport_size.x * 0.5 - minimap_size.x * 0.5,
        panel_top + 5.0 * scale_factor
    )
    minimap.size = minimap_size

    message_label.position = Vector2(
        viewport_size.x * 0.15625,
        viewport_size.y * (440.0 / 720.0)
    )
    message_label.size = Vector2(
        viewport_size.x * 0.6875,
        viewport_size.y * (40.0 / 720.0)
    )

    countdown_label.position = Vector2(
        viewport_size.x * 0.5 - 130.0 * scale_factor,
        20.0 * scale_factor
    )
    countdown_label.size = Vector2(260.0 * scale_factor, 160.0 * scale_factor)

func _start_race_music() -> void:
    race_music = get_node_or_null("RaceMusic") as AudioStreamPlayer
    if race_music == null:
        push_warning("Level 2 RaceMusic node is missing.")
        return
    if race_music.stream == null:
        push_warning("Level 2 RaceMusic has no stream.")
        return
    race_music.bus = "Master"
    var mp3 := race_music.stream as AudioStreamMP3
    if mp3 != null:
        mp3.loop = true
    # AudioManager owns persisted music mute/volume and the active scene player.
    AudioManager.register_music(race_music)

func _physics_process(delta: float) -> void:
    var input: Dictionary = race_input.read()
    # Race simulation advances on the fixed physics clock. Input is sampled
    # immediately before each fixed simulation step.
    controller.handle_input(
        float(input["steer"]),
        float(input["throttle"]),
        float(input["brake"])
    )
    controller.update(minf(delta, 0.25))

func _process(delta: float) -> void:
    if controller == null or controller.player == null or camera_state == null:
        return

    # Level2 owns the camera state. The pseudo-3D renderer applies yaw/roll
    # directly in its projection, while the car overlay uses the same state.
    camera_state.update_from_race_car(controller.player, delta)
    if renderer != null:
        renderer.queue_redraw()

    if car_3d_overlay != null and car_3d_overlay.has_method("sync_from_race_car"):
        car_3d_overlay.call(
            "sync_from_race_car",
            controller.player,
            controller.track_x,
            get_viewport_rect().size,
            camera_state,
            float(renderer.call("get_current_curve")) if renderer != null else 0.0,
            delta
        )

func _on_mission_end() -> void:
    var signal_bus := get_node_or_null("/root/SignalBus")
    if signal_bus != null:
        signal_bus.emit_signal(&"level_completed", &"level2")
