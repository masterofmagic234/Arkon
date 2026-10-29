extends SceneTree
## Production movement against actual solid geometry, without floor teleports.
var output := "/tmp/woodland-collision150"
var fixture: Fixture
var failures: Array[String]=[]
var report := {"cases":[],"source_hashes":{},"failures":[]}
var Guard: Script
var Navigation: Script
var Step: Script
var visual := false
var captures: Array[String]=[]
var evidence_camera: Camera3D
var include_garden := true
var garden_draws := 0

class FlatWorld extends Node3D:
    func surface_height_at(_x: float,_z: float) -> float:return 0.0

class Fixture extends Node3D:
    var player: Node
    var guard_navigation: Node
    var world: Node3D
    var water_flow: Node3D
    var stage := "garden"
    func ground_height_at(_point: Vector3) -> float:return 0.0
    func make_noise(_point: Vector3,_radius: float,_time: float) -> void:pass

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
        elif arg=="--visual":visual=true
        elif arg=="--no-garden":include_garden=false
    call_deferred("run")

func run() -> void:
    Guard=load("res://scripts/woodland_guard.gd")
    Navigation=load("res://scripts/botanical_guard_navigation.gd")
    Step=load("res://scripts/grounded_step_motion.gd")
    root.get_node("GameState").sfx_muted=true
    root.get_node("GameState").music_muted=true
    fixture=Fixture.new();root.add_child(fixture);current_scene=fixture
    fixture.world=FlatWorld.new();fixture.add_child(fixture.world)
    solid(Vector3(0,-.15,0),Vector3(220,.3,220),"Floor")
    fixture.player=load("res://scenes/level1_player.tscn").instantiate()
    fixture.player.heist=fixture;fixture.player.position=Vector3(-50,.61,-50)
    fixture.add_child(fixture.player);fixture.player.set_physics_process(false)
    fixture.player.configure_garden_collision()
    fixture.player.camera.position.y=.95;fixture.player.eye_height=.95
    if visual:setup_visual()
    for tank in [false,true]:await guard_obstacles(tank)
    await player_obstacles()
    await player_head_clearance()
    await stairs("scout")
    await stairs("tank")
    await stairs("player")
    await refused_steps()
    await routes()
    current_scene=null;fixture.queue_free();await frames(3)
    if include_garden:await garden_checks()
    for path in ["scripts/woodland_guard.gd","scripts/botanical_guard_navigation.gd","scripts/grounded_step_motion.gd","scripts/level1_player.gd","scripts/botanical_world.gd","scripts/botanical_garden.gd","scripts/botanical_collision150.gd","scripts/world_collision.gd","scripts/botanical_encounters.gd","scripts/botanical_mission_routes.gd","tools/woodland_collision150_test.gd"]:
        report.source_hashes[path]=FileAccess.get_sha256("res://"+path)
    report.failures=failures;report.captures=captures
    report.scope={"production_movement":true,"staged_fixture_starts":true,"actual_garden":include_garden,"visual":visual,"capture_dimensions":[1280,720]}
    report.renderer=DisplayServer.get_name();report.engine=Engine.get_version_info().string
    await finish_fixture()
    DirAccess.make_dir_recursive_absolute(output)
    FileAccess.open(output.path_join("collision150-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if failures.is_empty():print("WOODLAND COLLISION150: PASS — real capsules block walls/rocks/dashes; swept stair traversal, floor support and accessible size-aware routes")
    else:push_error("WOODLAND COLLISION150: FAIL "+str(failures))
    quit(0 if failures.is_empty() else 1)

func finish_fixture() -> void:
    # This fixture disables automatic drawing. Physics frames release Nodes,
    # but do not flush the renderer's pending texture deletions. Release its
    # remaining references and draw an empty viewport before renderer shutdown.
    current_scene=null
    fixture=null;evidence_camera=null;Guard=null;Navigation=null;Step=null
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    var empty_draws:=0
    if visual:
        for index in range(3):
            await process_frame;call_deferred("draw_frame");await RenderingServer.frame_post_draw
            empty_draws+=1
    RenderingServer.set_render_loop_enabled(true)
    report.teardown={"fixture_references_released":true,"audio_drained":true,"empty_viewport_draws":empty_draws,"actual_garden_draws":garden_draws,"automatic_render_loop_restored":true}

func guard_at(point: Vector3,tank: bool) -> CharacterBody3D:
    var actor=Guard.new();actor.is_tank=tank;actor.director=fixture;actor.position=point
    fixture.add_child(actor);actor.set_physics_process(false)
    return actor

func guard_obstacles(tank: bool) -> void:
    var actor=guard_at(Vector3(-4,.03,0),tank)
    var radius := .58 if tank else .36
    var wall=solid(Vector3(0,1.7,0),Vector3(.3,3.4,14),"Wall")
    await frames(3)
    for tick in range(150):
        actor._walk_towards(Vector3(4,0,0),4.2,1.0/60)
        await physics_frame
    check(actor.position.x<=-.15-radius+.025,"%s crossed a solid wall"%actor.is_tank)
    report.cases.append({"kind":"tank_wall" if tank else "scout_wall","position":str(actor.position),"blocked":actor.position.x<-.15})
    await capture(("tank" if tank else "scout")+"-wall",actor.position+Vector3(-5,3,6),Vector3(0,.9,0))
    wall.queue_free();actor.queue_free();await frames(3)
    actor=guard_at(Vector3(-4,.03,0),tank)
    var rock=StaticBody3D.new();rock.collision_layer=1;rock.position=Vector3(0,.65,0)
    var shape=CollisionShape3D.new();var sphere=SphereShape3D.new();sphere.radius=1.0;shape.shape=sphere;rock.add_child(shape);fixture.add_child(rock)
    if visual:
        var mesh:=MeshInstance3D.new();var sphere_mesh:=SphereMesh.new();sphere_mesh.radius=1;sphere_mesh.height=2;mesh.mesh=sphere_mesh;rock.add_child(mesh)
    await frames(3)
    for tick in range(150):
        actor._walk_towards(Vector3(4,0,0),4.2,1.0/60)
        await physics_frame
    check(actor.position.x<-.85,"Guard crossed a solid boulder")
    report.cases.append({"kind":"tank_rock" if tank else "scout_rock","position":str(actor.position),"blocked":actor.position.x<-.85})
    await capture(("tank" if tank else "scout")+"-rock",actor.position+Vector3(-5,3,6),Vector3(0,.6,0))
    actor.queue_free();rock.queue_free();await frames(3)

func player_obstacles() -> void:
    var actor=fixture.player
    actor.position=Vector3(-4,.61,0);actor.velocity=Vector3.ZERO
    var wall=solid(Vector3(0,1.7,0),Vector3(.12,3.4,14),"ThinDashWall")
    Input.action_press("l1_move_right")
    for tick in range(90):actor._physics_process(1.0/60);await physics_frame
    check(actor.position.x<=-.06-.28+.025,"Player walked through a thin wall")
    actor.dash_cooldown=0;check(actor.request_dash(),"Production dash did not start")
    for tick in range(20):actor._physics_process(1.0/60);await physics_frame
    check(actor.position.x<=-.06-.28+.025,"Player dashed through a thin wall")
    report.cases.append({"kind":"player_walk_dash_wall","position":str(actor.position),"blocked":actor.position.x<0})
    await capture("player-dash-wall",actor.position+Vector3(-4,2,5),Vector3(0,1,0))
    Input.action_release("l1_move_right");wall.queue_free();await frames(3)

func stairs(kind: String) -> void:
    var shapes: Array[Node]=[]
    var z := 25.0
    var rise := 1.0/6.0
    for i in range(8):shapes.append(solid(Vector3((i+.5)*.7,(i+1)*rise*.5,z),Vector3(.7,(i+1)*rise,5),"ActualTread"))
    shapes.append(solid(Vector3(7.0,4*rise,z),Vector3(2.8,8*rise,5),"Landing"))
    var player_case := kind=="player"
    var actor: CharacterBody3D=fixture.player if player_case else guard_at(Vector3(-2,.025,z),kind=="tank")
    actor.position=Vector3(-2,.61 if player_case else .025,z);actor.velocity=Vector3.ZERO
    await frames(3)
    var max_rise := 0.0
    var steps := 0
    for tick in range(240):
        var before := actor.position
        if player_case:
            Input.action_press("l1_move_right");actor._physics_process(1.0/60)
        else:actor._walk_towards(Vector3(7.2,8*rise,z),3.0,1.0/60)
        max_rise=maxf(max_rise,actor.position.y-before.y)
        if actor.position.y-before.y>.03:steps+=1
        await physics_frame
        if actor.position.x>6.6:break
    Input.action_release("l1_move_right")
    var feet := actor.position.y-(.6 if player_case else 0.0)
    check(actor.position.x>6.5,"%s could not ascend physical .1667m stair risers: %s"%[kind,actor.position])
    check(absf(feet-8*rise)<.045,"%s feet do not rest on actual landing"%kind)
    check(max_rise<=.205,"%s stair helper exceeded its physical step height"%kind)
    var top := actor.position
    await capture(kind+"-stairs",Vector3(4,5,z+9),Vector3(3,.8,z))
    for tick in range(240):
        if player_case:
            Input.action_press("l1_move_left");actor._physics_process(1.0/60)
        else:actor._walk_towards(Vector3(-2,0,z),3.0,1.0/60)
        await physics_frame
        if actor.position.x< -1.2:break
    Input.action_release("l1_move_left")
    feet=actor.position.y-(.6 if player_case else 0.0)
    check(actor.position.x< -1.1 and absf(feet)<.045,"%s could not descend onto the floor"%kind)
    report.cases.append({"kind":kind+"_physical_stairs","top":str(top),"bottom":str(actor.position),"max_tick_rise":max_rise,"step_ticks":steps,"actual_riser":rise})
    if not player_case:actor.queue_free()
    else:actor.position=Vector3(-50,.61,-50)
    for shape in shapes:shape.queue_free()
    await frames(3)

func refused_steps() -> void:
    for kind in ["scout","tank","player"]:
        var player_case: bool=kind=="player"
        var z := -25.0
        var actor: CharacterBody3D=fixture.player if player_case else guard_at(Vector3(-2,.025,z),kind=="tank")
        var half_height := .6 if player_case else 0.0
        var actual_height := 1.7 if player_case else (2.05 if kind=="tank" else 1.45)
        actor.position=Vector3(-2,half_height+.025,z);actor.velocity=Vector3.ZERO
        var ledge=solid(Vector3(1.5,.2,z),Vector3(3,.4,5),"TooTallStep")
        await frames(3)
        for tick in range(90):
            if player_case:Input.action_press("l1_move_right");actor._physics_process(1.0/60)
            else:actor._walk_towards(Vector3(2,.4,z),3,1.0/60)
            await physics_frame
        Input.action_release("l1_move_right")
        check(actor.position.x<0,"%s crossed a .4m vertical ledge"%kind)
        var ledge_position := actor.position
        ledge.queue_free();await frames(3)
        actor.position=Vector3(-2,half_height+.025,z);actor.velocity=Vector3.ZERO
        var tread=solid(Vector3(1.5,1.0/12,z),Vector3(3,1.0/6,5),"LowStep")
        var ceiling=solid(Vector3(1.5,actual_height+.15,z),Vector3(3,.16,5),"StepHeadroomBlocker")
        await frames(3)
        for tick in range(90):
            if player_case:Input.action_press("l1_move_right");actor._physics_process(1.0/60)
            else:actor._walk_towards(Vector3(2,1.0/6,z),3,1.0/60)
            await physics_frame
        Input.action_release("l1_move_right")
        check(actor.position.x<0,"%s crossed a stair without capsule headroom"%kind)
        report.cases.append({"kind":kind+"_step_refusals","vertical_ledge":str(ledge_position),"headroom_blocker":str(actor.position),"ledge_height":.4})
        tread.queue_free();ceiling.queue_free()
        if not player_case:actor.queue_free()
        else:actor.position=Vector3(-50,.61,-50)
        await frames(3)

func routes() -> void:
    var wall=solid(Vector3(0,1.7,0),Vector3(.4,3.4,15),"RouteWall")
    var deck=solid(Vector3(-12,.15,-12),Vector3(6,.3,6),"RaisedVisibleFloor")
    await frames(3)
    var nav=Navigation.new();fixture.guard_navigation=nav;fixture.add_child(nav);nav.setup(fixture)
    for tick in range(140):
        await physics_frame
        if nav.is_ready:break
    check(nav.is_ready,"Physical navigation did not build")
    check(not nav.segment_clear(Vector3(-4,0,0),Vector3(4,0,0)),"Capsule route crosses a solid wall")
    var point: Vector3=nav._point(Vector2i(24,28)) # (-12,-12), actual deck top .30.
    check(absf(point.y-.325)<.005,"Navigation sampled terrain beneath a visible solid deck")
    for tank in [false,true]:
        var route: PackedVector3Array=nav.path(Vector3(-6,0,0),Vector3(6,0,0),tank)
        check(route.size()>3,"No navigational route around a physical wall")
        var valid:=true
        for i in range(1,route.size()):valid=valid and nav.segment_clear(route[i-1],route[i],tank)
        check(valid,"Graph contains a nontraversable capsule segment")
        var actor=guard_at(Vector3(-6,.025,0),tank);actor.navigation=nav
        for tick in range(900):
            actor._walk_towards(Vector3(6,0,0),3.2,1.0/60)
            await physics_frame
            if actor.position.distance_to(Vector3(6,0,0))<.65:break
        check(actor.position.distance_to(Vector3(6,0,0))<.7,"%s did not physically follow its route around the wall"%tank)
        report.cases.append({"kind":"tank_wall_route" if tank else "scout_wall_route","route":str(route),"final":str(actor.position),"valid_segments":valid})
        actor.queue_free();await frames(3)
    # The scout fits through .94m; the 1.16m guardian does not.
    wall.queue_free();await frames(3)
    var sides: Array[Node]=[]
    sides.append(solid(Vector3(0,1.7,2.735),Vector3(.4,3.4,4.53),"NarrowGateSide"))
    sides.append(solid(Vector3(0,1.7,-2.735),Vector3(.4,3.4,4.53),"NarrowGateSide"))
    await frames(3)
    var scout_clear: bool=nav.segment_clear(Vector3(-2,0,0),Vector3(2,0,0),false)
    var tank_clear: bool=nav.segment_clear(Vector3(-2,0,0),Vector3(2,0,0),true)
    check(scout_clear,"Scout clearance wrongly rejects an open gate")
    check(not tank_clear,"Guardian route uses an undersized scout capsule")
    report.navigation={"points":nav.point_count,"connections":nav.connection_count,"tank_points":nav.tank_graph.get_point_count(),"queries":nav.query_count,"raised_floor_y":point.y,"gate_scout":scout_clear,"gate_tank":tank_clear}
    for side in sides:side.queue_free()
    await frames(3)
    var ledge_results: Dictionary={}
    for height in [.3,.7]:
        var ledge=solid(Vector3(1.5,height*.5,15),Vector3(3,height,4),"GraphVerticalLedge")
        await frames(3);nav._support_cache.clear()
        var any_clear := false
        for tank in [false,true]:
            var clear: bool=nav.segment_clear(Vector3(-1,0,15),Vector3(1,height,15),tank)
            any_clear=any_clear or clear
            check(not clear,"Graph climbed a %.1fm vertical ledge (%s)"%[height,tank])
        ledge_results["%.1fm"%height]=any_clear
        ledge.queue_free();await frames(3)
    var ramp=StaticBody3D.new();ramp.collision_layer=1
    var ramp_collision=CollisionShape3D.new();var wedge=ConvexPolygonShape3D.new()
    wedge.points=PackedVector3Array([Vector3(0,0,13),Vector3(0,0,17),Vector3(2,0,13),Vector3(2,0,17),Vector3(2,2,13),Vector3(2,2,17)])
    ramp_collision.shape=wedge;ramp.add_child(ramp_collision);fixture.add_child(ramp)
    var ramp_top=solid(Vector3(3.5,1,15),Vector3(3,2,4),"RampLanding")
    await frames(3);nav._support_cache.clear()
    var both_clear := true
    for tank in [false,true]:
        var clear: bool=nav.segment_clear(Vector3(-.5,0,15),Vector3(2.5,2,15),tank)
        both_clear=both_clear and clear
        check(clear,"Graph rejected an actual45degree ramp (%s)"%tank)
    ledge_results["45_degree_ramp"]=both_clear
    report.navigation.vertical_ledges=ledge_results
    ramp.queue_free();ramp_top.queue_free()
    deck.queue_free();nav.queue_free();fixture.guard_navigation=null;await frames(3)

func player_head_clearance() -> void:
    var actor=fixture.player
    var legacy=load("res://scenes/level1_player.tscn").instantiate()
    var legacy_height: float=legacy.get_node("CollisionShape3D").shape.height
    check(is_equal_approx(legacy_height,1.2),"Garden collision configuration mutated the legacy player scene resource")
    legacy.free()
    var z := -45.0
    var outcomes: Array[Dictionary]=[]
    for gap in [1.4,2.0]:
        actor.position=Vector3(-3,.61,z);actor.velocity=Vector3.ZERO
        var beam=solid(Vector3(2,gap+.25,z),Vector3(4,.5,4),"HeadClearanceBeam")
        await frames(3)
        for tick in range(90):
            Input.action_press("l1_move_right");actor._physics_process(1.0/60)
            await physics_frame
        Input.action_release("l1_move_right")
        var passed: bool=actor.position.x>2.0
        if gap<1.7:check(actor.position.x<0,"Garden camera/head entered a1.4m ceiling gap")
        else:check(passed,"Garden head capsule rejected an ordinary2m overhead clearance")
        outcomes.append({"gap":gap,"passed":passed,"body_position":str(actor.position),"camera_position":str(actor.camera.global_position)})
        beam.queue_free();await frames(3)
    report.cases.append({"kind":"garden_player_head_clearance","height":actor.get_node("CollisionShape3D").shape.height,"shape_offset":str(actor.get_node("CollisionShape3D").position),"legacy_height":legacy_height,"outcomes":outcomes})
    actor.position=Vector3(-50,.61,-50)

func solid(position_: Vector3,size_: Vector3,label: String) -> StaticBody3D:
    var body:=StaticBody3D.new();body.name=label;body.position=position_;body.collision_layer=1;body.collision_mask=0
    var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size_;shape.shape=box;body.add_child(shape);fixture.add_child(body)
    if visual:
        var mesh:=MeshInstance3D.new();var box_mesh:=BoxMesh.new();box_mesh.size=size_;mesh.mesh=box_mesh;body.add_child(mesh)
    return body

func setup_visual() -> void:
    check(DisplayServer.get_name()!="headless","--visual requires a native renderer")
    root.size=Vector2i(1280,720)
    RenderingServer.set_render_loop_enabled(false)
    var world_environment:=WorldEnvironment.new();var environment:=Environment.new()
    environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("a9bdc8")
    environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=.7
    world_environment.environment=environment;fixture.add_child(world_environment)
    var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);light.light_energy=1.4;fixture.add_child(light)
    evidence_camera=Camera3D.new();evidence_camera.fov=55;fixture.add_child(evidence_camera);evidence_camera.make_current()

func garden_checks() -> void:
    root.get_node("GameState").start_new_run()
    var game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    for tick in range(20):
        if game.ready_for_play:break
        await physics_frame
    check(game.ready_for_play,"Garden startup never finished capsule validation")
    var world_summary: Dictionary=game.world.collision_geometry.summary()
    check(world_summary.get("transform_authority","")=="authored_CPU_put_transforms" and int(world_summary.get("authored_instance_count",0))>3000,"World collider transforms are not retained authored CPU instances")
    var player_collider: CollisionShape3D=game.player.get_node("CollisionShape3D")
    var player_height: float=player_collider.shape.height
    var player_foot_offset: float=player_height*.5-player_collider.position.y
    check(is_equal_approx(player_height,1.7) and is_equal_approx(player_foot_offset,.6),"Actual garden player does not protect the head while preserving the foot/root offset")
    game.set_physics_process(false);game.player.set_physics_process(false)
    for actor in game.guards:actor.set_physics_process(false)
    # Exercise the actual native garden environment as well as the isolated
    # obstacle captures. In manual rendering mode its Sky must finish a draw
    # before the scene is freed, rather than being created/destroyed undrawn.
    await draw_garden()
    await frames(3)
    var space: PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
    var nav=game.guard_navigation
    for tick in range(180):
        if nav.is_ready:break
        await physics_frame
    check(nav.is_ready,"Actual garden physical navigation never initialized")
    var inside_cliff: Vector3=nav._support(Vector3(-40,3,-10))
    check(inside_cliff.is_finite(),"Inside-rock regression fixture has no measurable underlying terrain")
    var scout_inside_open: bool=nav._open(inside_cliff,false)
    var tank_inside_open: bool=nav._open(inside_cliff,true)
    check(not scout_inside_open and not tank_inside_open,"Navigation admits a capsule wholly inside a concave cliff shell")
    var initial: Dictionary={}
    for actor in game.guards:
        var load_overlaps := capsule_overlaps(actor,space,64)
        check(load_overlaps.is_empty(),"Authored guard%d starts inside a concave-rock load volume: %s"%[actor.encounter_id,load_overlaps])
        initial[actor.encounter_id]={"position":actor.position,"overlaps":capsule_overlaps(actor,space,1|64),"load_overlaps":load_overlaps}
    # Gravity and the engine's actual shape recovery settle every authored
    # body, including dormant reinforcements. No actor position is assigned.
    for tick in range(24):
        for actor in game.guards:actor._settle_floor(1.0/60)
        await physics_frame
    var placements: Array[Dictionary]=[]
    check(game.guards.size()==25,"Actual garden lost an authored guard")
    for actor in game.guards:
        var overlaps := capsule_overlaps(actor,space)
        var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*.4,actor.position-Vector3.UP*.8,1))
        var gap := float(actor.position.y-hit.position.y) if not hit.is_empty() else INF
        var support_normal: Vector3=hit.normal if not hit.is_empty() else Vector3.ZERO
        var radius: float=actor.body_shape.shape.radius
        var support_gap_allowance := .04+radius*(1.0/maxf(.6156614753,support_normal.y)-1.0)
        var drift := Vector2(actor.position.x-initial[actor.encounter_id].position.x,actor.position.z-initial[actor.encounter_id].position.z).length()
        var penetration := capsule_penetration(actor)
        check(penetration<.003,"Authored guard%d capsule penetrates static geometry: %s depth%s"%[actor.encounter_id,overlaps,penetration])
        check(support_normal.y>=.6156614753 and gap>=-.012 and gap<=support_gap_allowance,"Authored guard%d lacks actual floor support (%s, allowance%s)"%[actor.encounter_id,gap,support_gap_allowance])
        check(drift<.10,"Authored guard%d required sideways spawn recovery (%s)"%[actor.encounter_id,drift])
        check(actor.encounter_id==game.guards.find(actor),"Collision fix changed stable guard IDs")
        placements.append({"id":actor.encounter_id,"role":actor.tactical_role,"initial":str(initial[actor.encounter_id].position),"initial_overlaps":initial[actor.encounter_id].overlaps,"initial_load_overlaps":initial[actor.encounter_id].load_overlaps,"settled":str(actor.position),"final_overlaps":overlaps,"penetration_depth":penetration,"support_gap":gap if is_finite(gap) else null,"support_normal":[support_normal.x,support_normal.y,support_normal.z],"support_gap_allowance":support_gap_allowance,"sideways_recovery":drift})
    var revision: int=nav.revision
    var before: bool=nav.segment_clear(Vector3(0,3.90,15),Vector3(0,3.90,32))
    check(not before,"Unpowered bridge navigation uses the invisible pond-volume lid")
    game.mission_routes.set_powered(true)
    await frames(210)
    check(game.mission_routes.opened>=.995 and nav.revision>revision,"Lowered pressure bridge did not refresh navigation independently of the store gate")
    var open_route: PackedVector3Array=nav.path(Vector3(0,3.35,10),Vector3(0,.08,45))
    check(bridge_route(open_route),"Powered physical bridge did not become a guard route")
    var bridge_cell := Vector2i(28,40) # x0,z24; .90m above the terrain lookup.
    var bridge_height: float=nav.graph.get_point_position(nav._id(bridge_cell)).y if nav.graph.has_point(nav._id(bridge_cell)) else -INF
    check(bridge_height>3.90 and bridge_height<3.95,"Navigation samples terrain below the lowered wooden bridge")
    var traversals: Array[Dictionary]=[]
    for actor in [game.guards[0],game.guards[3]]:
        traversals.append(await walk_actual_bridge(actor,nav))
    var threshold_traversals: Array[Dictionary]=[]
    for actor in [game.guards[0],game.guards[3]]:
        threshold_traversals.append(await walk_actual_threshold(actor,nav,"conservatory",Vector3(1.25,7.03,-20.5),Vector3(1.25,7.26,-25)))
        threshold_traversals.append(await walk_actual_threshold(actor,nav,"pavilion_west",Vector3(36,12.03,-78),Vector3(39.2,12.30,-78)))
    var flank_regression := await blocked_flank_goal(game,nav)
    nav.set_process(false)
    var restored=Navigation.new();game.add_child(restored);restored.setup(game)
    for tick in range(180):
        if restored.is_ready:break
        await physics_frame
    var restored_route: PackedVector3Array=restored.path(Vector3(0,3.35,10),Vector3(0,.08,45))
    check(restored.is_ready and restored._bridge_was_open and bridge_route(restored_route),"Already-powered bridge failed fresh navigation initialization")
    report.garden={"world_collision":game.world.collision_geometry.summary(),"player_capsule":{"height":player_height,"local_offset":str(player_collider.position),"feet_below_root":player_foot_offset},"inside_cliff_clearance":{"point":str(inside_cliff),"scout_open":scout_inside_open,"tank_open":tank_inside_open},"authored_placements":placements,"navigation_points":nav.point_count,"navigation_connections":nav.connection_count,"bridge_before_clear":before,"bridge_revision_before":revision,"bridge_revision_after":nav.revision,"bridge_deck_y":bridge_height,"powered_route":str(open_route),"restored_route":str(restored_route),"physical_bridge_traversals":traversals,"physical_threshold_traversals":threshold_traversals,"blocked_flank_regression":flank_regression}
    await draw_garden()
    game.queue_free();current_scene=null;await frames(5)

