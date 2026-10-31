extends SceneTree
## Staged real keyboard/mouse/UI checks. Self-contained so the same script can
## run outside an exported Windows PCK through the executable's --script flag.
var failures: Array[String] = []
var output := "/tmp/desktop-controls157"
var visual := false
var native := false
var report: Dictionary = {"checks":[],"captures":[]}
var completed_stages: Array[String] = []

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--visual": visual = true
        elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    report.checks.append({"pass":ok,"message":message})
    if not ok:
        failures.append(message)
        push_error("DESKTOP CONTROLS157: " + message)

func frames(count: int = 2) -> void:
    for index in range(count): await process_frame

func ticks(count: int = 2) -> void:
    for index in range(count): await physics_frame

func key(code: Key, pressed: bool) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = pressed
    Input.parse_input_event(event)
    await process_frame

func tap(code: Key) -> void:
    await key(code,true)
    await key(code,false)

func physical_e_on_russian_layout() -> void:
    for pressed in [true,false]:
        var event := InputEventKey.new()
        event.keycode = 0x0423 # Logical У while the physical E key stays E.
        event.physical_keycode = KEY_E
        event.pressed = pressed
        Input.parse_input_event(event)
        await process_frame

func click(control: Control) -> void:
    var at := control.get_global_rect().get_center()
    for pressed in [true,false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.global_position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = pressed
        Input.parse_input_event(event)
        await process_frame

func capture(label: String) -> void:
    if not visual or not native: return
    await process_frame
    RenderingServer.force_draw(true)
    var picture := root.get_texture().get_image()
    check(picture != null and not picture.is_empty(),"native picture exists: " + label)
    if picture == null or picture.is_empty(): return
    check(picture.save_png(output.path_join(label+".png")) == OK,"native picture saved: " + label)
    report.captures.append(label+".png")

func launch(path: String) -> Node:
    root.get_node("PauseManager").resume()
    var scene := (load(path) as PackedScene).instantiate()
    root.add_child(scene)
    current_scene = scene
    await ticks(4)
    return scene

func dispose() -> void:
    root.get_node("PauseManager").resume()
    if is_instance_valid(current_scene): current_scene.queue_free()
    current_scene = null
    await frames(5)

func menu_checks() -> void:
    var menu: Control = await launch("res://menu.tscn")
    await tap(KEY_ESCAPE)
    check(not paused and not root.get_node("PauseManager").is_paused,"plain menu Escape does not pause/freeze the title screen")
    await click(menu.get_node("GraphicsButton"))
    var chooser: Control = menu.get_node("GraphicsPanel156")
    check(chooser.visible,"real mouse click opens desktop graphics menu")
    await tap(KEY_ESCAPE)
    check(not chooser.visible and not paused,"graphics Escape closes its modal once without pausing the menu")
    await capture("menu-keyboard")
    await dispose()
    completed_stages.append("menu")

func garden_checks() -> void:
    root.get_node("GameState").start_new_run()
    var game = await launch("res://game.tscn")
    for index in range(720):
        if game.ready_for_play and game.guard_navigation.is_ready: break
        await ticks(1)
    check(game.ready_for_play and game.guard_navigation.is_ready,"production garden becomes ready")
    if not game.ready_for_play: await dispose(); return
    for guard in game.guards: guard.set_physics_process(false)
    game.set_physics_process(false)
    check(game.player.desktop_mode and not game.hud.mobile,"garden selects keyboard/mouse desktop mode")
    for control in [game.hud.joystick,game.hud.fire_button,game.hud.interact_button,game.hud.dash_button]:
        check(not control.visible,"garden hides desktop touch control: " + String(control.name))
    var before: Vector3 = game.player.position
    await key(KEY_W,true)
    await ticks(5)
    await key(KEY_W,false)
    check(Vector2(before.x,before.z).distance_to(Vector2(game.player.position.x,game.player.position.z)) > 0.03,"physical W key moves the real collision body")
    if native:
        var yaw: float = game.player.rotation.y
        var motion := InputEventMouseMotion.new()
        motion.relative = Vector2(20,2)
        Input.parse_input_event(motion)
        await frames()
        check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and absf(game.player.rotation.y-yaw) > 0.001,"captured desktop mouse rotates the real camera")
    await key(KEY_W,true)
    game.hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(paused and root.get_node("PauseManager").is_paused,"actual botanical HUD forwards Alt-Tab pause notification")
    check(not Input.is_action_pressed("l1_move_forward") and not game.player.fire_requested,"focus loss releases held garden actions")
    if native: check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"focus loss releases the captured mouse")
    game.hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    check(paused,"focus return waits for explicit resume")
    await key(KEY_W,false)
    await tap(KEY_ESCAPE)
    check(not paused,"Escape explicitly resumes garden")
    if native: check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"garden resume recaptures the mouse")
    await capture("garden-desktop")
    await dispose()
    completed_stages.append("garden")

