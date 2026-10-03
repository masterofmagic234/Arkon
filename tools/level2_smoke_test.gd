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

    var level2_scene := load("res://scenes/level2_pseudo3d.tscn") as PackedScene
    if level2_scene == null:
        _fail("Level 2 pseudo-3D scene failed to load")
        return

    var level2_probe := level2_scene.instantiate()
    if level2_probe == null:
        _fail("Level 2 pseudo-3D scene could not instantiate")
        return

    var renderer_node := level2_probe.get_node_or_null("Renderer") as Node2D
    var racers_node := level2_probe.get_node_or_null("Racers") as Node2D
    if renderer_node == null:
        level2_probe.queue_free()
        _fail("Level 2 pseudo-3D Renderer node is missing")
        return
    if renderer_node.get_script() == null or str(renderer_node.get_script().resource_path) != "res://scripts/race_renderer_pseudo3d.gd":
        level2_probe.queue_free()
        _fail("Level 2 Renderer node is not bound to race_renderer_pseudo3d.gd")
        return
    if racers_node == null:
        level2_probe.queue_free()
        _fail("Level 2 Racers node is missing")
        return
    if racers_node.get_script() != null and str(racers_node.get_script().resource_path) == "res://scripts/race_renderer_pseudo3d.gd":
        level2_probe.queue_free()
        _fail("Level 2 renderer script is still attached to Racers")
        return
    level2_probe.queue_free()
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
    for marker in [
        "func track_center_x",
        "func track_center_slope",
        "func track_closure_error"
    ]:
        if not race_math_script.contains(marker):
            _fail("Shared Level 2 race math API is incomplete: %s" % marker)
            return

    var racer_script := FileAccess.get_file_as_string("res://scripts/level2_racer.gd")
    for marker in [
        "class_name Level2Racer",
        "RaceAIComponent",
        "movement.tick",
        "movement.set_render_alpha"
    ]:
        if not racer_script.contains(marker):
            _fail("Level 2 racer architecture marker missing: %s" % marker)
            return

    var movement_script := FileAccess.get_file_as_string(
        "res://scripts/components/race_movement_component.gd"
    )
    for marker in [
        "class_name RaceMovementComponent",
        "Input.is_action_pressed",
        "lateral_offset",
        "RaceMath.track_center_x"
    ]:
        if not movement_script.contains(marker):
            _fail("RaceMovementComponent architecture marker missing: %s" % marker)
            return

    var director_script := FileAccess.get_file_as_string("res://scripts/race_director.gd")
    for marker in [
        "class_name RaceDirector",
        "func setup(",
        "SignalBus.racer_position_changed.emit"
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
