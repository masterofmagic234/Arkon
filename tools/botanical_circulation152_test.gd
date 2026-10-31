extends SceneTree
## Full architectural circulation, using the actual garden player and InputMap.
## Starts are staged per route; no transform corrections occur during a walk.
const Layout=preload("res://scripts/botanical_layout.gd")
var game: Node3D
var player: CharacterBody3D
var output:="/tmp/botanical-circulation152"
var failures: Array[String]=[]
var records: Array=[]

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")

func release() -> void:
    for action in ["l1_move_forward","l1_move_backward","l1_move_left","l1_move_right"]:Input.action_release(action)

func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL CIRCULATION152: "+why)

func ground(point: Vector2) -> Dictionary:
    var at:=Vector3(point.x,game.world.surface_height_at(point.x,point.y),point.y)
    var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP*3,1)
    return game.get_world_3d().direct_space_state.intersect_ray(query)

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    for tick in range(720):
        await physics_frame
        if game.ready_for_play and game.guard_navigation.is_ready:break
    check(game.ready_for_play and game.guard_navigation.is_ready,"Actual garden never became ready")
    player=game.player;game.set_process(false);game.set_physics_process(false)
    player.set_process(false);player.set_physics_process(false)
    for guard in game.guards:
        guard.set_process(false);guard.set_physics_process(false);guard.collision_layer=0
    # Keep closed quest doors, pond, parked car, all furniture and actual
    # mission collision. Only moving enemies are excluded from this isolated
    # architecture proof; it does not certify live combat or campaign pacing.
    for route in Layout.all_paths():
        for backwards in [false,true]:
            var points: Array=route.points.duplicate()
            if backwards:points.reverse()
            await walk(route.id,points,backwards)
    release()
    var hashes: Dictionary={}
    for path in ["scripts/botanical_world.gd","scripts/botanical_layout.gd","scripts/botanical_world151.gd","scripts/botanical_collision150.gd","scripts/botanical_garden.gd","scripts/botanical_evening.gd","scripts/level1_player.gd","scripts/grounded_step_motion.gd","tools/botanical_circulation152_test.gd"]:hashes[path]=FileAccess.get_sha256("res://"+path)
    var report:={"result":"PASS" if failures.is_empty() else "FAIL","failures":failures,"routes":records,"source_hashes":hashes,"scope":"Actual game.tscn player, production InputMap and StepMotion; all17 routes in both directions, staged start only. Enemy motion/collision disabled to isolate architecture. Closed quest doors and real mission/vehicle/furniture collisions retained.","engine":Engine.get_version_info().string}
    FileAccess.open(output.path_join("circulation152-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    current_scene=null;game.queue_free()
    for i in range(4):await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    print("BOTANICAL CIRCULATION152: ",report.result," ",records.size()," route walks")
    quit(0 if failures.is_empty() else 1)

func walk(id: String,points: Array,backwards: bool) -> void:
    release();var hit:=ground(points[0])
    check(not hit.is_empty(),id+" start lacks actual support")
    if hit.is_empty():return
    player.position=hit.position+Vector3.UP*.605;player.velocity=Vector3.ZERO
    for tick in range(15):player._physics_process(1.0/60);await physics_frame
    var start:=player.position;var minimum_grounded_clearance:=INF;var maximum_lateral_error:=0.0;var steps:=0;var segment_records: Array=[]
    for index in range(1,points.size()):
        var a: Vector2=points[index-1];var b: Vector2=points[index]
        var maximum_ticks:=ceili(a.distance_to(b)/4.2*60)+360
        var arrived:=false;var segment_start:=player.position;var contacts: Dictionary={}
        for tick in range(maximum_ticks):
            var direction:=Vector3(b.x-player.position.x,0,b.y-player.position.z)
            if direction.length()<.16:arrived=true;break
            player.look_at(player.position+direction.normalized());player.camera.rotation=Vector3.ZERO
            Input.action_press("l1_move_forward")
            player._physics_process(1.0/60);await physics_frame;steps+=1
            for collision_index in range(player.get_slide_collision_count()):
                var contact=player.get_slide_collision(collision_index).get_collider()
                if contact!=null:contacts[str(contact.name)]=true
            var current:=Vector2(player.position.x,player.position.z)
            maximum_lateral_error=maxf(maximum_lateral_error,current.distance_to(Geometry2D.get_closest_point_to_segment(current,a,b)))
            if player.is_on_floor():
                var floor_hit:=ground(current)
                if not floor_hit.is_empty():minimum_grounded_clearance=minf(minimum_grounded_clearance,player.position.y-.6-floor_hit.position.y)
        release()
        check(arrived,"%s %s segment%d blocked at%s toward%s"%[id,"reverse" if backwards else "forward",index,str(player.position),str(b)])
        segment_records.append({"segment":index,"arrived":arrived,"start":[segment_start.x,segment_start.y,segment_start.z],"end":[player.position.x,player.position.y,player.position.z],"goal":[b.x,b.y],"contacts":contacts.keys()})
        if not arrived:break
    check(minimum_grounded_clearance>-.02,id+" feet penetrate the actual walk surface")
    check(maximum_lateral_error<.30,id+" needed lateral collision recovery outside the authored route")
    records.append({"id":id,"backwards":backwards,"start":[start.x,start.y,start.z],"end":[player.position.x,player.position.y,player.position.z],"frames":steps,"segments":segment_records,"minimum_grounded_clearance":minimum_grounded_clearance if is_finite(minimum_grounded_clearance) else null,"maximum_lateral_error":maximum_lateral_error})
