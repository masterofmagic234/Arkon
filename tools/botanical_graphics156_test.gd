extends SceneTree
## Native integration: quality changes must reduce cosmetic rendering while
## retaining authored geometry, collisions, actors and persistent viewport state.
const Foliage=preload("res://scripts/botanical_foliage148.gd")
const Probe=preload("res://scripts/botanical_performance_probe.gd")
var game: Node3D
var settings: Node
var failures: Array[String]=[]
var output:="/tmp/botanical-graphics156"
var report: Dictionary={"poses":[],"profiles":[]}

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL GRAPHICS156: "+why)

func frames(count: int) -> void:
    for i in range(count):await physics_frame

func root_state() -> Dictionary:
    return {"msaa":root.msaa_3d,"scale":root.scaling_3d_scale,"max_fps":Engine.max_fps,"occlusion":root.use_occlusion_culling,"lod":root.mesh_lod_threshold}

func physical_state() -> Dictionary:
    var state: Dictionary={}
    for node: CollisionShape3D in game.find_children("*","CollisionShape3D",true,false):
        state[node.get_instance_id()]=[node.shape.get_rid(),node.transform,node.disabled]
    for node: CollisionObject3D in game.find_children("*","CollisionObject3D",true,false):
        state[node.get_instance_id()]=[node.collision_layer,node.collision_mask]
    return state

func actor_state() -> Array:
    var result: Array=[]
    for guard in game.guards:result.append([guard.get_instance_id(),guard.position,guard.is_physics_processing()])
    result.append([game.player.get_instance_id(),game.player.position,game.player.is_physics_processing()])
    return result

func profile(name_: String,step:=0) -> Dictionary:
    var result: Dictionary=settings.get_level_settings(&"level1").duplicate(true)
    result.profile=name_;result.dynamic_step=step
    result.moon_shadows=name_!="low"
    result.shadow_distance=0.0 if name_=="low" else (30.0 if name_=="balanced" else 55.0)
    result.material_normal_distance=0.0 if name_=="low" else (8.0 if name_=="balanced" else 14.0)
    result.decorative_lights=name_!="low"
    result.decorative_light_range_scale=0.0 if name_=="low" else (.7 if name_=="balanced" else 1.0)
    return result

