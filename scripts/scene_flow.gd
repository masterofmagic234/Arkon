extends Node
# Autoload singleton. Owns scene navigation.
#
# complete_level(level_id) — campaign router: marks completed and routes to next.
# next_level() — advances from current campaign scene.
# go_to(level_id) — low-level arbitrary navigator; never marks completion.
#
# Contract:
# SceneFlow decides WHERE we go; GameState remembers WHAT happened.
# Directors emit level_completed facts; they do not call change_scene directly.
# Every transition resumes PauseManager. Direct dev launch remains allowed.

const SCENES := {
    &"level1": "res://game.tscn",
    &"level2": "res://scenes/level2.tscn",
    &"level3": "res://scenes/level3_store.tscn",
    &"menu": "res://menu.tscn",
    &"intro": "res://intro_cutscene.tscn",
}
const CAMPAIGN := [&"level1", &"level2", &"level3", &"menu"]

var _transitioning := false
var _signal_bus: Node = null

func _ready() -> void:
    _signal_bus = get_node_or_null("/root/SignalBus")
    if _signal_bus != null and not _signal_bus.is_connected(&"level_completed", Callable(self, "_on_level_completed")):
        _signal_bus.connect(&"level_completed", Callable(self, "_on_level_completed"))
    call_deferred("_sync_current_scene")

func _exit_tree() -> void:
    if _signal_bus != null:
        var callback := Callable(self, "_on_level_completed")
        if _signal_bus.is_connected(&"level_completed", callback):
            _signal_bus.disconnect(&"level_completed", callback)

func _sync_current_scene() -> void:
    var current := get_tree().current_scene
    if current == null:
        return
    for level_id in SCENES.keys():
        if SCENES[level_id] == current.scene_file_path:
            GameState.current_level = level_id
            return

func _on_level_completed(level_id: StringName) -> void:
    complete_level(level_id)

func complete_level(level_id: StringName) -> void:
    if _transitioning:
        return
    if not CAMPAIGN.has(level_id):
        push_error("[SceneFlow] Cannot complete unknown campaign level: %s" % level_id)
        return
    GameState.mark_completed(level_id)
    var next_id := _next_after(level_id)
    if next_id == &"":
        push_warning("[SceneFlow] No next campaign level after %s; staying." % level_id)
        return
    go_to(next_id)

func next_level() -> void:
    if GameState.current_level == &"":
        go_to(CAMPAIGN[0])
        return
    var next_id := _next_after(GameState.current_level)
    if next_id != &"":
        go_to(next_id)

func restart_current() -> void:
    if GameState.current_level != &"":
        go_to(GameState.current_level)

func go_to(level_id: StringName) -> void:
    if _transitioning:
        return
    var path: String = SCENES.get(level_id, "") as String
    if path == "":
        push_error("[SceneFlow] Unknown level id: %s" % level_id)
        return
    _transitioning = true
    if has_node("/root/PauseManager"):
        PauseManager.resume()
    GameState.current_level = level_id
    var scene_tree := get_tree()
    var rearm_callback := Callable(self, "_rearm")
    if not scene_tree.is_connected(&"scene_changed", rearm_callback):
        scene_tree.scene_changed.connect(rearm_callback, CONNECT_ONE_SHOT)

    # Facts may originate in an Area3D body_entered callback. Leave the physics
    # flush before replacing a scene containing collision objects.
    call_deferred("_change_scene", path)

func _change_scene(path: String) -> void:
    var scene_tree := get_tree()
    var rearm_callback := Callable(self, "_rearm")
    var err := scene_tree.change_scene_to_file(path)
    if err != OK:
        if scene_tree.is_connected(&"scene_changed", rearm_callback):
            scene_tree.scene_changed.disconnect(rearm_callback)
        _transitioning = false
        push_error("[SceneFlow] Failed to change scene to %s (error %d)" % [path, err])
        return

func _rearm() -> void:
    _sync_current_scene()
    _transitioning = false

func _next_after(level_id: StringName) -> StringName:
    var idx := CAMPAIGN.find(level_id)
    if idx < 0 or idx >= CAMPAIGN.size() - 1:
        return &""
    return CAMPAIGN[idx + 1]
