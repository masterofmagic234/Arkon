extends SceneTree
var failed:=false
const Probe=preload("res://scripts/botanical_performance_probe.gd")
var initial_frame_cap:=0
func _init() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failed=true;push_error("BOTANICAL PROBE: "+why)
func synthetic(id: String,ms: float,time: int,round_: int=0) -> Dictionary:
    return {"id":id,"round":round_,"midpoint_usec":time,"median_frame_ms":ms,"p95_frame_ms":ms,"fps":1000.0/ms,"frame_count":12,"stable":true,"render_cpu_ms":1.0,"gpu_ms":0.0,"gpu_available":false,"calls":5,"triangles":24}
func estimator_checks() -> void:
    var statistics=Probe.frame_statistics([20.0,20.0,20.0,100.0])
    check(statistics.frame_count==4 and is_equal_approx(statistics.fps,25.0),"wall-time throughput hid a real long frame")
    check(statistics.median_frame_ms==20 and statistics.p95_frame_ms==100,"frame median/p95 omitted the tail")
    var empty=Probe.frame_statistics([])
    check(empty.frame_count==0 and empty.fps==0 and empty.median_frame_ms==0,"empty sample invented a result")
    var before=synthetic("full",20,1000);var control=synthetic("test",10,1500);var after=synthetic("full",22,2000)
    var comparison=Probe.compare_bracket(before,control,after)
    check(comparison.reliable and is_equal_approx(comparison.speedup,2.1),"control did not use its two adjacent time-interpolated baselines")
    var drifting=after.duplicate();drifting.median_frame_ms=40
    comparison=Probe.compare_bracket(before,control,drifting)
    check(not comparison.reliable and comparison.reasons.has("baseline_drift"),"large baseline drift still claimed a reliable rendering regression")
    var compiling=control.duplicate();compiling.stable=false
    check(not Probe.compare_bracket(before,compiling,after).reliable,"an unstable/compiling sample became a reliable comparison")
    var settings={"window":[640,360],"scale_3d":1.0,"msaa":1,"max_fps":0,"vsync":0}
    before.render_settings=settings.duplicate(true);control.render_settings=settings.duplicate(true);after.render_settings=settings.duplicate(true)
    control.render_settings.scale_3d=.5
    check(Probe.compare_bracket(before,control,after).reasons.has("render_settings_changed"),"lowering control resolution silently improved its comparison")
    var analyzer=Probe.new()
    var baseline0=synthetic("full",20,1000);var control0=synthetic("test",10,1500)
    var baseline1=synthetic("full",20,2000);var control1=synthetic("test",16,2500,1);var baseline2=synthetic("full",20,3000,1)
    analyzer.report={"renderer":"gl_compatibility","samples":[baseline0,control0,baseline1,control1,baseline2],"comparisons":[Probe.compare_bracket(baseline0,control0,baseline1),Probe.compare_bracket(baseline1,control1,baseline2)],"stages":[]}
    analyzer._aggregate([["test","Control"]])
    check(not analyzer.report.reliable and not analyzer.report.stages[1].reliable,"contradictory repeated controls were averaged into a confident result")
    # Each adjacent bracket changes <18%, but cumulative drift exceeds18%.
    # This must remain inconclusive even if local normalized ratios agree.
    baseline1=synthetic("full",22,2000);control1=synthetic("test",11,2500,1);baseline2=synthetic("full",24,3000,1)
    analyzer.report={"renderer":"gl_compatibility","samples":[baseline0,control0,baseline1,control1,baseline2],"comparisons":[Probe.compare_bracket(baseline0,control0,baseline1),Probe.compare_bracket(baseline1,control1,baseline2)],"stages":[]}
    analyzer._aggregate([["test","Control"]])
    check(not analyzer.report.reliable and analyzer.report.baseline_drift_fraction>Probe.MAX_BASELINE_DRIFT,"whole-session baseline drift was hidden by locally stable pairs")
    analyzer.reference_147_available=true
    check(analyzer.stage_definitions()[0][0]=="reference_147" and analyzer.stage_definitions().size()==2,"default phone check lost the short current/1.47 and no-foliage comparison")
    analyzer.extended_controls=true
    check(analyzer.stage_definitions().size()==5,"targeted advanced ablations were removed rather than kept optional")
    analyzer.free()
