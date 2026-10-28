extends SceneTree
## Isolated physical AI fixtures. Full campaign input routes run separately.
const Teardown=preload("res://tools/level3_test_teardown.gd")
var failures: Array[String]=[]
var report: Dictionary={"scope":"Actual world collision/navigation/AI and public weapon input; staged fixtures, not a full playthrough."}
var game: Node3D
var visual:=false
var output:="user://guard-ai-evidence"
var events: Array[Dictionary]=[]
var captures: Array[String]=[]
var handoffs: Array[Dictionary]=[]

class RangeDirector extends Node3D:
    var player: Node3D
    var stage:="garden"

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual":visual=true
        elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL GUARD AI: "+why)
func frames(count: int) -> void:
    for i in range(count):await physics_frame
func draw() -> void:
    await process_frame;RenderingServer.force_draw(true)
func capture(name_: String) -> void:
    if not visual:return
    for i in range(3):await draw()
    var path:=output.path_join(name_+".png")
    check(root.get_texture().get_image().save_png(path)==OK,"could not save "+name_)
    captures.append(name_)
func dispose(scene: Node) -> void:
    if current_scene==scene:current_scene=null
    scene.queue_free();await frames(5)
func audio(kind: StringName,point: Vector3) -> void:
    if kind in [&"enemy_shoot",&"body_hit"] or str(kind).begins_with("impact_"):events.append({"kind":str(kind),"position":point})
    if kind==&"enemy_shoot":
        for cone in get_nodes_in_group("enemy_cone_projectile"):
            if cone.travelled>0 or cone.global_position.distance_to(point)>.001:continue
            var source=cone.source
            var held: Node3D=source.visual._throw_prop
            var thrown: Node3D=cone.get_node_or_null("ThrownConeVisual")
            check(held!=null and thrown!=null,"actual AI cone did not inherit the held geometry")
            if held==null or thrown==null:continue
            var error:float=point.distance_to(source.visual.throw_origin())
            check(error<.001,"cone launch popped away from the current hand socket")
            check(thrown.basis.is_equal_approx(held.global_basis),"held-to-flying cone changed its world scale or orientation")
            var original=held.find_children("*","MeshInstance3D",true,false)
            var copies=thrown.find_children("*","MeshInstance3D",true,false)
            check(not original.is_empty() and original.size()==copies.size(),"AI cone handoff lost its model parts")
            for i in range(mini(original.size(),copies.size())):
                check(original[i].mesh==copies[i].mesh and original[i].material_override==copies[i].material_override,"flying cone substituted held mesh/material resources")
            handoffs.append({"socket_error_metres":error,"mesh_parts":copies.size(),"held_visible_before_release":held.visible,"flying_visible":thrown.visible,"source_bones":source.visual.skeleton.get_bone_count()})
