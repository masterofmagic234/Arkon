extends SceneTree
## Full imported skin acceptance for directional collapse and static corpses.
## --visual --output=... captures actual native animation phases/terrain.
const Visual = preload("res://scripts/squirrel_3d_visual.gd")
const DIRECTIONS = [Vector3(0,0,1),Vector3(0,0,-1),Vector3(1,0,0),Vector3(-1,0,0)]
var failures: Array[String] = []
var output := ""
var visual_mode := false
var raw_rigs := false
var stage: Node3D
var camera: Camera3D
var ground: Node3D
var terrain := "flat"
var report: Dictionary = {"models":[],"terrain":[],"failures":[]}

func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
        elif argument=="--visual":visual_mode=true
        elif argument=="--raw-rigs":raw_rigs=true
    call_deferred("run")

func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("SQUIRREL DEFEAT149: "+why)

func points(actor,records: Array,stride: int=1,body_only: bool=false) -> PackedVector3Array:
    actor.skeleton.force_update_all_bone_transforms()
    var result=PackedVector3Array()
    for record in records:
        var transforms: Array[Transform3D]=[]
        for bind in range(record.mapping.size()):transforms.append(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(record.mapping[bind])*record.mesh.skin.get_bind_pose(bind))
        for vertex in range(0,record.vertices.size(),stride):
            if body_only:
                var body_weight:=0.0
                for influence in range(4):
                    var k=vertex*4+influence
                    if record.body_binds[record.bones[k]]:body_weight+=record.weights[k]
                if body_weight<.9:continue
            var value=Vector3.ZERO
            for influence in range(4):
                var k=vertex*4+influence
                if record.weights[k]>.000001:value+=transforms[record.bones[k]]*record.vertices[vertex]*record.weights[k]
            result.append(value)
    return result

func records(actor) -> Array:
    var result=[]
    for node in actor.model_instance.find_children("*","MeshInstance3D",true,false):
        if node.skin==null:continue
        var mapping=[];var body_binds=[]
        for bind in range(node.skin.get_bind_count()):
            var name: StringName=node.skin.get_bind_name(bind)
            var bone: int=actor.skeleton.find_bone(name) if name!=&"" else node.skin.get_bind_bone(bind)
            mapping.append(bone)
            var label: String=str(actor.skeleton.get_bone_name(bone)).to_lower()
            body_binds.append(not ("tail" in label or "head" in label or "neck" in label or label.begins_with("ear") or "jaw" in label))
        for surface in range(node.mesh.get_surface_count()):
            var arrays=node.mesh.surface_get_arrays(surface)
            result.append({"mesh":node,"vertices":arrays[Mesh.ARRAY_VERTEX],"bones":arrays[Mesh.ARRAY_BONES],"weights":arrays[Mesh.ARRAY_WEIGHTS],"mapping":mapping,"body_binds":body_binds})
    return result

func height_at(x: float) -> float:
    if terrain=="slope":return x*.13
    if terrain=="stairs":return floorf(x/.6)*.12
    return 0.0

func box(size: Vector3,position_: Vector3,rotation_: float=0) -> void:
    var body=StaticBody3D.new();body.position=position_;body.rotation.z=rotation_
    var shape=CollisionShape3D.new();var resource=BoxShape3D.new();resource.size=size;shape.shape=resource;body.add_child(shape)
    if visual_mode:
        var mesh=MeshInstance3D.new();var cube=BoxMesh.new();cube.size=size;mesh.mesh=cube
        var material=StandardMaterial3D.new();material.albedo_color=Color("42494c");mesh.material_override=material;body.add_child(mesh)
    ground.add_child(body)

func make_ground(kind: String) -> void:
    if ground!=null:ground.free()
    terrain=kind;ground=Node3D.new();stage.add_child(ground)
    if kind=="stairs":
        for step in range(-12,13):box(Vector3(.6,.8,16),Vector3((step+.5)*.6,step*.12-.4,0))
    elif kind=="slope":box(Vector3(24,.2,16),Vector3(0,-.101,0),atan(.13))
    else:box(Vector3(24,.2,16),Vector3(0,-.1,0))

func draw_capture(name_: String) -> void:
    if not visual_mode or output.is_empty():return
    await process_frame
    RenderingServer.force_draw(true)
    await process_frame
    root.get_texture().get_image().save_png(output.path_join(name_+".png"))

func make_actor(tank: bool):
    var actor=Visual.new();actor.model_path=Visual.TANK_MODEL_PATH if tank else Visual.MODEL_PATH;actor.target_height=2.4 if tank else 1.6
    # Match the actual guardian scene, including its approved .88 actor scale.
    actor.scale=Vector3.ONE*(.88 if tank else 1.0)
    stage.add_child(actor)
    if raw_rigs:
        var document=GLTFDocument.new();var state=GLTFState.new()
        check(document.append_from_file(actor.model_path,state)==OK,"raw GLB read failed")
        check(actor.setup(document.generate_scene(state)),"raw rig setup failed")
    else:check(actor.setup(),"rig setup failed")
    actor.apply_active()
    return actor

