extends SceneTree
## Production dialogue node in an isolated UI fixture: real input and font/atlas.
const Dialogue = preload("res://scripts/level3_dialogue.gd")
const Lines = preload("res://scripts/level3_dialogue_lines.gd")
const Portraits = preload("res://scripts/level3_dialogue_portraits.gd")
var ui: Control
var dialogue: Control
var failures: Array[String] = []
var finished_count := 0
var faces_seen: Dictionary = {}
var visual := false
var output := ""

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--visual": visual = true
        elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool, why: String) -> void:
    if not ok:
        failures.append(why)
        push_error("LEVEL3 DIALOGUE: " + why)

func frames(count: int = 4) -> void:
    for index in range(count): await process_frame

func build() -> void:
    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(ui)
    current_scene = ui
    var background := ColorRect.new()
    background.color = Color("172831")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(background)
    dialogue = Dialogue.new()
    var panel := Panel.new();panel.name = "Panel";dialogue.add_child(panel)
    for name_ in ["Speaker", "Text", "Prompt"]:
        var label := Label.new();label.name = name_;panel.add_child(label)
    ui.add_child(dialogue)
    dialogue.finished.connect(func(): finished_count += 1)

func key(code: Key, echo := false) -> void:
    var event := InputEventKey.new()
    event.keycode = code;event.physical_keycode = code
    event.pressed = true;event.echo = echo
    root.push_input(event, true)
    await process_frame
    event = InputEventKey.new();event.keycode = code;event.physical_keycode = code
    root.push_input(event, true)
    await frames(2)

func touch(id: int, pressed: bool, position_: Vector2) -> void:
    var event := InputEventScreenTouch.new()
    event.index = id;event.pressed = pressed;event.position = position_
    root.push_input(event, true)
    await process_frame

func emulated_mouse(position_: Vector2) -> void:
    var event := InputEventMouseButton.new()
    event.device = InputEvent.DEVICE_ID_EMULATION
    event.button_index = MOUSE_BUTTON_LEFT;event.pressed = true
    event.position = position_;event.global_position = position_
    root.push_input(event, true)
    await process_frame
    event = InputEventMouseButton.new();event.device = InputEvent.DEVICE_ID_EMULATION
    event.button_index = MOUSE_BUTTON_LEFT;event.position = position_;event.global_position = position_
    root.push_input(event, true)
    await frames(2)

func sample_face() -> void:
    faces_seen["%s/%d" % [dialogue.current_portrait_key, dialogue.portrait_frame]] = true
    check(dialogue.portrait.texture != null, "missing production portrait texture")

func capture(name_: String) -> void:
    if not visual: return
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    check(image != null and not image.is_empty(), "empty native dialogue framebuffer")
    if image != null: check(image.save_png(output.path_join(name_ + ".png")) == OK, "cannot save native dialogue capture")