func draw_garden() -> void:
    if not visual:return
    await process_frame;call_deferred("draw_frame");await RenderingServer.frame_post_draw
    garden_draws+=1

func capsule_overlaps(actor: CharacterBody3D,space: PhysicsDirectSpaceState3D,mask:=1) -> Array[String]:
    var query:=PhysicsShapeQueryParameters3D.new()
    query.shape=actor.body_shape.shape;query.transform=actor.body_shape.global_transform;query.collision_mask=mask;query.margin=0
    var names: Array[String]=[]
    for hit in space.intersect_shape(query,16):names.append(str(hit.collider.name))
    return names

func capsule_penetration(actor: CharacterBody3D) -> float:
    var parameters:=PhysicsTestMotionParameters3D.new();parameters.from=actor.global_transform;parameters.motion=Vector3.ZERO;parameters.margin=0;parameters.recovery_as_collision=true
    var result:=PhysicsTestMotionResult3D.new()
    PhysicsServer3D.body_test_motion(actor.get_rid(),parameters,result)
    var depth:=0.0
    for index in range(result.get_collision_count()):depth=maxf(depth,result.get_collision_depth(index))
    return depth

func bridge_route(route: PackedVector3Array) -> bool:
    for point in route:
        if absf(point.x)<.2 and point.z>15 and point.z<32 and point.y>3.90:return true
    return false

