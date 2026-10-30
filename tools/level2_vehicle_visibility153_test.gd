extends SceneTree
## A surface lifecycle regression for the real shared vehicle render target.
## No car sprite fallback, position correction or driving-physics changes.
var level: Node2D
var output := "/tmp/level2-visibility153"
var native := false
var baseline_source := ""
var failures: Array[String] = []
var cases: Array[Dictionary] = []

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):
            output = arg.trim_prefix("--output=")
        if arg.begins_with("--baseline-source="):
            baseline_source = arg.trim_prefix("--baseline-source=")
    call_deferred("run")

func run() -> void:
    native = DisplayServer.get_name() != "headless"
    DirAccess.make_dir_recursive_absolute(output)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.size = Vector2i(1280, 720)
    root.get_node("GameState").music_muted = true
    root.get_node("GameState").sfx_muted = true
    if native:
        RenderingServer.set_render_loop_enabled(false)
    await enter_level()
    if not failures.is_empty(): await finish(); return
    await early_drive()
    await assert_visible("early-race-desktop")
    if not baseline_source.is_empty():
        await reproduce_silent_loss(true)
        await finish()
        return
    await reproduce_silent_loss(false)
    await reproduce_silent_scenario_loss()
    for yaw in [1.1, -1.1, 0.0]:
        level.controller.player.heading_yaw = yaw
        level._process(1.0 / 60.0)
        await assert_visible("orbit-" + str(yaw))
    root.size = Vector2i(2582, 1220)
    await frames(3)
    await assert_visible("phone-resize")
    var target = level.car_3d_overlay
    var before: int = target.target_restore_count
    root.get_node("PauseManager").set_paused(true)
    await lose_surface()
    root.get_node("PauseManager").resume()
    await frames(3)
    check(target.target_restore_count > before, "Pause resume did not restore the vehicle render target")
    await assert_visible("resume-after-surface-loss")
    for notification_id in [Node.NOTIFICATION_APPLICATION_FOCUS_IN, Node.NOTIFICATION_APPLICATION_RESUMED]:
        before = target.target_restore_count
        await lose_surface()
        target.notification(notification_id)
        await frames(3)
        check(target.target_restore_count > before, "Application surface notification did not restore the vehicle target")
        await assert_visible("focus" if notification_id == Node.NOTIFICATION_APPLICATION_FOCUS_IN else "application-resume")
    root.size = Vector2i(1280, 720)
    await frames(3)
    await assert_visible("resize-back-to-desktop")
    var old_world_id: int = target.world_root.get_world_3d().get_instance_id()
    await leave_level()
    root.size = Vector2i(1280, 720)
    await enter_level()
    check(level.car_3d_overlay.world_root.get_world_3d().get_instance_id() != old_world_id, "Retry reused the previous vehicle scenario")
    await early_drive()
    await assert_visible("scene-reentry")
    await leave_level()
    await enter_routed_level()
    await assert_visible("real-loading-route-start")
    var routed_restores: int = level.car_3d_overlay.target_restore_count
    for tick in range(36):
        level._process(1.0 / 60.0)
        if native: await draw(1)
        else: await process_frame
    check(level.car_3d_overlay.target_restore_count == routed_restores, "Healthy rendering keeps rebuilding the target")
    await assert_visible("healthy-target-continuous-monitor")
    await finish()

func enter_routed_level() -> void:
    var flow = root.get_node("SceneFlow")
    flow.go_to(&"level2")
    for tick in range(600):
        await process_frame
        if not flow._transitioning: break
    check(not flow._transitioning, "Real loading route did not finish")
    level = current_scene
    check(is_instance_valid(level) and level.scene_file_path == "res://scenes/level2.tscn", "Real loading route did not enter Level2")
    if not is_instance_valid(level): return
    check(level.ready_for_play, "Real loading route dismisses cover without vehicle presentation")
    level.set_physics_process(false)
    level.set_process(false)
    # Preserve the ordinary countdown/start, unlike the separate controlled
    # early-chase poses above. Input travels through production sampling and
    # the unchanged real fixed-step controller after the real loading router.
    Input.action_press("race_accel")
    for tick in range(600): level._physics_process(1.0 / 60.0)
    Input.action_release("race_accel")
    level._process(1.0 / 60.0)
    check(level.state.race_started and level.state.race_time > 6.0 and level.controller.player.speed > 5, "Real route failed ordinary countdown and acceleration")

