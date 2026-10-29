extends SceneTree
## Focused staged physics fixture, not a full-route playthrough. Only the
## starting positions and bridge power are staged; production input, player
## gravity, capsule and authored pond/approach collisions decide every step.
var game: Node3D
var player: Node3D
var failures: Array[String]=[]
var samples: Array[Dictionary]=[]
var output:=""
const MOVEMENT=["l1_move_left","l1_move_right","l1_move_forward","l1_move_backward"]

func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL BRIDGE149: "+why)

func settle(count:=12) -> void:
    for i in range(count):await physics_frame

func release() -> void:
    for action in MOVEMENT:Input.action_release(action)

func place(at: Vector3) -> void:
    release();player.position=at;player.velocity=Vector3.ZERO
    await settle(20)

func drive(name_: String,direction: float,frames: int,target: float=INF,dash:=false) -> Dictionary:
    var start: Vector3=player.position
    player.rotation.y=PI if direction>0 else 0.0
    player.camera.rotation=Vector3.ZERO
    var furthest:=start.z
    var minimum_deck_y:=INF
    var crossed:=false
    for i in range(frames):
        Input.action_press("l1_move_forward",1.0)
        if dash and i%190==60:player.request_dash()
        await physics_frame
        furthest=maxf(furthest,player.position.z) if direction>0 else minf(furthest,player.position.z)
        if player.position.z>14 and player.position.z<33:minimum_deck_y=minf(minimum_deck_y,player.position.y)
        if is_finite(target) and (player.position.z>=target if direction>0 else player.position.z<=target):crossed=true;break
    release();await settle(8)
    var record={"case":name_,"start":[start.x,start.y,start.z],"end":[player.position.x,player.position.y,player.position.z],"furthest_z":furthest,"crossed":crossed,"minimum_deck_y":minimum_deck_y if is_finite(minimum_deck_y) else null,"dash":dash}
    samples.append(record);print("BOTANICAL BRIDGE149 CASE: ",JSON.stringify(record))
    return record

func run() -> void:
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    change_scene_to_file("res://game.tscn");await settle(20)
    game=current_scene;player=game.player
    game.set_physics_process(false)
    for guard in game.guards:guard.set_physics_process(false)
    check(not game.progress.installed and game.mission_routes.opened<.01,"fresh bridge is already powered")
    var water=game.world.get_node("PondWaterVolume")
    check(water.collision_layer==1 and is_equal_approx(water.position.y,3.26),"fixture changed the original solid pond volume")
    var space=game.get_world_3d().direct_space_state
    for z in [13.0,34.0]:
        var ray=PhysicsRayQueryParameters3D.create(Vector3(0,4.5,z-1),Vector3(0,4.5,z+1),1)
        var hit=space.intersect_ray(ray)
        check(not hit.is_empty() and str(hit.collider.name).begins_with("ClosedPressureBridgeLeaf"),"visible raised leaf has no physical face at z="+str(z))
    await place(Vector3(0,4.3,9))
    var north=await drive("unpowered_north_walk",1,300)
    check(float(north.furthest_z)<13.5,"unpowered north approach let the player walk through the raised leaf onto the pond")
    await place(Vector3(0,.8,46))
    var south=await drive("unpowered_south_walk",-1,360)
    check(float(south.furthest_z)>33.5,"unpowered south approach let the player walk through the raised leaf onto the pond")
    await place(Vector3(0,4.3,9))
    var north_dash=await drive("unpowered_north_dash",1,240,INF,true)
    check(float(north_dash.furthest_z)<13.5,"dash bypassed the unpowered north raised leaf")
    await place(Vector3(0,.8,46))
    var south_dash=await drive("unpowered_south_dash",-1,300,INF,true)
    check(float(south_dash.furthest_z)>33.5,"dash bypassed the unpowered south raised leaf")
    game.mission_routes.set_powered(true);await settle(170)
    check(game.mission_routes.opened>=.995,"powered bridge never fully lowered")
    for shape in game.mission_routes.crossing_shapes:check(not shape.disabled,"horizontal deck or rail did not become physical")
    await place(Vector3(0,4.3,9))
    var open_north=await drive("powered_north_to_south",1,720,46)
    check(bool(open_north.crossed),"powered north-to-south crossing hit an invisible wall")
    check(open_north.minimum_deck_y!=null and float(open_north.minimum_deck_y)>4.35,"powered crossing walked on the old pond collision instead of the raised deck")
    await place(Vector3(0,.8,46))
    var open_south=await drive("powered_south_to_north",-1,720,9)
    check(bool(open_south.crossed),"powered south-to-north crossing hit an invisible wall")
    check(open_south.minimum_deck_y!=null and float(open_south.minimum_deck_y)>4.35,"reverse crossing walked on the old pond collision instead of the raised deck")
    for z in [13.0,34.0]:
        var ray=PhysicsRayQueryParameters3D.create(Vector3(0,5,z-1),Vector3(0,5,z+1),1)
        check(space.intersect_ray(ray).is_empty(),"powered hinge retains a blocking collision at z="+str(z))
    check(water.collision_layer==1 and is_equal_approx(water.position.y,3.26),"bridge power altered the original pond collision")
    if not output.is_empty():
        DirAccess.make_dir_recursive_absolute(output)
        FileAccess.open(output.path_join("bridge149-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"samples":samples,"scope":"Staged bridge power and starting positions; production movement/gravity/capsule, walk/dash from both sides, actual powered crossings and hinge rays. Authored pond collider unchanged."},"  "))
    release();game.queue_free();current_scene=null;await settle()
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if failures.is_empty():print("BOTANICAL BRIDGE149: PASS — unpowered leaves block walking/dash from both sides, powered deck crosses both ways without invisible hinge walls, original pond unchanged")
    quit(0 if failures.is_empty() else 1)