func walk_actual_bridge(actor: CharacterBody3D,nav: Node) -> Dictionary:
    # Staged starting position only; every crossing displacement is made by
    # the production guard route follower and actual CharacterBody sweeps.
    var original := actor.position
    var old_state: String=actor.state
    actor.position=Vector3(0,3.57,9);actor.velocity=Vector3.ZERO
    actor.state="investigate";actor.navigation=nav;actor._replan=0;actor._route_goal=Vector3.INF
    for tick in range(8):actor._settle_floor(1.0/60);await physics_frame
    var minimum_deck_y := INF
    var maximum_tick_rise := 0.0
    var frame_count := 0
    var crossed := true
    var legs: Array[Dictionary]=[]
    for target in [Vector3(0,.035,46),Vector3(0,3.51,9)]:
        actor._replan=0;actor._route_goal=Vector3.INF
        var southbound: bool=target.z>20
        var maximum_sideways := 0.0
        var leg_minimum_y := INF
        for tick in range(900):
            var before := actor.position
            actor._walk_towards(target,3.2,1.0/60)
            actor._animate(1.0/60)
            maximum_tick_rise=maxf(maximum_tick_rise,absf(actor.position.y-before.y))
            if actor.position.z>15 and actor.position.z<32:
                leg_minimum_y=minf(leg_minimum_y,actor.position.y)
                maximum_sideways=maxf(maximum_sideways,absf(actor.position.x))
            await physics_frame;frame_count+=1
            if (actor.position.z>45.5 if southbound else actor.position.z<9.5):break
        var reached: bool=actor.position.z>45.5 if southbound else actor.position.z<9.5
        crossed=crossed and reached
        minimum_deck_y=minf(minimum_deck_y,leg_minimum_y)
        check(reached,"Actual %s could not physically cross its powered bridge route from %s"%["guardian" if actor.is_tank else "scout","north" if southbound else "south"])
        check(leg_minimum_y>3.89 and is_finite(leg_minimum_y) and maximum_sideways<1.5,"Guard failed to follow the raised bridge deck")
        legs.append({"target":str(target),"end":str(actor.position),"crossed":reached,"minimum_deck_y":leg_minimum_y if is_finite(leg_minimum_y) else null,"maximum_sideways":maximum_sideways})
    check(maximum_tick_rise<=.205,"Bridge guard changed height beyond the bounded physical step")
    var result := {"role":"tank" if actor.is_tank else "scout","crossed":crossed,"legs":legs,"final":str(actor.position),"minimum_deck_y":minimum_deck_y if is_finite(minimum_deck_y) else null,"maximum_tick_vertical_change":maximum_tick_rise,"physics_frames":frame_count,"staged_start":true,"movement":"production _walk_towards and body sweeps"}
    actor.position=original;actor.velocity=Vector3.ZERO;actor.state=old_state
    return result

