extends SceneTree
## Exercise the real asynchronous router as well as the visible phone layouts.
## Garden facts below are isolated save fixtures, never playthrough shortcuts.
const LoadingScreen = preload("res://scripts/context_loading151.gd")
const GardenState = preload("res://scripts/botanical_state.gd")
const Teardown = preload("res://tools/level3_test_teardown.gd")
const TARGETS := {
    &"level1":"res://game.tscn",
    &"level2":"res://scenes/level2.tscn",
    &"level3":"res://scenes/level3_store.tscn",
}
const HELD_ACTIONS := [&"l1_move_forward",&"l1_fire",&"l3_fire",&"l3_throw",&"race_accel",&"race_left"]
var output := "/tmp/context-loading151"
var visual := false
var failures: Array[String] = []
var report := {"contexts":[],"layouts":[],"transitions":[],"simulation_locks":[],"captures":[],"artwork":{},"source_hashes":{}}
var flow: Node
var _save_existed := false
var _save_bytes := PackedByteArray()

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--visual":visual = true
        elif arg.begins_with("--output="):output = arg.trim_prefix("--output=")
    call_deferred("run")

func check(condition: bool, message: String) -> void:
    if condition:return
    failures.append(message)
    push_error("CONTEXT LOADING151: " + message)

func draw_frame() -> void:
    RenderingServer.force_draw(true)

func advance_frame() -> void:
    await process_frame
    if DisplayServer.get_name() != "headless":
        call_deferred("draw_frame")
        await RenderingServer.frame_post_draw

func capture(label: String) -> void:
    if not visual:return
    await advance_frame()
    var image: Image = root.get_texture().get_image()
    check(image != null and not image.is_empty(),"Native loading capture is empty: " + label)
    if image == null or image.is_empty():return
    check(image.save_png(output.path_join(label + ".png")) == OK,"Cannot save loading capture: " + label)
    report.captures.append(label + ".png")

