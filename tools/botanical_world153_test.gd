extends SceneTree
## Reproduce the actual coplanar stair surfaces and the calm road approach.
## Geometry uses production mesh faces; the approach uses ordinary player input.
const Layout=preload("res://scripts/botanical_layout.gd")
var game: Node3D
var output:="/tmp/botanical-world153"
var visual:=false
var failures: Array[String]=[]
var report:={"stairs":[],"captures":[],"approach":{}}

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
        elif arg=="--visual":visual=true
    call_deferred("run")

func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL WORLD153: "+why)

func frames(count: int) -> void:
    for i in range(count):await physics_frame

func area(polygon: PackedVector2Array) -> float:
    var result:=0.0
    for i in range(polygon.size()):result+=polygon[i].cross(polygon[(i+1)%polygon.size()])
    return absf(result)*.5

func add_faces(groups: Dictionary,faces: PackedVector3Array,label: String) -> void:
    for i in range(0,faces.size(),3):
        var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
        var normal: Vector3=(b-a).cross(c-a).normalized()
        var axis:=normal.abs().max_axis_index()
        if absf(normal[axis])<.9999:continue
        # Godot front faces are clockwise: positive cross-Y is a downward
        # face. Foundation undersides are buried, never a visible z-fight.
        if axis==1 and normal.y>0:continue
        var key:="%d/%d/%d"%[axis,1 if normal[axis]>0 else -1,roundi(a[axis]*10000)]
        var polygon:=PackedVector2Array()
        for p in [a,b,c]:
            polygon.append(Vector2(p.y,p.z) if axis==0 else (Vector2(p.x,p.z) if axis==1 else Vector2(p.x,p.y)))
        if area(polygon)<.000001:continue
        if not groups.has(key):groups[key]=[]
        groups[key].append({"label":label,"face":i/3,"polygon":polygon})

func stair_overlap(index: int) -> void:
    var flight: Array=Layout.STAIR_FLIGHTS[index]
    var groups: Dictionary={};var tread_count:=0
    for instance in game.world.collision_instances:
        if instance.kind!="box" or instance.material!="trim":continue
        var matches:=false
        for step in range(int(flight[3])):
            var expected: Vector3=flight[0].lerp(flight[1],float(step+1)/float(flight[3]))-Vector3.UP*.07
            if instance.at.origin.distance_to(expected)<.001:matches=true;break
        if not matches:continue
        var faces:=PackedVector3Array()
        for p in instance.mesh.get_faces():faces.append(instance.at*p)
        add_faces(groups,faces,"tread_%d"%tread_count);tread_count+=1
    var foundation=game.world.find_child("ClosedStairFoundation151_%d"%index,true,false)
    check(foundation!=null,"missing closed stair foundation%d"%index)
    if foundation!=null:
        var faces:=PackedVector3Array()
        for p in foundation.mesh.get_faces():faces.append(foundation.global_transform*p)
        add_faces(groups,faces,"foundation_and_landings")
    var maximum:=0.0;var bad: Array=[];var comparisons:=0
    for rows in groups.values():
        for i in range(rows.size()):
            for j in range(i+1,rows.size()):
                comparisons+=1
                for intersection in Geometry2D.intersect_polygons(rows[i].polygon,rows[j].polygon):
                    # Shared float32 edges can differ by a few ten-thousandths
                    # of a metre after mesh quantization. A0.5mm inset removes
                    # those edge slivers, while the former20mm side and400mm
                    # landing overlaps remain a positive area and fail.
                    var overlap:=0.0
                    for inset in Geometry2D.offset_polygon(intersection,-.0005):overlap+=area(inset)
                    maximum=maxf(maximum,overlap)
                    if overlap>.0001 and bad.size()<12:bad.append([rows[i].label,rows[i].face,rows[j].label,rows[j].face,overlap])
    check(tread_count==int(flight[3]),"actual production stair%d lost a tread"%index)
    check(maximum<.0001,"stair%d has coplanar same-facing overlap %.5fm² %s"%[index,maximum,str(bad)])
    report.stairs.append({"flight":index,"actual_treads":tread_count,"actual_foundation_surfaces":foundation.mesh.get_surface_count() if foundation!=null else 0,"coplanar_face_pairs_compared":comparisons,"shared_edge_inset_m":.0005,"buried_downward_faces_excluded":true,"maximum_same_facing_overlap_m2":maximum,"bad_pairs":bad})

func walk_to(goal: Vector3,limit:=700) -> bool:
    for tick in range(limit):
        var direction:=Vector3(goal.x-game.player.position.x,0,goal.z-game.player.position.z)
        if direction.length()<.18:Input.action_release("l1_move_forward");return true
        game.player.look_at(game.player.position+direction.normalized());game.player.camera.rotation=Vector3.ZERO
        Input.action_press("l1_move_forward")
        await physics_frame
    Input.action_release("l1_move_forward");return false

