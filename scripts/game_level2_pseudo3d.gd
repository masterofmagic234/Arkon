extends Node2D

const RaceState = preload("res://scripts/race_state.gd")
const RaceController = preload("res://scripts/race_controller.gd")
const RaceInput = preload("res://scripts/race_input.gd")
const RaceCameraState = preload("res://scripts/race_camera_state.gd")
const RaceVehicleAudio = preload("res://scripts/race_vehicle_audio.gd")

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
var vehicle_audio
var render_player=preload("res://scripts/race_render_car.gd").new()
var render_ais: Array=[]
var presentation: CanvasLayer
var ready_for_play: bool:
    get:
        return controller != null and is_instance_valid(car_3d_overlay) and car_3d_overlay.is_presentation_ready()

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
    renderer.pursuit=controller.pursuit
    car_3d_overlay.pursuit=controller.pursuit
    camera_state = RaceCameraState.new()
    camera_state.reset(controller.player)
    render_player.setup(controller.player)
    for ai in controller.ais:
        var pose=preload("res://scripts/race_render_car.gd").new();pose.setup(ai.car)
        render_ais.append({"car":pose})
    vehicle_audio = RaceVehicleAudio.new()
    vehicle_audio.name = "VehicleAudio"
    add_child(vehicle_audio)
    vehicle_audio.bind(controller.player)
    var pursuit_audio:=preload("res://scripts/race_pursuit_audio.gd").new()
    pursuit_audio.name="PursuitAudio";add_child(pursuit_audio);pursuit_audio.bind(self)
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
        car_3d_overlay.call("bind_camera_state", camera_state, renderer)
    hud_panel.bind(controller.player)
    minimap.bind(state, controller.player, controller.ais, controller.track_pattern, controller.track_x)
    presentation = preload("res://scripts/race_presentation.gd").new()
    add_child(presentation)
    presentation.bind(self)

func _layout_responsive_ui() -> void:
    if presentation != null: presentation.layout()

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
    if get_node("/root/SceneFlow").is_loading_gameplay(): return
    # Do not run an invisible countdown/drive while the deferred GLB and its
    # shared vehicle target are still being built during a scene transition.
    if controller == null or not is_instance_valid(car_3d_overlay) or not car_3d_overlay.is_model_ready():
        return
    var input: Dictionary = race_input.read()
    # Race simulation advances on the fixed physics clock. Input is sampled
    # immediately before each fixed simulation step.
    controller.handle_input(
        float(input["steer"]),
        float(input["throttle"]),
        float(input["brake"])
    )
    controller.update(minf(delta, 0.25))
    render_player.capture()
    for ai in render_ais: ai.car.capture()
    renderer.update_skid_marks(minf(delta, 0.25))

func _process(delta: float) -> void:
    if controller == null or controller.player == null or camera_state == null:
        return

    # Level2 owns the camera state. The pseudo-3D renderer applies yaw/roll
    # directly in its projection, while the car overlay uses the same state.
    var presented=controller.player
    if is_physics_processing():
        var fraction := clampf(Engine.get_physics_interpolation_fraction(),0.0,1.0)
        render_player.sample(fraction);presented=render_player
        for ai in render_ais: ai.car.sample(fraction)
        renderer.ai_cars=render_ais
    else:
        renderer.ai_cars=controller.ais
    renderer.player_car=presented
    camera_state.update_from_race_car(presented, delta)
    if renderer != null:
        renderer.queue_redraw()

    if car_3d_overlay != null and car_3d_overlay.has_method("sync_from_race_car"):
        car_3d_overlay.call(
            "sync_from_race_car",
            presented,
            controller.track_x,
            get_viewport_rect().size,
            camera_state,
            float(renderer.call("get_current_curve")) if renderer != null else 0.0,
            delta
        )

func _on_mission_end() -> void:
    if presentation != null: presentation.show_finish(not state.mission_failed)

func _input(event: InputEvent) -> void:
    if race_input==null or get_tree().paused or (state!=null and state.race_finished): return
    if race_input.handle_event(event): get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and is_node_ready() and race_input!=null:
        race_input.stop()
        get_node("/root/PauseManager").set_paused(true)

func _exit_tree() -> void:
    if race_input!=null: race_input.stop()
    if controller!=null: controller.teardown()

func continue_campaign() -> void:
    if state.mission_complete and not state.mission_failed:
        get_node("/root/SignalBus").emit_signal(&"level_completed", &"level2")
