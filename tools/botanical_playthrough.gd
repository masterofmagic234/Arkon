extends SceneTree
## A complete fresh-run route driven by production input, gravity and collision.
var game: Node3D
var player: Node3D
var scene_id:=0
var record_output:=""
var frames:=0
var tick:=0
var visited: Array[String]=[]
var combat_mode:=false
func _init() -> void:
    combat_mode="--combat" in OS.get_cmdline_user_args()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--record="):record_output=arg.trim_prefix("--record=")
    call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:push_error("BOTANICAL PLAYTHROUGH: "+why);quit(1)
func settle(n:=12) -> void:
    for i in range(n):await physics_frame
func run() -> void:
    root.get_node("GameState").start_new_run();root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    if not record_output.is_empty():
        check(DisplayServer.get_name()!="headless","recording needs native frames");DirAccess.make_dir_recursive_absolute(record_output)
        root.size=Vector2i(960,540);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;RenderingServer.set_render_loop_enabled(false)
    change_scene_to_file("res://game.tscn");await settle(18);game=current_scene;player=game.player;scene_id=game.get_instance_id()
    check(game.ready_for_play and game.is_botanical,"botanical director did not boot")
    if not record_output.is_empty():game.hud.set_mobile_preview(true)
    await capture();await walk(Vector3(4,0,59));interact();await physics_frame
    check(game.progress.journal,"journal was not collected")
    await walk(Vector3(24,0,39));await walk(Vector3(26,3,24))
    await walk(Vector3(28,3,19));interact();await physics_frame
    await walk(Vector3(38,3,19));interact();await physics_frame
    check(game.progress.water,"actual valves did not activate irrigation")
    check(game.water_flow.visible,"restored irrigation has no visible water")
    visited.append("sluices");await capture()
    await walk(Vector3(30,3,7));await walk(Vector3(-26,3,8));await walk(game.SEED_POSITIONS[0]);interact();await physics_frame
    check(game.progress.seeds[0],"pond specimen not collected");visited.append("pond")
    await walk(Vector3(0,3,8));await walk(Vector3(0,7,-18))
    await walk(Vector3(-40,7,-20));await walk(Vector3(-39,7,-34));await walk(game.SEED_POSITIONS[1]);interact();await physics_frame
    check(game.progress.seeds[1],"western glasshouse specimen not collected");visited.append("west wing");await capture()
    await walk(Vector3(-39,7,-34));await walk(Vector3(-56,7,-48));await walk(Vector3(-53,10,-64));await walk(game.SEED_POSITIONS[2]);interact();await physics_frame
    check(game.progress.seeds[2],"upper grove specimen not collected");visited.append("upper orchard");await capture()
    await walk(Vector3(-23,12,-87));await walk(Vector3(25,12,-87));await walk(Vector3(43,12,-79));visited.append("pavilion")
    await walk(Vector3(53,11,-67));await walk(Vector3(56,7,-48));await walk(Vector3(56,7,-20));await walk(Vector3(0,7,-18));await walk(Vector3(0,3,8));await walk(Vector3(-25,3,8))
    if not combat_mode:
        if game.guide.position.z>30:await walk(Vector3(-27,1.5,35))
        # Complete the companion's actual walk through the same physical garden.
        for i in range(11000):
            if game.progress.guide_step==5:break
            var target: Vector3=game.guide.position
            var direction=target-player.position;direction.y=0
            if direction.length()>2.5:move(direction.normalized(),target)
            else:release_movement()
            await physics_frame;await capture_tick()
        release_movement();check(game.progress.guide_step==5,"guide escort stalled: step=%d player=%s guide=%s"%[game.progress.guide_step,player.position,game.guide.position])
    if combat_mode:await walk(Vector3(0,3,8));await walk(Vector3(0,7,-18))
    await walk(Vector3(-9,7,-18));interact();await physics_frame
    await walk(Vector3(0,7,-19));await walk(Vector3(3,7,-25));await walk(Vector3(9,7,-31));interact();await physics_frame;interact();await physics_frame
    check(game.light_solved and game._garden_ready(),"physical reflected light did not reach the receiver")
    visited.append("conservatory");await capture()
    await walk(Vector3(3,7,-25));await walk(Vector3(0,7,-20));interact();await physics_frame
    if combat_mode:
        check(game.stage=="cache","guardian did not accept the combat route")
        await fight_guardian()
    check(game.progress.guardian and game.tank.defeated,"guardian encounter did not complete")
    await walk(Vector3(3,7,-25));await walk(Vector3(3,7,-35));await walk(Vector3(0,7,-36));interact();await physics_frame
    check(game.progress.reward and root.get_node("GameState").acorns_collected==6,"revived garden did not yield the reward")
    await walk(Vector3(3,7,-25));await walk(Vector3(0,7,-18));await walk(Vector3(0,3,8));await walk(Vector3(-25,3,8));await walk(Vector3(-28,1.5,35));await walk(Vector3(0,0,45));await walk(game.DEPARTURE)
    check(game.get_instance_id()==scene_id,"the garden secretly replaced its scene between destinations")
    check(not root.get_node("GameState").is_completed(&"level1"),"garden completed before boarding the car")
    await capture();interact();await settle(30)
    check(current_scene.scene_file_path=="res://scenes/park_escape_cutscene.tscn","boarding did not open the park departure film")
    check(root.get_node("GameState").is_completed(&"level1") and root.get_node("GameState").acorns_collected==6,"boarding film lost earned progression")
    check(FileAccess.file_exists("user://botanical_garden.json"),"boarding deleted the checkpoint before the film finished")
    current_scene.get_node("Frame/SkipButton").pressed.emit();await settle(30)
    check(current_scene.scene_file_path=="res://scenes/level2.tscn","finished garden did not continue into Level2")
    check(not FileAccess.file_exists("user://botanical_garden.json"),"completed garden retained a stale checkpoint")
    if not record_output.is_empty():
        FileAccess.open(record_output.path_join("walk-evidence.json"),FileAccess.WRITE).store_string(JSON.stringify({"visited":visited,"scene_instances":1,"frames":frames,"note":"Production movement/hitscan and actual frames. About 15x accelerated when encoded at 3 fps. No device FPS claim."},"  "))
    print("BOTANICAL PLAYTHROUGH: PASS — one scene, real stairs/side ramps, three specimens, sluices, reflected sunlight, physical scout escort or two-phase fight, guardian outcome, reward, final car and departure film into Level2")
    current_scene.queue_free();current_scene=null;await settle();await load("res://tools/level3_test_teardown.gd").drain_audio(self);RenderingServer.set_render_loop_enabled(true);quit(0)
