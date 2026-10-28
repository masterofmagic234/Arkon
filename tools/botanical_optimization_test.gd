extends SceneTree
## Matched production-vs-1.47 native garden benchmark. Timings include the same
## framebuffer readback fence on both sides and are never reported as phone FPS.
const BASELINE_COMMIT := "0d858100521e0a0a7de3e201dc2ea3aaa978fd06"
const PHONE_SIZE := Vector2i(3088, 1440)
const DESKTOP_SIZE := Vector2i(1280, 720)
const VIEWS := [
    ["entry", Vector3(0, .65, 65), Vector3.ZERO, true],
    ["pond", Vector3(25, 3.65, 31), Vector3(0, 8, -20), false],
    ["conservatory", Vector3(0, 7.65, -19), Vector3(0, 14, -38), false],
    ["upper", Vector3(-23, 12.65, -88), Vector3(26, 15, -61), false],
    ["west-ramp", Vector3(-51.6, 5.45, -2.5), Vector3(-10.15765, -11.5184, -23.98168), false],
    ["entry-reverse", Vector3(0, .65, 60), Vector3(0, 3, 80), false],
]
var output := "user://botanical-optimization"
var samples := 6
var warmup := 2
var isolated_147 := false
var phone_only := false
var only_view := ""
var moving_steps := 90
var failures: Array[String] = []
var game: Node3D
var camera: Camera3D
var previous_fps := 0
var previous_vsync := DisplayServer.VSYNC_ENABLED
var current_reference := false
var report: Dictionary = {"schema": 148, "views": [], "moving": [], "failures": []}

func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
        elif argument.begins_with("--samples="): samples = maxi(3, int(argument.trim_prefix("--samples=")))
        elif argument.begins_with("--warmup="): warmup = maxi(2, int(argument.trim_prefix("--warmup=")))
        elif argument.begins_with("--view="): only_view = argument.trim_prefix("--view=")
        elif argument == "--isolated-147": isolated_147 = true
        elif argument == "--phone-only": phone_only = true
        elif argument == "--no-movement": moving_steps = 0
    call_deferred("run")

func check(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)
        push_error("BOTANICAL OPTIMIZATION: " + reason)

func git_value(arguments: PackedStringArray) -> String:
    var project := ProjectSettings.globalize_path("res://")
    if not FileAccess.file_exists(project.path_join(".git")) and not DirAccess.dir_exists_absolute(project.path_join(".git")):
        return "isolated-copy-see-benchmark-source.json"
    var value: Array = []
    var command := PackedStringArray(["-C", project])
    command.append_array(arguments)
    var exit_code := OS.execute("git", command, value)
    return str(value[0]).strip_edges() if exit_code == 0 and not value.is_empty() else "unavailable"

func draw_fenced() -> Image:
    await process_frame
    call_deferred("force_draw")
    await RenderingServer.frame_post_draw
    # Readback fences queued GPU work rather than timing command submission.
    # It adds identical CPU transfer work to every A/B sample; retain this limit.
    return root.get_texture().get_image()

func force_draw() -> void:
    RenderingServer.force_draw(true)

func numbers(values: Array) -> Dictionary:
    if values.is_empty(): return {}
    var ordered := values.duplicate()
    ordered.sort()
    var total := 0.0
    for value in values: total += float(value)
    return {"median": ordered[ordered.size() / 2], "p95": ordered[mini(ordered.size()-1, ceili(ordered.size()*.95)-1)], "min": ordered[0], "max": ordered[-1], "mean": total / values.size(), "samples": values}

func world_summary() -> Dictionary:
    var optimizer = game.world.rendering_optimizer
    if optimizer == null: return {"missing_optimizer": true}
    if optimizer.has_method("workload_summary"):
        return optimizer.call("workload_summary", camera)
    var instances := 0
    var cards := 0
    var surfaces := 0
    var batches := 0
    for record in optimizer.records:
        var count: int = record.multi.visible_instance_count
        if count < 0: count = record.multi.instance_count
        instances += count
        if record.cutout: cards += count
        if count > 0:
            batches += 1
            surfaces += record.multi.mesh.get_surface_count()
    return {"reference_147": true, "visible_instances_estimate": instances, "visible_cards": cards, "active_batches_estimate": batches, "active_surfaces_estimate": surfaces, "buffer_upload_count": optimizer.upload_count, "update_cpu_us": optimizer.last_update_usec, "buffer_upload_bytes": -1, "note": "Original 1.47 has no byte-write counter; instance counts are culling estimates, not fragment invocations."}

func select_profile(reference: bool) -> void:
    if isolated_147:
        check(reference, "isolated original source cannot represent production 1.48")
        current_reference = true
        return
    check(game.world.has_method("set_reference_147_enabled"), "world lacks real 1.47 reference toggle")
    if not game.world.has_method("set_reference_147_enabled"): return
    game.world.call("set_reference_147_enabled", reference)
    current_reference = reference