func race_checks() -> void:
    # The production vehicle target deliberately waits for submitted GPU
    # frames before announcing readiness. Keep that real bootstrap contract.
    if native: RenderingServer.set_render_loop_enabled(true)
    var game = await launch("res://scenes/level2.tscn")
    for index in range(360):
        if game.ready_for_play: break
        await frames(1)
    check(game.ready_for_play,"production race vehicle presentation becomes ready")
    RenderingServer.set_render_loop_enabled(false)
    var presentation = game.presentation
    check(presentation.desktop_controls == (OS.get_name()=="Windows"),"Windows desktop controls are selected only on Windows by default")
    var geometry := [game.get_viewport_rect().size,game.renderer.PLAYFIELD_FRACTION,game.car_3d_overlay.viewport.size,game.car_3d_overlay.camera.fov]
    # Explicitly stage both presentation modes on Linux; the exported Windows
    # run additionally checks that the desktop branch was selected by default.
    presentation.desktop_controls = true
    for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
        root.size = dimensions
        await frames()
        presentation.layout()
        check(not game.joystick.visible and not game.gas_button.visible and not game.brake_button.visible,"Windows hides phone driving controls at " + str(dimensions))
        check(presentation.keyboard_hint.visible and game.hud_background.get_global_rect().encloses(presentation.keyboard_hint.get_global_rect()),"desktop key legend fits its dashboard at " + str(dimensions))
    root.size = Vector2i(1280,720)
    await frames()
    presentation.layout()
    check(geometry == [game.get_viewport_rect().size,game.renderer.PLAYFIELD_FRACTION,game.car_3d_overlay.viewport.size,game.car_3d_overlay.camera.fov],"desktop HUD preserves shared camera/playfield/3D projection")
    await key(KEY_W,true)
    check(game.race_input.read().throttle == 1.0,"physical W holds the throttle")
    await key(KEY_D,true)
    check(game.race_input.read().steer == 1.0,"physical D steers right")
    await key(KEY_W,false)
    await key(KEY_D,false)
    await key(KEY_S,true)
    check(game.race_input.read().brake == 1.0,"physical S holds braking/reverse input")
    game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(paused and game.race_input.read() == {"steer":0.0,"throttle":0.0,"brake":0.0},"race focus loss pauses and releases all held controls")
    await key(KEY_S,false)
    await tap(KEY_ESCAPE)
    check(not paused,"Escape explicitly resumes pursuit")
    await capture("race-windows-keyboard")
    presentation.desktop_controls = false
    presentation.layout()
    check(game.joystick.visible and game.gas_button.visible and game.brake_button.visible and not presentation.keyboard_hint.visible,"phone/legacy driving controls remain available without desktop mode")
    await dispose()
    completed_stages.append("race")