func stage_setup() -> void:
    stage=Node3D.new();root.add_child(stage);current_scene=stage
    if not visual_mode:return
    check(DisplayServer.get_name()!="headless","native framebuffer required")
    root.size=Vector2i(1440,960);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    var world=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("273138");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("cfdae6");env.ambient_light_energy=.7;world.environment=env;stage.add_child(world)
    var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-35,0);sun.light_energy=1.6;sun.shadow_enabled=true;stage.add_child(sun)
    camera=Camera3D.new();camera.position=Vector3(5,4,7);camera.fov=40;stage.add_child(camera);camera.look_at(Vector3(0,.65,0));camera.current=true

func run() -> void:
    stage_setup()
    if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
    for ground_kind in ["flat","slope","stairs"]:
        make_ground(ground_kind)
        await physics_frame
        var worst_penetration:=0.0
        for tank in [false,true]:
            var actor=make_actor(tank);var mesh_records=records(actor)
            actor.position=Vector3(.25,height_at(.25),0)
            var role: String="tank" if tank else "scout"
            for index in range(DIRECTIONS.size()):
                actor.apply_active();actor.animate_squirrel(0,0,2.3,Vector3.ZERO,.13)
                actor.apply_hit();actor.animate_squirrel(0,0,0,Vector3.ZERO,.055)
                var start_root: Basis=actor.basis
                var prehit=points(actor,mesh_records,17)
                actor.prepare_impact(actor.to_global(-DIRECTIONS[index]*4))
                actor.apply_defeated()
                check(actor._defeat_clip!=&"death","incoming impact direction was ignored")
                var selected_clip: String=str(actor._defeat_clip)
                var previous=prehit;var peak_step:=0.0
                for frame in range(121):
                    actor.animate_squirrel(0,0,0,Vector3.ZERO,1.0/60)
                    if frame in [0,2,5,9,17,35,59,89,120]:
                        var skin=points(actor,mesh_records,17)
                        for k in range(mini(previous.size(),skin.size())):
                            if frame==0:peak_step=maxf(peak_step,skin[k].distance_to(previous[k]))
                        previous=skin
                        var phase_minimum:=INF
                        for point in points(actor,mesh_records,3):phase_minimum=minf(phase_minimum,point.y-height_at(point.x))
                        check(phase_minimum>-.045,role+" "+ground_kind+" phase"+str(frame)+" penetrates during live-hit collapse "+str(phase_minimum))
                        if visual_mode and (ground_kind=="flat" or frame in [35,89,120]):
                            camera.position=actor.position+Vector3(4,2.6,5);camera.look_at(actor.position+Vector3(0,.65,0))
                            await draw_capture(role+"_"+ground_kind+"_"+str(index)+"_"+str(frame))
                check(peak_step<actor.target_height*.18,role+" live-hit to collapse pose popped")
                check(actor.basis.is_equal_approx(start_root),role+" whole actor rotated as a plank")
                check(actor.death_settled() and not actor.is_processing(),role+" corpse still evaluates animation")
                var terminal=points(actor,mesh_records)
                var minimum:=INF
                for point in terminal:minimum=minf(minimum,point.y-height_at(point.x))
                worst_penetration=maxf(worst_penetration,-minimum)
                check(minimum>-.045,role+" "+ground_kind+" direction"+str(index)+" penetrates support "+str(minimum))
                var body_gap:=INF
                for point in points(actor,mesh_records,1,true):body_gap=minf(body_gap,point.y-height_at(point.x))
                if ground_kind=="flat":check(body_gap<actor.target_height*.04,role+" torso/limbs float while only tail touches ground")
                var saved_pose=[]
                for bone in range(actor.skeleton.get_bone_count()):saved_pose.append(actor.skeleton.get_bone_pose(bone))
                for frame in range(30):actor.animate_squirrel(0,0,0,Vector3.ZERO,1.0/60)
                for bone in range(saved_pose.size()):check(actor.skeleton.get_bone_pose(bone).is_equal_approx(saved_pose[bone]),role+" held pose changed")
                actor.apply_active();actor.apply_defeated(true)
                check(actor.death_settled() and actor.action_time>=1.79 and not actor.is_processing(),role+" saved dead actor replayed falling")
                if visual_mode and index==0:await draw_capture(role+"_"+ground_kind+"_restored")
                if ground_kind=="flat":report.models.append({"role":role,"direction":index,"clip":selected_clip,"transition_vertex_step":peak_step,"final_body_support_gap":body_gap,"held_pose":true,"restored_without_replay":true})
            actor.free()
        report.terrain.append({"surface":ground_kind,"maximum_final_skin_penetration":worst_penetration})
    report.failures=failures
    if not output.is_empty():
        var file=FileAccess.open(output.path_join("defeat149-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
    if failures.is_empty():print("SQUIRREL DEFEAT149: PASS — both original weighted skins; four hit directions; articulated collapse; flat/slope/stair support; instant saved rest and static held corpses")
    quit(0 if failures.is_empty() else 1)
