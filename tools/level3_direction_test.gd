extends SceneTree
## Staged director/collision acceptance, not a complete mission playthrough.
## Normal arrival, deployment, navigation, glass and flashbang run physically.
const Director = preload("res://scripts/level3_raid_director.gd")
const Teardown = preload("res://tools/level3_test_teardown.gd")
var game: Level3Store
var failures: Array[String] = []
var visual := false
var capture_size := Vector2i(1280,720)
var output := "user://level3-direction"
var shots: Dictionary = {}
var minimum_curb_clearance := INF
var minimum_south_clearance := INF
var physical_samples := 0
var old_intrusions := 0
var maximum_frame_width := 0.0
var maximum_frame_height := 0.0
var first_breach := -1.0
var elapsed := 0.0
var query := PhysicsShapeQueryParameters2D.new()
func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument == "--visual": visual = true
        elif argument.begins_with("--output="): output = argument.trim_prefix("--output=")
        elif argument.begins_with("--size="):
            var parts := argument.trim_prefix("--size=").split("x")
            if parts.size() == 2: capture_size = Vector2i(int(parts[0]),int(parts[1]))
    call_deferred("run")
func check(ok: bool, why: String) -> void:
    if not ok:
        failures.append(why)
        push_error("LEVEL3 DIRECTION: " + why)
func _check_trajectory() -> void:
    # The old arc is retained here only as a negative control: the same body
    # bounds must detect its real intrusion above the street pavement.
    for frame in range(1201):
        var t := float(frame) / 1200.0
        var pose := Director.arrival_transform(t)
        for point in Director.footprint(pose, Vector2.ONE*1.005):
            minimum_curb_clearance = minf(minimum_curb_clearance, point.y - Director.CURB_Y)
            minimum_south_clearance = minf(minimum_south_clearance, Director.STREET_BOTTOM - point.y)
            check(point.x >= -146 and point.x <= 1298, "swept van touches the street side boundary")
        var old_at := Vector2(1280,879).lerp(Vector2(350,823),1.0-pow(1.0-t,2)) + Vector2(0,-64*sin(PI*t))
        var old_pose := Transform2D(PI+sin(PI*t)*.64-.12*t,old_at)
        for point in Director.footprint(old_pose,Vector2.ONE*1.005):
            if point.y < 768: old_intrusions += 1
    check(minimum_curb_clearance > 10, "body/rear corner crosses the pavement during drift")
    check(minimum_south_clearance > 10, "body/rear corner touches the south street barrier")
    check(old_intrusions > 0, "negative control no longer detects the original wall collision")
func _check_framing() -> void:
    for dimensions in [Vector2(960,540),Vector2(1280,720),Vector2(1600,720),Vector2(2582,1220)]:
        for second in range(140):
            var at := float(second)*.1
            var description := Director.deployment_shot(at)
            var zoom := Director.zoom_for(dimensions,description.extent)
            var visible: Vector2 = dimensions / zoom
            check(visible.x <= description.extent.x+.01 and visible.y <= description.extent.y+.01, "wide phone expands the shot into a map overview")
            check(visible.x <= 540.01 and visible.y <= 340.01, "deployment framing is too distant to read the actors")
func _check_physical_body() -> void:
    if not game.mission.van.visible: return
    var shape := RectangleShape2D.new()
    shape.size = game.mission.van.get_body_size()
    query.shape = shape
    query.transform = game.mission.van.global_transform
    query.collision_mask = 1
    query.collide_with_areas = false
    query.margin = .8
    query.exclude = [game.mission._van_body.get_rid()] if is_instance_valid(game.mission._van_body) else []
    var overlaps := game.get_world_2d().direct_space_state.intersect_shape(query,12)
    check(overlaps.is_empty(), "actual rotated van overlaps a wall, curb, parked car or street barrier")
    physical_samples += 1
func _snapshot(id: StringName) -> void:
    if not visual or shots[id].has("image"): return
    await RenderingServer.frame_post_draw
    var filename := "%02d-%s.png" % [shots.size(),id]
    root.get_texture().get_image().save_png(output.path_join(filename))
    shots[id].image = filename
