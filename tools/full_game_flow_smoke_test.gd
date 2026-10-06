extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    # --- Architecture contract: SceneFlow + GameState runtime behavior ---
    var game_state := root.get_node_or_null("GameState")
    if game_state == null:
        _fail("GameState autoload missing")
        return
    var scene_flow := root.get_node_or_null("SceneFlow")
    if scene_flow == null:
        _fail("SceneFlow autoload missing")
        return
    var pause_manager := root.get_node_or_null("PauseManager")
    if pause_manager == null:
        _fail("PauseManager autoload missing")
        return

    var signal_bus := root.get_node_or_null("SignalBus")
    if signal_bus == null:
        _fail("SignalBus autoload missing")
        return

    game_state.start_new_run()
    if game_state.is_completed(&"level1"):
        _fail("GameState.start_new_run did not clear completed_levels")
        return
    game_state.mark_completed(&"level1")
    if not game_state.is_completed(&"level1"):
        _fail("GameState.mark_completed did not persist")
        return
    if not game_state.is_unlocked(&"level2", &"level1"):
        _fail("GameState.is_unlocked false after predecessor completed")
        return
    if game_state.is_unlocked(&"level2", &"level3"):
        _fail("GameState.is_unlocked true with uncompleted predecessor")
        return
    game_state.retry_level()
    if not game_state.is_completed(&"level1"):
        _fail("GameState.retry_level cleared completed_levels (must keep progression)")
        return
    game_state.start_new_run()

    var campaign: Array = scene_flow.get("CAMPAIGN") as Array
    if campaign.size() < 4 or campaign[0] != &"level1" or campaign[campaign.size() - 1] != &"menu":
        _fail("SceneFlow.CAMPAIGN order contract broken")
        return

    pause_manager.resume()
    if pause_manager.is_paused:
        _fail("PauseManager still paused after resume()")
        return

    var expected_main := "res://game.tscn"
    var expected_l2 := "res://scenes/level2.tscn"
    var expected_l3 := "res://scenes/level3_store.tscn"
    var expected_menu := "res://menu.tscn"

    # Behavioral campaign gate: exercise the real SceneFlow + SignalBus contract
    # in one SceneTree. The scene transitions are intentionally driven by the
    # same global completion fact emitted by the gameplay directors.
    scene_flow.go_to(&"level1")
    if not await _wait_for_scene(expected_main):
        _fail("SceneFlow did not load Level 1")
        return
    if bool(scene_flow.get("_transitioning")):
        _fail("SceneFlow transition guard remained active after Level 1 load")
        return

    signal_bus.emit_signal(&"level_completed", &"level1")
    if not await _wait_for_scene(expected_l2):
        _fail("SceneFlow did not transition Level 1 -> Level 2")
        return
    if not game_state.is_completed(&"level1"):
        _fail("Level 1 completion was not persisted during real flow")
        return
    if bool(scene_flow.get("_transitioning")):
        _fail("SceneFlow transition guard remained active after Level 1 -> Level 2")
        return

    var active_l2: Node = current_scene
    var l2_script := FileAccess.get_file_as_string("res://scripts/game_level2_pseudo3d.gd")
    if active_l2 == null or str(active_l2.get_script().resource_path) != "res://scripts/game_level2_pseudo3d.gd":
        _fail("Active Level 2 scene is not using game_level2_pseudo3d.gd")
        return
    var active_l2_hud := active_l2.get_node_or_null("HUD/HUDRoot")
    var active_l2_minimap := active_l2.get_node_or_null("HUD/Minimap")
    if active_l2_hud == null or active_l2_hud.get("player_movement") == null:
        _fail("Level 2 HUD did not bind to the runtime player")
        return
    if not l2_script.contains("func _physics_process(delta: float)"):
        _fail("Level 2 race simulation is not driven from fixed physics")
        return
    var race_car_script := FileAccess.get_file_as_string("res://scripts/race_car_controller.gd")
    for marker in [
        "var lateral_offset: float = 0.0",
        "RaceMath.track_center_x(track_position, track_x)",
        "world_x = center + lateral_offset"
    ]:
        if not race_car_script.contains(marker):
            _fail("Level 2 car is not using the continuous centerline contract: %s" % marker)
            return
    var race_overlay_script := FileAccess.get_file_as_string("res://scripts/race_240sx_overlay.gd")
    if not race_overlay_script.contains("RaceMath.track_center_x(track_position, track_x)"):
        _fail("Level 2 240SX overlay is using a discrete road center")
        return
    if not race_overlay_script.contains("const MODEL_AUTHORED_FORWARD_YAW := PI"):
        _fail("Level 2 240SX orientation is not configured for a rear-facing camera view")
        return
    if not race_overlay_script.contains("func _fit_camera_to_model(scaled_size: Vector3) -> void:"):
        _fail("Level 2 240SX viewport fitting is not geometry-driven")
        return
    if not race_overlay_script.contains("viewport.size = next_viewport_size"):
        _fail("Level 2 240SX SubViewport is not matched to the overlay aspect")
        return
    if not g_script_is_audio_manager_bound():
        _fail("Level 2 music is not registered with AudioManager")
        return
    var race_renderer_script := FileAccess.get_file_as_string("res://scripts/race_renderer_pseudo3d.gd")
    if not race_renderer_script.contains("return RaceMath.track_center_x(track_position, track_x)"):
        _fail("Level 2 renderer is not using the shared continuous centerline")
        return
    var level2_scene := FileAccess.get_file_as_string("res://scenes/level2.tscn")
    if not level2_scene.contains("autoplay = false"):
        _fail("Level 2 scene music can bypass AudioManager on scene enter")
        return
    if not level2_scene.contains("stretch = false"):
        _fail("Level 2 240SX SubViewportContainer must disable stretch for manual responsive sizing")
        return
    if active_l2_minimap == null or (active_l2_minimap.get("map_points") as PackedVector2Array).is_empty():
        _fail("Level 2 minimap did not build runtime geometry")
        return

    signal_bus.emit_signal(&"level_completed", &"level2")
    if not await _wait_for_scene(expected_l3):
        _fail("SceneFlow did not transition Level 2 -> Level 3")
        return
    if not game_state.is_completed(&"level2"):
        _fail("Level 2 completion was not persisted during real flow")
        return
    if bool(scene_flow.get("_transitioning")):
        _fail("SceneFlow transition guard remained active after Level 2 -> Level 3")
        return

    var level3_store_script := FileAccess.get_file_as_string("res://scripts/level3_store.gd")
    if not level3_store_script.contains("Edge actions stay pending until Level3Player consumes them"):
        _fail("Level 3 ACTION/THROW input can still be cleared on the render tick")
        return
    var level3_projectile_script := FileAccess.get_file_as_string("res://scripts/level3_projectile.gd")
    for projectile_marker in [
        "intersect_ray(query)",
        "query.collide_with_bodies = true",
        "query.collide_with_areas = true",
        "callback.call(impact_position, _impact_collider)"
    ]:
        if not level3_projectile_script.contains(projectile_marker):
            _fail("Level 3 projectile swept-collision contract missing: %s" % projectile_marker)
            return
    signal_bus.emit_signal(&"level_completed", &"level3")
    if not await _wait_for_scene(expected_menu):
        _fail("SceneFlow did not transition Level 3 -> menu")
        return
    if not game_state.is_completed(&"level3"):
        _fail("Level 3 completion was not persisted during real flow")
        return
    if bool(scene_flow.get("_transitioning")):
        _fail("SceneFlow transition guard remained active after Level 3 -> menu")
        return

    scene_flow.go_to(&"level1")
    if not await _wait_for_scene(expected_main):
        _fail("SceneFlow could not start a second campaign cycle")
        return
    if bool(scene_flow.get("_transitioning")):
        _fail("SceneFlow transition guard remained active after second cycle")
        return

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
    if not l1_script.contains('emit_signal(&"level_completed", &"level1")'):
        _fail("L1 completion does not emit level_completed for SceneFlow")
        return

    for marker in [
        'extends Node2D',
        'const RaceController = preload("res://scripts/race_controller.gd")',
        'controller.setup(',
        'renderer.bind(',
        'hud_panel.bind(',
        'minimap.bind(',
        'SignalBus',
        'level_completed'
    ]:
        if not l2_script.contains(marker):
            _fail("Active pseudo-3D Level 2 scene-director contract missing: %s" % marker)
            return

    var controller_script := FileAccess.get_file_as_string(
        "res://scripts/race_controller.gd"
    )
    for marker in [
        'extends RefCounted',
        'func start()',
        'func handle_input(',
        'func update(',
        '_sync_visuals()',
        '_sync_hud()'
    ]:
        if not controller_script.contains(marker):
            _fail("Level 2 pseudo-3D controller marker missing: %s" % marker)
            return

    var renderer_script := FileAccess.get_file_as_string(
        "res://scripts/race_renderer_pseudo3d.gd"
    )
    for marker in [
        'extends Node2D',
        'func _draw_road(',
        'func _draw_ai_cars(',
        'func _draw_player_car('
    ]:
        if not renderer_script.contains(marker):
            _fail("Level 2 pseudo-3D renderer marker missing: %s" % marker)
            return

    if not ResourceLoader.exists("res://scenes/level2_pseudo3d.tscn"):
        _fail("Pseudo-3D Level 2 scene is missing")
        return
    if not ResourceLoader.exists("res://scripts/race_state.gd"):
        _fail("Pseudo-3D Level 2 race state is missing")
        return
    if not ResourceLoader.exists("res://scripts/race_car_controller.gd"):
        _fail("Pseudo-3D Level 2 car controller is missing")
        return

    for legacy_3d_path in [
        "res://scripts/race_director.gd",
        "res://scripts/level2_camera_3d.gd",
        "res://scripts/level2_racer.gd",
        "res://scripts/level2_racer_visual_3d.gd",
        "res://scripts/components/race_movement_component.gd",
        "res://scripts/components/race_ai_component.gd",
        "res://scripts/race_authored_track_data.gd",
        "res://scripts/race_track_view.gd",
        "res://scripts/race_hud.gd",
        "res://scripts/race_audio.gd",
        "res://scenes/level2_racer.tscn",
        "res://scenes/level2_racer_3d.tscn"
    ]:
        if ResourceLoader.exists(legacy_3d_path):
            _fail("Obsolete 3D Level 2 resource still exists: %s" % legacy_3d_path)
            return

    var l3_script := FileAccess.get_file_as_string("res://scripts/level3_store.gd")
    var scene_flow_script := FileAccess.get_file_as_string(
        "res://scripts/scene_flow.gd"
    )
    if not l3_script.contains('emit_signal(&"level_completed", &"level3")'):
        _fail("Level 3 completion does not emit level_completed for SceneFlow")
        return
    if not scene_flow_script.contains('const CAMPAIGN := [&"level1", &"level2", &"level3", &"menu"]'):
        _fail("SceneFlow no longer routes Level 3 completion to menu")
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

    # The second campaign cycle already leaves a real Level 1 scene active.
    # Reuse that runtime scene instead of instantiating a duplicate physics world.
    var l1_root: Node = current_scene
    if l1_root == null or l1_root.scene_file_path != expected_main:
        _fail("Level 1 runtime scene is not the active campaign scene")
        return

    await process_frame
    await process_frame
    await process_frame

    var pseudo_l2_scene := load(expected_l2) as PackedScene
    if pseudo_l2_scene == null:
        l1_root.queue_free()
        _fail("Level 2 pseudo-3D scene failed to load")
        return

    l1_root.process_mode = Node.PROCESS_MODE_DISABLED

    var pseudo_l2_root := pseudo_l2_scene.instantiate()
    if pseudo_l2_root == null:
        l1_root.queue_free()
        _fail("Level 2 pseudo-3D scene failed to instantiate")
        return

    get_root().add_child(pseudo_l2_root)
    await process_frame
    await process_frame
    await process_frame

    if not (pseudo_l2_root is Node2D):
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 active scene is not Node2D pseudo-3D")
        return

    var pseudo_renderer := pseudo_l2_root.get_node_or_null("Renderer")
    if pseudo_renderer == null or not (pseudo_renderer is Node2D):
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 pseudo-3D renderer is missing")
        return

    var car_3d_overlay := pseudo_l2_root.get_node_or_null(
        "Car3DOverlay"
    ) as SubViewportContainer
    if car_3d_overlay == null or car_3d_overlay.get_script() == null:
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 dedicated 3D car overlay is missing")
        return
    if str(car_3d_overlay.get_script().resource_path) != "res://scripts/race_240sx_overlay.gd":
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 dedicated 3D car overlay uses the wrong script")
        return

    var car_3d_viewport := car_3d_overlay.get_node_or_null(
        "Car3DViewport"
    ) as SubViewport
    if car_3d_viewport == null:
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 dedicated 3D car viewport is missing")
        return

    var car_3d_world := car_3d_viewport.get_node_or_null(
        "Car3DWorld"
    ) as Node3D
    if car_3d_world == null:
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 dedicated 3D car world is missing")
        return

    var car_overlay_script := FileAccess.get_file_as_string(
        "res://scripts/race_240sx_overlay.gd"
    )
    if (
        not car_overlay_script.contains("240_sx_nfs_pro_street.glb")
        or not car_overlay_script.contains("SubViewport")
    ):
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 240SX overlay does not use the dedicated 3D viewport")
        return

    if not ResourceLoader.exists("res://240_sx_nfs_pro_street.glb"):
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 240SX asset was removed")
        return

    var pseudo_hud_root := pseudo_l2_root.get_node_or_null(
        "HUD/HUDRoot"
    )
    if pseudo_hud_root == null or pseudo_hud_root.get_script() == null:
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 pseudo-3D HUD root is missing")
        return
    if str(pseudo_hud_root.get_script().resource_path) != "res://scripts/race_hud_panel_pseudo3d.gd":
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 HUD is not using the pseudo-3D HUD")
        return

    var pseudo_minimap := pseudo_l2_root.get_node_or_null("HUD/Minimap")
    if pseudo_minimap == null or pseudo_minimap.get_script() == null:
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 minimap is missing")
        return
    if str(pseudo_minimap.get_script().resource_path) != "res://scripts/race_minimap_nes.gd":
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 minimap is not using the pseudo-3D race minimap")
        return

    if not bool(car_3d_overlay.call("is_model_ready")):
        pseudo_l2_root.queue_free()
        l1_root.queue_free()
        _fail("Level 2 240SX model did not become ready")
        return

    pseudo_l2_root.queue_free()

    # Level 1 was paused while the pseudo-3D Level 2 scene was being inspected.
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
        "cull_back",
        "filter_linear_mipmap",
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
    if grass_instance_count < 2500 or grass_instance_count > 3300:
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
    if camera.far > 29.1:
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
    if fog.fog_depth_begin > 8.1 or fog.fog_depth_end < 23.4 or fog.fog_depth_end >= camera.far:
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
        var current_y := float(enemy.global_position.y)
        var expected_y := float(initial_y[enemy])
        var drift := current_y - expected_y
        if absf(drift) > 0.001:
            var locked_y := float(enemy.get("ground_y"))
            l1_root.queue_free()
            _fail(
                "Level 1 squirrel Y drift detected: %s drift=%.5f current=%.5f expected=%.5f ground_y=%.5f"
                % [enemy.name, drift, current_y, expected_y, locked_y]
            )
            return

    var level_data_script := FileAccess.get_file_as_string(
        "res://scripts/level_data.gd"
    )
    for grid_marker in [
        "static func world_to_cell(",
        "static func cell_center_world(",
        "static func cell_bounds_world("
    ]:
        if not level_data_script.contains(grid_marker):
            l1_root.queue_free()
            _fail("Level 1 shared grid contract missing: %s" % grid_marker)
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
    if not squirrel_script.contains("player_visible and ai.can_attack(dist)"):
        l1_root.queue_free()
        _fail("Level 1 squirrels can attack without line-of-sight")
        return
    var movement_script := FileAccess.get_file_as_string("res://scripts/movement_math.gd")
    if not movement_script.contains("player_basis.x * right"):
        l1_root.queue_free()
        _fail("Desktop A/D strafe is missing from Level 1 movement math")
        return
    if not player_script.contains("var movement_axis := move_axis if desktop_mode else Vector2(0.0, move_axis.y)"):
        l1_root.queue_free()
        _fail("Level 1 mobile turning/desktop strafe split is missing")
        return
    var minimap_script := FileAccess.get_file_as_string("res://scripts/minimap_view.gd")
    if not minimap_script.contains('str(LevelData.CANONICAL_MAP[row]).substr(col, 1) != "#":'):
        l1_root.queue_free()
        _fail("Level 1 minimap is not reading canonical wall cells")
        return
    if not minimap_script.contains("func _calculate_map_transform()"):
        l1_root.queue_free()
        _fail("Level 1 minimap does not scale from full world bounds")
        return
    if minimap_script.contains("const MAP_SCALE := 3.0"):
        l1_root.queue_free()
        _fail("Level 1 minimap still uses the fixed legacy scale")
        return
    var hitbox_script := FileAccess.get_file_as_string("res://scripts/components/hitbox_3d_component.gd")
    if not hitbox_script.contains("func receive_hit(amount: int, source: Node = null) -> bool"):
        l1_root.queue_free()
        _fail("Level 1 hitbox does not return actual damage application")
        return

    l1_root.queue_free()
    await process_frame

    print("FULL GAME FLOW SMOKE TEST: PASS; L1 -> L2 -> L3 -> menu -> L1")
    quit(0)

func _wait_for_scene(expected_path: String, max_frames: int = 120) -> bool:
    for _i in range(max_frames):
        var current: Node = current_scene
        if current != null and current.scene_file_path == expected_path:
            await process_frame
            return true
        await process_frame
    return false

func g_script_is_audio_manager_bound() -> bool:
    var source := FileAccess.get_file_as_string("res://scripts/game_level2_pseudo3d.gd")
    return source.contains("AudioManager.register_music(race_music)")

func _fail(message: String) -> void:
    push_error("FULL GAME FLOW SMOKE TEST: " + message)
    quit(1)
