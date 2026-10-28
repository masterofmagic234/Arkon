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
    if combat_mode:
        await walk(Vector3(28,3,19));interact();await physics_frame
        await walk(Vector3(38,3,19));interact();await physics_frame
        check(not game.progress.water,"unpowered pump ran before installing its fuse/gear/key")
    visited.append("pump survey");await capture()
    await walk(Vector3(30,3,7));await walk(Vector3(-26,3,8));await walk(game.PART_POSITIONS[0]);interact();await physics_frame
    check(game.progress.parts[0],"pump fuse not collected");visited.append("pond")
    await walk(Vector3(0,3,8));await walk(Vector3(0,7,-18))
    await walk(Vector3(-40,7,-20));await walk(Vector3(-39,7,-34));await walk(game.PART_POSITIONS[1]);interact();await physics_frame
    check(game.progress.parts[1],"reduction gear not collected");visited.append("west wing");await capture()
    await walk(Vector3(-39,7,-34));await walk(Vector3(-56,7,-48));await walk(Vector3(-53,10,-64));await walk(game.PART_POSITIONS[2]);interact();await physics_frame
    check(game.progress.parts[2],"service-panel key not collected");visited.append("upper orchard");await capture()
    await walk(Vector3(-23,12,-87));await walk(Vector3(25,12,-87));await walk(Vector3(43,12,-79));visited.append("pavilion")
    await walk(Vector3(53,11,-67));await walk(Vector3(56,7,-48));await walk(Vector3(56,7,-20));await walk(Vector3(0,7,-18));await walk(Vector3(0,3,8));await walk(Vector3(26,3,8));await walk(game.PANEL);interact();await physics_frame
    check(game.progress.installed,"collected parts were never installed in the control panel")
    if not combat_mode:
        await walk(Vector3(28,3,19));interact();await physics_frame
        await walk(Vector3(38,3,19));interact();await physics_frame
    check(game.progress.water and game.water_flow.moving_water.visible,"repaired pump never supplied the contained channels")
    await walk(Vector3(26,3,8));await walk(Vector3(0,3,8));await walk(Vector3(0,7,-18));await walk(Vector3(0,7,-20))
    check(game._garden_ready() and game.water_flow.gate_open>=.98,"actual hydraulic gate did not open")
    visited.append("conservatory");await capture()
    await walk(Vector3(3,7,-25));await walk(Vector3(0,7,-20));interact();await physics_frame
    check(game.stage=="cache","guardian combat did not start")
    await fight_guardian()
    check(game.progress.guardian and game.tank.defeated,"guardian encounter did not complete")
    await walk(Vector3(3,7,-25));await walk(Vector3(0,7,-32));await walk(Vector3(0,7,-36));interact();await physics_frame
    check(game.progress.reward and root.get_node("GameState").acorns_collected==6,"revived garden did not yield the reward")
    await walk(Vector3(0,7,-32));await walk(Vector3(3,7,-25));await walk(Vector3(0,7,-18));await walk(Vector3(0,3,8));await walk(Vector3(-25,3,8));await walk(Vector3(-28,1.5,35));await walk(Vector3(0,0,45));await walk(game.DEPARTURE)
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
    print("BOTANICAL PLAYTHROUGH: PASS — one evening garden, physical stairs/ramps, three service parts installed, powered sluices/hydraulic gate, mandatory two-phase guardian fight, six acorns and departure film into Level2")
    current_scene.queue_free();current_scene=null;await settle();await load("res://tools/level3_test_teardown.gd").drain_audio(self);RenderingServer.set_render_loop_enabled(true);quit(0)
func fight_guardian() -> void:
    var stomp_seen=false
    for i in range(6000):
        if game.tank.defeated:break
        check(not game.mission_failed,"guardian defeated the combat driver")
        var tank=game.tank;var direction=Vector3.ZERO
        player.look_at(Vector3(tank.position.x,player.position.y,tank.position.z));player.camera.look_at(tank.position+Vector3.UP*1.15)
        if tank.state in ["windup","charge"]:
            # Dodge the actual locked lane, then stop spending movement once
            # clear. The former unconditional strafe ran off the terrace.
            var relative=player.position-tank.position;relative.y=0
            var lateral=relative-tank._charge_direction*relative.dot(tank._charge_direction)
            if lateral.length()<2.5:
                var side=tank._charge_direction.cross(Vector3.UP).normalized()
                var left=player.position+side*3;var right=player.position-side*3
                direction=side if absf(left.x)<absf(right.x) else -side
        elif tank.state in ["stomp_windup","shockwave"]:
            stomp_seen=true
            if player.position.distance_to(tank.position)<8.8:
                direction=tank.position.direction_to(player.position);direction.y=0
                if player.dash_cooldown<=0:player.request_dash()
        elif tank.state=="recover":
            if can_hit(tank):player.request_fire()
            else:
                var towards=player.position.direction_to(tank.position);towards.y=0
                direction=towards if player.position.distance_to(tank.position)>4 else towards.cross(Vector3.UP)
        elif player.position.distance_to(tank.position)>7:
            direction=player.position.direction_to(tank.position);direction.y=0
        # This is a normal steering target within the visible flat arena, not
        # a position clamp or teleport. Physics still decides where she moves.
        var next=player.position+direction.normalized()*2
        if absf(next.x)>8:direction.x=-signf(player.position.x)
        if next.z> -19:direction.z=-1
        elif next.z< -31:direction.z=1
        var local: Vector3=player.global_basis.inverse()*direction.normalized()
        for pair in [["l1_move_forward",-local.z],["l1_move_backward",local.z],["l1_move_left",-local.x],["l1_move_right",local.x]]:Input.action_press(pair[0],maxf(0,pair[1]))
        await physics_frame
    release_movement();await settle(8)
    check(game.tank.defeated and stomp_seen and game.progress.guardian,"two-phase combat never completed")

func can_hit(guard: Node3D) -> bool:
    var target=guard.global_position+Vector3.UP*(1.15 if guard.is_tank else .9)
    var query=PhysicsRayQueryParameters3D.create(player.camera.global_position,target,1|2)
    query.collide_with_areas=true
    var hit=game.get_world_3d().direct_space_state.intersect_ray(query)
    return not hit.is_empty() and hit.collider==guard.hitbox

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
        if not guard.is_tank and not guard.defeated and guard.position.distance_to(player.position)<15 and can_hit(guard):
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
