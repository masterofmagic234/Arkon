extends Node2D

const RaceDirector = preload("res://scripts/race_director.gd")
const RaceHudPanel = preload("res://scripts/race_hud_panel_pseudo3d.gd")
const Level2Racer = preload("res://scripts/level2_racer.gd")

const HUD_TOP_FRACTION: float = 505.0 / 720.0
const BASE_VIEWPORT_SIZE := Vector2(1280.0, 720.0)

@onready var renderer: Node2D = $Renderer
@onready var hud_panel: RaceHudPanel = $HUD/HUDRoot
@onready var hud_background: Panel = $HUD/Panel
@onready var minimap: Control = $HUD/Minimap
@onready var joystick: Panel = $HUD/Joystick
@onready var joystick_knob: Panel = $HUD/Joystick/Knob
@onready var gas_button: Button = $HUD/Gas
@onready var brake_button: Button = $HUD/Brake
@onready var message_label: Label = $HUD/Message
@onready var countdown_label: Label = $HUD/Panel/Countdown

@onready var director: RaceDirector = $RaceDirector

var race_music: AudioStreamPlayer
var signal_bus: Node = null

func _force_level3_dev_mode() -> bool:
    if not bool(ProjectSettings.get_setting("run/dev_force_level3", false)):
        return false
    get_tree().change_scene_to_file("res://scenes/level3_store.tscn")
    return true

func _ready() -> void:
    if _force_level3_dev_mode():
        return

    signal_bus = get_node_or_null("/root/SignalBus")
    if signal_bus == null:
        push_error("[Level2] SignalBus autoload is unavailable.")
        return

    get_viewport().size_changed.connect(_layout_responsive_ui)
    _layout_responsive_ui()

    if not signal_bus.is_connected("level_completed", Callable(self, "_on_level_completed")):
        signal_bus.connect("level_completed", Callable(self, "_on_level_completed"))

    var racers: Array = []
    for child in $Racers.get_children():
        if child is Level2Racer:
            racers.append(child)

    if racers.is_empty():
        # Keep a defensive fallback for scene variants, but normal gameplay
        # must come from the actual Racers container.
        racers = get_tree().get_nodes_in_group("level2_racer")

    director.setup(racers)

    var player_movement := director.get_player_movement()
    if player_movement == null:
        push_error("[Level2] RaceDirector did not expose a player movement component.")
        return
    if director.track_pattern.is_empty() or director.track_x.is_empty():
        push_error("[Level2] RaceDirector produced an empty track.")
        return

    renderer.bind(
        player_movement,
        director.track_pattern,
        director.track_x
    )

    for racer in racers:
        racer.bind_renderer(renderer)

    hud_panel.bind(director.get_player_movement())
    minimap.bind(racers, director.track_pattern)

    _start_race_music()

func _exit_tree() -> void:
    if get_viewport().size_changed.is_connected(_layout_responsive_ui):
        get_viewport().size_changed.disconnect(_layout_responsive_ui)
    if signal_bus != null and signal_bus.is_connected("level_completed", Callable(self, "_on_level_completed")):
        signal_bus.disconnect("level_completed", Callable(self, "_on_level_completed"))

func _layout_responsive_ui() -> void:
    if not is_instance_valid(hud_background):
        return

    var viewport_size := get_viewport_rect().size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return

    var scale_factor: float = clampf(
        minf(
            viewport_size.x / BASE_VIEWPORT_SIZE.x,
            viewport_size.y / BASE_VIEWPORT_SIZE.y
        ),
        0.65,
        1.20
    )
    var panel_top: float = viewport_size.y * HUD_TOP_FRACTION

    hud_background.offset_left = 0.0
    hud_background.offset_top = panel_top
    hud_background.offset_right = viewport_size.x
    hud_background.offset_bottom = viewport_size.y

    var joystick_size := Vector2(150.0, 150.0) * scale_factor
    joystick.position = Vector2(
        24.0 * scale_factor,
        panel_top + 20.0 * scale_factor
    )
    joystick.size = joystick_size
    joystick_knob.size = Vector2(60.0, 60.0) * scale_factor
    joystick_knob.position = (
        joystick.size * 0.5
        - joystick_knob.size * 0.5
    )

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
    countdown_label.size = Vector2(
        260.0 * scale_factor,
        160.0 * scale_factor
    )

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

func _on_level_completed(level_id: StringName) -> void:
    if level_id != &"level2":
        return
    get_tree().call_deferred(
        "change_scene_to_file",
        "res://scenes/level3_store.tscn"
    )
