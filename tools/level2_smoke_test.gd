extends SceneTree

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")

func _init() -> void:
    _run()

func _run() -> void:
    var required_actions := [
        "race_left",
        "race_right",
        "race_accel",
        "race_brake"
    ]
    for action in required_actions:
        if not InputMap.has_action(action):
            _fail("Missing Level 2 InputMap action: %s" % action)
            return

    if str(ProjectSettings.get_setting("application/run/main_scene", "")) != "res://game.tscn":
        _fail("Full game boot scene is not Level 1")
        return

    if bool(ProjectSettings.get_setting("run/dev_force_level3", false)):
        _fail("Development Level 3 skip is still enabled")
        return

    var required_resources := [
        "res://game.tscn",
        "res://scenes/level2_pseudo3d.tscn",
        "res://scenes/level2_racer.tscn",
        "res://scenes/level3_store.tscn",
        "res://scripts/race_director.gd",
        "res://scripts/level2_racer.gd",
        "res://scripts/race_math.gd",
        "res://scripts/race_level_data.gd"
    ]
    for path in required_resources:
        if not ResourceLoader.exists(path):
            _fail("Required Level 2 resource missing: %s" % path)
            return

    var track := RaceLevelData.get_track_pattern()
    if track.is_empty():
        _fail("TRACK_PATTERN is empty")
        return

    var closure_error: float = RaceMath.track_closure_error(track)
    if absf(closure_error) > 0.001:
        _fail("Default race track lateral closure error: %.3f" % closure_error)
        return

    var race_math_script := FileAccess.get_file_as_string("res://scripts/race_math.gd")
    if not race_math_script.contains("func catmull_rom") or not race_math_script.contains("func track_closure_error"):
        _fail("Shared Level 2 race math API is incomplete")
        return

    var racer_script := FileAccess.get_file_as_string("res://scripts/level2_racer.gd")
    for marker in [
        "class_name Level2Racer",
        "Input.is_action_pressed",
        "RaceAIComponent",
        "lateral_offset"
    ]:
        if not racer_script.contains(marker):
            _fail("Level 2 racer architecture marker missing: %s" % marker)
            return

    var director_script := FileAccess.get_file_as_string("res://scripts/race_director.gd")
    for marker in [
        "class_name RaceDirector",
        "racer_position_changed",
        "RACER_COUNT"
    ]:
        if not director_script.contains(marker):
            _fail("RaceDirector architecture marker missing: %s" % marker)
            return

    for legacy_path in [
        "res://scripts/race_controller.gd",
        "res://scripts/race_car_controller.gd",
        "res://scripts/race_ai_controller.gd",
        "res://scripts/race_input.gd",
        "res://scripts/race_state.gd"
    ]:
        if ResourceLoader.exists(legacy_path):
            _fail("Legacy Level 2 controller still exists: %s" % legacy_path)
            return

    print(
        "LEVEL2 SMOKE TEST: PASS; track_size=%d closure_error=%.6f"
        % [track.size(), closure_error]
    )
    quit(0)

func _fail(message: String) -> void:
    push_error("LEVEL2 SMOKE TEST: " + message)
    quit(1)