func capture_first_transition_draw(label: String) -> void:
    var image: Image = root.get_texture().get_image()
    check(image != null and not image.is_empty(),"First transition frame is empty: " + label)
    if image == null or image.is_empty():return
    var filename := label + "-first-draw.png"
    check(image.save_png(output.path_join(filename)) == OK,"Cannot save first transition frame")
    report.captures.append(filename)

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.size = Vector2i(1280,720)
    flow = root.get_node("SceneFlow")
    root.get_node("PauseManager").resume()
    root.get_node("GameState").music_muted = true
    root.get_node("GameState").sfx_muted = true
    _save_existed = FileAccess.file_exists(GardenState.PATH)
    if _save_existed:_save_bytes = FileAccess.get_file_as_bytes(GardenState.PATH)
    if visual:
        check(DisplayServer.get_name() != "headless","Loading artwork review needs a real display")
        if DisplayServer.get_name() == "headless":visual = false
        else:RenderingServer.set_render_loop_enabled(false)
    verify_contexts()
    await verify_layouts()
    GardenState.clear()
    root.get_node("GameState").start_new_run()
    # All three arrivals use the production SceneFlow, resource loader and
    # readiness signals. No direct scene instantiation stands in for this gate.
    for level_id in [&"level1",&"level2",&"level3"]:
        await verify_transition(level_id)
        if not failures.is_empty():break
    await cleanup()
    for path in ["scripts/scene_flow.gd","scripts/context_loading151.gd","scripts/pixel_interface_theme.gd"]:
        report.source_hashes[path] = FileAccess.get_sha256("res://" + path)
    report.scope = {"actual_async_router":true,"actual_arriving_levels":true,"held_actions_released":true,"saved_garden_context_fixtures":true,"staged_production_loading_lock":true,"actual_gameplay_state_compared":true,"native":visual,"manual_render_loop":visual}
    report.failures = failures
    FileAccess.open(output.path_join("loading151-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if failures.is_empty():print("CONTEXT LOADING151: PASS — stage-specific artwork, input isolation, responsive screens and real ready-before-play arrivals")
    quit(0 if failures.is_empty() else 1)

func verify_contexts() -> void:
    var fixtures := [
        {"id":"new","title":"НОЧНОЙ САД"},
        {"id":"entry","title":"НАСОСНАЯ У ПРУДА"},
        {"id":"pump","title":"НАСОСНАЯ ОЖИЛА"},
        {"id":"gallery","title":"КЛЮЧ ОТ ОРАНЖЕРЕИ"},
        {"id":"guardian_started","title":"СТРАЖ ОРАНЖЕРЕИ"},
        {"id":"guardian","title":"ЗАПАС В ОРАНЖЕРЕЕ"},
        {"id":"reward","title":"ПРОРЫВ К МАШИНЕ"},
    ]
    for fixture in fixtures:
        GardenState.clear()
        var saved = GardenState.new()
        if fixture.id != "new":saved.encounters_completed.append("entry")
        if fixture.id in ["pump","gallery","guardian_started","guardian","reward"]:
            saved.parts[0] = true;saved.installed = true
            saved.encounters_completed.append_array(["pump_repair","pump"])
        if fixture.id in ["gallery","guardian_started","guardian","reward"]:
            saved.encounters_completed.append("gallery");saved.service_key = true
        if fixture.id in ["guardian_started","guardian","reward"]:
            saved.gate_unlatched = true;saved.guardian_started = true
        if fixture.id in ["guardian","reward"]:saved.guardian = true
        if fixture.id == "reward":saved.reward = true
        check(saved.save(),"Could not write isolated garden loading fixture: " + fixture.id)
        var context: Dictionary = flow.call("loading_context",&"level1")
        check(context.get("title","") == fixture.title,"Wrong loading chapter for garden stage " + fixture.id)
        check(not str(context.get("description","")).is_empty(),"Garden stage lost its contextual instruction")
        report.contexts.append({"stage":fixture.id,"title":context.get("title",""),"description":context.get("description","")})
    var game_state := root.get_node("GameState")
    game_state.completed_levels.clear()
    var direct: Dictionary = flow.call("loading_context",&"level2")
    check(str(direct.description).contains("240"),"Direct pursuit loading text assumes unearned acorns")
    game_state.mark_completed(&"level1")
    var campaign: Dictionary = flow.call("loading_context",&"level2")
    check(str(campaign.description).contains("Шесть жёлудей"),"Post-park pursuit loading text ignores the stolen acorns")
    var diner: Dictionary = flow.call("loading_context",&"level3")
    check(str(diner.description).contains("Тая") and str(diner.description).contains("заказ"),"Diner loading context loses the heroine or peaceful order pickup")
    report.contexts.append({"stage":"pursuit_direct","description":direct.description})
    report.contexts.append({"stage":"pursuit_campaign","description":campaign.description})
    report.contexts.append({"stage":"diner","description":diner.description})

func verify_layouts() -> void:
    var screen = LoadingScreen.new()
    root.add_child(screen)
    var hashes: Array[String] = []
    for level_id in [&"level1",&"level2",&"level3"]:
        var path: String = LoadingScreen.ART[level_id]
        check(ResourceLoader.exists(path),"Missing actual level artwork: " + path)
        var hash := FileAccess.get_sha256(path)
        check(not hash.is_empty() and not hashes.has(hash),"Loading chapters reuse identical or missing artwork")
        hashes.append(hash)
        screen.present(level_id,flow.call("loading_context",level_id))
        check(screen.artwork_ready and screen.background.texture != null,"Level loading screen falls back to a blank colour: " + String(level_id))
        if screen.background.texture != null:
            var dimensions: Vector2 = screen.background.texture.get_size()
            check(dimensions.x >= 960 and dimensions.y >= 540,"Loading artwork is too small for phone displays")
            report.artwork[String(level_id)] = {"path":path,"sha256":hash,"width":dimensions.x,"height":dimensions.y}
        screen.set_progress(.67);screen.set_progress(.20)
        check(is_equal_approx(screen.displayed_progress,.67),"Real loading progress goes backwards")
        for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(2582,1220),Vector2i(1080,2400)]:
            root.size = dimensions
            await advance_frame()
            screen._layout()
            var visible: Rect2 = root.get_visible_rect()
            var panel: Rect2 = screen.frame.get_global_rect()
            check(visible.encloses(panel),"Loading frame leaves screen at " + str(dimensions))
            check(screen.screen.visible and screen.active and screen.screen.mouse_filter == Control.MOUSE_FILTER_STOP,"Loading screen does not cover gameplay input")
            for label in [screen.chapter,screen.title,screen.description,screen.status]:
                check(panel.encloses(label.get_global_rect()),"A loading label leaves its frame")
                check(label.get_line_count() * label.get_line_height() <= label.size.y + 1,"A loading label is vertically clipped at " + str(dimensions))
            check(not screen.retry.visible and not screen.menu.visible,"Normal loading unexpectedly exposes error buttons")
            report.layouts.append({"target":String(level_id),"viewport":[dimensions.x,dimensions.y],"frame":str(panel),"artwork_ready":screen.artwork_ready})
            await capture("loading-%s-%dx%d" % [level_id,dimensions.x,dimensions.y])
        screen.show_failure()
        check(screen.failed and screen.retry.visible and screen.menu.visible,"Loading failure offers no retry/menu controls")
        for button in [screen.retry,screen.menu]:
            check(screen.frame.get_global_rect().encloses(button.get_global_rect()),"Loading failure button leaves its frame")
        await capture("loading-%s-retry" % level_id)
        await screen.dismiss()
        check(not screen.active and not screen.screen.visible,"Loading screen remains over play after dismissal")
    screen.queue_free()
    await advance_frame()
    root.size = Vector2i(1280,720)

func verify_transition(level_id: StringName) -> void:
    var old: Node = current_scene
    var previous_disable_3d := root.disable_3d
    var previous_log_size: int = flow.transition_log.size()
    for action in HELD_ACTIONS:Input.action_press(action)
    flow.go_to(level_id)
    var loader: CanvasLayer = flow.loading_screen
    check(loader != null and loader.active and loader.screen.visible,"Context artwork was not presented synchronously before resource loading")
    check(loader.target == level_id,"Loading screen belongs to the wrong arriving level")
    check(root.disable_3d if level_id == &"level1" else root.disable_3d == previous_disable_3d,"Loader did not limit hidden main-world drawing to the garden")
    if old != null:check(old.process_mode == Node.PROCESS_MODE_DISABLED,"Departing game still simulates underneath loading artwork")
    if visual:
        RenderingServer.frame_post_draw.connect(capture_first_transition_draw.bind("arrival-" + String(level_id)),CONNECT_ONE_SHOT)
    var started := Time.get_ticks_msec()
    var observations := 0
    var unready_observations := 0
    var released := false
    var loading_snapshot: Dictionary = {}
    var loading_state_comparisons := 0
    var suppressed_world_observations := 0
    var first_scene_seen_msec := -1
    var first_ready_seen_msec := -1
    # Production owns two separate 30s phases (threaded resource load and
    # arriving-scene startup). Observe their errors instead of cutting off the
    # complete cold native path at the first phase's budget.
    while Time.get_ticks_msec() - started < 65000:
        check(not loader.failed,"Real scene loading entered the retry state: " + String(level_id))
        if loader.failed:break
        var arriving: Node = current_scene
        if arriving != null and arriving.scene_file_path == TARGETS[level_id]:
            if first_scene_seen_msec < 0:first_scene_seen_msec = Time.get_ticks_msec()-started
            var ready: bool = bool(flow.call("_scene_ready",arriving))
            if ready and first_ready_seen_msec < 0:first_ready_seen_msec = Time.get_ticks_msec()-started
            # Startup may legitimately repair the saved capsule or populate
            # actors. Once gameplay itself is ready, only route/target warm-up
            # remains and its simulation must stay unchanged behind the art.
            if bool(arriving.get("ready_for_play")) and bool(flow.call("is_loading_gameplay")):
                var snapshot: Dictionary = gameplay_snapshot(arriving,level_id)
                if loading_snapshot.is_empty():loading_snapshot = snapshot
                else:
                    check(snapshot == loading_snapshot,"Gameplay advanced during actual async loading: " + String(level_id))
                    loading_state_comparisons += 1
            if not ready:
                unready_observations += 1
                check(loader.active and loader.screen.visible,"Loading artwork disappeared before the actual arriving scene was ready")
                if level_id == &"level1":
                    check(root.disable_3d,"Hidden garden was rendered repeatedly while its navigation was still building")
                    suppressed_world_observations += 1
            if not bool(flow.get("_transitioning")):
                check(ready,"Router completed before arriving gameplay readiness")
                break
        observations += 1
        await advance_frame()
        if not released:
            for action in HELD_ACTIONS:check(not Input.is_action_pressed(action),"Held action bled into the next level: " + String(action))
            released = true
    var arrived: Node = current_scene
    var succeeded: bool = arrived != null and arrived.scene_file_path == TARGETS[level_id] and not bool(flow.get("_transitioning"))
    check(succeeded,"Real async transition timed out: " + String(level_id))
    if not succeeded:
        var failed_arrival := {"target":String(level_id),"ready":false,"observations":observations,"unready_observations":unready_observations,"first_scene_seen_msec":first_scene_seen_msec,"first_ready_seen_msec":first_ready_seen_msec,"wall_msec":Time.get_ticks_msec()-started,"loader_failed":loader.failed,"arriving_scene":arrived.scene_file_path if arrived != null else ""}
        if arrived != null and level_id == &"level1" and arrived.get("guard_navigation") != null:
            failed_arrival.navigation_ready = arrived.guard_navigation.is_ready
            failed_arrival.navigation_points_so_far = arrived.guard_navigation.graph.get_point_count()
            failed_arrival.navigation_queries = arrived.guard_navigation.query_count
        report.transitions.append(failed_arrival)
        return
    check(released,"Loading transition never produced an input-isolation frame")
    check(not loader.active and not loader.screen.visible,"Loading panel covers ready gameplay")
    check(root.disable_3d == previous_disable_3d,"Loading did not restore the arriving main viewport before play")
    check(flow.transition_log.size() == previous_log_size + 1,"Router lost or duplicated its arrival record")
    var record: Dictionary = flow.transition_log.back()
    check(record.target == String(level_id) and record.ready and not record.context.is_empty(),"Arrival record lost readiness or stage context")
    var detail := {"target":String(level_id),"scene":arrived.scene_file_path,"observations":observations,"unready_observations":unready_observations,"actual_loading_state_comparisons":loading_state_comparisons,"first_scene_seen_msec":first_scene_seen_msec,"first_ready_seen_msec":first_ready_seen_msec,"suppressed_world_observations":suppressed_world_observations,"main_viewport_restored":root.disable_3d == previous_disable_3d,"wall_msec":Time.get_ticks_msec()-started,"ready":true,"artwork_dismissed":not loader.active,"held_actions_released":released,"arrival_context":record.context}
    if level_id == &"level1":
        check(arrived.guard_navigation != null and arrived.guard_navigation.is_ready,"Garden starts before its physical route graph is ready")
        detail.navigation_points = arrived.guard_navigation.point_count
        await physics_frame
        await advance_frame()
        check(arrived._loading_announcements.is_empty() and arrived.hud.communication_remaining>4.3,"Opening garden speech was consumed under the loading artwork")
        detail.opening_speech_seconds = arrived.hud.communication_remaining
    elif level_id == &"level2":
        check(arrived.car_3d_overlay.is_model_ready(),"Pursuit starts without the actual 240 model")
        detail.vehicle_target_drawn = arrived.car_3d_overlay.target_drawn
        if DisplayServer.get_name() != "headless":check(arrived.car_3d_overlay.target_drawn,"Native pursuit loading ends before a vehicle framebuffer draw")
    else:
        check(arrived.navigation.ready and is_instance_valid(arrived.player),"Diner starts before navigation and heroine are ready")
        check(not arrived.can_player_attack(),"Diner loading arrives with a drawn weapon before the assault")
    report.transitions.append(detail)
    await capture("arrival-" + String(level_id) + "-ready")
    await verify_simulation_lock(arrived,level_id)

func gameplay_snapshot(game: Node, level_id: StringName) -> Dictionary:
    if level_id == &"level1":
        var guards: Array[Dictionary] = []
        for guard in game.guards:
            guards.append({"position":guard.position,"hp":guard.hp,"state":guard.state,"clock":guard._clock,"timer":guard._timer,"shots":guard._shots_fired})
        return {"hp":game.player.get_hp(),"ammo":game.player.ammo,"position":game.player.position,"velocity":game.player.velocity,"seconds":game.seconds,"checkpoint_clock":game.checkpoint_clock,"encounter_clock":game.encounter_director._elapsed,"guards":guards,"speech_seconds":game.hud.communication_remaining,"queued_speech":game._loading_announcements.size()}
    if level_id == &"level2":
        var cars: Array[Dictionary] = []
        for ai in game.controller.ais:
            cars.append({"x":ai.car.world_x,"z":ai.car.world_z,"speed":ai.car.speed})
        return {"hp":game.state.hp,"ammo":game.state.ammo,"x":game.controller.player.world_x,"z":game.controller.player.world_z,"speed":game.controller.player.speed,"countdown":game.state.countdown,"race_time":game.state.race_time,"pursuit_clock":game.controller.pursuit.clock,"cars":cars}
    return {"hp":game.player.health,"ammo":game.player.ammo,"position":game.player.position,"velocity":game.player.velocity,"throwable":String(game.player.throwable),"phase":String(game.mission.phase),"story_clock":game.mission.clock,"enemies_alive":game._enemies_alive}

func verify_simulation_lock(game: Node, level_id: StringName) -> void:
    # Native fade supplies real simulation ticks under the artwork. Headless
    # dismissal is intentionally instantaneous, so stage the same production
    # router lock for eight ticks as a separate, explicitly labelled probe.
    # No actor, health, ammo, mission flag, navigation or game clock is altered.
    check(not bool(flow.get("_transitioning")),"Simulation lock probe began before the actual arrival completed")
    flow.set("_target_id",level_id)
    flow.set("_transitioning",true)
    var loader: CanvasLayer = flow.loading_screen
    loader.present(level_id,flow.call("loading_context",level_id))
    var before: Dictionary = gameplay_snapshot(game,level_id)
    var completed_ticks := 0
    for i in range(8):
        await physics_frame
        await advance_frame()
        check(bool(flow.call("is_loading_gameplay")) and loader.active,"Production loading lock expired during its staged probe")
        check(gameplay_snapshot(game,level_id) == before,"Player, opponents, resources or encounter clock changed under artwork: " + String(level_id))
        check(bool(flow.call("_scene_ready",game)),"Loading lock froze navigation or vehicle target readiness")
        completed_ticks += 1
    var frozen: Dictionary = gameplay_snapshot(game,level_id)
    await capture("loading-" + String(level_id) + "-simulation-lock")
    await loader.dismiss()
    flow.set("_transitioning",false)
    check(not bool(flow.call("is_loading_gameplay")) and not loader.active,"Dismissed artwork still locks gameplay")
    for i in range(6):
        await physics_frame
        await advance_frame()
    var resumed: Dictionary = gameplay_snapshot(game,level_id)
    if level_id == &"level1":
        check(float(resumed.seconds)>float(frozen.seconds) and float(resumed.encounter_clock)>float(frozen.encounter_clock),"Garden/encounter clocks did not resume after loading dismissal")
        check(not resumed.guards.is_empty() and float(resumed.guards[0].clock)>float(frozen.guards[0].clock),"Garden opponents remained frozen after loading dismissal")
    elif level_id == &"level2":
        check(float(resumed.countdown)<float(frozen.countdown) or float(resumed.race_time)>float(frozen.race_time),"Pursuit countdown/race clock did not resume after loading dismissal")
    else:
        check(float(resumed.story_clock)>float(frozen.story_clock),"Diner story clock did not resume after loading dismissal")
    report.simulation_locks.append({"target":String(level_id),"fixture":"production router lock plus real artwork; no gameplay-state overrides","physics_ticks":completed_ticks,"before":before,"after_locked":frozen,"after_unlock":resumed,"state_unchanged_while_locked":before==frozen,"ready_while_locked":bool(flow.call("_scene_ready",game))})

func cleanup() -> void:
    for action in HELD_ACTIONS:Input.action_release(action)
    root.get_node("PauseManager").resume()
    if not bool(flow.get("_transitioning")):
        flow.go_to(&"menu")
        var deadline := Time.get_ticks_msec()+30000
        while Time.get_ticks_msec()<deadline:
            if current_scene != null and current_scene.scene_file_path == "res://menu.tscn" and not bool(flow.get("_transitioning")):break
            await advance_frame()
    elif not failures.is_empty():
        # Cancel only this failed fixture's outstanding coroutine before
        # releasing its scene, so a primary timeout cannot create freed-node
        # errors in the asynchronous router during diagnostic teardown.
        flow.set("_generation",int(flow.get("_generation"))+1)
        var rearm := Callable(flow,"_rearm")
        if scene_changed.is_connected(rearm):scene_changed.disconnect(rearm)
        flow.call("_restore_scene_inputs")
        flow.call("_restore_loading_world")
        flow.set("_transitioning",false)
    if current_scene != null:
        current_scene.queue_free();current_scene = null
    for i in range(3):await advance_frame()
    await Teardown.drain_audio(self)
    if visual:RenderingServer.set_render_loop_enabled(true)
    GardenState.clear()
    if _save_existed:
        var file := FileAccess.open(GardenState.PATH,FileAccess.WRITE)
        if file != null:file.store_buffer(_save_bytes)
