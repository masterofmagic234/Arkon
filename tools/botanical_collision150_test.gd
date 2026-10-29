extends SceneTree
## Staged component fixture. Starting poses/chapter completion are explicit;
## every traversal uses production InputMap motion and swept projectiles.
const Fixture=preload("res://tools/botanical_fixture149.gd")
const State=preload("res://scripts/botanical_state.gd")
const SOURCES=["scripts/botanical_world.gd","scripts/botanical_world151.gd","scripts/botanical_layout.gd","scripts/botanical_collision150.gd","scripts/world_collision.gd","scripts/botanical_garden.gd","scripts/botanical_state.gd","scripts/botanical_waterworks.gd","scripts/botanical_conservatory_access151.gd","scripts/botanical_mission_routes.gd","scripts/grounded_step_motion.gd","scripts/level1_player.gd","scripts/woodland_guard.gd","scripts/botanical_guard_navigation.gd","tools/botanical_collision150_test.gd"]
var game: Node3D
var player: Node3D
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
var output:=""
var movement_frames:=0
var captures: Array[String]=[]
var actual_garden_draws:=0
var gate_fixture: Dictionary={}

func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL COLLISION150: "+why)

func v(point: Vector3) -> Array:return [point.x,point.y,point.z]
func settle(count:=12) -> void:
    for i in range(count):await physics_frame
func release() -> void:
    for action in ["l1_move_forward","l1_move_backward","l1_move_left","l1_move_right"]:Input.action_release(action)

func place(at: Vector3) -> void:
    release();player.position=at;player.velocity=Vector3.ZERO;await settle(12)

func ray(from: Vector3,to: Vector3) -> Dictionary:
    return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))

func force_draw() -> void:RenderingServer.force_draw(true)
func capture_view(id: String,at: Vector3,target: Vector3) -> void:
    if DisplayServer.get_name()=="headless" or output.is_empty():return
    await place(at);player.look_at(Vector3(target.x,player.position.y,target.z));player.camera.look_at(target)
    await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw
    var path=output.path_join(id+".png");get_root().get_texture().get_image().save_png(path);captures.append(path)

func floor_case(id: String,at: Vector3,expected: float) -> void:
    var hit=ray(at+Vector3.UP*.4,at-Vector3.UP*2)
    check(not hit.is_empty() and absf(hit.position.y-expected)<.004,id+" has no support at the actual visible top")
    cases.append({"case":id,"kind":"actual_support_ray","expected_y":expected,"actual":v(hit.get("position",Vector3.ZERO)),"body":str(hit.collider.name) if not hit.is_empty() else "none"})

func travel(id: String,at: Vector3,goal: Vector3,frames:=240,dash:=false) -> Dictionary:
    await place(at)
    var start: Vector3=player.position;var furthest=start;var contacts={};var minimum_clearance:=INF
    var arrived=false
    for i in range(frames):
        var direction=goal-player.position;direction.y=0
        if direction.length()<.28:arrived=true;break
        player.look_at(player.position+direction.normalized());player.camera.rotation=Vector3.ZERO
        Input.action_press("l1_move_forward",1.0)
        if dash and i%190==30:player.request_dash()
        movement_frames+=1;await physics_frame;furthest=player.position
        for index in range(player.get_slide_collision_count()):
            var object=player.get_slide_collision(index).get_collider()
            if object!=null:contacts[str(object.name)]=true
        if player.is_on_floor():
            var support=ray(player.position+Vector3.UP*.05,player.position-Vector3.UP*.8)
            if not support.is_empty():minimum_clearance=minf(minimum_clearance,player.position.y-.6-support.position.y)
    release();await settle(4)
    var shape=player.get_node("CollisionShape3D")
    var record={"case":id,"kind":"production_input_motion","start":v(start),"goal":v(goal),"end":v(furthest),"arrived":arrived,"dash":dash,"capsule_radius":shape.shape.radius,"capsule_height":shape.shape.height,"capsule_offset":v(shape.position),"contacts":contacts.keys(),"minimum_grounded_foot_clearance":minimum_clearance if is_finite(minimum_clearance) else null}
    cases.append(record);return record

func projectile_case(id: String,from: Vector3,to: Vector3,maximum_travel: float) -> void:
    var result={"case":id,"kind":"production_swept_cone","from":v(from),"to":v(to),"hit_wall":false,"finished":false}
    var projectile=load("res://scripts/woodland_cone_projectile.gd").new();game.add_child(projectile);projectile.setup(from,to,game.tank)
    projectile.tree_exiting.connect(func():result.hit_wall=projectile.hit_wall;result.finished=true;result.travelled=projectile.travelled;result.position=v(projectile.position))
    for i in range(100):
        await physics_frame
        if result.finished:break
    check(result.finished and result.hit_wall and float(result.get("travelled",100))<maximum_travel,id+" passed through its visible blocker")
    cases.append(result)

