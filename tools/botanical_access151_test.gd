extends SceneTree
## Explicit staged chapter outcomes isolate the key/lever rules. Physical
## doorway movement and all bypass sweeps use the production capsule/world.
const Fixture=preload("res://tools/botanical_fixture149.gd")
const State=preload("res://scripts/botanical_state.gd")
var game: Node3D
var failures: Array[String]=[]
var output:="user://botanical-access151"
var visual:=false
var report:={"cases":[],"captures":[],"source_hashes":{}}

func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument=="--visual":visual=true
        elif argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL ACCESS151: "+why)

func settle(count:=3) -> void:
    for index in range(count):await physics_frame

func at_lever() -> void:
    game.player.position=game.GATE_LEVER+Vector3(-1.4,.65,1.0)
    game.player.velocity=Vector3.ZERO;game.interact()

func cast_capsule(a: Vector3,b: Vector3) -> PackedFloat32Array:
    var query:=PhysicsShapeQueryParameters3D.new()
    query.shape=game.player.get_node("CollisionShape3D").shape
    query.transform=Transform3D(Basis.IDENTITY,a);query.motion=b-a;query.collision_mask=1;query.margin=.005
    return game.get_world_3d().direct_space_state.cast_motion(query)

func check_perimeter() -> void:
    var rows: Array=[]
    for index in range(16):
        var angle: float=(index+.5)*TAU/16
        var axis:=Vector3(cos(angle),0,sin(angle))
        var a:=Vector3(0,8.55,-35)+axis*14.5
        var b:=Vector3(0,8.55,-35)+axis*10.5
        var hit:=cast_capsule(a,b)
        check(hit.size()==2 and hit[0]<.99,"Locked dome can be entered through perimeter bay%d"%index)
        rows.append({"bay":index,"safe_fraction":hit[0] if hit.size()==2 else -1})
    report.cases.append({"case":"all_sixteen_physical_perimeter_bays","sweeps":rows,"actual_player_capsule":true})
    var patched: Array=[]
    for i in range(24):
        for j in range(10):
            if (i+j)%13!=0:continue
            var angle: float=(i+.5)*TAU/24;var phi: float=(j+.5)*PI*.5/10
            var point:=Vector3(cos(angle)*12.2*cos(phi),13.2+sin(phi)*7.3,-35+sin(angle)*12.2*cos(phi))
            var hit:=cast_capsule(point+Vector3.UP*3,point-Vector3.UP*3)
            check(hit.size()==2 and hit[0]<.99,"A formerly missing roof panel still admits a capsule: %d/%d"%[i,j])
            patched.append({"bay":i,"ring":j,"safe_fraction":hit[0] if hit.size()==2 else -1})
    report.cases.append({"case":"formerly_missing_roof_panels_block_drop_in","sweeps":patched})

func move_into_door(with_dash: bool,lane:=0.0) -> Vector3:
    game.player.position=Vector3(lane,7.63,-19)
    game.player.rotation=Vector3.ZERO;game.player.velocity=Vector3.ZERO
    Input.action_press("l1_move_forward")
    for index in range(100):
        if with_dash and index==50:game.player.dash_cooldown=0;game.player.request_dash()
        game.player._physics_process(1.0/60);game._physics_process(1.0/60)
        await physics_frame
    Input.action_release("l1_move_forward")
    var contacts: Array=[]
    for index in range(game.player.get_slide_collision_count()):
        var hit: KinematicCollision3D=game.player.get_slide_collision(index)
        contacts.append({"collider":str(hit.get_collider().get_path()),"position":str(hit.get_position()),"normal":str(hit.get_normal())})
    report.cases.append({"case":"doorway_motion_contacts","lane":lane,"dash":with_dash,"position":str(game.player.position),"contacts":contacts})
    return game.player.position

func capture(name_: String,where: Vector3,target: Vector3) -> void:
    if not visual:return
    var weapon_visible: bool=game.weapon.visible;game.weapon.hide()
    var camera:=Camera3D.new();camera.fov=65;game.add_child(camera);camera.global_position=where;camera.look_at(target);camera.make_current()
    for index in range(4):await draw()
    root.get_texture().get_image().save_png(output.path_join(name_+".png"));report.captures.append(name_+".png")
    game.player.camera.make_current();game.weapon.visible=weapon_visible;camera.queue_free();await process_frame