func run() -> void:
    root.size = capture_size
    if visual: check(DisplayServer.get_name() != "headless", "visual acceptance requires a real framebuffer")
    DirAccess.make_dir_recursive_absolute(output)
    _check_trajectory()
    _check_framing()
    game = load("res://scenes/level3_store.tscn").instantiate()
    root.add_child(game); current_scene = game
    for frame in range(8): await physics_frame
    if not visual:
        # Exercise the actual scene camera/viewport path as well as the pure
        # framing formula. Clear the probe history before the real raid.
        for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720),Vector2i(2582,1220)]:
            root.size = dimensions
            await process_frame
            game.mission._camera_shot(Director.deployment_shot(6))
            var actual_view: Vector2 = game.get_viewport_rect().size / game.camera.zoom
            check(actual_view.x <= 540.1 and actual_view.y <= 340.1, "actual phone viewport expands the close camera framing")
        root.size = Vector2i(1280,720)
        await process_frame
        game.mission.shot_history.clear()
        game.mission.shot = &""
    if visual:
        # Placement for a labelled action fragment, after the real conversation
        # would leave Carolina here. Full input progression is tested separately.
        game.player.global_position = Vector2(680,155)
        game.camera.global_position = game.player.global_position
        game.camera.reset_smoothing()
    game.mission.begin_raid()
    var physics_start := Engine.get_physics_frames()
    for frame in range(2400):
        elapsed = float(Engine.get_physics_frames()-physics_start) / Engine.physics_ticks_per_second
        var story = game.mission
        if story.phase == &"assault": break
        _check_physical_body()
        if not shots.has(story.shot):
            shots[story.shot] = {"time": elapsed, "extent": [story.shot_extent.x,story.shot_extent.y], "actors": story.deployment_count}
            print("LEVEL3 DIRECTION SHOT: ",story.shot," at ",elapsed)
            await _snapshot(story.shot)
        if story.phase == &"deployment" or story.phase == &"breach":
            var frame_size := game.get_viewport_rect().size / game.camera.zoom
            maximum_frame_width = maxf(maximum_frame_width,frame_size.x)
            maximum_frame_height = maxf(maximum_frame_height,frame_size.y)
            check(frame_size.x <= 540.1 and frame_size.y <= 340.1, "physical camera regressed to distant parade framing")
        if story.glass_broken and first_breach < 0:
            first_breach = elapsed
            if visual:
                shots[&"glass_grenade"] = {"time":elapsed}
                await _snapshot(&"glass_grenade")
        await physics_frame
    var story = game.mission
    check(story.phase == &"assault" and not story.raid_skipped, "physical director never hands off to the actual assault")
    check(story.deployment_count == 10 and story.deployed_positions.size() == 10, "editorial cuts hid an incomplete tactical deployment")
    check(story.deployed_facings.size() == 10, "actual stack facing was not recorded")
    for index in range(story.deployed_positions.size()):
        check(story.deployed_positions[index].distance_to(story.STACKS[index]) < 5, "actor did not physically reach its window/door")
        var expected: float = story.deployed_positions[index].direction_to(story.STACK_AIMS[index]).angle()
        check(absf(angle_difference(story.deployed_facings[index],expected)) < .04, "stacked actor faces Carolina instead of guarding its opening")
    for enemy in game._enemies:
        check(enemy.staging_face == Vector2.INF and not enemy.staging, "stack facing leaked into normal assault AI")
    check(story.glass_broken and story.flashbang_detonated, "close insert lost the actual glass/grenade action")
    check(game.player.controls_enabled and game.camera.zoom.is_equal_approx(Vector2.ONE*1.7), "director did not restore normal controls/framing")
    check(game.pickups_root.visible, "editorial presentation did not restore collectible markers")
    check(game.camera.position_smoothing_enabled, "director did not restore gameplay camera smoothing")
    for required in [&"street_arrival",&"sliding_door",&"front_door_team",&"kitchen_reaction",&"service_door_team",&"west_window_team",&"north_window_team",&"window_breach",&"carolina_return"]:
        check(story.shot_history.has(required), "missing directed shot " + required)
    check(story._skids.size() == 2 and story._skids[0].get_point_count() > 20, "safe drift lost tyre marks")
    var logical: Vector2 = game.get_viewport_rect().size
    var report := {"failures":failures,"native":visual,"window":[root.size.x,root.size.y],"logical_viewport":[logical.x,logical.y],"renderer":RenderingServer.get_current_rendering_method(),"physical_body_samples":physical_samples,"swept_samples":1201,"old_wall_intrusions_detected":old_intrusions,"minimum_curb_clearance":minimum_curb_clearance,"minimum_south_clearance":minimum_south_clearance,"deployment_max_world_view":[maximum_frame_width,maximum_frame_height],"seconds":elapsed,"shots":shots,"physical_deployments":story.deployment_count,"first_breach":first_breach,"note":"Staged physical direction acceptance/optional native action fragment, not a full mission replay or phone FPS measurement."}
    FileAccess.open(output.path_join("direction-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    game.queue_free(); current_scene = null
    for frame in range(4): await process_frame
    await Teardown.drain_audio(self)
    if failures.is_empty(): print("LEVEL3 DIRECTION: PASS — swept street-safe drift, close phone-scaled editorial shots, ten physical stacks and normal gameplay handoff")
    quit(0 if failures.is_empty() else 1)