func walk_actual_threshold(actor: CharacterBody3D,nav: Node,label: String,from: Vector3,to: Vector3) -> Dictionary:
    var original := actor.position
    var old_state: String=actor.state
    actor.position=from;actor.velocity=Vector3.ZERO;actor.state="investigate";actor.navigation=nav
    for tick in range(8):actor._settle_floor(1.0/60);await physics_frame
    var legs: Array[Dictionary]=[]
    for target in [to,from]:
        actor._replan=0;actor._route_goal=Vector3.INF
        var maximum_vertical_change := 0.0
        for tick in range(240):
            var before:=actor.position
            actor._walk_towards(target,2.5,1.0/60);actor._animate(1.0/60)
            maximum_vertical_change=maxf(maximum_vertical_change,absf(actor.position.y-before.y))
            await physics_frame
            if Vector2(actor.position.x-target.x,actor.position.z-target.z).length()<.3:break
        var reached := Vector2(actor.position.x-target.x,actor.position.z-target.z).length()<.4
        check(reached,"Actual %s %s threshold route was blocked"%["tank" if actor.is_tank else "scout",label])
        check(absf(actor.position.y-target.y)<.07,"Actual %s feet missed the %s floor"%[actor.is_tank,label])
        check(maximum_vertical_change<=.205,"Actual threshold motion exceeded a bounded physical step")
        legs.append({"target":str(target),"end":str(actor.position),"reached":reached,"maximum_tick_vertical_change":maximum_vertical_change})
    var result := {"role":"tank" if actor.is_tank else "scout","threshold":label,"legs":legs,"staged_start":true,"movement":"production _walk_towards and body sweeps"}
    actor.position=original;actor.velocity=Vector3.ZERO;actor.state=old_state
    return result

