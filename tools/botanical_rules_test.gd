extends SceneTree
var game: Node3D
var failed:=false
func _init() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failed=true;push_error("BOTANICAL RULES: "+why)
func settle(n:=12) -> void:
    for i in range(n):await physics_frame
func at(point: Vector3) -> void:
    game.player.position=point+Vector3.UP*.65;game.interact()
func emulated_mouse(point: Vector2,pressed: bool) -> void:
    var event:=InputEventMouseButton.new();event.device=InputEvent.DEVICE_ID_EMULATION;event.button_index=MOUSE_BUTTON_LEFT
    event.position=point;event.global_position=point;event.pressed=pressed
    root.push_input(event,true)
func run() -> void:
    root.get_node("GameState").start_new_run();root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    var scale_before=root.scaling_3d_scale;var msaa_before=root.msaa_3d;var occlusion_before=root.use_occlusion_culling;var fps_before=Engine.max_fps
    change_scene_to_file("res://game.tscn");await settle();game=current_scene;game.player.set_physics_process(false)
    at(game.DEPARTURE);check(not game.mission_complete,"fresh garden allowed car completion")
    at(Vector3(0,7,-20));check(game.stage!="cache","unrestored garden started the final fight")
    at(game.SEED_POSITIONS[1]);check(game.progress.seeds==[false,true,false],"specimens are gated by an unrelated location")
    at(Vector3(33,3,19));check(not game.progress.water,"wrong valve pattern was accepted")
    at(Vector3(33,3,19));at(Vector3(28,3,19));at(Vector3(38,3,19));check(game.progress.water and game.water_flow.visible,"correct valves failed to restore visible water")
    at(Vector3(-9,7,-18));at(Vector3(9,7,-31));check(not game.light_solved,"wrong reflection reached the flower")
    at(Vector3(9,7,-31));check(game.light_solved,"correct reflection never reached the flower")
    at(Vector3(0,7,-36));check(not game.progress.reward,"guarded reward was collected before the guardian")
    game._save();var old_id=game.get_instance_id();game.restart();await settle(30);game=current_scene
    check(game.get_instance_id()!=old_id,"retry never replaced the old instance")
    check(game.progress.water and game.progress.seeds==[false,true,false] and game.light_solved,"retry discarded partial quest progress")
    check(game.player.get_hp()==100 and game.player.ammo==38 and game.player.position.z>60,"retry did not restore safe entry resources")
    game.world.set_meta("force_mobile_profile",true);root.size=Vector2i(2400,1080);game.world._mobile_profile()
    check(root.scaling_3d_scale<.61,"Android 3D pixel cap missing")
    check(Engine.max_fps>0 and Engine.max_fps<=60,"high-refresh Android frame cap missing")
    game.hud.set_mobile_preview(true)
    var touch=InputEventScreenTouch.new();touch.index=8;touch.pressed=true;touch.position=game.hud.map_button.get_global_rect().get_center();game.hud._input(touch)
    check(root.get_node("PauseManager").is_paused and game.hud.map_panel.visible,"touch map did not pause the game")
    game.hud._input(touch);check(not root.get_node("PauseManager").is_paused,"touch map could not close while paused")
    # Use both input paths of one Android tap across separate frames. The
    # second, GUI activation used to close the pause opened by the raw touch.
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;await process_frame
    var pause_point=game.hud.pause_button.get_global_rect().get_center()
    touch.position=pause_point;game.hud._input(touch)
    await process_frame;emulated_mouse(pause_point,true)
    await process_frame;touch.pressed=false;game.hud._input(touch);emulated_mouse(pause_point,false)
    await process_frame
    check(root.get_node("PauseManager").is_paused and game.hud.modal.visible,"emulated release of a pause tap resumed the game")
    var diagnostics_point=game.hud.diagnostics_button.get_global_rect().get_center()
    emulated_mouse(diagnostics_point,true);emulated_mouse(diagnostics_point,false)
    var opened_probe: CanvasLayer
    for child in root.get_children():
        if child.get_script()==load("res://scripts/botanical_performance_probe.gd"):opened_probe=child
    check(opened_probe!=null,"paused touch could not open FPS diagnostics")
    if opened_probe!=null:
        # The native timed sampling is covered by botanical_probe_test; here
        # cancel immediately after the real GUI button opened it.
        opened_probe.cancelled=true
        for i in range(3):await process_frame
        opened_probe.queue_free();await process_frame
    check(root.get_node("PauseManager").is_paused,"diagnostics opening/cancel resumed gameplay")
    var continue_point=game.hud.resume_button.get_global_rect().get_center()
    emulated_mouse(continue_point,true);emulated_mouse(continue_point,false)
    await process_frame
    check(not root.get_node("PauseManager").is_paused,"explicit Continue did not resume after diagnostics")
    root.get_node("SceneFlow").go_to(&"menu");await settle(30)
    check(is_equal_approx(root.scaling_3d_scale,scale_before) and root.msaa_3d==msaa_before and root.use_occlusion_culling==occlusion_before and Engine.max_fps==fps_before,"garden rendering profile leaked to the menu")
    check(current_scene.get_node("LevelButtons/Level1Button").text.begins_with("ПРОДОЛЖИТЬ"),"menu lost saved garden continuation")
    current_scene.get_node("LevelButtons/Level1Button").pressed.emit();await settle(30);game=current_scene
    check(game.progress.water and game.progress.seeds[1],"menu resume erased the partially completed garden")
    root.get_node("GameState").start_new_run();check(not FileAccess.file_exists("user://botanical_garden.json"),"new adventure kept the garden checkpoint")
    current_scene.queue_free();current_scene=null;await settle();await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if not failed:print("BOTANICAL RULES: PASS — independent destinations, negative valves/optics/reward, partial checkpoint retry, native touch map, menu resume, profile restoration and new run")
    quit(1 if failed else 0)
