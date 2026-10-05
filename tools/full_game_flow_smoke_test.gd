extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var expected_main := "res://game.tscn"
    var expected_l2 := "res://scenes/level2.tscn"
    var expected_l3 := "res://scenes/level3_store.tscn"
    var expected_menu := "res://menu.tscn"

    if str(ProjectSettings.get_setting("application/run/main_scene", "")) != expected_main:
        _fail("main_scene is not Level 1: %s" % ProjectSettings.get_setting("application/run/main_scene", ""))
        return

    if bool(ProjectSettings.get_setting("run/dev_force_level3", false)):
        _fail("dev_force_level3 is enabled")
        return

    for path in [
        expected_main,
        expected_l2,
        expected_l3,
        expected_menu
    ]:
        if not ResourceLoader.exists(path):
            _fail("Required flow resource missing: %s" % path)
            return

    var l1_script := FileAccess.get_file_as_string("res://scripts/game.gd")
    if not l1_script.contains('const LEVEL_2_SCENE_PATH := "res://scenes/level2.tscn"'):
        _fail("L1 does not declare the Level 2 transition")
        return

    if not l1_script.contains('get_tree().call_deferred("change_scene_to_file", LEVEL_2_SCENE_PATH)'):
        _fail("L1 completion does not transition to Level 2")
        return

    var l2_script := FileAccess.get_file_as_string("res://scripts/game_level2.gd")
    for marker in [
        'extends Node3D',
        'director.setup(racers)',
        'track_view.build(',
        'hud.bind(',
        'minimap.bind(',
        'race_audio.bind_player(',
        'res://scenes/level3_store.tscn'
    ]:
        if not l2_script.contains(marker):
            _fail("Honest 3D Level 2 scene-director contract missing: %s" % marker)
            return

    var racer_script := FileAccess.get_file_as_string(
        "res://scripts/level2_racer.gd"
    )
    for marker in [
        'extends VehicleBody3D',
        'class_name Level2Racer',
        'movement.tick',
        'VehicleBody3D'
    ]:
        if not racer_script.contains(marker):
            _fail("Level 2 physical racer architecture marker missing: %s" % marker)
            return

    var movement_script := FileAccess.get_file_as_string(
        "res://scripts/components/race_movement_component.gd"
    )
    for marker in [
        'class_name RaceMovementComponent',
        'vehicle.linear_velocity',
        'get_physical_vehicle',
        'get_track_position_at_distance',
        'get_track_tangent_at_distance',
        'get_forward_speed',
        '_nearest_track_distance',
        'vehicle.global_position',
        'vehicle.global_rotation',
        'lateral_offset +='
    ]:
        if not movement_script.contains(marker):
            _fail("Level 2 physical movement marker missing: %s" % marker)
            return

    var ai_script := FileAccess.get_file_as_string(
        "res://scripts/components/race_ai_component.gd"
    )
    for marker in [
        'get_physical_vehicle',
        'get_ai_target_point',
        'signed_angle',
        'movement.set_inputs('
    ]:
        if not ai_script.contains(marker):
            _fail("Level 2 physical AI steering marker missing: %s" % marker)
            return

    var track_script := FileAccess.get_file_as_string(
        "res://scripts/race_track_view.gd"
    )
    for marker in [
        'MeshInstance3D',
        'StaticBody3D',
        'BoxShape3D',
        'RoadCollision',
        'GroundCollision'
    ]:
        if not track_script.contains(marker):
            _fail("Level 2 physical track marker missing: %s" % marker)
            return

    var visual_script := FileAccess.get_file_as_string(
        "res://scripts/level2_racer_visual_3d.gd"
    )
    for marker in [
        '240_sx_nfs_pro_street.glb',
        'CAR_MODEL_PATH',
        'MODEL_AUTHORED_FORWARD_YAW',
        'DESIRED_LENGTH',
        'is_model_ready'
    ]:
        if not visual_script.contains(marker):
            _fail("Level 2 GLB visual marker missing: %s" % marker)
            return

    var camera_script := FileAccess.get_file_as_string(
        "res://scripts/level2_camera_3d.gd"
    )
    for marker in [
        'extends SpringArm3D',
        'class_name Level2Camera3D',
        'spring_length',
        'camera.fov'
    ]:
        if not camera_script.contains(marker):
            _fail("Level 2 chase-camera marker missing: %s" % marker)
            return

    var math_script := FileAccess.get_file_as_string(
        "res://scripts/race_math.gd"
    )
    if not math_script.contains("func track_elevation("):
        _fail("Level 2 physical track elevation API is missing")
        return

    if ResourceLoader.exists("res://scripts/game_level2_pseudo3d.gd"):
        _fail("Legacy pseudo-3D Level 2 director still exists")
        return
    if ResourceLoader.exists("res://scripts/race_renderer_pseudo3d.gd"):
        _fail("Legacy pseudo-3D race renderer still exists")
        return
    if ResourceLoader.exists("res://scenes/level2_pseudo3d.tscn"):
        _fail("Legacy pseudo-3D Level 2 scene still exists")
        return
    if ResourceLoader.exists("res://scenes/level2_racer_pseudo3d.tscn"):
        _fail("Legacy pseudo-3D racer scene still exists")
        return
    var l3_script := FileAccess.get_file_as_string("res://scripts/level3_store.gd")
    if not l3_script.contains("change_scene_to_file") or not l3_script.contains("res://menu.tscn"):
        _fail("Level 3 completion does not return to menu")
        return

    if l3_script.contains("dialogue.start_dialogue("):
        _fail("Level 3 still contains an automatic cinematic/dialogue gate")
        return

    if l3_script.contains("var _clear_timer"):
        _fail("Level 3 still contains obsolete cinematic timer state")
        return

    # Combat/presentation regression checks: squirrels need a generous
    # playable hit volume, and the Android Level 3 movement stick must never
    # become an implicit fire trigger through touch-to-mouse emulation.
    var enemy_scene := load("res://scenes/level1_enemy.tscn") as PackedScene
    if enemy_scene == null:
        _fail("Level 1 enemy scene failed to load")
        return
    var enemy_probe := enemy_scene.instantiate()
    if enemy_probe == null:
        _fail("Level 1 enemy scene failed to instantiate")
        return

    var hit_shape := enemy_probe.get_node_or_null("Hitbox/CollisionShape3D") as CollisionShape3D
    var hit_box := hit_shape.shape as BoxShape3D if hit_shape != null else null
    var visual_node := enemy_probe.get_node_or_null("Visual") as MeshInstance3D
    var visual_quad := visual_node.mesh as QuadMesh if visual_node != null else null
    if hit_box == null or hit_box.size.x < 2.0 or hit_box.size.y < 2.4 or hit_box.size.z < 1.7:
        enemy_probe.queue_free()
        _fail("Level 1 squirrel hitbox is still too narrow")
        return
    if visual_quad == null or visual_quad.size.x < 2.79 or visual_quad.size.y < 2.79:
        enemy_probe.queue_free()
        _fail("Level 1 billboard squirrel is still too small")
        return
    enemy_probe.queue_free()

    var squirrel_visual_script := FileAccess.get_file_as_string(
        "res://scripts/squirrel_3d_visual.gd"
    )
    if not squirrel_visual_script.contains("TARGET_HEIGHT: float = 2.15"):
        _fail("Level 1 rigged squirrel scale regression detected")
        return

    if not l3_script.contains("if not OS.has_feature(\"mobile\")") or not l3_script.contains("Mobile firing must come only from the explicit FIRE button"):
        _fail("Level 3 still polls l3_fire globally on mobile")
        return

    var mobile_input_script := FileAccess.get_file_as_string(
        "res://scripts/level1_mobile_input.gd"
    )
    if not mobile_input_script.contains("func _layout_responsive_ui()"):
        _fail("Level 1 HUD is missing responsive viewport layout")
        return
    if mobile_input_script.contains('Input.action_press("l1_fire"'):
        _fail("Level 1 mobile FIRE still synthesizes the l1_fire action")
        return

    var player_script := FileAccess.get_file_as_string(
        "res://scripts/level1_player.gd"
    )
    if player_script.contains('Input.is_action_just_pressed("l1_fire")'):
        _fail("Level 1 player still polls l1_fire on mobile")
        return

    # Runtime Level 1 height regression test. The navigation mesh is authored
    # on Y=0, while squirrels spawn at their authored gameplay height. Boot
    # the real scene and make sure several physics frames cannot pull them down.
    var l1_scene := load(expected_main) as PackedScene
    if l1_scene == null:
        _fail("Level 1 runtime scene failed to load")
        return

    var l1_root := l1_scene.instantiate()
    if l1_root == null:
        _fail("Level 1 runtime scene failed to instantiate")
        return

    get_root().add_child(l1_root)
    await process_frame
    await process_frame
    await process_frame

    var l2_scene := load(expected_l2) as PackedScene
    if l2_scene == null:
        l1_root.queue_free()
        _fail("Level 2 honest 3D scene failed to load")
        return

    l1_root.process_mode = Node.PROCESS_MODE_DISABLED

    var l2_root := l2_scene.instantiate()
    if l2_root == null:
        l1_root.queue_free()
        _fail("Level 2 honest 3D scene failed to instantiate")
        return

    get_root().add_child(l2_root)
    await process_frame
    await process_frame
    await process_frame

    var track_view := l2_root.get_node_or_null("Track")
    if not (track_view is Node3D):
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 Track node is not Node3D")
        return

    var authored_track := track_view.get_node_or_null(
        "AuthoredTrack"
    ) as Node3D
    if (
        authored_track == null
        or authored_track.find_children(
            "*",
            "MeshInstance3D",
            true,
            false
        ).is_empty()
    ):
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 authored London road mesh was not instantiated")
        return

    var road_collision := track_view.get_node_or_null(
        "RoadCollision"
    ) as StaticBody3D
    if road_collision == null or road_collision.get_child_count() < 60:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail(
            "Level 2 authored London road collision is incomplete: %d shapes"
            % (road_collision.get_child_count() if road_collision != null else 0)
        )
        return

    var ground_collision := track_view.get_node_or_null(
        "GroundCollision/CollisionShape3D"
    ) as CollisionShape3D
    if ground_collision == null or ground_collision.shape == null:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 ground collision was not generated")
        return

    var player_vehicle := l2_root.get_node_or_null(
        "Racers/Player"
    ) as VehicleBody3D
    if player_vehicle == null:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 player is not a VehicleBody3D")
        return

    var wheels := player_vehicle.find_children(
        "*",
        "VehicleWheel3D",
        true,
        false
    )
    if wheels.size() != 4:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 player does not have exactly four VehicleWheel3D nodes")
        return

    var steering_wheels := 0
    var traction_wheels := 0
    for wheel_node in wheels:
        var wheel := wheel_node as VehicleWheel3D
        if wheel == null:
            continue
        if wheel.use_as_steering:
            steering_wheels += 1
        if wheel.use_as_traction:
            traction_wheels += 1

    if steering_wheels != 2 or traction_wheels != 4:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail(
            "Level 2 wheel configuration invalid: steering=%d traction=%d"
            % [steering_wheels, traction_wheels]
        )
        return

    var visual := player_vehicle.get_node_or_null(
        "Visuals"
    ) as Node3D
    if visual == null:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 player 3D visuals are missing")
        return
    if not visual.has_method("is_model_ready"):
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 player GLB visual readiness API is missing")
        return
    if not bool(visual.call("is_model_ready")):
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 player GLB model did not become ready")
        return

    var grass_regression_script := FileAccess.get_file_as_string(
        "res://scripts/level1_grass_generator.gd"
    )
    if (
        not grass_regression_script.contains("const GRASS_HEIGHT := 0.55")
        or not grass_regression_script.contains("const GRASS_HALF_WIDTH := 0.25")
    ):
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 1 Carolina grass geometry scale regressed")
        return

    var model_pivot := visual.get_node_or_null("ModelPivot") as Node3D
    if model_pivot == null:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 240SX model pivot is missing")
        return

    var model_yaw_error := absf(float(model_pivot.rotation.y))
    if model_yaw_error > 0.05:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 240SX model is not aligned with the authored front direction")
        return

    var camera_rig := l2_root.get_node_or_null(
        "Racers/Player/CameraRig"
    ) as SpringArm3D
    var race_camera := camera_rig.get_node_or_null(
        "Camera3D"
    ) as Camera3D if camera_rig != null else null
    if camera_rig == null or race_camera == null:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 player chase camera rig is missing")
        return

    if not race_camera.current:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 chase camera is not current")
        return

    var vehicle_forward := -player_vehicle.global_transform.basis.z
    vehicle_forward.y = 0.0
    if vehicle_forward.length_squared() > 0.0001:
        vehicle_forward = vehicle_forward.normalized()
        var camera_to_vehicle := race_camera.global_position - player_vehicle.global_position
        camera_to_vehicle.y = 0.0
        if camera_to_vehicle.length_squared() > 0.0001:
            camera_to_vehicle = camera_to_vehicle.normalized()
            if camera_to_vehicle.dot(vehicle_forward) > -0.20:
                l2_root.queue_free()
                l1_root.queue_free()
                _fail("Level 2 chase camera is on the wrong side of the car")
                return

        var camera_forward := -race_camera.global_transform.basis.z
        camera_forward.y = 0.0
        if camera_forward.length_squared() > 0.0001:
            camera_forward = camera_forward.normalized()
            if camera_forward.dot(vehicle_forward) < 0.90:
                l2_root.queue_free()
                l1_root.queue_free()
                _fail("Level 2 chase camera is looking away from race direction")
                return

    var hud_root := l2_root.get_node_or_null("HUD/HUDRoot")
    if hud_root == null or hud_root.get_script() == null:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 HUD root is missing")
        return
    if str(hud_root.get_script().resource_path) != "res://scripts/race_hud.gd":
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 HUD is not using the shared RaceHud")
        return

    var minimap := l2_root.get_node_or_null("HUD/Minimap")
    if minimap == null or minimap.get_script() == null:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 minimap is missing")
        return
    if str(minimap.get_script().resource_path) != "res://scripts/race_minimap_nes.gd":
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 minimap is not using the shared race minimap")
        return

    l2_root.queue_free()

    # Level 1 was paused while the honest 3D Level 2 scene was being inspected.
    # Restore its processing before runtime combat/height checks so queued
    # player actions are consumed by the real _physics_process tick.
    l1_root.process_mode = Node.PROCESS_MODE_INHERIT
    await physics_frame

    var floor_paths := [
        "res://floor_zone_1(1).jpg",
        "res://floor_zone_2(1).jpg",
        "res://floor_zone_3(1).jpg",
        "res://floor_zone_4(1).jpg",
    ]
    for floor_path in floor_paths:
        if not ResourceLoader.exists(floor_path):
            l1_root.queue_free()
            _fail("Missing Level 1 zone floor texture: %s" % floor_path)
            return

    var environment_node := l1_root.get_node_or_null("Level1Environment")
    var layout_node := l1_root.get_node_or_null("Level1Layout")
    var zone_root := layout_node.get_node_or_null("Floor/ZoneGrounds") if layout_node != null else null
    if environment_node == null or zone_root == null:
        l1_root.queue_free()
        _fail("Level 1 did not build its four floor zones")
        return

    var floor_zones := zone_root.get_children()
    if floor_zones.size() != 4:
        l1_root.queue_free()
        _fail("Level 1 floor zone count is %d, expected 4" % floor_zones.size())
        return

    for zone_index in range(4):
        var zone := floor_zones[zone_index] as MeshInstance3D
        if zone == null or zone.mesh == null:
            l1_root.queue_free()
            _fail("Level 1 floor zone %d has no mesh" % (zone_index + 1))
            return
        var zone_mesh := zone.mesh as PlaneMesh
        var zone_material := zone_mesh.material as StandardMaterial3D if zone_mesh != null else null
        var texture := zone_material.albedo_texture if zone_material != null else null
        if zone_material == null or texture == null:
            l1_root.queue_free()
            _fail("Level 1 floor zone %d has no material texture" % (zone_index + 1))
            return
        if str(texture.resource_path) != floor_paths[zone_index]:
            l1_root.queue_free()
            _fail(
                "Level 1 floor zone %d uses %s instead of %s"
                % [zone_index + 1, texture.resource_path, floor_paths[zone_index]]
            )
            return
        if zone_material.uv1_scale != Vector3(0.22, 0.22, 0.22):
            l1_root.queue_free()
            _fail("Level 1 floor zone %d UV1 scale regression: %s" % [zone_index + 1, zone_material.uv1_scale])
            return
        if not zone_material.emission_enabled or zone_material.emission_texture == null:
            l1_root.queue_free()
            _fail("Level 1 floor zone %d is missing emissive texture setup" % (zone_index + 1))
            return

    var grass_script := FileAccess.get_file_as_string(
        "res://scripts/level1_grass_generator.gd"
    )
    for grass_marker in [
        "MultiMeshInstance3D",
        "density_per_cell",
        "LevelData.CANONICAL_MAP",
        "grass_tuft_carolina.svg"
    ]:
        if not grass_script.contains(grass_marker):
            l1_root.queue_free()
            _fail("Level 1 3D grass component marker missing: %s" % grass_marker)
            return
    if grass_script.contains('cell_char == "." or cell_char == "#"'):
        l1_root.queue_free()
        _fail("Level 1 grass generator still places grass on wall cells")
        return

    var grass_shader_source := FileAccess.get_file_as_string(
        "res://shaders/level1_grass.gdshader"
    )
    for grass_shader_marker in [
        "ALPHA_SCISSOR_THRESHOLD",
        "cull_disabled",
        "depth_draw_opaque"
    ]:
        if not grass_shader_source.contains(grass_shader_marker):
            l1_root.queue_free()
            _fail("Level 1 grass shader optimization marker missing: %s" % grass_shader_marker)
            return

    var grass_generator := l1_root.get_node_or_null(
        "Level1Environment/Level1GrassGenerator"
    )
    if grass_generator == null:
        l1_root.queue_free()
        _fail("Level 1 3D grass generator was not spawned")
        return
    var grass_field_count := int(grass_generator.call("get_field_count"))
    var grass_instance_count := int(grass_generator.call("get_instance_count"))
    if grass_field_count < 5 or grass_field_count > 8:
        l1_root.queue_free()
        _fail("Level 1 grass chunk count is unsafe: %d" % grass_field_count)
        return
    if grass_instance_count < 3000 or grass_instance_count > 4200:
        l1_root.queue_free()
        _fail("Level 1 grass instance budget is unsafe: %d" % grass_instance_count)
        return

    var wall_root := layout_node.get_node_or_null("Walls")
    if wall_root == null:
        l1_root.queue_free()
        _fail("Level 1 wall root is missing")
        return

    var wall_zones_seen := [false, false, false, false]
    for wall_node in wall_root.get_children():
        if not wall_node is StaticBody3D or not wall_node.name.begins_with("MapWall_"):
            continue
        var wall_mesh := wall_node.get_node_or_null("Mesh") as MeshInstance3D
        var wall_material := wall_mesh.material_override as ShaderMaterial if wall_mesh != null else null
        if wall_material == null or wall_material.shader == null:
            l1_root.queue_free()
            _fail("A Level 1 wall has no night shader material")
            return
        if str(wall_material.shader.resource_path) != "res://shaders/level1_wall_night.gdshader":
            l1_root.queue_free()
            _fail("A Level 1 wall is missing the contact-AO night shader")
            return
        var wall_zone := int(environment_node.call("_zone_index_for_world_x", wall_node.position.x))
        wall_zones_seen[wall_zone] = true

    for zone_index in range(4):
        if not wall_zones_seen[zone_index]:
            l1_root.queue_free()
            _fail("No Level 1 wall segment was assigned to zone %d" % (zone_index + 1))
            return

    var camera := l1_root.get_node_or_null("Player/Camera3D") as Camera3D
    var world_environment := l1_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if camera == null or world_environment == null or world_environment.environment == null:
        l1_root.queue_free()
        _fail("Level 1 camera/environment missing")
        return
    if camera.far < 44.9:
        l1_root.queue_free()
        _fail("Level 1 Camera3D far clip is still too short: %.2f" % camera.far)
        return
    if not world_environment.environment.fog_enabled:
        l1_root.queue_free()
        _fail("Level 1 depth fog is disabled")
        return
    var fog := world_environment.environment
    if fog.fog_mode != Environment.FOG_MODE_DEPTH:
        l1_root.queue_free()
        _fail("Level 1 atmosphere is not using depth fog")
        return
    if fog.fog_depth_begin > 10.1 or fog.fog_depth_end < 31.9 or fog.fog_depth_end >= camera.far:
        l1_root.queue_free()
        _fail("Level 1 fog range is unsafe: begin=%.2f end=%.2f far=%.2f" % [fog.fog_depth_begin, fog.fog_depth_end, camera.far])
        return
    if fog.fog_light_color != Color(0.12, 0.17, 0.25, 1):
        l1_root.queue_free()
        _fail("Level 1 fog color no longer matches horizon sky color")
        return
    if not world_environment.environment.glow_enabled or world_environment.environment.glow_bloom <= 0.0:
        l1_root.queue_free()
        _fail("Level 1 compatibility glow/bloom is disabled")
        return
    if world_environment.environment.glow_hdr_threshold > 0.60:
        l1_root.queue_free()
        _fail("Level 1 glow threshold is too high for Compatibility renderer")
        return

    var hud_controller: Node = l1_root.get_node_or_null("HUD")
    if hud_controller == null:
        l1_root.queue_free()
        _fail("Level 1 HUD controller is missing")
        return
    var viewport_size: Vector2 = get_root().get_viewport().get_visible_rect().size
    var hud_joystick := l1_root.get_node_or_null("HUD/Joystick") as Control
    var hud_fire := l1_root.get_node_or_null("HUD/Fire") as Control
    var hud_mute := l1_root.get_node_or_null("HUD/Mute") as Control
    if hud_joystick == null or hud_fire == null or hud_mute == null:
        l1_root.queue_free()
        _fail("Level 1 HUD mobile controls are missing")
        return
    if hud_joystick.position.x < -0.1 or hud_joystick.position.y + hud_joystick.size.y > viewport_size.y + 0.1:
        l1_root.queue_free()
        _fail("Level 1 joystick is not anchored to bottom-left of viewport")
        return
    if hud_fire.position.x + hud_fire.size.x > viewport_size.x + 0.1 or hud_fire.position.y + hud_fire.size.y > viewport_size.y + 0.1:
        l1_root.queue_free()
        _fail("Level 1 FIRE button is not anchored to bottom-right of viewport")
        return
    if hud_mute.position.x + hud_mute.size.x > viewport_size.x + 0.1:
        l1_root.queue_free()
        _fail("Level 1 mute button is not anchored to top-right of viewport")
        return

    var minimap_frame := l1_root.get_node_or_null("HUD/Minimap/Frame") as Panel
    if minimap_frame == null or minimap_frame.get_theme_stylebox("panel") == null:
        l1_root.queue_free()
        _fail("Level 1 minimap is missing its backdrop panel")
        return
    var minimap_style := minimap_frame.get_theme_stylebox("panel") as StyleBoxFlat
    if minimap_style == null or minimap_style.bg_color.a > 0.56:
        l1_root.queue_free()
        _fail("Level 1 minimap backdrop is not a semi-transparent dark panel")
        return

    var tree_test_material_found := false
    for tree_candidate in layout_node.find_children("*", "MeshInstance3D", true, false):
        var tree_mesh := tree_candidate as MeshInstance3D
        if tree_mesh == null or tree_mesh.mesh == null:
            continue
        for surface in range(tree_mesh.mesh.get_surface_count()):
            var active_mat := tree_mesh.get_active_material(surface) as StandardMaterial3D
            if active_mat == null or active_mat.albedo_texture == null:
                continue
            if active_mat.albedo_texture.resource_path == "res://assets/oak_tree.png":
                tree_test_material_found = true
                if active_mat.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
                    l1_root.queue_free()
                    _fail("Oak tree material is not using alpha scissor")
                    return
                if active_mat.alpha_scissor_threshold < 0.4 or active_mat.alpha_scissor_threshold > 0.55:
                    l1_root.queue_free()
                    _fail("Oak tree alpha scissor threshold is unsafe: %.3f" % active_mat.alpha_scissor_threshold)
                    return
    if not tree_test_material_found:
        l1_root.queue_free()
        _fail("Oak tree material was not found for alpha-edge regression check")
        return

    var ground_source := layout_node.get_node_or_null("Floor/Ground") as MeshInstance3D
    if ground_source == null or ground_source.visible:
        l1_root.queue_free()
        _fail("Original full-map Level 1 ground was not hidden after zone split")
        return

    var enemies := l1_root.get_tree().get_nodes_in_group("level1_enemy")
    if enemies.is_empty():
        l1_root.queue_free()
        _fail("Level 1 runtime produced no squirrels")
        return

    # Runtime combat regression: fire the real Level 1 weapon at Squirrel01
    # from a controlled position and verify two hits can actually kill it.
    var combat_player: Node = l1_root.get_node_or_null("Player")
    var combat_target: Node = l1_root.get_node_or_null("Squirrel01")
    if combat_player == null or combat_target == null:
        l1_root.queue_free()
        _fail("Level 1 runtime combat probe could not find Player/Squirrel01")
        return

    var target_health: Node = combat_target.get_node_or_null("Health")
    if target_health == null:
        l1_root.queue_free()
        _fail("Squirrel01 has no HealthComponent")
        return

    combat_target.set_physics_process(false)
    combat_target.global_position = Vector3(-36.0, 0.95, -0.9)
    combat_player.process_mode = Node.PROCESS_MODE_ALWAYS
    combat_player.set_physics_process(true)
    combat_player.global_position = Vector3(-40.0, 0.9, -0.9)
    combat_player.rotation.y = -PI * 0.5
    await physics_frame

    var health_before := int(target_health.get("current_health"))
    combat_player.request_fire()
    await physics_frame
    await process_frame
    if int(target_health.get("current_health")) != health_before - 1:
        l1_root.queue_free()
        _fail(
            "Level 1 hitscan did not damage squirrel: before=%d after=%d"
            % [health_before, int(target_health.get("current_health"))]
        )
        return

    await create_timer(0.30).timeout
    combat_player.request_fire()
    await physics_frame
    await process_frame
    if not bool(target_health.get("is_dead")):
        l1_root.queue_free()
        _fail(
            "Level 1 squirrel could not be killed by repeated direct hits: health=%d"
            % int(target_health.get("current_health"))
        )
        return

    var initial_y: Dictionary = {}
    for enemy in enemies:
        initial_y[enemy] = float(enemy.global_position.y)

    for _i in range(45):
        await process_frame

    for enemy in enemies:
        if not is_equal_approx(float(enemy.global_position.y), float(initial_y[enemy])):
            var drift := float(enemy.global_position.y) - float(initial_y[enemy])
            l1_root.queue_free()
            _fail(
                "Level 1 squirrel Y drift detected: %s drift=%.5f"
                % [enemy.name, drift]
            )
            return

    var environment_script := FileAccess.get_file_as_string(
        "res://scripts/level1_environment.gd"
    )
    var wall_shader_source := FileAccess.get_file_as_string(
        "res://shaders/level1_wall_night.gdshader"
    )
    if not wall_shader_source.contains("ao_strength") or not wall_shader_source.contains("smoothstep(0.0, ao_height"):
        l1_root.queue_free()
        _fail("Level 1 wall contact-AO shader is missing its bottom gradient")
        return
    if not wall_shader_source.contains("sample_triplanar"):
        l1_root.queue_free()
        _fail("Level 1 wall shader lost the CI #199 triplanar sampling path")
        return
    if not wall_shader_source.contains("vec2(p.z, -p.y)") or not wall_shader_source.contains("vec2(p.x, -p.y)"):
        l1_root.queue_free()
        _fail("Level 1 wall shader vertical texture flip regression detected")
        return
    if not wall_shader_source.contains("triplanar_scale"):
        l1_root.queue_free()
        _fail("Level 1 wall shader triplanar scale parameter is missing")
        return
    if not wall_shader_source.contains("render_mode unshaded, cull_back"):
        l1_root.queue_free()
        _fail("Level 1 wall shader culling changed from the CI #199 configuration")
        return
    if not environment_script.contains("FLOOR_UV_SCALE := Vector3(0.22, 0.22, 0.22)"):
        l1_root.queue_free()
        _fail("Level 1 floor texture scale regression detected")
        return

    var squirrel_script := FileAccess.get_file_as_string(
        "res://scripts/level1_enemy.gd"
    )
    if squirrel_script.contains("global_position = proposed")             and not squirrel_script.contains("proposed.y = ground_y"):
        l1_root.queue_free()
        _fail("Level 1 movement no longer clamps proposed Y")
        return
    if not squirrel_script.contains("nav_dir.y = 0.0"):
        l1_root.queue_free()
        _fail("Level 1 navigation direction can still alter Y")
        return

    l1_root.queue_free()

    print("FULL GAME FLOW SMOKE TEST: PASS; L1 height-safe -> L2 -> L3 -> menu")
    quit(0)

func _fail(message: String) -> void:
    push_error("FULL GAME FLOW SMOKE TEST: " + message)
    quit(1)
