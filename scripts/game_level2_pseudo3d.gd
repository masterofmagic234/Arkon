extends Node2D

const RaceState = preload("res://scripts/race_state.gd")
const RaceController = preload("res://scripts/race_controller.gd")
const RaceInput = preload("res://scripts/race_input.gd")

@onready var renderer: Node2D = $Renderer
@onready var hud_panel: Node = $HUD/HUDRoot
@onready var minimap: Control = $HUD/Minimap
@onready var joystick: Panel = $HUD/Joystick
@onready var joystick_knob: Panel = $HUD/Joystick/Knob
@onready var gas_button: Button = $HUD/Gas
@onready var brake_button: Button = $HUD/Brake
@onready var message_label: Label = $HUD/Message
@onready var countdown_label: Label = $HUD/Panel/Countdown

var state
var controller
var race_input
var race_music: AudioStreamPlayer

func _ready() -> void:
    state = RaceState.new()
    race_input = RaceInput.new()
    race_input.setup(joystick, joystick_knob, gas_button, brake_button)
    controller = RaceController.new()
    controller.setup(self, null, [], null, hud_panel, null, null, null, state, Callable(self, "_on_mission_end"))
    controller.start()
    _start_race_music()
    print("Level 2 track size: ", controller.track_pattern.size())
    renderer.bind(state, controller.player, controller.ais, controller.track_pattern, controller.track_x)
    hud_panel.bind(state, controller.player)
    minimap.bind(state, controller.player, controller.ais, controller.track_pattern, controller.track_x)

func _start_race_music() -> void:
    race_music = get_node_or_null("RaceMusic") as AudioStreamPlayer
    if race_music == null:
        push_warning("Level 2 RaceMusic node is missing.")
        return
    if race_music.stream == null:
        push_warning("Level 2 RaceMusic has no stream.")
        return
    race_music.bus = "Master"
    race_music.volume_db = -5.0
    var mp3 := race_music.stream as AudioStreamMP3
    if mp3 != null:
        mp3.loop = true
    race_music.play()

func _process(delta: float) -> void:
    var input: Dictionary = race_input.read()
    # Read Button state directly as a touch fallback. This keeps hold-to-drive
    # working even if a platform does not deliver button_down/button_up reliably.
    controller.handle_input(
        float(input["steer"]),
        float(input["throttle"]),
        float(input["brake"])
    )
    controller.update(delta)

func _on_mission_end() -> void:
    get_tree().change_scene_to_file("res://scenes/level3_store.tscn")