func diner_checks() -> void:
    var game = await launch("res://scenes/level3_store.tscn")
    for index in range(120):
        if game.ready_for_play: break
        await ticks(1)
    check(game.ready_for_play,"production diner and navigation become ready")
    check(not game.hud.mobile_active and not game.move_joystick.visible and not game.aim_joystick.visible,"diner selects native desktop keyboard/mouse UI")
    check(not game.player.combat_enabled,"desktop diner entry keeps the weapon holstered")
    await frames()
    var objective: Label = game.objective_label
    check(game.hud._cards[0].get_global_rect().encloses(objective.get_global_rect()),"desktop diner objective stays inside its card")
    check(objective.get_line_count() == 2 and objective.get_minimum_size().y <= objective.size.y,"full initial diner instruction fits two desktop lines")
    game.hud.mobile_active = true
    game.hud._layout()
    check(game.hud._cards[0].size.y == 88 and objective.size.y == 26 and objective.autowrap_mode == TextServer.AUTOWRAP_OFF,"mobile diner objective keeps its original card and single-line layout")
    game.hud.mobile_active = false
    game.hud._layout()
    var before: Vector2 = game.player.global_position
    await key(KEY_W,true)
    await ticks(5)
    await key(KEY_W,false)
    check(before.distance_to(game.player.global_position) > 1.0,"physical W moves the real diner actor")
    await key(KEY_D,true)
    game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(paused and not Input.is_action_pressed("l3_move_right"),"diner focus loss pauses and releases its keyboard input")
    game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    check(paused,"diner remains paused when focus returns")
    await key(KEY_D,false)
    await tap(KEY_ESCAPE)
    check(not paused and not game.hud.mobile_active,"diner resumes with desktop controls")
    await capture("diner-desktop")
    var lines: Array[Dictionary] = [
        {"speaker":"ТАЯ","portrait":"carolina","text":"Проверяем физическую клавишу действия."},
        {"speaker":"ПОВАР","portrait":"chef","text":"Раскладка не должна мешать разговору."}
    ]
    game.dialogue.start_dialogue(lines)
    await ticks(8)
    await physical_e_on_russian_layout()
    check(game.dialogue._fully_revealed and game.dialogue._index == 0,"Russian-layout physical E reveals the current dialogue line")
    await ticks(8)
    await physical_e_on_russian_layout()
    check(game.dialogue._index == 1 and not game._pending_action,"Russian-layout physical E advances dialogue without leaking a world action")
    game.dialogue.cancel_dialogue()
    game.mission.begin_raid()
    await frames(3)
    check(game.mission.is_raid_cinematic(),"real raid cinematic starts for keyboard-skip check")
    await physical_e_on_russian_layout()
    check(game.mission.raid_skipped and game.mission.deployment_count == 10,"Russian-layout physical E skips the actual tactical raid")
    check(not game._pending_action,"raid skip key does not also activate the world")
    for index in range(180):
        if game.navigation.ready and game.mission.phase == &"assault": break
        await ticks(1)
    check(game.navigation.ready and game.mission.phase == &"assault","keyboard skip completes physical breach navigation before restoring control")
    await dispose()
    completed_stages.append("diner")

func run() -> void:
    native = DisplayServer.get_name() != "headless"
    DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(1280,720)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").music_muted = true
    root.get_node("GameState").sfx_muted = true
    RenderingServer.set_render_loop_enabled(false)
    var physics_before := Engine.physics_ticks_per_second
    var speed_before := Engine.time_scale
    await menu_checks()
    await garden_checks()
    await race_checks()
    await diner_checks()
    check(completed_stages == ["menu","garden","race","diner"],"all desktop stages completed without an aborted coroutine")
    check(Engine.physics_ticks_per_second == physics_before and Engine.time_scale == speed_before,"desktop presentation does not alter physics or simulation speed")
    root.get_node("AudioManager").shutdown()
    var deadline := Time.get_ticks_msec()+350
    while Time.get_ticks_msec()<deadline:
        OS.delay_msec(10)
        await process_frame
    report.merge({"result":"PASS" if failures.is_empty() else "FAIL","failures":failures,"completed_stages":completed_stages,"platform":OS.get_name(),"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"mouse_capture_exercised":native,"staged_control_check_not_full_playthrough":true,"physical_windows_benchmark":false})
    var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
    check(file != null,"desktop report is writable")
    if file != null: file.store_string(JSON.stringify(report,"  "))
    RenderingServer.set_render_loop_enabled(true)
    if failures.is_empty(): print("DESKTOP CONTROLS157: PASS")
    quit(0 if failures.is_empty() else 1)
