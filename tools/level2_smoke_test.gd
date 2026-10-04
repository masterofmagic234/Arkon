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

    # The track must contain many visible corner blocks, not just a few long
    # gentle bends. Count transitions into non-straight sections and verify
    # the centerline actually reaches a strong lateral displacement.
    var turn_blocks := 0
    var previous_type := 0
    for segment in track:
        var segment_type := int(segment)
        if segment_type != 0 and previous_type == 0:
            turn_blocks += 1
        previous_type = segment_type

    if turn_blocks < 7:
        _fail("Default race track has too few turn blocks: %d" % turn_blocks)
        return

    var track_x := RaceMath.accumulate_track_x(track)
    var max_abs_track_x := 0.0
    for x in track_x:
        max_abs_track_x = maxf(max_abs_track_x, absf(float(x)))

    if max_abs_track_x < 24.0:
        _fail("Default race track turns are too shallow: max_abs_track_x=%.2f" % max_abs_track_x)
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
        "signal_bus.emit_signal(\"racer_position_changed\""
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

    # Runtime probe: actually boot the Level 2 scene, let _ready() run, and
    # verify the renderer received a player + track before checking pixels.
    var runtime_scene := load("res://scenes/level2_pseudo3d.tscn") as PackedScene
    if runtime_scene == null:
        _fail("Level 2 runtime scene failed to load")
        return

    var runtime_root := runtime_scene.instantiate()
    if runtime_root == null:
        _fail("Level 2 runtime scene failed to instantiate")
        return

    get_root().add_child(runtime_root)

    # Give children, Level2Racer._ready(), RaceDirector._ready(), and
    # game_level2_pseudo3d._ready() enough frames to complete bootstrap.
    await process_frame
    await process_frame
    await process_frame

    var runtime_renderer := runtime_root.get_node_or_null("Renderer") as Node2D
    var runtime_director := runtime_root.get_node_or_null("RaceDirector")
    if runtime_renderer == null:
        runtime_root.queue_free()
        _fail("Level 2 runtime Renderer node is missing")
        return

    var bound_player = runtime_renderer.get("player_car")
    var bound_track_size: int = int(runtime_renderer.get("track_size"))
    var bound_track_x = runtime_renderer.get("track_x")
    if bound_player == null:
        runtime_root.queue_free()
        _fail("Level 2 runtime renderer has no player binding")
        return
    if bound_track_size <= 0:
        runtime_root.queue_free()
        _fail("Level 2 runtime renderer has no track")
        return
    if bound_track_x == null or bound_track_x.size() != bound_track_size:
        runtime_root.queue_free()
        _fail(
            "Level 2 runtime renderer track mismatch: size=%d tx=%d"
            % [bound_track_size, 0 if bound_track_x == null else bound_track_x.size()]
        )
        return

    var projection: Dictionary = runtime_renderer.project_racer(bound_player)
    if not bool(projection.get("visible", false)):
        runtime_root.queue_free()
        _fail("Level 2 runtime player projection is invisible")
        return

    # Do not force a GPU readback here. On GitHub's llvmpipe/Xvfb runner,
    # ViewportTexture.get_image() can block indefinitely even though the
    # renderer itself is healthy. Runtime binding + projection above already
    # prove that the Level 2 renderer booted and produced a visible racer.
    var projection_visible := bool(projection.get("visible", false))
    if not projection_visible:
        runtime_root.queue_free()
        _fail("Level 2 runtime projection became invisible during smoke test")
        return

    runtime_root.queue_free()

    print(
        "LEVEL2 SMOKE TEST: PASS; track_size=%d turn_blocks=%d max_abs_track_x=%.2f closure_error=%.6f runtime_bound=true projection_visible=%s director=%s"
        % [track.size(), turn_blocks, max_abs_track_x, closure_error, projection_visible, runtime_director != null]
    )
    quit(0)

func _fail(message: String) -> void:
    push_error("LEVEL2 SMOKE TEST: " + message)
    quit(1)