func enter_level() -> void:
    root.get_node("PauseManager").resume()
    level = load("res://scenes/level2.tscn").instantiate()
    if not baseline_source.is_empty():
        var old_script := GDScript.new()
        old_script.source_code = FileAccess.get_file_as_string(baseline_source).replace("class_name Race240SXOverlay", "")
        check(old_script.reload() == OK, "Baseline script does not compile")
        level.get_node("Car3DOverlay").set_script(old_script)
    root.add_child(level)
    current_scene = level
    for tick in range(60):
        if level.car_3d_overlay.is_model_ready(): break
        await process_frame
    check(level.car_3d_overlay.is_model_ready(), "Vehicle model never initialized")
    if not level.car_3d_overlay.is_model_ready(): return
    var target = level.car_3d_overlay
    check(target.viewport.own_world_3d, "Vehicle scene does not own its 3D world before startup")
    check(target.viewport.get_camera_3d() == target.camera, "Vehicle camera is not current in its own viewport")
    check(level.find_children("*", "SubViewport", true, false).size() == 1, "Visibility repair allocated another viewport")
    if native:
        check(not target.target_drawn and not level.ready_for_play, "Native loading completed before any vehicle target draw")
    else:
        check(level.ready_for_play, "Headless level readiness waits on a framebuffer")
    level.set_physics_process(false)
    level.set_process(false)
    level.state.race_started = true
    level.state.countdown = 0.0
    level.hud_panel.hide_countdown()
    level._process(1.0 / 60.0)

func early_drive() -> void:
    # The user's screenshot is six seconds into the real early chase. Drive
    # that state through production input and fixed-step vehicle simulation.
    Input.action_press("race_accel")
    for tick in range(375):
        level._physics_process(1.0 / 60.0)
    Input.action_release("race_accel")
    level._process(1.0 / 60.0)
    check(level.state.race_time >= 6.2 and level.controller.player.speed > 5, "Early-race fixture did not advance through production driving")

func lose_surface() -> void:
    var target = level.car_3d_overlay
    # Reproduce the observable result of a replaced Android surface: the
    # vehicle target has been cleared and has lost its 3D/current-camera state.
    # Notifications must restore ownership, not substitute a painted car.
    target.viewport.disable_3d = true
    target.camera.clear_current()
    target.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    if native: await draw(2)
    target.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func reproduce_silent_loss(expect_old_gap: bool) -> void:
    var target = level.car_3d_overlay
    var before: int = target.target_restore_count
    await lose_surface()
    if native:
        root.get_texture().get_image().save_png(output.path_join("silent-loss-before.png"))
    for tick in range(12):
        level._process(1.0 / 60.0)
        await process_frame
        if native: await draw(1)
    if expect_old_gap:
        check(target.viewport.disable_3d and target.target_restore_count == before, "Old code did not reproduce the silent target-loss gap")
        # This intentionally records the old symptom; it is not a passing
        # visibility claim or a reconstruction of the unknown Android trigger.
        if native:
            root.get_texture().get_image().save_png(output.path_join("old-silent-loss-unrecovered.png"))
        cases.append({"name":"old-silent-loss-unrecovered", "native":native, "target_disable_3d":target.viewport.disable_3d, "restore_count_before":before, "restore_count_after":target.target_restore_count, "target_drawn_stale":target.target_drawn, "expected_old_symptom":true})
        return
    check(target.target_restore_count > before, "Target lost after first draw requires an application notification to recover")
    await assert_visible("silent-target-loss-recovered")

func reproduce_silent_scenario_loss() -> void:
    if not native: return
    var target = level.car_3d_overlay
    var before: int = target.target_restore_count
    # A blank target can also have apparently correct public flags. Detach
    # the actual server scenario, then require real draw acknowledgements to
    # restore its existing world. No replacement model/sprite is injected.
    var empty_world := World3D.new()
    RenderingServer.viewport_set_scenario(target.viewport.get_viewport_rid(), empty_world.scenario)
    await draw(2)
    root.get_texture().get_image().save_png(output.path_join("silent-scenario-loss-before.png"))
    for tick in range(36):
        level._process(1.0 / 60.0)
        await process_frame
        await draw(1)
    check(target.target_restore_count > before, "Blank framebuffer with valid flags was accepted forever after its first successful draw")
    await assert_visible("silent-scenario-loss-recovered")

