extends Node3D

# Level 2 scene director: scene wiring only.
const RaceDirector = preload("res://scripts/race_director.gd")
const RaceHud = preload("res://scripts/race_hud.gd")

@onready var director: RaceDirector = $RaceDirector
@onready var track_view: Node3D = $Track
@onready var hud: RaceHud = $HUD/HUDRoot

func _force_level3_dev_mode() -> bool:
    if not bool(ProjectSettings.get_setting("run/dev_force_level3", false)):
        return false
    get_tree().change_scene_to_file("res://scenes/level3_store.tscn")
    return true

func _ready() -> void:
    if _force_level3_dev_mode():
        return

    if not SignalBus.level_completed.is_connected(_on_level_completed):
        SignalBus.level_completed.connect(_on_level_completed)

    var racers := get_tree().get_nodes_in_group("level2_racer")
    director.setup(racers)
    track_view.build(director.track_pattern, director.track_x)
    hud.bind(director.get_player_movement())

func _exit_tree() -> void:
    if SignalBus.level_completed.is_connected(_on_level_completed):
        SignalBus.level_completed.disconnect(_on_level_completed)

func _on_level_completed(level_id: StringName) -> void:
    if level_id != &"level2":
        return
    get_tree().call_deferred(
        "change_scene_to_file",
        "res://scenes/level3_store.tscn"
    )