func update_visibility() -> void:
    if game.world.rendering_optimizer != null:
        game.world.rendering_optimizer.update(camera)

func configure_view(pose: Array, size_: Vector2i) -> void:
    root.size = size_
    game.world._mobile_profile()
    Engine.max_fps = 0
    game.player.global_position = pose[1]
    camera.fov = 65
    if pose[3]: camera.global_rotation_degrees = pose[2]
    else: camera.look_at(pose[2])
    update_visibility()

func sample_block(reference: bool, block: int, directory: String) -> Dictionary:
    # Native visibility-range hysteresis remembers a view's arrival path. B
    # hides the old plant instances, so an already-visible A0 and re-enabled A3
    # otherwise enter different native histories despite identical CPU buffers.
    # Give EVERY block the same hidden->visible transition, without changing
    # the authored ranges/margins or retaining a cheaper culling policy for A.
    game.world.hide()
    await draw_fenced()
    select_profile(reference)
    update_visibility()
    game.world.show()
    var before := world_summary()
    for i in range(warmup):
        await draw_fenced()
        # Also settle viewport-resize/projection notifications before timing.
        update_visibility()
    var times: Array = []
    var cpu_times: Array = []
    var gpu_times: Array = []
    var draw_calls: Array = []
    var triangles: Array = []
    var final_image: Image
    for i in range(samples):
        var started := Time.get_ticks_usec()
        final_image = await draw_fenced()
        times.append((Time.get_ticks_usec() - started) / 1000.0)
        cpu_times.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
        gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
        draw_calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
        triangles.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
    var profile := "reference147" if reference else "production148"
    var path := directory.path_join("%s-%d.png" % [profile, block])
    check(final_image != null and not final_image.is_empty(), "empty native frame")
    if final_image != null: final_image.save_png(path)
    var after := world_summary()
    return {"profile": profile, "block": block, "frame_ms": numbers(times), "render_cpu_ms": numbers(cpu_times), "gpu_timer_ms": numbers(gpu_times), "draw_calls": numbers(draw_calls), "triangles": numbers(triangles), "workload": after, "workload_before": before, "image": path.get_file()}

