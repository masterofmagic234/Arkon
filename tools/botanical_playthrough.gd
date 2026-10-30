extends SceneTree
## A complete fresh-run route driven by production input, gravity and collision.
var game: Node3D
var player: Node3D
var scene_id:=0
var record_output:=""
var report_output:=""
var audio_events: Dictionary={}
var defeat_evidence: Dictionary={}
var role_attacks: Dictionary={}
var gallery_extent: Dictionary={"max_x":-1000.0,"max_radius":0.0}
var frames:=0
var tick:=0
var visited: Array[String]=[]
var combat_mode:=false
var input_counts: Dictionary={"l1_fire":0,"l1_interact":0,"l1_dash":0,"movement_frames":0}
var combat_samples: Array[Dictionary]=[]
var encounter_evidence: Array[Dictionary]=[]
var boss_recoveries:=0
var guardian_trace: Array[Dictionary]=[]
var shots:=0
var hits:=0
var shot_group:=""
var group_shots: Dictionary={}
var captured_attack_groups: Dictionary={}
var loaded_navigation_mask:=0
var actual_player_capsule: Dictionary={}
var pump_reserves_before_install: Dictionary={}
func _init() -> void:
    combat_mode="--combat" in OS.get_cmdline_user_args()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--record="):record_output=arg.trim_prefix("--record=")
        elif arg.begins_with("--report="):report_output=arg.trim_prefix("--report=")
    call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:push_error("BOTANICAL PLAYTHROUGH: "+why);quit(1)
func settle(n:=12) -> void:
    for i in range(n):await physics_frame
