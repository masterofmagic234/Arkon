extends SceneTree
## Staged production HUD/player/projectile acceptance, not a campaign playthrough.
var failures: Array[String] = []
var visual := false
var output := "user://damage150"
var game: Node3D
var feedback: Control
var snapshots: Array[Dictionary] = []
var source_hashes: Dictionary = {}
var source_placements: Array[Dictionary] = []
var baseline_offset := Vector2(.017, -.013)
var original_rotation: Vector3
var original_fov := 65.0
var camera_peak := 0.0

class CleanupHost extends Node:
    var mission_failed := false
    var mission_complete := false

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--visual": visual = true
        elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool, why: String) -> void:
    if not ok:
        failures.append(why)
        push_error("BOTANICAL DAMAGE150: " + why)

func settle(count := 4) -> void:
    for i in range(count): await physics_frame

func snapshot(name_: String) -> void:
    # Both modes sample the prepared presentation frame rather than the
    # synchronous health signal before its first process tick.
    for i in range(2):
        await process_frame
        if visual: RenderingServer.force_draw(true)
    if visual:
        root.get_texture().get_image().save_png(output.path_join(name_ + ".png"))
    var bearing_: Vector2 = feedback.bearing()
    snapshots.append({"id":name_, "hp":game.player.get_hp(), "accepted_hits":feedback.accepted_hits,
        "hit_strength":feedback.hit_strength, "hit_remaining":feedback.hit_remaining,
        "direction_remaining":feedback.direction_remaining, "bearing":[bearing_.x,bearing_.y],
        "camera_shift":[game.player.camera.h_offset-baseline_offset.x,game.player.camera.v_offset-baseline_offset.y],
        "overlay_visible":feedback.visible, "edges_visible":feedback.edges.visible,
        "viewport":[root.size.x,root.size.y]})

func camera_offset() -> Vector2:
    return Vector2(game.player.camera.h_offset,game.player.camera.v_offset)

func place_source(source: CharacterBody3D, direction: Vector3) -> void:
    var point: Vector3 = game.player.global_position + game.player.global_basis * direction * 6.0
    # Guard origins are at their feet. Sample the physical path/disc surface,
    # which can sit above the analytic terrain under the same visible point.
    var physical: Dictionary = game.world.physical_support_at(point) if game.world.has_method("physical_support_at") else {}
    check(not physical.is_empty(), "staged damage source has no real supporting floor")
    point.y = (float(physical.position.y) if not physical.is_empty() else game.world.surface_height_at(point.x,point.z))+.003
    source.global_position = point
    source_placements.append({"position":[point.x,point.y,point.z],"physical_support":not physical.is_empty(),
        "support_y":float(physical.position.y) if not physical.is_empty() else null,"feet_clearance_m":.003})

func reset_damage_window() -> void:
    # Wait for the real actor/health immunity clocks; never clear them by hand.
    await settle(55)

func check_source_pins() -> void:
    for path in ["res://scripts/level1_player.gd","res://scripts/botanical_hud.gd",
        "res://scripts/botanical_damage_feedback.gd","res://shaders/woodland/garden_damage_edges.gdshader"]:
        source_hashes[path.trim_prefix("res://")] = FileAccess.get_sha256(path)

