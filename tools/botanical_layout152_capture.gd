extends SceneTree
## Capture the complete actual production geometry for an independent checker.
## This collector does not award progress, move actors or certify its own layout.
const World=preload("res://scripts/botanical_world.gd")
const Layout=preload("res://scripts/botanical_layout.gd")
var world: Node3D
var game: Node3D
var output:="/tmp/botanical-layout152"
var visual:=false
var report: Dictionary={}
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
        if arg=="--visual":visual=true
    call_deferred("_run")

func _json(value: Variant) -> Variant:
    if value is Vector2 or value is Vector2i:return [value.x,value.y]
    if value is Vector3:return [value.x,value.y,value.z]
    if value is Rect2:return {"position":_json(value.position),"size":_json(value.size)}
    if value is AABB:return {"position":_json(value.position),"size":_json(value.size)}
    if value is Array or value is PackedVector2Array or value is PackedVector3Array:
        var rows=[]
        for row in value:rows.append(_json(row))
        return rows
    if value is Dictionary:
        var row={}
        for key in value:row[str(key)]=_json(value[key])
        return row
    return value

func _hit(point: Vector3,up:=.25,down:=1.0,excluded: Array[RID]=[]) -> Dictionary:
    var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*up,point-Vector3.UP*down,1)
    query.exclude=excluded
    var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():return {}
    return {"position":hit.position,"normal":hit.normal,"body":str(hit.collider.name),"surface":str(hit.collider.get_meta("audio_surface","unknown"))}

func _floor_exclusions() -> Array[RID]:
    var result: Array[RID]=[]
    for body in game.find_children("*","StaticBody3D",true,false):
        if body.get_meta("audio_surface",&"") in [&"wood",&"metal"]:result.append(body.get_rid())
    return result

func _faces(node: MeshInstance3D) -> PackedVector3Array:
    var faces:=PackedVector3Array()
    for point in node.mesh.get_faces():faces.append(node.global_transform*point)
    return faces

func _walking_export() -> void:
    report.production_context={"scene":game.scene_file_path,"frozen_guards":game.guards.size(),"water_visible_for_layout":true,"access_earned":game.progress.gate_unlatched,"campaign_facts_modified":false,"mission_props_included":true}
    report.rendered_transform_parity=world.collision_geometry.rendered_transform_parity(world)
    for index in range(Layout.STAIR_FLIGHTS.size()):
        var flight: Array=Layout.STAIR_FLIGHTS[index];var a: Vector3=flight[0];var b: Vector3=flight[1]
        for step in range(int(flight[3])):
            var expected: Vector3=a.lerp(b,float(step+1)/float(flight[3]))-Vector3.UP*.07
            for item in world.collision_instances:
                if item.kind!="box" or item.material!="trim" or item.at.origin.distance_to(expected)>.001:continue
                var faces:=PackedVector3Array()
                for point in item.mesh.get_faces():faces.append(item.at*point)
                report.walking_surfaces.append({"id":"stair_%d_tread_%d"%[index,step],"triangles":faces,"batch_key":item.batch_key,"batch_index":item.batch_index});break
    for node in world.find_children("*","MeshInstance3D",true,false):
        if node.name.begins_with("ClosedStairFoundation151") or node.name=="RockBankEscapeSteps151" or node.get_meta("mission150_dynamic",false):report.walking_surfaces.append({"id":str(node.name),"triangles":_faces(node)})
        if node.get_meta("bridge152",false):
            var facts: Dictionary={}
            for row in world.placement_records:
                if row.kind=="canal_bridge":facts=row
            var samples: Array=[];var at: Vector3=facts.root;var direction: Vector2=facts.direction
            for distance in [-3.0,-2.0,-.75,0.0,.75,2.0,3.0]:
                var point: Vector3=at+Vector3(direction.x,0,direction.y)*distance;samples.append({"point":point,"floor_hit":_hit(point,.8,1.0)})
            report.bridges.append({"id":str(node.name),"triangles":_faces(node),"support_samples":samples,"water_y":at.y+.10,"facts":facts})
    for node in game.mission_routes.find_children("*","MeshInstance3D",true,false):report.walking_surfaces.append({"id":"pressure_bridge/"+str(node.get_path()),"triangles":_faces(node),"current_opening":game.mission_routes.opened})
    var names: Dictionary={"main_0":["parked240_approach","entrance_junction"],"main_6":["front_plaza","keyed_guardian_gate"],"main_7":["west_promenade","west_gallery_entrance"],"main_8":["upper_promenade","pavilion_west_step"],"main_5":["west_shore_junction","west_bridge_overlook"],"main_9":["east_bridge_overlook","pump_shore_approach"]}
    for route in Layout.all_paths():
        for end in [0,1]:
            var point: Vector2=route.points[0 if end==0 else -1];var at:=Vector3(point.x,world.surface_height_at(point.x,point.y),point.y);var hit:=_hit(at,2,3)
            var row: Dictionary={"path_id":route.id,"end":end,"name":names[route.id][end] if names.has(route.id) else String(route.id)+"_junction_%d"%end,"point":at,"floor_hit":hit}
            var shape:=CapsuleShape3D.new();shape.height=1.7;shape.radius=.28
            var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.margin=.003
            var floor_y: float=at.y if hit.is_empty() else float(hit.position.y)
            query.transform=Transform3D(Basis.IDENTITY,Vector3(at.x,floor_y+.93,at.z));row.capsule_bottom_clearance=.08;row.capsule_hits=[]
            for body in world.get_world_3d().direct_space_state.intersect_shape(query,16):row.capsule_hits.append(str(body.collider.name))
            report.route_terminals.append(row)

