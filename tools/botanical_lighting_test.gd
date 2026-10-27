extends SceneTree
var failed:=false
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    if not ok:failed=true;push_error("BOTANICAL LIGHTING: "+message)
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
            check(game.world.environment.adjustment_enabled and is_equal_approx(game.world.environment.adjustment_contrast,.8),"Compatibility soft contrast is missing")
            check(game.world.environment.sky.sky_material is ShaderMaterial,"linear HDR panorama correction is missing")
        check(not game.world.environment.ssao_enabled,"production retained the expensive SSAO/normal prepass")
        check(lighting.data.get_user_count()>=121 and lighting.originals.size()+lighting.retired_sources.size()==121,"static receiver coverage is incomplete")
        check(lighting.data.get_lightmap_textures().size()>0,"lightmap texture data is empty")
        # The dummy renderer does not store probe arrays. Validate them with a
        # real rendering server; never re-save a lightmap through dummy storage.
        if DisplayServer.get_name()!="headless":
            var probes=lighting.data.get("probe_data")
            check(probes is Dictionary and probes.get("points",[]).size()>=748,"playable-space light probes are missing")
        check(game.world.get_node("GardenSun").shadow_enabled,"realtime sun shadows were lost")
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
    if not failed:print("BOTANICAL LIGHTING: PASS — real baked receivers, textures, UV2, sun shadows and A/B restoration")
    quit(1 if failed else 0)