func fight_guardian() -> void:
    var stomp_seen=false
    for i in range(6000):
        if game.tank.defeated:break
        check(not game.mission_failed,"guardian defeated the combat driver")
        var tank=game.tank;var direction=Vector3.ZERO
        player.look_at(Vector3(tank.position.x,player.position.y,tank.position.z));player.camera.look_at(tank.position+Vector3.UP*1.15)
        if tank.state in ["windup","charge"]:direction=tank._charge_direction.cross(Vector3.UP).normalized()
        elif tank.state in ["stomp_windup","shockwave"]:
            stomp_seen=true;direction=tank.position.direction_to(player.position);direction.y=0
            if player.dash_cooldown<=0:player.request_dash()
        elif tank.state=="recover":player.request_fire()
        elif player.position.distance_to(tank.position)>8:direction=player.position.direction_to(tank.position);direction.y=0
        var local: Vector3=player.global_basis.inverse()*direction.normalized()
        for pair in [["l1_move_forward",-local.z],["l1_move_backward",local.z],["l1_move_left",-local.x],["l1_move_right",local.x]]:Input.action_press(pair[0],maxf(0,pair[1]))
        await physics_frame
    release_movement();await settle(8)
    check(game.tank.defeated and stomp_seen and game.progress.guardian,"two-phase combat never completed")
func walk(goal: Vector3) -> void:
    for i in range(2800):
        check(not game.mission_failed,"player defeated while walking to "+str(goal))
        var direction=goal-player.position;direction.y=0
        if direction.length()<1.15:release_movement();return
        move(direction.normalized(),goal);await physics_frame;await capture_tick()
    push_error("BOTANICAL PLAYTHROUGH: blocked route to %s at %s"%[goal,player.position]);quit(1)
func move(direction: Vector3,goal: Vector3) -> void:
    var aiming=false
    for guard in game.guards:
        if not guard.is_tank and not guard.defeated and guard.position.distance_to(player.position)<15:
            player.look_at(Vector3(guard.position.x,player.position.y,guard.position.z));player.camera.look_at(guard.position+Vector3.UP*.9);player.request_fire();aiming=true;break
    if not aiming:player.look_at(Vector3(goal.x,player.position.y,goal.z));player.camera.rotation=Vector3.ZERO
    var local: Vector3=player.global_basis.inverse()*direction
    for pair in [["l1_move_forward",-local.z],["l1_move_backward",local.z],["l1_move_left",-local.x],["l1_move_right",local.x]]:Input.action_press(pair[0],maxf(0,pair[1]))
func release_movement() -> void:
    for action in ["l1_move_forward","l1_move_backward","l1_move_left","l1_move_right"]:Input.action_release(action)
func interact() -> void:
    var event=InputEventAction.new();event.action="l1_interact";event.pressed=true;Input.parse_input_event(event)
    var up=InputEventAction.new();up.action="l1_interact";Input.parse_input_event(up)
func capture_tick() -> void:
    if record_output.is_empty():return
    tick+=1
    if tick%300==0:await capture()
func capture() -> void:
    if record_output.is_empty():return
    await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(record_output.path_join("frame-%04d.png"%frames));frames+=1
func force_draw() -> void:RenderingServer.force_draw(true)
