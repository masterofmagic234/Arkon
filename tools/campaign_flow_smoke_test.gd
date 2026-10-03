extends SceneTree

const MAIN_SCENE := "res://scenes/game.tscn"
const LEVEL2_SCENE := "res://scenes/level2_pseudo3d.tscn"
const LEVEL3_SCENE := "res://scenes/level3_store.tscn"
const MENU_SCENE := "res://menu.tscn"

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if ProjectSettings.get_setting("application/run/main_scene", "") != MAIN_SCENE:
        _fail("Campaign entry point is not Level 1")
        return
    if bool(ProjectSettings.get_setting("run/dev_force_level3", true)):
        _fail("Level 3 developer force-skip is still enabled")
        return

    for path in [MAIN_SCENE, LEVEL2_SCENE, LEVEL3_SCENE, MENU_SCENE]:
        if not ResourceLoader.exists(path):
            _fail("Campaign scene missing: %s" % path)
            return

    var level1_text := FileAccess.get_file_as_string("res://scripts/game.gd")
    if not level1_text.contains(LEVEL2_SCENE):
        _fail("Level 1 does not transition to Level 2")
        return

    var level2_text := FileAccess.get_file_as_string("res://scripts/game_level2_pseudo3d.gd")
    if not level2_text.contains("level_completed"):
        _fail("Level 2 does not consume the completion fact")
        return
    if not level2_text.contains(LEVEL3_SCENE):
        _fail("Level 2 does not transition to Level 3")
        return

    var level3_text := FileAccess.get_file_as_string("res://scripts/level3_store.gd")
    if not level3_text.contains('change_scene_to_file') or not level3_text.contains(MENU_SCENE):
        _fail("Level 3 has no direct completion route to the menu")
        return
    if level3_text.contains("start_dialogue("):
        _fail("Level 3 still contains an active cutscene/dialogue trigger")
        return

    print("CAMPAIGN FLOW SMOKE TEST: PASS; L1 -> L2 -> L3 -> MENU")
    quit(0)

func _fail(message: String) -> void:
    push_error("CAMPAIGN FLOW SMOKE TEST: " + message)
    quit(1)