func inventory_cases() -> Dictionary:
    var builder=game.world.collision_geometry
    var summary=builder.summary();check(int(summary.records)>500,"authored solid inventory is incomplete")
    check(summary.transform_authority=="authored_CPU_put_transforms" and int(summary.authored_instance_count)>int(summary.records),"collision did not consume authored CPU transforms")
    check(int(summary.categories.get("world/box/glass",0))==34,"expected all34 main/wing glass panels")
    check(int(summary.categories.get("world/cliff/cliff",0))==12,"expected all12 rock-garden cliffs")
    var samples=0;var hits=0;var misses=[];var treads=0
    for record in builder.records:
        var point: Vector3=record.sample;var normal: Vector3=record.normal
        var hit=ray(point+normal*.025,point-normal*.025);samples+=1
        if not hit.is_empty():hits+=1
        else:misses.append(record.label)
        var bounds: AABB=record.bounds
        if record.category=="world/box/trim" and absf(bounds.size.y-.16)<.001 and bounds.size.x>=11 and bounds.size.z<1:
            treads+=1
            var center=bounds.get_center()
            # Lower flights remain clear at their centers; the bridge covers
            # the center of the first central treads, so sample their open side.
            if absf(center.x)<10:center.x+=bounds.size.x*.3
            center.z+=bounds.size.z*.32
            floor_case("tread_%03d"%treads,Vector3(center.x,bounds.end.y+.05,center.z),bounds.end.y)
    check(treads==110,"not all110 actual stair treads were inventoried")
    check(hits==samples,"authored face rays missed registered surfaces: "+str(misses.slice(0,12)))
    summary.face_rays={"samples":samples,"hits":hits,"misses":misses};summary.actual_treads=treads
    return summary

func hidden_prop_cases() -> void:
    Fixture.complete(game,"entry");Fixture.complete(game,"pump_repair")
    var before=ray(Vector3(28,3.35,10.4),Vector3(28,3.35,11.6))
    check(not before.is_empty(),"visible fuse crate has no physical body")
    await place(Vector3(28,3.7,12.4));game.interact();await settle(3)
    var after=ray(Vector3(28,3.35,10.4),Vector3(28,3.35,11.6))
    check(game.progress.parts[0] and after.is_empty(),"picked-up fuse left an invisible collider")
    cases.append({"case":"fuse_visibility_lifecycle","kind":"real_interaction_and_rays","visible_hit":not before.is_empty(),"hidden_hit":not after.is_empty()})
    var supply=game.supplies[0];player.health.current_health=30;player.ammo=1
    var supply_point: Vector3=supply.position+Vector3.UP*.25
    before=ray(supply_point-Vector3.RIGHT,supply_point+Vector3.RIGHT)
    await place(supply.position+Vector3(0,.65,.85));game.set_physics_process(true);await settle(3);game.set_physics_process(false)
    after=ray(supply_point-Vector3.RIGHT,supply_point+Vector3.RIGHT)
    check(supply.get_meta("used",false) and not supply.visible and after.is_empty(),"used supply left an invisible collider")
    cases.append({"case":"supply_visibility_lifecycle","kind":"actual_proximity_pickup_and_rays","visible_hit":not before.is_empty(),"hidden_hit":not after.is_empty()})
    game.progress.guardian=true;game.progress.installed=true;game.progress.gate_unlatched=true;game._apply_garden_state();await settle(170)
    before=ray(Vector3(-1,8.89,-36.18),Vector3(1,8.89,-36.18))
    await place(Vector3(0,7.9,-33.2));game.interact();await settle(3)
    after=ray(Vector3(-1,8.89,-36.18),Vector3(1,8.89,-36.18))
    check(game.progress.reward and after.is_empty(),"collected acorns left an invisible collider")
    cases.append({"case":"reward_visibility_lifecycle","kind":"real_interaction_and_rays","visible_hit":not before.is_empty(),"hidden_hit":not after.is_empty()})

