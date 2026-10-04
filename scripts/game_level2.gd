extends Node3D

# Level 2 scene director: gameplay state stays in RaceDirector and the racer
# components. This scene owns only the 3D world wiring and presentation.

const RaceDirector = preload("res://scripts/race_director.gd")
const RaceHud = preload("res://scripts/race_hud.gd")
const RaceTrackView = preload("res://scripts/race_track_view.gd")

@onready var director: RaceDirector = $RaceDirector
@onready var track_view: RaceTrackView = $Track
@onready var hud: RaceHud = $HUD/HUDRoot
@onready var minimap: Control = $HUD/Minimap
@onready var race_audio: RaceAudio = $RaceAudio

func _force_level3_dev_mode() -> bool:
    if not bool(ProjectSettings.get_setting("run/dev_force_level3", false)):
        return false

    get_tree().change_scene_to_file(
        "res://scenes/level3_store.tscn"
    )
    return true

func _ready() -> void:
    if _force_level3_dev_mode():
        return

    if not SignalBus.level_completed.is_connected(
        _on_level_completed
    ):
        SignalBus.level_completed.connect(_on_level_completed)

    var racers := get_tree().get_nodes_in_group(
        "level2_racer"
    )
    director.setup(racers)

    if director.track_pattern.is_empty():
        push_error("[Level2] RaceDirector produced an empty track.")
        return

    track_view.build(
        director.track_pattern,
        director.track_x
    )

    var player_movement := director.get_player_movement()
    if player_movement == null:
        push_error("[Level2] No player movement component after setup.")
        return

    hud.bind(player_movement)
    minimap.bind(
        racers,
        director.track_pattern
    )
    race_audio.bind_player(player_movement)

func _exit_tree() -> void:
    if SignalBus.level_completed.is_connected(
        _on_level_completed
    ):
        SignalBus.level_completed.disconnect(
            _on_level_completed
        )

func _on_level_completed(level_id: StringName) -> void:
    if level_id != &"level2":
        return

    get_tree().call_deferred(
        "change_scene_to_file",
        "res://scenes/level3_store.tscn"
    )
