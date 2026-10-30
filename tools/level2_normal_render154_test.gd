extends SceneTree
## Native production-loop regression. Preserves the game's canvas_items stretch.
## The optional preceding-garden route is a lifecycle fixture: it emits a Level1
## completion fact and presses the real film skip button after actual decoding.
## This does not claim an earned garden playthrough or Android reproduction.
var level
var from_garden := false
var output := "/tmp/level2-normal-render154"
var report := {"cases":[], "failures":[],"scope":{"automatic_render_loop":true,"production_canvas_items_stretch":true,"native_render_target_and_final_composite":true,"physical_android":false,"fault_injections":false,"freeze_only_for_pixel_comparisons":true}}
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
        if arg=="--from-garden":from_garden=true
    call_deferred("run")
func frames(n: int) -> void:
    for i in range(n): await process_frame
func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    report["os"]=OS.get_name()
    report["engine"]=Engine.get_version_info()
    report["renderer"]=RenderingServer.get_current_rendering_method()
    report["driver"]=RenderingServer.get_current_rendering_driver_name()
    report["preceding_garden_fixture"]=from_garden
    if root.content_scale_mode!=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
        push_error("NORMAL154 requires the production canvas_items stretch");quit(1);return
    if DisplayServer.get_name()=="headless" or not RenderingServer.is_render_loop_enabled():
        push_error("NORMAL154 requires the normal native render loop"); quit(1);return
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=true
    root.size=Vector2i(1280,720)
    if from_garden: await garden_to_film()
    else: root.get_node("SceneFlow").go_to(&"level2")
    for i in range(600):
        await process_frame
        if not root.get_node("SceneFlow")._transitioning: break
    level=current_scene
    if level==null or level.scene_file_path!="res://scenes/level2.tscn":
        push_error("NORMAL154 failed real scene route");quit(1);return
    await frames(8)
    await capture("ordinary-route-start")
    Input.action_press("race_accel")
    await frames(570)
    Input.action_release("race_accel")
    await capture("ordinary-drive-6sec")
    if level.state.race_time<6.0:report.failures.append("ordinary race did not reach six actual race seconds")
    root.size=Vector2i(2582,1220)
    await frames(8)
    await capture("phone-stretch")
    root.get_node("PauseManager").set_paused(true)
    await frames(3)
    root.get_node("PauseManager").resume()
    await frames(8)
    await capture("phone-pause-resume")
    root.size=Vector2i(1280,720)
    await frames(8)
    await capture("desktop-restored")
    await retry_route("same-size-retry")
    root.size=Vector2i(2582,1220)
    await frames(8)
    await retry_route("phone-retry")
    current_scene=null;level.queue_free();level=null
    await frames(6)
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    var hashes:={}
    for path in ["scripts/race_240sx_overlay.gd","scripts/race_squirrel_helicopter.gd","scripts/race_scenery_depth.gd","scripts/race_traffic_3d.gd","scripts/game_level2_pseudo3d.gd","scripts/scene_flow.gd","scenes/level2.tscn","project.godot","tools/level2_normal_render154_test.gd"]:
        hashes[path]=FileAccess.get_sha256("res://"+path)
    report["source_sha256"]=hashes
    FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if report.failures.is_empty(): print("LEVEL2 NORMAL154: PASS")
    else: push_error("LEVEL2 NORMAL154: "+str(report.failures))
    quit(0 if report.failures.is_empty() else 1)
func garden_to_film() -> void:
    var flow=root.get_node("SceneFlow")
    root.get_node("GameState").start_new_run()
    flow.go_to(&"level1")
    for i in range(2400):
        await process_frame
        if not flow._transitioning:break
    if current_scene==null or current_scene.scene_file_path!="res://game.tscn" or flow._transitioning:
        push_error("NORMAL154 real garden failed startup");quit(1);return
    await frames(5)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join("preceding-real-garden.png"))
    report["garden_root_state"]={"msaa":root.msaa_3d,"scale":root.scaling_3d_scale,"occlusion":root.use_occlusion_culling,"disabled":root.disable_3d}
    # A transition fixture: completion fact enters the real film and decodes it.
    # This is not an earned Level1 combat playthrough.
    root.get_node("SignalBus").emit_signal(&"level_completed",&"level1")
    for i in range(600):
        await process_frame
        if not flow._transitioning:break
    var film=current_scene
    if film==null or film.scene_file_path!="res://scenes/park_escape_cutscene.tscn":
        push_error("NORMAL154 real escape film failed route");quit(1);return
    for i in range(600):
        await process_frame
        if film.get_playback_time()>=1.0:break
    report["actual_film_decoded_time"]=film.get_playback_time()
    if film.get_playback_time()<1.0:report.failures.append("preceding escape film failed to decode one actual second")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join("preceding-real-film.png"))
    # Use the actual button signal/handoff, including the decoder's stop/free.
    film.get_node("Frame/SkipButton").emit_signal("pressed")
    for i in range(600):
        await process_frame
        if flow._transitioning:break
    film=null
