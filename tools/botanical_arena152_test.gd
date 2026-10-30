extends "res://tools/botanical_ai152_test.gd"
## Actual authored conservatory collision/navigation. Actor placement, frozen
## unrelated guards and gate state are isolated fixture setup, not a claimed
## mission playthrough. Attacks, dodges, body motion and hits remain production.
var garden:Node3D
var _active_guard:Node3D

func run() -> void:
    Guard=load("res://scripts/woodland_guard.gd")
    var state=load("res://scripts/botanical_state.gd");state.clear()
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    root.size=Vector2i(1280,720);DirAccess.make_dir_recursive_absolute(output)
    if visual:RenderingServer.set_render_loop_enabled(false)
    garden=load("res://game.tscn").instantiate();root.add_child(garden);current_scene=garden
    for i in range(600):
        if garden.ready_for_play and garden.guard_navigation.is_ready:break
        await physics_frame
    check(garden.ready_for_play and garden.guard_navigation.is_ready,"actual garden/navigation never became ready")
    # Move the player out of contact only for the passive-post observation.
    garden.player.set_physics_process(false);garden.player.position=Vector3(80,.7,70)
    var before:Dictionary={}
    for actor in garden.guards:
        if not actor.encounter_active and not actor.defeated:before[actor.encounter_id]=actor.position
    await frames(90)
    var reserves:Array=[]
    for id in before:
        var actor=garden.guards[id]
        var moved:=Vector2(actor.position.x-before[id].x,actor.position.z-before[id].z).length()
        check(not actor.encounter_active and moved>.1,"actual reserve failed to patrol before contact: "+str(id))
        reserves.append({"id":id,"metres":moved,"encounter_active":actor.encounter_active})
    check(not garden.progress.installed and not garden.encounter_done("pump") and not garden.progress.service_key,"passive patrol observation earned repair or key progress")
    report.actual_reserve_patrols=reserves
    garden.set_process(false);garden.set_physics_process(false)
    for actor in garden.guards:actor.set_physics_process(false)
    # Supplied flags isolate collision behavior, not mission earning. Start
    # with the actually closed initial gate, then use its real opening motion.
    # The normal campaign driver separately earns prerequisites and boss health.
    garden.progress.installed=true;garden.progress.service_key=true;garden.progress.gate_unlatched=false
    garden._apply_garden_state();garden.stage="cache"
    await frames(60)
    var cases:Array=[]
    cases.append(await arena_case("staged-closed-outer-gate-robustness",Vector3(0,0,1),true))
    garden.progress.gate_unlatched=true;garden._apply_garden_state();await frames(220)
    for degrees in range(0,360,30):
        var angle:=deg_to_rad(float(degrees));var direction:=Vector3(sin(angle),0,cos(angle))
        cases.append(await arena_case("radial-%03d"%degrees,direction,false))
    cases.append(await actual_sill_overlap())
    report.actual_arena_cases=cases;report.failures=failures
    report.scope="Actual garden geometry/navigation with explicitly staged actors/gate and unrelated actors frozen; real movement/hits. Full mission/both-phase combat is a separate ordinary-input driver."
    report.source_hashes={}
    for path in ["res://scripts/woodland_guard.gd","res://scripts/botanical_encounter_director.gd","res://scripts/botanical_encounters.gd","res://scripts/botanical_guard_navigation.gd","res://scripts/botanical_garden.gd","res://scripts/botanical_world.gd","res://scripts/botanical_world151.gd","res://scripts/botanical_layout.gd","res://scripts/botanical_collision150.gd","res://scripts/botanical_conservatory_access151.gd","res://tools/botanical_ai152_test.gd","res://tools/botanical_arena152_test.gd"]:
        report.source_hashes[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
    current_scene=null;garden.queue_free();await frames(5)
    state.clear();await Teardown.drain_audio(self);RenderingServer.set_render_loop_enabled(true)
    FileAccess.open(output.path_join("arena152-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if failures.is_empty():print("BOTANICAL ARENA152: PASS — actual reserve posts, twelve radial conservatory contacts, closed gate, staged existing sill overlap, supported body escape, real hits and renewed attacks")
    quit(0 if failures.is_empty() else 1)

func clear_guard_point(point:Vector3) -> bool:
    return point.is_finite() and garden.guard_navigation._open(point,true)

func replace_guard(at:Vector3) -> Node3D:
    var old=garden.tank;old.queue_free();await frames(3)
    var actor=Guard.new();actor.name="ActualArenaGuardian";actor.director=garden;actor.is_tank=true;actor.final_boss=true
    actor.encounter_id=3;actor.encounter_group="guardian";actor.tactical_role="guardian"
    actor.position=at+Vector3.UP*.025;garden.add_child(actor);garden.guards[3]=actor;garden.tank=actor;_active_guard=actor
    actor.visual.scale=Vector3.ONE*.88
    return actor

func stage_player(point:Vector3,look_at:Vector3) -> void:
    garden.player.set_physics_process(false);garden.player.position=point+Vector3.UP*.578
    garden.player.velocity=Vector3.ZERO;garden.player.input_enabled=true
    garden.player.look_at(Vector3(look_at.x,garden.player.position.y,look_at.z))
    garden.player.camera.look_at(look_at+Vector3.UP)
    garden.player.set_physics_process(true)

func arena_case(name_:String,direction:Vector3,closed:bool) -> Dictionary:
    var origin:=Vector3.INF;var target:=Vector3.INF
    if closed:
        # The original central column stands at (0,-23), before the door.
        # Use the real right-hand door lane and identify its collider below;
        # a stop on that column cannot count as a closed-gate regression.
        origin=garden.guard_navigation.ground_goal(Vector3(1.5,7,-25.5))
        target=garden.guard_navigation.ground_goal(Vector3(1.5,7,-23.5))
        if not clear_guard_point(origin) or not garden.guard_navigation._open(target,false):origin=Vector3.INF;target=Vector3.INF
    else:
        for radius in [7.5,8.0,8.5,9.0]:
            var a:Vector3=garden.guard_navigation.ground_goal(Vector3(0,7,-35)+direction*radius)
            var b:Vector3=garden.guard_navigation.ground_goal(Vector3(0,7,-35)+direction*(radius+1.5))
            if clear_guard_point(a) and b.is_finite() and garden.guard_navigation._open(b,false):origin=a;target=b;break
    check(origin.is_finite() and target.is_finite(),name_+": no clear supported authored start/target")
    if not origin.is_finite() or not target.is_finite():return {"case":name_,"missing_clear_setup":true}
    garden.player.set_physics_process(false)
    var actor=await replace_guard(origin)
    stage_player(target,origin)
    if not await wait_state(actor,"windup",180):return {"case":name_,"failed_start":true}
    var charge_start:Vector3=actor.position
    var first:int=actor._attack_count;var hp:int=garden.player.get_hp()
    Input.action_press("l1_move_right");await frames(52);Input.action_release("l1_move_right")
    var predicted_stop:Dictionary=await wait_recovery_contact(actor,180)
    var contact:Vector3=actor.position
    var contact_navigation_open:bool=clear_guard_point(garden.guard_navigation.ground_goal(contact))
    var actual_gate_stop:=false
    for hit:Dictionary in predicted_stop.get("contacts",[]):
        if hit.gate_meta:actual_gate_stop=true
    if closed:check(actual_gate_stop,name_+": charge stopped without the actual keyed door RID in its blocking sweep")
    await frames(22)
    var point:Vector3=garden.guard_navigation.ground_goal(actor.position)
    var physical_clear:bool=physical_recovery_clear(actor)
    check(clear_guard_point(point),name_+": recovered actual boss cannot attach to tank navigation")
    check(physical_clear,name_+": recovery capsule lacks actual world clearance or floor support")
    check(garden.player.get_hp()==hp,name_+": input dodge did not clear the announced lane")
    check(actor._charge_wall_stops>0,name_+": charge never reached real authored arena geometry")
    # This artificial closed-door robustness probe may already stop at legal
    # navigation clearance in a narrow vestibule. Only that fixture may remain
    # there without backoff, with independently clear capsule/support/hit/attack.
    # Every normal open-arena wall contact must physically move away.
    if actor._charge_wall_stops>0:
        if closed and actor._charge_backoff_metres<=.12:check(contact_navigation_open and physical_clear,name_+": zero-backoff door stop lacks original clearance/support")
        else:check(actor._charge_backoff_metres>.12,name_+": real arena blocker left boss without physical backoff")
    if closed:check(actor._charge_wall_stops>0,name_+": closed outer gate did not stop charge")
    var before_hp:int=actor.hp
    garden.player.camera.look_at(actor.position+Vector3.UP*1.1);garden.player.request_fire();await frames(3)
    check(actor.hp==before_hp-1,name_+": actual recovery window rejected a real weapon hit")
    var pursuit_budget:Dictionary=next_attack_budget(actor)
    await wait_state(actor,"windup",pursuit_budget.frames)
    check(actor._attack_count>first,name_+": actual arena guardian did not resume attacks")
    await capture_arena(name_,actor)
    var row:Dictionary={"case":name_,"authored_stage_origin":origin,"charge_start_after_stalk":charge_start,"target":target,"contact":contact,"contact_tank_navigation_open":contact_navigation_open,"end":actor.position,"wall_stops":actor._charge_wall_stops,"backoff_metres":actor._charge_backoff_metres,"tank_navigation_open":clear_guard_point(point),"recovery_physical_clear":physical_clear,"real_recovery_hit":actor.hp==before_hp-1,"next_attack_count":actor._attack_count,"next_attack_budget":pursuit_budget,"gate_closed_fixture":closed,"predicted_stop":predicted_stop,"actual_gate_rid_blocked_charge":actual_gate_stop}
    actor.set_physics_process(false);garden.player.set_physics_process(false)
    return row

func physical_recovery_clear(actor:Node3D) -> bool:
    var query:=PhysicsShapeQueryParameters3D.new();query.shape=actor.body_shape.shape
    query.transform=actor.body_shape.global_transform;query.transform.origin+=Vector3.UP*.06
    query.margin=.008;query.collision_mask=actor.collision_mask;query.exclude=[actor.get_rid()]
    var space:=garden.get_world_3d().direct_space_state
    if not space.intersect_shape(query,1).is_empty():return false
    var ray:=PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*.3,actor.position-Vector3.UP*.3,1)
    ray.exclude=[actor.get_rid()]
    var floor:Dictionary=space.intersect_ray(ray)
    return not floor.is_empty() and floor.normal.y>=cos(actor.floor_max_angle) and absf(floor.position.y-actor.position.y)<.15 and str(floor.collider.name)!="PondWaterVolume" and bool(floor.collider.get_meta("walkable_support",true))

func wait_recovery_contact(actor:Node3D,limit:int) -> Dictionary:
    var last_stop:Dictionary={}
    for i in range(limit):
        if actor.state=="recover":return last_stop
        if actor.state=="charge":
            var observed:Dictionary=observe_charge_blocker(actor)
            if not observed.is_empty():last_stop=observed
        await physics_frame
    check(false,"actual arena guardian did not recover (actual "+str(actor.state)+")")
    return last_stop

func stop_collider_record(collider:Object,rid:RID,normal:Vector3) -> Dictionary:
    return {"collider":str(collider.get_path()) if collider is Node else str(collider),"rid":rid.get_id(),"normal":normal,"gate_meta":is_instance_valid(collider) and bool(collider.get_meta("conservatory_gate151",false))}

func observe_charge_blocker(actor:Node3D) -> Dictionary:
    # Read the exact production prediction at this paused-before-physics pose.
    # Repeating its non-mutating server query exposes the actual stopping RID;
    # mere spatial proximity to a door would mislabel a nearby column stop.
    var motion:Vector3=actor._charge_direction*(10.0/60.0)
    var production:Dictionary=actor._charge_wall_sweep(motion)
    if not production.blocked:return {}
    var query:=PhysicsShapeQueryParameters3D.new();query.shape=actor.body_shape.shape
    query.transform=actor.body_shape.global_transform;query.transform.origin+=Vector3.UP*.06
    query.margin=.045;query.collision_mask=actor.collision_mask;query.exclude=[actor.get_rid()]
    var rest:Dictionary=garden.get_world_3d().direct_space_state.get_rest_info(query)
    if not rest.is_empty() and absf(rest.normal.y)<.65:
        return {"pose":actor.position,"query":"production_initial_rest","contacts":[stop_collider_record(instance_from_id(rest.collider_id),rest.rid,rest.normal)]}
    var parameters:=PhysicsTestMotionParameters3D.new();parameters.from=actor.global_transform
    parameters.from.origin+=Vector3.UP*.06;parameters.motion=motion;parameters.margin=.045
    parameters.max_collisions=8;parameters.recovery_as_collision=true
    var result:=PhysicsTestMotionResult3D.new();var contacts:Array=[]
    if PhysicsServer3D.body_test_motion(actor.get_rid(),parameters,result):
        for i in range(result.get_collision_count()):
            var normal:=result.get_collision_normal(i)
            if absf(normal.y)<.65:contacts.append(stop_collider_record(result.get_collider(i),result.get_collider_rid(i),normal))
    return {"pose":actor.position,"query":"production_body_sweep","contacts":contacts,"predicted_distance":production.distance}

func world_overlap(point:Vector3,shape:Shape3D) -> bool:
    var q:=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.collision_mask=1
    q.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*1.025)
    if is_instance_valid(_active_guard):q.exclude=[_active_guard.get_rid()]
    return not garden.get_world_3d().direct_space_state.intersect_shape(q,8).is_empty()

func actual_sill_overlap() -> Dictionary:
    var direction:=Vector3(cos(PI/16),0,sin(PI/16))
    var center:=Vector3(0,7,-35)
    var origin:Vector3=garden.guard_navigation.ground_goal(center+direction*8)
    check(clear_guard_point(origin),"actual sill overlap lacks a clear initial actor point")
    var actor=await replace_guard(origin)
    var target:Vector3=garden.guard_navigation.ground_goal(center+direction*6)
    stage_player(target,origin)
    await wait_state(actor,"charge",240)
    actor.set_physics_process(false)
    var boundary:=-1.0
    for i in range(220):
        var radius:=8+float(i)*.02
        var point:=center+direction*radius;point.y=origin.y+.025
        if world_overlap(point,actor.body_shape.shape):boundary=radius;break
    check(boundary>8,"actual radial sill body was not found")
    if boundary<=8:actor.set_physics_process(true);return {"case":"actual-sill-overlap","setup_failed":true}
    var lower:float=boundary-.02;var upper:float=boundary
    for i in range(12):
        var middle:float=(lower+upper)*.5
        var probe:=center+direction*middle;probe.y=origin.y+.025
        if world_overlap(probe,actor.body_shape.shape):upper=middle
        else:lower=middle
    boundary=upper
    actor.position=center+direction*(boundary+.02);actor.position.y=origin.y+.025;actor.velocity=Vector3.ZERO
    var overlap_start:Vector3=actor.position
    var actual_overlap:=world_overlap(actor.position,actor.body_shape.shape)
    check(actual_overlap,"actual existing shallow world overlap was not staged")
    var sweep:Dictionary=actor._charge_wall_sweep(actor._charge_direction/6)
    check(sweep.blocked,"actual initial world recovery contact was omitted from sweep")
    actor.set_physics_process(true)
    await wait_state(actor,"recover",160);await frames(22)
    var point:Vector3=garden.guard_navigation.ground_goal(actor.position)
    var radial_backoff:float=(actor.position-overlap_start).dot(direction)
    var original_side:bool=radial_backoff<-.1
    var physical_clear:bool=physical_recovery_clear(actor)
    check(original_side,"actual initial world overlap escaped through to the opposite wall side")
    check(actor._charge_backoff_metres>.12 and clear_guard_point(point),"actual initial world overlap never recovered a physically clear route start")
    check(physical_clear,"actual initial world overlap lacks actual capsule clearance or floor support")
    var before_hp:int=actor.hp;garden.player.camera.look_at(actor.position+Vector3.UP*1.1);garden.player.request_fire();await frames(3)
    check(actor.hp==before_hp-1,"actual initial overlap recovery was not vulnerable")
    var first:int=actor._attack_count;var pursuit_budget:Dictionary=next_attack_budget(actor)
    await wait_state(actor,"windup",pursuit_budget.frames)
    check(actor._attack_count>first,"actual initial overlap never resumed attack cycle")
    await capture_arena("actual-sill-overlap",actor)
    return {"case":"actual-sill-overlap","staged_initial_overlap":actual_overlap,"boundary_radius":boundary,"staged_radial_depth_metres":.02,"overlap_initial_position":overlap_start,"radial_backoff_metres":radial_backoff,"original_side_preserved":original_side,"backoff_metres":actor._charge_backoff_metres,"tank_navigation_open":clear_guard_point(point),"recovery_physical_clear":physical_clear,"real_recovery_hit":actor.hp==before_hp-1,"next_attack_count":actor._attack_count,"next_attack_budget":pursuit_budget}

func next_attack_budget(actor:Node3D) -> Dictionary:
    # An open doorway can let the complete charge end beyond the threshold.
    # Allow the measured physical route home at the production1.85m/s stalk
    # speed, plus recovery/cooldown, rather than inventing an instant attack.
    var route:PackedVector3Array=garden.guard_navigation.path(actor.position,garden.player.position,true)
    var metres:=0.0
    for i in range(1,route.size()):metres+=route[i-1].distance_to(route[i])
    return {"route_metres":metres,"route_points":route.size(),"frames":clampi(ceili((metres/1.85+3.0)*60),360,1200),"maximum_seconds":20.0}

func capture_arena(name_:String,actor:Node3D) -> void:
    if not visual:return
    # Use the physically reached player viewpoint, not a spectator camera that
    # can accidentally stand outside the glass and hide the repaired contact.
    garden.player.camera.look_at(actor.position+Vector3.UP*1.1)
    garden.player.camera.make_current()
    for i in range(3):await process_frame;RenderingServer.force_draw(true)
    root.get_texture().get_image().save_png(output.path_join(name_+".png"))
