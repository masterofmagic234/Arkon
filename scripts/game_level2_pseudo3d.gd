extends Node2D

const RaceState = preload("res://scripts/race_state.gd")
const RaceController = preload("res://scripts/race_controller.gd")
const RaceInput = preload("res://scripts/race_input.gd")

@onready var renderer: Node2D = $World/Renderer
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

func _ready() -> void:
    state = RaceState.new()
    race_input = RaceInput.new()
    race_input.setup(joystick, joystick_knob, gas_button, brake_button)
    controller = RaceController.new()
    controller.setup(self, null, [], null, null, null, null, null, state, Callable(self, "_on_mission_end"))
    controller.start()
    renderer.bind(state, controller.player, controller.ais, controller.track_pattern, controller.track_x)
    hud_panel.bind(state, controller.player)
    minimap.bind(state, controller.player, controller.ais, controller.track_pattern, controller.track_x)

func _process(delta: float) -> void:
    var input: Dictionary = race_input.read()
    # Read Button state directly as a touch fallback. This keeps hold-to-drive
    # working even if a platform does not deliver button_down/button_up reliably.
    var throttle := float(input["throttle"])
    var brake := float(input["brake"])
    if gas_button != null and gas_button.is_pressed():
        throttle = 1.0
    if brake_button != null and brake_button.is_pressed():
        brake = 1.0
    controller.handle_input(float(input["steer"]), throttle, brake)
    controller.update(delta)

func _on_mission_end() -> void:
    pass
