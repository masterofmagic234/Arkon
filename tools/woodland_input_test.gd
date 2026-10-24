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
    root.get_node("PauseManager").set_paused(true)
    assert(not Input.is_action_pressed("l1_move_forward"))
    assert(hud.joystick_touch_id == -1 and hud.look_touch_id == -1 and hud.fire_touch_id == -1)
    touch(hud, 3, hud.fire_button.get_global_rect().get_center(), true)
    assert(director.player.shots == 1)
    root.get_node("PauseManager").resume()
    hud._refresh()
    assert(hud.boss_panel.visible)
    assert(hud.boss_panel.get_global_rect().intersection(hud.mission.get_global_rect()).get_area() == 0.0)
    print("WOODLAND HUD: PASS — independent move/look/fire, interaction, pause release, boss layout")
    hud.free()
    director.free()
    quit()
