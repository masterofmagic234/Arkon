extends SceneTree
## Production frames for every location; never claim staged frames are replay/FPS.
const State=preload("res://scripts/woodland_journey_state.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
const POSES=[
    [Vector3(0,.65,21),Vector3(0,3,-24)],
    [Vector3(0,.65,21),Vector3(-8,2,-5)],
    [Vector3(-5,.65,13),Vector3(15,3,-10)],
    [Vector3(0,.65,18),Vector3(0,4,-10)],
    [Vector3(-17,.65,14),Vector3(0,1,-2)],
    [Vector3(-23,.65,14),Vector3(0,2,-10)],
    [Vector3(0,.65,8),Vector3(0,2,-16)],
    [Vector3(0,.65,8),Vector3(0,3,-17)],
]
var output="user://journey-visual"
var failures: Array[String]=[]
var report: Array=[]
var gateways: Array=[]
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("JOURNEY VISUAL: "+why)
func draw() -> Image:
    await process_frame;call_deferred("force_frame");await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func force_frame() -> void:RenderingServer.force_draw(true)
func run() -> void:
    check(DisplayServer.get_name()!="headless","native renderer required")
    if not failures.is_empty():quit(1);return
    DirAccess.make_dir_recursive_absolute(output)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1920,1080)
    root.get_node("GameState").start_new_run();root.get_node("GameState").music_muted=true;root.get_node("GameState").sfx_muted=true
    RenderingServer.set_render_loop_enabled(false)
    var old_scale=root.scaling_3d_scale
    for area in range(8):
        var save=State.new();save.region=area
        for i in range(area):save.completed.append(i)
        check(save.save_checkpoint(),"cannot stage region checkpoint")
        var game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
        game.set_physics_process(false);game.set_process_unhandled_input(false);game.player.set_physics_process(false);game.player.input_enabled=false
        for guard in game.guards:guard.set_physics_process(false)
        game.world.set_meta("force_mobile_profile",true);game.world._mobile_profile();game.hud.set_mobile_preview(true)
        game.player.position=POSES[area][0];game.player.camera.look_at(POSES[area][1]);game.hud.message_remaining=0;game.hud._refresh()
        if area==3:game.regional.mirror_states.assign([1,2]);game.regional._trace_light()
        await draw();var image=await draw()
        check(image!=null and image.get_size()==root.size,"bad framebuffer area%d"%area)
        var visible_calls=RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
        var shadow_calls=RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
        var canvas_calls=RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
        var calls=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
        var triangles=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
        check(calls>0 and calls<=260,"area%d draw budget %d"%[area,calls]);check(triangles<=150000,"area%d triangle budget %d"%[area,triangles])
        check(game.hud.map_button.visible,"journey map button missing")
        check(root.size.x*root.size.y*root.scaling_3d_scale*root.scaling_3d_scale<=921605,"3D pixel cap failed")
        var name_="%02d-%s.png"%[area+1,["clearing","orchard","mill","greenhouse","ravine","camp","runes","ancient-grove"][area]]
        image.save_png(output.path_join(name_))
        report.append({"region":area,"title":State.TITLES[area],"calls":calls,"triangles":triangles,"visible_calls":visible_calls,"shadow_calls":shadow_calls,"canvas_calls":canvas_calls,"image":name_})
        print("JOURNEY PROBE: ",report[-1])
        if area==4:
            game.hud._toggle_map();await draw();var map_image=await draw();map_image.save_png(output.path_join("journey-map.png"))
            check(game.hud.map_panel.visible and root.get_node("PauseManager").is_paused,"map failed to pause play")
            game.hud._toggle_map()
        if area in [0,1]:
            var gates=[{"name":"outward","position":Vector3(26,.65,-34),"target":Vector3(26,2,-51)}]
            if area==1:gates.append({"name":"return","position":Vector3(-26,.65,34),"target":Vector3(-26,2,51)})
            for gate in gates:
                game.player.position=gate.position;game.player.camera.look_at(gate.target);game.hud._refresh()
                await draw();var gate_image=await draw()
                var gate_calls=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
                var gate_triangles=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
                check(gate_calls<=260 and gate_triangles<=150000,"trail entrance exceeds phone budget")
                var filename="trail-%d-%s.png"%[area,gate.name];gate_image.save_png(output.path_join(filename))
                gateways.append({"area":area,"name":gate.name,"calls":gate_calls,"triangles":gate_triangles,"image":filename})
        game.queue_free();current_scene=null
        for i in range(4):await process_frame
        check(is_equal_approx(root.scaling_3d_scale,old_scale),"scale leaked between areas")
    State.clear_checkpoint()
    var file=FileAccess.open(output.path_join("journey-evidence.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"regions":report,"gateways":gateways,"failures":failures,"note":"Staged native frames; software GPU is not phone FPS."},"  "));file.close()
    await Teardown.drain_audio(self);RenderingServer.set_render_loop_enabled(true)
    if failures.is_empty():print("WOODLAND JOURNEY VISUAL: PASS — eight actual locations, live map, bounded rendering and scene restoration")
    quit(0 if failures.is_empty() else 1)
