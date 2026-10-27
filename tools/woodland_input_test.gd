extends SceneTree
class FakePlayer extends Node:
    var input_enabled := true
    var quiet_mode := false
    var fire_requested := false
    var shots := 0
    var looks := 0
    var dashes := 0
    func get_hp(): return 100
    func get_ammo(): return 38
    func request_fire(): shots += 1
    func request_dash(): dashes += 1
    func toggle_quiet(): quiet_mode = not quiet_mode
    func handle_touch_look(_relative): looks += 1
class FakeTank extends Node:
    var hp := 12
    var max_hp := 12
class FakeDirector extends Node:
    var player := FakePlayer.new()
    var tank := FakeTank.new()
    var stage := "cache"
    var mission_failed := false
    var mission_complete := false
    var stations_lit := 1
    var interactions := 0
    func objective_text(): return "СТРАЖ ДУБА\nУклоняйся от рывка. Стреляй, пока он переводит дух."
    func context_text(): return "Зажечь фонарь"
    func interact(): interactions += 1
    func restart(): pass
func _initialize(): call_deferred("run")
func touch(hud, id, point, pressed):
    var event := InputEventScreenTouch.new()
    event.index = id
    event.position = point
    event.pressed = pressed
    hud._input(event)
func drag(hud, id, point, relative):
    var event := InputEventScreenDrag.new()
    event.index = id
    event.position = point
    event.relative = relative
    hud._input(event)
func emulated_mouse(point: Vector2, pressed: bool) -> void:
    var event:=InputEventMouseButton.new()
    event.device=InputEvent.DEVICE_ID_EMULATION
    event.button_index=MOUSE_BUTTON_LEFT
    event.position=point;event.global_position=point;event.pressed=pressed
    root.push_input(event,true)
func run():
    var director := FakeDirector.new()
    root.add_child(director)
    director.add_child(director.player)
    director.add_child(director.tank)
    root.get_node("GameState").sfx_muted = true
    var hud = load("res://scripts/woodland_hud.gd").new()
    root.add_child(hud)
    hud.setup(director)
    hud.set_mobile_preview(true)
    var center = hud.joystick.get_global_rect().get_center()
    touch(hud, 1, center, true)
    drag(hud, 1, center + Vector2(30,-30), Vector2(30,-30))
    assert(Input.is_action_pressed("l1_move_forward"))
    assert(Input.is_action_pressed("l1_move_right"))
    touch(hud, 2, Vector2(780,320), true)
    drag(hud, 2, Vector2(795,320), Vector2(15,0))
    assert(director.player.looks == 1)
    touch(hud, 3, hud.fire_button.get_global_rect().get_center(), true)
    assert(director.player.shots == 1)
    assert(hud.fire_touch_id == 3 and hud.look_touch_id == 2 and hud.joystick_touch_id == 1)
    touch(hud, 3, Vector2.ZERO, false)
    assert(not hud.fire_held)
    assert(Input.is_action_pressed("l1_move_forward"))
    touch(hud, 4, hud.interact_button.get_global_rect().get_center(), true)
    assert(director.interactions == 1)
    var action_point=hud.interact_button.get_global_rect().get_center()
    await process_frame;emulated_mouse(action_point,true)
    await process_frame;touch(hud,4,action_point,false);emulated_mouse(action_point,false)
    await process_frame
    assert(director.interactions==1,"one Android action tap dispatched twice")
    root.get_node("PauseManager").set_paused(true)
    assert(not Input.is_action_pressed("l1_move_forward"))
    assert(hud.joystick_touch_id == -1 and hud.look_touch_id == -1 and hud.fire_touch_id == -1)
    touch(hud, 3, hud.fire_button.get_global_rect().get_center(), true)
    assert(director.player.shots == 1)
    root.get_node("PauseManager").resume()
    # Android dispatches the raw finger and its emulated mouse activation
    # separately. At slideshow FPS they can arrive on different frames.
    # One physical pause tap must never become pause followed by resume.
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    await process_frame
    var pause_point=hud.pause_button.get_global_rect().get_center()
    touch(hud,7,pause_point,true)
    assert(root.get_node("PauseManager").is_paused)
    await process_frame
    emulated_mouse(pause_point,true)
    await process_frame
    touch(hud,7,pause_point,false)
    emulated_mouse(pause_point,false)
    await process_frame
    assert(root.get_node("PauseManager").is_paused)
    assert(hud.modal.visible)
    # Explicit Continue remains a normal GUI activation and can resume.
    var continue_point=hud.resume_button.get_global_rect().get_center()
    emulated_mouse(continue_point,true);emulated_mouse(continue_point,false)
    await process_frame
    assert(not root.get_node("PauseManager").is_paused)
    hud._refresh()
    assert(hud.boss_panel.visible)
    assert(hud.boss_panel.get_global_rect().intersection(hud.mission.get_global_rect()).get_area() == 0.0)
    print("WOODLAND HUD: PASS — independent move/look/fire, interaction, pause release, boss layout")
    hud.free()
    director.free()
    quit()