func _run() -> void:
    root.size=Vector2i(1280,720)
    DirAccess.make_dir_recursive_absolute(output)
    game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    for i in range(720):
        await physics_frame
        if bool(game.get("ready_for_play")) and game.guard_navigation!=null and game.guard_navigation.is_ready:break
    if not bool(game.get("ready_for_play")) or game.guard_navigation==null or not game.guard_navigation.is_ready:
        push_error("LAYOUT152: production garden did not become ready");quit(1);return
    world=game.world
    if world.baked_lighting==null or not world.baked_lighting.enabled:
        push_error("LAYOUT152: production baked-light bindings are disabled; refusing visual proof")
        quit(1);return
    game.set_process(false);game.set_physics_process(false)
    game.player.set_physics_process(false);game.player.set_process(false);game.player.hide();game.hud.hide()
    for guard in game.guards:
        guard.set_physics_process(false);guard.set_process(false)
        for animation in guard.find_children("*","AnimationPlayer",true,false):animation.active=false
    # Visual inspection matches the reported post-pump state, while the locked
    # gate and actual campaign facts remain unchanged.
    game.water_flow.set_state(true,true)
    for i in range(5):await physics_frame
    var native:=DisplayServer.get_name()!="headless"
    report={"engine":Engine.get_version_info().string,"native":native,"source_hashes":{},"circulation":Layout.describe(),"paths":[],"plants":[],"soil":[],"lamps":[],"benches":[],"terrain":[],"walking_surfaces":[],"bridges":[],"route_terminals":[],"captures":[],"world_inventory":world.collision_geometry.summary(),"retired_bake_sources":world.baked_lighting.retired_sources.keys() if world.baked_lighting!=null else [],"bake_enabled":world.baked_lighting!=null and world.baked_lighting.enabled,"scope":"Whole authored production layout; actual emitted Mesh faces, roots, supporting ray hits and bench approach capsules. Visual samples include the reported bank/channel/gallery failures, not only four good stair views."}
    for path in ["scripts/botanical_world.gd","scripts/botanical_world151.gd","scripts/botanical_layout.gd","scripts/botanical_lighting.gd","scripts/botanical_collision150.gd","scripts/botanical_waterworks.gd","scripts/botanical_evening.gd","scripts/botanical_garden.gd"]:report.source_hashes[path]=FileAccess.get_sha256("res://"+path)
    for node in world.get_children():
        if not node is MeshInstance3D:continue
        var source:=str(node.get_meta("lightmap_source_id",""))
        if source.begins_with("path:"):
            var faces:=PackedVector3Array()
            for point in node.mesh.get_faces():faces.append(node.transform*point)
            var metadata: Dictionary={}
            for row in world.paving_triangles152:
                if row.source_id==source:metadata=row;break
            report.paths.append({"source_id":source,"id":metadata.get("id",""),"triangles":faces,"route":metadata.get("route",[]),"half_width":metadata.get("half_width",0),"authored_triangles":metadata.get("triangles",PackedVector3Array()),"independent_coordinate_tolerance":.0001})
        if source.begins_with("terrain:"):
            report.terrain.append({"source_id":source,"actual_triangle_count":node.mesh.get_faces().size()/3,"critical_full_resolution":node.get_meta("critical_walk_terrain152",false),"bounds":node.get_aabb()})
    _walking_export()
    var excluded:=_floor_exclusions()
    for original in world.placement_records:
        var row: Dictionary=original.duplicate(true)
        if row.kind in ["ground_plant","bed_plant"]:
            var mesh: Mesh=world.meshes[row.mesh_key]
            row.mesh_bounds=mesh.get_aabb();row.base=Vector3(row.root.x,row.root.y+mesh.get_aabb().position.y*float(row.scale),row.root.z)
            row.floor_hit=_hit(row.base,.22,.9)
            report.plants.append(row)
        elif row.kind=="lamp":
            row.floor_hit=_hit(row.visible_foot,.04,.8,excluded)
            report.lamps.append(row)
        elif row.kind in ["soil_bed","pot_soil"]:report.soil.append(row)
        elif row.kind=="bench":
            row.foot_hits=[]
            for foot in row.feet:row.foot_hits.append(_hit(foot,.12,.8,excluded))
            row.approach_hit=_hit(row.front,.12,.8,excluded)
            var shape:=CapsuleShape3D.new();shape.height=1.7;shape.radius=.28
            var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,row.front+Vector3.UP*.87);query.collision_mask=1;query.margin=.003
            row.approach_capsule_hits=[]
            for hit in world.get_world_3d().direct_space_state.intersect_shape(query,16):row.approach_capsule_hits.append(str(hit.collider.name))
            report.benches.append(row)
    if visual and native:await _captures()
    FileAccess.open(output.path_join("layout152-report.json"),FileAccess.WRITE).store_string(JSON.stringify(_json(report),"  "))
    print("BOTANICAL LAYOUT152 CAPTURE: ",report.paths.size()," paths / ",report.plants.size()," roots / ",report.benches.size()," benches / ",report.soil.size()," explicitsoil surfaces")
    current_scene=null;game.queue_free()
    for i in range(3):await process_frame
    if native:
        for i in range(3):
            call_deferred("_draw_empty");await RenderingServer.frame_post_draw
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    quit(0)