func run() -> void:
    check(DisplayServer.get_name()!="headless","native GL required; headless skips foliage construction")
    settings=root.get_node_or_null("GraphicsSettings")
    check(settings!=null,"persistent GraphicsSettings autoload missing")
    if not failures.is_empty():quit(1);return
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    for tick in range(720):
        await physics_frame
        if game.ready_for_play and game.guard_navigation.is_ready:break
    check(game.ready_for_play and game.guard_navigation.is_ready,"production garden failed to become ready")
    game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
    for guard in game.guards:guard.set_process(false);guard.set_physics_process(false)
    game.hud.hide();game.weapon.hide()
    var world=game.world
    var optimizer=world.rendering_optimizer
    var foliage=optimizer.mobile_foliage
    check(not world._owns_viewport_settings and world.original_msaa==-1 and world.original_max_fps==-1,"garden captured stale global settings")
    check(world.baked_lighting!=null and world.baked_lighting.enabled,"production baked lighting missing")
    var physics_before:=physical_state();var actors_before:=actor_state()
    var buffers: Dictionary={};var meshes: Dictionary={}
    for node in foliage.nodes:
        if node is MultiMeshInstance3D:buffers[node]=node.multimesh.buffer
        elif node is MeshInstance3D:meshes[node]=node.mesh.get_rid()
    var initial_uploads: int=foliage.construction_upload_count
    var initial_mode: String=String(settings.get_summary().mode)
    var snapshot:=root_state()
    for name_ in ["high","low","balanced","low","high"]:
        world.apply_graphics_profile(profile(name_))
        check(root_state()==snapshot,"local profile changed root viewport/FPS")
        check(physical_state()==physics_before and actor_state()==actors_before,"graphics profile changed collision or gameplay actors")
        var local: Dictionary=Foliage.quality_settings(name_)
        check(foliage.quality==local,"production foliage did not receive selected profile")
        check(is_equal_approx(world.performance_herb_material.get_shader_parameter("fade_end"),local.herb_fade.y),"actual shared herb material retained high fade distance")
        for chunk in foliage.chunks:
            if chunk.kind=="far_crown":check(chunk.node.visibility_range_end==176.0,"low profile removed distant skyline")
        for material: ShaderMaterial in world.material_profile.copies.values():
            if material.shader==world.material_profile.TRIPLANAR:
                check(is_equal_approx(material.get_shader_parameter("normal_detail_distance"),float(profile(name_).material_normal_distance)),"visible baked receiver missed normal quality")
        check(world.get_node("GardenSun").shadow_enabled==(name_!="low"),"moon shadow profile ignored")
        for child in world.get_node("EveningLanterns").get_children():
            if child is OmniLight3D:check(child.visible==(name_!="low"),"decorative light quality ignored")
        check(world.baked_lighting.enabled,"quality disabled baked illumination")
        report.profiles.append({"profile":name_,"quality":foliage.quality.duplicate(true)})
    for pose in [["entry",Vector3(0,1.6,65),Vector3(0,4,-35)],["concept",Vector3(-22,4.6,22),Vector3(0,6,-47)],["forest",Vector3(11,2.6,48),Vector3(26,10,52)]]:
        game.player.camera.global_position=pose[1];game.player.camera.look_at(pose[2])
        var workloads: Dictionary={}
        for name_ in ["high","low"]:
            # Exercise the real selector as well as local geometry settings:
            # image pairs include the actual root pixel/MSAA budget of each tier.
            settings.set_mode(name_);settings.apply_root_viewport()
            optimizer.update(game.player.camera)
            workloads[name_]=foliage.summary(game.player.camera)
            await process_frame;RenderingServer.force_draw(true)
            workloads[name_]["native_draw_calls"]=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
            workloads[name_]["native_triangles"]=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
            workloads[name_]["root_settings"]=root_state()
            workloads[name_]["policy"]=settings.get_level_settings(&"level1").duplicate(true)
            var image_name: String=String(pose[0])+"-"+name_+".png"
            check(root.get_texture().get_image().save_png(output.path_join(image_name))==OK,"failed to save native image"+image_name)
            workloads[name_]["image"]=image_name
        check(workloads.low.estimated_submitted_triangles<workloads.high.estimated_submitted_triangles,"low profile failed to reduce submitted cosmetic geometry at"+pose[0])
        report.poses.append({"pose":pose[0],"high":workloads.high,"low":workloads.low})
    settings.set_mode(initial_mode);settings.apply_root_viewport()
    world.apply_graphics_profile(profile("low",2))
    check(foliage.quality.herb_end<Foliage.quality_settings("low").herb_end,"dynamic floor did not trim decorative herbs")
    optimizer.set_enabled(false)
    world.apply_graphics_profile(profile("balanced"))
    for node in foliage.nodes:check(node.visibility_range_end==0,"profile toggled native rejection back on during diagnostic culling-off")
    optimizer.set_enabled(true)
    for chunk in foliage.herb_chunks:check(is_equal_approx(chunk.near.visibility_range_end,58.0),"range restoration retained previous quality metadata")
    for node in buffers:check(node.multimesh.buffer==buffers[node],"profile rewrote immutable MultiMesh buffer")
    for node in meshes:check(node.mesh.get_rid()==meshes[node],"profile rebuilt authored near foliage mesh")
    check(foliage.construction_upload_count==initial_uploads,"quality constructed new GPU buffers")
    check(physical_state()==physics_before and actor_state()==actors_before,"profile/camera sequence changed gameplay")
    settings.apply_root_viewport();root.size=Vector2i(2400,1080);await frames(2)
    settings.apply_root_viewport();snapshot=root_state();world._mobile_profile()
    check(root_state()==snapshot,"garden resize path overrode persistent root profile")
    var probe=Probe.new();root.add_child(probe);probe.director=game;probe.capture()
    check(probe._adaptation_token>=0,"diagnostic failed to suspend adaptation")
    probe.apply_stage("no_msaa");Engine.max_fps=0
    probe._cancel("user_cancelled");probe.restore();probe.captured=false
    var expected: Dictionary=settings.get_level_settings(&"level1")
    check(root.msaa_3d==int(expected.msaa_3d) and Engine.max_fps==int(expected.target_fps),"cancel restored stale viewport/FPS")
    check(probe._adaptation_token==-1 and world.graphics_profile==expected,"cancel did not return profile ownership")
    probe.queue_free();await frames(2)
    # Simulate a replacement acquiring root ownership before the old scene's
    # asynchronous diagnostic finishes; old teardown must not undo the new cap.
    probe=Probe.new();root.add_child(probe);probe.director=game;probe.capture()
    var replacement=Node.new();root.add_child(replacement);settings.enter_level(&"level2",replacement)
    settings.apply_root_viewport();snapshot=root_state()
    game.queue_free();current_scene=null;await frames(4)
    check(root_state()==snapshot,"old garden/probe teardown overwrote replacement root settings")
    check(probe.cancelled and probe._adaptation_token==-1,"scene unload leaked adaptation suspension")
    probe.queue_free();settings.leave_level(replacement);replacement.queue_free();await frames(2)
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    RenderingServer.set_render_loop_enabled(true)
    report["physics_objects_checked"]=physics_before.size();report["actors_checked"]=actors_before.size()
    report["immutable_buffers_checked"]=buffers.size();report["immutable_meshes_checked"]=meshes.size()
    report["renderer"]=RenderingServer.get_current_rendering_method();report["failures"]=failures
    report["note"]="Native profile/configuration/geometry/ownership acceptance. No physical Redmi10 FPS inference."
    FileAccess.open(output.path_join("botanical-graphics156-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BOTANICAL GRAPHICS156: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
    quit(0 if failures.is_empty() else 1)
