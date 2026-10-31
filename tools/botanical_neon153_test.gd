extends SceneTree
var failures: Array[String]=[]
var output:="user://neon153"
var visual:=false
var frames: Array[String]=[]
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual":visual=true
        elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL NEON153: "+why)
func run() -> void:
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    var game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    for i in range(12):await physics_frame
    game.player.set_physics_process(false)
    var lights=game.world.find_children("*","OmniLight3D",true,false)
    check(lights.size()==6,"static lighting must not add dynamic sources")
    for light in lights:
        check(not light.shadow_enabled,"neon introduced dynamic shadow rendering")
        check(is_equal_approx(light.light_energy,1.15) and is_equal_approx(light.omni_range,11),"existing light budget changed")
        check(light.light_color.b>.65 and light.light_color.g>.50,"yellow task lights remain")
    var accents=game.world.get_node("StaticNeonWayfinding153")
    check(accents.get_meta("lamp_cores")==14 and accents.get_meta("task_beacons")==4,"important task points or original lamp cores missing")
    check(accents.get_meta("realtime_lights")==0 and accents.get_child_count()==2,"static accents need exactly two batched meshes")
    check(accents.find_children("*","Light3D",true,false).is_empty(),"a beacon added a runtime light")
    for node in accents.get_children():
        check(node is MeshInstance3D and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"accent casts shadows")
        check(node.mesh.get_surface_count()==1,"static accents unexpectedly split into multiple draw surfaces")
        check(node.get_meta("cosmetic_task_light153",false),"light geometry can enter physical collision bake")
    check(game.world.collision_geometry.excluded.get("cosmetic_task_light153",0)==2,"cosmetic pools/cores became collision surfaces")
    for record in game.world.collision_geometry.records:
        check(record.label not in ["NeonCores","StaticLightPools"],"a light pool became a physical floor")
    DirAccess.make_dir_recursive_absolute(output)
    if visual:
        check(DisplayServer.get_name()!="headless","visual evidence requires native renderer")
        root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
        game.hud.root.hide()
        var views=[
            ["entry",Vector3(-4,2.2,86),Vector3(0,2,66)],
            ["pump",Vector3(31,6.2,24),Vector3(23,4.2,19)],
            ["gate",Vector3(9,10.1,-14),Vector3(3,8.5,-23)],
            ["reward",Vector3(4,10,-29),Vector3(0,8.6,-36)],
        ]
        for view in views:
            game.player.camera.global_position=view[1];game.player.camera.look_at(view[2])
            for i in range(3):await process_frame;RenderingServer.force_draw(true)
            var path=output.path_join(view[0]+".png");root.get_texture().get_image().save_png(path);frames.append(path)
    var report={"pass":failures.is_empty(),"failures":failures,"dynamic_lights":lights.size(),"new_dynamic_lights":0,"new_shadow_maps":0,"static_batches":2,"lamp_cores":14,"task_beacons":4,"captures":frames,"renderer":RenderingServer.get_current_rendering_method()}
    var f=FileAccess.open(output.path_join("neon153-report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report));f.close()
    print("BOTANICAL NEON153: ","PASS" if failures.is_empty() else "FAIL")
    game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
