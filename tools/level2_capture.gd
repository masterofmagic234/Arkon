extends SceneTree

# Reproducible graphics check: real controller input from rest, a bend, braking.
# godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
#   --script tools/level2_capture.gd -- --output=/absolute/output/directory
const RaceMath = preload("res://scripts/race_math.gd")
const Data = preload("res://scripts/race_level_data.gd")
var output_dir: String

func _init() -> void:
    output_dir = OS.get_user_data_dir().path_join("level2_capture")
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):
            output_dir = argument.trim_prefix("--output=")
    call_deferred("_run")

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Level2 capture needs a graphics display; use the smoke test for headless checks.")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(output_dir)
    var game_state = root.get_node("GameState")
    var music_was_muted: bool = game_state.music_muted
    game_state.music_muted = true
    var level = load("res://scenes/level2.tscn").instantiate()
    root.add_child(level)
    await process_frame
    await process_frame
    level.set_physics_process(false)
    level.set_process(false)
    level.state.race_started = true
    level.state.countdown = 0.0
    var car = level.controller.player
    var trace: Array = []
    var maximum_speed := 0.0
    for frame in range(360):
        for _step in range(2):
            var position: float = float(car.segment_index) + float(car.segment_progress)
            var centre := RaceMath.track_center_x(position, level.controller.track_x)
            var tangent := atan2(RaceMath.track_center_slope(position + 0.15, level.controller.track_x), Data.SEGMENT_HEIGHT)
            var ratio := clampf(float(car.speed) / Data.PLAYER_MAX_SPEED, 0.0, 1.0)
            # Test driver only: feed production steering, never modify car pose.
            var desired_yaw := tangent + (centre - float(car.world_x)) * 0.08
            var steer := clampf(desired_yaw / (Data.NFS_MAX_HEADING_YAW * lerpf(1.0, 0.48, ratio)), -0.85, 0.85)
            var braking := 1.0 if frame >= 290 else 0.0
            level.controller.handle_input(steer, 1.0 if braking == 0.0 else 0.0, braking)
            level.controller.update(1.0 / 60.0)
        level._process(1.0 / 30.0)
        await process_frame
        await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        var result := image.save_png(output_dir.path_join("frame_%04d.png" % frame))
        if result != OK:
            push_error("Cannot save captured frame: %s" % result)
            quit(1)
            return
        maximum_speed = maxf(maximum_speed, float(car.speed) / Data.SPEED_UNITS_PER_KMH)
        trace.append({"frame": frame, "speed_kmh": float(car.speed) / Data.SPEED_UNITS_PER_KMH, "car_yaw": float(car.heading_yaw), "camera_yaw": float(level.camera_state.yaw_offset), "steer": float(car.steer_applied), "lateral": float(car.lateral_offset), "wheel_phase": float(level.car_3d_overlay.rig.wheel_phase), "brake_light": float(level.car_3d_overlay.rig.brake_strength)})
    var file := FileAccess.open(output_dir.path_join("trace.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify({"fps": 30, "max_kmh": maximum_speed, "frames": trace}, "  "))
    file.close()
    print("LEVEL2 CAPTURE: PASS; frames=360; max_kmh=", maximum_speed, "; output=", output_dir)
    level.race_music.stop()
    level.race_music.stream = null
    level.queue_free()
    await create_timer(0.1).timeout
    game_state.music_muted = music_was_muted
    quit(0)