func _draw_empty() -> void:RenderingServer.force_draw(true)

func _captures() -> void:
    var camera:=Camera3D.new();camera.fov=65;camera.far=300;root.add_child(camera);camera.current=true
    var poses=[
        ["bank-west-original",Vector2(-56,-3),Vector2(-56,-13)],
        ["west-promenade-bank",Vector2(-62,4),Vector2(-62,-12)],
        ["east-promenade-turn",Vector2(48,14),Vector2(62,5)],
        ["canal-footbridge-crossing",Vector2(40,-16.5),Vector2(47,-19.1)],
        ["bench-east-canal-original",Vector2(46,-20),Vector2(52,-24)],
        ["bench-east-front",Vector2(55,-20),Vector2(52,-24)],
        ["gallery-promenade-original-row",Vector2(38,-18),Vector2(14,-18)],
        ["gallery-recessed-soil",Vector2(37,-22),Vector2(26,-25.5)],
        ["entry-stair-west-foot",Vector2(-24,48.5),Vector2(-24,30)],
        ["entry-stair-east-foot",Vector2(24,48.5),Vector2(24,30)],
        ["central-stair-foot",Vector2(6,14),Vector2(6,-8)],
        ["central-landing-west-seam",Vector2(-14,12.8),Vector2(-8,11.8)],
        ["upper-stair-foot",Vector2(0,-49),Vector2(0,-67)],
        ["entry-bench-alcove",Vector2(3,56.5),Vector2(9,56.5)],
        ["orchard-pavilion-route",Vector2(22,-88),Vector2(35,-91)],
    ]
    for pose in poses:
        var a: Vector2=pose[1];var b: Vector2=pose[2]
        var ahit:=_hit(Vector3(a.x,world.surface_height_at(a.x,a.y),a.y),2,5)
        var y: float=world.surface_height_at(a.x,a.y) if ahit.is_empty() else float(ahit.position.y)
        camera.position=Vector3(a.x,y+1.65,a.y);camera.look_at(Vector3(b.x,world.surface_height_at(b.x,b.y)+.7,b.y))
        for i in range(4):
            await process_frame;call_deferred("_draw_empty");await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output.path_join(pose[0]+".png"));report.captures.append({"id":pose[0],"camera":camera.position,"target":Vector3(b.x,world.surface_height_at(b.x,b.y)+.7,b.y),"mode":"normal_eye_height_production_culling"})
    # One explicitly instrumented overview disables range culling and height
    # fog for a readable architecture diagram. Normal eye-height pictures above
    # retain the production environment; this diagram makes no FPS/color claim.
    var previous_fog: bool=world.environment.fog_enabled;world.environment.fog_enabled=false
    for node in world.find_children("*","GeometryInstance3D",true,false):node.visibility_range_end=0
    world.set_distance_culling_enabled(false)
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=220;camera.position=Vector3(0,180,-10);camera.rotation_degrees=Vector3(-90,0,0)
    for i in range(4):await process_frame;call_deferred("_draw_empty");await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join("whole-layout-overview.png"));report.captures.append({"id":"whole-layout-overview","mode":"instrumented_orthographic_layout_no_range_culling_or_fog"})
    world.environment.fog_enabled=previous_fog
    camera.queue_free()
