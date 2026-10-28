extends SceneTree
var failed:=false
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    if not ok:failed=true;push_error("BOTANICAL LIGHTING: "+message)
func check_material_profile(world: Node3D,lighting,camera: Camera3D) -> void:
    # 1.48 must optimize the visible UV2 receivers too: their ground shader is
    # embedded in the bake, so changing only the hidden source material is inert.
    var profile=world.get("material_profile")
    check(profile!=null and world.has_method("set_reference_147_enabled"),"production material profile or explicit 1.47 control is missing")
    if profile==null or not world.has_method("set_reference_147_enabled"):return
    check(profile.enabled and not world.is_reference_147_enabled(),"production defaulted to the old 1.47 rendering profile")
    var preserved={};var preserved_instances=0;var aquatic_instances=0
    for node in world.find_children("*","GeometryInstance3D",true,false):
        if not node.get_meta("performance_preserve_material_147",false):continue
        preserved[node]=node.material_override
        if node is MultiMeshInstance3D:
            preserved_instances+=node.multimesh.instance_count
            var shape=String(node.get_meta("lightmap_source_id","")).trim_prefix("batch:").get_slice("|",0)
            if shape=="lily_pad":
                aquatic_instances+=node.multimesh.instance_count
                check(node.visible and node.multimesh.mesh==world.meshes.lily_pad,"preserved aquatic pads lost their original visible geometry")
    if DisplayServer.get_name()!="headless":check(aquatic_instances==38,"all 38 original aquatic pads require the explicit material-preservation contract")
    var ground=0;var architecture=0
    for record in profile.records:
        check(not preserved.has(record.node),"profile falsely claims an unsupported preserved material is optimized")
        var active=record.node.material_override if record.surface<0 else record.node.get_active_material(record.surface)
        check(active==record.optimized,"visible material was not replaced by its prepared fast profile")
        if lighting.baked_root.is_ancestor_of(record.node):
            if record.kind=="ground":ground+=1
            elif record.kind=="triplanar":architecture+=1
    check(ground>=25 and architecture>=100,"fast profile missed embedded baked ground or architectural receivers")
    var receivers=[]
    for receiver in lighting.baked_root.get_children():
        if receiver is MeshInstance3D:receivers.append([receiver,receiver.mesh,receiver.transform])
    var gi_data=lighting.gi.light_data
    var settings=[root.scaling_3d_scale,root.msaa_3d,camera.fov,camera.far,world.environment.fog_density,world.get_node("GardenSun").light_energy]
    world.set_reference_147_enabled(true)
    check(world.is_reference_147_enabled() and not profile.enabled,"1.47 reference did not activate as a whole-world control")
    for record in profile.records:
        var active=record.node.material_override if record.surface<0 else record.node.get_active_material(record.surface)
        var override_=record.node.material_override if record.surface<0 else record.node.get_surface_override_material(record.surface)
        check(active==record.original and override_==record.original_override,"1.47 reference did not restore the exact original material/nullable override")
    for node in preserved:check(node.material_override==preserved[node],"reference comparison changed an unsupported original foliage material")
    check(lighting.enabled and lighting.gi.light_data==gi_data,"reference comparison changed the baked irradiance")
    world.set_reference_147_enabled(false)
    check(profile.enabled and not world.is_reference_147_enabled(),"optimized profile did not restore after reference comparison")
    for record in profile.records:
        var active=record.node.material_override if record.surface<0 else record.node.get_active_material(record.surface)
        check(active==record.optimized,"comparison leaked an old receiver material")
    for node in preserved:check(node.material_override==preserved[node],"optimized restoration applied an incompatible material to unrebuilt foliage")
    for receiver in receivers:check(receiver[0].mesh==receiver[1] and receiver[0].transform==receiver[2],"material optimization altered baked geometry or UV binding")
    check(settings==[root.scaling_3d_scale,root.msaa_3d,camera.fov,camera.far,world.environment.fog_density,world.get_node("GardenSun").light_energy],"reference comparison changed resolution, MSAA, camera or lighting")
    print("BOTANICAL MATERIAL PROFILE: ",{"baked_ground":ground,"baked_architecture":architecture,"preserved_foliage_instances":preserved_instances,"preserved_aquatic_instances":aquatic_instances})
