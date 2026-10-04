extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var expected_main := "res://game.tscn"
    var expected_l2 := "res://scenes/level2_pseudo3d.tscn"
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
    if not l1_script.contains('const LEVEL_2_SCENE_PATH := "res://scenes/level2_pseudo3d.tscn"'):
        _fail("L1 does not declare the Level 2 transition")
        return

    if not l1_script.contains('get_tree().call_deferred("change_scene_to_file", LEVEL_2_SCENE_PATH)'):
        _fail("L1 completion does not transition to Level 2")
        return

    var l2_script := FileAccess.get_file_as_string("res://scripts/game_level2_pseudo3d.gd")
    if not l2_script.contains('@onready var oka_stage: Node3D = $Oka3DStage'):
        _fail("Level 2 is missing the dedicated Node3D Oka stage binding")
        return

    var oka_stage_script := FileAccess.get_file_as_string("res://scripts/level2_oka_3d_stage.gd")
    if not oka_stage_script.contains("extends Node3D"):
        _fail("Level 2 Oka stage is not a Node3D root")
        return
    if not oka_stage_script.contains("SubViewport.new()") or not oka_stage_script.contains("Camera3D.new()"):
        _fail("Level 2 Oka stage is missing SubViewport/Camera3D")
        return
    if not oka_stage_script.contains('const OKA_MODEL_PATH := "res://compact+car+3d+model.glb"'):
        _fail("Level 2 Oka stage is not bound to the uploaded GLB")
        return
    if not oka_stage_script.contains("PI + track_yaw"):
        _fail("Level 2 Oka model is not rotated to show its rear while driving")
        return
    if not l2_script.contains('get_tree().call_deferred(') or not l2_script.contains('"res://scenes/level3_store.tscn"'):
        _fail("Level 2 does not transition to Level 3")
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
        _fail("Level 2 runtime scene failed to load")
        return
    var l2_root := l2_scene.instantiate()
    if l2_root == null:
        l1_root.queue_free()
        _fail("Level 2 runtime scene failed to instantiate")
        return
    get_root().add_child(l2_root)
    await process_frame
    await process_frame
    await process_frame
    var oka_stage := l2_root.get_node_or_null("Oka3DStage")
    if oka_stage == null:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 Oka3DStage node is missing at runtime")
        return
    if not bool(oka_stage.call("is_model_ready")):
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 Oka 3D model did not become ready")
        return
    var oka_texture := oka_stage.call("get_view_texture") as Texture2D
    if oka_texture == null or oka_texture.get_width() != 256 or oka_texture.get_height() != 256:
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 Oka viewport texture has unexpected size")
        return
    var player_racer := l2_root.get_node_or_null("Racers/Player")
    var player_visual := player_racer.get_node_or_null("Visuals") if player_racer != null else null
    if player_visual == null or not player_visual.has_method("bind_stage"):
        l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 player visual is not wired to the dedicated Oka stage")
        return
    l2_root.queue_free()

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
    combat_player.global_position = Vector3(-40.0, 0.9, -0.9)
    combat_player.rotation.y = -PI * 0.5
    await process_frame

    var health_before := int(target_health.get("current_health"))
    combat_player.request_fire()
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