func run() -> void:
    root.get_node("GameState").start_new_run();root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    if not record_output.is_empty():
        check(DisplayServer.get_name()!="headless","recording needs native frames");DirAccess.make_dir_recursive_absolute(record_output)
        root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;RenderingServer.set_render_loop_enabled(false)
    root.get_node("SignalBus").audio_event.connect(on_audio_event)
    change_scene_to_file("res://game.tscn");await settle(18);game=current_scene;await await_garden_ready(game);player=game.player;scene_id=game.get_instance_id()
    check(game.ready_for_play and game.is_botanical,"botanical director did not boot")
    loaded_navigation_mask=game.guard_navigation._query.collision_mask
    check(loaded_navigation_mask==65,"actual production navigation omitted enclosed-rock clearance volumes")
    var body_shape=player.get_node("CollisionShape3D")
    actual_player_capsule={"height":body_shape.shape.height,"radius":body_shape.shape.radius,"offset":[body_shape.position.x,body_shape.position.y,body_shape.position.z]}
    check(is_equal_approx(body_shape.shape.height,1.7) and is_equal_approx(body_shape.position.y,.25),"fresh garden used the obsolete head-height collision body")
    if not record_output.is_empty():game.hud.set_mobile_preview(true)
    root.get_node("SignalBus").combat_event.connect(on_combat_event)
    # Read from the clear front-left approach, inside the actual3m prompt.
    # The original goal was the solid table centre. The new road-arrival
    # angle could leave the smaller player wedged beside it where the wider
    # production guard-route capsule correctly rejects a starting node.
    await capture();await walk(Vector3(2,0,60.5),.35);interact();await physics_frame
    check(game.progress.journal,"journal was not collected")
    # These are steering goals on the existing stairs and terraces. Every
    # fight below uses production movement and fire input, with no saved facts,
    # actor positions, enemy health or mission flags injected by the driver.
    await fight_group("entry")
    visited.append("entry battle");await capture()
    # Closed stair sides are retaining walls. Approach the real bottom landing
    # rather than cutting diagonally through the side halfway up the flight.
    await follow_route(Vector3(24,0,47));await walk(Vector3(24,0,39));await walk(Vector3(26,3,24));await walk(Vector3(35,3,23));await walk(Vector3(35,3,11))
    await fight_group("pump_repair")
    check(not game.progress.water and not game.progress.installed,"pump powered before the service action")
    await walk(game.PART_POSITIONS[0]);interact();await physics_frame
    check(game.progress.parts[0] and game.PART_POSITIONS.size()==1,"single pump fuse was not earned")
    visited.append("pump fuse");await capture()
    await walk(game.PANEL)
    var reserves: Array=[]
    for guard in game.guards:
        if guard.encounter_group=="pump":reserves.append({"id":guard.encounter_id,"hp":guard.hp,"defeated":guard.defeated})
    pump_reserves_before_install={"installed":game.progress.installed,"remaining":game.encounter_director.remaining("pump"),"actors":reserves}
    print("BOTANICAL PUMP RESERVES: ",JSON.stringify(pump_reserves_before_install))
    interact();await physics_frame
    check(game.progress.installed and game.progress.water and game.water_flow.moving_water.visible,"one repair action did not power the contained channels")
    check(not game._garden_ready(),"pump repair skipped the gallery encounter")
    await fight_group("pump")
    visited.append("pump counterattack");await capture()
    await walk(Vector3(26,3,12));await follow_route(Vector3(4,3,14));await walk(Vector3(0,7,-18))
    await walk(game.GALLERY_APPROACH);await walk(Vector3(-35,7,-26));await walk(game.GALLERY_ENTRANCE)
    # The nominal wingcentre is occupied by the solid exhibit pot row atz−33.
    # Enter through the real westend and use its clear northern interioraisle.
    await walk(Vector3(-35,7,-35.5));await walk(Vector3(-27,7,-35.5))
    await fight_group("gallery")
    await settle(165)
    check(game.progress.service_key and not game.progress.gate_unlatched and game.water_flow.gate_open<.01,"gallery victory bypassed the keyed lever")
    visited.append("gallery roles");visited.append("actual west glass wing");await capture()
    await walk(game.GALLERY_ENTRANCE);await walk(Vector3(-35,7,-26));await walk(Vector3(-10,7,-20));await walk(Vector3(0,7,-20))
    await walk(game.GATE_LEVER+Vector3(-1.4,0,1));interact()
    check(await preload("res://tools/botanical_guide153_input.gd").acknowledge(self,game),"the earned guardian tutorial did not accept ordinary mobile input")
    await settle(165)
    check(game._garden_ready() and game.water_flow.gate_open>=.98,"the gallery key did not release the lever-controlled gates")
    # The front doors open onto two aisles around the retained stone mullion.
    await walk(Vector3(1.35,7,-21),.35);await walk(Vector3(1.35,7,-26),.25);await physics_frame
    check(game.stage=="cache" and game.progress.guardian_started,"crossing the actual doorway did not automatically start guardian combat")
    await fight_guardian()
    check(game.progress.guardian and game.tank.defeated,"guardian encounter did not complete")
    visited.append("guardian two phases");await capture()
    # The reward plinth is solid. Reach the ordinary interaction radius from
    # its clear southern side rather than steering into its center.
    await follow_route(Vector3(0,7,-32));await walk(Vector3(0,7,-33.8),.35);interact();await physics_frame
    check(game.progress.reward and root.get_node("GameState").acorns_collected==6,"defeated guardian did not yield six acorns")
    check(not game.encounter_director.can_depart(),"reward pickup skipped the final escape")
    visited.append("six acorns");await capture()
    await walk(Vector3(0,7,-32));await walk(Vector3(1.35,7,-25));await walk(Vector3(1.35,7,-21));await walk(Vector3(0,7,-18));await walk(Vector3(0,3,8))
    await walk(Vector3(0,3,21));await walk(Vector3(0,0,42))
    await fight_group("escape")
    check(game.encounter_director.can_depart(),"physical escape defenders did not release boarding")
    visited.append("physical bridge and escape encounters");await capture()
    # Board from outside the now-solid parked body, within the real4m prompt.
    await walk(game.DEPARTURE+Vector3(0,0,-3),.4)
    check(game.get_instance_id()==scene_id,"the garden secretly replaced its scene between destinations")
    check(not root.get_node("GameState").is_completed(&"level1"),"garden completed before boarding the car")
    validate_combat_lifecycle()
    await capture();interact();await await_scene("res://scenes/park_escape_cutscene.tscn")
    check(current_scene.scene_file_path=="res://scenes/park_escape_cutscene.tscn","boarding did not open the park departure film")
    check(root.get_node("GameState").is_completed(&"level1") and root.get_node("GameState").acorns_collected==6,"boarding film lost earned progression")
    check(FileAccess.file_exists("user://botanical_garden.json"),"boarding deleted the checkpoint before the film finished")
    current_scene.get_node("Frame/SkipButton").pressed.emit();await await_scene("res://scenes/level2.tscn")
    check(current_scene.scene_file_path=="res://scenes/level2.tscn","finished garden did not continue into Level2")
    check(not FileAccess.file_exists("user://botanical_garden.json"),"completed garden retained a stale checkpoint")
    var evidence_output:=report_output if not report_output.is_empty() else record_output
    if not evidence_output.is_empty():
        DirAccess.make_dir_recursive_absolute(evidence_output)
        FileAccess.open(evidence_output.path_join("walk-evidence.json"),FileAccess.WRITE).store_string(JSON.stringify({"visited":visited,"scene_instances":1,"frames":frames,"input_counts":input_counts,"shots":shots,"accepted_hits":hits,"boss_recovery_windows":boss_recoveries,"guardian_trace":guardian_trace,"encounters":encounter_evidence,"combat_frames":combat_samples,"engine":Engine.get_version_info().string,"version":ProjectSettings.get_setting("application/config/version"),"source_hashes":source_hashes(),"gallery_extent":gallery_extent,"audio_events":audio_events,"pump_reserves_before_install":pump_reserves_before_install,"animated_defeats":defeat_evidence,"role_attacks":role_attacks,"loaded_navigation_mask":loaded_navigation_mask,"actual_player_capsule":actual_player_capsule,"note":"Fresh production InputMap movement/fire/dash/interact, actual collision and damage. Camera steering uses look_at. Frames sample gameplay including fights; encoded at 3fps, no device FPS claim."},"  "))
    print("BOTANICAL INPUT: actions=",JSON.stringify(input_counts)," shots=",shots," accepted_hits=",hits)
    print("BOTANICAL VOICES: ",JSON.stringify(audio_events))
    print("BOTANICAL DEFEATS: ",JSON.stringify(defeat_evidence))
    print("BOTANICAL PLAYTHROUGH: PASS — one evening garden, entry battle, one fuse/pump action, counterattack, gallery roles, physical stairs/bridge, mandatory two-phase guardian fight, six acorns and final escape and departure film into Level2")
    current_scene.queue_free();current_scene=null;await settle();await load("res://tools/level3_test_teardown.gd").drain_audio(self);RenderingServer.set_render_loop_enabled(true);quit(0)