func draw() -> void:
    await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw
func force_draw() -> void:RenderingServer.force_draw(true)

func cold_load_case(opened: bool) -> void:
    State.clear()
    var raw:={"version":3,"parts":[true,false,false],"installed":true,"gate_unlatched":opened,"encounters_completed":["entry","pump_repair","pump","gallery"],"position":[5,7.7,-27],"hp":19,"ammo":2,"checkpoint_id":"pump","checkpoint_position":[23,3.7,21],"checkpoint_hp":44,"checkpoint_ammo":9,"checkpoint_defeated":[0,4],"checkpoint_supplies":[1]}
    FileAccess.open(State.PATH,FileAccess.WRITE).store_string(JSON.stringify(raw))
    game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    for index in range(300):
        if game.ready_for_play:break
        await physics_frame
    check(game.ready_for_play,"legacy access fixture startup timed out")
    game.set_physics_process(false);Fixture.freeze(game)
    if visual:await draw()
    check(game.player.get_hp()==19 and game.player.ammo==2 and game.progress.service_key,"legacy scene migration lost resources or its earned gallery key")
    if opened:
        check(game.water_flow.gate_open>.98 and game.player.position.z< -23,"earned legacy opening was reset or player moved outside")
        game._physics_process(1.0/60)
        check(game.stage=="cache" and game.progress.guardian_started,"an earned legacy player inside the dome still bypasses automatic guardian combat")
        report.cases.append({"case":"legacy_open_inside_restores_and_starts_guardian","position":str(game.player.position),"hp":game.player.get_hp(),"ammo":game.player.ammo,"stage":game.stage})
    else:
        check(game.water_flow.gate_open<.01 and game.player.position.z> -22.1 and game.stage!="cache","an unearned legacy interior save stayed behind locked doors")
        check(game.progress.checkpoint_id=="pump" and game.progress.checkpoint_position==Vector3(23,3.7,21) and game.progress.checkpoint_hp==44 and game.progress.checkpoint_ammo==9 and game.progress.checkpoint_defeated==[0,4] and game.progress.checkpoint_supplies==[1],"closed interior repair overwrote an independent valid retry")
        report.cases.append({"case":"legacy_closed_inside_repairs_only_position","position":str(game.player.position),"hp":game.player.get_hp(),"ammo":game.player.ammo,"independent_retry_preserved":true})
    game.queue_free();current_scene=null;game=null;await settle(5)

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    if visual:
        check(DisplayServer.get_name()!="headless","visual fixture needs a native framebuffer")
        root.size=Vector2i(1280,720);RenderingServer.set_render_loop_enabled(false)
    game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    for index in range(300):
        if game.ready_for_play:break
        await physics_frame
    check(game.ready_for_play,"garden never completed collision-safe startup")
    game.set_physics_process(false);Fixture.freeze(game);await settle(3)
    check_perimeter()
    for lane in [-1.35,0.0,1.35]:
        var stopped:=await move_into_door(true,lane)
        check(stopped.z> -21.95 and game.stage!="cache","Walk/dash bypassed the locked front doors or woke the guardian at lane%0.2f"%lane)
        report.cases.append({"case":"closed_front_walk_and_dash","lane":lane,"end":str(stopped),"guardian_started":game.progress.guardian_started})
    at_lever();await settle(170)
    check(not game.progress.service_key and not game.progress.gate_unlatched and game.water_flow.gate_open<.01,"Fresh lever worked without a gallery key")
    report.cases.append({"case":"unearned_lever_rejected"})
    Fixture.complete(game,"entry");Fixture.complete(game,"pump_repair");await settle(2)
    game.player.position=game.PART_POSITIONS[0]+Vector3(0,.65,1.5);game.interact()
    game.player.position=game.PANEL+Vector3(0,.65,1.5);game.interact()
    check(game.progress.installed,"Production fuse/pump actions failed during staged quest fixture")
    Fixture.complete(game,"pump");await settle(3)
    at_lever();await settle(170)
    check(not game.progress.gate_unlatched and game.water_flow.gate_open<.01,"Pump pressure opened the gate without a key")
    Fixture.complete(game,"gallery");await settle(170)
    check(game.progress.service_key and not game.progress.gate_unlatched and game.water_flow.gate_open<.01,"Gallery victory automatically opened the gate without its lever")
    report.cases.append({"case":"pump_and_gallery_do_not_replace_lever","key":game.progress.service_key,"gate_open":game.water_flow.gate_open})
    await capture("closed-keyed-entrance",Vector3(0,9.6,-15),Vector3(0,9.2,-25))
    await capture("key-slot-and-lever",Vector3(2.4,9,-18.5),game.GATE_LEVER+Vector3.UP*.8)
    game.player.health.current_health=37;game.player.ammo=6
    at_lever()
    check(await preload("res://tools/botanical_guide153_input.gd").acknowledge(self,game),"Earned gate tutorial could not be acknowledged through the real button")
    await settle(170)
    check(game.progress.gate_unlatched and game._garden_ready(),"Earned key did not turn the lever and open both real gates")
    check(game.player.get_hp()==37 and game.player.ammo==6 and game.progress.checkpoint_hp==37 and game.progress.checkpoint_ammo==6,"Gate lever secretly refilled resources")
    var checkpoint: String=game.progress.checkpoint_id
    at_lever();await settle(3)
    check(game.progress.checkpoint_id==checkpoint and game.player.get_hp()==37 and game.player.ammo==6,"Repeated lever use duplicated a checkpoint reward")
    check(game.water_flow.gate_body.position.y>3.5,"Inner store shutter did not follow the same earned opening")
    var halves: Array=game.water_flow.conservatory_access.gate_halves
    check(halves.size()==2 and absf(halves[0].rotation.y)>1.5 and absf(halves[1].rotation.y)>1.5,"Outer double doors never physically swung clear")
    report.cases.append({"case":"keyed_lever_opens_outer_and_inner_gate_once","key":true,"gate_open":game.water_flow.gate_open,"unchanged_hp":37,"unchanged_ammo":6})
    await capture("open-keyed-entrance",Vector3(0,9.6,-15),Vector3(0,9.2,-25))
    # The original stone mullion at x0/z−23 remains visible and solid. Both
    # real door lanes pass either side; do not steer into that retained column.
    for lane in [-1.35,1.35]:
        var reached:=await move_into_door(false,lane)
        check(reached.z< -23.0 and game.stage=="cache" and game.progress.guardian_started,"Crossing the open doorway did not automatically activate the mandatory guardian at lane%0.2f"%lane)
        report.cases.append({"case":"real_entry_starts_guardian_without_interact","lane":lane,"end":str(reached),"stage":game.stage})
    var interior: Array=[]
    for index in range(16):
        var angle: float=(index+.5)*TAU/16
        var point:=Vector3(cos(angle)*11.2,7.9,-35+sin(angle)*11.2)
        check(game._inside_guardian_arena(point),"Guardian activation has an interior perimeter blind spot%d"%index)
        interior.append(str(point))
    report.cases.append({"case":"whole_interior_is_guardian_trigger","points":interior})
    game.player.position=Vector3(0,7.9,-33.8);game.interact()
    check(not game.progress.reward,"An activated but undefeated guardian yielded the acorns")
    report.cases.append({"case":"guardian_victory_still_required_for_reward"})
    if visual:await draw()
    game.queue_free();current_scene=null;game=null;await settle(5)
    await cold_load_case(false);await cold_load_case(true);State.clear()
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if visual:
        for index in range(3):await draw()
        RenderingServer.set_render_loop_enabled(true)
    for path in ["scripts/botanical_garden.gd","scripts/botanical_state.gd","scripts/botanical_waterworks.gd","scripts/botanical_conservatory_access151.gd","scripts/botanical_guard_navigation.gd","tools/botanical_access151_test.gd"]:report.source_hashes[path]=FileAccess.get_sha256("res://"+path)
    report.failures=failures;report.scope="Staged chapter outcomes; actual input-driven capsule moves, physical all-bay/roof sweeps, keyed lever, automatic entry trigger and no reward before victory. Full unassisted quest combat is checked separately."
    FileAccess.open(output.path_join("access151-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if failures.is_empty():print("BOTANICAL ACCESS151: PASS — locked perimeter and roof, earned key, explicit lever, physical doors and mandatory guardian entry")
    quit(0 if failures.is_empty() else 1)
