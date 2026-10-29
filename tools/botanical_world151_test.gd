extends SceneTree
## Reproduce the reported stair cuts, rock-pocket falls and blocked car exit.
const World=preload("res://scripts/botanical_world.gd")
const Circulation=preload("res://scripts/botanical_world151.gd")
const Motion=preload("res://scripts/grounded_step_motion.gd")
var world: Node3D
var actor: CharacterBody3D
var output:="/tmp/botanical-world151"
var visual:=false
var failures: Array[String]=[]
var evidence:={"stair_clearance":[],"stair_walks":[],"path_cutouts":[],"rock_falls":[],"entry":[],"captures":[]}
var camera: Camera3D

class NavigationDirector extends Node3D:
    var world: Node3D
    var water_flow: Node3D
    var mission_routes: Node3D

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
        elif arg=="--visual":visual=true
    call_deferred("run")

func check(ok: bool,message: String) -> void:
    if not ok:failures.append(message);push_error(message)

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(1280,720)
    if visual:RenderingServer.set_render_loop_enabled(false)
    world=World.new();root.add_child(world);current_scene=world;world.build()
    check(world.baked_lighting!=null and world.baked_lighting.baked_root!=null and world.baked_lighting.enabled,"Corrected geometry disabled the garden's retained baked lighting")
    actor=CharacterBody3D.new();actor.collision_layer=4;actor.collision_mask=1
    actor.floor_snap_length=.4;actor.floor_max_angle=deg_to_rad(52)
    var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
    capsule.height=1.70;capsule.radius=.28;shape.shape=capsule;shape.position.y=.85
    actor.add_child(shape);root.add_child(actor)
    camera=Camera3D.new();camera.fov=65;root.add_child(camera);camera.make_current()
    await frames(3)
    await navigation_checks()
    # An eight-square-meter triangle crossing the right stair's x18 edge must
    # retain the exact six-square-meter exterior polygon, not lose a whole
    # triangle. Its sloping Y plane must survive the newly inserted cut edge.
    var cut_sample:=Circulation.clip_path_triangle(PackedVector3Array([Vector3(16,8.4,34),Vector3(20,8.8,34),Vector3(16,9.2,38)]))
    var retained_area:=0.0;var plane_error:=0.0
    for i in range(0,cut_sample.size(),3):
        retained_area+=absf(Vector2(cut_sample[i+1].x-cut_sample[i].x,cut_sample[i+1].z-cut_sample[i].z).cross(Vector2(cut_sample[i+2].x-cut_sample[i].x,cut_sample[i+2].z-cut_sample[i].z)))*.5
    for point in cut_sample:plane_error=maxf(plane_error,absf(point.y-(point.x*.1+point.z*.2)))
    check(absf(retained_area-6.0)<.0001 and plane_error<.00001,"Path clipping dropped an exterior edge or changed its authored surface plane")
    evidence.path_cut_edge={"retained_area_m2":retained_area,"expected_area_m2":6.0,"maximum_plane_error":plane_error}
    for source in world.get_children():
        if not source is MeshInstance3D or not source.get_meta("stair_path_cutout151",false):continue
        var faces: PackedVector3Array=source.mesh.get_faces();var maximum_overlap:=0.0
        for i in range(0,faces.size(),3):
            var polygon:=PackedVector2Array([Vector2(faces[i].x,faces[i].z),Vector2(faces[i+1].x,faces[i+1].z),Vector2(faces[i+2].x,faces[i+2].z)])
            for flight in Circulation.FLIGHTS:
                var rect:=Circulation.stair_footprint(flight)
                var boundary:=PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])
                for overlap in Geometry2D.intersect_polygons(polygon,boundary):
                    var area:=0.0
                    for k in range(overlap.size()):area+=overlap[k].cross(overlap[(k+1)%overlap.size()])*.5
                    maximum_overlap=maxf(maximum_overlap,absf(area))
        check(maximum_overlap<.0001,"A diagonal stone path still cuts across the actual stair treads")
        evidence.path_cutouts.append({"source":str(source.get_meta("lightmap_source_id")),"triangles":faces.size()/3,"maximum_stair_overlap_m2":maximum_overlap})
    check(evidence.path_cutouts.size()==3,"Stair cutout must change exactly three authored stone paths")
    var cache_errors=[]
    for tile in Circulation.TERRAIN_TILES:
        var path="res://assets/level1/botanical/meshes/terrain151_%d.res"%tile
        check(ResourceLoader.exists(path),"Corrected terrain LOD asset is missing")
        if not ResourceLoader.exists(path):continue
        var mesh: ArrayMesh=load(path)
        check(mesh.get_meta("world151_terrain",false) and mesh.get_meta("lod_count",0)>0,"Corrected terrain lost its offline LODs")
        for point: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
            if absf(point.y-World.height_at(point.x,point.z))>.00002:cache_errors.append(str(point))
    check(cache_errors.is_empty(),"Rendered corrected terrain differs from physical/source height")
    evidence.terrain_cache_errors=cache_errors
    for flight in Circulation.FLIGHTS:
        var a: Vector3=flight[0];var b: Vector3=flight[1];var count: int=flight[3]
        var minimum:=INF
        for i in range(count):
            var p:=a.lerp(b,float(i+1)/count)
            var half_depth:=absf(a.z-b.z)/count*.5
            for z in [p.z-half_depth,p.z,p.z+half_depth]:
                var terrain:=World.surface_height_at(p.x,z)
                minimum=minf(minimum,p.y+.01-terrain)
        check(minimum>.07,"Terrain still cuts through a visible stair tread")
        evidence.stair_clearance.append({"start":str(a),"end":str(b),"minimum_visible_clearance":minimum})
        actor.position=a+Vector3(0,.2,1.5);actor.velocity=Vector3.ZERO
        await move_frames(Vector3.ZERO,40)
        var uphill:=await walk_to(b+Vector3(0,0,-1.5),1000)
        var downhill:=await walk_to(a+Vector3(0,0,1.5),1000)
        check(uphill and downhill,"A corrected stair flight is not traversable in both directions")
        evidence.stair_walks.append({"start":str(a),"end":str(b),"uphill":uphill,"downhill":downhill,"returned":str(actor.position)})
        await capture("stairs-%d"%evidence.stair_clearance.size(),a+Vector3(8,3,1),a.lerp(b,.55)+Vector3.UP)
    for side in [-1.0,1.0]:
        for x in [14.5,20.0,25.5,33.0,41.0,46.5,52.0]:
            actor.position=Vector3(side*x,11.4,-11.8);actor.velocity=Vector3.ZERO
            await move_frames(Vector3.ZERO,135)
            var landed:=actor.position
            check(actor.is_on_floor() and actor.position.y>6.3,"Fall behind rocks did not reach the filled shelf")
            var traversed:=await walk_to(Vector3(side*11.35,7,-11.8),1100)
            var returned:=await walk_to(Vector3(side*11.35,7,-16.2),360)
            check(traversed and returned,"A normal capsule remains softlocked behind the rocks")
            evidence.rock_falls.append({"drop":str(Vector3(side*x,11.4,-11.8)),"landed":str(landed),"returned":str(actor.position),"escaped":traversed and returned})
    # The parked car faces inward; either a reverse or a three-point turn has
    # a continuous full-height route through the actual fence and old boundary.
    for x in [-2.5,0.0,2.5]:
        actor.position=Vector3(x,.2,74);actor.velocity=Vector3.ZERO
        await move_frames(Vector3.ZERO,12)
        var outward:=await walk_to(Vector3(x,0,96),500)
        var inward:=await walk_to(Vector3(x,0,74),500)
        check(outward and inward,"Entrance road has a fence/invisible-wall collision across its opening")
        evidence.entry.append({"x":x,"outward":outward,"inward":inward,"end":str(actor.position)})
    await capture("entry-road",Vector3(-4,2.2,66),Vector3(0,1,91))
    await capture("rock-bank-west",Vector3(-22,10,-17),Vector3(-33,6,-10))
    evidence.failures=failures;evidence.world=world.get_meta("world151_circulation")
    evidence.retired_baked_sources=world.baked_lighting.retired_sources
    evidence.retained_baked_lighting_enabled=world.baked_lighting.enabled
    var expected_retired: Array=["batch:box|wood|0|0","path:1","path:2","path:5","terrain:7","terrain:11","terrain:12","terrain:13","terrain:17"]
    var actual_retired: Array=world.baked_lighting.retired_sources.keys()
    expected_retired.sort();actual_retired.sort()
    check(actual_retired==expected_retired,"Circulation repair retired an unexpected baked receiver")
    evidence.scope="Actual world with the garden's1.70m/.28m capsule,4.2m/s walk,18m/s² gravity and production StepMotion. Starts are staged only; no position overrides during falling or walking."
    FileAccess.open(output.path_join("world151-report.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))
    if visual:await draw()
    world.queue_free();actor.queue_free();camera.queue_free();current_scene=null
    await frames(4)
    if visual:
        for i in range(3):await draw()
    RenderingServer.set_render_loop_enabled(true)
    print("BOTANICAL WORLD151: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
    quit(0 if failures.is_empty() else 1)

func move_frames(direction: Vector3,count: int) -> void:
    for i in range(count):
        actor.velocity.x=direction.x*4.2;actor.velocity.z=direction.z*4.2
        actor.velocity.y=-.5 if actor.is_on_floor() else actor.velocity.y-18.0/60
        Motion.move(actor,1.0/60)
        await physics_frame

func navigation_checks() -> void:
    var director:=NavigationDirector.new();director.world=world;root.add_child(director)
    var nav=preload("res://scripts/botanical_guard_navigation.gd").new();director.add_child(nav);nav.setup(director)
    for i in range(180):
        await physics_frame
        if nav.is_ready:break
    check(nav.is_ready,"Production guard navigation did not finish sampling the corrected world")
    var records=[]
    if nav.is_ready:
        for index in range(Circulation.FLIGHTS.size()):
            var start: Vector3=Circulation.FLIGHTS[index][0]
            # x9 is the actual central grid lane beside the pond/pressure
            # bridge. The other three flights use their unobstructed centre.
            var offset:=9.0 if index==2 else 0.0
            var outside: Vector3=nav.ground_goal(start+Vector3(offset,0,3.0))
            var inside: Vector3=nav.ground_goal(start+Vector3(offset,0,-1.0))
            for tank in [false,true]:
                var uphill: bool=nav.segment_clear(outside,inside,tank)
                var downhill: bool=nav.segment_clear(inside,outside,tank)
                check(uphill and downhill,"Production guard navigation rejects a stair-foot seam for flight%d/%s"%[index,"tank" if tank else "scout"])
                records.append({"flight":index,"profile":"tank" if tank else "scout","outside":str(outside),"inside":str(inside),"uphill":uphill,"downhill":downhill})
    evidence.navigation_bottom_seams={"cases":records,"point_count":nav.point_count,"connection_count":nav.connection_count,"query_count":nav.query_count,"scope":"Actual production navigation grid and segment_clear with unchanged20cm step ceiling, physical floor normals/capsule sweeps, both profiles and both directions across allfour stair feet."}
    director.queue_free();await frames(2)

func walk_to(target: Vector3,limit: int) -> bool:
    for i in range(limit):
        var offset:=Vector3(target.x-actor.position.x,0,target.z-actor.position.z)
        if offset.length()<.2:return true
        await move_frames(offset.normalized(),1)
    return false

func frames(count: int) -> void:
    for i in range(count):await physics_frame

func draw() -> void:
    await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw

func force_draw() -> void:RenderingServer.force_draw(true)

func capture(label: String,from: Vector3,to: Vector3) -> void:
    if not visual:return
    camera.position=from;camera.look_at(to)
    for i in range(4):await draw()
    var name_=label+".png";root.get_texture().get_image().save_png(output.path_join(name_));evidence.captures.append(name_)
