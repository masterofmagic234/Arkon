extends SceneTree
## Real imported skins/clips and CPU-skinned contacts. Optional native acceptance
## frames are staged animation views, not an AI/gameplay replay.
const Visual = preload("res://scripts/squirrel_3d_visual.gd")
const CLIPS = ["idle","walk","run","turn_left","turn_right","alert","aim","fire","melee","charge_tell","charge","stomp_tell","stomp","recover","hit","stunned","death"]
var failures: Array[String] = []
var raw_rigs := ""
var output := ""
var visual_mode := false
var stage: Node3D
var camera: Camera3D
var actors: Array = []
var report: Dictionary = {"models":[],"failures":[]}
func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--raw-rigs="): raw_rigs=argument.trim_prefix("--raw-rigs=")
        elif argument.begins_with("--output="): output=argument.trim_prefix("--output=")
        elif argument=="--visual":visual_mode=true
    call_deferred("run")
func check(ok: bool, why: String) -> void:
    if not ok: failures.append(why);push_error("SQUIRREL RIG: "+why)
func _make_actor(tank: bool):
    var actor=Visual.new();actor.model_path=Visual.TANK_MODEL_PATH if tank else Visual.MODEL_PATH;actor.target_height=2.4 if tank else 1.6
    stage.add_child(actor)
    if raw_rigs.is_empty():check(actor.setup(),"runtime model setup failed")
    else:
        var document=GLTFDocument.new();var state=GLTFState.new();var path=raw_rigs.path_join("tank_candidate.glb" if tank else "scout_candidate.glb")
        if not check_load(document.append_from_file(path,state)==OK,path):return actor
        check(actor.setup(document.generate_scene(state)),"raw model setup failed")
    actor.apply_active();actor.animate_squirrel(0,0,0,Vector3.ZERO,0)
    return actor
func check_load(ok: bool,path: String) -> bool:
    check(ok,"cannot load "+path);return ok
func _records(actor) -> Array:
    var records=[]
    for node in actor.model_instance.find_children("*","MeshInstance3D",true,false):
        if node.skin==null:continue
        var mapping=[]
        for bind in range(node.skin.get_bind_count()):
            var name: StringName=node.skin.get_bind_name(bind)
            var bone: int=actor.skeleton.find_bone(name) if name!=&"" else node.skin.get_bind_bone(bind)
            check(bone>=0 and bone<actor.skeleton.get_bone_count(),"unbound skin joint")
            mapping.append(bone)
        for surface in range(node.mesh.get_surface_count()):
            var arrays=node.mesh.surface_get_arrays(surface)
            if arrays.is_empty():continue
            records.append({"mesh":node,"vertices":arrays[Mesh.ARRAY_VERTEX],"bones":arrays[Mesh.ARRAY_BONES],"weights":arrays[Mesh.ARRAY_WEIGHTS],"mapping":mapping})
    return records
func _points(actor,records: Array,stride: int=1) -> PackedVector3Array:
    actor.skeleton.force_update_all_bone_transforms()
    var points=PackedVector3Array()
    var skeleton_to_actor: Transform3D=actor.global_transform.affine_inverse()*actor.skeleton.global_transform
    for record in records:
        var transforms: Array[Transform3D]=[]
        for bind in range(record.mapping.size()):transforms.append(skeleton_to_actor*actor.skeleton.get_bone_global_pose(record.mapping[bind])*record.mesh.skin.get_bind_pose(bind))
        var vertices: PackedVector3Array=record.vertices
        for vertex in range(0,vertices.size(),stride):
            var value=Vector3.ZERO
            for influence in range(4):
                var k=vertex*4+influence
                if record.weights[k]>.000001:value+=transforms[record.bones[k]]*vertices[vertex]*record.weights[k]
            points.append(value)
    return points
func _bounds(points: PackedVector3Array) -> AABB:
    var bounds=AABB(points[0],Vector3.ZERO)
    for point in points:bounds=bounds.expand(point)
    return bounds