func spawn_cases() -> void:
    var state=State.new();state.reward=true;state.guardian=true;state.position=Vector3(0,7.65,-36);state.hp=23;state.ammo=2;state.save()
    var loaded=State.new();loaded.load_save()
    check(loaded.reward and loaded.guardian and loaded.gate_unlatched and loaded.hp==23 and loaded.ammo==2 and loaded.position==Vector3(0,7.7,-31.5),"pedestal load repair lost earned progress/resources or kept invalid position")
    var capsule=player.get_node("CollisionShape3D").shape as CapsuleShape3D
    var shape_offset: Vector3=player.get_node("CollisionShape3D").position
    var space=game.get_world_3d().direct_space_state
    var positions=[Vector3(23,3.6,16),Vector3(17,.6,52),Vector3(0,7.65,-36)]
    var inside_rock=false
    for record in game.world.collision_geometry.records:
        if record.category!="world/cliff/cliff":continue
        var center: Vector3=record.bounds.get_center()
        var at=Vector3(center.x,game.world.surface_height_at(center.x,center.z)+.62,center.z)
        var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,at+shape_offset);query.margin=0;query.collision_mask=1
        if not space.intersect_shape(query,1).is_empty():continue
        query.collision_mask=64
        if space.intersect_shape(query,1).is_empty():continue
        positions.append(at);inside_rock=true;break
    check(inside_rock,"missing fully enclosed rock spawn case that requires the load-only convex query")
    for at in positions:
        var repaired=WorldCollision.restore_clear_position(space,at,capsule,shape_offset)
        var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1|64;query.transform=Transform3D(Basis.IDENTITY,repaired+shape_offset);query.margin=0
        check(space.intersect_shape(query,1).is_empty() and repaired.distance_to(at)<6,"load-only capsule repair did not find bounded free support")
        cases.append({"case":"load_clearance","kind":"actual_capsule_and_floor_queries","before":v(at),"after":v(repaired),"radius":capsule.radius,"height":capsule.height,"offset":v(shape_offset),"fully_inside_rock":inside_rock and at==positions[-1]})

func rock_cases() -> void:
    for record in game.world.collision_geometry.records:
        if record.category!="world/cliff/cliff":continue
        var bounds: AABB=record.bounds;var center=bounds.get_center()
        var start=Vector3(center.x,game.world.surface_height_at(center.x,bounds.end.z+1)+.7,bounds.end.z+1)
        for dash in [false,true]:
            var result=await travel("rock_dash" if dash else "rock_walk",start,Vector3(center.x,start.y,center.z-2),180,dash)
            check(not result.arrived and float(result.end[2])>center.z+.5,"production player passed through the large visible rock")
        return

func headroom_case() -> void:
    var body=StaticBody3D.new();body.name="FixtureLowCeiling150";body.collision_layer=1;body.position=Vector3(40,1.5,55);game.add_child(body)
    var shape=BoxShape3D.new();shape.size=Vector3(3,.2,2);var collider=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);await settle(2)
    var result=await travel("actual_player_rejects_1_4m_headroom",Vector3(40,.7,58),Vector3(40,.7,52),180)
    check(not result.arrived and float(result.end[2])>56.1 and result.capsule_height>=1.7,"production garden player's eyes can pass through a1.4m ceiling")
    body.queue_free();await settle(2)