func assert_visible(label: String) -> void:
    var target = level.car_3d_overlay
    check(not target.viewport.disable_3d and target.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, label + ": target remains disabled")
    check(target.viewport.get_camera_3d() == target.camera, label + ": target lost its camera")
    level._process(1.0 / 60.0)
    check(target.size.is_equal_approx(Vector2(target.viewport.size)), label + ": container retains a stale viewport minimum size")
    var changed := 0
    if native:
        await draw(3)
        check(level.ready_for_play and target.target_drawn and target.target_draw_calls > 0, label + ": native target has never submitted vehicle geometry")
        var shown: Image = root.get_texture().get_image()
        target.hide()
        await draw(2)
        var bare: Image = root.get_texture().get_image()
        target.show()
        await draw(2)
        var width := shown.get_width()
        var playfield := roundi(shown.get_height() * level.renderer.PLAYFIELD_FRACTION)
        # Count real near-car pixels, excluding HUD, road lights and CPU shadows
        # which remain visible when the entire 3D overlay disappears.
        for y in range(roundi(playfield * .40), playfield - 3):
            for x in range(roundi(width * .22), roundi(width * .78)):
                var a := shown.get_pixel(x, y)
                var b := bare.get_pixel(x, y)
                if maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b))) > .04: changed += 1
        check(changed > 900, label + ": real car geometry is absent despite road/shadows remaining")
        shown.save_png(output.path_join(label + ".png"))
        bare.save_png(output.path_join(label + "-bare.png"))
    var playfield := roundi(root.size.y * level.renderer.PLAYFIELD_FRACTION)
    var roi := [roundi(root.size.x*.22),roundi(playfield*.40),roundi(root.size.x*.78),playfield-3]
    cases.append({"name":label, "window":[root.size.x,root.size.y], "race_time":level.state.race_time, "speed":level.controller.player.speed, "own_world":target.viewport.own_world_3d, "camera_current":target.viewport.get_camera_3d()==target.camera, "restores":target.target_restore_count, "target_drawn":target.target_drawn, "draw_calls":target.target_draw_calls, "actual_car_pixels":changed, "native":native,"shown_png":label+".png" if native else "","bare_png":label+"-bare.png" if native else "","pixel_roi_xyxy_exclusive":roi,"pixel_channel_difference_threshold":.04,"minimum_actual_car_pixels":900})

func draw(count: int) -> void:
    for tick in range(count):
        await process_frame
        call_deferred("force_draw")
        await RenderingServer.frame_post_draw

func force_draw() -> void:
    RenderingServer.force_draw(true)

func frames(count: int) -> void:
    for tick in range(count): await process_frame

func leave_level() -> void:
    root.get_node("PauseManager").resume()
    current_scene = null
    level.queue_free()
    level = null
    await frames(6)
    await preload("res://tools/level3_test_teardown.gd").drain_audio(self)
    if native: await draw(3)

func finish() -> void:
    if is_instance_valid(level): await leave_level()
    var source_hashes := {}
    for path in ["scripts/race_240sx_overlay.gd", "scripts/game_level2_pseudo3d.gd", "scenes/level2.tscn", "scenes/level2_pseudo3d.tscn", "tools/level2_vehicle_visibility153_test.gd"]:
        source_hashes[path] = FileAccess.get_sha256("res://" + path)
    FileAccess.open(output.path_join("visibility153-report.json"), FileAccess.WRITE).store_string(JSON.stringify({"native":native,"cases":cases,"source_hashes":source_hashes,"baseline_source_sha256":FileAccess.get_sha256(baseline_source) if not baseline_source.is_empty() else "", "failures":failures}, "  "))
    RenderingServer.set_render_loop_enabled(true)
    if failures.is_empty(): print("LEVEL2 VISIBILITY153: PASS — own vehicle world, actual target draw, early chase, resize, pause/focus surface restore and scene re-entry")
    else: push_error("LEVEL2 VISIBILITY153: " + str(failures))
    quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