func _audit(actor,tank: bool) -> Dictionary:
    check(actor.skeleton_ready,"skeletal presentation missing")
    check(actor.skeleton.get_bone_count()==(87 if tank else 31),"full rest hierarchy changed")
    check(actor.left_arm_bones.size()==3 and actor.right_arm_bones.size()==3,"articulated elbow/hand chain missing")
    check(actor.left_leg_bones.size()==3 and actor.right_leg_bones.size()==3,"articulated knee/ankle chain missing")
    check(actor.tail_bones.size()==6,"dedicated tail chain missing")
    var records=_records(actor);check(not records.is_empty(),"no actual weighted surfaces")
    var influences={};var mixed=0;var vertices=0;var max_error=0.0
    for record in records:
        vertices+=record.vertices.size();check(record.bones.size()==record.vertices.size()*4,"wrong mobile skin influence format")
        for vertex in range(record.vertices.size()):
            var sum=0.0;var n=0
            for slot in range(4):
                var k=vertex*4+slot;var w: float=record.weights[k];sum+=w
                check(is_finite(w) and w>=0 and w<=1.00001,"invalid skin weight")
                if w>.002:influences[record.bones[k]]=true;n+=1
            max_error=maxf(max_error,absf(sum-1));mixed+=int(n>1)
    check(max_error<.0001,"weights are not normalized")
    check(influences.size()>=(55 if tank else 28),"decorative/unweighted skeleton used")
    check(mixed>vertices*.50,"rig still uses rigid region skinning")
    actor.skeleton.reset_bone_poses();var rest_points=_points(actor,records,1);var rest_bounds=_bounds(rest_points)
    check(absf(rest_bounds.size.y-actor.target_height)<.012,"actual weighted rest height changed")
    var max_penetration=0.0;var max_extent=0.0;var charge_clearance=0.0;var clips=[]
    for name in CLIPS:
        check(actor.imported_animation_names.has(StringName(name)),"missing authored clip "+name)
        if not actor.imported_animation_names.has(StringName(name)):continue
        var clip: Animation=actor.imported_animation_player.get_animation(name)
        var peak_keys=0
        for track in range(clip.get_track_count()):peak_keys=maxi(peak_keys,clip.track_get_key_count(track))
        # Godot resamples at 30 Hz and its editor importer also removes
        # redundant keys. Short source clips still have >=17 authored samples;
        # native .24s hit has nine keys. Real skin motion is checked below.
        check(peak_keys>=mini(17,maxi(8,ceili(clip.length*30))),"undersampled/static clip "+name)
        var first: PackedVector3Array
        var motion=0.0
        for phase in [0.0,.19,.43,.68,.91,1.0]:
            actor._play_clip(StringName(name),.12,float(phase))
            var points=_points(actor,records,1 if name in ["walk","run","charge","stomp_tell","death"] else 9)
            var bounds=_bounds(points);max_penetration=maxf(max_penetration,-bounds.position.y);max_extent=maxf(max_extent,bounds.size.length())
            if name=="charge":
                charge_clearance=maxf(charge_clearance,bounds.position.y)
                if phase==1.0:check(absf(bounds.position.y)<.035,"power-lunge failed to return to ground support")
            check(is_finite(bounds.size.length()) and bounds.size.length()<actor.target_height*2.2,"exploded skinned bounds in "+name)
            if first.is_empty():first=points
            else:
                for k in range(mini(first.size(),points.size())):motion=maxf(motion,first[k].distance_to(points[k]))
        check(motion>.0015,"clip does not move the actual mesh: "+name)
        clips.append({"name":name,"tracks":clip.get_track_count(),"peak_sample_keys":peak_keys,"mesh_motion":motion})
    check(max_penetration<.035,"skinned paws/body penetrate the floor: "+str(max_penetration))
    check(charge_clearance>actor.target_height*.06,"charge is still a sliding run instead of an airborne power-lunge")
    actor.apply_active();actor.set_action(&"patrol");actor.animate_squirrel(0,0,1.1,Vector3.BACK,.18);check(actor.current_mode=="walk","patrol gait missing")
    actor.apply_hit();actor.set_action(&"chase");actor.animate_squirrel(0,0,2.5,Vector3.BACK,.05);check(actor.current_mode=="hit","AI state erased real hit reaction")
    if not tank:
        actor.apply_active();actor.set_action(&"aim",.7);actor.animate_squirrel(0,0,0,Vector3.BACK,.18)
        check(actor._throw_prop.visible,"prepared throw has no visible cone")
        var origin: Vector3=actor.throw_origin();check(origin.y>.65 and origin.y<1.45,"throw socket detached from upper body")
        var launched: Node3D=actor.make_thrown_visual()
        check(launched!=null and launched.get_child_count()==actor._throw_prop.get_child_count(),"launched cone changed geometry")
        if launched!=null:
            check(launched.basis.is_equal_approx(actor._throw_prop.global_basis),"launched cone changed world scale/orientation")
            launched.free()
        actor.set_action(&"fire",.41);actor.animate_squirrel(0,0,0,Vector3.BACK,.03);check(actor._throw_prop.visible,"cone vanished before release")
        actor.set_action(&"fire",.43);actor.animate_squirrel(0,0,0,Vector3.BACK,.03);check(not actor._throw_prop.visible,"held cone duplicated after release")
    actor.apply_defeated()
    for frame in range(180):actor.animate_squirrel(0,0,0,Vector3.ZERO,1.0/60)
    var held=actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone("BoneRoot" if tank else "root"))
    for frame in range(90):actor.animate_squirrel(0,0,0,Vector3.ZERO,1.0/60)
    var final_pose=actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone("BoneRoot" if tank else "root"))
    check(held.angle_to(final_pose)<.001 and actor.current_mode=="death" and actor.stunned,"defeated actor restarted or lost its held pose")
    actor.apply_active();check(not actor.stunned and not actor._defeated and actor.action_lock==0,"reset left a death/hit state")
    return {"role":"guardian" if tank else "scout","bones":actor.skeleton.get_bone_count(),"weighted_joints":influences.size(),"vertices":vertices,"mixed_vertices":mixed,"weight_error":max_error,"floor_penetration":max_penetration,"charge_clearance":charge_clearance,"maximum_extent":max_extent,"clips":clips}