func run() -> void:
    root.get_node("PauseManager").resume()
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").sfx_muted = true
    root.get_node("GameState").music_muted = true
    DirAccess.make_dir_recursive_absolute(output)
    if visual:
        check(DisplayServer.get_name() != "headless", "visual capture requires a real framebuffer")
        root.size = Vector2i(1280,720)
        root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
        RenderingServer.set_render_loop_enabled(false)
    change_scene_to_file("res://game.tscn")
    await settle(16)
    game = current_scene
    await await_garden_ready(game)
    game.set_physics_process(false)
    for guard in game.guards: guard.set_physics_process(false)
    game.hud.set_mobile_preview(true)
    feedback = game.hud.damage_feedback
    check(is_instance_valid(feedback) and feedback.actor == game.player, "current garden HUD never bound hit feedback to Carolina")
    game.player.camera.h_offset = baseline_offset.x
    game.player.camera.v_offset = baseline_offset.y
    original_rotation = game.player.camera.rotation
    original_fov = game.player.camera.fov
    var center := root.get_visible_rect().size * .5
    var aim: Vector3 = game.player.camera.project_ray_normal(center)
    await snapshot("00-undamaged")
    check(feedback.accepted_hits == 0 and not feedback.edges.visible, "fresh garden invented damage or red edges")

    # Actual swept enemy cone, actual player capsule and normal take_damage API.
    var source: CharacterBody3D = game.guards[0]
    place_source(source,Vector3.RIGHT)
    var cone = load("res://scripts/woodland_cone_projectile.gd").new()
    game.add_child(cone)
    cone.setup(source.global_position+Vector3.UP*.6,game.player.global_position+Vector3.UP*.35,source)
    for i in range(100):
        await physics_frame
        if game.player.get_hp() < 100: break
    check(game.player.get_hp() == 92 and feedback.accepted_hits == 1, "actual cone failed to start exactly one accepted damage flash")
    await settle(3)
    camera_peak = camera_offset().distance_to(baseline_offset)
    check(camera_peak > .0001 and camera_peak < .016, "hit camera response was absent or exceeded its centimetre bound")
    check(game.player.camera.rotation.is_equal_approx(original_rotation) and is_equal_approx(game.player.camera.fov,original_fov), "damage changed stored look rotation or FOV")
    check(game.player.camera.project_ray_normal(center).distance_to(aim) < .00001, "cosmetic camera translation altered the centre aim direction")
    check(feedback.bearing().x > .99, "right-side actual cone points to the wrong screen bearing")
    await snapshot("01-right-hit")
    var count_before: int = feedback.accepted_hits
    check(not game.player.take_damage(8,source) and feedback.accepted_hits == count_before, "immune/rejected hit retriggered visual damage")
    var paused_remaining: float = feedback.hit_remaining
    root.get_node("PauseManager").set_paused(true)
    check(camera_offset().distance_to(baseline_offset) < .000001, "pausing left camera displacement installed")
    check(not game.player.take_damage(8,source) and game.player.get_hp() == 92, "paused player accepted damage")
    for i in range(10): await process_frame
    check(is_equal_approx(feedback.hit_remaining,paused_remaining) and not feedback.visible, "paused hit timer advanced or bled over the pause menu")
    await snapshot("02-paused")
    root.get_node("PauseManager").resume()
    await snapshot("03-resumed")
    # Desktop/touch look remains independent while the hit envelope is active.
    var yaw_before: float = game.player.rotation.y
    var pitch_before: float = game.player.camera.rotation.x
    game.player.handle_touch_look(Vector2(3,-2))
    check(is_equal_approx(game.player.rotation.y,yaw_before-.015) and is_equal_approx(game.player.camera.rotation.x,pitch_before+.008), "hit feedback stole normal touch look")
    await settle(100)
    check(feedback.hit_remaining == 0 and feedback.direction_remaining == 0 and not feedback.edges.visible, "expired damage overlay or direction marker persisted")
    check(camera_offset().distance_to(baseline_offset) < .000001, "camera failed to return to its pre-existing offsets")
    await snapshot("04-faded")

    for row in [["front",Vector3.FORWARD,Vector2.UP],["rear",Vector3.BACK,Vector2.DOWN],["left",Vector3.LEFT,Vector2.LEFT]]:
        place_source(source,row[1])
        check(game.player.take_damage(8,source), "normal cardinal hit was rejected: " + row[0])
        check(feedback.bearing().distance_to(row[2]) < .001, "wrong screen direction for " + row[0])
        await snapshot("05-" + row[0] + "-hit")
        await reset_damage_window()
    count_before = feedback.accepted_hits
    check(not game.player.take_damage(0,source) and feedback.accepted_hits == count_before, "zero damage started feedback")
    root.get_node("SignalBus").entity_damaged.emit(source,8,game.player)
    check(feedback.accepted_hits == count_before, "enemy damage painted Carolina's HUD")
    game.player.health.heal(10)
    check(feedback.accepted_hits == count_before, "healing was presented as fresh damage")
    await settle(100)
    check(game.player.get_hp() == 78, "accepted/rejected damage did not preserve real health arithmetic")
    place_source(source,Vector3.FORWARD)
    check(game.player.take_damage(55,source), "critical health fixture damage was rejected")
    await snapshot("06-heavy-hit")
    await settle(100)
    check(game.player.get_hp() == 23 and feedback.hit_remaining == 0 and feedback.edges.visible, "low health lacks a persistent restrained danger cue")
    await snapshot("07-low-health")
    check(game.player.take_damage(1), "environmental damage fixture was rejected")
    check(feedback.source_position == null and feedback.direction_remaining == 0, "unknown source invented a directional attacker")
    await snapshot("08-environment-hit")
    game.player.health.heal(100)
    await settle(100)
    check(game.player.get_hp() == 100 and not feedback.edges.visible, "healed full-health player retains danger tint")
    await snapshot("09-healed")
    root.size = Vector2i(2582,1220)
    await settle(3)
    await snapshot("11-phone-undamaged")
    check(game.player.take_damage(8,source), "phone-aspect damage fixture was rejected")
    await snapshot("12-phone-hit")
    root.get_node("PauseManager").set_paused(true)
    await snapshot("13-phone-paused")
    check(not feedback.visible and camera_offset().distance_to(baseline_offset) < .000001, "phone pause did not clear presentation and camera offset")
    root.get_node("PauseManager").resume()
    await reset_damage_window()
    root.size = Vector2i(1280,720)
    await settle(3)
    # Rebinding must restore offsets and replace signal subscriptions, not stack.
    count_before = feedback.accepted_hits
    feedback.bind(game.player,game,game.hud.supplies)
    check(game.player.take_damage(8,source) and feedback.accepted_hits == count_before+1, "rebind duplicated or lost accepted damage subscription")
    await reset_damage_window()
    check(game.player.take_damage(200,source), "fatal damage fixture was rejected")
    await settle(3)
    check(game.mission_failed and game.player.health.is_dead and not feedback.visible, "death left combat presentation above the retry state")
    check(camera_offset().distance_to(baseline_offset) < .000001, "death left a camera offset installed")
    await snapshot("10-death-menu")
    var final_accepted_hits: int = feedback.accepted_hits
    check(final_accepted_hits == 9, "accepted hit inventory differs from nine actual health changes")
    game.queue_free()
    current_scene = null
    await settle(6)
    await cleanup_exit_case()
    check_source_pins()
    var report := {"result":"PASS" if failures.is_empty() else "FAIL", "failures":failures,
        "source_hashes":source_hashes,"accepted_source":"actual swept cone plus normal take_damage; no direct damage-event injection for Carolina",
        "camera_peak_m":camera_peak,"accepted_hits":final_accepted_hits,"snapshots":snapshots,"source_placements":source_placements,
        "scope":"Staged production garden player/HUD/projectile and isolated teardown. Real immunity clocks, four bearings, touch look, pause, fade, critical health, heal, death, bind and exit; not a full mission or phone FPS claim."}
    FileAccess.open(output.path_join("damage150-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    root.get_node("GameState").start_new_run()
    if visual: RenderingServer.set_render_loop_enabled(true)
    if failures.is_empty(): print("BOTANICAL DAMAGE150: PASS — actual accepted cone hit, four source bearings, visible bounded feedback, unchanged aim, pause/health/death/rebind/exit restoration")
    quit(0 if failures.is_empty() else 1)

func cleanup_exit_case() -> void:
    var host := CleanupHost.new()
    root.add_child(host)
    var player = load("res://scenes/level1_player.tscn").instantiate()
    host.add_child(player)
    player.set_physics_process(false)
    var label := Label.new()
    host.add_child(label)
    var ui = load("res://scripts/botanical_damage_feedback.gd").new()
    host.add_child(ui)
    ui.bind(player,host,label)
    player.camera.h_offset = .023
    player.camera.v_offset = -.009
    check(player.take_damage(8), "isolated actual player rejected cleanup hit")
    await settle(3)
    check(absf(player.camera.v_offset+.009) > .0001, "cleanup did not exercise an active camera kick")
    ui.queue_free()
    await process_frame
    check(absf(player.camera.h_offset-.023) < .000001 and absf(player.camera.v_offset+.009) < .000001, "freeing feedback did not restore pre-existing camera offsets")
    host.queue_free()
    await settle(4)

func await_garden_ready(scene: Node3D) -> void:
    for frame in range(300):
        if scene.ready_for_play:return
        await physics_frame
    check(false,"production garden did not finish its collision-safe startup")
