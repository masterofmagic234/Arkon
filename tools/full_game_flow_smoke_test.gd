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
    if hit_box == null or hit_box.size.x < 1.5 or hit_box.size.z < 1.0:
        enemy_probe.queue_free()
        _fail("Level 1 squirrel hitbox is still too narrow")
        return
    if visual_quad == null or visual_quad.size.x < 2.2 or visual_quad.size.y < 2.2:
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

    var enemies := l1_root.get_tree().get_nodes_in_group("level1_enemy")
    if enemies.is_empty():
        l1_root.queue_free()
        _fail("Level 1 runtime produced no squirrels")
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