func _stage() -> void:
    stage=Node3D.new();root.add_child(stage);current_scene=stage
    if not visual_mode:return
    root.size=Vector2i(1400,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    var we=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("283039");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("c3d0df");env.ambient_light_energy=.65;we.environment=env;stage.add_child(we)
    var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-35,0);sun.light_energy=1.4;sun.shadow_enabled=true;stage.add_child(sun)
    var ground=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(20,20);ground.mesh=plane;var mat=StandardMaterial3D.new();mat.albedo_color=Color("40484c");ground.material_override=mat;stage.add_child(ground)
    camera=Camera3D.new();camera.position=Vector3(5,3,7);camera.fov=35;stage.add_child(camera);camera.look_at(Vector3(0,1,0));camera.current=true
func _draw() -> void:
    await process_frame;RenderingServer.force_draw(true);await process_frame
func run() -> void:
    if visual_mode:check(DisplayServer.get_name()!="headless","native framebuffer required")
    _stage()
    for tank in [false,true]:
        var actor=_make_actor(tank);actor.position.x=1.6 if tank else -1.6;actors.append(actor);report.models.append(_audit(actor,tank))
    if visual_mode and not output.is_empty():
        DirAccess.make_dir_recursive_absolute(output)
        for mode in [&"idle",&"patrol",&"chase",&"aim",&"fire",&"windup",&"charge",&"stomp_windup",&"shockwave",&"recover",&"defeated"]:
            for actor in actors:actor.apply_active();actor.set_action(mode)
            for frame in range(45 if mode==&"defeated" else 21):
                for actor in actors:actor.animate_squirrel(0,0,1.1 if mode==&"patrol" else 2.6 if mode==&"chase" else 0,Vector3.BACK,1.0/30)
            await _draw();root.get_texture().get_image().save_png(output.path_join(str(mode)+".png"))
        for angle in [90,180,270]:
            for actor in actors:actor.apply_active();actor.rotation.y=deg_to_rad(angle)
            await _draw();root.get_texture().get_image().save_png(output.path_join("rest-%d.png"%angle))
    report.failures=failures
    if not output.is_empty():
        DirAccess.make_dir_recursive_absolute(output);FileAccess.open(output.path_join("rig-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    for actor in actors:actor.free()
    stage.queue_free();current_scene=null;await process_frame
    if failures.is_empty():print("SQUIRREL RIG: PASS — genuine skins, 17 sampled clips, limb chains, skinned floor contacts, throw socket and held death")
    quit(0 if failures.is_empty() else 1)