func blocked_flank_goal(game: Node3D,nav: Node) -> Dictionary:
    var actor: CharacterBody3D=game.guards[0]
    var old_position:=actor.position
    var old_state: String=actor.state
    var old_player: Vector3=game.player.position
    game.player.position=nav.ground_goal(Vector3(-13.5,3,-4))+Vector3.UP*.603
    actor.position=nav.ground_goal(Vector3(-9.866,7,-16.846))+Vector3.UP*.005
    actor.velocity=Vector3.ZERO;actor.state="flank";actor._replan=0;actor._route_goal=Vector3.INF
    for tick in range(8):actor._settle_floor(1.0/60);await physics_frame
    var blocked := Vector3(-18.626,3.603,-5.450)
    var primary: PackedVector3Array=nav.path(actor.position,blocked)
    check(primary.is_empty(),"Blocked-flank regression goal is no longer inside the actual cliff")
    var calls_before: int=actor._tactical_fallbacks
    actor._walk_towards(blocked,3.8,1.0/60)
    var chosen: Vector3=actor._route_destination
    var route_points: int=actor._route.size()
    var requests_after_replan: int=nav.route_requests
    check(actor._tactical_fallbacks>calls_before and route_points>1,"Flanker froze on an unreachable lateral order")
    check(chosen.y>game.player.position.y+.5,"Opposite flank order did not project onto the higher real stair floor")
    var projected: Vector3=nav.ground_goal(chosen)
    check(projected.is_finite() and absf(projected.y-chosen.y)<.005,"Tactical goal height is not the actual physical support")
    var maximum_change:=0.0
    for tick in range(420):
        var before:=actor.position
        actor._walk_towards(blocked,3.8,1.0/60);actor._animate(1.0/60)
        maximum_change=maxf(maximum_change,absf(actor.position.y-before.y))
        await physics_frame
        if Vector2(actor.position.x-chosen.x,actor.position.z-chosen.z).length()<.45:break
    var reached:=Vector2(actor.position.x-chosen.x,actor.position.z-chosen.z).length()<.5
    check(reached and maximum_change<=.205,"Flanker did not physically reach its safe opposite lane")
    check(nav.route_requests==requests_after_replan,"Cached tactical order requested a new path every movement frame")
    var result: Dictionary={"primary":str(blocked),"primary_unreachable":primary.is_empty(),"chosen":str(chosen),"end":str(actor.position),"route_points":route_points,"fallbacks":actor._tactical_fallbacks-calls_before,"reached":reached,"maximum_tick_vertical_change":maximum_change,"cached_route_requests":nav.route_requests==requests_after_replan,"role":actor.tactical_role,"staged_start":true}
    actor.position=old_position;actor.velocity=Vector3.ZERO;actor.state=old_state;game.player.position=old_player
    return result

func capture(label: String,from: Vector3,target: Vector3) -> void:
    if not visual:return
    DirAccess.make_dir_recursive_absolute(output)
    evidence_camera.position=from;evidence_camera.look_at(target)
    await process_frame;call_deferred("draw_frame");await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join(label+".png"));captures.append(label+".png")

func draw_frame() -> void:RenderingServer.force_draw(true)

func frames(count: int) -> void:
    for tick in range(count):await physics_frame

func check(ok: bool,message: String) -> void:
    if not ok:failures.append(message);push_error(message)