func retry_route(label: String) -> void:
    root.get_node("SceneFlow").restart_current()
    level=null
    for i in range(600):
        await process_frame
        if not root.get_node("SceneFlow")._transitioning: break
    level=current_scene
    if level==null or level.scene_file_path!="res://scenes/level2.tscn":
        report.failures.append(label+": failed route")
        return
    await frames(8)
    await capture(label)
func difference_samples(a: Image,b: Image) -> int:
    if a.get_size()!=b.get_size():return 0
    var result:=0
    for y in range(0,a.get_height(),3):
        for x in range(0,a.get_width(),3):
            var first:=a.get_pixel(x,y);var second:=b.get_pixel(x,y)
            if maxf(absf(first.r-second.r),maxf(absf(first.g-second.g),maxf(absf(first.b-second.b),absf(first.a-second.a))))>.04:result+=1
    return result
func capture(label: String) -> void:
    var processing: bool=level.is_processing();var physics: bool=level.is_physics_processing()
    level.set_process(false);level.set_physics_process(false)
    await frames(3)
    await RenderingServer.frame_post_draw
    var target=level.car_3d_overlay
    var shown: Image=root.get_texture().get_image()
    var target_image: Image=target.viewport.get_texture().get_image()
    target.model_root.hide()
    await frames(3);await RenderingServer.frame_post_draw
    var no_player_final: Image=root.get_texture().get_image()
    var no_player_target: Image=target.viewport.get_texture().get_image()
    target.model_root.show()
    await frames(3)
    var player_target_pixels:=difference_samples(target_image,no_player_target)
    var player_final_pixels:=difference_samples(shown,no_player_final)
    if player_target_pixels<100:report.failures.append(label+": player absent from target")
    if player_final_pixels<100:report.failures.append(label+": player absent from final composite")
    var alpha_pixels:=0
    for y in range(0,target_image.get_height(),3):
        for x in range(0,target_image.get_width(),3):
            if target_image.get_pixel(x,y).a>.1:alpha_pixels+=1
    if not target.helicopter.warmup_started or not target.helicopter.warmup_complete:report.failures.append(label+": ordinary render-loop warmup branch did not finish")
    var row:={"name":label,"root_size":str(root.size),"root_msaa":root.msaa_3d,"root_3d_scale":root.scaling_3d_scale,"root_occlusion":root.use_occlusion_culling,"viewport_rect":str(level.get_viewport_rect()),"scale_mode":root.content_scale_mode,"scale_size":str(root.content_scale_size),"target_size":str(target.viewport.size),"container_rect":str(target.get_global_rect()),"container_transform":str(target.get_global_transform()),"draws":target.target_draw_calls,"target_alpha_samples":alpha_pixels,"player_target_difference_samples":player_target_pixels,"player_composite_difference_samples":player_final_pixels,"warmup_started":target.helicopter.warmup_started,"warmup_complete":target.helicopter.warmup_complete,"race_time":level.state.race_time,"ready":level.ready_for_play}
    target.hide()
    await frames(3);await RenderingServer.frame_post_draw
    var bare: Image=root.get_texture().get_image()
    target.show()
    await frames(3)
    var difference:=0
    var end:=int(shown.get_height()*.69)
    for y in range(0,end,3):
        for x in range(0,shown.get_width(),3):
            var a:=shown.get_pixel(x,y);var b:=bare.get_pixel(x,y)
            if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.04:difference+=1
    row["composite_difference_samples"]=difference
    shown.save_png(output.path_join(label+".png"));target_image.save_png(output.path_join(label+"-target.png"))
    print("NORMAL154 CASE ",JSON.stringify(row))
    report.cases.append(row)
    if difference<100:report.failures.append(label+": absent vehicle composition")
    level.set_process(processing);level.set_physics_process(physics)