func fight_guardian() -> void:
    var stomp_seen=false
    var last_state: String=""
    var last_hp: int=player.get_hp()
    var dodge_side:=Vector3.ZERO
    for i in range(6000):
        if game.tank.defeated:break
        check(not game.mission_failed,"guardian defeated the combat driver")
        var tank=game.tank;var direction=Vector3.ZERO
        if tank.state=="windup" and last_state!="windup":
            var side: Vector3=tank._charge_direction.cross(Vector3.UP).normalized()
            var left:=player.position+side*3;var right:=player.position-side*3
            dodge_side=side if absf(left.x)<absf(right.x) else -side
            var foot:=player.position-Vector3.UP*.6
            if not game.guard_navigation.segment_clear(foot,foot+dodge_side*3) and game.guard_navigation.segment_clear(foot,foot-dodge_side*3):dodge_side=-dodge_side
        if tank.state!=last_state or player.get_hp()!=last_hp:
            var row:={"tick":i,"state":tank.state,"hp":player.get_hp(),"boss_hp":tank.hp,"player":str(player.position),"boss":str(tank.position)}
            guardian_trace.append(row);print("BOTANICAL GUARDIAN: ",JSON.stringify(row))
        last_hp=player.get_hp()
        if tank.state=="recover" and last_state!="recover":boss_recoveries+=1
        last_state=tank.state
        player.look_at(Vector3(tank.position.x,player.position.y,tank.position.z));player.camera.look_at(tank.position+Vector3.UP*1.15)
        if tank.state in ["windup","charge"]:
            # Dodge the actual locked lane, then stop spending movement once
            # clear. The former unconditional strafe ran off the terrace.
            var relative=player.position-tank.position;relative.y=0
            var lateral=relative-tank._charge_direction*relative.dot(tank._charge_direction)
            if lateral.length()<2.5:
                # Commit to one clear side for this locked charge. Rechoosing
                # "closer to center" each tick just oscillates around x0.
                direction=dodge_side
        elif tank.state in ["stomp_windup","shockwave"]:
            stomp_seen=true
            if player.position.distance_to(tank.position)<8.8:
                direction=tank.position.direction_to(player.position);direction.y=0
                if player.dash_cooldown<=0:pulse("l1_dash")
        elif tank.state=="recover":
            if can_hit(tank):fire()
            else:
                var towards=player.position.direction_to(tank.position);towards.y=0
                direction=towards if player.position.distance_to(tank.position)>4 else towards.cross(Vector3.UP)
        elif player.position.distance_to(tank.position)>7:
            direction=player.position.direction_to(tank.position);direction.y=0
        # This is a normal steering target within the visible flat arena, not
        # a position clamp or teleport. Physics still decides where she moves.
        var next=player.position+direction.normalized()*2
        if absf(next.x)>8:direction.x=-signf(player.position.x)
        # Fight past the opened leaves, not in the narrow front vestibule.
        if next.z> -25.6:direction.z=-1
        elif next.z< -31:direction.z=1
        var local: Vector3=player.global_basis.inverse()*direction.normalized()
        for pair in [["l1_move_forward",-local.z],["l1_move_backward",local.z],["l1_move_left",-local.x],["l1_move_right",local.x]]:Input.action_press(pair[0],maxf(0,pair[1]))
        input_counts.movement_frames+=1
        await physics_frame;await capture_tick()
    release_movement();await settle(8)
    print("BOTANICAL INPUT: guardian recovery_windows=",boss_recoveries," hp=",player.get_hp()," mouse_shots=",group_shots.get("guardian",0))
    check(game.tank.defeated and stomp_seen and game.progress.guardian and boss_recoveries>=5,"two-phase combat did not require five distinct recovery windows")

