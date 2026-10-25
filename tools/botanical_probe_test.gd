extends SceneTree
var failed:=false
func _init() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
    if not ok:failed=true;push_error("BOTANICAL PROBE: "+why)
func run() -> void:
    root.get_node("GameState").start_new_run();root.get_node("GameState").sfx_muted=true;root.get_node("GameState").music_muted=true
    var game=load("res://game.tscn").instantiate();root.add_child(game);current_scene=game
    root.get_node("PauseManager").set_paused(true)
    var probe=load("res://scripts/botanical_performance_probe.gd").new();root.add_child(probe);probe.director=game;probe.capture()
    check(not game.hud.is_processing_input(),"probe allowed hidden map/touch controls")
    var old_3d=root.disable_3d;var old_ssao=game.world.environment.ssao_enabled;var old_shadows=game.world.get_node("GardenSun").shadow_enabled;var position=game.player.position
    for stage in ["no_ssao","no_shadows","no_foliage","ui_only","ui_no_vsync","full"]:
        probe.apply_stage(stage);probe.restore()
        check(root.disable_3d==old_3d and game.world.environment.ssao_enabled==old_ssao and game.world.get_node("GardenSun").shadow_enabled==old_shadows,"stage "+stage+" leaked rendering changes")
        for i in range(probe.foliage.size()):check(probe.foliage[i].visible==probe.visibility[i],"foliage visibility was not restored")
    check(game.player.position==position and root.get_node("PauseManager").is_paused,"probe changed gameplay while paused")
    probe.queue_free();await process_frame
    check(root.disable_3d==old_3d,"probe cleanup leaked viewport state")
    check(game.hud.is_processing_input(),"probe cleanup did not return touch input")
    game.hud.sampled_playing=true;game.hud.last_tick=Time.get_ticks_usec()-30000000;game.hud.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
    check(not game.hud.sampled_playing and game.hud.last_tick==0,"background gap contaminated FPS")
    if OS.get_cmdline_user_args().has("--native-run"):
        check(DisplayServer.get_name()!="headless","actual on-device-style sampling needs a native renderer")
        var real_probe=load("res://scripts/botanical_performance_probe.gd").new();root.add_child(real_probe);real_probe.start(game)
        await process_frame
        while real_probe.busy:await process_frame
        check(real_probe.report.stages.size()==6 and not real_probe.report.cancelled,"full native probe did not finish all stages")
        check(not root.disable_3d and game.world.environment.ssao_enabled==old_ssao and game.world.get_node("GardenSun").shadow_enabled==old_shadows,"native sampling did not restore production rendering")
        for arg in OS.get_cmdline_user_args():
            if arg.begins_with("--output="):
                var folder=arg.trim_prefix("--output=");DirAccess.make_dir_recursive_absolute(folder)
                await process_frame;await process_frame
                root.get_texture().get_image().save_png(folder.path_join("performance-probe.png"))
                FileAccess.open(folder.path_join("performance-probe.json"),FileAccess.WRITE).store_string(JSON.stringify(real_probe.report,"  "))
        real_probe.queue_free();await process_frame
    game.queue_free();current_scene=null;root.get_node("PauseManager").resume()
    for i in range(5):await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    if not failed:print("BOTANICAL PROBE: PASS — staged restoration, paused gameplay, cleanup and background-safe FPS")
    quit(1 if failed else 0)