func run() -> void:
    if DisplayServer.get_name()!="headless":
        root.size=Vector2i(1280,720);RenderingServer.set_render_loop_enabled(false)
    if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
    root.get_node("GameState").start_new_run();root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    change_scene_to_file("res://game.tscn")
    for i in range(120):
        await physics_frame
        if current_scene!=null and current_scene.get("ready_for_play")==true:break
    game=current_scene;player=game.player;game.set_physics_process(false)
    for guard in game.guards:guard.set_physics_process(false)
    await settle(5)
    if DisplayServer.get_name()!="headless":
        for i in range(2):
            await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw
            actual_garden_draws+=1
    var inventory=inventory_cases()
    var parity=game.world.collision_geometry.rendered_transform_parity(game.world)
    if parity.available:check(parity.mismatches.is_empty() and parity.active_gpu_mismatches.is_empty() and parity.checked==inventory.authored_instance_count,"native rendered hard-instance transforms differ from collision CPU source")
    floor_case("conservatory_disc",Vector3(0,8,-30),7.26)
    floor_case("pavilion_disc",Vector3(47,13,-79),12.30)
    floor_case("planting_bed_top",Vector3(17,1,52),.7)
    floor_case("wall_coping",Vector3(-20,7.5,-14.45),7.24)
    var closed=ray(Vector3(-29.8,9.1,-28),Vector3(-29.8,9.1,-30));check(not closed.is_empty(),"west gallery glass is not physical")
    cases.append({"case":"glass_panel","kind":"physical_ray","hit":not closed.is_empty(),"body":str(closed.collider.name) if not closed.is_empty() else "none"})
    for dash in [false,true]:
        var bed=await travel("bed_dash" if dash else "bed_walk",Vector3(17,.7,56),Vector3(17,.7,48),180,dash)
        check(not bed.arrived and float(bed.end[2])>54.6,"player crossed the .7m stone bed")
        var pot=await travel("pot_dash" if dash else "pot_walk",Vector3(23,3.7,18.3),Vector3(23,3.7,13),180,dash)
        check(not pot.arrived and float(pot.end[2])>16.7,"player crossed the pump-side pot")
    await rock_cases();await headroom_case()
    var stairs=await travel("central_actual_treads_up",Vector3(4,3.7,13),Vector3(4,7.9,-16),600)
    check(stairs.arrived and float(stairs.minimum_grounded_foot_clearance)>-.015,"real stair ascent blocked or feet sank below treads")
    # This component fixture checks an open threshold. The dedicated access151
    # fixture separately proves the keyed lever and closed-gate restrictions.
    game.progress.installed=true;game.progress.service_key=true;game.progress.gate_unlatched=true;game._apply_garden_state()
    await settle(170)
    gate_fixture={"staged_earned_opening":true,"key":game.progress.service_key,"gate_unlatched":game.progress.gate_unlatched,"physical_gate_open_ratio":game.water_flow.gate_open,"scope":"Only physical entrance stairs are isolated here; access151 independently tests the closed keyed entrance."}
    var entry=await travel("conservatory_step_in",Vector3(1.25,7.7,-20),Vector3(1.25,7.9,-27),240)
    check(entry.arrived,"physical conservatory entrance/half-step is not traversable")
    var exit=await travel("conservatory_step_out",Vector3(1.25,7.9,-27),Vector3(1.25,7.7,-20),240)
    check(exit.arrived,"conservatory exit is blocked")
    var pavilion=await travel("pavilion_west_step_in",Vector3(36,12.7,-78),Vector3(39.2,12.9,-78),180)
    check(pavilion.arrived,"grounded west pavilion half-step is not traversable")
    var pavilion_out=await travel("pavilion_west_step_out",Vector3(39.2,12.9,-78),Vector3(36,12.7,-78),180)
    check(pavilion_out.arrived,"west pavilion exit is blocked")
    await place(Vector3(0,.7,65))
    await projectile_case("cone_stops_at_glass",Vector3(-29.8,9.1,-28),Vector3(-29.8,9.1,-31),1.5)
    await projectile_case("cone_stops_at_bed",Vector3(17,.35,56),Vector3(17,.35,50),2)
    var car=ray(Vector3(-3,1,71),Vector3(3,1,71));check(not car.is_empty() and str(car.collider.name)=="ParkedCarCollision150","parked car has no physical body")
    cases.append({"case":"parked_car","kind":"physical_ray","body":str(car.collider.name) if not car.is_empty() else "none"})
    await hidden_prop_cases();spawn_cases()
    await capture_view("bed",Vector3(11,.7,55),Vector3(17,.6,52))
    await capture_view("pot",Vector3(20,3.7,19),Vector3(23,3.7,16))
    await capture_view("glass",Vector3(-29.8,7.7,-26),Vector3(-29.8,9.1,-29))
    await capture_view("pavilion",Vector3(36,12.7,-77),Vector3(38,12.15,-78))
    await capture_view("car",Vector3(-2.5,.7,68),Vector3(0,1,71))
    var hashes={}
    for path in SOURCES:hashes[path]=FileAccess.get_sha256("res://"+path)
    var result={"failures":failures,"source_hashes":hashes,"engine":Engine.get_version_info().string,"native":DisplayServer.get_name()!="headless","inventory":inventory,"rendered_transform_parity":parity,"captures":captures,"cases":cases,"movement_frames":movement_frames,"gate_fixture":gate_fixture,"scope":"Staged isolated component fixture using current authored collision surfaces, production input/gravity/swept steps and actual cone projectiles. Version151 adds closed stair foundations/landings, rear-rock escape bank, stair-ribbon cutouts and a real vehicle gateway. Explicit decorative exclusions and car/legacy trunk/bench proxies are not claimed as complete mesh collision."}
    release();game.queue_free();current_scene=null;await settle();await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    game=null;player=null
    var empty_draws:=0
    if DisplayServer.get_name()!="headless":
        for i in range(3):
            await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw
            empty_draws+=1
    result.teardown={"actual_garden_draws":actual_garden_draws,"empty_viewport_draws":empty_draws,"fixture_references_released":true,"audio_drained":true}
    if not output.is_empty():
        DirAccess.make_dir_recursive_absolute(output)
        FileAccess.open(output.path_join("collision150-report.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    if failures.is_empty():print("BOTANICAL COLLISION150: PASS — authored solid inventory,110 treads, real walk/dash and floor support, glass/projectile/car blockers, both grounded entrances, pickup collider lifecycle and bounded load-only spawn clearance")
    RenderingServer.set_render_loop_enabled(true);quit(0 if failures.is_empty() else 1)