func can_hit(guard: Node3D) -> bool:
    var target=guard.global_position+Vector3.UP*(1.15 if guard.is_tank else .9)
    var query=PhysicsRayQueryParameters3D.create(player.camera.global_position,target,1|2)
    query.collide_with_areas=true
    var hit=game.get_world_3d().direct_space_state.intersect_ray(query)
    return not hit.is_empty() and hit.collider==guard.hitbox

func follow_route(goal: Vector3) -> void:
    # Reuse the physically sampled production graph for the variable post-fight
    # position; every segment still runs through normal player movement.
    var route: PackedVector3Array=game.guard_navigation.path(player.position-Vector3.UP*.6,goal)
    check(not route.is_empty(),"no physical route from "+str(player.position)+" to "+str(goal)+" nodes="+str(game.guard_navigation._nearest(player.position-Vector3.UP*.6))+"/"+str(game.guard_navigation._nearest(goal)))
    for point in route:
        if Vector2(point.x-player.position.x,point.z-player.position.z).length()>1.0:await walk(point,.5)
    await walk(goal,.7)
func walk(goal: Vector3,arrival_radius: float=1.15) -> void:
    for i in range(2800):
        check(not game.mission_failed,"player defeated while walking to "+str(goal))
        var direction=goal-player.position;direction.y=0
        if direction.length()<arrival_radius:release_movement();return
        move(direction.normalized(),goal);await physics_frame;await capture_tick()
    push_error("BOTANICAL PLAYTHROUGH: blocked route to %s at %s"%[goal,player.position]);quit(1)
