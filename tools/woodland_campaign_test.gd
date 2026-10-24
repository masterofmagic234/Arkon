extends SceneTree
# This fixture stages each director's exit prerequisites, then exercises its
# production completion path in one real SceneTree. Input-driven mission,
# pursuit and diner playthroughs are separate CI gates.
const Teardown = preload("res://tools/level3_test_teardown.gd")
var failed := false
var state: Node
var flow: Node
var pause_manager: Node
var original_scale := 1.0
var settings_present := false
var settings_bytes := PackedByteArray()

func _init() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        failed = true
        push_error("WOODLAND CAMPAIGN: " + message)

func settle(count: int = 5) -> void:
    for i in range(count): await process_frame

func wait_scene(path: String, previous_id: int = 0) -> bool:
    for i in range(300):
        await process_frame
        if current_scene != null and current_scene.scene_file_path == path and current_scene.get_instance_id() != previous_id and not flow._transitioning:
            await settle(5)
            return true
    check(false, "did not reach " + path)
    return false

func _run() -> void:
    state = root.get_node("GameState")
    flow = root.get_node("SceneFlow")
    pause_manager = root.get_node("PauseManager")
    settings_present = FileAccess.file_exists(state.SAVE_PATH)
    if settings_present: settings_bytes = FileAccess.get_file_as_bytes(state.SAVE_PATH)
    state.sfx_muted = true
    state.set_music_muted(true)
    state.music_muted = false
    state.load_settings()
    check(state.music_muted, "saved music mute did not reload")
    state.start_new_run()
    original_scale = root.scaling_3d_scale
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.size = Vector2i(1920, 1080)
    flow.go_to(&"level1")
    if not await wait_scene("res://game.tscn"): await finish(); return
    var woodland: Node3D = current_scene
    check(woodland.ready_for_play and woodland.stage == "trail", "new woodland director did not start a fresh mission")
    check(woodland.get_script().resource_path == "res://scripts/level1_woodland.gd", "campaign launched the retired estate")
    check(is_instance_valid(woodland.ambient) and not woodland.ambient.playing, "saved mute was bypassed when the woodland registered ambience")
    root.get_node("AudioManager").toggle_music()
    await settle()
    check(not state.music_muted and woodland.ambient.playing, "global music toggle did not start the registered ambience")
    root.get_node("AudioManager").toggle_music()
    await settle()
    check(state.music_muted and not woodland.ambient.playing, "global music toggle did not stop woodland ambience")
    woodland.world.set_meta("force_mobile_profile", true)
    woodland.world._mobile_profile()
    check(root.scaling_3d_scale <= 2.0 / 3.0 + .001, "Full HD mobile 3D cap is absent")
    woodland.player.take_damage(30)
    var previous_id := woodland.get_instance_id()
    pause_manager.set_paused(true)
    check(paused, "pause manager did not pause the active woodland")
    woodland.restart()
    if not await wait_scene("res://game.tscn", previous_id): await finish(); return
    woodland = current_scene
    check(not paused and not pause_manager.is_paused, "retry retained paused state")
    check(woodland.player.get_hp() == 100 and woodland.player.ammo == 38, "retry did not restore player resources")
    check(woodland.stage == "trail" and woodland.stations_lit == 0 and not woodland.tank.defeated, "retry retained previous mission state")
    check(not woodland.ambient.playing, "muted ambience restarted on retry")
    check(state.completed_levels.is_empty(), "retry incorrectly completed a level")
    check(is_equal_approx(root.scaling_3d_scale, original_scale), "retry leaked the previous scene's 3D scale")

    # Reapply a mobile profile so the real woodland -> race transition must
    # restore it. The mission input fixture verifies how escape is unlocked.
    woodland.world.set_meta("force_mobile_profile", true)
    woodland.world._mobile_profile()
    woodland.player.set_physics_process(false)
    woodland.lit.assign([true, true, true])
    woodland.stations_lit = 3
    woodland.stage = "reward"
    woodland.player.position = Vector3(0, .65, -15.5)
    check(woodland._distance(woodland.CACHE) < 3.1 and woodland._distance(woodland.STATIONS[2].position) < 3.1, "cache/station overlap fixture missed its interaction ranges")
    check(woodland.context_text() == "Забрать карту лесничества", "completed oak station hides the cache action prompt")
    woodland.interact()
    check(woodland.journey.completed.has(0) and not woodland.cache_node.visible, "completed oak station swallowed cache interaction in the overlap")
    woodland.journey.completed.assign([0,1,2,3,4,5,6,7])
    woodland.player.position = woodland.EXIT + Vector3.UP * .65
    woodland.interact()
    # A duplicate fact in the same frame must not advance twice.
    root.get_node("SignalBus").emit_signal(&"level_completed", &"level1")
    if not await wait_scene("res://scenes/level2.tscn"): await finish(); return
    check(state.current_level == &"level2" and state.is_completed(&"level1"), "woodland completion was not persisted")
    check(not state.is_completed(&"level2"), "duplicate woodland completion skipped the race")
    check(is_equal_approx(root.scaling_3d_scale, original_scale), "woodland pixel cap leaked into the race")
    check(not paused, "woodland transition left the race paused")
    var race: Node = current_scene
    race.set_process(false)
    race.set_physics_process(false)
    race.continue_campaign()
    await settle()
    check(current_scene == race and not state.is_completed(&"level2"), "unfinished pursuit permitted Continue")
    race.state.mission_complete = true
    race.state.mission_failed = false
    pause_manager.set_paused(true)
    race.continue_campaign()
    if not await wait_scene("res://scenes/level3_store.tscn"): await finish(); return
    check(not paused and state.current_level == &"level3" and state.is_completed(&"level2"), "pursuit did not safely hand off to the diner")
    var diner: Node = current_scene
    diner.set_process(false)
    diner.set_physics_process(false)
    diner.player.set_physics_process(false)
    for enemy in diner._enemies: enemy.set_physics_process(false)
    diner.order_collected = false
    diner._finish_level()
    await settle()
    check(current_scene == diner and not diner._level_complete_started, "diner exited before its objective")
    diner.order_collected = true
    diner._enemies_alive = 0
    diner._finish_level()
    if not await wait_scene("res://menu.tscn"): await finish(); return
    check(state.current_level == &"menu" and state.is_completed(&"level3"), "diner completion did not reach the menu")
    check(state.completed_levels.size() == 3, "campaign completion facts were duplicated or lost")
    var completed: Array = state.completed_levels.duplicate()
    state.player_hp = 3
    state.player_ammo = 1
    state.retry_level()
    check(state.completed_levels == completed and state.player_hp == 100 and state.player_ammo == 38, "retry erased campaign progress or did not reset resources")
    state.start_new_run()
    check(state.completed_levels.is_empty() and state.acorns_collected == 0, "new run did not clear campaign progress")
    await finish()

func finish() -> void:
    pause_manager.resume()
    if current_scene != null:
        current_scene.queue_free()
        current_scene = null
    await settle()
    root.scaling_3d_scale = original_scale
    await Teardown.drain_audio(self)
    if settings_present:
        FileAccess.open(state.SAVE_PATH, FileAccess.WRITE).store_buffer(settings_bytes)
    else:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(state.SAVE_PATH))
    if not failed: print("WOODLAND CAMPAIGN: PASS — saved mute/global audio; cache interaction priority; fresh retry; paused handoffs; mobile scale restoration; director exits 1 -> 2 -> 3 -> menu; persistent and cleared progress")
    quit(1 if failed else 0)
