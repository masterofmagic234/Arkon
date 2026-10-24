extends SceneTree
const State=preload("res://scripts/woodland_journey_state.gd")
var game: Node3D
var failures: Array[String]=[]
func _init() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("JOURNEY RULES: "+why)
func settle(count:=8) -> void:
    for i in range(count):await physics_frame
func load_area(index: int,done:=false) -> void:
    if current_scene!=null:current_scene.queue_free();current_scene=null;await settle()
    var save=State.new();save.region=index
    for i in range(index):save.completed.append(i)
    if done:save.completed.append(index)
    check(save.save_checkpoint(),"checkpoint save")
    change_scene_to_file("res://game.tscn");await settle();game=current_scene
    game.player.set_physics_process(false)
    for guard in game.guards:guard.set_physics_process(false)
func interact_at(position_: Vector3) -> void:
    game.player.position=position_+Vector3.UP*.65;game.interact()
func run() -> void:
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    change_scene_to_file("res://game.tscn");await settle()
    check(FileAccess.file_exists(State.PATH),"first entry created no resumable checkpoint")
    await load_area(2)
    interact_at(game.NEXT_TRAIL);check(not game.travelling,"unfinished area opened its next path")
    interact_at(Vector3(0,0,-19));check(not game.regional.complete,"mill key collected through a locked sluice")
    var query=PhysicsRayQueryParameters3D.create(Vector3(0,1,7),Vector3(0,1,0),1)
    check(not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"closed bridge has no physical gate")
    interact_at(Vector3(-16,0,9));interact_at(Vector3(16,0,9));await settle()
    check(game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"correct valves did not remove the real bridge gate")
    for i in range(120):await physics_frame
    check(game.world.water_surface.position.y<-.15,"sluices never lowered the visible water")
    await load_area(2,true)
    check(game.regional.complete and game.world.bridge_gate==null and game.world.water_surface.position.y<-.3,"solved mill reverted after backtracking")
    await load_area(3)
    interact_at(Vector3(12,0,-17));check(not game.regional.complete,"unlit flower yielded a seal")
    interact_at(Vector3(-12,0,-2));interact_at(Vector3(12,0,-2))
    check(not game.regional.light_reaches_flower,"wrong reflection reached the flower")
    await load_area(4)
    game.player.position=Vector3(0,.65,0);game.regional.update(.1)
    check(game.player.position.distance_to(Vector3(-20,.65,12))<.1 and game.player.get_hp()==85,"ravine did not rescue an off-bridge player")
    game.player.position=Vector3(0,.65,-2);game.player.quiet_mode=true;game.regional.wind_time=6
    game.regional.update(.4);check(is_equal_approx(game.player.position.z,-2),"braced player drifted in the wind")
    game.player.quiet_mode=false;game.regional.update(.3);check(game.player.position.z> -2,"gust had no physical effect on an unbraced player")
    await load_area(4,true)
    check(game.world.shortcut_open,"ravine rope did not restore its visible shortcut")
    game.player.position=Vector3(0,.65,0);game.regional.update(.1)
    check(game.player.position.z==0,"completed ravine shortcut did not support the player")
    game.player.position=Vector3(8,.65,0);game.regional.update(.1)
    check(game.player.position.distance_to(Vector3(-20,.65,12))<.1,"completed ravine allowed walking off its visible bridges")
    await load_area(6)
    game.regional.target_hit(0);game.regional.target_hit(2)
    check(game.regional.rune_step==0 and not game.regional.complete,"wrong rune order was accepted")
    game.player.ammo=0;interact_at(Vector3(0,0,16));check(game.player.ammo==38,"rune puzzle can run out of ammunition permanently")
    await load_area(3)
    interact_at(Vector3(-12,0,-2));game.player.health.apply_damage(30);game.player.ammo=4
    game.restart();await settle(24);game=current_scene
    check(game.region_index==3 and game.journey.completed.size()==3,"retry lost the current area checkpoint")
    check(game.player.get_hp()==100 and game.player.ammo==38 and game.regional.mirror_states==[0,0],"retry retained partial puzzle/damage instead of the entry checkpoint")
    game.hud.set_mobile_preview(true)
    var stick=game.hud.joystick.get_global_rect().get_center()
    var touch=InputEventScreenTouch.new();touch.index=11;touch.position=stick;touch.pressed=true;game.hud._input(touch)
    var drag=InputEventScreenDrag.new();drag.index=11;drag.position=stick+Vector2(0,-35);drag.relative=Vector2(0,-35);game.hud._input(drag)
    check(Input.is_action_pressed("l1_move_forward"),"mobile movement setup failed")
    touch.index=12;touch.position=game.hud.map_button.get_global_rect().get_center();game.hud._input(touch)
    check(root.get_node("PauseManager").is_paused and game.hud.map_panel.visible and not Input.is_action_pressed("l1_move_forward"),"map touch was swallowed by look input or failed to release movement")
    game.hud._input(touch);check(not root.get_node("PauseManager").is_paused,"map could not close while paused")
    root.get_node("SceneFlow").go_to(&"menu");await settle(24)
    check(current_scene.get_node("LevelButtons/Level1Button").text.begins_with("ПРОДОЛЖИТЬ"),"menu offers no checkpoint continuation")
    current_scene.get_node("LevelButtons/Level1Button").pressed.emit();await settle(24);game=current_scene
    check(game.region_index==3 and game.journey.completed.size()==3,"menu resume discarded the checkpoint")
    root.get_node("GameState").start_new_run();check(not FileAccess.file_exists(State.PATH),"new adventure retained the previous journey")
    current_scene.queue_free();current_scene=null;await settle()
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if failures.is_empty():print("WOODLAND JOURNEY RULES: PASS — locked gates, water movement, wrong optics/runes, wind rescue, ammo recovery, checkpoint retry, touch map, menu resume and new-run reset")
    quit(0 if failures.is_empty() else 1)