func move(direction: Vector3,goal: Vector3) -> void:
    var aiming=false
    for guard in game.guards:
        if not guard.is_tank and not guard.defeated and guard.encounter_active and guard.position.distance_to(player.position)<29 and can_hit(guard):
            player.look_at(Vector3(guard.position.x,player.position.y,guard.position.z));player.camera.look_at(guard.position+Vector3.UP*.9);fire(guard.encounter_group);aiming=true;break
    input_counts.movement_frames+=1
    if not aiming:player.look_at(Vector3(goal.x,player.position.y,goal.z));player.camera.rotation=Vector3.ZERO
    var local: Vector3=player.global_basis.inverse()*direction
    for pair in [["l1_move_forward",-local.z],["l1_move_backward",local.z],["l1_move_left",-local.x],["l1_move_right",local.x]]:Input.action_press(pair[0],maxf(0,pair[1]))
func release_movement() -> void:
    for action in ["l1_move_forward","l1_move_backward","l1_move_left","l1_move_right"]:Input.action_release(action)
func pulse(action: String) -> void:
    input_counts[action]=int(input_counts.get(action,0))+1
    var event=InputEventAction.new();event.action=action;event.pressed=true;Input.parse_input_event(event)
    var up=InputEventAction.new();up.action=action;Input.parse_input_event(up)
func interact() -> void:pulse("l1_interact")
func fire(group: String="guardian") -> void:
    if player.fire_cooldown>0 or player.ammo<=0:return
    input_counts.l1_fire+=1;shot_group=group
    # Woodland's desktop handler consumes actual mouse events, matching the
    # production left-button binding rather than a direct weapon invocation.
    var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=Vector2(root.size)*.5
    Input.parse_input_event(event)
    var up=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.position=event.position
    Input.parse_input_event(up)
func on_combat_event(kind: StringName,_point: Vector2) -> void:
    if kind==&"weapon_fired":shots+=1;group_shots[shot_group]=int(group_shots.get(shot_group,0))+1
    elif kind==&"weapon_hit":hits+=1
func on_audio_event(kind: StringName,_point: Vector3) -> void:
    var name_: String=str(kind)
    audio_events[name_]=int(audio_events.get(name_,0))+1
func source_hashes() -> Dictionary:
    var result: Dictionary={}
    for path in ["scripts/botanical_garden.gd","scripts/botanical_encounters.gd","scripts/botanical_encounter_director.gd","scripts/woodland_guard.gd","scripts/squirrel_3d_visual.gd","scripts/woodland_audio.gd","scripts/woodland_audio_bank.gd","scout_rigged.glb","assets/level1/characters/tank_squirrel.glb","assets/level1/characters/defeat149-contacts.json","tools/botanical_playthrough.gd","scripts/botanical_guard_navigation.gd","scripts/botanical_world.gd","scripts/botanical_collision150.gd","scripts/grounded_step_motion.gd","scripts/level1_player.gd","scripts/world_collision.gd"]:
        result[path]=FileAccess.get_sha256("res://"+path)
    return result
