extends "res://tools/botanical_arena152_test.gd"
## Explicit scenario staging on the real authored world. Retreat and re-entry
## use production player input; the legacy outside spawn is separate setup.
func run() -> void:
    Guard=load("res://scripts/woodland_guard.gd")
    var state_=load("res://scripts/botanical_state.gd");state_.clear()
    root.get_node("GameState").start_new_run();root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    root.size=Vector2i(1280,720);DirAccess.make_dir_recursive_absolute(output)
    if visual:RenderingServer.set_render_loop_enabled(false)
    garden=load("res://game.tscn").instantiate();root.add_child(garden);current_scene=garden
    for i in range(600):
        if garden.ready_for_play and garden.guard_navigation.is_ready:break
        await physics_frame
    check(garden.ready_for_play and garden.guard_navigation.is_ready,"garden/navigation not ready")
    garden.set_process(false);garden.set_physics_process(false)
    for guard in garden.guards:guard.set_physics_process(false)
    garden.player.set_physics_process(false)
    garden.progress.installed=true;garden.progress.service_key=true;garden.progress.gate_unlatched=true
    garden._apply_garden_state();garden.stage="cache";await frames(240)
    var cases:Array=[]
    cases.append(await retreat_case())
    cases.append(await legacy_return_case(Vector3(1.5,7,-21.0),"legacy-gate-outside"))
    cases.append(await legacy_return_case(Vector3(6,6.5,-11),"legacy-stairs-outside"))
    report.cases=cases
    var visual_guard:Node3D=garden.tank
    visual_guard.set_physics_process(false)
    report.recovery_timing=recovery_timing_case(visual_guard)
    report.expression=await expression_case(visual_guard)
    report.failures=failures;report.source_hashes={}
    for path in ["res://scripts/woodland_guard.gd","res://scripts/squirrel_3d_visual.gd","res://scripts/botanical_guard_navigation.gd","res://scripts/botanical_garden.gd","res://tools/botanical_guardian153_test.gd"]:
        report.source_hashes[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
    report.scope="Explicit earned-gate/actor fixtures on production world; actual ordinary-input retreat and reentry, full body movement, real accepted recovery hits. No claimed full campaign."
    current_scene=null;garden.queue_free();await frames(4);state_.clear();await Teardown.drain_audio(self);RenderingServer.set_render_loop_enabled(true)
    FileAccess.open(output.path_join("guardian153-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if failures.is_empty():print("BOTANICAL GUARDIAN153: PASS — doorway retreat/reentry, legacy outside recovery, actual weapon hits, locked facing and skinned facial expressions")
    quit(0 if failures.is_empty() else 1)

func recovery_timing_case(actor:Node3D) -> Dictionary:
    # Explicit phase fixture on the real guard API. The previous attack's
    # duration must not normalize the newly authored vulnerability animation.
    var original_final:bool=actor.final_boss
    var rows:Array=[]
    for final_:bool in [false,true]:
        actor.final_boss=final_
        actor.visual.apply_active()
        actor._attack_duration=.42
        actor._begin_recovery()
        var opening:float=actor._timer
        check(is_equal_approx(actor._attack_duration,opening),"recovery still normalizes against the previous attack duration")
        for phase:float in [0.0,.5,.9]:
            actor._timer=opening*(1.0-phase)
            actor._animate(0)
            check(actor.visual.action==&"recover" and is_equal_approx(actor.visual.action_progress,phase),"real guard did not pass its actual recovery opening phase to the visual")
            check(actor.visual.current_mode=="recover","recovery window selected another animation")
            var player:AnimationPlayer=actor.visual.imported_animation_player
            var sampled_phase:float=player.current_animation_position/player.get_animation(&"recover").length
            check(absf(sampled_phase-phase)<.002,"actual recovery clip did not span the vulnerability opening")
            rows.append({"final_boss":final_,"opening_seconds":opening,"normalized_window_phase":phase,"actual_imported_clip_phase":sampled_phase})
    actor.final_boss=original_final
    return {"scope":"Controlled phase fixture calls the actual guard _begin_recovery/_animate; no claim of earned mission progression.","samples":rows}

func retreat_case() -> Dictionary:
    var origin:Vector3=garden.guard_navigation.ground_goal(Vector3(1.5,7,-31))
    var actor:Node3D=await replace_guard(origin)
    stage_player(garden.guard_navigation.ground_goal(Vector3(1.5,7,-26.3)),origin)
    check(await wait_state(actor,"windup",180),"retreat did not begin a real windup")
    var initial_attacks:int=actor._attack_count
    # Back away from the announced line using the real player controller.
    Input.action_press("l1_move_backward")
    for i in range(85):
        await physics_frame
        if garden.player.position.z>-19.5:break
    Input.action_release("l1_move_backward")
    check(garden.player.position.z>-23.8,"actual retreat did not pass through open gate")
    var max_z:float=actor.position.z;var recovery_seen:=false;var accepted_hit:=false;var facing_error:=0.0
    var outside_position:Vector3=garden.player.position
    for i in range(420):
        max_z=maxf(max_z,actor.position.z)
        if actor.state=="charge":
            var face:Vector3=actor.visual.global_basis.z.normalized()
            facing_error=maxf(facing_error,face.angle_to(actor._charge_direction))
        if actor.state=="recover" and not accepted_hit:
            recovery_seen=true
            garden.player.camera.look_at(actor.position+Vector3.UP*1.1)
            var hp_before:int=actor.hp;garden.player.request_fire();await frames(2)
            accepted_hit=actor.hp<hp_before
        await physics_frame
    check(max_z<=actor.GUARDIAN_DOOR_LINE+.04,"retreat lured boss outside onto stairs")
    check(recovery_seen and accepted_hit,"doorway finish did not give a real damage window")
    check(facing_error<.025,"charge face deviated from locked announced direction")
    check(actor._attack_count==initial_attacks,"boss attacked into the outside staircase after retreat")
    await capture_arena("retreat-outside",actor)
    garden.player.look_at(Vector3(1.5,garden.player.position.y,-33));garden.player.camera.rotation.x=0
    Input.action_press("l1_move_forward")
    for i in range(150):
        await physics_frame
        if garden.player.position.z<-26.3:break
    Input.action_release("l1_move_forward")
    check(garden.player.position.z<-25.5,"real player could not reenter arena")
    for i in range(240):
        if actor._attack_count>initial_attacks:break
        await physics_frame
    check(actor._attack_count>initial_attacks,"boss did not resume combat after actual reentry")
    await capture_arena("reentered-arena",actor)
    var result:Dictionary={"case":"actual-input-retreat-and-reentry","maximum_guardian_z":max_z,"outside_player_position":outside_position,"actual_reentry_position":garden.player.position,"recovery_seen":recovery_seen,"real_weapon_hit":accepted_hit,"charge_face_error_radians":facing_error,"attacks_before":initial_attacks,"attacks_after":actor._attack_count}
    actor.set_physics_process(false);garden.player.set_physics_process(false);return result

func legacy_return_case(point:Vector3,name_:String) -> Dictionary:
    var origin:Vector3=garden.guard_navigation.ground_goal(point)
    check(origin.is_finite(),name_+": no actual floor")
    var actor:Node3D=await replace_guard(origin)
    actor.state="stalk"
    stage_player(garden.guard_navigation.ground_goal(Vector3(1.5,7,-30)),origin)
    var max_motion:=0.0;var returned:=false;var recovery_seen:=false;var accepted_hit:=false
    for i in range(1200):
        max_motion=maxf(max_motion,actor.position.distance_to(origin))
        if actor.position.z<actor.GUARDIAN_DOOR_LINE-.5:returned=true;break
        if actor.state=="recover" and not accepted_hit:
            recovery_seen=true;garden.player.camera.look_at(actor.position+Vector3.UP*1.1)
            var hp_before:int=actor.hp;garden.player.request_fire();await frames(2)
            accepted_hit=actor.hp<hp_before
        await physics_frame
    check(returned or (recovery_seen and accepted_hit),name_+": outside guardian neither physically returned nor opened a real hittable recovery")
    check(max_motion>.1,name_+": guardian remained a frozen body")
    if returned:
        for i in range(240):
            if actor._attack_count>0:break
            await physics_frame
        check(actor._attack_count>0,name_+": returned guardian did not resume attacks")
    await capture_arena(name_,actor)
    var result:Dictionary={"case":name_,"explicit_legacy_start":origin,"end":actor.position,"physically_returned":returned,"travel":max_motion,"recovery_seen":recovery_seen,"accepted_recovery_hit":accepted_hit,"attacks":actor._attack_count}
    actor.set_physics_process(false);garden.player.set_physics_process(false);return result

func expression_case(actor:Node3D) -> Dictionary:
    var view=actor.visual;var jaw:int=view.skeleton.find_bone("Jaw")
    check(jaw>=0,"tank missing actual skinned jaw")
    var weighted_vertices:=0
    for mesh in view.model_instance.find_children("*","MeshInstance3D",true,false):
        if mesh.skin==null:continue
        var jaw_binds:Array[int]=[]
        for bind in range(mesh.skin.get_bind_count()):
            var bind_name:StringName=mesh.skin.get_bind_name(bind)
            var bone:int=view.skeleton.find_bone(bind_name) if bind_name!=&"" else mesh.skin.get_bind_bone(bind)
            if bone==jaw:jaw_binds.append(bind)
        for surface in range(mesh.mesh.get_surface_count()):
            var arrays:Array=mesh.mesh.surface_get_arrays(surface)
            var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
            var indices:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
            for vertex in range(arrays[Mesh.ARRAY_VERTEX].size()):
                for influence in range(4):
                    if indices[vertex*4+influence] in jaw_binds and weights[vertex*4+influence]>.01:
                        weighted_vertices+=1;break
    check(weighted_vertices>10,"facial jaw joint is unweighted decoration")
    view.skeleton.reset_bone_poses()
    var jaw_rest:Quaternion=view.skeleton.get_bone_pose_rotation(jaw)
    var poses:Array=[]
    actor.position=garden.guard_navigation.ground_goal(Vector3(1.5,7,-29))
    stage_player(garden.guard_navigation.ground_goal(Vector3(1.5,7,-25.8)),actor.position)
    garden.player.set_physics_process(false)
    for spec in [[&"windup",.45],[&"charge",.4],[&"recover",.5],[&"stomp_windup",.5]]:
        view.apply_active();view.set_action(spec[0],spec[1]);view.face_locked_direction(Vector3.BACK)
        for i in range(12):view.animate_squirrel(0,0,0,Vector3.BACK,1.0/60)
        var q:Quaternion=view.skeleton.get_bone_pose_rotation(jaw)
        var jaw_motion:=q.angle_to(jaw_rest)
        check(jaw_motion>.025,"authored jaw stayed rigid relative to its rest pose in "+str(spec[0]))
        poses.append({"action":spec[0],"actual_jaw_rotation_radians":jaw_motion,"authored_face_motion":true})
        await capture_arena("expression-"+str(spec[0]),actor)
    return {"actual_skinned_jaw":jaw,"jaw_weighted_vertices":weighted_vertices,"poses":poses,"no_added_meshes_or_renderpasses":true}