func run() -> void:
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    var game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    # A native gate must finish actual GL sky/post-buffer initialization before
    # freeing the scene. The headless path has no GPU resources to settle.
    if DisplayServer.get_name()!="headless":
        for i in range(4):
            await process_frame;RenderingServer.force_draw(true)
    var lighting=game.world.baked_lighting
    check(lighting!=null and lighting.enabled,"production garden did not activate the bake")
    if lighting!=null and lighting.enabled:
        if RenderingServer.get_current_rendering_method()=="gl_compatibility":
            check(game.player.camera.attributes is CameraAttributesPractical,"Compatibility camera exposure is missing")
            check(is_equal_approx(game.player.camera.attributes.exposure_multiplier,.75),"Compatibility surface exposure changed")
            check(game.world.environment.adjustment_enabled and is_equal_approx(game.world.environment.adjustment_contrast,.94),"Compatibility evening contrast changed")
            check(game.world.environment.sky.sky_material is ShaderMaterial,"authored evening sky is missing")
        check(lighting.data.resource_path.ends_with("garden_evening.lmbake"),"daytime lightmap data remained active")
        check(game.world.get_node("GardenSun").light_energy<.3 and game.world.environment.fog_density>=.01,"evening direct light or depth fog is missing")
        check(not game.world.environment.ssao_enabled,"production retained the expensive SSAO/normal prepass")
        check(lighting.data.get_user_count()>=121 and lighting.originals.size()+lighting.retired_sources.size()==121,"static receiver coverage is incomplete")
        check(lighting.data.get_lightmap_textures().size()>0,"lightmap texture data is empty")
        # The dummy renderer does not store probe arrays. Validate them with a
        # real rendering server; never re-save a lightmap through dummy storage.
        if DisplayServer.get_name()!="headless":
            var probes=lighting.data.get("probe_data")
            check(probes is Dictionary and probes.get("points",[]).size()>=748,"playable-space light probes are missing")
        check(game.world.get_node("GardenSun").shadow_enabled,"realtime sun shadows were lost")
        check_material_profile(game.world,lighting,game.player.camera)
        for i in range(lighting.data.get_user_count()):
            var receiver=lighting.gi.get_node_or_null(lighting.data.get_user_path(i))
            check(receiver is MeshInstance3D,"baked UV binding points to missing geometry")
            if receiver is MeshInstance3D:
                check(receiver.mesh.lightmap_size_hint.x>0,"receiver lacks its unwrapped chart size")
                check(receiver.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]!=null,"receiver lacks UV2")
                if receiver.visible and receiver.get_meta("lightmap_source_id","")=="batch:box|trim|0|0":
                    var arrays=receiver.mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
                    var stale_rail=false
                    for j in range(0,indices.size(),3):
                        var p=receiver.transform*((vertices[indices[j]]+vertices[indices[j+1]]+vertices[indices[j+2]])/3.0)
                        if absf(p.x)<31 and absf(p.z-25)<.5 and p.y>3.5 and p.y<4.35:stale_rail=true;break
                    check(not stale_rail,"retired shore railing survived in baked color geometry")
        for source in lighting.originals:check(lighting.probe_sources.has(source) or not source.visible or source.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"original receiver rendered color twice")
        lighting.set_enabled(false)
        check(lighting.gi.light_data==null and not lighting.baked_root.visible and game.world.environment.ssao_enabled,"control retained baked lighting")
        for i in range(lighting.originals.size()):check(lighting.originals[i].visible==lighting.original_visibility[i] and lighting.originals[i].cast_shadow==lighting.original_shadow[i],"control lost original geometry/shadow mode")
        lighting.set_enabled(true)
        check(lighting.gi.light_data==lighting.data and lighting.baked_root.visible and not game.world.environment.ssao_enabled,"bake did not restore after comparison")
        for source in lighting.originals:check(lighting.probe_sources.has(source) or not source.visible or source.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"comparison leaked duplicate color geometry")
    game.queue_free();current_scene=null
    for i in range(5):await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if not failed:print("BOTANICAL LIGHTING: PASS — real baked receivers, fast visible materials, UV2, shadows and exact 1.47 profile restoration")
    quit(1 if failed else 0)
