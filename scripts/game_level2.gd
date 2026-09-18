extends Node3D

# Рут сцены Level 2.

const RaceState = preload("res://scripts/race_state.gd")
const RaceController = preload("res://scripts/race_controller.gd")
const RaceInput = preload("res://scripts/race_input.gd")

class RaceMessageView:
    var node: Label
    func _init(n: Label) -> void:
        node = n
    func set_text(t: String) -> void:
        if node:
            node.text = t

class RaceMissionView:
    var panel: Panel
    var title: Label
    var body: Label
    func _init(p: Panel, t: Label, b: Label) -> void:
        panel = p
        title = t
        body = b
    func show_finished(state) -> void:
        if panel:
            panel.visible = true
        if title:
            title.text = "ФИНИШ!"
        if body:
            body.text = "ЛУЧШИЙ КРУГ: %s" % state.best_lap
    func show_failed() -> void:
        if panel:
            panel.visible = true
        if title:
            title.text = "ПРОВАЛ"
        if body:
            body.text = "Белки ликуют."

@onready var player_visual: Node3D = $Player
@onready var ai1: Node3D = $AI1
@onready var ai2: Node3D = $AI2
@onready var ai3: Node3D = $AI3
@onready var camera: Camera3D = $Camera3D
@onready var track_view: Node3D = $Track
@onready var hud: Node = $HUD/HUDRoot
@onready var joystick: Panel = $HUD/Joystick
@onready var joystick_knob: Panel = $HUD/Joystick/Knob
@onready var gas_button: Button = $HUD/Gas
@onready var brake_button: Button = $HUD/Brake
@onready var message_label: Label = $HUD/Message
@onready var mission_panel: Panel = $HUD/Mission
@onready var mission_title: Label = $HUD/Mission/Title
@onready var mission_body: Label = $HUD/Mission/Body

var state
var controller
var message_view
var mission_view
var race_input

func _ready() -> void:
    state = RaceState.new()
    message_view = RaceMessageView.new(message_label)
    mission_view = RaceMissionView.new(mission_panel, mission_title, mission_body)
    race_input = RaceInput.new()
    race_input.setup(joystick, joystick_knob, gas_button, brake_button)
    controller = RaceController.new()
    controller.setup(self, player_visual, [ai1, ai2, ai3], camera, hud, null, message_view, mission_view, state, Callable(self, "_on_mission_end"))
    controller.start()
    track_view.build(controller.track_pattern, controller.track_x)

func _process(delta: float) -> void:
    var input: Dictionary = race_input.read()
    controller.handle_input(float(input["steer"]), float(input["throttle"]), float(input["brake"]))
    controller.update(delta)

func _on_mission_end() -> void:
    pass