func measure_view(pose: Array, size_: Vector2i) -> void:
    configure_view(pose, size_)
    var name_ := "%s-%dx%d" % [pose[0], size_.x, size_.y]
    var directory := output.path_join(name_)
    DirAccess.make_dir_recursive_absolute(directory)
    var blocks: Array = []
    var sequence: Array = [true] if isolated_147 else [true, false, false, true]
    for i in range(sequence.size()):
        var result := await sample_block(sequence[i], i, directory)
        blocks.append(result)
        print("BOTANICAL OPTIMIZATION BLOCK: ", JSON.stringify({"view": name_, "profile": result.profile, "block": i, "median_ms": result.frame_ms.median, "calls": result.draw_calls.median, "triangles": result.triangles.median}))
    var viewport_size := Vector2(root.size) * root.scaling_3d_scale
    var result := {"view": name_, "camera_position": [camera.global_position.x, camera.global_position.y, camera.global_position.z], "camera_rotation_degrees": [camera.global_rotation_degrees.x, camera.global_rotation_degrees.y, camera.global_rotation_degrees.z], "window": [root.size.x, root.size.y], "scale_3d": root.scaling_3d_scale, "nominal_3d_pixels": viewport_size.x * viewport_size.y, "msaa": root.msaa_3d, "fov": camera.fov, "blocks": blocks}
    check(absf(float(result.nominal_3d_pixels) - 921600.0) < 5.0, "resolution/pixel cap changed during A/B")
    check(root.msaa_3d == Viewport.MSAA_2X, "MSAA differs from measured phone/reference configuration")
    report.views.append(result)
    FileAccess.open(output.path_join("optimization.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))

func measure_movement(reference: bool) -> Dictionary:
    select_profile(reference)
    configure_view(VIEWS[1], PHONE_SIZE)
    await draw_fenced()
    var start := world_summary()
    var samples_us: Array = []
    for i in range(moving_steps):
        game.player.global_position = Vector3(-22 + i * .2, 3.65, 22 - i * .25)
        camera.look_at(Vector3(sin(i * .05) * 25, 7, -35))
        var before := Time.get_ticks_usec()
        update_visibility()
        samples_us.append(Time.get_ticks_usec() - before)
    var finish := world_summary()
    var uploads := int(finish.get("buffer_upload_count", 0)) - int(start.get("buffer_upload_count", 0))
    var bytes := -1
    if int(finish.get("buffer_upload_bytes", -1)) >= 0 and int(start.get("buffer_upload_bytes", -1)) >= 0:
        bytes = int(finish.buffer_upload_bytes) - int(start.buffer_upload_bytes)
    var stationary_before := world_summary()
    for i in range(10): update_visibility()
    var stationary_after := world_summary()
    check(int(stationary_before.get("buffer_upload_count", 0)) == int(stationary_after.get("buffer_upload_count", 0)), "stationary camera unnecessarily uploads buffers")
    return {"profile": "reference147" if reference else "production148", "steps": moving_steps, "visibility_update_us": numbers(samples_us), "buffer_uploads": uploads, "buffer_upload_bytes": bytes, "start_workload": start, "end_workload": finish, "stationary_uploads": int(stationary_after.get("buffer_upload_count", 0)) - int(stationary_before.get("buffer_upload_count", 0)), "note": "CPU-only walking/turning visibility updates, without draw/readback inside the timer. GPU submission work is covered separately."}

func run() -> void:
    check(DisplayServer.get_name() != "headless", "native framebuffer required")
    check(RenderingServer.get_current_rendering_method() == "gl_compatibility", "benchmark must use actual Compatibility")
    if not failures.is_empty(): quit(1); return
    DirAccess.make_dir_recursive_absolute(output)
    previous_fps = Engine.max_fps
    previous_vsync = DisplayServer.window_get_vsync_mode()
    Engine.max_fps = 0
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    root.size = PHONE_SIZE
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").start_new_run()
    root.get_node("GameState").music_muted = true
    root.get_node("GameState").sfx_muted = true
    RenderingServer.set_render_loop_enabled(false)
    game = load("res://game.tscn").instantiate()
    if isolated_147: game.set_meta("reference_147", true)
    root.add_child(game)
    current_scene = game
    camera = game.player.camera
    check(camera != null, "actual player camera is missing")
    if camera == null: quit(1); return
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    game.player.set_process_unhandled_input(false)
    game.world.set_process(false)
    for guard in game.guards:
        guard.set_physics_process(false)
        guard.visual.set_process(false)
        guard.visual.apply_active()
        guard.visual.animate_squirrel(0, 0, 0, Vector3.ZERO, 0)
    game.world.set_meta("force_mobile_profile", true)
    game.world._mobile_profile()
    Engine.max_fps = 0
    game.hud.hide()
    game.weapon.hide()
    for label in game.find_children("*", "Label3D", true, false): label.hide()
    var water := Shader.new()
    water.code = game.world.mats.water.shader.code.replace("TIME", "0.0")
    game.world.mats.water.shader = water
    RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
    report.merge({"baseline_commit": BASELINE_COMMIT, "source_commit": git_value(["rev-parse", "HEAD"]), "source_tree": git_value(["rev-parse", "HEAD^{tree}"]), "isolated_original_147": isolated_147, "version": ProjectSettings.get_setting("application/config/version"), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "software_render_threads": OS.get_environment("LP_NUM_THREADS"), "sequence": "one frozen original 1.47 block" if isolated_147 else "ABBA = reference147, production148, production148, reference147", "visibility_history": "Canonical whole-world hidden->visible transition before EVERY block; authored ranges/margins remain unchanged. Camera/projection updates settle during fenced warmups.", "samples_per_block": samples, "warmup_frames_per_block": warmup, "max_fps": Engine.max_fps, "vsync": DisplayServer.window_get_vsync_mode(), "depth_prepass_setting": ProjectSettings.get_setting("rendering/driver/depth_prepass/enable", "unset"), "note": "Static baked-night garden, fixed actors/camera/water, same 921600 3D pixels/MSAA2. Native software GPU with identical full-frame readback fences; timing includes transfer overhead and is NOT mobile FPS. No samples or slow frames are discarded."}, true)
    for pose in VIEWS:
        if not only_view.is_empty() and str(pose[0]) != only_view: continue
        await measure_view(pose, PHONE_SIZE)
    if not phone_only and (only_view.is_empty() or only_view == "entry"):
        await measure_view(VIEWS[0], DESKTOP_SIZE)
    if moving_steps > 0:
        report.moving.append(await measure_movement(true))
        if not isolated_147: report.moving.append(await measure_movement(false))
    report.failures = failures
    FileAccess.open(output.path_join("optimization.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    game.queue_free()
    current_scene = null
    for i in range(5): await process_frame
    await load("res://tools/level3_test_teardown.gd").drain_audio(self)
    RenderingServer.set_render_loop_enabled(true)
    Engine.max_fps = previous_fps
    DisplayServer.window_set_vsync_mode(previous_vsync)
    if failures.is_empty(): print("BOTANICAL OPTIMIZATION CAPTURE: PASS — native matched pixels, warmed ABBA, actual workload and movement uploads; not phone FPS")
    quit(0 if failures.is_empty() else 1)
