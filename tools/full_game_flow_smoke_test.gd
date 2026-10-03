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
    if not l3_script.contains('change_scene_to_file", "res://menu.tscn"'):
        _fail("Level 3 completion does not return to menu")
        return

    if l3_script.contains("dialogue.start_dialogue("):
        _fail("Level 3 still contains an automatic cinematic/dialogue gate")
        return

    if l3_script.contains("var _clear_timer"):
        _fail("Level 3 still contains obsolete cinematic timer state")
        return

    print("FULL GAME FLOW SMOKE TEST: PASS; L1 -> L2 -> L3 -> menu")
    quit(0)

func _fail(message: String) -> void:
    push_error("FULL GAME FLOW SMOKE TEST: " + message)
    quit(1)