func cancel_checks(game,old_fps: int,old_vsync: int) -> void:
    for background in [false,true]:
        var probe=Probe.new();root.add_child(probe);probe.start(game)
        for i in range(3):await process_frame
        check(probe.captured and probe.busy and Engine.max_fps==0,"paused diagnostic did not temporarily remove the gameplay FPS cap")
        if background:probe.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
        else:probe.close()
        while probe.busy:await process_frame
        check(probe.report.cancelled and not probe.report.reliable,"cancelled diagnostic claimed a complete reliable result")
        check(probe.report.cancel_reason==("application_background" if background else "user_cancelled"),"diagnostic cancellation lost its reason")
        check(Engine.max_fps==old_fps and DisplayServer.window_get_vsync_mode()==old_vsync,"cancel/background leaked the diagnostic cap or VSync")
        check(root.get_node("PauseManager").is_paused and not game.hud.is_processing_input(),"diagnostic cancellation resumed gameplay under its result")
        probe.queue_free();await process_frame
        check(game.hud.is_processing_input(),"cancelled diagnostic did not return HUD input on close")
func run() -> void:
    estimator_checks()
    initial_frame_cap=Engine.max_fps
    if OS.get_cmdline_user_args().has("--native-run"):
        # Exercise the actual protocol and restoration on software CI without
        # confusing this bounded lifecycle fixture with a hardware benchmark.
        root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
        root.size=Vector2i(640,360)
    root.get_node("GameState").start_new_run();root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    var game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    root.get_node("PauseManager").set_paused(true)
    Engine.max_fps=37 # A nondefault user cap catches hardcoded60/uncapped leaks.
    var nested_root=Node3D.new();game.world.add_child(nested_root)
    var nested=MeshInstance3D.new();nested.set_meta("botanical_foliage",true);nested.set_meta("tree_canopy",true);nested_root.add_child(nested)
    var hidden=MeshInstance3D.new();hidden.set_meta("botanical_foliage",true);nested_root.add_child(hidden);hidden.hide()
    var probe=Probe.new();root.add_child(probe);probe.director=game;probe.capture()
    check(not game.hud.is_processing_input(),"probe allowed hidden map/touch controls")
    check(probe.foliage.has(nested) and probe.foliage.has(hidden),"probe missed nested spatial chunks or hidden reference foliage")
    var old_3d=root.disable_3d;var old_ssao=game.world.environment.ssao_enabled;var old_shadows=game.world.get_node("GardenSun").shadow_enabled;var position=game.player.position;var old_msaa=root.msaa_3d;var old_compositor=probe.environment_node.compositor;var old_fps=Engine.max_fps;var old_vsync=DisplayServer.window_get_vsync_mode()
    var old_hp=game.player.get_hp();var old_ammo=game.player.ammo
    for stage in ["reference_147","original_lighting","baked_with_ssao","legacy_geometry","color_alpha","no_canopy","unsorted_foliage","no_ssao","normals_only","no_msaa","no_shadows","no_foliage","ui_only","ui_no_vsync","full"]:
        probe.apply_stage(stage)
        if stage=="reference_147" and probe.reference_147_available:check(probe._reference_enabled(),"1.47 control did not switch the actual world profile")
        if stage=="legacy_geometry" and game.world.rendering_optimizer!=null:check(not game.world.rendering_optimizer.foliage_geometry_enabled,"geometry trial did not switch meshes")
        if stage=="color_alpha":
            for i in range(probe.mask_materials.size()):check(probe.mask_materials[i].shader==probe.atlas_shaders[i],"atlas-alpha trial did not switch sampling")
        if stage=="no_canopy":
            for node in probe.canopy_nodes:check(not node.visible,"canopy trial retained a color or shadow instance")
        if stage=="no_foliage":check(not nested.visible and not hidden.visible,"no-foliage trial retained nested geometry")
        probe.restore()
        check(probe._reference_enabled()==probe.original_reference_147,"stage "+stage+" leaked the whole-world1.47 profile")
        if game.world.baked_lighting!=null:check(game.world.baked_lighting.enabled==probe.original_baked,"stage "+stage+" leaked lightmap/probe bindings")
        check(root.disable_3d==old_3d and game.world.environment.ssao_enabled==old_ssao and game.world.get_node("GardenSun").shadow_enabled==old_shadows,"stage "+stage+" leaked rendering changes")
        check(root.msaa_3d==old_msaa and probe.environment_node.compositor==old_compositor,"stage "+stage+" leaked MSAA or the normals probe")
        check(Engine.max_fps==old_fps and DisplayServer.window_get_vsync_mode()==old_vsync,"stage "+stage+" leaked the user FPS cap or VSync")
        if game.world.rendering_optimizer!=null:check(game.world.rendering_optimizer.foliage_sorting_enabled==probe.original_sorting,"stage "+stage+" leaked foliage ordering")
        if game.world.rendering_optimizer!=null:check(game.world.rendering_optimizer.foliage_geometry_enabled==probe.original_geometry,"probe leaked legacy geometry")
        for i in range(probe.mask_materials.size()):check(probe.mask_materials[i].shader==probe.mask_shaders[i],"stage "+stage+" leaked alpha-mask sampling")
        for i in range(probe.foliage.size()):check(probe.foliage[i].visible==probe.visibility[i],"foliage visibility was not restored")
    check(game.player.position==position and root.get_node("PauseManager").is_paused,"probe changed gameplay while paused")
    check(game.player.get_hp()==old_hp and game.player.ammo==old_ammo,"probe changed player health/ammo")
    probe._deadline_usec=1 # An expired deadline, without waiting120seconds.
    check(not probe._can_continue() and probe.cancel_reason=="time_budget","diagnostic deadline did not stop an unfinished measurement")
    probe.restore()
    check(Engine.max_fps==old_fps and root.get_node("PauseManager").is_paused,"deadline restoration changed the game cap or pause state")
    probe.queue_free();await process_frame
    nested_root.queue_free();await process_frame
    check(root.disable_3d==old_3d,"probe cleanup leaked viewport state")
    check(game.hud.is_processing_input(),"probe cleanup did not return touch input")
    game.hud.sampled_playing=true;game.hud.last_tick=Time.get_ticks_usec()-30000000;game.hud.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
    check(not game.hud.sampled_playing and game.hud.last_tick==0,"background gap contaminated FPS")
    await cancel_checks(game,old_fps,old_vsync)
    if OS.get_cmdline_user_args().has("--native-run"):
        check(DisplayServer.get_name()!="headless","actual on-device-style sampling needs a native renderer")
        var real_probe=Probe.new();root.add_child(real_probe);real_probe.start(game)
        await process_frame
        while real_probe.busy:await process_frame
        var controls=real_probe.stage_definitions()
        check(real_probe.report.stages.size()==controls.size()+2 and not real_probe.report.cancelled,"full native probe did not finish all controls")
        check(real_probe.report.protocol=="bracketed_reverse_order" and real_probe.report.comparisons.size()==controls.size()*2,"native probe omitted reverse-order repeated brackets")
        check(real_probe.report.samples.size()==controls.size()*4+2,"native probe did not return to its production baseline after every control")
        var actual_order=[]
        for sample in real_probe.report.samples:
            if sample.id not in ["full","ui_only"]:actual_order.append(sample.id)
            check(sample.frame_count==sample.intervals_ms.size() and sample.frame_count>0,"native sample has no real frame intervals")
            if sample.stable:check(sample.frame_count>=Probe.MIN_SAMPLE_FRAMES and sample.pipeline_compilations==0,"stable sample lacked its minimum real frames or contained compilation")
            if real_probe.report.renderer=="gl_compatibility":check(not sample.gpu_available and sample.gpu_ms==0,"GL diagnostic invented GPU timing")
            check(sample.gpu_boundary_drain=="readback_before_warmup" and sample.gpu_boundary_drain_ms>=0,"profile boundary left old GPU work in the sampled interval")
            check(sample.render_settings.max_fps==0 and sample.render_settings.vsync==real_probe.report.probe_vsync,"profile switch changed cap/present mode inside a comparison")
            check(is_equal_approx(sample.render_settings.scale_3d,real_probe.report.scale_3d) and sample.render_settings.msaa==old_msaa,"native current/1.47 comparison changed resolution or MSAA")
            check(sample.reference_147_enabled==(sample.id=="reference_147"),"native control did not sample the intended actual world profile")
        var expected_order=[]
        for control in controls:expected_order.append(control[0])
        var reverse=expected_order.duplicate();reverse.reverse();expected_order.append_array(reverse)
        check(actual_order==expected_order,"controls did not reverse their order on the second pass")
        check(real_probe.report.probe_max_fps==0 and real_probe.report.max_fps==old_fps,"probe did not distinguish uncapped throughput from gameplay FPS")
        check(real_probe.report.restored_max_fps==old_fps and real_probe.report.restored_vsync==old_vsync,"native sampling leaked the temporary frame cap or VSync")
        check(real_probe.report.camera_position.size()==3 and real_probe.report.camera_rotation_degrees.size()==3 and real_probe.report.camera_fov>0,"native report lost the reproducible camera pose")
        check(real_probe.report.stages[0].triangles>0 and real_probe.report.stages[0].calls>0,"native report lost its real render workload")
        check(not root.disable_3d and game.world.environment.ssao_enabled==old_ssao and game.world.get_node("GardenSun").shadow_enabled==old_shadows,"native sampling did not restore production rendering")
        check(game.player.position==position and game.player.get_hp()==old_hp and game.player.ammo==old_ammo,"native sampling changed player state")
        await process_frame
        check(root.get_visible_rect().encloses(real_probe.close_button.get_global_rect()),"long report pushed the close button outside the phone screen")
        for arg in OS.get_cmdline_user_args():
            if arg.begins_with("--output="):
                var folder=arg.trim_prefix("--output=");DirAccess.make_dir_recursive_absolute(folder)
                await process_frame;await process_frame
                root.get_texture().get_image().save_png(folder.path_join("performance-probe.png"))
                real_probe.report["acceptance_scope"]="640x360 native protocol/lifecycle acceptance; timings are not device performance evidence"
                FileAccess.open(folder.path_join("performance-probe.json"),FileAccess.WRITE).store_string(JSON.stringify(real_probe.report,"  "))
        real_probe.queue_free();await process_frame
        check(game.hud.is_processing_input(),"completed native probe did not return HUD input on close")
    # A scene transition can destroy the owner while the root-level probe is
    # awaiting a frame. It must still return global settings and finish safely.
    game.world.original_max_fps=11 # The cap before this garden, restored on exit.
    var exit_msaa=game.world.original_msaa
    var leaving_probe=Probe.new();root.add_child(leaving_probe);leaving_probe.start(game)
    for i in range(3):await process_frame
    check(leaving_probe.captured and Engine.max_fps==0,"scene-exit fixture never started the actual diagnostic")
    game.queue_free();await process_frame
    while leaving_probe.busy:await process_frame
    check(leaving_probe.report.cancelled and leaving_probe.report.cancel_reason=="scene_unloaded" and not leaving_probe.report.reliable,"scene deletion left a live or reliable diagnostic")
    check(Engine.max_fps==11 and DisplayServer.window_get_vsync_mode()==old_vsync,"scene deletion overrode the garden's restored entry cap/present mode")
    check(root.msaa_3d==exit_msaa and root.disable_3d==old_3d,"scene deletion carried garden-only MSAA/3D state into the next scene")
    leaving_probe.queue_free();await process_frame
    current_scene=null;root.get_node("PauseManager").resume()
    for i in range(5):await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    Engine.max_fps=initial_frame_cap
    if not failed:print("BOTANICAL PROBE: PASS — repeated baseline brackets, drift/uncertainty, real frame intervals, exact settings restoration and background-safe cancellation")
    quit(1 if failed else 0)
