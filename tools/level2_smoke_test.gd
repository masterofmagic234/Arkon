extends SceneTree

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")

func _init() -> void:
    call_deferred("_run")

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

    if str(ProjectSettings.get_setting(
        "application/run/main_scene",
        ""
    )) != "res://game.tscn":
        _fail("Full game boot scene is not Level 1")
        return

    if bool(ProjectSettings.get_setting(
        "run/dev_force_level3",
        false
    )):
        _fail("Development Level 3 skip is still enabled")
        return

    for path in [
        "res://game.tscn",
        "res://scenes/level2.tscn",
        "res://scenes/level2_racer.tscn",
        "res://scenes/level2_racer_3d.tscn",
        "res://scenes/level3_store.tscn",
        "res://scripts/race_director.gd",
        "res://scripts/level2_racer.gd",
        "res://scripts/components/race_movement_component.gd",
        "res://scripts/components/race_ai_component.gd",
        "res://scripts/race_math.gd",
        "res://scripts/race_level_data.gd",
        "res://scripts/race_track_view.gd",
        "res://scripts/level2_camera_3d.gd"
    ]:
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
        max_abs_track_x = maxf(
            max_abs_track_x,
            absf(float(x))
        )

    if max_abs_track_x < 24.0:
        _fail(
            "Default race track turns are too shallow: max_abs_track_x=%.2f"
            % max_abs_track_x
        )
        return

    var race_math_script := FileAccess.get_file_as_string(
        "res://scripts/race_math.gd"
    )
    for marker in [
        "func track_elevation",
        "func track_center_x",
        "func track_center_slope",
        "func track_closure_error"
    ]:
        if not race_math_script.contains(marker):
            _fail("Shared Level 2 race math API is incomplete: %s" % marker)
            return

    var movement_script := FileAccess.get_file_as_string(
        "res://scripts/components/race_movement_component.gd"
    )
    for marker in [
        "class_name RaceMovementComponent",
        "VehicleBody3D",
        "vehicle.engine_force",
        "vehicle.steering",
        "vehicle.linear_velocity",
        "get_forward_speed"
    ]:
        if not movement_script.contains(marker):
            _fail("Physical RaceMovementComponent marker missing: %s" % marker)
            return
    if movement_script.contains("lateral_offset +="):
        _fail("Physical movement still integrates fake lateral motion")
        return

    var racer_script := FileAccess.get_file_as_string(
        "res://scripts/level2_racer.gd"
    )
    for marker in [
        "extends VehicleBody3D",
        "class_name Level2Racer",
        "func _physics_process"
    ]:
        if not racer_script.contains(marker):
            _fail("Level2Racer physical architecture marker missing: %s" % marker)
            return

    var track_script := FileAccess.get_file_as_string(
        "res://scripts/race_track_view.gd"
    )
    for marker in [
        "SurfaceTool.new()",
        "MeshInstance3D",
        "create_trimesh_shape()",
        "StaticBody3D"
    ]:
        if not track_script.contains(marker):
            _fail("RaceTrackView physical mesh/collision marker missing: %s" % marker)
            return

    var camera_script := FileAccess.get_file_as_string(
        "res://scripts/level2_camera_3d.gd"
    )
    for marker in [
        "extends SpringArm3D",
        "spring_length",
        "camera.fov"
    ]:
        if not camera_script.contains(marker):
            _fail("Level 2 chase camera marker missing: %s" % marker)
            return

    var scene := load("res://scenes/level2.tscn") as PackedScene
    if scene == null:
        _fail("Level 2 honest 3D scene failed to load")
        return

    var root := scene.instantiate()
    if root == null:
        _fail("Level 2 honest 3D scene failed to instantiate")
        return

    get_root().add_child(root)
    await process_frame
    await process_frame
    await process_frame

    if not root is Node3D:
        root.queue_free()
        _fail("Level 2 root is not Node3D")
        return

    var track_view := root.get_node_or_null("Track")
    if track_view == null:
        root.queue_free()
        _fail("Level 2 Track node is missing")
        return

    var road := track_view.get_node_or_null("Road") as MeshInstance3D
    var road_shape := track_view.get_node_or_null(
        "RoadCollision/CollisionShape3D"
    ) as CollisionShape3D
    var ground_shape := track_view.get_node_or_null(
        "GroundCollision/CollisionShape3D"
    ) as CollisionShape3D

    if road == null or road.mesh == null:
        root.queue_free()
        _fail("Level 2 road ArrayMesh was not generated")
        return

    if road_shape == null or road_shape.shape == null:
        root.queue_free()
        _fail("Level 2 road trimesh collision was not generated")
        return

    if ground_shape == null or ground_shape.shape == null:
        root.queue_free()
        _fail("Level 2 ground collision was not generated")
        return

    var racers := root.get_node_or_null("Racers")
    if racers == null or racers.get_child_count() != 4:
        root.queue_free()
        _fail("Level 2 does not instantiate exactly four racers")
        return

    var player := root.get_node_or_null(
        "Racers/Player"
    ) as VehicleBody3D
    if player == null:
        root.queue_free()
        _fail("Level 2 player is not a VehicleBody3D")
        return

    var wheels := player.find_children(
        "*",
        "VehicleWheel3D",
        true,
        false
    )
    if wheels.size() != 4:
        root.queue_free()
        _fail("Level 2 player wheel count is %d, expected 4" % wheels.size())
        return

    var steering_count := 0
    var traction_count := 0
    for wheel_node in wheels:
        var wheel := wheel_node as VehicleWheel3D
        if wheel == null:
            continue
        if wheel.use_as_steering:
            steering_count += 1
        if wheel.use_as_traction:
            traction_count += 1

    if steering_count != 2:
        root.queue_free()
        _fail("Level 2 steering wheel count is %d, expected 2" % steering_count)
        return

    if traction_count != 4:
        root.queue_free()
        _fail("Level 2 traction wheel count is %d, expected 4" % traction_count)
        return

    var camera_rig := root.get_node_or_null(
        "Racers/Player/CameraRig"
    ) as SpringArm3D
    var camera := camera_rig.get_node_or_null(
        "Camera3D"
    ) as Camera3D if camera_rig != null else null

    if camera_rig == null or camera == null or not camera.current:
        root.queue_free()
        _fail("Level 2 SpringArm3D chase camera is not configured")
        return

    var hud_root := root.get_node_or_null("HUD/HUDRoot")
    if hud_root == null or hud_root.get_script() == null:
        root.queue_free()
        _fail("Level 2 shared RaceHud is missing")
        return

    var minimap := root.get_node_or_null("HUD/Minimap")
    if minimap == null or minimap.get_script() == null:
        root.queue_free()
        _fail("Level 2 shared minimap is missing")
        return

    root.queue_free()

    for legacy_path in [
        "res://scripts/race_renderer_pseudo3d.gd",
        "res://scripts/game_level2_pseudo3d.gd",
        "res://scripts/level2_racer_visual_pseudo3d.gd",
        "res://scripts/level2_oka_3d_stage.gd",
        "res://scenes/level2_pseudo3d.tscn",
        "res://scenes/level2_racer_pseudo3d.tscn"
    ]:
        if ResourceLoader.exists(legacy_path):
            _fail("Legacy pseudo-3D Level 2 resource still exists: %s" % legacy_path)
            return

    print(
        "LEVEL2 SMOKE TEST: PASS; physical_3d=true track_size=%d turn_blocks=%d max_abs_track_x=%.2f closure_error=%.6f"
        % [
            track.size(),
            turn_blocks,
            max_abs_track_x,
            closure_error
        ]
    )
    quit(0)

func _fail(message: String) -> void:
    push_error("LEVEL2 SMOKE TEST: " + message)
    quit(1)
