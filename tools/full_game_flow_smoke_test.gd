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
    var shared_camera = active_l2.camera_state
    var runtime_renderer = active_l2.get_node("Renderer")
    var runtime_overlay = active_l2.get_node("Car3DOverlay")
    if shared_camera == null or runtime_renderer.camera_state != shared_camera or runtime_overlay.camera_state != shared_camera:
        _fail("Level 2 renderer and model viewport do not share the director camera")
        return
    var saved_yaw: float = shared_camera.yaw_offset
    shared_camera.yaw_offset = 0.25
    var camera_ray: Vector2 = runtime_renderer._world_to_camera(sin(0.25) * 20.0, cos(0.25) * 20.0)
    shared_camera.yaw_offset = saved_yaw
    if absf(camera_ray.x) > 0.001 or absf(camera_ray.y - 20.0) > 0.001:
        _fail("Level 2 main camera does not rotate world points into the nose basis")
        return
    if not g_script_is_audio_manager_bound():
        _fail("Level 2 music is not registered with AudioManager")
        return
    var level2_scene := FileAccess.get_file_as_string("res://scenes/level2.tscn")
    if not level2_scene.contains("autoplay = false") or not level2_scene.contains("stretch = false"):
        _fail("Level 2 scene music/viewport lifecycle contract failed")
        return
    if active_l2_minimap == null:
        _fail("Level 2 minimap is missing")
        return
    if not active_l2_minimap.has_method("get_map_point_count"):
        _fail("Level 2 minimap geometry contract is missing")
        return
    if int(active_l2_minimap.call("get_map_point_count")) <= 0:
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

    var expected_start_menu := "res://menu.tscn"
    if str(ProjectSettings.get_setting("application/run/main_scene", "")) != expected_start_menu:
        _fail("main_scene is not the level selection menu: %s" % ProjectSettings.get_setting("application/run/main_scene", ""))
        return
    var menu_scene := load(expected_start_menu) as PackedScene
    if menu_scene == null:
        _fail("Level selection menu scene could not be loaded")
        return
    var menu_root := menu_scene.instantiate() as Control
    if menu_root == null:
        _fail("Level selection menu did not instantiate")
        return
    root.add_child(menu_root)
    for button_path in [
        "LevelButtons/Level1Button",
        "LevelButtons/Level2Button",
        "LevelButtons/Level3Button"
    ]:
        if menu_root.get_node_or_null(button_path) == null:
            menu_root.queue_free()
            _fail("Level selection menu is missing button: %s" % button_path)
            return
    menu_root.queue_free()
    await process_frame

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

    var environment_node := l1_root.get_node_or_null("Level1Environment")
    if environment_node == null or not environment_node.park_ready:
        _fail("Level 1 park presentation did not finish building")
        return
    var camera := l1_root.get_node("Player/Camera3D") as Camera3D
    if camera.far <= l1_root.get_node("WorldEnvironment").environment.fog_depth_end:
        _fail("Level 1 fog must hide the far clip")
        return
    if l1_root.get_node_or_null("ExitCar/BoardingArea") == null:
        _fail("Level 1 boarding trigger is missing")
        return
    for node in get_nodes_in_group("level1_enemy"):
        if not node.squirrel_3d_visual.presentation_ready:
            _fail("A Level 1 squirrel has no shared 3D visual")
            return
    l1_root.queue_free()
    await process_frame
    if is_instance_valid(current_scene): current_scene.queue_free()
    for i in range(3): await process_frame
    root.get_node("AudioManager").shutdown()
    OS.delay_msec(60)
    print("FULL GAME FLOW SMOKE TEST: PASS")
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