func run() -> void:
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    DirAccess.make_dir_recursive_absolute(output)
    root.get_node("SignalBus").audio_event.connect(audio)
    if visual:
        root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
        RenderingServer.set_render_loop_enabled(false)
    await garden_navigation_and_patrol()
    await cone_fixture("dodge")
    await cone_fixture("hit")
    await cone_fixture("wall")
    await save_ids()
    await Teardown.drain_audio(self)
    RenderingServer.set_render_loop_enabled(true)
    report.failures=failures;report.captures=captures;report.physical_cone_handoffs=handoffs
    FileAccess.open(output.path_join("guard-ai-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if failures.is_empty():print("BOTANICAL GUARD AI: PASS — six owned actors, physical terrace routes/patrol/search/reacquisition, locked dodgeable shots/world impacts and stable legacy/new save IDs")
    quit(0 if failures.is_empty() else 1)

func garden_navigation_and_patrol() -> void:
    game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    for i in range(140):
        await physics_frame
        if game.guard_navigation.is_ready:break
    var nav=game.guard_navigation
    check(nav.is_ready and nav.point_count>2500 and nav.connection_count>7000,"shared physical navigation did not build")
    check(game.guards.size()==6 and game.tank==game.guards[3],"stable six actor/guardian IDs changed")
    var models: Array[Node3D]=[]
    var visual_script=load("res://scripts/squirrel_3d_visual.gd")
    for node in game.find_children("*","Node3D",true,false):
        if node.get_script()==visual_script:models.append(node)
    check(models.size()==6,"combat-looking squirrel mannequin remained outside controller ownership")
    for model in models:check(model.get_parent() in game.guards,"unowned squirrel visual is unresponsive scenery")
    var walked: Array[float]=[]
    for guard in game.guards:walked.append(guard._distance_walked)
    await frames(900)
    var patrols: Array[Dictionary]=[]
    for i in range(game.guards.size()):
        var guard=game.guards[i]
        var travelled:float=guard._distance_walked-walked[i]
        check(travelled>7 if guard.is_tank else travelled>14,"patrol stood still: "+guard.name)
        check(guard._unsticks<5,"patrol repeatedly hit an unreachable point: "+guard.name)
        patrols.append({"id":i,"name":str(guard.name),"walked_15_seconds":travelled,"unsticks":guard._unsticks,"role":guard.tactical_role})
    report.patrols=patrols
    var routes: Array[Dictionary]=[]
    for endpoints in [[Vector3(-42,7,-31),Vector3(-40,3,-10)],[Vector3(-27,3,8),Vector3(38,3,16)],[Vector3(-45,12,-83),Vector3(0,3,8)]]:
        var path: PackedVector3Array=nav.path(endpoints[0],endpoints[1])
        check(path.size()>3,"missing physical terrace/pond detour")
        if path.is_empty():continue
        var length:=0.0
        for i in range(1,path.size()):
            length+=path[i-1].distance_to(path[i]);check(nav.segment_clear(path[i-1],path[i]),"route crosses a real collider")
        check(path[-1].distance_to(endpoints[1])<3,"route ended on the wrong terrace")
        if endpoints[0].x< -40 and endpoints[1].x< -30:check(length>45,"retaining wall was bypassed by a height teleport")
        routes.append({"from":endpoints[0],"to":endpoints[1],"points":path.size(),"metres":length})
    report.routes=routes
    if visual:
        var observer:=Camera3D.new();game.add_child(observer);observer.current=true;observer.position=Vector3(-20,6.5,17);observer.look_at(game.guards[4].position+Vector3.UP*.9)
        await capture("pond-patrol")
        observer.position=Vector3(-34,10,-24);observer.look_at(game.guards[1].position+Vector3.UP*.9);await capture("west-patrol")
        observer.queue_free();game.player.camera.make_current()
    # Real gun noise on the lower side of a wall must lead the west guard
    # around a traversable opening, not vertically through the wall.
    for guard in game.guards:guard.set_physics_process(false)
    game.player.set_physics_process(false)
    var before_gate: PackedVector3Array=nav.path(Vector3(0,7,-31),Vector3(0,7,-36))
    check(before_gate.is_empty() or before_gate[-1].distance_to(Vector3(0,7,-36))>2.5,"closed hydraulic gate admitted an actor route")
    var gate_revision:int=nav.revision
    for point: Vector3 in game.PART_POSITIONS:
        game.player.position=point+Vector3.UP*.65;game.interact()
    game.player.position=game.PANEL+Vector3.UP*.65;game.interact()
    for point in [Vector3(28,3.65,19),Vector3(38,3.65,19)]:
        game.player.position=point;game.interact()
    await frames(210)
    var after_gate: PackedVector3Array=nav.path(Vector3(0,7,-31),Vector3(0,7,-36))
    check(nav.revision>gate_revision and after_gate.size()>1 and after_gate[-1].z< -35,"physically raised gate did not reconnect navigation")
    report.gate_navigation={"before_revision":gate_revision,"after_revision":nav.revision,"closed_route_points":before_gate.size(),"open_route_points":after_gate.size()}
    game.player.set_physics_process(true)
    var actor=game.guards[1]
    actor.position=Vector3(-36,7.05,-23);actor.velocity=Vector3.ZERO;actor.set_physics_process(true)
    game.player.position=Vector3(-40,3.65,-10);game.player.velocity=Vector3.ZERO
    game.player.camera.look_at(actor.position+Vector3.UP*.9)
    await frames(2)
    game.player.request_fire();await frames(2)
    game.player.set_physics_process(false)
    check(actor.state=="investigate" and actor._memory>10,"real gunshot failed to start committed investigation")
    var crossed:=false
    var crossed_x:=INF
    var reached:=false
    var start_z:float=actor.position.z
    for i in range(2700):
        var before: Vector3=actor.position
        await physics_frame
        check(absf(actor.position.y-before.y)<.35,"guard teleported between terrace heights")
        if before.z< -14 and actor.position.z>=-14:
            crossed=true;crossed_x=actor.position.x
            check(absf(crossed_x)>50.3 or absf(crossed_x)<10.5,"guard crossed the retaining wall instead of an opening")
        if actor.position.distance_to(game.player.position)<6:
            reached=true;break
    check(crossed and reached,"investigation never reached the lower terrace around the real wall")
    report.investigation={"wall_crossed_at_x":crossed_x,"reached_player_side":reached,"replans":actor._route_replans,"unsticks":actor._unsticks}
    if visual:
        game.player.camera.look_at(actor.position+Vector3.UP*.9);await capture("lower-terrace-investigation")
    game.player.position=Vector3(0,.65,65)
    var saw_search:=false
    for i in range(900):
        await physics_frame
        if actor.state=="search":saw_search=true
        if saw_search and actor.state=="patrol":break
    check(saw_search and actor.state=="patrol","lost contact failed to search then resume patrol")
    var reacquired:=false
    for offset in [Vector3(6,0,0),Vector3(-6,0,0),Vector3(0,0,6),Vector3(0,0,-6)]:
        var point: Vector3=actor.position+offset
        point.y=game.world.surface_height_at(point.x,point.z)+.65
        if not preload("res://scripts/squirrel_queries.gd").visible_from(actor.position+Vector3.UP*1.1,point+Vector3.UP*.3,game.get_world_3d(),1):continue
        game.player.position=point;await frames(18)
        if actor._sees_player:reacquired=true;break
    check(reacquired and actor.state in ["chase","flank","aim","fire","melee","recover"],"visible player was not reacquired")
    var clock:float=actor._clock
    root.get_node("PauseManager").set_paused(true)
    for i in range(12):await process_frame
    check(is_equal_approx(clock,actor._clock),"pause advanced AI or its locked attack")
    root.get_node("PauseManager").set_paused(false)
    for guard in game.guards:guard.set_physics_process(false)
    game.player.position=Vector3(0,.65,60)
    game.player.set_physics_process(true)
    var pair=[game.guards[0],game.guards[4]]
    pair[0].position=Vector3(-3,.05,52);pair[1].position=Vector3(3,.05,52)
    var initial_shots:int=pair[0]._shots_fired+pair[1]._shots_fired
    for guard in pair:guard.set_physics_process(true)
    var max_tells:=0
    var max_projectiles:=0
    var hp_before:int=game.player.get_hp()
    for i in range(360):
        await physics_frame
        var tells:=0
        for guard in pair:
            if guard.state in ["aim","fire","melee"]:tells+=1
        max_tells=maxi(max_tells,tells)
        max_projectiles=maxi(max_projectiles,get_nodes_in_group("enemy_cone_projectile").size())
    check(max_tells<=1,"nearby scouts stacked overlapping attack tells")
    check(pair[0]._shots_fired+pair[1]._shots_fired>initial_shots,"nearby scouts never applied ranged pressure")
    check(game.player.get_hp()<hp_before and game.player.get_hp()>0,"actual nearby pressure did no damage or overwhelmed a stationary player too quickly")
    check(max_projectiles<=3,"projectile pressure is not bounded")
    report.pressure={"simulated_seconds":6,"simultaneous_tells":max_tells,"max_projectiles":max_projectiles,"hp_before":hp_before,"hp_after":game.player.get_hp()}
    if visual:
        game.player.camera.look_at(pair[0].position+Vector3.UP*1.05);await capture("nearby-scout-pressure")
    report.navigation={"points":nav.point_count,"connections":nav.connection_count,"queries":nav.query_count,"requests":nav.route_requests,"cache_hits":nav.cache_hits}
    await dispose(game)

func solid(parent: Node3D,position_: Vector3,size_: Vector3) -> StaticBody3D:
    var body:=StaticBody3D.new();body.collision_layer=1;body.position=position_
    var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size_;shape.shape=box
    body.add_child(shape);parent.add_child(body)
    if visual:
        var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.mesh.size=size_
        var mat:=StandardMaterial3D.new();mat.albedo_color=Color("626d6b");mesh.material_override=mat;body.add_child(mesh)
    return body
func cone_fixture(kind: String) -> void:
    var scene:=RangeDirector.new();root.add_child(scene);current_scene=scene
    solid(scene,Vector3(0,-.1,0),Vector3(60,.2,60))
    if visual:
        var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("243343");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("a6bed3");env.environment.ambient_light_energy=.8;scene.add_child(env)
        var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);scene.add_child(light)
    scene.player=load("res://scenes/level1_player.tscn").instantiate();scene.player.position=Vector3(0,.875,11);scene.add_child(scene.player)
    var guard=load("res://scripts/woodland_guard.gd").new();guard.director=scene;scene.add_child(guard)
    await frames(5)
    var entered_aim:=false
    for i in range(180):
        await physics_frame
        if guard.state=="aim":entered_aim=true;break
    check(entered_aim and guard.warning_ring.visible,"ranged attack lacks its readable aim tell")
    var locked:Vector3=guard._attack_target
    if visual:
        scene.player.camera.look_at(guard.position+Vector3.UP*1.05);await capture("cone-"+kind+"-tell")
    if kind=="dodge":Input.action_press("l1_move_right")
    var observer: Camera3D
    if visual and kind=="hit":
        observer=Camera3D.new();scene.add_child(observer);observer.current=true
        observer.position=Vector3(2.6,2.0,3.6);observer.look_at(guard.position+Vector3.UP*.95)
    var released:=false
    var captured_hand:=false
    for i in range(150):
        await physics_frame
        if visual and kind=="hit" and not captured_hand and guard.state=="fire" and guard._timer<.43 and guard._timer>.35:
            captured_hand=true;await capture("cone-held-before-release")
        if guard._shots_fired>0:released=true;break
    if visual and kind=="hit":await capture("cone-physical-after-release")
    check(not guard.visual._throw_prop.visible,"held cone remained duplicated after its actual projectile release")
    check(released and guard._attack_target.is_equal_approx(locked),"aim changed after the tell or projectile never released")
    var event_start:=events.size()
    if kind=="wall":solid(scene,Vector3(0,1.5,6),Vector3(8,3,.4))
    if kind=="dodge":
        await frames(12);Input.action_release("l1_move_right")
        check(scene.player.position.x>3,"dodge did not use actual player movement")
    guard.set_physics_process(false)
    await frames(120)
    if kind=="hit":check(scene.player.get_hp()==92,"stationary player did not receive one real 8-point projectile hit")
    else:check(scene.player.get_hp()==100,"dodged or wall-blocked projectile still damaged player")
    var world_impact:=false
    for event in events.slice(event_start):
        if str(event.kind).begins_with("impact_"):world_impact=true
    if kind=="wall":check(world_impact,"real wall impact produced no impact event")
    report["projectile_"+kind]={"hp":scene.player.get_hp(),"shots":guard._shots_fired,"locked_target":locked,"actual_player_position":scene.player.position,"world_impact":world_impact}
    Input.action_release("l1_move_right")
    await dispose(scene)

func save_ids() -> void:
    var State=load("res://scripts/botanical_state.gd")
    var state=State.new();state.defeated.assign([0,3,4,5]);state.guardian=true;state.reward=true;state.gate_unlatched=true
    check(state.save(),"new defeated IDs did not save")
    var restored=State.new();restored.load_save()
    check(restored.defeated==[0,3,4,5] and restored.reward and restored.guardian,"version2 lost appended actor IDs or earned reward")
    var loaded=await load_saved_actors()
    check(loaded.guards[4].defeated and loaded.guards[5].defeated and loaded.tank.defeated,"saved new actor defeats were not applied to real controllers")
    await dispose(loaded)
    var raw={"version":1,"guardian":true,"reward":false,"position":[0,7.65,-36],"defeated":[0,1,2,3,4,5]}
    FileAccess.open(State.PATH,FileAccess.WRITE).store_string(JSON.stringify(raw))
    restored=State.new();restored.load_save()
    check(restored.defeated==[0,1,2] and not restored.guardian and not restored.gate_unlatched and restored.position.z> -33,"unfinished legacy checkpoint granted new defeats or trapped the player")
    loaded=await load_saved_actors()
    check(not loaded.tank.defeated and not loaded.guards[4].defeated and not loaded.guards[5].defeated and loaded.player.position.z> -33,"unfinished legacy controller migration bypassed combat or safe relocation")
    await dispose(loaded)
    raw.reward=true
    FileAccess.open(State.PATH,FileAccess.WRITE).store_string(JSON.stringify(raw))
    restored=State.new();restored.load_save()
    check(restored.defeated==[0,1,2] and restored.guardian and restored.reward and restored.gate_unlatched,"completed legacy checkpoint lost its earned escape or invented new actor defeats")
    loaded=await load_saved_actors()
    check(loaded.tank.defeated and loaded.progress.reward and loaded.water_flow.gate_open>.98 and not loaded.guards[4].defeated and not loaded.guards[5].defeated,"completed legacy actual guardian/gate restoration or new encounter IDs changed")
    await dispose(loaded)
    report.save_ids={"version2":[0,3,4,5],"legacy_unfinished":[0,1,2],"legacy_completed":[0,1,2],"legacy_guardian_restored_from_reward":true,"guardian_id":3}
    State.clear()

func load_saved_actors() -> Node3D:
    var scene=load("res://game.tscn").instantiate();root.add_child(scene);current_scene=scene
    for guard in scene.guards:guard.set_physics_process(false)
    scene.player.set_physics_process(false)
    await frames(6)
    if visual:
        for i in range(4):await draw()
    return scene
