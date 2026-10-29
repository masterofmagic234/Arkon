extends SceneTree
## Verify player-facing copy while preserving update-compatible technical IDs.
const Dialogue = preload("res://scripts/level3_dialogue_lines.gd")
var failures: Array[String] = []
var scanned := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error("HERO NAME151: " + message)

func scan(path: String) -> void:
    var directory := DirAccess.open(path)
    if directory == null: return
    for child in directory.get_directories():
        scan(path.path_join(child))
    for filename in directory.get_files():
        if filename.get_extension() not in ["gd", "tscn", "tres"]: continue
        var file := path.path_join(filename)
        scanned += 1
        check(not FileAccess.get_file_as_string(file).to_lower().contains("каролин"), "old heroine name in shipped source: " + file)

func run() -> void:
    scan("res://scripts")
    scan("res://scenes")
    var lines: Array = []
    lines.append_array(Dialogue.RECEPTION)
    lines.append_array(Dialogue.KITCHEN)
    lines.append_array(Dialogue.AFTERMATH)
    var heroine_lines := 0
    for line in lines:
        if line.get("portrait", "") == "carolina":
            heroine_lines += 1
            check(line.speaker == "ТАЯ", "heroine's actual dialogue speaker is not ТАЯ")
    check(heroine_lines == 7, "heroine dialogue entries were lost during the rename")
    var intro: GDScript = load("res://scripts/intro_cinematic_v2.gd")
    var intro_lines: Array = intro.get_script_constant_map().get("DIALOGUE_DATA", [])
    var intro_heroine_lines := 0
    for line in intro_lines:
        if line.speaker == "ТАЯ": intro_heroine_lines += 1
    check(intro_heroine_lines == 9, "opening dialogue heroine labels were not all renamed")
    check(intro_lines.size() > 0 and intro_lines[0].text == "Тая, спишь?", "Darina still addresses the old name")
    check(FileAccess.get_file_as_string("res://scripts/level3_story.gd").contains("ЗАКАЗ НА ИМЯ ТАИ"), "declined order name was not changed")
    var export_config := ConfigFile.new()
    check(export_config.load("res://export_presets.cfg") == OK, "Android update settings unavailable")
    check(export_config.get_value("preset.0.options", "package/unique_name", "") == "com.acornhunter.carolina", "rename changed installed Android application identity")
    check(ResourceLoader.exists("res://assets/level3/carolina147/torso.png") and ResourceLoader.exists("res://assets/level3/carolina147/head.png"), "existing heroine art IDs were accidentally removed")
    print("HERO NAME151: ", "PASS" if failures.is_empty() else "FAIL", " / ", scanned, " production source files, ", heroine_lines, " diner heroine lines, ", intro_heroine_lines, " opening heroine lines")
    quit(0 if failures.is_empty() else 1)
