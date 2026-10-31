extends SceneTree
## Reproduce the owner's 1.31 experience from a NEW run: no completion flags,
## staged regional checkpoints, teleports, interact calls or hidden hotspot.
## Ordinary movement must discover every location and return to the first.
var game: Node3D
var player: Node3D
var visits: Array[int]=[0]
var replay_output := ""
var replay_frame := 0
var replay_tick := 0
func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--record="):replay_output=argument.trim_prefix("--record=")
    call_deferred("run")
func run() -> void:
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    if not replay_output.is_empty():
        check(DisplayServer.get_name()!="headless","recording requires a native renderer")
        DirAccess.make_dir_recursive_absolute(replay_output)
        root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(960,540)
        RenderingServer.set_render_loop_enabled(false)
    change_scene_to_file("res://game.tscn");await settle();bind_game()
    await record_frame()
    check(game.region_index==0 and game.journey.completed.is_empty(),"fresh game did not begin on the original clearing")
    check(game.hud.trail.visible and game.hud.trail.text.contains("ЯБЛОНЕВЫЙ САД"),"fresh entry does not advertise the next location")
    for point in [Vector3(8,0,20),Vector3(17,0,13),Vector3(20,0,0),Vector3(20,0,-15),Vector3(26,0,-25)]:await walk(point)
    await leave(1)
    # Return through the opposite corridor before completing either mission.
    check(game.journey.entry=="south" and player.position.z<30,"arrival spawned inside its return trigger")
    await walk(Vector3(-26,0,34));await leave(0,true)
    check(game.journey.entry=="north" and player.position.z > -30,"reverse travel returned to the car rather than the incoming path")
    await leave(1)
    for region in range(1,8):
        if region==4:
            await walk(Vector3(-20,0,12));player.toggle_quiet()
            for point in game.world.RAVINE_ROUTE:await walk(point)
            player.toggle_quiet();await walk(Vector3(26,0,-24))
        else:
            await walk(Vector3(0,0,22));await walk(Vector3(29,0,19))
            if region==2:
                await walk(Vector3(27,0,7));await walk(Vector3(27,0,-12))
                check(game.world.bridge_gate!=null and not game.regional.complete,"public footbridge accidentally solved the sluice puzzle")
            else:await walk(Vector3(29,0,-24))
            await walk(Vector3(26,0,-26))
        await leave(0 if region==7 else region+1)
    check(game.journey.visited.size()==8 and game.journey.completed.is_empty(),"exploring fabricated completion or did not visit every location")
    check(not root.get_node("GameState").is_completed(&"level1"),"exploration alone completed Level1")
    check(not game.context_text().contains("Сесть в машину"),"unfinished journey allowed campaign completion")
    root.get_node("SceneFlow").go_to(&"menu");await settle(24)
    current_scene.get_node("LevelButtons/Level1Button").pressed.emit();await settle(24);bind_game()
    check(game.journey.visited.size()==8 and game.journey.completed.is_empty(),"menu resume lost exploration or changed quest progress")
    if not replay_output.is_empty():
        var file=FileAccess.open(replay_output.path_join("walk-evidence.json"),FileAccess.WRITE)
        file.store_string(JSON.stringify({"visited":visits,"completed":game.journey.completed,"frames":replay_frame,"note":"Actual production movement from a fresh game; one captured frame per four simulated seconds, plus arrivals. Encode at 3 fps for approximately 12x speed. No phone FPS claim."},"  "))
        file.close()
    print("WOODLAND OPEN TRAILS: PASS visits=",visits," fresh-run physical walking; automatic forward/backward crossings; unfinished quests; public bridge; checkpoint resume")
    current_scene.queue_free();current_scene=null;await settle()
    await load("res://tools/level3_test_teardown.gd").drain_audio(self);RenderingServer.set_render_loop_enabled(true);quit(0)
func bind_game() -> void:
    game=current_scene;player=game.player
    if not replay_output.is_empty():game.hud.set_mobile_preview(true)
func record_tick() -> void:
    if replay_output.is_empty():return
    replay_tick+=1
    if replay_tick%240==0:await record_frame()
func record_frame() -> void:
    if replay_output.is_empty() or current_scene!=game:return
    await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(replay_output.path_join("frame-%04d.png"%replay_frame))
    replay_frame+=1
func force_draw() -> void:RenderingServer.force_draw(true)
func settle(frames:=12) -> void:
    for i in range(frames):await physics_frame
func leave(expected: int,back:=false) -> void:
    var goal=Vector3(-26,0,43) if back else Vector3(26,0,-43)
    for i in range(1400):
        if current_scene!=game:break
        move_toward_point(goal);await physics_frame
        await record_tick()
    release_movement();await settle(24)
    check(current_scene!=game,"walking through the open trail did not change locations")
    bind_game();check(game.region_index==expected,"trail arrived at the wrong location")
    check(game.journey.completed.is_empty(),"travel silently completed an unfinished quest")
    visits.append(expected)
    await record_frame()
func walk(goal: Vector3) -> void:
    for i in range(2200):
        check(not game.mission_failed,"defeated while following the public route")
        var direction=goal-player.position;direction.y=0
        if direction.length()<1.15:release_movement();return
        move_toward_point(goal);await physics_frame
        await record_tick()
    fail("blocked walking to %s at %s"%[goal,player.position])
func move_toward_point(goal: Vector3) -> void:
    var aiming=false
    for guard in game.guards:
        if not guard.is_tank and not guard.defeated and guard.position.distance_to(player.position)<16:
            player.look_at(Vector3(guard.position.x,player.position.y,guard.position.z));player.camera.look_at(guard.position+Vector3.UP*.9)
            player.request_fire();aiming=true;break
    if not aiming:player.look_at(Vector3(goal.x,player.position.y,goal.z));player.camera.rotation=Vector3.ZERO
    var direction=goal-player.position;direction.y=0
    var local: Vector3=player.global_basis.inverse()*direction.normalized()
    for pair in [["l1_move_forward",-local.z],["l1_move_backward",local.z],["l1_move_left",-local.x],["l1_move_right",local.x]]:Input.action_press(pair[0],maxf(0,pair[1]))
func release_movement() -> void:
    for action in ["l1_move_forward","l1_move_backward","l1_move_left","l1_move_right"]:Input.action_release(action)
func check(ok: bool,why: String) -> void:
    if not ok:fail(why)
func fail(why: String) -> void:
    release_movement();push_error("WOODLAND OPEN TRAILS: "+why);quit(1)