func run() -> void:
    if visual:
        check(not output.is_empty(), "visual mode needs --output")
        DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(1280, 720)
    build();await frames(8)
    for role in Portraits.PATHS:
        for index in range(4):
            var texture := Portraits.frame(role, index)
            check(texture != null and texture.get_size() == Vector2(96, 96), "portrait atlas/frame bounds " + role)
        var a := Portraits.frame(role, 0).get_image()
        var b := Portraits.frame(role, 1).get_image()
        var blink := Portraits.frame(role, 3).get_image()
        check(a.get_data() != b.get_data() and a.get_data() != blink.get_data(), "mouth/blink art must really change: " + role)
    dialogue.start_dialogue(Lines.KITCHEN)
    check(dialogue.is_active(), "conversation did not start")
    check(dialogue.text_label.visible_characters == 0, "typewriter was bypassed at line start")
    for index in range(35):
        await process_frame;sample_face()
    check(dialogue.text_label.visible_characters > 0 and dialogue.text_label.visible_characters < dialogue.text_label.text.length(), "text does not reveal progressively")
    check(faces_seen.has("carolina/1") and faces_seen.has("carolina/2"), "talking mouth frames do not animate")
    await capture("01-carolina-talking")
    await key(KEY_ENTER)
    check(dialogue._index == 0 and dialogue._fully_revealed, "first press must reveal, not skip the line")
    await frames(12);await key(KEY_ENTER, true)
    check(dialogue._index == 0, "keyboard auto-repeat advanced a page")
    var point := Vector2(640, 600)
    await touch(0, true, point)
    check(dialogue._index == 1, "raw finger did not advance the revealed line")
    await emulated_mouse(point)
    check(dialogue._index == 1 and not dialogue._fully_revealed, "same-finger emulated mouse revealed/skipped the next line")
    await frames(12);await touch(1, true, point)
    check(dialogue._index == 1 and not dialogue._fully_revealed, "second held finger advanced the dialogue")
    await touch(1, false, point);await touch(0, false, point)
    for index in range(16): await process_frame;sample_face()
    await capture("02-chef-talking")
    var before: int = dialogue.text_label.visible_characters
    var before_frame: int = dialogue.portrait_frame
    paused = true
    await frames(30);await key(KEY_SPACE)
    check(dialogue.text_label.visible_characters == before and dialogue.portrait_frame == before_frame and dialogue._index == 1, "pause changed text/portrait/page")
    paused = false;await frames(12)
    # Each passage requires a reveal (if unfinished), then a distinct next press.
    var seen_lines: Dictionary = {0:true,1:true}
    for attempts in range(30):
        if not dialogue.is_active(): break
        seen_lines[dialogue._index] = true
        await frames(10);dialogue.advance();await frames(10)
    check(not dialogue.is_active() and finished_count == 1 and seen_lines.size() == 6, "six-page kitchen conversation did not finish exactly once")
    dialogue.advance();check(finished_count == 1, "inactive advance emitted duplicate finish")
    dialogue.start_dialogue(Lines.AFTERMATH)
    for index in range(35): await process_frame;sample_face()
    check(dialogue.current_portrait_key == "chef_shocked" and faces_seen.has("chef_shocked/1") and faces_seen.has("chef_shocked/2"), "aftermath must use animated shocked chef art")
    await capture("03-chef-shocked")
    dialogue.advance()
    var blink_seen := false
    for index in range(220):
        await process_frame;sample_face()
        if dialogue.portrait_frame == 3: blink_seen = true
    check(blink_seen and dialogue._index == 0 and dialogue.portrait_frame == 0, "revealed line must wait for input and animate a complete blink back to rest")
    for viewport in [Vector2i(1024,576),Vector2i(2582,1220),Vector2i(1280,720)]:
        root.size = viewport;await frames(8)
        var bounds := Rect2(Vector2.ZERO,root.get_visible_rect().size)
        for control in [dialogue.panel, dialogue.portrait_border, dialogue.speaker_label, dialogue.text_label, dialogue.prompt_label]:
            var rect: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
            check(bounds.grow(1).encloses(rect), "dialogue/portrait leaves viewport " + str(viewport))
        for sequence in [Lines.RECEPTION, Lines.KITCHEN, Lines.AFTERMATH]:
            for line in sequence:
                var page: Array[Dictionary] = [line]
                dialogue.start_dialogue(page);dialogue._guard = 0;dialogue.advance();await frames(2)
                var font: Font = dialogue.text_label.get_theme_font("font")
                var height := font.get_height(24)
                check(dialogue.text_label.get_line_count() * height < dialogue.text_label.size.y, "Russian dialogue text clips at " + str(viewport))
    dialogue.cancel_dialogue()
    check(not dialogue.is_active() and not dialogue.visible, "cancel left modal input active")
    if failures.is_empty(): print("LEVEL3 DIALOGUE: PASS — original animated portraits, typewriter/reveal/advance, touch-emulation deduplication, held-finger guard, pause, six kitchen lines and three layouts")
    if visual:
        FileAccess.open(output.path_join("dialogue-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"kitchen_lines":6,"portrait_states":3,"poses":12,"face_samples":faces_seen.keys(),"renderer":RenderingServer.get_current_rendering_method()},"  "))
    ui.queue_free();current_scene = null;await frames(4)
    quit(0 if failures.is_empty() else 1)