func validate_combat_lifecycle() -> void:
    check(float(gallery_extent.max_x)<-8.0,"western gallery group was towed into the central guardian plaza")
    for kind in ["squirrel_warn","squirrel_defeat","guardian_warn","guardian_attack","guardian_hit","guardian_defeat","encounter_entry","encounter_gallery","encounter_escape"]:
        check(int(audio_events.get(kind,0))>0,"fresh combat did not emit its production vocal fact: "+kind)
    check(not pump_reserves_before_install.get("installed",true),"pump reserve snapshot was not taken before physical installation")
    if int(pump_reserves_before_install.get("remaining",-1))>0:
        check(int(audio_events.get("encounter_pump",0))>0,"surviving pump reserves did not announce the repaired pump")
    else:
        var ids: Array=[]
        for actor in pump_reserves_before_install.get("actors",[]):
            ids.append(int(actor.id))
            check(bool(actor.defeated) and int(actor.hp)<=0,"silent pump cue hid a living reserve")
        ids.sort()
        check(ids==[12,13,14,15] and int(pump_reserves_before_install.get("remaining",-1))==0,"pre-install defeat evidence lacks all four pump reserves")
        check(int(audio_events.get("encounter_pump",0))==0,"already defeated pump reserves emitted a phantom order")
    check(int(audio_events.get("enemy_shoot",0))>0,"all mandatory groups were defeated without any actual enemy cone pressure")
    for id in [0,1,3,4,6,7,8,9,10,11,12,13,14,15,16,17,18,21,22,23,24]:
        check(defeat_evidence.has(str(id)) and int(defeat_evidence.get(str(id),{}).get("animated_frames",0))>0,"actual imported defeat clip did not animate for mandatory actor "+str(id))
func fight_group(id: String) -> void:
    var starting_hp: int=player.get_hp()
    var route_points:=PackedVector3Array()
    var route_cursor:=0
    var route_target_id:=-1
    var last_replan:=-120
    var route_revision:=-1
    for i in range(5400):
        check(not game.mission_failed,"player defeated during "+id)
        if game.encounter_director.is_complete(id):
            release_movement()
            encounter_evidence.append({"id":id,"hp_before":starting_hp,"hp_after":player.get_hp(),"shots":int(group_shots.get(id,0)),"at":[player.position.x,player.position.y,player.position.z],"remaining":game.encounter_director.remaining(id)})
            print("BOTANICAL INPUT: encounter=",id," hp=",player.get_hp()," mouse_shots=",group_shots.get(id,0)," position=",player.position)
            return
        var nearest: Node3D
        var distance:=INF
        for guard in game.guards:
            if guard.is_tank or guard.defeated or guard.encounter_group!=id:continue
            var d: float=player.position.distance_to(guard.position)
            if d<distance:nearest=guard;distance=d
        if nearest!=null:
            var direction: Vector3=player.position.direction_to(nearest.position);direction.y=0
            if can_hit(nearest) and distance<29:
                route_points.clear();route_cursor=0
                player.look_at(Vector3(nearest.position.x,player.position.y,nearest.position.z));player.camera.look_at(nearest.position+Vector3.UP*.9);fire(id)
                # Dodge locked projectile lanes with short real strafes.
                # Keep the arena traversal centred rather than circling cover.
                direction=direction.cross(Vector3.UP)*(1 if (i/36)%2==0 else -1) if distance<14 else Vector3.ZERO
                var next: Vector3=player.position+direction*2
                if next.z>58 or next.z< -31 or absf(next.x)>49:direction=Vector3.ZERO
                steer(direction)
            else:
                # Production shared collider graph chooses a physical route;
                # only input drives the player along it.
                # Consume earned graph waypoints in order. Re-selecting the
                # first point every frame reverses toward a node already behind
                # the player at its 1.2m radius, causing bridge oscillation.
                if route_points.is_empty() or route_target_id!=nearest.encounter_id or route_revision!=game.guard_navigation.revision or i-last_replan>=120:
                    route_points=game.guard_navigation.path(player.position-Vector3.UP*.6,nearest.position)
                    route_cursor=0;route_target_id=nearest.encounter_id;route_revision=game.guard_navigation.revision;last_replan=i
                while route_cursor<route_points.size() and Vector2(route_points[route_cursor].x-player.position.x,route_points[route_cursor].z-player.position.z).length()<.6:
                    route_cursor+=1
                var goal: Vector3=route_points[route_cursor] if route_cursor<route_points.size() else nearest.position
                move(((goal-player.position)*Vector3(1,0,1)).normalized(),goal)
        await physics_frame;await capture_tick()
    check(false,"encounter did not clear through normal input: "+id+" at "+str(player.position))