func capture(label: String,where: Vector3,target: Vector3) -> void:
    if not visual:return
    var camera: Camera3D
    var weapon_visible: bool=game.weapon.visible
    if label=="road-arrival":
        # Show the real spawn view; the first-person viewmodel must never be
        # mistaken for a world prop by a detached architecture camera.
        game.player.camera.make_current()
    else:
        game.weapon.hide()
        camera=Camera3D.new();camera.fov=65;camera.far=260;game.add_child(camera);camera.position=where;camera.look_at(target);camera.make_current()
    for i in range(4):await process_frame;RenderingServer.force_draw(true)
    var name_:=label+".png";root.get_texture().get_image().save_png(output.path_join(name_));report.captures.append(name_)
    if camera!=null:camera.queue_free()
    game.weapon.visible=weapon_visible;game.player.camera.make_current();await process_frame

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(1280,720)
    if visual:RenderingServer.set_render_loop_enabled(false)
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    for tick in range(720):
        await physics_frame
        if game.ready_for_play and game.guard_navigation.is_ready:break
    check(game.ready_for_play and game.guard_navigation.is_ready,"production garden did not become ready")
    var start: Vector3=game.player.position
    var car=game.get_node("GardenExitCar")
    check(Vector2(start.x,start.z).distance_to(Vector2(Layout.ENTRY_PLAYER_SPAWN.x,Layout.ENTRY_PLAYER_SPAWN.z))<.1,"fresh player did not spawn beside road car")
    check(car.position.is_equal_approx(Layout.ENTRY_CAR_POSITION) and is_equal_approx(car.rotation.y,Layout.ENTRY_CAR_YAW),"car not parked along actual outside road")
    check(not game.objective_events.has("entry_approach") and not game.encounter_director.active.has("entry"),"entry encounter triggered before entering the park")
    var hp: int=game.player.get_hp()
    await frames(1200)
    check(game.player.get_hp()==hp and hp==100,"idle road arrival took damage")
    check(not game.encounter_director.active.has("entry"),"entry activated during20s calm road arrival")
    await capture("road-arrival",start+Vector3(-2,1.0,3),Vector3(0,2,65))
    var to_drive:=await walk_to(Vector3(0,0,86));var to_gate:=await walk_to(Vector3(0,0,74))
    check(to_drive and to_gate,"ordinary input cannot walk from parked car through entrance drive")
    check(not game.encounter_director.active.has("entry") and game.player.get_hp()==100,"entry ambushed player before approach threshold")
    var at_gate: Vector3=game.player.position
    await capture("gate-approach",at_gate+Vector3(0,.95,0),Vector3(0,4,45))
    var to_trigger:=await walk_to(Vector3(0,0,69));await frames(3)
    check(to_trigger and game.encounter_director.active.has("entry"),"entry did not activate after walking into park")
    check(game.objective_events.count("entry_approach")==1,"entry approach event missing or repeated")
    report.approach={"start":str(start),"car":str(car.position),"idle_frames":1200,"idle_health":hp,"to_drive":to_drive,"to_gate":to_gate,"to_entry_trigger":to_trigger,"walked_distance_m":Vector2(start.x,start.z).distance_to(Vector2(game.player.position.x,game.player.position.z)),"entry_events":game.objective_events.count("entry_approach"),"scope":"Actual fresh game, ordinary InputMap movement, live guards; no position/resource/objective overrides during road approach."}
    game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
    for guard in game.guards:guard.set_process(false);guard.set_physics_process(false)
    for i in range(Layout.STAIR_FLIGHTS.size()):stair_overlap(i)
    await capture("central-stair-foot",Vector3(7,4.6,13),Vector3(0,6,-6))
    await capture("central-stair-crest",Vector3(7,8.6,-11),Vector3(0,7,-17))
    await capture("central-stair-side",Vector3(12,5.6,4),Vector3(0,5,-3))
    report.failures=failures;report.renderer=RenderingServer.get_current_rendering_method();report.engine=Engine.get_version_info().string
    var hashes={}
    for path in ["scripts/botanical_world.gd","scripts/botanical_world151.gd","scripts/botanical_layout.gd","scripts/botanical_garden.gd","scripts/botanical_state.gd","scripts/botanical_encounter_director.gd","tools/botanical_world153_test.gd"]:hashes[path]=FileAccess.get_sha256("res://"+path)
    report.source_hashes=hashes
    FileAccess.open(output.path_join("world153-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    game.queue_free();current_scene=null;await frames(4);await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    RenderingServer.set_render_loop_enabled(true)
    print("BOTANICAL WORLD153: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
    quit(0 if failures.is_empty() else 1)
