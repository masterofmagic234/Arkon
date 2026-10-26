extends SceneTree
## Repeatable native render workload. Software-GPU timings are not phone FPS.
const POSES=[
    ["entry",Vector3(0,.65,65),Vector3(0,11,-30)],
    ["concept-view",Vector3(-22,3.65,22),Vector3(0,6,-47)],
    ["pond",Vector3(25,3.65,31),Vector3(0,8,-20)],
    ["conservatory",Vector3(0,7.65,-19),Vector3(0,14,-38)],
    ["upper-garden",Vector3(-23,12.65,-88),Vector3(26,15,-61)],
    ["entrance-reverse",Vector3(0,.65,60),Vector3(0,3,80)],
    ["west-ramp",Vector3(-56,5,-5),Vector3(-40,9,-45)],
    ["east-ramp",Vector3(54,9,-61),Vector3(45,17,-79)],
    ["p60-west",Vector3(-51.6,5.45,-2.5),Vector3(-10.1576467047,-11.5183974773,-23.9816755676)],
    ["p60-entry",Vector3(0,.65,65),Vector3(3.4745514651,-2.7577871374,15.3115991062)],
]
var output="user://botanical-benchmark"
var frames=24
var reference=false
var legacy_foliage=false
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
        if arg.begins_with("--frames="):frames=int(arg.trim_prefix("--frames="))
        if arg=="--reference":reference=true
        if arg=="--legacy-foliage":legacy_foliage=true
    call_deferred("run")
func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1600,1000);root.msaa_3d=Viewport.MSAA_2X
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    var game=load("res://game.tscn").instantiate()
    if reference:game.set_meta("reference_rendering",true)
    root.add_child(game);current_scene=game
    game.set_physics_process(false);game.player.set_physics_process(false);game.player.set_process_unhandled_input(false)
    for guard in game.guards:guard.set_physics_process(false)
    game.world.set_meta("force_mobile_profile",true);game.world._mobile_profile();game.hud.set_mobile_preview(true)
    game.hud.hide();game.weapon.hide()
    for label in game.find_children("*","Label3D",true,false):label.hide()
    var rid=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(rid,true)
    if reference:
        await draw();await draw()
        RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM,true,.5,2,50,300)
    if legacy_foliage:game.world.rendering_optimizer.set_foliage_geometry_enabled(false)
    var results=[]
    for pose in POSES:
        root.size=Vector2i(2582,1220) if pose[0].begins_with("p60-") else Vector2i(1600,1000)
        game.world._mobile_profile()
        game.player.position=pose[1];game.player.camera.look_at(pose[2])
        for i in range(8):await draw()
        var times=[];var cpu=[];var gpu=[]
        for i in range(frames):
            var start=Time.get_ticks_usec();await draw();times.append((Time.get_ticks_usec()-start)/1000.0)
            cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid));gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
        times.sort();cpu.sort();gpu.sort()
        var r={"view":pose[0],"window":str(root.size),"scale_3d":root.scaling_3d_scale,"calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"median_ms":times[times.size()/2],"p95_ms":times[mini(times.size()-1,ceili(times.size()*.95)-1)],"render_cpu_ms":cpu[cpu.size()/2],"render_gpu_ms":gpu[gpu.size()/2]}
        if game.world.rendering_optimizer!=null:r["cull_cpu_us"]=game.world.rendering_optimizer.last_update_usec
        if game.world.rendering_optimizer!=null:r["foliage"]=game.world.rendering_optimizer.foliage_workload(game.player.camera)
        results.append(r);print("BOTANICAL BENCHMARK: ",JSON.stringify(r))
        root.get_texture().get_image().save_png(output.path_join(pose[0]+".png"))
        await capture_foliage_mask(game,output.path_join(pose[0]+"-foliage.png"))
    FileAccess.open(output.path_join("benchmark.json"),FileAccess.WRITE).store_string(JSON.stringify({"views":results,"frames":frames,"reference":reference,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"note":"Identical scene/cameras/MSAA2/921600 pixel cap. Static native rendering, not device FPS."},"  "))
    game.queue_free();current_scene=null
    for i in range(5):await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self);RenderingServer.set_render_loop_enabled(true);quit()
func draw() -> void:
    await process_frame;call_deferred("force_draw");await RenderingServer.frame_post_draw
func force_draw() -> void:RenderingServer.force_draw(true)

var mask_materials: Dictionary={}
func coverage_material(source: Material,white: bool) -> Material:
    var key=[source,white]
    if mask_materials.has(key):return mask_materials[key]
    var material=source.duplicate()
    if material is ShaderMaterial:
        var code=source.shader.code
        code=code.insert(code.find(";")+1,"\nrender_mode unshaded;\n")
        code=code.insert(code.rfind("}"),"\nALBEDO=vec3(%s); EMISSION=vec3(0.0);\n"%("1.0" if white else "0.0"))
        var shader=Shader.new();shader.code=code;material.shader=shader
    elif material is BaseMaterial3D:
        material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        material.albedo_color=Color(0,0,0,source.albedo_color.a);material.albedo_texture=null
        material.emission_enabled=false
    mask_materials[key]=material
    return material
func capture_foliage_mask(game,path: String) -> void:
    var nodes=[];var meshes={}
    for node in game.find_children("*","GeometryInstance3D",true,false):
        var white=node.get_meta("botanical_foliage",false)
        if node.material_override!=null:
            nodes.append([node,node.material_override]);node.material_override=coverage_material(node.material_override,white)
        elif node is MeshInstance3D:
            for i in range(node.mesh.get_surface_count()):
                var source=node.get_active_material(i)
                if source==null:source=StandardMaterial3D.new()
                nodes.append([node,node.get_surface_override_material(i),i]);node.set_surface_override_material(i,coverage_material(source,false))
        elif node is MultiMeshInstance3D:
            var mesh=node.multimesh.mesh
            if meshes.has(mesh):continue
            var original=[]
            for i in range(mesh.get_surface_count()):
                original.append(mesh.surface_get_material(i))
                mesh.surface_set_material(i,coverage_material(original[-1],white))
            meshes[mesh]=original
    var env=game.world.environment
    var original_env=[env.background_mode,env.background_color,env.ssao_enabled,env.fog_enabled]
    env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK;env.ssao_enabled=false;env.fog_enabled=false
    var sun=game.world.get_node("GardenSun");var shadow=sun.shadow_enabled;sun.shadow_enabled=false
    for i in range(3):await draw()
    root.get_texture().get_image().save_png(path)
    sun.shadow_enabled=shadow
    env.background_mode=original_env[0];env.background_color=original_env[1];env.ssao_enabled=original_env[2];env.fog_enabled=original_env[3]
    for entry in nodes:
        if entry.size()==2:entry[0].material_override=entry[1]
        else:entry[0].set_surface_override_material(entry[2],entry[1])
    for mesh in meshes:
        for i in range(mesh.get_surface_count()):mesh.surface_set_material(i,meshes[mesh][i])