func steer(direction: Vector3) -> void:
    input_counts.movement_frames+=1
    var local: Vector3=player.global_basis.inverse()*direction.normalized()
    for pair in [["l1_move_forward",-local.z],["l1_move_backward",local.z],["l1_move_left",-local.x],["l1_move_right",local.x]]:Input.action_press(pair[0],maxf(0,pair[1]))
func capture_tick() -> void:
    tick+=1
    for actor in game.guards:
        if actor.encounter_group=="gallery" and actor.encounter_active and not actor.defeated:
            gallery_extent.max_x=maxf(float(gallery_extent.max_x),actor.position.x)
            gallery_extent.max_radius=maxf(float(gallery_extent.max_radius),Vector2(actor.position.x+27,actor.position.z+33).length())
        if actor.defeated:
            var visual=actor.visual
            var clip: String=str(visual.current_mode)
            if not clip.begins_with("death"):continue
            var key: String=str(actor.encounter_id)
            var row: Dictionary=defeat_evidence.get(key,{"clip":clip,"animated_frames":0,"max_action_time":0.0,"settled":false})
            if not visual.death_settled() and visual.action_time>0:row.animated_frames=int(row.animated_frames)+1
            row.max_action_time=maxf(float(row.max_action_time),visual.action_time);row.settled=visual.death_settled();defeat_evidence[key]=row
        elif actor.encounter_active and actor.state in ["aim","fire","melee","windup","charge","stomp_windup","shockwave"]:
            role_attacks[actor.tactical_role]=int(role_attacks.get(actor.tactical_role,0))+1
    if record_output.is_empty():return
    var due:=tick%120==0
    for actor in game.guards:
        if actor.defeated or not actor.encounter_active:continue
        if actor.state not in ["aim","fire","melee","windup","charge","stomp_windup","shockwave"]:continue
        var group: String=actor.encounter_group
        var key:=group+"_phase2" if actor.is_tank and actor.state in ["stomp_windup","shockwave"] else group
        if not captured_attack_groups.has(key):
            captured_attack_groups[key]=true;due=true
    if due:await capture()
func capture() -> void:
    if record_output.is_empty():return
    await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(record_output.path_join("frame-%04d.png"%frames))
    var states: Array[String]=[]
    for actor in game.guards:
        if actor.encounter_active and not actor.defeated:states.append(str(actor.encounter_id)+":"+actor.state)
    combat_samples.append({"frame":frames,"physics_tick":tick,"stage":game.stage,"player":[player.position.x,player.position.y,player.position.z],"hp":player.get_hp(),"ammo":player.ammo,"active_states":states,"shots_so_far":shots,"hits_so_far":hits})
    frames+=1
func force_draw() -> void:RenderingServer.force_draw(true)

func await_garden_ready(scene: Node3D) -> void:
    for frame in range(300):
        if scene.ready_for_play:return
        await physics_frame
    check(false,"production garden did not finish its collision-safe startup")

func await_scene(path: String) -> void:
    var deadline:=Time.get_ticks_msec()+30000
    while Time.get_ticks_msec()<deadline:
        if current_scene!=null and current_scene.scene_file_path==path and not root.get_node("SceneFlow")._transitioning:return
        await process_frame
    check(false,"normal-input scene transition did not become ready: "+path)
