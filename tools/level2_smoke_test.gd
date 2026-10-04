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
        "res://scripts/level2_camera_3d.gd",
        "res://scripts/level2_mobile_input.gd"
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

    var movement_constants := FileAccess.get_file_as_string(
        "res://scripts/components/race_movement_component.gd"
    )
    if not movement_constants.contains("const ENGINE_FORCE := 42.0"):
        _fail("Level 2 engine force drifted from the Godot vehicle scale")
        return
    if not movement_constants.contains("const BRAKE_FORCE := 28.0"):
        _fail("Level 2 brake force drifted from the Godot vehicle scale")
        return

    var mobile_script := FileAccess.get_file_as_string(
        "res://scripts/level2_mobile_input.gd"
    )
    for marker in [
        "func _layout_mobile_controls()",
        "race_accel",
        "race_brake",
        "race_left",
        "race_right"
    ]:
        if not mobile_script.contains(marker):
            _fail("Level 2 mobile input marker missing: %s" % marker)
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
        "get_forward_speed",
        "nearest_track_progress"
    ]:
        if not movement_script.contains(marker):
            _fail("Physical RaceMovementComponent marker missing: %s" % marker)
            return

    if movement_script.contains("vehicle.global_position = pos"):
        _fail("Physical vehicle is still being teleported for off-road correction")
        return
    if movement_script.contains("func _recover_from_track_fall"):
        _fail("Physical vehicle still contains runtime teleport recovery")
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

    var player_scene_text := FileAccess.get_file_as_string(
        "res://scenes/level2_racer.tscn"
    )
    if not player_scene_text.contains('position = Vector3(0, 0.45, 0)'):
        root.queue_free()
        _fail("Level 2 chassis collision is still seated too high above the road")
        return
    if not player_scene_text.contains('position = Vector3(-0.73, 0.34, -1.02)'):
        root.queue_free()
        _fail("Level 2 front wheels are still mounted too high")
        return

    var player := root.get_node_or_null(
        "Racers/Player"
    ) as VehicleBody3D
    if player == null:
        root.queue_free()
        _fail("Level 2 player is not a VehicleBody3D")
        return

    var player_visual := player.get_node_or_null("Visuals") as Node3D
    if player_visual == null or not player_visual.has_method("is_model_ready"):
        root.queue_free()
        _fail("Level 2 player GLB visual is not exposing readiness")
        return
    if not bool(player_visual.call("is_model_ready")):
        root.queue_free()
        _fail("Level 2 player GLB model did not become ready")
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

    var joystick := root.get_node_or_null("HUD/Joystick") as Panel
    var joystick_knob := root.get_node_or_null("HUD/Joystick/Knob") as Panel
    var gas := root.get_node_or_null("HUD/Gas") as Button
    var brake := root.get_node_or_null("HUD/Brake") as Button
    if joystick == null or joystick_knob == null or gas == null or brake == null:
        root.queue_free()
        _fail("Level 2 mobile controls are missing from the HUD")
        return
    if joystick.get_theme_stylebox("panel") == null or joystick_knob.get_theme_stylebox("panel") == null:
        root.queue_free()
        _fail("Level 2 steering stick has no visible visual style")
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

    var player_movement := player.get_node_or_null(
        "RaceMovementComponent"
    ) as RaceMovementComponent
    if player_movement == null:
        root.queue_free()
        _fail("Level 2 player movement component is missing")
        return

    player.start_race()

    # Let the suspension settle before testing propulsion. VehicleBody3D control
    # depends on traction wheels actually touching a surface.
    for _i in range(12):
        await physics_frame

    var contact_count := 0
    for wheel_node in wheels:
        var wheel := wheel_node as VehicleWheel3D
        if wheel != null and wheel.is_in_contact():
            contact_count += 1

    if contact_count < 2:
        root.queue_free()
        _fail(
            "Level 2 wheels are not contacting the physical road: contacts=%d/4 y=%.3f"
            % [contact_count, player.global_position.y]
        )
        return

    # Verify steering input reaches the physical VehicleBody3D.
    Input.action_press("race_right", 1.0)
    await physics_frame
    var steering_response := absf(player.steering)
    Input.action_release("race_right")
    if steering_response < 0.01:
        root.queue_free()
        _fail(
            "Level 2 steering input does not reach VehicleBody3D: steering=%.4f"
            % steering_response
        )
        return

    var start_position := player.global_position
    Input.action_press("race_accel", 1.0)
    for _i in range(180):
        await physics_frame
    Input.action_release("race_accel")

    if player.global_position.y < -1.8:
        root.queue_free()
        _fail("Level 2 player fell below the playable track floor: y=%.3f" % player.global_position.y)
        return

    var delta_position := player.global_position - start_position
    var horizontal_traveled := Vector2(
        delta_position.x,
        delta_position.z
    ).length()
    var forward_speed := player_movement.get_forward_speed()
    var physical_speed := player.linear_velocity.length()
    if horizontal_traveled < 0.50 or forward_speed < 0.50 or physical_speed < 0.50:
        root.queue_free()
        _fail(
            "Level 2 player does not respond to throttle physically: "
            + "horizontal=%.3f forward=%.3f speed=%.3f"
            % [
                horizontal_traveled,
                forward_speed,
                physical_speed
            ]
        )
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
